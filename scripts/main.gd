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
const DEV_MENU_SCENE := preload("res://scenes/ui/DevMenu.tscn")
const PORT_DIR := "res://data/ports/"
const ARCHIPELAGO_DIR := "res://data/archipelagos/"

@onready var scene_root: Node = $SceneRoot

var _dock_tuning: DockTuning
var _respawn_tuning: RespawnTuning
var _is_map_open: bool = false
var _is_travelling: bool = false
var _is_dev_menu_open: bool = false
var _map_instance: Node = null
var _dev_menu_instance: Node = null


func _ready() -> void:
	_dock_tuning = Tunings.dock
	_respawn_tuning = Tunings.respawn
	# Boot path: resume a saved game if one exists, otherwise fresh start.
	# Persistence.load() applies onto GameState directly; on corruption or
	# version mismatch it emits hud_message and falls back to a new game.
	if Persistence.has_save():
		if not Persistence.load():
			GameState.reset_new_game()
	else:
		GameState.reset_new_game()
	EventBus.port_docked.connect(_on_port_docked)
	EventBus.port_undocked.connect(_on_port_undocked)
	EventBus.map_toggled.connect(_on_map_toggled_signal)
	EventBus.dev_menu_toggled.connect(_on_dev_menu_toggled_signal)
	EventBus.travel_started.connect(_on_travel_started)
	EventBus.travel_completed.connect(_on_travel_completed)
	EventBus.player_death.connect(_on_player_death)
	_mount(OPEN_SEA)


func _unhandled_input(event: InputEvent) -> void:
	if _is_travelling:
		return

	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("map"):
		EventBus.map_toggled.emit(not _is_map_open)
	elif event.is_action_pressed("dev_menu"):
		EventBus.dev_menu_toggled.emit(not _is_dev_menu_open)


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


func _on_dev_menu_toggled_signal(open: bool) -> void:
	_is_dev_menu_open = open
	if open:
		if _dev_menu_instance == null:
			_dev_menu_instance = DEV_MENU_SCENE.instantiate()
			add_child(_dev_menu_instance)
			get_tree().paused = true
	else:
		if _dev_menu_instance != null:
			_dev_menu_instance.queue_free()
			_dev_menu_instance = null
			get_tree().paused = false


func _on_travel_started(target: ArchipelagoDef) -> void:
	_is_travelling = true
	# Ensure map is closed when travel starts
	if _is_map_open:
		EventBus.map_toggled.emit(false)
	# Mount the Travel scene manually so we can hand it the clicked target.
	# Same shape as _mount but instantiates locally so we can set target_archipelago
	# before add_child / _ready runs.
	for child in scene_root.get_children():
		child.queue_free()
	var travel_instance: Travel = TRAVEL_SCENE.instantiate() as Travel
	travel_instance.target_archipelago = target
	scene_root.add_child.call_deferred(travel_instance)


func _on_travel_completed(_target: ArchipelagoDef) -> void:
	_is_travelling = false
	_mount(OPEN_SEA)
	# archipelago_changed is emitted by Travel._complete_travel (the source of
	# truth for arrival). Do not re-emit here.


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


# Player death — wipe cargo, halve gold, refill HP, teleport to nearest port
# in the current archipelago, autosave the penalty. Matches JS handlePlayerDeath
# (game.js:1399) with the gold penalty added per T37.
#
# Player position + speed/sail/yaw reset live on PlayerShip when the OpenSea
# scene is mounted; in tests / when no PlayerShip exists we still mutate
# GameState and emit the alert so the rest of the chain is observable.
func _on_player_death() -> void:
	var ship: PlayerState = GameState.ship
	if ship == null:
		return

	# Health: refill to class max. Look up the ShipClass from disk rather than
	# reaching into a PlayerShip node — we want this to work in tests too.
	var ship_class := ShipClass.load_or_default(ship.ship_class_id)
	var max_hp: float = ship_class.max_health if ship_class != null else 100.0
	ship.health = max_hp

	# Cargo wipe + gold penalty. Both via the tuning fraction (no magic 0.5).
	ship.cargo = {}
	var retention: float = (
		_respawn_tuning.gold_retention_fraction if _respawn_tuning != null else 0.5
	)
	ship.gold = int(floor(retention * float(ship.gold)))

	# Find nearest port in the current archipelago by Euclidean distance to the
	# player. Falls back gracefully if PlayerShip isn't mounted (tests / boot).
	var player := scene_root.find_child("PlayerShip", true, false) as PlayerShip
	var player_pos: Vector3 = player.global_position if player != null else Vector3.ZERO
	var nearest: PortDef = _find_nearest_port(GameState.current_archipelago_id, player_pos)

	var port_name: String = "OPEN SEA"
	if nearest != null:
		port_name = nearest.display_name
		# Teleport: position + zero speed + default sail level. Yaw/rudder reset
		# too so we don't immediately barrel out of the harbour.
		if player != null:
			player.global_position = nearest.position
			player.speed = 0.0
			player.rudder = 0.0
			player.yaw = 0.0
			player.set_sail_level(_default_sail_level())
		else:
			ship.sail_level = _default_sail_level()

	EventBus.hud_message.emit(
		"YOUR SHIP HAS SUNK — RESPAWNED AT %s" % port_name.to_upper(),
		"alert",
	)

	# Persist the penalty so reloading after death doesn't dodge it.
	Persistence.save()


func _default_sail_level() -> float:
	return _respawn_tuning.default_sail_level if _respawn_tuning != null else 2.0


# Returns the PortDef from `archipelago_id` whose world-position is closest to
# `pos`. Returns null if the archipelago has no resolvable ports (e.g. data
# missing, or `archipelago_id` empty).
func _find_nearest_port(archipelago_id: String, pos: Vector3) -> PortDef:
	if archipelago_id == "":
		return null
	var arch_path: String = ARCHIPELAGO_DIR + archipelago_id + ".tres"
	if not ResourceLoader.exists(arch_path):
		return null
	var arch: ArchipelagoDef = load(arch_path) as ArchipelagoDef
	if arch == null:
		return null

	var best: PortDef = null
	var best_d2: float = INF
	for port_id in arch.port_ids:
		var port_path: String = PORT_DIR + port_id + ".tres"
		if not ResourceLoader.exists(port_path):
			continue
		var port_def: PortDef = load(port_path) as PortDef
		if port_def == null:
			continue
		var d2: float = pos.distance_squared_to(port_def.position)
		if d2 < best_d2:
			best_d2 = d2
			best = port_def
	return best



# Swap the active sub-scene. Defers the actual add so we don't free a node
# from inside its own signal callback (the dock action emits port_docked from
# inside _unhandled_input on OpenSea, and a same-frame free would tear down
# the input dispatcher mid-call).
func _mount(packed: PackedScene) -> void:
	for child in scene_root.get_children():
		child.queue_free()
	scene_root.add_child.call_deferred(packed.instantiate())
