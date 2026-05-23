# Regression tests for the compass-dial widget's needle-direction projection.
#
# The HUD computes wind-needle rotation as `yaw - wind_angle` (see
# hud.gd::wind_needle_rotation, pinned by test_hud_wind_needle). The compass
# dial widget then projects that angle into Control-frame screen coordinates.
#
# These tests pin the projection: angle 0 must point UP (toward N on the dial),
# angle +PI/2 must point RIGHT (E), angle -PI/2 must point LEFT (W).
extends GutTest

const CompassDial := preload("res://scripts/ui/compass_dial.gd")
const TOL := 1e-5


func _vec_almost_eq(a: Vector2, b: Vector2) -> void:
	assert_almost_eq(a.x, b.x, TOL, "x mismatch (got %s expected %s)" % [str(a), str(b)])
	assert_almost_eq(a.y, b.y, TOL, "y mismatch (got %s expected %s)" % [str(a), str(b)])


func test_zero_angle_points_up() -> void:
	# Control-frame -Y is up. Needle straight up = (0, -1).
	_vec_almost_eq(CompassDial.needle_direction(0.0), Vector2(0.0, -1.0))


func test_positive_quarter_turn_points_right() -> void:
	# +PI/2 (CW on screen) -> east -> (+X).
	_vec_almost_eq(CompassDial.needle_direction(PI / 2.0), Vector2(1.0, 0.0))


func test_negative_quarter_turn_points_left() -> void:
	# -PI/2 (CCW on screen) -> west -> (-X).
	_vec_almost_eq(CompassDial.needle_direction(-PI / 2.0), Vector2(-1.0, 0.0))


func test_half_turn_points_down() -> void:
	_vec_almost_eq(CompassDial.needle_direction(PI), Vector2(0.0, 1.0))


func test_unit_vector_invariant() -> void:
	# Whatever angle we throw at it, output must be unit-length.
	for a in [0.0, 0.5, 1.7, -2.3, PI * 0.75, -PI * 1.25]:
		var v := CompassDial.needle_direction(a)
		assert_almost_eq(v.length(), 1.0, TOL)
