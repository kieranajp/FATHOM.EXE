# CombatSystem — per-tick driver for projectiles, AI, hit detection, target lock,
# enforcer response. Sibling node under OpenSea.
#
# Owns no state of its own beyond cached references. All gameplay state lives
# on World (projectiles/enemies/splashes/debris/active_target) and on the
# EnemyShip nodes. This keeps the source-of-truth rule honest — CombatSystem is
# a function, not a god object.
#
# Pure helpers (Combat.fire_broadside, AISteering.calculate_ai_steering,
# Combat.check_cylinder_intersection, Combat.apply_ship_damage) handle the
# numbers — CombatSystem is the glue.
class_name CombatSystem extends Node

@export var tuning: CombatTuning
@export var visuals_tuning: CombatVisualsTuning
@export var player_path: NodePath
@export var ocean_path: NodePath
@export var enemies_root_path: NodePath  # Node3D parent for spawned enemies; falls back to OpenSea root

var _player: PlayerShip
var _ocean: Ocean
var _enemies_root: Node3D
var _ports_root: Node


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/combat.tres") as CombatTuning
	if visuals_tuning == null:
		visuals_tuning = load("res://data/tuning/combat_visuals.tres") as CombatVisualsTuning

	if player_path != NodePath(""):
		_player = get_node_or_null(player_path) as PlayerShip
	if ocean_path != NodePath(""):
		_ocean = get_node_or_null(ocean_path) as Ocean
	if enemies_root_path != NodePath(""):
		_enemies_root = get_node_or_null(enemies_root_path) as Node3D
	# Fallback: use our parent (OpenSea) as the enemy parent — keeps the scene
	# tidy without requiring a dedicated child node.
	if _enemies_root == null:
		_enemies_root = get_parent() as Node3D

	# Clear stale state from previous scenes.
	World.projectiles.clear()
	World.splashes.clear()
	World.debris.clear()
	World.active_target = null
	World.enforcer_alert_active = false
	World.enforcer = null

	# Wire ocean ref into already-spawned enemies (if any pre-exist for tests).
	for e in World.enemies:
		if e is EnemyShip:
			(e as EnemyShip).wire_ocean(_ocean)

	# Clear enemies on archipelago change (fast-travel).
	EventBus.archipelago_changed.connect(_on_archipelago_changed)


func _process(delta: float) -> void:
	if _player == null or _ocean == null or tuning == null:
		return
	# Pause combat sim while docked (per issue: keep enemies, freeze AI).
	if GameState.current_port_id != "":
		return

	_tick_projectiles(delta)
	_tick_splashes(delta)
	_tick_debris(delta)
	_tick_enemies(delta)
	_tick_target_acquisition()
	_tick_reload_timers(delta)


# --- Player-side reload countdown. ---
#
# CombatSystem owns the player's reload state too (PlayerShip exposes the
# fields, but the countdown is a combat concern, not a sailing concern). This
# keeps player and AI reload logic in one place.
func _tick_reload_timers(delta: float) -> void:
	if _player.reload_port > 0.0:
		_player.reload_port = maxf(0.0, _player.reload_port - delta)
	if _player.reload_stbd > 0.0:
		_player.reload_stbd = maxf(0.0, _player.reload_stbd - delta)


# --- Projectile integration + hit detection. ---
func _tick_projectiles(delta: float) -> void:
	var keep: Array = []
	for p in World.projectiles:
		p.x += p.vx * delta
		p.z += p.vz * delta
		p.vy -= tuning.gravity * delta
		p.y += p.vy * delta
		p.life -= delta

		# Splash.
		var wave_y: float = _ocean.get_wave_height(p.x, p.z)
		if p.y <= wave_y:
			_spawn_splash(p.x, p.z)
			EventBus.projectile_splashed.emit(p.x, p.z)
			continue

		# Hit check.
		if p.is_player_owned:
			if _check_hits_against_enemies(p):
				continue
		else:
			if _check_hits_against_player(p):
				continue

		if p.life > 0.0:
			keep.append(p)
	World.projectiles = keep


