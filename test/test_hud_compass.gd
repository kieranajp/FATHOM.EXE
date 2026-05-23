# Regression tests for the HUD heading conversion.
#
# Convention (see hud.gd::yaw_to_compass_deg comment):
#   yaw=0          -> 0°   N
#   yaw=-PI/2      -> 90°  E   (starboard turn: -ve yaw delta, see test_steering)
#   yaw= PI/2      -> 270° W   (port turn)
#   yaw=PI / -PI   -> 180° S
#
# 8-point compass labels are at multiples of 45°. Nearest-neighbour rounding
# means a heading of 22° (just under N->NE midpoint) labels as N, 23° as NE.
extends GutTest

const HudScript := preload("res://scripts/ui/hud.gd")


func test_yaw_zero_is_north() -> void:
	assert_eq(HudScript.yaw_to_compass_deg(0.0), 0)
	assert_eq(HudScript.compass_label(0), "N")


func test_starboard_quarter_turn_is_east() -> void:
	# -PI/2 yaw == 90° heading == east.
	assert_eq(HudScript.yaw_to_compass_deg(-PI / 2.0), 90)
	assert_eq(HudScript.compass_label(90), "E")


func test_port_quarter_turn_is_west() -> void:
	# +PI/2 yaw == 270° heading == west.
	assert_eq(HudScript.yaw_to_compass_deg(PI / 2.0), 270)
	assert_eq(HudScript.compass_label(270), "W")


func test_half_turn_is_south() -> void:
	# Both ±PI should land on 180° S.
	assert_eq(HudScript.yaw_to_compass_deg(PI), 180)
	assert_eq(HudScript.yaw_to_compass_deg(-PI), 180)
	assert_eq(HudScript.compass_label(180), "S")


func test_wraparound_above_tau() -> void:
	# A yaw two full turns east of zero should still land on N.
	# yaw = -TAU (two full CW turns) → 720° → wraps to 0°.
	# We tolerate a 1° rounding margin around the boundary.
	var d := HudScript.yaw_to_compass_deg(-TAU)
	assert_true(d == 0 or d == 360 - 1 or d == 1, "wraparound landed at %d" % d)


func test_intermediate_quadrant_labels() -> void:
	# 45° -> NE, 135° -> SE, 225° -> SW, 315° -> NW.
	assert_eq(HudScript.compass_label(45), "NE")
	assert_eq(HudScript.compass_label(135), "SE")
	assert_eq(HudScript.compass_label(225), "SW")
	assert_eq(HudScript.compass_label(315), "NW")


func test_label_nearest_neighbour_rounding() -> void:
	# 22° is closer to 0 (N) than to 45 (NE).
	assert_eq(HudScript.compass_label(22), "N")
	# 23° rounds up to NE.
	assert_eq(HudScript.compass_label(23), "NE")
