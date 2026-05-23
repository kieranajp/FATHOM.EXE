# LineModel.deformations — verify the open_factor interpolation that drives
# sail unfurling. The math is short but load-bearing for the W/S input feeling
# right; this guards against a future refactor breaking the linear lerp or
# accidentally touching non-listed vertices.
#
# Setup mirrors the dinghy: a few "sail" verts above a "top_y" anchor with
# their z offset from "mast_z". At f=0 they collapse to the anchor; at f=1
# they sit at their authored position; at f=0.5 the y and z are halfway.
extends GutTest


# Build a LineModel with the JS-style sail topology in miniature:
#   - vertex 0: hull vert (untouched by deformations)
#   - vertex 1, 2: sail verts, both with y above top_y and z offset from mast_z
# One deformation entry collapses verts 1,2 toward (top_y=5.0, mast_z=-0.5).
func _make_model() -> LineModel:
	var m := LineModel.new()
	m.vertices = PackedVector3Array([
		Vector3(0, 0, 0),         # 0 — hull, never deforms
		Vector3(-1.0, 7.0, 1.5),  # 1 — sail, original y=7, z=1.5
		Vector3(1.0, 6.0, -1.0),  # 2 — sail, original y=6, z=-1.0
	])
	# Edges drawn so we can read all three verts back through surface_get_arrays
	# in a known order: (0,1) then (0,2).
	m.edges = PackedInt32Array([0, 1, 0, 2])
	m.deformations = [{
		"indices": PackedInt32Array([1, 2]),
		"top_y": 5.0,
		"mast_z": -0.5,
	}]
	return m


func _surface_verts(mesh: ImmediateMesh) -> PackedVector3Array:
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


func test_open_factor_zero_collapses_sail_verts_to_anchor() -> void:
	var m := _make_model()
	var mesh := m.build_immediate_mesh(1.0, 0.0)
	var verts := _surface_verts(mesh)
	# Layout: [0, 1, 0, 2]. Verts 1 and 2 should sit at (anchor_y, anchor_z).
	assert_eq(verts[1].y, 5.0, "Vertex 1 y collapses to top_y at f=0")
	assert_eq(verts[1].z, -0.5, "Vertex 1 z collapses to mast_z at f=0")
	assert_eq(verts[3].y, 5.0, "Vertex 2 y collapses to top_y at f=0")
	assert_eq(verts[3].z, -0.5, "Vertex 2 z collapses to mast_z at f=0")
	# X is untouched by deformations at any open_factor.
	assert_eq(verts[1].x, -1.0, "Vertex 1 x unchanged at f=0")
	assert_eq(verts[3].x, 1.0, "Vertex 2 x unchanged at f=0")


func test_open_factor_one_leaves_sail_verts_at_original() -> void:
	var m := _make_model()
	var mesh := m.build_immediate_mesh(1.0, 1.0)
	var verts := _surface_verts(mesh)
	assert_eq(verts[1], Vector3(-1.0, 7.0, 1.5), "Vertex 1 at original at f=1")
	assert_eq(verts[3], Vector3(1.0, 6.0, -1.0), "Vertex 2 at original at f=1")


func test_open_factor_half_lerps_halfway() -> void:
	var m := _make_model()
	var mesh := m.build_immediate_mesh(1.0, 0.5)
	var verts := _surface_verts(mesh)
	# Vertex 1: y = 5 + (7-5)*0.5 = 6.0; z = -0.5 + (1.5-(-0.5))*0.5 = 0.5
	assert_almost_eq(verts[1].y, 6.0, 0.0001, "Vertex 1 y is halfway at f=0.5")
	assert_almost_eq(verts[1].z, 0.5, 0.0001, "Vertex 1 z is halfway at f=0.5")
	# Vertex 2: y = 5 + (6-5)*0.5 = 5.5; z = -0.5 + (-1.0-(-0.5))*0.5 = -0.75
	assert_almost_eq(verts[3].y, 5.5, 0.0001, "Vertex 2 y is halfway at f=0.5")
	assert_almost_eq(verts[3].z, -0.75, 0.0001, "Vertex 2 z is halfway at f=0.5")


func test_non_sail_verts_unaffected_at_any_open_factor() -> void:
	var m := _make_model()
	# At f=0 the hull vert 0 (idx not in any deformation) should still be ZERO.
	var mesh0 := m.build_immediate_mesh(1.0, 0.0)
	var v0 := _surface_verts(mesh0)
	assert_eq(v0[0], Vector3.ZERO, "Hull vert untouched at f=0")
	assert_eq(v0[2], Vector3.ZERO, "Hull vert untouched at f=0 (second occurrence)")
	# Mid-range too.
	var mesh_half := m.build_immediate_mesh(1.0, 0.5)
	var vh := _surface_verts(mesh_half)
	assert_eq(vh[0], Vector3.ZERO, "Hull vert untouched at f=0.5")


func test_rebuild_in_place_matches_fresh_build() -> void:
	# rebuild_immediate_mesh should produce the same surface as build_immediate_mesh
	# at the same open_factor — this is the per-frame fast path PlayerShip uses.
	var m := _make_model()
	var fresh := m.build_immediate_mesh(1.0, 0.5)
	var reused := ImmediateMesh.new()
	m.rebuild_immediate_mesh(reused, 1.0, 0.5)
	var a := _surface_verts(fresh)
	var b := _surface_verts(reused)
	assert_eq(a.size(), b.size(), "Same vertex count")
	for i in a.size():
		assert_eq(a[i], b[i], "Vertex %d matches" % i)


func test_model_without_deformations_is_unaffected_by_open_factor() -> void:
	# Backwards-compat: lighthouse / non-sailing models have no deformations.
	var m := LineModel.new()
	m.vertices = PackedVector3Array([Vector3.ZERO, Vector3(1, 2, 3)])
	m.edges = PackedInt32Array([0, 1])
	# No deformations set.
	var at_zero := _surface_verts(m.build_immediate_mesh(1.0, 0.0))
	var at_one := _surface_verts(m.build_immediate_mesh(1.0, 1.0))
	assert_eq(at_zero[1], Vector3(1, 2, 3), "Original vert preserved at f=0 with no deformations")
	assert_eq(at_one[1], Vector3(1, 2, 3), "Original vert preserved at f=1 with no deformations")


func test_dinghy_resource_deformations_load() -> void:
	# Pin the ported deformations so a future .tres edit can't quietly drop them.
	var dinghy := load("res://data/models/dinghy.tres") as LineModel
	assert_not_null(dinghy, "dinghy.tres should load")
	assert_eq(dinghy.deformations.size(), 1, "Dinghy has one sail deformation entry")
	var entry: Dictionary = dinghy.deformations[0]
	var indices: PackedInt32Array = entry["indices"]
	assert_eq(indices.size(), 5, "Five sail vertices (12..16)")
	for idx in [12, 13, 14, 15, 16]:
		assert_true(idx in indices, "Sail vert idx %d is listed" % idx)
	assert_eq(float(entry["top_y"]), 5.2, "top_y ported from JS")
	assert_eq(float(entry["mast_z"]), -0.5, "mast_z Z-flipped from JS +0.5")
