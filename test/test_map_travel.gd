# Unit and Integration tests for Map & Fast Travel (T08)
extends GutTest

func before_each() -> void:
	GameState.reset_new_game()
	TimeSystem._accumulated_seconds = 0.0
	TimeSystem._in_world_minutes = 0
	TimeSystem._is_docked = false
	TimeSystem._is_map_open = false
	TimeSystem._is_inventory_open = false
	TimeSystem._is_travelling = false
	
	# Find Main root node to clear its state if it exists in the active tree
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node != null:
		main_node._is_map_open = false
		main_node._is_travelling = false
		if main_node._map_instance != null:
			main_node._map_instance.free()
			main_node._map_instance = null


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


func test_travel_sequence_duration_and_events() -> void:
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	Travel.active_target = target
	
	var travel_node = Travel.new()
	add_child_autofree(travel_node)
	travel_node._ready()
	
	assert_eq(travel_node.target_archipelago.id, "spanish_main", "Travel points to Spanish Main")
	
	# Duration must be 3s (calm) or 5s (storm)
	assert_true(travel_node._travel_duration == 3.0 or travel_node._travel_duration == 5.0, "Duration is properly rolled")
	assert_eq(travel_node._is_storm, travel_node._travel_duration == 5.0, "Storm correctly dictates duration")


func test_arrival_state_writes() -> void:
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	Travel.active_target = target
	
	var travel_node = Travel.new()
	add_child_autofree(travel_node)
	travel_node._ready()
	
	# Pre-conditions
	GameState.current_archipelago_id = "pirates_cradle"
	GameState.travel_count = 0
	GameState.visited_archipelagos = ["pirates_cradle"]
	
	# Complete travel manually
	travel_node._complete_travel()
	
	assert_eq(GameState.current_archipelago_id, "spanish_main", "GameState archipelago id is updated")
	assert_true("spanish_main" in GameState.visited_archipelagos, "Spanish Main added to visited list")
	assert_eq(GameState.travel_count, 1, "Travel count is incremented")


func test_time_system_integration() -> void:
	var target := load("res://data/archipelagos/spanish_main.tres") as ArchipelagoDef
	
	# Pre-conditions
	GameState.day = 1
	GameState.hour = 8
	TimeSystem._accumulated_seconds = 0.0
	TimeSystem._in_world_minutes = 0
	
	# Simulate fast travel completion which triggers the 6-hour advance
	EventBus.travel_completed.emit(target)
	
	assert_eq(GameState.day, 1, "Day remains 1 (8 + 6 = 14)")
	assert_eq(GameState.hour, 14, "Clock advances by exactly 6 hours upon fast-travel arrival")
	assert_eq(TimeSystem.day, 1, "TimeSystem day syncs perfectly")
	assert_eq(TimeSystem.hour, 14, "TimeSystem hour syncs perfectly")
