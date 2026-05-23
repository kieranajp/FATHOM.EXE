# Pins the aim-mode OR-gate. Mouse handling is integration plumbing and not
# worth a full input-fake, but the truth table for "either source activates
# aim_mode" is load-bearing — if a future edit reorders the operands to AND,
# Space-only or RMB-only aiming silently breaks.
#
# See scripts/player/player_ship.gd._compute_aim_mode.
extends GutTest


func test_neither_input_is_false() -> void:
	assert_false(PlayerShip._compute_aim_mode(false, false))


func test_right_mouse_only_is_true() -> void:
	assert_true(PlayerShip._compute_aim_mode(true, false))


func test_action_only_is_true() -> void:
	assert_true(PlayerShip._compute_aim_mode(false, true))


func test_both_inputs_is_true() -> void:
	assert_true(PlayerShip._compute_aim_mode(true, true))


# Aim-side selection — JS rule is "fire AWAY from camera". The camera sees the
# ship's near flank; targets visible past the hull are on the far flank, which
# is where we want the cannons to be.
#
# In Godot's right-handed frame (+X right, -Z forward) a positive
# `_drag_offset_yaw` orbits the camera to the ship's STARBOARD (camera at +X),
# so the firing flank is PORT. Negative → camera on port → fire starboard.
#
# Previously this returned the opposite mapping (and the camera was
# re-positioned to the opposite flank in aim mode); both moved in the same
# round-3 fix so the camera now stays where the user dragged it.
func test_aim_side_positive_yaw_picks_port() -> void:
	assert_eq(PlayerShip._aim_side_from_camera_yaw(0.5), "port")


func test_aim_side_negative_yaw_picks_starboard() -> void:
	assert_eq(PlayerShip._aim_side_from_camera_yaw(-0.5), "starboard")


func test_aim_side_zero_yaw_picks_port() -> void:
	# `>= 0` — exact zero falls into the port branch. Pinned so a future
	# refactor doesn't silently swap the inequality.
	assert_eq(PlayerShip._aim_side_from_camera_yaw(0.0), "port")


# Aim drag yaw — positive mouse_dx (cursor right) → positive yaw offset.
# Matches JS game.js:497. The previous negation existed to compensate for a
# round-2 camera flank-flip that has now been reverted.
func test_aim_yaw_delta_positive_mouse_dx_gives_positive_offset() -> void:
	assert_almost_eq(PlayerShip._compute_aim_yaw_delta(1.0, 0.003), 0.003, 1e-6)


func test_aim_yaw_delta_negative_mouse_dx_gives_negative_offset() -> void:
	assert_almost_eq(PlayerShip._compute_aim_yaw_delta(-1.0, 0.003), -0.003, 1e-6)


func test_aim_yaw_delta_scales_with_rate() -> void:
	assert_almost_eq(PlayerShip._compute_aim_yaw_delta(2.0, 0.01), 0.02, 1e-6)
