# Regression tests for AI state-machine thresholds + fire alignment.
# Values pinned to the JS reference (main:game.test.js:209-290).
extends GutTest

const TOL := 1.0e-3
const BASE_MAX_SPEED := 5.0

var _tuning: CombatTuning


func before_each() -> void:
	_tuning = load("res://data/tuning/combat.tres") as CombatTuning


func _enemy_base() -> Dictionary:
	return {
		"x": 0.0, "y": 0.0, "z": 0.0,
		"yaw": 0.0, "speed": 0.0,
		"base_max_speed": BASE_MAX_SPEED,
		"reload_timer": 0.0,
		"rudder": 0.0,
	}


func test_patrol_when_target_far() -> void:
	# dist = 350 > 300 → patrol.
	var target := {"x": 0.0, "z": 350.0}
	var dt: float = 0.5
	var s: Dictionary = AISteering.calculate_ai_steering(_enemy_base(), target, dt, _tuning)
	assert_almost_eq(s.speed, BASE_MAX_SPEED * 0.4, TOL)
	assert_eq(s.rudder, 0.0)
	# yaw drift: 0 + 0.15 * 0.5 = 0.075.
	assert_almost_eq(s.yaw, 0.075, TOL)
	assert_eq(s.fire_side, "")


func test_chase_when_target_medium_range() -> void:
	# dist ≈ 212 > 100 and ≤ 300 → chase. target at (150, 150) → atan2(150,150)=π/4.
	var target := {"x": 150.0, "z": 150.0}
	var s: Dictionary = AISteering.calculate_ai_steering(_enemy_base(), target, 0.1, _tuning)
	assert_almost_eq(s.speed, BASE_MAX_SPEED * 0.8, TOL)
	assert_gt(s.rudder, 0.0)  # steers right toward π/4
	assert_gt(s.yaw, 0.0)
	assert_eq(s.fire_side, "")


func test_orbit_when_close() -> void:
	# dist ≈ 70.7 < 100 → orbit.
	var target := {"x": 50.0, "z": 50.0}
	var s: Dictionary = AISteering.calculate_ai_steering(_enemy_base(), target, 0.1, _tuning)
	assert_almost_eq(s.speed, BASE_MAX_SPEED * 0.7, TOL)
	assert_gt(s.rudder, 0.0)
	assert_gt(s.yaw, 0.0)


func test_fires_port_when_aligned_left() -> void:
	# Target directly to the left (relAngle ≈ -π/2) → port broadside.
	var enemy: Dictionary = _enemy_base()
	enemy.reload_timer = 0.0
	enemy.yaw = 0.0
	var target := {"x": -50.0, "z": 0.0}
	var s: Dictionary = AISteering.calculate_ai_steering(enemy, target, 0.1, _tuning)
	assert_eq(s.fire_side, "port")


func test_fires_starboard_when_aligned_right() -> void:
	var enemy: Dictionary = _enemy_base()
	enemy.reload_timer = 0.0
	enemy.yaw = 0.0
	var target := {"x": 50.0, "z": 0.0}
	var s: Dictionary = AISteering.calculate_ai_steering(enemy, target, 0.1, _tuning)
	assert_eq(s.fire_side, "starboard")


func test_does_not_fire_during_reload() -> void:
	var enemy: Dictionary = _enemy_base()
	enemy.reload_timer = 1.5
	enemy.yaw = 0.0
	var target := {"x": -50.0, "z": 0.0}
	var s: Dictionary = AISteering.calculate_ai_steering(enemy, target, 0.1, _tuning)
	assert_eq(s.fire_side, "")
