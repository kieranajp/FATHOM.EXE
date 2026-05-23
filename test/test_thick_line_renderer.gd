# ThickLineRenderer — verify the billboarded-quad emission. This is the load-
# bearing piece of the resolution-independent line-thickness fix; if a future
# refactor breaks the per-segment perpendicular math or drops the degenerate-
# edge guards, ships and lighthouses go invisible.
extends GutTest


func _make_mesh() -> ImmediateMesh:
	return ImmediateMesh.new()


func _surface_verts(mesh: ImmediateMesh) -> PackedVector3Array:
	if mesh.get_surface_count() == 0:
		return PackedVector3Array()
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


func test_single_edge_emits_six_vertices() -> void:
	# One edge → one quad → two triangles → six vertices.
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	# Camera at +Y; line along X; perp axis = view × line = Y × X = -Z → quad in XZ plane.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 1, 0), 0.1, null)
	assert_eq(mesh.get_surface_count(), 1, "Should have one surface")
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 6, "One edge → six vertices (two triangles)")


func test_degenerate_edge_emits_no_vertices() -> void:
	# Zero-length edge — should be skipped (line_len <= epsilon).
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var edges := PackedInt32Array([0, 1])
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 1, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 0, "Degenerate edge emits zero vertices")


func test_zero_thickness_emits_no_surface() -> void:
	# A zero-thickness ribbon collapses to a degenerate quad; the renderer
	# bails out early before opening a surface. Either zero surfaces or zero
	# verts is acceptable — we pin zero surfaces (the early-return path).
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 1, 0), 0.0, null)
	assert_eq(mesh.get_surface_count(), 0, "Zero thickness → no surface emitted")


func test_camera_position_changes_vertex_positions() -> void:
	# When the camera moves, the billboarded quad rotates — vertex positions
	# should differ between two camera positions on different sides of the
	# line. (Picking +Y vs -Z; both are perpendicular to the X-axis line, but
	# the resulting perp axes differ.)
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])

	var mesh_a := _make_mesh()
	ThickLineRenderer.rebuild(mesh_a, verts, edges, Vector3(0, 1, 0), 0.1, null)
	var out_a := _surface_verts(mesh_a)

	var mesh_b := _make_mesh()
	ThickLineRenderer.rebuild(mesh_b, verts, edges, Vector3(0, 0, -1), 0.1, null)
	var out_b := _surface_verts(mesh_b)

	assert_eq(out_a.size(), out_b.size(), "Both rebuilds emit same vertex count")
	# At least one vertex must differ — the quads face different cameras.
	var any_differ: bool = false
	for i in out_a.size():
		if out_a[i] != out_b[i]:
			any_differ = true
			break
	assert_true(any_differ, "Vertex positions must differ when camera moves")


func test_multiple_edges_emit_proportional_vertices() -> void:
	# Each well-formed edge emits 6 verts; 3 edges → 18 verts.
	var mesh := _make_mesh()
	var verts := PackedVector3Array(
		[Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0)]
	)
	var edges := PackedInt32Array([0, 1, 1, 2, 2, 3])
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 1, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 18, "Three edges → 18 vertices")


func test_collinear_view_and_line_uses_fallback_perpendicular() -> void:
	# Camera lies on the line itself — view_dir is parallel to line_dir so the
	# view×line perpendicular collapses to zero. Round-4 fix: instead of
	# skipping the quad (which made port outer-rings disappear at the horizon),
	# fall back to a world-up-based perpendicular so the edge stays visible.
	#
	# Pin the new contract: the quad still emits its six vertices and the
	# ribbon width matches the requested thickness.
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	# Camera at +X — same axis as the line. perp via view×line = 0.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(5, 0, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 6, "Collinear camera-and-line should fall back, not skip")
	# Fallback uses world-up × line. For an X-axis line that's UP × X = -Z, so
	# the +perp / -perp offsets sit at ±Z relative to the segment endpoints.
	# Ribbon width = thickness regardless of orientation.
	var width := out[0].distance_to(out[1])
	assert_almost_eq(width, 0.1, 1e-5, "Fallback ribbon width still matches thickness")


func test_vertical_collinear_uses_world_right_fallback() -> void:
	# Edge cases: a vertical edge viewed along its own axis. Both view×line AND
	# UP×line collapse (UP is parallel to the line), so the renderer must drop
	# through to the world-right fallback. Pin "still emits something".
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(0, 1, 0)])
	var edges := PackedInt32Array([0, 1])
	# Camera directly above — view_dir = UP, line_dir = UP. Both crosses zero.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 5, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 6, "Vertical edge viewed along its length still emits a quad")


func test_thickness_scales_perp_distance() -> void:
	# Doubling the thickness should double the cross-line distance between
	# the +perp and -perp vertices of a quad.
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])

	var mesh_a := _make_mesh()
	ThickLineRenderer.rebuild(mesh_a, verts, edges, Vector3(0, 1, 0), 0.1, null)
	var out_a := _surface_verts(mesh_a)

	var mesh_b := _make_mesh()
	ThickLineRenderer.rebuild(mesh_b, verts, edges, Vector3(0, 1, 0), 0.2, null)
	var out_b := _surface_verts(mesh_b)

	# verts[0] and verts[1] are (a+perp) and (a-perp) — their separation is
	# the full ribbon width.
	var width_a := out_a[0].distance_to(out_a[1])
	var width_b := out_b[0].distance_to(out_b[1])
	assert_almost_eq(width_a, 0.1, 1e-5, "Thickness 0.1 → ribbon width 0.1")
	assert_almost_eq(width_b, 0.2, 1e-5, "Thickness 0.2 → ribbon width 0.2")


func test_invalid_edge_indices_are_skipped() -> void:
	# Defensive — bad .tres edges shouldn't crash. Out-of-range indices
	# should be dropped silently, like LineModel.build_immediate_mesh does.
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	# (0, 99) and (-1, 0) are both invalid; only (0, 1) survives.
	var edges := PackedInt32Array([0, 1, 0, 99, -1, 0])
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 1, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 6, "Only the valid (0,1) edge produces vertices")
