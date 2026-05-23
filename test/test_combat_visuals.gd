# T47 — CombatVisuals renders projectiles, splashes, sparks, crates.
#
# Doesn't assert visual fidelity (that's a manual playtest with the
# tools/ScreenshotChasecam harness). Instead asserts the contract:
#   - Populating World.projectiles/splashes/debris produces a non-empty
#     ImmediateMesh surface (i.e. geometry was emitted, the consumer ran).
#   - Crate (`is_spark: false`) entries spawn a MeshInstance3D child.
#   - An empty World leaves the mesh empty (no surfaces).
#   - Tick-and-update doesn't crash when Ocean is wired up.
extends GutTest

var _visuals: CombatVisuals
var _ocean_node: Node3D


func before_each() -> void:
	World.clear()

	# Provide a stub Ocean — CombatVisuals samples wave heights for the
	# splash ring's per-vertex Y. The real Ocean has the same name + class so
	# a real instance gives us the canonical wave formula at time=0.
	_ocean_node = Ocean.new()
	add_child_autofree(_ocean_node)
	_ocean_node.tuning = load("res://data/tuning/world.tres") as WorldTuning

	_visuals = CombatVisuals.new()
	_visuals.tuning = load("res://data/tuning/combat_visuals.tres") as CombatVisualsTuning
	# Wire ocean by direct ref (NodePath-based wiring needs both nodes in the
	# tree at the same time — easier in tests to skip that path).
	add_child_autofree(_visuals)
	_visuals.set("_ocean", _ocean_node)


func after_each() -> void:
	World.clear()


func test_empty_world_emits_no_surfaces() -> void:
	# A bare tick on an empty World should leave the mesh empty — important so
	# we don't pay the cost of an empty PRIMITIVE_LINES surface every frame.
	_visuals._process(0.016)
	var mesh: ImmediateMesh = _visuals._lines_mesh
	assert_eq(mesh.get_surface_count(), 0, "Empty World means no surfaces emitted")


func test_projectiles_alone_emit_no_lines_surface() -> void:
	# Round-10: chain moved off the PRIMITIVE_LINES surface (was a 1px hairline,
	# invisible at 4K). Round-7: ball/grape never emit a trail. So with only
	# projectiles in the world and no splashes/sparks, the lines surface is
	# empty. Geometry for all three types now lives on the heads mesh — see
	# test_chain_bola_emits_two_heads_plus_link below for the chain pin.
	World.projectiles = [
		{
			"x": 0.0, "y": 5.0, "z": 0.0,
			"vx": 10.0, "vy": 0.0, "vz": 5.0,
			"life": 2.0, "type": "ball", "is_player_owned": true,
		},
		{
			"x": 10.0, "y": 4.0, "z": 0.0,
			"vx": -5.0, "vy": -1.0, "vz": 0.0,
			"life": 1.5, "type": "chain", "is_player_owned": false,
		},
		{
			"x": 5.0, "y": 3.0, "z": 5.0,
			"vx": 1.0, "vy": -0.5, "vz": 1.0,
			"life": 0.5, "type": "grape", "is_player_owned": true,
		},
	]
	_visuals._process(0.016)
	var mesh: ImmediateMesh = _visuals._lines_mesh
	assert_eq(mesh.get_surface_count(), 0,
		"Projectiles alone don't populate the lines mesh — splashes/sparks are the only customers now")


func test_ball_and_grape_emit_solid_head_quads() -> void:
	# Round-5: each non-chain projectile spawns a camera-facing filled quad
	# in the heads mesh — 6 vertices each (two triangles). Chain shot is
	# explicitly excluded — it has its own whirling-dot rendering in lines.
	#
	# Spin up a real Camera3D so _rebuild_heads can resolve a viewport camera
	# and emit the triangle surface. Two ball/grape projectiles → 12 verts.
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.current = true
	# Let the camera become the viewport's active one this frame.
	await get_tree().process_frame

	World.projectiles = [
		{"x": 0.0, "y": 5.0, "z": 0.0, "vx": 10.0, "vy": 0.0, "vz": 5.0,
		 "life": 2.0, "type": "ball", "is_player_owned": true},
		{"x": 5.0, "y": 3.0, "z": 5.0, "vx": 1.0, "vy": -0.5, "vz": 1.0,
		 "life": 0.5, "type": "grape", "is_player_owned": true},
	]
	_visuals._process(0.016)
	var heads_mesh: ImmediateMesh = _visuals._heads_mesh
	assert_eq(heads_mesh.get_surface_count(), 1,
		"Heads mesh emits a single triangles surface for two head quads")
	var arrays := heads_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# 2 projectiles × 2 triangles × 3 verts = 12.
	assert_eq(verts.size(), 12, "Two non-chain projectiles → 12 head-quad vertices")


