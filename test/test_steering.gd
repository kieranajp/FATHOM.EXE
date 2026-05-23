# Regression test for the rudder→yaw sign convention.
#
# Godot is right-handed (+Y up, -Z forward); positive yaw rotates CCW about Y
# when viewed from above, which swings the bow from -Z towards -X — that's a
# PORT (left) turn. So in Godot's frame:
#
#   positive rudder == starboard (right) turn == decreasing yaw == NEGATIVE delta
#   negative rudder == port (left) turn      == increasing yaw == POSITIVE delta
#   zero rudder                              == zero delta
#
# The JS prototype on `main` uses left-handed coords with the opposite sign;
# transliterating it reversed the steering (T02 post-merge bug). If this test
# fails, you've reintroduced that bug — re-read docs/ARCHITECTURE.md
# § "Coordinate conversions from JS reference" before "fixing" the test.
extends GutTest


func test_positive_rudder_yields_negative_yaw_delta() -> void:
	# Starboard turn: rudder=+1 must produce a clockwise (negative) yaw delta.
	var delta := PlayerShip._compute_yaw_delta(1.0, 2.0, 0.1)
	assert_lt(delta, 0.0, "positive rudder should yield negative yaw delta (starboard turn)")


func test_negative_rudder_yields_positive_yaw_delta() -> void:
	# Port turn: rudder=-1 must produce a CCW (positive) yaw delta.
	var delta := PlayerShip._compute_yaw_delta(-1.0, 2.0, 0.1)
	assert_gt(delta, 0.0, "negative rudder should yield positive yaw delta (port turn)")


func test_zero_rudder_yields_zero_delta() -> void:
	assert_eq(PlayerShip._compute_yaw_delta(0.0, 2.0, 0.1), 0.0)


func test_delta_scales_linearly_with_rudder() -> void:
	# Doubling rudder should double the delta (linear in rudder).
	var a := PlayerShip._compute_yaw_delta(0.5, 2.0, 0.1)
	var b := PlayerShip._compute_yaw_delta(1.0, 2.0, 0.1)
	assert_almost_eq(b, a * 2.0, 1.0e-6)


func test_delta_scales_linearly_with_turn_rate() -> void:
	var a := PlayerShip._compute_yaw_delta(1.0, 1.0, 0.1)
	var b := PlayerShip._compute_yaw_delta(1.0, 2.0, 0.1)
	assert_almost_eq(b, a * 2.0, 1.0e-6)


func test_delta_scales_linearly_with_time() -> void:
	var a := PlayerShip._compute_yaw_delta(1.0, 2.0, 0.05)
	var b := PlayerShip._compute_yaw_delta(1.0, 2.0, 0.10)
	assert_almost_eq(b, a * 2.0, 1.0e-6)
