# Combat — pure helpers (cylinder hit, damage, broadside spawning).
#
# All functions are static. Stateful per-frame work (projectile integration, AI
# tick, target acquisition) lives on CombatSystem (Node in OpenSea.tscn). This
# class is the JS-port surface — its functions correspond 1:1 to
# game.test.js entries, which makes the regression tests directly readable.
#
# Projectile schema (Dictionary in World.projectiles):
#   x, y, z:    position floats (separate to match JS test fixtures)
#   vx, vy, vz: velocity m/s
#   life:       seconds remaining before silent despawn
#   damage:     HP applied on hit
#   type:       "ball" | "chain" | "grape"
#   is_player_owned: bool
#   attacker:   Node ref (PlayerShip or EnemyShip); may be null in tests
class_name Combat


# Cylinder hit test. Ported from JS game.js:699 — note the `py >= sy - 1.0`
# half-metre-below leniency that gives wave troughs a forgiving floor. Issue
# spec said "0 ≤ (py - sy)"; the JS test fixture (game.test.js:99) goes -1.5
# below the target and asserts MISS, while -1.0 would be inside. The JS impl
# (not the spec wording) is the contract.
static func check_cylinder_intersection(
	px: float, py: float, pz: float,
	sx: float, sy: float, sz: float,
	hit_radius: float, hit_height: float,
) -> bool:
	var dx: float = px - sx
	var dz: float = pz - sz
	var horizontal: float = sqrt(dx * dx + dz * dz)
	if horizontal >= hit_radius:
		return false
	return py >= sy - 1.0 and py <= sy + hit_height


# Applies damage to a duck-typed ship state. Returns true if reduced to 0 HP.
#
# `ship` may be:
#   - PlayerState (Resource) — fields: health (no max_health; use ShipClass)
#   - EnemyShip (Node3D)     — fields: health, max_health
#   - Dictionary (tests)     — keys: "health", "max_health"
#
# `max_hp` is passed explicitly because PlayerState doesn't carry max_health
# (it lives on the ShipClass). This keeps the function pure and easily testable
# rather than reaching into ResourceLoader from a helper.
#
# Negative damage clamps to max_hp (per JS test game.test.js:198) — i.e. a
# negative number does NOT heal, the result is just clamped.
static func apply_ship_damage(ship: Object, damage: float, max_hp: float) -> bool:
	if ship == null:
		return false
	if max_hp <= 0.0:
		max_hp = 100.0
	var hp: float = float(ship.get("health"))
	hp = clampf(hp - damage, 0.0, max_hp)
	ship.set("health", hp)
	return hp <= 0.0


# Convenience: as above but on a Dictionary (used by tests). Keeps the
# game.test.js → test_apply_damage.gd port straight-line.
static func apply_ship_damage_dict(ship: Dictionary, damage: float) -> bool:
	if ship == null or ship.is_empty():
		return false
	var max_hp: float = float(ship.get("max_health", 100.0))
	if max_hp <= 0.0:
		max_hp = 100.0
	var hp: float = float(ship.get("health", 0.0))
	hp = clampf(hp - damage, 0.0, max_hp)
	ship["health"] = hp
	return hp <= 0.0


