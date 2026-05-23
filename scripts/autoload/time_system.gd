# TimeSystem — in-world clock. Emits hour_passed / day_passed via EventBus.
# Pauses when docked, when map/inventory is open, or during fast travel.
extends Node

var day: int:
	get:
		return GameState.day
	set(value):
		GameState.day = value

var hour: int:
	get:
		return GameState.hour
	set(value):
		GameState.hour = value

var is_paused: bool:
	get:
		return _is_docked or _is_map_open or _is_inventory_open or _is_travelling

var tuning: TimeTuning
var travel_tuning: TravelTuning

var _is_docked: bool = false
var _is_map_open: bool = false
var _is_inventory_open: bool = false
var _is_travelling: bool = false

var _accumulated_seconds: float = 0.0
var _in_world_minutes: int = 0


func _ready() -> void:
	tuning = load("res://data/tuning/time.tres") as TimeTuning
	travel_tuning = load("res://data/tuning/travel.tres") as TravelTuning

	# Initialise docked state based on whether player starts in a port
	_is_docked = GameState.current_port_id != ""
	
	# Connect to EventBus signals
	EventBus.port_docked.connect(_on_port_docked)
	EventBus.port_undocked.connect(_on_port_undocked)
	EventBus.map_toggled.connect(_on_map_toggled)
	EventBus.inventory_toggled.connect(_on_inventory_toggled)
	EventBus.travel_started.connect(_on_travel_started)
	EventBus.travel_completed.connect(_on_travel_completed)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_paused:
		return
	
	if tuning == null or tuning.seconds_per_in_world_minute <= 0.0:
		return
		
	_accumulated_seconds += delta
	while _accumulated_seconds >= tuning.seconds_per_in_world_minute:
		_accumulated_seconds -= tuning.seconds_per_in_world_minute
		_in_world_minutes += 1
		if _in_world_minutes >= 60:
			_in_world_minutes = 0
			hour += 1
			if hour >= 24:
				hour = 0
				day += 1
				EventBus.hour_passed.emit(day, hour)
				EventBus.day_passed.emit(day)
			else:
				EventBus.hour_passed.emit(day, hour)


func advance_hours(n: int) -> void:
	if n <= 0:
		return
		
	# Reset accumulated sub-ticks to keep timing aligned post-advance
	_accumulated_seconds = 0.0
	_in_world_minutes = 0
	
	for i in range(n):
		hour += 1
		if hour >= 24:
			hour = 0
			day += 1
			EventBus.hour_passed.emit(day, hour)
			EventBus.day_passed.emit(day)
		else:
			EventBus.hour_passed.emit(day, hour)


func _on_port_docked(_port: PortDef) -> void:
	_is_docked = true


func _on_port_undocked() -> void:
	_is_docked = false


func _on_map_toggled(open: bool) -> void:
	_is_map_open = open


func _on_inventory_toggled(open: bool) -> void:
	_is_inventory_open = open


func _on_travel_started(_target: ArchipelagoDef) -> void:
	_is_travelling = true


func _on_travel_completed(_target: ArchipelagoDef) -> void:
	_is_travelling = false
	var hours: int = travel_tuning.hours_per_trip if travel_tuning != null else 6
	advance_hours(hours)
