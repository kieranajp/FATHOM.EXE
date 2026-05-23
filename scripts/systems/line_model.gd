# LineModel — explicit vertex+edge topology rendered as line primitives.
#
# Replaces "box-mesh + wireframe-shader" for things whose silhouette is
# non-box-aligned (ships, lighthouses, anything with a polygonal hull or
# octagonal column). The wireframe shader can only draw box-aligned edges via
# per-face UV detection; this model carries explicit edge pairs so we draw
# whatever topology the source data describes.
#
# Pipeline mirrors the T01 ocean grid: ImmediateMesh + PRIMITIVE_LINES + an
# emissive unshaded StandardMaterial3D. Blooms naturally via the OpenSea
# WorldEnvironment glow.
#
# Authoring: each .tres carries `vertices` and `edges`. Edges are a flat
# PackedInt32Array of vertex-index pairs (i0, i1, i0, i1, …). The pair-flat
# layout keeps .tres editing simple and avoids nested arrays in the resource.
#
# JS coords → Godot: every JS vertex (x, y, z) becomes Godot (x, y, -z). The JS
# prototype is left-handed with +Z north; Godot is right-handed with -Z
# forward. The Z-flip is applied at port time (in the .tres) so runtime stays
# axis-agnostic. Document any axis convention in a comment on each .tres.
class_name LineModel extends Resource

@export var vertices: PackedVector3Array
@export var edges: PackedInt32Array  # flat pairs: (i0, i1, i0, i1, …)
@export var color: Color = Color(1, 1, 1, 1)

# Optional vertex deformations keyed on a 0..1 "open factor" parameter
# (e.g. sail level / 4 for ships). Each entry is a plain Dictionary with:
#   indices: PackedInt32Array — vertex indices this entry applies to
#   top_y:   float            — Y anchor the listed verts collapse toward at f=0
#   mast_z:  float            — Z anchor the listed verts collapse toward at f=0
# Applied with factor f: each listed vertex's (y, z) is lerped from
# (top_y, mast_z) at f=0 to its authored (y, z) at f=1. X is untouched.
#
# NOT typed as `Array[Dictionary]` because typed Dictionaries can't nest (per
# docs/AGENTS.md gotchas), and the inner schema mixes a PackedInt32Array with
# floats. Plain `Array` of plain Dictionaries keeps .tres authoring simple.
@export var deformations: Array = []


# Builds an ImmediateMesh that draws this model as PRIMITIVE_LINES. Each edge
# pair becomes two vertices in sequence.
#
# `scale` is a uniform multiplier applied to all vertices — convenient when a
# model authored in metres needs to feel chunkier without re-authoring coords.
#
# `open_factor` drives any `deformations` entries: 0 collapses listed verts to
# their (top_y, mast_z) anchor, 1 leaves them at their authored position. Models
# with no deformations are unaffected.
func build_immediate_mesh(scale: float = 1.0, open_factor: float = 1.0) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Iterate edges in pairs. Each (i0, i1) emits one line segment.
	var n: int = edges.size()
	var i: int = 0
	while i + 1 < n:
		var i0: int = edges[i]
		var i1: int = edges[i + 1]
		if i0 >= 0 and i1 >= 0 and i0 < vertices.size() and i1 < vertices.size():
			mesh.surface_add_vertex(_deformed_vertex(i0, scale, open_factor))
			mesh.surface_add_vertex(_deformed_vertex(i1, scale, open_factor))
		i += 2
	mesh.surface_end()
	return mesh


# Rebuilds the given ImmediateMesh in place using the same logic as
# build_immediate_mesh. Mirrors Ocean's per-frame regenerate pattern — avoids
# allocating a fresh ImmediateMesh every frame when only the open_factor moves.
func rebuild_immediate_mesh(mesh: ImmediateMesh, scale: float = 1.0, open_factor: float = 1.0) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var n: int = edges.size()
	var i: int = 0
	while i + 1 < n:
		var i0: int = edges[i]
		var i1: int = edges[i + 1]
		if i0 >= 0 and i1 >= 0 and i0 < vertices.size() and i1 < vertices.size():
			mesh.surface_add_vertex(_deformed_vertex(i0, scale, open_factor))
			mesh.surface_add_vertex(_deformed_vertex(i1, scale, open_factor))
		i += 2
	mesh.surface_end()


# Returns the scaled position of vertex `idx`, with deformations applied at
# `open_factor`. Iterates deformations; first match wins (sail verts shouldn't
# be in multiple entries, but if they were we'd want deterministic order).
func _deformed_vertex(idx: int, scale: float, open_factor: float) -> Vector3:
	var v: Vector3 = vertices[idx] * scale
	for def in deformations:
		var indices: PackedInt32Array = def.get("indices", PackedInt32Array())
		if idx in indices:
			var top_y: float = float(def.get("top_y", 0.0)) * scale
			var mast_z: float = float(def.get("mast_z", 0.0)) * scale
			v.y = top_y + (v.y - top_y) * open_factor
			v.z = mast_z + (v.z - mast_z) * open_factor
			break
	return v


# Builds a MeshInstance3D ready to drop into a scene. Material is an emissive
# unshaded StandardMaterial3D matching the ocean grid's setup so glow behaves
# identically. `emission_energy_multiplier` is tunable; the default mirrors
# Ocean's 1.5.
func build_mesh_instance(scale: float = 1.0, emission_energy: float = 1.5) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = build_immediate_mesh(scale)

	var mat := _build_material(emission_energy)
	inst.material_override = mat
	# Models rebuild rarely; the AABB is stable so default culling is fine —
	# unlike Ocean's per-frame regenerate grid, this mesh doesn't flicker.
	return inst


# Like build_mesh_instance, but emits view-aligned thick quads instead of
# 1-pixel PRIMITIVE_LINES. The returned node is a ThickLineMesh which rebuilds
# itself every frame against the active Camera3D — necessary because the
# quads must face the camera to read as flat ribbons.
#
# `thickness` is world-space metres of full ribbon width. ~0.04m at chase-cam
# range reads as roughly 2px on 4K; see RenderTuning.line_thickness_world.
#
# `reference_distance` enables distance-linear thickness scaling — edges
# beyond this distance get proportionally fatter so they stay visible at
# range. Zero disables. Islands sit ~540m from the player ship while ships
# are ~15m away, so the chase cam needs the scaling to see distant bases.
#
# Returns the ThickLineMesh node (a MeshInstance3D subclass) so callers that
# need to drive deformations (sails) can set `open_factor` directly. Static
# models can ignore the field — it defaults to 1.0.
func build_thick_mesh_instance(
	scale: float = 1.0,
	thickness: float = 0.04,
	emission_energy: float = 1.5,
	reference_distance: float = 0.0,
) -> ThickLineMesh:
	var inst := ThickLineMesh.new()
	inst.model = self
	inst.thickness = thickness
	inst.scale_factor = scale
	inst.reference_distance = reference_distance
	inst.material_override = _build_material(emission_energy)
	return inst


# Shared material build — extracted so both the line and the thick-line paths
# stay byte-identical. Bloom contract: ALBEDO + emission > 1.0 so glow passes
# the WorldEnvironment HDR threshold. Cull disabled so the thick-line quads
# render from either side — billboarded triangles flip winding as the camera
# orbits, and the default back-face cull would silently drop half the geometry.
func _build_material(emission_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_energy
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