func _check_hits_against_enemies(p: Dictionary) -> bool:
	for e in World.enemies:
		if e == null or not is_instance_valid(e):
			continue
		if not (e is EnemyShip):
			continue
		var enemy := e as EnemyShip
		if enemy.health <= 0.0 or enemy.is_sinking:
			continue
		var hr: float = enemy.ship_class.hit_radius if enemy.ship_class != null else 4.0
		var hh: float = enemy.ship_class.hit_height if enemy.ship_class != null else 6.0
		if Combat.check_cylinder_intersection(
			p.x, p.y, p.z,
			enemy.global_position.x, enemy.global_position.y, enemy.global_position.z,
			hr, hh,
		):
			var dmg: float = float(p.get("damage", tuning.ball_damage))
			var ammo_type: String = String(p.get("type", "ball"))
			var attacker: Node = p.get("attacker", null) as Node
			var sunk: bool = Combat.apply_ship_damage(enemy, dmg, enemy.max_health)
			EventBus.ship_damaged.emit(enemy, dmg, ammo_type)
			EventBus.projectile_hit.emit(enemy, dmg, ammo_type, attacker)
			_spawn_debris(enemy.global_position.x, enemy.global_position.y + 2.0, enemy.global_position.z)
			if ammo_type == "chain":
				enemy.speed_debuff_timer = tuning.chain_debuff_seconds
			if sunk:
				_begin_sink(enemy, attacker)
				EventBus.hud_message.emit("ENEMY DOWN", "info")
			return true
	return false


func _check_hits_against_player(p: Dictionary) -> bool:
	if _player == null or _player.ship_class == null:
		return false
	var hr: float = _player.ship_class.hit_radius
	var hh: float = _player.ship_class.hit_height
	var pp: Vector3 = _player.global_position
	if not Combat.check_cylinder_intersection(p.x, p.y, p.z, pp.x, pp.y, pp.z, hr, hh):
		return false
	var dmg: float = float(p.get("damage", tuning.ball_damage))
	var ammo_type: String = String(p.get("type", "ball"))
	var attacker: Node = p.get("attacker", null) as Node
	# Player damage lives on GameState.ship.health. Apply with the ship class
	# max as the cap, mirroring how apply_ship_damage clamps for enemies.
	var max_hp: float = _player.ship_class.max_health
	GameState.ship.health = clampf(GameState.ship.health - dmg, 0.0, max_hp)
	var sunk: bool = GameState.ship.health <= 0.0
	EventBus.ship_damaged.emit(_player, dmg, ammo_type)
	EventBus.projectile_hit.emit(_player, dmg, ammo_type, attacker)
	_spawn_debris(pp.x, pp.y + 1.5, pp.z)
	if ammo_type == "chain":
		_player.speed_debuff_timer = tuning.chain_debuff_seconds
		EventBus.hud_message.emit("RIGGING DAMAGED — SAILS SHREDDED", "warning")
	# BRACE FOR IMPACT alert — only on non-fatal hits; T37 owns the sunk message.
	if not sunk:
		EventBus.hud_message.emit("BRACE FOR IMPACT (-%d HP)" % int(roundf(dmg)), "alert")
	if sunk:
		EventBus.ship_sunk.emit(_player, attacker)
		EventBus.player_death.emit()
	return true


# --- Splash + debris (one-line wrappers; FX is its own ticket). ---
func _spawn_splash(x: float, z: float) -> void:
	var max_r: float = tuning.splash_max_radius_base + randf() * tuning.splash_max_radius_jitter
	World.splashes.append({
		"x": x, "z": z, "r": 0.2, "max_r": max_r, "life": tuning.splash_life,
	})


func _spawn_debris(x: float, y: float, z: float) -> void:
	for _i in tuning.debris_count_on_hit:
		World.debris.append({
			"x": x, "y": y, "z": z,
			"vx": (randf() - 0.5) * 4.0,
			"vy": 1.0 + randf() * 3.0,
			"vz": (randf() - 0.5) * 4.0,
			"life": 1.5 + randf() * 0.5,
			"yaw": randf() * TAU,
			"pitch": 0.0, "roll": 0.0,
			"rot_speed_yaw": (randf() - 0.5) * 4.0,
			"rot_speed_pitch": (randf() - 0.5) * 4.0,
			"rot_speed_roll": (randf() - 0.5) * 4.0,
			"is_spark": true,
		})


