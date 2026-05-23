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
	# view×line perpendicular collapses to zero. Round-4 fell back to UP×line
	# which produced a HORIZONTAL perpendicular for horizontal lines (the quad
	# went edge-on to a chase cam and disappeared); round-5 projects world-up
	# onto the line's perpendicular plane so the quad stands VERTICALLY for a
	# horizontal line and stays visible from a horizontal viewpoint.
	#
	# Pin: quad still emits its six vertices, ribbon width matches thickness,
	# and (the new contract) the perpendicular axis is VERTICAL — y-dominant.
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	# Camera at +X — same axis as the line. perp via view×line = 0.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(5, 0, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 6, "Collinear camera-and-line should fall back, not skip")
	var width := out[0].distance_to(out[1])
	assert_almost_eq(width, 0.1, 1e-5, "Fallback ribbon width still matches thickness")
	# Perp should be vertical: out[0]=(a+perp), out[1]=(a-perp) → their offset
	# along Y dominates X and Z.
	var perp_offset: Vector3 = out[0] - out[1]
	assert_gt(abs(perp_offset.y), abs(perp_offset.x), "Fallback perp is vertical (y > x)")
	assert_gt(abs(perp_offset.y), abs(perp_offset.z), "Fallback perp is vertical (y > z)")


func test_horizontal_line_toward_camera_emits_vertical_perp() -> void:
	# The bug round-5 fixes: a horizontal outer-ring edge of an island pointing
	# along the camera's view axis. Round-4 fallback (UP×line) would emit a
	# HORIZONTAL perpendicular, giving a horizontal quad that's invisible from
	# a horizontal chase cam. Round-5 must emit a VERTICAL perpendicular.
	var mesh := _make_mesh()
	# Line along +X, sitting on the sea surface.
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(2, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	# Camera further along +X axis, also at sea level — looking down the line.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(50, 0, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 6, "Edge still emits a quad after fallback")
	var perp_offset: Vector3 = out[0] - out[1]
	assert_gt(abs(perp_offset.y), abs(perp_offset.x), "Perp is vertical (y>x)")
	assert_gt(abs(perp_offset.y), abs(perp_offset.z), "Perp is vertical (y>z)")


func test_vertical_collinear_uses_world_right_fallback() -> void:
	# A vertical edge viewed along its own axis. view×line = 0, and the
	# round-5 UP-projection also collapses (UP is parallel to line), so the
	# renderer must drop through to the world-right projection as last resort.
	# Pin "emits a quad" and "perp is horizontal".
	var mesh := _make_mesh()
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(0, 1, 0)])
	var edges := PackedInt32Array([0, 1])
	# Camera directly above — view_dir = UP, line_dir = UP. Both crosses zero.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 5, 0), 0.1, null)
	var out := _surface_verts(mesh)
	assert_eq(out.size(), 6, "Vertical edge viewed along its length still emits a quad")
	# Last-resort fallback uses world-right (X axis) projected onto the line-
	# perpendicular plane. For a Y-axis line that's just X itself.
	var perp_offset: Vector3 = out[0] - out[1]
	assert_gt(abs(perp_offset.x), abs(perp_offset.y), "Last-resort perp is horizontal (x>y)")


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


# --- Round-7: distance-linear thickness scaling. ---
#
# Islands at the chase-cam range (~540m) need fatter ribbons or they subtend
# <0.1 px and visually disappear. Optional via `reference_distance` argument
# so close-range overlays (aim cone) and the player ship don't get inflated.

func test_distance_scaling_zero_disables() -> void:
	# `reference_distance = 0.0` (the default) keeps the authored thickness
	# everywhere — preserves the existing pre-round-7 behaviour for any
	# caller that hasn't opted into scaling.
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	# Camera 100m away. Without scaling, width should still equal thickness.
	var mesh := _make_mesh()
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0, 100, 0), 0.1, null, 0.0)
	var out := _surface_verts(mesh)
	var width := out[0].distance_to(out[1])
	assert_almost_eq(width, 0.1, 1e-5, "ref_distance=0 disables scaling")


func test_distance_scaling_close_clamps_to_base() -> void:
	# Camera closer than the reference distance — thickness must stay at the
	# authored width thanks to the max(1.0, dist/ref) clamp.
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	var mesh := _make_mesh()
	# Camera 10m away, reference 15m — dist/ref = 0.67, clamped to 1.0.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0.5, 10, 0), 0.06, null, 15.0)
	var out := _surface_verts(mesh)
	var width := out[0].distance_to(out[1])
	assert_almost_eq(width, 0.06, 1e-4,
		"Camera within reference distance keeps the authored thickness")


func test_distance_scaling_far_inflates_linearly() -> void:
	# Camera 10× the reference distance — ribbon width must be 10× the
	# authored thickness. Keeps far ribbons at a stable on-screen pixel size.
	var verts := PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	var edges := PackedInt32Array([0, 1])
	var mesh := _make_mesh()
	# Camera 150m away, reference 15m — 10× factor.
	ThickLineRenderer.rebuild(mesh, verts, edges, Vector3(0.5, 150, 0), 0.06, null, 15.0)
	var out := _surface_verts(mesh)
	var width := out[0].distance_to(out[1])
	assert_almost_eq(width, 0.6, 1e-3,
		"Camera at 10× reference distance gives 10× ribbon width")
