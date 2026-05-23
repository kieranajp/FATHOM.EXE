# ThickLineMesh — a MeshInstance3D that renders a LineModel as billboarded
# quads via ThickLineRenderer, regenerated every frame against the active
# Camera3D.
#
# Why a node (not just a static call): each consumer (PlayerShip, EnemyShip,
# PortMesh, lighthouse beam) needs per-frame camera tracking + optional
# open_factor deformation. Bundling that loop into one node keeps the
# consumer code trivial — instantiate, add as child, done.
#
# Cost: O(edges) triangles per frame. The whole scene fits in low tens of
# thousands of triangles — well under the per-frame budget. We resolve the
# camera via get_viewport().get_camera_3d() which is internally cached, so
# the lookup is one pointer-chase per node per frame.
#
# Headless: get_camera_3d() returns null when no Camera3D is in the scene
# (typical for unit tests). We skip the rebuild in that case so the mesh
# stays empty rather than crashing.
class_name ThickLineMesh extends MeshInstance3D

# Source model + per-frame rebuild params. `model` carries vertices, edges,
# and optional deformations; `scale` mirrors LineModel.build_immediate_mesh.
var model: LineModel
var thickness: float = 0.04
var scale_factor: float = 1.0
# open_factor drives LineModel.deformations — set by sail-handling code
# (PlayerShip) each frame. Static models (lighthouse, island, beam) leave it
# at 1.0 and the deformation loop becomes a no-op.
var open_factor: float = 1.0
# Distance-linear thickness scaling. Edges further than this from the camera
# get fatter so they stay visible at chase-cam range (islands ~540m away vs.
# ships ~15m away). Zero disables the scaling — keep the authored thickness
# everywhere. See ThickLineRenderer.rebuild docstring.
var reference_distance: float = 0.0

# Held so we don't reallocate per frame. material_override sits on the node
# itself (set up at construction time).
var _imm_mesh: ImmediateMesh


func _ready() -> void:
	_imm_mesh = ImmediateMesh.new()
	mesh = _imm_mesh
	# Cull margin: edges may extend outside the node's local AABB once
	# billboarded. ImmediateMesh AABB updates per surface_end, so the cull
	# bounds *will* update — but the safe path is to disable bound culling
	# entirely for these meshes since rebuild cost is dominated by triangle
	# emission, not by visibility checks. Matches AimOverlay's pattern.
	extra_cull_margin = 4096.0


func _process(_delta: float) -> void:
	if model == null or _imm_mesh == null:
		return
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	# Camera position is needed in *local* space because surface_add_vertex
	# emits vertices in the node's local frame. Transform world→local via the
	# inverse global transform.
	var cam_local: Vector3 = global_transform.affine_inverse() * cam.global_position
	# Build a deformed vertex array. For models without deformations this is
	# just the scaled originals; for sails it tweens against open_factor.
	var verts := _deformed_vertices()
	ThickLineRenderer.rebuild(
		_imm_mesh,
		verts,
		model.edges,
		cam_local,
		thickness,
		material_override,
		reference_distance,
	)


# Mirrors LineModel._deformed_vertex but emits the full array up-front so
# ThickLineRenderer can index it freely. A bit wasteful for static models —
# fine in practice; vertex counts are tens, not thousands.
func _deformed_vertices() -> PackedVector3Array:
	var n: int = model.vertices.size()
	var out := PackedVector3Array()
	out.resize(n)
	for idx in range(n):
		out[idx] = _deformed_vertex(idx)
	return out


func _deformed_vertex(idx: int) -> Vector3:
	var v: Vector3 = model.vertices[idx] * scale_factor
	for def in model.deformations:
		var indices: PackedInt32Array = def.get("indices", PackedInt32Array())
		if idx in indices:
			var top_y: float = float(def.get("top_y", 0.0)) * scale_factor
			var mast_z: float = float(def.get("mast_z", 0.0)) * scale_factor
			v.y = top_y + (v.y - top_y) * open_factor
			v.z = mast_z + (v.z - mast_z) * open_factor
			break
	return v
