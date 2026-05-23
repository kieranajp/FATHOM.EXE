# AISteering — pure state-machine for enemy AI.
#
# Three modes selected by distance-to-target:
#   PATROL  (dist > 300m): slow yaw drift, 0.4× max speed
#   CHASE   (100 < dist ≤ 300m): head toward target, 0.8× max speed
#   ORBIT   (dist ≤ 100m): perpendicular yaw, 0.7× max speed, fire when aligned
#
# Pure inputs → pure outputs. No node state, no side effects.
# Pinned to JS game.test.js:209-290 — if you change a threshold or rate, update
# the test in lockstep.
#
# Tests live at test/test_ai_steering.gd.
class_name AISteering


# Returns a Dictionary with:
#   yaw:        float (post-update heading, normalised to [0, 2π))
#   speed:      float (target speed in m/s)
#   rudder:     float (current rudder; -1..1)
#   fire_side:  String "" | "port" | "starboard"
#
# `enemy` keys: x, y, z, yaw, speed, base_max_speed, rudder, reload_timer.
# `target` keys: x, z.
static func calculate_ai_steering(
	enemy: Dictionary, target: Dictionary, dt: float, tuning: CombatTuning
) -> Dictionary:
	var dx: float = float(target.get("x", 0.0)) - float(enemy.get("x", 0.0))
	var dz: float = float(target.get("z", 0.0)) - float(enemy.get("z", 0.0))
	var dist: float = sqrt(dx * dx + dz * dz)

	var yaw: float = float(enemy.get("yaw", 0.0))
	var speed: float = float(enemy.get("speed", 0.0))
	var rudder: float = float(enemy.get("rudder", 0.0))
	var fire_side: String = ""
	var base_max: float = float(enemy.get("base_max_speed", 5.0))
	var reload_timer: float = float(enemy.get("reload_timer", 0.0))

	if dist > tuning.ai_patrol_distance:
		# Patrol — slow drift.
		yaw += tuning.ai_patrol_yaw_rate * dt
		speed = base_max * tuning.ai_patrol_speed_fraction
		rudder = 0.0
	elif dist > tuning.ai_chase_distance:
		# Chase — head toward target.
		var target_yaw: float = atan2(dx, dz)
		var yaw_diff: float = _wrap_to_pi(target_yaw - yaw)
		rudder = clampf(yaw_diff * 2.0, -1.0, 1.0)
		yaw += rudder * tuning.ai_chase_yaw_rate * dt
		speed = base_max * tuning.ai_chase_speed_fraction
	else:
		# Orbit — broadside perpendicular to bearing, fire on alignment.
		var angle_to_target: float = atan2(dx, dz)
		var orbit_yaw: float = angle_to_target + PI / 2.0
		var yaw_diff: float = _wrap_to_pi(orbit_yaw - yaw)
		rudder = clampf(yaw_diff * 2.5, -1.0, 1.0)
		yaw += rudder * tuning.ai_orbit_yaw_rate * dt
		speed = base_max * tuning.ai_orbit_speed_fraction

		# Fire if reloaded and the target lies ~±π/2 (broadside-aligned).
		# Use UPDATED yaw, matching JS reference.
		var rel_angle: float = _wrap_to_pi(angle_to_target - yaw)
		if reload_timer <= 0.0:
			if absf(rel_angle - (-PI / 2.0)) < tuning.ai_fire_angle_tolerance:
				fire_side = "port"
			elif absf(rel_angle - (PI / 2.0)) < tuning.ai_fire_angle_tolerance:
				fire_side = "starboard"

	# Normalise to [0, 2π).
	yaw = fmod(yaw, TAU)
	if yaw < 0.0:
		yaw += TAU

	return {
		"yaw": yaw,
		"speed": speed,
		"rudder": rudder,
		"fire_side": fire_side,
	}


# Wrap an angle delta to [-π, π].
static func _wrap_to_pi(a: float) -> float:
	while a < -PI:
		a += TAU
	while a > PI:
		a -= TAU
	return a
