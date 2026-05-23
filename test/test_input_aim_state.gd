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


# Reticle world-frame invariant — positive `aim_yaw_offset` must mean "rotate
# the aim direction toward the bow" on BOTH flanks. Round 8 regression: the
# previous code applied `aim_yaw = fire_yaw + offset` uniformly, which is
# correct on starboard (fire_yaw=+π/2) but inverted on port (fire_yaw=-π/2 →
# +offset tilts toward the stern). The user-facing symptom was "mouse RIGHT
# moves the reticle the wrong way". Fixed by flipping the offset sign for port
# inside `_signed_aim_offset`; pin that here.
#
# Convention: Godot +Y up, -Z forward. yaw=0 ship faces -Z → bow direction is
# -Z, stern is +Z. Starboard at yaw=0 is +X, port is -X.

func test_reticle_starboard_positive_offset_is_forward_and_starboard() -> void:
	var r := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "starboard", PI / 6.0, 100.0, 0.0,
	)
	assert_gt(r.x, 0.0, "Starboard reticle X must be positive (starboard of ship)")
	assert_lt(r.z, 0.0, "Starboard +offset reticle Z must be negative (toward bow)")


func test_reticle_port_positive_offset_is_forward_and_port() -> void:
	var r := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "port", PI / 6.0, 100.0, 0.0,
	)
	assert_lt(r.x, 0.0, "Port reticle X must be negative (port of ship)")
	assert_lt(r.z, 0.0, "Port +offset reticle Z must be negative (toward bow)")


func test_reticle_starboard_negative_offset_is_aft() -> void:
	# Mirror invariant: negative offset = toward stern, both flanks.
	var r := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "starboard", -PI / 6.0, 100.0, 0.0,
	)
	assert_gt(r.x, 0.0, "Starboard reticle X still positive at negative offset")
	assert_gt(r.z, 0.0, "Starboard -offset reticle Z must be positive (toward stern)")


func test_reticle_port_negative_offset_is_aft() -> void:
	var r := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "port", -PI / 6.0, 100.0, 0.0,
	)
	assert_lt(r.x, 0.0, "Port reticle X still negative at negative offset")
	assert_gt(r.z, 0.0, "Port -offset reticle Z must be positive (toward stern)")


func test_reticle_zero_offset_is_pure_flank() -> void:
	# Sanity: with no offset, the reticle is straight off the respective beam.
	var rs := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "starboard", 0.0, 100.0, 0.0,
	)
	assert_almost_eq(rs.x, 100.0, 1e-4, "Starboard zero-offset = +X · range")
	assert_almost_eq(rs.z, 0.0, 1e-4, "Starboard zero-offset has no Z component")
	var rp := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "port", 0.0, 100.0, 0.0,
	)
	assert_almost_eq(rp.x, -100.0, 1e-4, "Port zero-offset = -X · range")
	assert_almost_eq(rp.z, 0.0, 1e-4, "Port zero-offset has no Z component")


# Bridges the mouse → reticle path: a positive mouse_dx must end up causing
# the reticle to move toward the bow on both flanks. This is the property the
# user-facing complaint ("mouse right moves reticle left") tests against.
func test_mouse_right_drag_moves_reticle_toward_bow_starboard() -> void:
	var rate: float = 0.003
	var delta_offset: float = PlayerShip._compute_aim_yaw_delta(1.0, rate)  # positive
	var r_before := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "starboard", 0.0, 100.0, 0.0,
	)
	var r_after := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "starboard", delta_offset, 100.0, 0.0,
	)
	assert_lt(r_after.z, r_before.z, "Mouse-right on starboard moves reticle toward bow (-Z)")


func test_mouse_right_drag_moves_reticle_toward_bow_port() -> void:
	var rate: float = 0.003
	var delta_offset: float = PlayerShip._compute_aim_yaw_delta(1.0, rate)
	var r_before := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "port", 0.0, 100.0, 0.0,
	)
	var r_after := PlayerShip._compute_reticle_world(
		Vector3.ZERO, 0.0, "port", delta_offset, 100.0, 0.0,
	)
	assert_lt(r_after.z, r_before.z, "Mouse-right on port moves reticle toward bow (-Z)")
