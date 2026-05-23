# Regression tests for the sailing efficiency curve. Values pinned to the JS
# reference test file (main:game.test.js:38-61) which asserts at
# `toBeCloseTo(..., 4)` precision — so 1e-3 tolerance gives us margin.
#
# If these fail, you've changed the curve's *shape*. That's an explicit retune,
# not a bug — update the test values and the curve in lockstep.
extends GutTest

const TOL := 1.0e-3


func test_in_irons_is_near_zero() -> void:
	# Head to wind: yaw == wind angle → diff = 0 → efficiency = 0.
	assert_almost_eq(SailingMath.efficiency(0.0, 0.0), 0.0, TOL)


func test_just_off_irons_is_small_but_positive() -> void:
	# JS asserts: 0 < eff(0.1, 0) < 0.05. We pin the exact linear-ramp value.
	# 0.05 * (0.1 / (PI/4)) = 0.05 * 0.127323 = 0.006366
	assert_almost_eq(SailingMath.efficiency(0.1, 0.0), 0.006366, TOL)


func test_beam_reach() -> void:
	# PI/2: middle of the reaching range → 0.05 + 0.95 * sin(PI/4) = 0.7218.
	assert_almost_eq(SailingMath.efficiency(PI / 2.0, 0.0), 0.7218, TOL)


func test_broad_reach_is_peak() -> void:
	# 3PI/4: top of reaching range → 0.05 + 0.95 * sin(PI/2) = 1.0.
	assert_almost_eq(SailingMath.efficiency(PI * 0.75, 0.0), 1.0, TOL)


func test_running_downwind() -> void:
	# PI: end of running range → 1.0 - 0.25 = 0.75.
	assert_almost_eq(SailingMath.efficiency(PI, 0.0), 0.75, TOL)


func test_symmetric_about_wind() -> void:
	# Port vs starboard tack: same efficiency for ±yaw against wind=0.
	# JS uses abs(playerYaw - windAngle), so the curve is symmetric.
	for y in [0.1, PI / 3.0, PI / 2.0, PI * 0.75, PI]:
		var pos: float = SailingMath.efficiency(y, 0.0)
		var neg: float = SailingMath.efficiency(-y, 0.0)
		assert_almost_eq(neg, pos, TOL, "expected symmetric efficiency at yaw=%f" % y)
