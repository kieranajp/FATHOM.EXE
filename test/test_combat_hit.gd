# Regression test for cylinder hit detection. Values pinned to the JS
# reference (main:game.test.js:63-114).
#
# The JS impl gives a small leniency below the target (py >= sy - 1.0) so that
# wave troughs don't make a near-miss feel cheap. Don't "fix" this back to
# strict y >= sy without coordinating — it would break the parity tests.
extends GutTest


func test_direct_center_hit() -> void:
	# px==sx, py==sy, pz==sz → distance 0, py == sy → hit.
	assert_true(Combat.check_cylinder_intersection(100.0, 0.0, 100.0, 100.0, 0.0, 100.0, 5.0, 10.0))


func test_within_radius_and_height() -> void:
	# (px+3, py+5, pz+3): horizontal dist = sqrt(18) ≈ 4.24 < 5; y = 5 < 10 → hit.
	assert_true(Combat.check_cylinder_intersection(103.0, 5.0, 103.0, 100.0, 0.0, 100.0, 5.0, 10.0))


func test_outside_radius() -> void:
	# Horizontal dist = 6 > 5 → miss.
	assert_false(Combat.check_cylinder_intersection(106.0, 2.0, 100.0, 100.0, 0.0, 100.0, 5.0, 10.0))


func test_below_cylinder() -> void:
	# py = sy - 1.5 → below the -1.0 floor → miss.
	assert_false(Combat.check_cylinder_intersection(100.0, -1.5, 100.0, 100.0, 0.0, 100.0, 5.0, 10.0))


func test_above_cylinder() -> void:
	# py = sy + 10.5 > sy + hit_height (10) → miss.
	assert_false(Combat.check_cylinder_intersection(100.0, 10.5, 100.0, 100.0, 0.0, 100.0, 5.0, 10.0))


func test_leniency_floor_includes_one_below() -> void:
	# Exact -1.0 below the target is INSIDE the leniency (per JS).
	# The JS impl uses `py >= sy - 1.0`, so py = sy - 1.0 hits.
	assert_true(Combat.check_cylinder_intersection(100.0, -1.0, 100.0, 100.0, 0.0, 100.0, 5.0, 10.0))


func test_radius_boundary_is_exclusive() -> void:
	# JS impl: `dist < hit_radius`, strict less-than → exactly on the boundary misses.
	assert_false(Combat.check_cylinder_intersection(105.0, 0.0, 100.0, 100.0, 0.0, 100.0, 5.0, 10.0))
