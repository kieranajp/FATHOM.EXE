# EnemySpawner — drops pirate ships at random bearings around the player
# whenever the archipelago is (re)entered. Delegates the actual spawn to
# CombatSystem.spawn_enemy so all enemy lifecycle goes through one entry.
#
# Re-spawn on archipelago_changed (fast-travel) so each new zone seeds itself.
# T48: ambient count scales with ArchipelagoDef.risk_tier via
# CombatTuning.spawn_count_for_tier. The T39 intercept path (which uses
# World.pending_intercept_count) is explicit and unaffected by the tier.
class_name EnemySpawner extends Node

const ARCHIPELAGO_DIR := "res://data/archipelagos/"

@export var combat_path: NodePath
@export var player_path: NodePath
@export var tuning: CombatTuning

var _combat: CombatSystem
var _player: PlayerShip
var _spawned_initial: bool = false


func _ready() -> void:
	if tuning == null:
		tuning = Tunings.combat
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
	# T48 — look up the archipelago's risk_tier and ask the tuning helper for
	# the ambient spawn count. Fallback to tier 1 if the archipelago resource
	# is missing or fails to load, so we still tick ambient threat rather than
	# silently spawning zero.
	var risk_tier: int = _current_risk_tier()
	var count: int = tuning.spawn_count_for_tier(risk_tier)
	if count <= 0:
		return
	spawn_pirates_near(_player.global_position, count)


# Resolves GameState.current_archipelago_id -> ArchipelagoDef.risk_tier.
# Returns 1 (low) on any miss so an unconfigured zone fails safe to the gentlest
# difficulty curve rather than going calm or apocalyptic.
func _current_risk_tier() -> int:
	var arch_id: String = GameState.current_archipelago_id
	if arch_id == "":
		return 1
	var arch_path: String = ARCHIPELAGO_DIR + arch_id + ".tres"
	if not ResourceLoader.exists(arch_path):
		push_warning("EnemySpawner: archipelago resource missing: %s" % arch_path)
		return 1
	var arch: ArchipelagoDef = load(arch_path) as ArchipelagoDef
	if arch == null:
		return 1
	return arch.risk_tier


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


# Spawns a specific ship class at the given world position (T38 dev menu).
func spawn_at(ship_class_id: String, pos: Vector3, faction_id: String) -> EnemyShip:
	if _combat == null:
		return null
	return _combat.spawn_enemy(pos, ship_class_id, faction_id, _player, false)
