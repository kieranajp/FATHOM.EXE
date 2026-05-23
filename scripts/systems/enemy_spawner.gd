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
	_spawned_initial = true


func _spawn_initial_group() -> void:
	if tuning == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(
		tuning.spawn_initial_count_min, tuning.spawn_initial_count_max
	)
	for _i in count:
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(tuning.spawn_min_distance, tuning.spawn_max_distance)
		var p: Vector3 = _player.global_position + Vector3(
			sin(angle) * dist, 0.0, cos(angle) * dist,
		)
		_combat.spawn_enemy(p, "sloop", "pirate", _player, false)


func _on_archipelago_changed(_arch: ArchipelagoDef) -> void:
	_spawned_initial = false  # next _process will seed the new zone
