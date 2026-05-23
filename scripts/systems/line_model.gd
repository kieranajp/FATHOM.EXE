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


# Builds an ImmediateMesh that draws this model as PRIMITIVE_LINES. Each edge
# pair becomes two vertices in sequence.
#
# `scale` is a uniform multiplier applied to all vertices — convenient when a
# model authored in metres needs to feel chunkier without re-authoring coords.
func build_immediate_mesh(scale: float = 1.0) -> ImmediateMesh:
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
			mesh.surface_add_vertex(vertices[i0] * scale)
			mesh.surface_add_vertex(vertices[i1] * scale)
		i += 2
	mesh.surface_end()
	return mesh


# Builds a MeshInstance3D ready to drop into a scene. Material is an emissive
# unshaded StandardMaterial3D matching the ocean grid's setup so glow behaves
# identically. `emission_energy_multiplier` is tunable; the default mirrors
# Ocean's 1.5.
func build_mesh_instance(scale: float = 1.0, emission_energy: float = 1.5) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = build_immediate_mesh(scale)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_energy
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	inst.material_override = mat
	# Models rebuild rarely; the AABB is stable so default culling is fine —
	# unlike Ocean's per-frame regenerate grid, this mesh doesn't flicker.
	return inst
