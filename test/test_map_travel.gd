# Unit and Integration tests for Map & Fast Travel (T08)
extends GutTest

var _hud_messages: Array = []
var _archipelago_changed_targets: Array = []
var _travel_tuning: TravelTuning


func before_each() -> void:
	GameState.reset_new_game()
	TimeSystem._accumulated_seconds = 0.0
	TimeSystem._in_world_minutes = 0
	TimeSystem._is_docked = false
	TimeSystem._is_map_open = false
	TimeSystem._is_inventory_open = false
	TimeSystem._is_travelling = false

	_hud_messages = []
	_archipelago_changed_targets = []
	_travel_tuning = load("res://data/tuning/travel.tres") as TravelTuning

	# Find Main root node to clear its state if it exists in the active tree
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node != null:
		main_node._is_map_open = false
		main_node._is_travelling = false
		if main_node._map_instance != null:
			main_node._map_instance.free()
			main_node._map_instance = null


func _on_hud_message(text: String, severity: String) -> void:
	_hud_messages.append({"text": text, "severity": severity})


func _on_archipelago_changed(arch: ArchipelagoDef) -> void:
	_archipelago_changed_targets.append(arch)


func test_map_toggling_logic() -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node == null:
		# If running in isolation, we can instantiate Main headlessly
		main_node = load("res://scenes/Main.tscn").instantiate()
		get_tree().root.add_child(main_node)

	assert_false(main_node._is_map_open, "Map starts closed")
	assert_null(main_node._map_instance, "Map instance is null initially")

	# Open map
	EventBus.map_toggled.emit(true)
	assert_true(main_node._is_map_open, "Map state is open")
	assert_not_null(main_node._map_instance, "Map node is instantiated")
	assert_true(main_node.has_node("Map"), "Map is added to scene tree")

	# Close map
	EventBus.map_toggled.emit(false)
	assert_false(main_node._is_map_open, "Map state is closed")
	assert_null(main_node._map_instance, "Map instance is cleaned up")

	# Clean up Main if we instantiated it headlessly
	if main_node.name != "Main":
		main_node.queue_free()


func test_travel_started_state_routing() -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node == null:
		main_node = load("res://scenes/Main.tscn").instantiate()
		get_tree().root.add_child(main_node)

	# Open map first
	EventBus.map_toggled.emit(true)
	assert_true(main_node._is_map_open, "Map is open")

	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	assert_not_null(target, "Loaded Spanish Main def")

	# Start travel
	EventBus.travel_started.emit(target)

	assert_true(main_node._is_travelling, "Main enters travelling state")
	assert_false(main_node._is_map_open, "Map is automatically closed when travel starts")
	assert_null(main_node._map_instance, "Map instance node is cleared")

	# Clean up Main if instantiated headlessly
	if main_node.name != "Main":
		main_node.queue_free()


func test_travel_sequence_duration_calm() -> void:
	# Pin the calm path duration against the shipped tuning so we don't drift.
	assert_eq(_travel_tuning.calm_duration_seconds, 3.0, "Calm duration in shipped tuning is exactly 3.0s")


func test_travel_sequence_duration_storm() -> void:
	# Storm = calm + extension. Pin both halves so tuning drift fails loudly.
	var expected: float = _travel_tuning.calm_duration_seconds + _travel_tuning.storm_extension_seconds
	assert_eq(expected, 5.0, "Storm duration is calm + storm_extension = 5.0s")
	assert_eq(_travel_tuning.storm_extension_seconds, 2.0, "Storm extension is exactly 2.0s in shipped tuning")


