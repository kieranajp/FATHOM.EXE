# LineModel — verify the resource loader handles ported .tres files and the
# helper produces the right vertex count.
#
# Load-bearing because the renderer's "two ImmediateMesh vertices per edge"
# invariant is the only thing keeping silhouettes from going haywire. If
# someone later swaps surface_add_vertex semantics or refactors the edge
# layout this test will catch the regression.
extends GutTest


func test_build_immediate_mesh_emits_two_vertices_per_edge() -> void:
	var model := LineModel.new()
	model.vertices = PackedVector3Array(
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)]
	)
	# Two edges: (0→1) and (1→2). Expect 4 line-vertices on the surface.
	model.edges = PackedInt32Array([0, 1, 1, 2])
	var mesh := model.build_immediate_mesh()
	assert_eq(mesh.get_surface_count(), 1, "Should have exactly one surface")
	# Surface arrays: [VERTEX] index is 0 in ArrayMesh-style fetch.
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 4, "Two edges × 2 endpoints = 4 line-vertices")
	assert_eq(verts[0], Vector3(0, 0, 0))
	assert_eq(verts[1], Vector3(1, 0, 0))
	assert_eq(verts[2], Vector3(1, 0, 0))
	assert_eq(verts[3], Vector3(0, 1, 0))


func test_build_immediate_mesh_skips_out_of_range_indices() -> void:
	# Defensive — bad .tres data shouldn't crash the renderer.
	var model := LineModel.new()
	model.vertices = PackedVector3Array([Vector3.ZERO, Vector3.ONE])
	model.edges = PackedInt32Array([0, 1, 0, 99, -1, 0])  # second + third pairs invalid
	var mesh := model.build_immediate_mesh()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 2, "Only the (0,1) pair should make it through")


func test_dinghy_resource_loads() -> void:
	var dinghy := load("res://data/models/dinghy.tres") as LineModel
	assert_not_null(dinghy, "dinghy.tres should load as a LineModel")
	assert_eq(dinghy.vertices.size(), 17, "Dinghy has 17 vertices (JS source)")
	# 28 edges in JS source → 56 ints in flat (i0, i1) pair layout.
	assert_eq(dinghy.edges.size(), 56, "Dinghy has 28 edges → 56 ints")


func test_lighthouse_resource_loads() -> void:
	var lh := load("res://data/models/lighthouse.tres") as LineModel
	assert_not_null(lh, "lighthouse.tres should load as a LineModel")
	assert_eq(lh.vertices.size(), 25, "Lighthouse has 25 vertices (JS source)")
	# 44 edges in JS source → 88 ints.
	assert_eq(lh.edges.size(), 88, "Lighthouse has 44 edges → 88 ints")


func test_build_mesh_instance_has_emissive_material() -> void:
	# Asserts the bloom contract — albedo + emission should be set so glow_hdr_threshold
	# in OpenSea WorldEnvironment can do its job.
	var model := LineModel.new()
	model.vertices = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])
	model.edges = PackedInt32Array([0, 1])
	model.color = Color(0.5, 1.0, 0.3, 1.0)
	var inst := model.build_mesh_instance()
	assert_not_null(inst.material_override, "Material should be set")
	var mat := inst.material_override as StandardMaterial3D
	assert_not_null(mat, "Material should be StandardMaterial3D")
	assert_true(mat.emission_enabled, "Emission must be enabled to bloom")
	assert_eq(mat.emission, model.color, "Emission colour matches model colour")
	assert_eq(
		mat.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Unshaded so lighting doesn't dim the wires"
	)
	# free() the orphan so GUT doesn't complain — there's no scene tree here.
	inst.free()
