# OpenSea — script attached to the OpenSea scene root. Owns:
#   - WindSystem tick (paused when docked — T08 will wire that)
#   - Spawning the active archipelago's ports
#   - Proximity detection → World.active_port + port_proximity_entered/exited
#   - Dock input → scene swap to Port.tscn
#
# Subscribed to EventBus.archipelago_changed (T08 fast-travel) — re-spawns ports.
extends Node3D

const PORT_DIR := "res://data/ports/"
const ARCHIPELAGO_DIR := "res://data/archipelagos/"

@export var tuning: DockTuning

var _proximity_accum: float = 0.0
var _ports_root: Node3D
var _player: PlayerShip


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/dock.tres") as DockTuning

	_ports_root = Node3D.new()
	_ports_root.name = "Ports"
	add_child(_ports_root)

	# Find the player node. The scene tree has it as a sibling; cache to avoid
	# re-lookup per tick.
	_player = get_node_or_null("PlayerShip") as PlayerShip

	EventBus.archipelago_changed.connect(_on_archipelago_changed)
	_spawn_current_archipelago()


func _process(delta: float) -> void:
	WindSystem.update(delta)

	# Proximity check on a fixed cadence — 4Hz is plenty and saves
	# per-frame node iteration. JS does it every frame; we can afford slack.
	if _player != null and tuning != null:
		_proximity_accum += delta
		var tick_period: float = 1.0 / tuning.proximity_tick_hz
		if _proximity_accum >= tick_period:
			_proximity_accum = 0.0
			_tick_proximity()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dock"):
		_try_dock()


func _spawn_current_archipelago() -> void:
	_clear_ports()
	var arch_id: String = GameState.current_archipelago_id
	if arch_id == "":
		return
	var arch_path: String = ARCHIPELAGO_DIR + arch_id + ".tres"
	if not ResourceLoader.exists(arch_path):
		push_warning("OpenSea: archipelago resource missing: %s" % arch_path)
		return
	var arch: ArchipelagoDef = load(arch_path) as ArchipelagoDef
	if arch == null:
		return

	for port_id in arch.port_ids:
		var port_path: String = PORT_DIR + port_id + ".tres"
		if not ResourceLoader.exists(port_path):
			push_warning("OpenSea: port resource missing: %s" % port_path)
			continue
		var port_def: PortDef = load(port_path) as PortDef
		if port_def == null:
			continue
		var port_node := Port.new()
		port_node.name = "Port_" + port_id
		port_node.port_def = port_def
		port_node.tuning = tuning
		_ports_root.add_child(port_node)


func _clear_ports() -> void:
	for child in _ports_root.get_children():
		child.queue_free()
	# Drop the proximity state; will be recomputed on next tick.
	if World.active_port != null:
		World.active_port = null
		EventBus.port_proximity_exited.emit()


func _on_archipelago_changed(_archipelago: ArchipelagoDef) -> void:
	# T08 (map / fast-travel) flips GameState.current_archipelago_id before
	# emitting. We re-read it rather than trusting the signal arg — keeps the
	# "GameState is the source of truth" rule honest.
	_spawn_current_archipelago()


func _tick_proximity() -> void:
	var player_pos: Vector3 = _player.global_position
	var threshold: float = tuning.proximity_padding

	var nearest: Port = null
	for node in _ports_root.get_children():
		if not (node is Port):
			continue
		var port := node as Port
		if port.port_def == null:
			continue
		if Port.is_in_proximity(player_pos, port.global_position, port.port_def.size, threshold):
			nearest = port
			break  # ports don't overlap; first match wins

	var previous: PortDef = World.active_port
	if nearest != null:
		if previous != nearest.port_def:
			World.active_port = nearest.port_def
			EventBus.port_proximity_entered.emit(nearest.port_def)
	else:
		if previous != null:
			World.active_port = null
			EventBus.port_proximity_exited.emit()


func _try_dock() -> void:
	var port_def: PortDef = World.active_port
	if port_def == null:
		return
	if GameState.current_port_id != "":
		return  # already docked

	GameState.current_port_id = port_def.id
	# Main listens for port_docked and swaps SceneRoot.child to Port.tscn.
	EventBus.port_docked.emit(port_def)