func test_head_quad_has_authored_world_extent() -> void:
	# Round-6 regression guard. Pins the quad's actual world-space extent rather
	# than just vertex count — catches future bugs where someone:
	#   - renames the variable to `half` and silently treats the tuning value as
	#     already-halved (round-5's near-miss),
	#   - applies a non-unit scale on the camera ancestor (basis vectors stop
	#     being unit length and the quad shrinks),
	#   - flips the cull_mode back to CULL_BACK and the head vanishes (we can't
	#     test "visible" directly, but we can pin the geometry that drives it).
	#
	# Camera placed so cam_right is roughly world-X — makes the assertion
	# tractable without trig.
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.global_position = Vector3(0.0, 5.0, 10.0)
	cam.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	cam.current = true
	await get_tree().process_frame

	_visuals.tuning.projectile_ball_size = 1.0
	World.projectiles = [
		{"x": 0.0, "y": 0.0, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0,
		 "life": 2.0, "type": "ball", "is_player_owned": true},
	]
	_visuals._process(0.016)
	var arrays := _visuals._heads_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 6, "Ball projectile emits 6 verts (2 triangles)")

	# All six verts should sit within a sphere of radius sqrt(2) * size around
	# the projectile centre — and the horizontal spread (max X minus min X)
	# must be close to 2 * projectile_ball_size = 2.0m (camera is purely along
	# +Z so cam_right ≈ world-X exactly).
	var min_x: float = INF
	var max_x: float = -INF
	for v in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
	var width: float = max_x - min_x
	assert_almost_eq(width, 2.0, 0.05,
		"Quad world width must be 2 × projectile_ball_size — catches round-5 'size pre-halved' confusion")


func test_chain_bola_link_thickness_drives_link_quad_width() -> void:
	# Independent pin on the link quad's world-space width. Camera placed so the
	# chain line (along world-X, between p1 and p2) is perpendicular to the view
	# direction (camera straight above the projectile). In that geometry the
	# link quad's perpendicular sits along world-Z and the spread between
	# +perp and -perp verts equals `chain_link_thickness`.
	#
	# This catches a future bug where someone hard-codes the link thickness
	# (e.g. accidentally reuses `projectile_head_size`) instead of reading
	# `chain_link_thickness`. Bumping the tuning value must show up in geometry.
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.global_position = Vector3(0.0, 20.0, 0.0)
	cam.look_at(Vector3(0.0, 0.0, 0.0), Vector3.FORWARD)
	cam.current = true
	await get_tree().process_frame

	_visuals.tuning.chain_link_thickness = 0.5
	_visuals.tuning.chain_visual_radius = 1.0
	# life * speed = angle. Pick life so sin(angle)=1, cos(angle)=0 — i.e. p1, p2
	# are along world-X.
	var angle: float = PI * 0.5
	var life: float = angle / _visuals.tuning.chain_visual_speed
	World.projectiles = [
		{"x": 0.0, "y": 0.0, "z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0,
		 "life": life, "type": "chain", "is_player_owned": true},
	]
	_visuals._process(0.016)
	var arrays := _visuals._heads_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Last 6 verts are the link quad. Z-spread should be chain_link_thickness.
	var min_z: float = INF
	var max_z: float = -INF
	for i in range(verts.size() - 6, verts.size()):
		min_z = minf(min_z, verts[i].z)
		max_z = maxf(max_z, verts[i].z)
	var spread: float = max_z - min_z
	assert_almost_eq(spread, 0.5, 0.02,
		"Link quad width tracks chain_link_thickness — not a hard-coded constant")


func test_chain_bola_emits_two_heads_plus_link() -> void:
	# Round-10 regression pin: chain must render as a BOLA (two filled head
	# quads + one billboarded link quad), NOT as a 1px-line hairline. If a
	# future "let's simplify" reverts to PRIMITIVE_LINES the vertex count
	# drops and this test fails loudly.
	#
	# Expected geometry on the heads (triangle) surface:
	#   2 head quads × 6 verts each = 12
	# + 1 link quad × 6 verts        =  6
	#   total                         = 18
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.global_position = Vector3(0.0, 5.0, 10.0)
	cam.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	cam.current = true
	await get_tree().process_frame

	World.projectiles = [
		{"x": 0.0, "y": 5.0, "z": 0.0, "vx": 10.0, "vy": 0.0, "vz": 0.0,
		 "life": 2.0, "type": "chain", "is_player_owned": true},
	]
	_visuals._process(0.016)
	var heads_mesh: ImmediateMesh = _visuals._heads_mesh
	assert_eq(heads_mesh.get_surface_count(), 1,
		"Chain bola lives on the heads-mesh triangle surface")
	var arrays := heads_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 18,
		"Chain bola = 2 head quads (12 verts) + 1 link quad (6 verts) = 18")

	# Chain must NOT leak back into the lines surface — its old PRIMITIVE_LINES
	# emission (a 1px hairline on a 4K display) was the round-10 bug.
	var lines_mesh: ImmediateMesh = _visuals._lines_mesh
	assert_eq(lines_mesh.get_surface_count(), 0,
		"Chain no longer emits into the lines mesh — no hairline regression")


