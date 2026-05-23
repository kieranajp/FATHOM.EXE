# Pins the chase camera's aim-flank invariant: when the player aims at one
# side, the camera must sit on the OPPOSITE side so the ship doesn't block
# the view of targets. Load-bearing because a future agent "fixing" the sign
# could regress the playtest issue back into existence.
#
# See scripts/systems/chase_camera.gd.compute_aim_yaw_offset.
extends GutTest


func test_starboard_fire_puts_camera_on_port() -> void:
	# Firing starboard (yaw + π/2) → camera at yaw - π/2.
	var offset := ChaseCamera.compute_aim_yaw_offset("starboard", PI / 2.0)
	assert_almost_eq(offset, -PI / 2.0, 1e-6, "Starboard fire → camera offset is -π/2 (port)")


func test_port_fire_puts_camera_on_starboard() -> void:
	# Firing port (yaw - π/2) → camera at yaw + π/2.
	var offset := ChaseCamera.compute_aim_yaw_offset("port", PI / 2.0)
	assert_almost_eq(offset, PI / 2.0, 1e-6, "Port fire → camera offset is +π/2 (starboard)")


func test_magnitude_is_preserved() -> void:
	# Tuning value flows through unchanged in absolute terms.
	assert_almost_eq(ChaseCamera.compute_aim_yaw_offset("starboard", 1.23), -1.23, 1e-6)
	assert_almost_eq(ChaseCamera.compute_aim_yaw_offset("port", 1.23), 1.23, 1e-6)


func test_unknown_side_defaults_to_positive() -> void:
	# Defensive — any non-"starboard" string falls into the positive branch.
	# Don't change this without thinking; aim_side is only ever "port" or
	# "starboard" in practice, but we shouldn't crash on a typo.
	assert_almost_eq(ChaseCamera.compute_aim_yaw_offset("", 1.0), 1.0, 1e-6)