func _tick_splashes(delta: float) -> void:
	var keep: Array = []
	for s in World.splashes:
		s.life -= delta
		s.r += (s.max_r - s.r) * 5.0 * delta
		if s.life > 0.0:
			keep.append(s)
	World.splashes = keep


func _tick_debris(delta: float) -> void:
	var keep: Array = []
	for d in World.debris:
		d.life -= delta
		if bool(d.get("is_spark", false)):
			d.x += d.vx * delta
			d.y += d.vy * delta
			d.z += d.vz * delta
			d.vy -= tuning.gravity * delta
		if d.life > 0.0:
			keep.append(d)
	World.debris = keep


# --- Enemy tick: AI steering + fire + waves + sinking + cull. ---
func _tick_enemies(delta: float) -> void:
	var keep: Array = []
	for e in World.enemies:
		if e == null or not is_instance_valid(e):
			continue
		if not (e is EnemyShip):
			continue
		var enemy := e as EnemyShip

		if enemy.is_sinking or enemy.health <= 0.0:
			# Sink animation. Rotate pitch+roll, descend.
			enemy.pitch = lerpf(enemy.pitch, PI / 6.0, 1.0 - exp(-1.0 * delta))
			enemy.roll = lerpf(enemy.roll, PI / 4.0, 1.0 - exp(-1.0 * delta))
			enemy.global_position.y -= tuning.sink_descent_rate * delta
			enemy.apply_transform()
			if enemy.global_position.y > tuning.sink_despawn_y:
				keep.append(enemy)
			else:
				# Final removal. ship_sunk already emitted at _begin_sink.
				enemy.queue_free()
			continue

		# Decrement reload + debuff timers (independent of who fired last).
		if enemy.reload_timer > 0.0:
			enemy.reload_timer = maxf(0.0, enemy.reload_timer - delta)
			enemy.reload_port = enemy.reload_timer
			enemy.reload_stbd = enemy.reload_timer
		if enemy.speed_debuff_timer > 0.0:
			enemy.speed_debuff_timer = maxf(0.0, enemy.speed_debuff_timer - delta)

		# Default target = player. Enforcers carry their own .target.
		var target_node: Node3D = enemy.target as Node3D
		if target_node == null or not is_instance_valid(target_node):
			target_node = _player
		if target_node == null:
			# No target at all (headless boot before player wired) — skip AI tick.
			keep.append(enemy)
			continue

		var enemy_state := enemy.as_state_dict()
		var target_state := {
			"x": target_node.global_position.x,
			"z": target_node.global_position.z,
		}
		var steer := AISteering.calculate_ai_steering(enemy_state, target_state, delta, tuning)
		enemy.yaw = float(steer.get("yaw", enemy.yaw))
		enemy.speed = float(steer.get("speed", enemy.speed))
		if enemy.speed_debuff_timer > 0.0:
			enemy.speed *= tuning.ai_chain_debuff_speed_mult
		enemy.rudder = float(steer.get("rudder", enemy.rudder))

		var fire_side: String = String(steer.get("fire_side", ""))
		if fire_side != "":
			# Build a fresh state dict for the firing call — it will write back
			# reload_<side>, which we then mirror back onto the enemy.
			var fire_state := enemy.as_state_dict()
			Combat.fire_broadside(
				fire_state, fire_side, tuning, World.projectiles, enemy, {},
			)
			enemy.apply_state_dict(fire_state)

		# Advance position.
		enemy.global_position.x += sin(enemy.yaw) * enemy.speed * delta
		enemy.global_position.z += cos(enemy.yaw) * enemy.speed * delta
		enemy.global_position.y = _ocean.get_wave_height(enemy.global_position.x, enemy.global_position.z)

		# Slope pitch + turn roll.
		var ahead_y: float = _ocean.get_wave_height(
			enemy.global_position.x + sin(enemy.yaw) * 1.5,
			enemy.global_position.z + cos(enemy.yaw) * 1.5,
		)
		var behind_y: float = _ocean.get_wave_height(
			enemy.global_position.x - sin(enemy.yaw) * 1.5,
			enemy.global_position.z - cos(enemy.yaw) * 1.5,
		)
		enemy.pitch = (ahead_y - behind_y) / 3.0
		enemy.roll = -enemy.rudder * enemy.speed * 0.05
		enemy.apply_transform()

		keep.append(enemy)
	World.enemies = keep

	# Authority alert ends when no live enforcer remains.
	if World.enforcer_alert_active:
		var any_alive := false
		for e in World.enemies:
			if e == null or not is_instance_valid(e):
				continue
			if e is EnemyShip and (e as EnemyShip).is_enforcer and (e as EnemyShip).health > 0.0:
				any_alive = true
				break
		if not any_alive:
			World.enforcer_alert_active = false
			World.enforcer = null
			EventBus.enforcer_alert_ended.emit()


