# EnemySpawner — drops 1-2 pirate ships at random bearings around the player
# whenever the archipelago is (re)entered. Delegates the actual spawn to
# CombatSystem.spawn_enemy so all enemy lifecycle goes through one entry.
#
# Re-spawn on archipelago_changed (fast-travel) so each new zone seeds itself.
class_name EnemySpawner extends Node

@export var combat_path: NodePath
@export var player_path: NodePath
@export var tuning: CombatTuning

var _combat: CombatSystem
var _player: PlayerShip
var _spawned_initial: bool = false


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/combat.tres") as CombatTuning
	if combat_path != NodePath(""):
		_combat = get_node_or_null(combat_path) as CombatSystem
	if player_path != NodePath(""):
		_player = get_node_or_null(player_path) as PlayerShip

	EventBus.archipelago_changed.connect(_on_archipelago_changed)


func _process(_delta: float) -> void:
	# One-shot initial spawn once the player + combat system are wired and we
	# haven't seeded this archipelago yet. Deferred to first _process so the
	# combat system has had a tick to wire its caches.
	if _spawned_initial:
		return
	if _combat == null or _player == null:
		return
	if GameState.current_port_id != "":
		# Don't spawn while docked at start.
		return
	_spawn_initial_group()
	# T39: a pirate intercept aborts the trip and asks the spawner to drop a
	# couple of sloops on the player's lap, on top of the normal seed. The
	# flag is one-shot — consume + clear so the next mount doesn't double up.
	if World.pending_intercept_count > 0:
		spawn_pirates_near(_player.global_position, World.pending_intercept_count)
		World.pending_intercept_count = 0
	_spawned_initial = true


func _spawn_initial_group() -> void:
	if tuning == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(
		tuning.spawn_initial_count_min, tuning.spawn_initial_count_max
	)
	spawn_pirates_near(_player.global_position, count)


# Drops `count` pirate sloops at random bearings around `centre`, each at a
# tuning-driven distance. Exposed so Travel (T39 intercept) can request an
# ambush on the player's current position without reaching into combat itself.
# Returns the number actually spawned (0 if the spawner isn't wired yet).
func spawn_pirates_near(centre: Vector3, count: int) -> int:
	if tuning == null or _combat == null or _player == null:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawned: int = 0
	for _i in count:
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(tuning.spawn_min_distance, tuning.spawn_max_distance)
		var p: Vector3 = centre + Vector3(
			sin(angle) * dist, 0.0, cos(angle) * dist,
		)
		_combat.spawn_enemy(p, "sloop", "pirate", _player, false)
		spawned += 1
	return spawned


func _on_archipelago_changed(_arch: ArchipelagoDef) -> void:
	_spawned_initial = false  # next _process will seed the new zone