func test_splashes_produce_ring_geometry() -> void:
	World.splashes = [
		{"x": 20.0, "z": 30.0, "r": 1.5, "max_r": 4.0, "life": 0.4},
	]
	_visuals._process(0.016)
	var mesh: ImmediateMesh = _visuals._lines_mesh
	assert_eq(mesh.get_surface_count(), 1, "Splash emits one surface")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Ring has `splash_ring_segments` line segments — 16 segments × 2 verts = 32.
	var segments: int = _visuals.tuning.splash_ring_segments
	assert_eq(verts.size(), segments * 2, "Ring vertex count == segments × 2")


func test_sparks_produce_geometry() -> void:
	World.debris = [
		{
			"x": 0.0, "y": 5.0, "z": 0.0,
			"vx": 1.0, "vy": 2.0, "vz": -1.0,
			"life": 1.0, "is_spark": true,
		},
		{
			"x": 1.0, "y": 5.0, "z": 1.0,
			"vx": -1.0, "vy": 2.0, "vz": 1.0,
			"life": 1.0, "is_spark": true,
		},
	]
	_visuals._process(0.016)
	var mesh: ImmediateMesh = _visuals._lines_mesh
	assert_eq(mesh.get_surface_count(), 1, "Sparks emit a surface")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Each spark = 2 verts; 2 sparks = 4.
	assert_eq(verts.size(), 4, "Two sparks → 4 line-vertices")


func test_crates_spawn_mesh_instances() -> void:
	# `id` mirrors what CombatSystem._next_id() stamps at spawn — it's the stable
	# key CombatVisuals._sync_crates uses. See the comment in _sync_crates: a
	# mutable dict can't be used as a hash key because Godot 4 hashes by content.
	World.debris = [
		{
			"id": 1,
			"x": 5.0, "y": 0.0, "z": 5.0,
			"vx": 0.5, "vy": 0.0, "vz": 0.5,
			"life": 5.0, "is_spark": false,
			"yaw": 0.0, "pitch": 0.0, "roll": 0.0,
		},
		{
			"id": 2,
			"x": -5.0, "y": 0.0, "z": -5.0,
			"vx": -0.5, "vy": 0.0, "vz": -0.5,
			"life": 5.0, "is_spark": false,
			"yaw": 1.0, "pitch": 0.5, "roll": 0.0,
		},
	]
	_visuals._process(0.016)
	# Should have created two MeshInstance3D children inside the CombatVisuals
	# node (beyond the shared CombatLines and CombatHeads infrastructure nodes).
	var crate_count := 0
	for child in _visuals.get_children():
		if child is MeshInstance3D and child.name != "CombatLines" and child.name != "CombatHeads":
			crate_count += 1
	assert_eq(crate_count, 2, "One MeshInstance3D per live crate")


func test_crate_visuals_freed_when_debris_clears() -> void:
	World.debris = [
		{
			"id": 42,
			"x": 0.0, "y": 0.0, "z": 0.0,
			"vx": 0.0, "vy": 0.0, "vz": 0.0,
			"life": 5.0, "is_spark": false,
			"yaw": 0.0, "pitch": 0.0, "roll": 0.0,
		},
	]
	_visuals._process(0.016)
	# Now clear and tick again — visual must clean up.
	World.debris = []
	_visuals._process(0.016)
	# queue_free is deferred; wait one frame so it actually runs.
	await get_tree().process_frame
	var crate_count := 0
	for child in _visuals.get_children():
		if (child is MeshInstance3D and child.name != "CombatLines"
				and child.name != "CombatHeads" and is_instance_valid(child)):
			# queue_free can leave the ref but the node is queued; check it's
			# scheduled-for-deletion or actually gone.
			if not child.is_queued_for_deletion():
				crate_count += 1
	assert_eq(crate_count, 0, "Crate visuals freed when their debris entry disappears")


# Regression: sinking a ship spawns crates that get mutated every tick (x, y,
# z, yaw, pitch, roll, life). When the visual pool was keyed by the debris
# dict itself, the second tick crashed with "Invalid access to property or
# key" because Godot 4 hashes Dictionaries by content. Pin that mutating
# fields across ticks does NOT desync the visual pool.
func test_crate_visuals_survive_mutation_across_ticks() -> void:
	var crate := {
		"id": 7,
		"x": 0.0, "y": 0.0, "z": 0.0,
		"vx": 0.0, "vy": 0.0, "vz": 0.0,
		"life": 5.0, "is_spark": false,
		"yaw": 0.0, "pitch": 0.0, "roll": 0.0,
	}
	World.debris = [crate]
	_visuals._process(0.016)
	# Simulate _tick_debris mutating every field that combat_system touches.
	crate.x = 12.34
	crate.y = 0.5
	crate.z = -7.0
	crate.yaw = 1.7
	crate.pitch = 0.3
	crate.roll = -0.4
	crate.life = 4.9
	# This is the call that used to crash.
	_visuals._process(0.016)
	var crate_count := 0
	for child in _visuals.get_children():
		if (child is MeshInstance3D and child.name != "CombatLines"
				and child.name != "CombatHeads" and is_instance_valid(child)):
			if not child.is_queued_for_deletion():
				crate_count += 1
	assert_eq(crate_count, 1, "Single crate survives mutation — no duplicate spawn, no crash")
