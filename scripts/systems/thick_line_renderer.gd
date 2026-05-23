# ThickLineRenderer — renders an edge list as a triangle-strip mesh of
# view-aligned quads, giving "thick lines" in world-space metres of consistent
# apparent width regardless of resolution.
#
# Why this exists: Godot's PRIMITIVE_LINES is hard-coded to 1 pixel wide in
# Vulkan, which on a 4K display reads as hair-thin against the bloom halo.
# Emission bumping only gets you so far before everything bleeds together.
# Replacing the line primitive with billboarded quads gives us pixel-thickness
# we can dial — at the cost of CPU-side per-frame regeneration (the quads
# must face the camera, so they rebuild whenever the camera moves).
#
# Pipeline mirrors LineModel.build_immediate_mesh: each input edge (a, b)
# becomes a quad with vertices offset by ±thickness/2 perpendicular to both
# the line and the view direction (start→camera). The quad always faces the
# camera, so it reads as a thick line from any angle.
#
# Caller is responsible for owning the ImmediateMesh, calling rebuild()
# per-frame (or whenever camera moves), and assigning the mesh to a
# MeshInstance3D. The material lives on the MeshInstance3D as before —
# same StandardMaterial3D (unshaded + emissive) the line renderer used —
# but consumed as a PRIMITIVE_TRIANGLES surface now.
class_name ThickLineRenderer extends RefCounted


# Rebuilds the ImmediateMesh in-place. Each input edge emits two triangles
# (one quad) view-aligned against camera_pos. Degenerate edges (zero length
# or collinear with view direction) are skipped.
#
# Use Mesh.PRIMITIVE_TRIANGLES — the spec quirk is each pair of triangles
# in a quad is emitted as six discrete vertices, not as a strip, so the
# triangle winding stays consistent regardless of edge order.
#
# `reference_distance` enables distance-linear thickness scaling. Edges whose
# midpoint sits beyond this distance from `camera_pos` get a thickness of
# `thickness × (dist / reference_distance)`; closer edges keep the authored
# `thickness`. Passing 0.0 (the default) disables scaling — useful for short-
# range overlays like the aim cone where everything is roughly at chase-cam
# distance anyway. Distant islands viewed from chase-cam (~540m) need the
# scaling because a 0.06m world-space ribbon subtends ~0.1px at that range
# and effectively vanishes.
static func rebuild(
	mesh: ImmediateMesh,
	vertices: PackedVector3Array,
	edges: PackedInt32Array,
	camera_pos: Vector3,
	thickness: float,
	material: Material,
	reference_distance: float = 0.0,
) -> void:
	mesh.clear_surfaces()
	if edges.size() < 2 or thickness <= 0.0:
		return
	# Two-pass so we don't surface_begin a doomed-empty surface (Godot complains
	# loudly if surface_end is called with zero vertices). First pass collects
	# all quad verts in a local buffer; second pass replays them through
	# surface_add_vertex once we know there's something to emit.
	var buf := PackedVector3Array()
	var n: int = edges.size()
	var i: int = 0
	while i + 1 < n:
		var i0: int = edges[i]
		var i1: int = edges[i + 1]
		if i0 >= 0 and i1 >= 0 and i0 < vertices.size() and i1 < vertices.size():
			var a: Vector3 = vertices[i0]
			var b: Vector3 = vertices[i1]
			# Per-edge thickness so distant ribbons get fatter to stay visible
			# at chase-cam scale (islands at 540m). max(1.0, ...) clamps so
			# near edges keep their authored width — only far ones bloom.
			var half_t: float = thickness * 0.5
			if reference_distance > 0.0:
				var mid: Vector3 = (a + b) * 0.5
				var dist: float = mid.distance_to(camera_pos)
				var factor: float = maxf(1.0, dist / reference_distance)
				half_t = thickness * 0.5 * factor
			_append_quad(buf, a, b, camera_pos, half_t)
		i += 2
	if buf.is_empty():
		return
	# Pass material only if non-null. Surface materials can be overridden by the
	# MeshInstance3D.material_override; passing null lets that path take over
	# cleanly and avoids a "no material set" runtime warning.
	if material != null:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	else:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in buf:
		mesh.surface_add_vertex(v)
	mesh.surface_end()


# Appends a single view-aligned quad's six vertices (two triangles) into buf.
# Vertices offset by ±half_t perpendicular to both the line direction and the
# view direction. Skipped if the line is degenerate or collinear with the
# view (perp becomes the zero vector).
static func _append_quad(
	buf: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	camera_pos: Vector3,
	half_t: float,
) -> void:
	var line_dir: Vector3 = b - a
	var line_len: float = line_dir.length()
	if line_len <= 1e-5:
		return
	line_dir /= line_len
	# Use the midpoint→camera vector for the view direction. Per-segment
	# (rather than per-mesh) so very long meshes still face correctly.
	var mid: Vector3 = (a + b) * 0.5
	var view_dir: Vector3 = (camera_pos - mid)
	var view_len: float = view_dir.length()
	if view_len <= 1e-5:
		return
	view_dir /= view_len
	# Perpendicular to both line and view. When the edge is collinear with the
	# view direction (e.g. a port's outer sea-level ring viewed end-on from a
	# chase camera), the cross product collapses to zero.
	#
	# Round-4 fell back to UP × line — but for a HORIZONTAL line pointing toward
	# the camera that produces a HORIZONTAL perpendicular, so the resulting
	# quad lies in the horizontal plane and goes edge-on (invisible) from a
	# horizontal chase-cam viewpoint. Was the cause of "island outer-ring base
	# still vanishes at horizon" after round-4.
	#
	# Round-5: project world-UP onto the plane perpendicular to the line. For
	# a horizontal line this yields world-up itself (VERTICAL perpendicular,
	# vertical quad — visible from horizontal viewpoints). For a vertical line
	# this collapses to zero, so we drop through to a world-right projection
	# as the final last-resort.
	var perp: Vector3 = view_dir.cross(line_dir)
	var perp_len: float = perp.length()
	if perp_len > 1e-5:
		perp = (perp / perp_len) * half_t
	else:
		var up := Vector3.UP
		var perp_in_plane: Vector3 = up - line_dir * up.dot(line_dir)
		if perp_in_plane.length_squared() < 1e-10:
			# Line itself is vertical — project world-right instead.
			var right := Vector3.RIGHT
			perp_in_plane = right - line_dir * right.dot(line_dir)
		perp = perp_in_plane.normalized() * half_t

	# Two triangles forming the quad. Winding is irrelevant since we render
	# with an unshaded material (no cull_back relevance) — but we keep both
	# triangles in the same order so a future cull change doesn't surprise.
	buf.append(a + perp)
	buf.append(a - perp)
	buf.append(b + perp)
	buf.append(b + perp)
	buf.append(a - perp)
	buf.append(b - perp)