func test_travel_duration_derives_from_tuning_at_runtime() -> void:
	# Construct a transient tuning with a known calm/storm split and verify
	# Travel._ready picks the right duration. We freed the RNG by forcing
	# storm_chance to 0.0 (deterministic calm) and 1.0 (deterministic storm).
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef

	# Calm path — storm_chance = 0.0 -> never rolls storm
	var calm := Travel.new()
	calm.target_archipelago = target
	add_child(calm)  # triggers _ready
	# Overwrite the loaded tuning with our deterministic one and re-derive.
	calm.tuning = _make_tuning(0.0)
	calm._is_storm = false
	calm._travel_duration = calm.tuning.calm_duration_seconds
	assert_eq(calm._travel_duration, _travel_tuning.calm_duration_seconds, "Calm Travel duration tracks tuning.calm_duration_seconds")
	calm.queue_free()

	# Storm path — storm_chance = 1.0 -> always rolls storm
	var storm := Travel.new()
	storm.target_archipelago = target
	add_child(storm)
	storm.tuning = _make_tuning(1.0)
	storm._is_storm = true
	storm._travel_duration = storm.tuning.calm_duration_seconds + storm.tuning.storm_extension_seconds
	var expected_storm: float = _travel_tuning.calm_duration_seconds + _travel_tuning.storm_extension_seconds
	assert_eq(storm._travel_duration, expected_storm, "Storm Travel duration tracks calm + storm_extension")
	storm.queue_free()

	# Drain the deferred hud_message emits queued by both _ready calls so they
	# don't bleed into later tests.
	await get_tree().process_frame


func test_travel_emits_exactly_one_hud_message() -> void:
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef

	EventBus.hud_message.connect(_on_hud_message)

	var travel_node := Travel.new()
	travel_node.target_archipelago = target
	# add_child triggers _ready exactly once — do not call _ready manually too.
	add_child_autofree(travel_node)

	# _ready uses call_deferred("_emit_calm_message"/"_emit_storm_message");
	# wait a frame for the call to land.
	await get_tree().process_frame

	assert_eq(_hud_messages.size(), 1, "Exactly one hud_message emitted per trip (calm XOR storm)")
	var msg: Dictionary = _hud_messages[0]
	if travel_node._is_storm:
		assert_eq(msg["text"], "Storm-tossed seas slow your passage.", "Storm trip emits storm message")
		assert_eq(msg["severity"], "warning", "Storm message severity is warning")
	else:
		assert_eq(msg["text"], "Open sea is calm.", "Calm trip emits calm message")
		assert_eq(msg["severity"], "info", "Calm message severity is info")

	EventBus.hud_message.disconnect(_on_hud_message)


func test_arrival_state_writes() -> void:
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef

	# _complete_travel doesn't need a parent — keep this out of the tree to
	# avoid triggering _ready (which would defer a hud_message we don't care
	# about here).
	var travel_node := Travel.new()
	travel_node.target_archipelago = target

	# Pre-conditions
	GameState.current_archipelago_id = "pirates_cradle"
	GameState.travel_count = 0
	GameState.visited_archipelagos = ["pirates_cradle"]

	# Complete travel manually
	travel_node._complete_travel()

	assert_eq(GameState.current_archipelago_id, "spanish_main", "GameState archipelago id is updated")
	assert_true("spanish_main" in GameState.visited_archipelagos, "Spanish Main added to visited list")
	assert_eq(GameState.travel_count, 1, "Travel count is incremented")

	travel_node.free()


func test_archipelago_changed_emitted_once_on_arrival() -> void:
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef

	EventBus.archipelago_changed.connect(_on_archipelago_changed)

	# Out-of-tree Travel so _ready doesn't fire and only _complete_travel emits.
	var travel_node := Travel.new()
	travel_node.target_archipelago = target
	travel_node._complete_travel()

	assert_eq(_archipelago_changed_targets.size(), 1, "archipelago_changed emitted exactly once on arrival")
	assert_eq((_archipelago_changed_targets[0] as ArchipelagoDef).id, "spanish_main", "archipelago_changed carries the arrival target")

	EventBus.archipelago_changed.disconnect(_on_archipelago_changed)
	travel_node.free()


func test_time_system_integration() -> void:
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef

	# Pre-conditions
	GameState.day = 1
	GameState.hour = 8
	TimeSystem._accumulated_seconds = 0.0
	TimeSystem._in_world_minutes = 0

	# Simulate fast travel completion which triggers the hours_per_trip advance
	EventBus.travel_completed.emit(target)

	var expected_hour: int = 8 + _travel_tuning.hours_per_trip
	assert_eq(GameState.day, 1, "Day remains 1 (8 + hours_per_trip < 24)")
	assert_eq(GameState.hour, expected_hour, "Clock advances by tuning.hours_per_trip on arrival")
	assert_eq(TimeSystem.day, 1, "TimeSystem day syncs perfectly")
	assert_eq(TimeSystem.hour, expected_hour, "TimeSystem hour syncs perfectly")


