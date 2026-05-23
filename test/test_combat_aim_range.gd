# Combat.fire_broadside — aim-range physics pin.
#
# Asserts that a projectile fired at aim_range_max DOES actually reach the
# reticle before its life expires. Previously aim_range_max was 240m but with
# muzzle=28 and ball_life=4.0 the projectile despawned at t=4s having travelled
# only ~112m — visible to the player as a silent undershoot.
#
# Regression bound: integrating the projectile across its life must take the
# impact point within ±10m of the reticle's (x,z) at default aim_height.
#
# See scripts/combat/combat.gd, scripts/resources/combat_tuning.gd,
# data/tuning/combat.tres.
extends GutTest

const TOL_HORIZ: float = 10.0  # metres
var _tuning: CombatTuning


func before_each() -> void:
	_tuning = load("res://data/tuning/combat.tres") as CombatTuning


func _player_state() -> Dictionary:
	return {
		"x": 0.0, "y": 0.0, "z": 0.0,
		"yaw": 0.0, "speed": 0.0,
		"hit_radius": 3.0,
		"firepower": 1,
		"reload_port": 0.0, "reload_stbd": 0.0,
		"active_ammo": "ball",
		"ammo": {"ball": 5, "chain": 0, "grape": 0},
		"is_player_owned": true,
	}


# Integrate a projectile forward until y <= 0 (splash) or life runs out. Returns
# the (x, z) at the splash, or (NaN, NaN) if the projectile never landed.
# Step is small enough to keep error well under the ±10m tolerance.
func _integrate_until_splash(p: Dictionary) -> Vector2:
	const DT: float = 0.01
	var t: float = 0.0
	var x: float = p.x
	var y: float = p.y
	var z: float = p.z
	var vy: float = p.vy
	while t < p.life:
		x += p.vx * DT
		z += p.vz * DT
		vy -= _tuning.gravity * DT
		y += vy * DT
		if y <= 0.0:
			return Vector2(x, z)
		t += DT
	return Vector2(NAN, NAN)


func test_aim_range_max_reaches_reticle_at_default_height() -> void:
	# Fire to the starboard side at aim_range_max, default elev (height=0).
	# Reticle XZ: starboard fire_yaw at yaw=0 is +π/2 → +X direction. So the
	# reticle is at (aim_range_max, 0, 0) approximately (within hit_radius
	# barrel offset and ship_y=0).
	var state := _player_state()
	var projectiles: Array = []
	var aim := {
		"active": true,
		"side": "starboard",
		"yaw_offset": 0.0,
		"range": _tuning.aim_range_max,
		"height": 0.0,
	}
	var ok := Combat.fire_broadside(state, "starboard", _tuning, projectiles, null, aim)
	assert_true(ok, "fire_broadside should succeed with full ammo and zero cooldown")
	assert_eq(projectiles.size(), 1)

	# Reticle world position — matches PlayerShip._compute_reticle_world for
	# (yaw=0, side=starboard, yaw_offset=0).
	var reticle_x: float = sin(PI / 2.0) * _tuning.aim_range_max  # = aim_range_max
	var reticle_z: float = cos(PI / 2.0) * _tuning.aim_range_max  # = 0

	var impact := _integrate_until_splash(projectiles[0])
	assert_false(is_nan(impact.x),
		"Projectile must land within its life — got airborne despawn at aim_range_max")
	var dx: float = impact.x - reticle_x
	var dz: float = impact.y - reticle_z  # Vector2.y is the z coord here
	var horiz_err: float = sqrt(dx * dx + dz * dz)
	assert_lt(horiz_err, TOL_HORIZ,
		"Impact (%f, %f) must be within %.1fm of reticle (%f, %f) — was %.2fm" % [
			impact.x, impact.y, TOL_HORIZ, reticle_x, reticle_z, horiz_err,
		])


func test_aim_range_max_reaches_reticle_at_high_elevation() -> void:
	# Same test but at aim_height_max — the ballistic solver should also resolve
	# a vy that lands the ball at the elevated reticle within life.
	var state := _player_state()
	var projectiles: Array = []
	var aim := {
		"active": true,
		"side": "starboard",
		"yaw_offset": 0.0,
		"range": _tuning.aim_range_max,
		"height": _tuning.aim_height_max,
	}
	var ok := Combat.fire_broadside(state, "starboard", _tuning, projectiles, null, aim)
	assert_true(ok)

	# Integrate until projectile descends back below the target_y (or runs out).
	# We don't require y<=0 here because the reticle is above sea level — instead
	# integrate until life ends and check the projectile passed within tolerance
	# of the reticle XZ at SOME point.
	var p: Dictionary = projectiles[0]
	const DT: float = 0.01
	var t: float = 0.0
	var x: float = p.x
	var y: float = p.y
	var z: float = p.z
	var vy: float = p.vy
	var reticle_x: float = sin(PI / 2.0) * _tuning.aim_range_max
	var reticle_z: float = 0.0
	var min_err: float = INF
	while t < p.life:
		x += p.vx * DT
		z += p.vz * DT
		vy -= _tuning.gravity * DT
		y += vy * DT
		# Closest-approach in 3D to the reticle.
		var dx: float = x - reticle_x
		var dy: float = y - _tuning.aim_height_max
		var dz: float = z - reticle_z
		var err: float = sqrt(dx * dx + dy * dy + dz * dz)
		if err < min_err:
			min_err = err
		t += DT
	assert_lt(min_err, TOL_HORIZ,
		"Closest approach to elevated reticle (%.2fm) must be within %.1fm" % [min_err, TOL_HORIZ])
