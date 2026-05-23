# Unit tests for TimeSystem (in-world clock system, T11)
extends GutTest

var hour_emitted_count := 0
var last_emitted_day := -1
var last_emitted_hour := -1
var day_emitted_count := 0
var last_emitted_day_passed := -1


func before_each() -> void:
	GameState.reset_new_game()
	TimeSystem._accumulated_seconds = 0.0
	TimeSystem._in_world_minutes = 0
	TimeSystem._is_docked = false
	TimeSystem._is_map_open = false
	TimeSystem._is_inventory_open = false
	TimeSystem._is_travelling = false
	
	hour_emitted_count = 0
	last_emitted_day = -1
	last_emitted_hour = -1
	day_emitted_count = 0
	last_emitted_day_passed = -1


func _on_hour_passed(day: int, hour: int) -> void:
	hour_emitted_count += 1
	last_emitted_day = day
	last_emitted_hour = hour


func _on_day_passed(day: int) -> void:
	day_emitted_count += 1
	last_emitted_day_passed = day


func test_initial_state() -> void:
	assert_eq(TimeSystem.day, 1, "Game starts on Day 1")
	assert_eq(TimeSystem.hour, 8, "Game starts at Hour 8")
	assert_false(TimeSystem.is_paused, "Time starts unpaused at sea")


func test_ticking_at_sea() -> void:
	var minute_seconds: float = TimeSystem.tuning.seconds_per_in_world_minute
	
	# Tick less than a minute
	TimeSystem.tick(minute_seconds * 0.5)
	assert_eq(TimeSystem.hour, 8, "Hour should not advance yet")
	
	# Tick another half minute to make 1 minute
	TimeSystem.tick(minute_seconds * 0.5)
	assert_eq(TimeSystem.hour, 8, "Hour should still be 8 after 1 minute")
	
	# Tick a full hour (59 more minutes)
	TimeSystem.tick(minute_seconds * 59.0)
	assert_eq(TimeSystem.hour, 9, "Hour should advance to 9 after 60 in-world minutes")
	assert_eq(TimeSystem.day, 1, "Day should still be 1")


func test_pause_logic() -> void:
	var minute_seconds: float = TimeSystem.tuning.seconds_per_in_world_minute
	
	# Docking pauses
	TimeSystem._is_docked = true
	assert_true(TimeSystem.is_paused, "Time should be paused when docked")
	
	TimeSystem.tick(minute_seconds * 60.0)
	assert_eq(TimeSystem.hour, 8, "Clock should not tick while docked")
	
	# Undocking unpauses
	TimeSystem._is_docked = false
	assert_false(TimeSystem.is_paused, "Time should unpause when undocked")
	
	# Map open pauses
	TimeSystem._is_map_open = true
	assert_true(TimeSystem.is_paused, "Time should pause when map is open")
	
	# Overlapping pauses (e.g. docked + map open)
	TimeSystem._is_docked = true
	assert_true(TimeSystem.is_paused, "Time remains paused")
	
	# Closing map while still docked keeps paused
	TimeSystem._is_map_open = false
	assert_true(TimeSystem.is_paused, "Time should stay paused because player is still docked")
	
	# Undocking finally unpauses
	TimeSystem._is_docked = false
	assert_false(TimeSystem.is_paused, "Time should finally unpause")


func test_boundary_hour_transition_signals() -> void:
	var minute_seconds: float = TimeSystem.tuning.seconds_per_in_world_minute
	
	# Set up to 23:00 Day 1
	GameState.day = 1
	GameState.hour = 23
	
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.day_passed.connect(_on_day_passed)
	
	# Advance by 1 hour (60 minutes)
	TimeSystem.tick(minute_seconds * 60.0)
	
	assert_eq(TimeSystem.hour, 0, "Hour should roll to 0")
	assert_eq(TimeSystem.day, 2, "Day should increment to 2")
	
	assert_eq(hour_emitted_count, 1, "hour_passed should fire exactly once")
	assert_eq(last_emitted_day, 2, "Emitted hour_passed day should be 2")
	assert_eq(last_emitted_hour, 0, "Emitted hour_passed hour should be 0")
	
	assert_eq(day_emitted_count, 1, "day_passed should fire exactly once")
	assert_eq(last_emitted_day_passed, 2, "Emitted day_passed day should be 2")
	
	EventBus.hour_passed.disconnect(_on_hour_passed)
	EventBus.day_passed.disconnect(_on_day_passed)


func test_advance_hours_across_day_boundaries() -> void:
	GameState.day = 1
	GameState.hour = 22
	
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.day_passed.connect(_on_day_passed)
	
	# Advance by 4 hours (should cross into Day 2)
	TimeSystem.advance_hours(4)
	
	assert_eq(TimeSystem.day, 2, "Day should have advanced to 2")
	assert_eq(TimeSystem.hour, 2, "Hour should have advanced to 2")
	
	assert_eq(hour_emitted_count, 4, "hour_passed should have fired 4 times")
	assert_eq(day_emitted_count, 1, "day_passed should have fired 1 time")
	assert_eq(last_emitted_day, 2, "Last emitted hour should be on Day 2")
	assert_eq(last_emitted_hour, 2, "Last emitted hour should be Hour 2")
	
	EventBus.hour_passed.disconnect(_on_hour_passed)
	EventBus.day_passed.disconnect(_on_day_passed)