# --- Target acquisition. ---
func _tick_target_acquisition() -> void:
	var closest: EnemyShip = null
	var min_dist: float = tuning.target_acquire_range
	var pp: Vector3 = _player.global_position
	for e in World.enemies:
		if e == null or not is_instance_valid(e):
			continue
		if not (e is EnemyShip):
			continue
		var enemy := e as EnemyShip
		if enemy.health <= 0.0 or enemy.is_sinking:
			continue
		var dx: float = enemy.global_position.x - pp.x
		var dz: float = enemy.global_position.z - pp.z
		var dist: float = sqrt(dx * dx + dz * dz)
		if dist < min_dist:
			min_dist = dist
			closest = enemy
	World.active_target = closest


# --- Sinking entry point. ---
func _begin_sink(enemy: EnemyShip, sunk_by: Node) -> void:
	if enemy.is_sinking:
		return
	enemy.is_sinking = true
	enemy.health = 0.0
	EventBus.ship_sunk.emit(enemy, sunk_by)


# --- Public API. ---
#
# Spawns an enemy at a given world position. Used by EnemySpawner and the
# authority alert response. Returns the inserted EnemyShip (or null on fail).
func spawn_enemy(
	pos: Vector3, ship_class_id: String, faction_id: String,
	target: Node = null, is_enforcer: bool = false,
) -> EnemyShip:
	if _enemies_root == null:
		return null
	var enemy := EnemyShip.new()
	enemy.ship_class_id = ship_class_id
	enemy.faction_id = faction_id
	enemy.is_enforcer = is_enforcer
	enemy.target = target if target != null else _player
	if is_enforcer:
		enemy.display_name = "PORT AUTHORITY GALLEON"
	elif faction_id == "pirate":
		enemy.display_name = "PIRATE RAIDER"
	_enemies_root.add_child(enemy)
	enemy.global_position = pos
	enemy.wire_ocean(_ocean)
	# Face the player on spawn.
	if _player != null:
		var dx: float = _player.global_position.x - pos.x
		var dz: float = _player.global_position.z - pos.z
		enemy.yaw = atan2(dx, dz)
	World.enemies.append(enemy)
	if is_enforcer:
		World.enforcer = enemy
	return enemy


# Player fire — the entry point input handlers call. Wraps Combat.fire_broadside
# with the GameState/PlayerShip state and writes results back.
func player_fire(side: String) -> bool:
	if GameState.current_port_id != "":
		return false
	if _player == null or _player.ship_class == null:
		return false

	# Build the firing state dict from PlayerShip + GameState.ship.
	var state := {
		"x": _player.global_position.x,
		"y": _player.global_position.y,
		"z": _player.global_position.z,
		"yaw": _player.yaw,
		"speed": _player.speed,
		"hit_radius": _player.ship_class.hit_radius,
		"firepower": _player.ship_class.firepower,
		"reload_port": _player.reload_port,
		"reload_stbd": _player.reload_stbd,
		"active_ammo": GameState.ship.active_ammo,
		"ammo": GameState.ship.ammo,
		"is_player_owned": true,
	}
	var aim := _build_aim_dict()
	var ok := Combat.fire_broadside(state, side, tuning, World.projectiles, _player, aim)
	if not ok:
		return false
	# Write back mutated fields.
	_player.reload_port = float(state.get("reload_port", _player.reload_port))
	_player.reload_stbd = float(state.get("reload_stbd", _player.reload_stbd))
	GameState.ship.ammo = state.get("ammo", GameState.ship.ammo) as Dictionary
	_check_no_fire_zone()
	return true