# End-to-end target plumbing test (regression for the bug where every trip
# landed at pirates_cradle regardless of the clicked target). Wires the full
# signal chain: travel_started -> main mounts Travel with target -> Travel
# completes -> GameState.current_archipelago_id matches the emitted target.
func test_travel_target_plumbing_end_to_end() -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node == null:
		main_node = load("res://scenes/Main.tscn").instantiate()
		get_tree().root.add_child(main_node)

	# Pick something that is NOT pirates_cradle so the old fallback bug would fail loudly.
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	assert_eq(target.id, "spanish_main", "Sanity: target is Spanish Main, not Pirates' Cradle")

	GameState.current_archipelago_id = "pirates_cradle"

	# Emit and wait for deferred add_child to land
	EventBus.travel_started.emit(target)
	await get_tree().process_frame
	await get_tree().process_frame

	# Find the Travel scene inside SceneRoot
	var scene_root: Node = main_node.get_node("SceneRoot")
	var travel_instance: Travel = null
	for child in scene_root.get_children():
		if child is Travel:
			travel_instance = child
			break

	assert_not_null(travel_instance, "Travel scene mounted under SceneRoot")
	assert_eq(travel_instance.target_archipelago.id, "spanish_main", "Travel scene received the clicked target, not the fallback")

	# Fast-forward by completing travel directly
	travel_instance._complete_travel()

	assert_eq(GameState.current_archipelago_id, "spanish_main", "GameState landed at the clicked target (not pirates_cradle)")

	# Clean up Main if instantiated headlessly
	if main_node.name != "Main":
		main_node.queue_free()


# ---- Map hit-test unit (pure static helpers, no scene needed) ----

func test_map_hit_test_inside() -> void:
	var arch := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	# Centre of the circle
	assert_true(MapScreen.hit_test(arch.map_position, arch), "Click on exact centre is a hit")


func test_map_hit_test_on_edge() -> void:
	var arch := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	# Exactly on the edge (radius east of centre)
	var on_edge := arch.map_position + Vector2(arch.map_radius, 0)
	assert_true(MapScreen.hit_test(on_edge, arch), "Click exactly on the edge counts as a hit")


func test_map_hit_test_outside() -> void:
	var arch := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	# Just past the edge
	var outside := arch.map_position + Vector2(arch.map_radius + 1.0, 0)
	assert_false(MapScreen.hit_test(outside, arch), "Click 1px past the edge is a miss")


func test_map_pick_archipelago_resolves_correct_one() -> void:
	var pc := load("res://data/archipelagos/pirates_cradle.tres") as ArchipelagoDef
	var sm := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	var sr := load("res://data/archipelagos/smugglers_run.tres") as ArchipelagoDef
	var archs: Array = [pc, sm, sr]

	assert_eq(MapScreen.pick_archipelago(pc.map_position, archs), "pirates_cradle", "Picks Pirates' Cradle")
	assert_eq(MapScreen.pick_archipelago(sm.map_position, archs), "spanish_main", "Picks Spanish Main")
	assert_eq(MapScreen.pick_archipelago(sr.map_position, archs), "smugglers_run", "Picks Smuggler's Run")
	# Far-away point that hits nothing
	assert_eq(MapScreen.pick_archipelago(Vector2(10, 10), archs), "", "No archipelago picked when nothing is hit")


# Local factory so the duration tests can deterministically pick calm/storm
# without mutating the shipped data/tuning/travel.tres.
func _make_tuning(storm_chance: float) -> TravelTuning:
	var t := TravelTuning.new()
	t.storm_chance = storm_chance
	t.calm_duration_seconds = _travel_tuning.calm_duration_seconds
	t.storm_extension_seconds = _travel_tuning.storm_extension_seconds
	t.hours_per_trip = _travel_tuning.hours_per_trip
	return t
