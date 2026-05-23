# Regression tests for WindSystem's pure angle-interpolation helper, mirroring
# JS calculateNextWindAngle (main:game.test.js:291-313).
extends GutTest

const TOL := 1.0e-4


func test_smooth_interpolation_non_wrapping() -> void:
	# current=0.0, target=1.0, lerp=0.1 → next = 0.0 + (1.0 - 0.0)*0.1 = 0.1.
	# (JS value, asserted at toBeCloseTo(0.1, 4).)
	var next: float = WindSystem.calculate_next_angle(0.0, 1.0, 0.1)
	assert_almost_eq(next, 0.1, TOL)


func test_halfway_with_factor_half() -> void:
	# Factor 0.5 with a non-wrapping diff goes exactly halfway.
	var next: float = WindSystem.calculate_next_angle(0.5, 1.5, 0.5)
	assert_almost_eq(next, 1.0, TOL)


func test_shortest_path_wraps_around_zero() -> void:
	# current=0.1, target=2*PI - 0.1 (≈6.183).
	# Naive diff is +6.083; shortest path is -0.2 (counter-clockwise).
	# With factor 0.5, expect 0.1 + (-0.2)*0.5 = 0.0.
	# (JS value, asserted at toBeCloseTo(0.0, 4).)
	var next: float = WindSystem.calculate_next_angle(0.1, TAU - 0.1, 0.5)
	assert_almost_eq(next, 0.0, TOL)


func test_result_stays_in_zero_to_tau() -> void:
	# Crossing the boundary in the other direction. current=2π - 0.1,
	# target=0.1, lerp=0.5 → diff = +0.2, next = 2π - 0.1 + 0.1 = 2π → wraps to 0.
	var next: float = WindSystem.calculate_next_angle(TAU - 0.1, 0.1, 0.5)
	assert_true(next >= 0.0 and next < TAU, "expected [0, TAU), got %f" % next)
	# And specifically, near 0.
	assert_almost_eq(next, 0.0, TOL)
