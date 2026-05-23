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


# Aim-side selection: must read from the camera's accumulated drag yaw (JS
# game.js:458 — `aimSide = mouse.yaw >= 0 ? starboard : port`). Previously
# read cursor X, which defaulted to 0 → "always starboard" if the player
# right-clicked without first moving the cursor.
func test_aim_side_positive_yaw_picks_starboard() -> void:
	assert_eq(PlayerShip._aim_side_from_camera_yaw(0.5), "starboard")


func test_aim_side_negative_yaw_picks_port() -> void:
	assert_eq(PlayerShip._aim_side_from_camera_yaw(-0.5), "port")


func test_aim_side_zero_yaw_picks_starboard() -> void:
	# JS uses `>= 0` — exact zero is the starboard branch. Pinned so a future
	# refactor doesn't silently swap the inequality.
	assert_eq(PlayerShip._aim_side_from_camera_yaw(0.0), "starboard")


# Aim drag yaw is negated because the chase camera sits OPPOSITE the firing
# flank — mouse-right in screen space corresponds to a leftward drag in the
# firing-flank frame. The negation lives in _compute_aim_yaw_delta so a future
# camera-side flip can flip this back atomically.
func test_aim_yaw_delta_positive_mouse_dx_gives_negative_offset() -> void:
	assert_almost_eq(PlayerShip._compute_aim_yaw_delta(1.0, 0.003), -0.003, 1e-6)


func test_aim_yaw_delta_negative_mouse_dx_gives_positive_offset() -> void:
	assert_almost_eq(PlayerShip._compute_aim_yaw_delta(-1.0, 0.003), 0.003, 1e-6)


func test_aim_yaw_delta_scales_with_rate() -> void:
	assert_almost_eq(PlayerShip._compute_aim_yaw_delta(2.0, 0.01), -0.02, 1e-6)