# Fires a broadside. Returns the count of projectiles (or pellet groups for
# grape) the loop ran, or 0 if blocked.
#
# Parameters live in a single Dictionary `state`:
#   x, y, z, yaw, speed:        float (firing platform pose)
#   hit_radius:                 float (barrel offset distance)
#   firepower:                  int   (cannons per broadside)
#   reload_port, reload_stbd:   float (seconds remaining; written on success)
#   active_ammo:                String ("ball"|"chain"|"grape"); ignored for AI
#   ammo:                       Dictionary { "ball": int, "chain": int, "grape": int }
#   is_player_owned:            bool
#   ship_class_id:              String (optional; flips AI reload timer)
#
# `state` is MUTATED in place: reload_<side> is set on success, ammo[type] is
# decremented. This mirrors the JS reference which directly mutates the
# player/enemy dict.
#
# `aim` (optional) — {active, side, yaw_offset, range, height}.
# `attacker` — Node to set as `attacker` field on each projectile (player or enemy node).
# `projectiles_out` — sink Array; each spawned projectile Dictionary is appended.
#
# Returns true if a broadside fired; false if blocked by cooldown / docked /
# no ammo / zero firepower.
static func fire_broadside(
	state: Dictionary,
	side: String,
	tuning: CombatTuning,
	projectiles_out: Array,
	attacker: Object = null,
	aim: Dictionary = {},
) -> bool:
	if state == null or state.is_empty() or tuning == null:
		return false

	var reload_field: String = "reload_port" if side == "port" else "reload_stbd"
	if float(state.get(reload_field, 0.0)) > 0.0:
		return false

	var is_player_owned: bool = bool(state.get("is_player_owned", false))
	var ammo_type: String = "ball"
	var ammo_dict: Dictionary = {}
	var ammo_available: int = 0
	if is_player_owned:
		ammo_type = String(state.get("active_ammo", "ball"))
		ammo_dict = state.get("ammo", {}) as Dictionary
		ammo_available = int(ammo_dict.get(ammo_type, 0))
		if ammo_available <= 0:
			return false

	var firepower: int = maxi(1, int(state.get("firepower", 1)))
	var count: int = mini(firepower, ammo_available) if is_player_owned else firepower

	# Cooldown — AI galleon gets a longer reload.
	var cooldown: float = tuning.reload_seconds
	if not is_player_owned:
		var enemy_class: String = String(state.get("ship_class_id", "sloop"))
		cooldown = (
			tuning.ai_galleon_reload_seconds
			if enemy_class == "galleon"
			else tuning.ai_reload_seconds
		)
	state[reload_field] = cooldown

	# Ammo decrement (player only).
	if is_player_owned:
		ammo_dict[ammo_type] = ammo_available - count
		state["ammo"] = ammo_dict

	var yaw: float = float(state.get("yaw", 0.0))
	var fire_yaw: float = yaw - PI / 2.0 if side == "port" else yaw + PI / 2.0

	var use_aim: bool = (
		is_player_owned
		and bool(aim.get("active", false))
		and String(aim.get("side", "")) == side
	)
	var target_x: float = 0.0
	var target_y: float = 0.0
	var target_z: float = 0.0
	if use_aim:
		# Per-flank sign flip on yaw_offset so positive offset means "toward the
		# bow" on both sides. PlayerShip._tick_aim_state applies the same flip
		# when computing the world-space reticle — keep the two in lockstep.
		var signed_offset: float = PlayerShip._signed_aim_offset(
			float(aim.get("yaw_offset", 0.0)), side
		)
		var aim_yaw: float = fire_yaw + signed_offset
		var aim_range: float = float(aim.get("range", tuning.aim_range_default))
		target_x = float(state.get("x", 0.0)) + sin(aim_yaw) * aim_range
		target_y = float(aim.get("height", 0.0))
		target_z = float(state.get("z", 0.0)) + cos(aim_yaw) * aim_range

	var elev_rad: float = deg_to_rad(tuning.elev_degrees)
	var muzzle: float = tuning.muzzle_velocity if is_player_owned else tuning.ai_muzzle_velocity
	var v_y_fixed: float = muzzle * sin(elev_rad)
	var v_horiz_fixed: float = muzzle * cos(elev_rad)

	var ship_x: float = float(state.get("x", 0.0))
	var ship_y: float = float(state.get("y", 0.0))
	var ship_z: float = float(state.get("z", 0.0))
	var ship_speed: float = float(state.get("speed", 0.0))
	var hit_radius: float = float(state.get("hit_radius", 3.0))

	# Resolve effective ammo type for AI (always "ball"-like).
	var effective_type: String = ammo_type if is_player_owned else "ball"

	for i in count:
		var gun_spread: float = 0.0
		if count > 1:
			gun_spread = (float(i) / float(count - 1) - 0.5) * tuning.cannon_spread

		var start_x: float = ship_x + sin(fire_yaw) * hit_radius
		var start_y: float = ship_y + 1.0
		var start_z: float = ship_z + cos(fire_yaw) * hit_radius

		if is_player_owned and ammo_type == "grape":
			for _j in tuning.grape_pellets:
				var pellet := _spawn_grape_pellet(
					start_x, start_y, start_z,
					fire_yaw, gun_spread, ship_speed, yaw,
					use_aim, target_x, target_y, target_z,
					muzzle, elev_rad, tuning,
				)
				pellet["attacker"] = attacker
				pellet["is_player_owned"] = true
				projectiles_out.append(pellet)
				EventBus.projectile_spawned.emit(pellet)
		else:
			var p := _spawn_ball_or_chain(
				start_x, start_y, start_z,
				fire_yaw, gun_spread, ship_speed, yaw,
				effective_type,
				use_aim, target_x, target_y, target_z,
				v_y_fixed, v_horiz_fixed, muzzle, tuning,
			)
			p["attacker"] = attacker
			p["is_player_owned"] = is_player_owned
			projectiles_out.append(p)
			EventBus.projectile_spawned.emit(p)

	EventBus.cannon_fired.emit(side, effective_type, attacker)
	return true