func _build_aim_dict() -> Dictionary:
	if not _player.aim_mode:
		return {}
	return {
		"active": true,
		"side": _player.aim_side,
		"yaw_offset": _player.aim_yaw_offset,
		"range": _player.aim_range,
		"height": _player.aim_height,
	}


# Emits no_fire_zone_violated if the player is within `no_fire_zone_radius` of
# any port. On first violation in the session (no active enforcer alert),
# spawns the authority galleon; if an enforcer is already active and the
# violator differs from its current target, retargets the enforcer instead of
# spawning a second one (mirrors JS alertPortAuthority).
func _check_no_fire_zone() -> void:
	var nearest_port: PortDef = null
	var nearest_dist: float = INF
	var nearest_node: Port = null
	for node in get_tree().get_nodes_in_group("port"):
		if not (node is Port):
			continue
		var port := node as Port
		if port.port_def == null:
			continue
		var d: float = _player.global_position.distance_to(port.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_port = port.port_def
			nearest_node = port
	if nearest_port == null or nearest_dist >= tuning.no_fire_zone_radius:
		return
	_handle_no_fire_zone_violation(_player, nearest_port, nearest_node)


# Shared retarget/spawn logic. Public-ish so tests can drive it directly with a
# synthetic violator without needing a port group set up; the per-tick check
# above wraps it with player+port lookup.
func _handle_no_fire_zone_violation(violator: Node, near_port: PortDef, near_port_node: Node3D) -> void:
	EventBus.no_fire_zone_violated.emit(violator, near_port)

	# An enforcer is already chasing someone — either retarget or no-op.
	if World.enforcer_alert_active and World.enforcer != null and is_instance_valid(World.enforcer):
		var enforcer := World.enforcer as EnemyShip
		if enforcer != null and not enforcer.is_sinking and enforcer.health > 0.0:
			if enforcer.target != violator:
				enforcer.target = violator
				EventBus.hud_message.emit("ENFORCER REDIRECTED", "alert")
			# Already targeting this violator: no spawn, no hud spam.
			return
		# Stale ref — fall through to spawn a fresh one.

	# Fresh spawn path: place a galleon between violator and the violated port.
	var origin: Vector3 = (violator as Node3D).global_position if violator is Node3D else _player.global_position
	var port_pos: Vector3 = near_port_node.global_position if near_port_node != null else origin
	var dx: float = port_pos.x - origin.x
	var dz: float = port_pos.z - origin.z
	var len: float = sqrt(dx * dx + dz * dz)
	if len < 0.0001:
		len = 1.0
	var spawn_pos := Vector3(
		origin.x + (dx / len) * 100.0,
		0.0,
		origin.z + (dz / len) * 100.0,
	)
	spawn_enemy(spawn_pos, "galleon", "authority", violator, true)
	World.enforcer_alert_active = true
	EventBus.enforcer_alert_started.emit()
	EventBus.hud_message.emit("PORT AUTHORITY ALERTED", "alert")


func _on_archipelago_changed(_arch: ArchipelagoDef) -> void:
	# Drop existing combat state on fast-travel.
	for e in World.enemies:
		if e == null or not is_instance_valid(e):
			continue
		if e is Node:
			(e as Node).queue_free()
	World.enemies.clear()
	World.projectiles.clear()
	World.splashes.clear()
	World.debris.clear()
	World.active_target = null
	World.enforcer_alert_active = false
	World.enforcer = null
