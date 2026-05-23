# Main scene root. Hosts the active scene under SceneRoot and orchestrates
# the OpenSea ↔ Port scene swap on dock/undock.
#
# Other tickets (T08 travel, T08 map) will hook here too — the signals fire
# from gameplay code, Main owns "which sub-scene is mounted".
extends Node

const OPEN_SEA := preload("res://scenes/OpenSea.tscn")
const PORT := preload("res://scenes/Port.tscn")
const MAP_SCENE := preload("res://scenes/Map.tscn")
const TRAVEL_SCENE := preload("res://scenes/Travel.tscn")

@onready var scene_root: Node = $SceneRoot

var _dock_tuning: DockTuning
var _is_map_open: bool = false
var _is_travelling: bool = false
var _map_instance: Node = null


func _ready() -> void:
	_dock_tuning = load("res://data/tuning/dock.tres") as DockTuning
	EventBus.port_docked.connect(_on_port_docked)
	EventBus.port_undocked.connect(_on_port_undocked)
	EventBus.map_toggled.connect(_on_map_toggled_signal)
	EventBus.travel_started.connect(_on_travel_started)
	EventBus.travel_completed.connect(_on_travel_completed)
	_mount(OPEN_SEA)


func _unhandled_input(event: InputEvent) -> void:
	if _is_travelling:
		return

	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("map"):
		EventBus.map_toggled.emit(not _is_map_open)


func _on_map_toggled_signal(open: bool) -> void:
	_is_map_open = open
	if open:
		if _map_instance == null:
			_map_instance = MAP_SCENE.instantiate()
			add_child(_map_instance)
	else:
		if _map_instance != null:
			_map_instance.queue_free()
			_map_instance = null


func _on_travel_started(_target: ArchipelagoDef) -> void:
	_is_travelling = true
	# Ensure map is closed when travel starts
	if _is_map_open:
		EventBus.map_toggled.emit(false)
	_mount(TRAVEL_SCENE)


func _on_travel_completed(target: ArchipelagoDef) -> void:
	_is_travelling = false
	_mount(OPEN_SEA)
	# Emit archipelago_changed so OpenSea knows to load the new archipelago's ports.
	# Defer it so the new OpenSea scene is fully mounted and ready to listen.
	EventBus.archipelago_changed.emit.call_deferred(target)


func _on_port_docked(_port: PortDef) -> void:
	_mount(PORT)


func _on_port_undocked() -> void:
	_mount(OPEN_SEA)
	# After OpenSea remounts, grant collision immunity on the new PlayerShip so
	# undocking next to a port doesn't insta-bounce. Deferred via call_deferred
	# so it runs after the scene_root.add_child.call_deferred in _mount.
	_apply_undock_immunity.call_deferred()



func _apply_undock_immunity() -> void:
	var immunity: float = _dock_tuning.undock_immunity_seconds if _dock_tuning != null else 3.0
	var ship := scene_root.find_child("PlayerShip", true, false) as PlayerShip
	if ship != null:
		ship.collision_immunity_timer = immunity


# Swap the active sub-scene. Defers the actual add so we don't free a node
# from inside its own signal callback (the dock action emits port_docked from
# inside _unhandled_input on OpenSea, and a same-frame free would tear down
# the input dispatcher mid-call).
func _mount(packed: PackedScene) -> void:
	for child in scene_root.get_children():
		child.queue_free()
	scene_root.add_child.call_deferred(packed.instantiate())
