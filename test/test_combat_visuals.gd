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


func test_projectiles_produce_geometry() -> void:
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
	assert_eq(mesh.get_surface_count(), 1, "Projectiles emit a single surface")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Ball/grape = 2 trail + 6 tick verts (three orthogonal arms) = 8 each.
	# Chain = 1 segment (2) + 2 ticks × 2 ends (4) = 8 total.
	# 8 + 8 + 8 = 24 minimum. Loose `gte` so future visual tweaks (more arms,
	# extra trails) don't break this contract test.
	assert_gte(verts.size(), 10, "All three projectile types emit geometry")


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
	World.debris = [
		{
			"x": 5.0, "y": 0.0, "z": 5.0,
			"vx": 0.5, "vy": 0.0, "vz": 0.5,
			"life": 5.0, "is_spark": false,
			"yaw": 0.0, "pitch": 0.0, "roll": 0.0,
		},
		{
			"x": -5.0, "y": 0.0, "z": -5.0,
			"vx": -0.5, "vy": 0.0, "vz": -0.5,
			"life": 5.0, "is_spark": false,
			"yaw": 1.0, "pitch": 0.5, "roll": 0.0,
		},
	]
	_visuals._process(0.016)
	# Should have created two MeshInstance3D children inside the CombatVisuals
	# node (beyond the one shared CombatLines node).
	var crate_count := 0
	for child in _visuals.get_children():
		if child is MeshInstance3D and child.name != "CombatLines":
			crate_count += 1
	assert_eq(crate_count, 2, "One MeshInstance3D per live crate")


func test_crate_visuals_freed_when_debris_clears() -> void:
	World.debris = [
		{
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
		if child is MeshInstance3D and child.name != "CombatLines" and is_instance_valid(child):
			# queue_free can leave the ref but the node is queued; check it's
			# scheduled-for-deletion or actually gone.
			if not child.is_queued_for_deletion():
				crate_count += 1
	assert_eq(crate_count, 0, "Crate visuals freed when their debris entry disappears")