static func _spawn_ball_or_chain(
	start_x: float, start_y: float, start_z: float,
	fire_yaw: float, gun_spread: float, ship_speed: float, ship_yaw: float,
	ammo_type: String,
	use_aim: bool, target_x: float, target_y: float, target_z: float,
	v_y_fixed: float, v_horiz_fixed: float, muzzle: float,
	tuning: CombatTuning,
) -> Dictionary:
	var vx: float
	var vy: float
	var vz: float

	if use_aim:
		var dx: float = target_x - start_x
		var dz: float = target_z - start_z
		var raw_dist: float = sqrt(dx * dx + dz * dz)
		var d: float = maxf(tuning.min_aim_distance, raw_dist)
		var dir_yaw: float = atan2(dx, dz) + gun_spread
		var v_horiz: float = muzzle
		var t: float = d / muzzle
		vy = (target_y - start_y) / t + 0.5 * tuning.gravity * t
		vy = clampf(vy, tuning.vy_clamp_min, tuning.vy_clamp_max)
		vx = sin(ship_yaw) * ship_speed + sin(dir_yaw) * v_horiz
		vz = cos(ship_yaw) * ship_speed + cos(dir_yaw) * v_horiz
	else:
		var ball_yaw: float = fire_yaw + gun_spread
		vx = sin(ship_yaw) * ship_speed + sin(ball_yaw) * v_horiz_fixed
		vy = v_y_fixed
		vz = cos(ship_yaw) * ship_speed + cos(ball_yaw) * v_horiz_fixed

	var life: float
	var damage: float
	match ammo_type:
		"chain":
			life = tuning.chain_life
			damage = tuning.chain_damage
		_:
			life = tuning.ball_life
			damage = tuning.ball_damage

	return {
		"x": start_x, "y": start_y, "z": start_z,
		"vx": vx, "vy": vy, "vz": vz,
		"life": life, "damage": damage,
		"type": ammo_type,
	}


static func _spawn_grape_pellet(
	start_x: float, start_y: float, start_z: float,
	fire_yaw: float, gun_spread: float, ship_speed: float, ship_yaw: float,
	use_aim: bool, target_x: float, target_y: float, target_z: float,
	muzzle: float, elev_rad: float,
	tuning: CombatTuning,
) -> Dictionary:
	var rand_spread: float = (randf() - 0.5) * tuning.grape_spread
	var rand_vy: float = (randf() - 0.5) * tuning.grape_vy_jitter
	var speed_var: float = lerpf(tuning.grape_speed_min, tuning.grape_speed_max, randf())

	var vx: float
	var vy: float
	var vz: float

	if use_aim:
		var dx: float = target_x - start_x
		var dz: float = target_z - start_z
		var raw_dist: float = sqrt(dx * dx + dz * dz)
		var d: float = maxf(tuning.min_aim_distance, raw_dist)
		var dir_yaw: float = atan2(dx, dz) + rand_spread + gun_spread
		var v_horiz: float = muzzle * speed_var
		var t: float = d / v_horiz
		vy = (target_y - start_y) / t + 0.5 * tuning.gravity * t + rand_vy
		vy = clampf(vy, tuning.vy_clamp_min, tuning.vy_clamp_max)
		vx = sin(ship_yaw) * ship_speed + sin(dir_yaw) * v_horiz
		vz = cos(ship_yaw) * ship_speed + cos(dir_yaw) * v_horiz
	else:
		var ball_yaw: float = fire_yaw + gun_spread + rand_spread
		var v_pellet: float = muzzle * speed_var
		var v_y_pellet: float = v_pellet * sin(elev_rad) + rand_vy
		var v_horiz: float = v_pellet * cos(elev_rad)
		vx = sin(ship_yaw) * ship_speed + sin(ball_yaw) * v_horiz
		vy = v_y_pellet
		vz = cos(ship_yaw) * ship_speed + cos(ball_yaw) * v_horiz

	return {
		"x": start_x, "y": start_y, "z": start_z,
		"vx": vx, "vy": vy, "vz": vz,
		"life": tuning.grape_life, "damage": tuning.grape_damage,
		"type": "grape",
	}
