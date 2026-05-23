# Regression tests for the HUD wind-needle rotation.
#
# The needle visualises wind direction relative to the ship's bow on a
# Control-based dial. Two rotation conventions are in play:
#
#   - yaw / wind.angle (world frame): CCW-positive about +Y (right-hand rule).
#   - Control.rotation (screen):      CW-positive on-screen.
#
# Because the two are visually opposite, the JS-canonical formula
# `wind.angle - player.yaw` would point the needle the wrong way in Godot.
# The fix is to negate: `yaw - wind.angle`. These tests pin the sign.
#
# Compass convention (cross-reference test_hud_compass.gd):
#   yaw=0      → 0°   (N, facing -Z)
#   yaw=+PI/2  → 270° (W) — port quarter-turn
#   yaw=-PI/2  → 90°  (E) — starboard quarter-turn
#   yaw=PI     → 180° (S)
#
# Wind labels follow the same conversion: `wind.angle=+PI/2` shows "W" on the
# dial. The needle points toward the source of the wind, so "W" means the
# needle should be at the 9-o'clock position when the ship faces north — i.e.
# Control.rotation must be negative (CCW on-screen) by PI/2.
extends GutTest

const HudScript := preload("res://scripts/ui/hud.gd")
const TOL := 1e-5


func test_headwind_from_north_at_yaw_zero_is_zero_rotation() -> void:
	# Ship facing N (yaw=0), wind from due N (wind_angle=0). Needle points
	# straight up — zero rotation.
	var r := HudScript.wind_needle_rotation(0.0, 0.0)
	assert_almost_eq(r, 0.0, TOL)


func test_wind_from_port_at_yaw_zero_is_negative_rotation() -> void:
	# Ship facing N (yaw=0), wind from due W (wind_angle=+PI/2, which renders
	# as "W" via angle_to_compass_deg — see test_hud_compass). West is the port
	# side at this yaw, so the needle must point left = negative on-screen
	# rotation (Control.rotation is CW-positive, so left = CCW = negative).
	var r := HudScript.wind_needle_rotation(0.0, PI / 2.0)
	assert_almost_eq(r, -PI / 2.0, TOL)


func test_wind_from_starboard_at_yaw_zero_is_positive_rotation() -> void:
	# Symmetric to the port case: wind_angle=-PI/2 reads as "E" on the compass,
	# i.e. starboard at this yaw. Needle points right = positive rotation.
	var r := HudScript.wind_needle_rotation(0.0, -PI / 2.0)
	assert_almost_eq(r, PI / 2.0, TOL)


func test_ship_facing_east_wind_from_north_is_port_side() -> void:
	# Ship turned 90° starboard (yaw=-PI/2 → compass "E"), absolute wind from
	# the north (wind_angle=0). Wind hits the ship's port (left) side, so the
	# needle should point left of the bow = negative rotation.
	var r := HudScript.wind_needle_rotation(-PI / 2.0, 0.0)
	assert_almost_eq(r, -PI / 2.0, TOL)
