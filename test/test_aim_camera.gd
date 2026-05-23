# Aim camera contract — the chase camera DOES NOT reposition in aim mode.
# Matches JS where `final_yaw = player.yaw + mouse.yaw` runs regardless of
# aim state, i.e. the user-chosen vantage persists through RMB-press.
#
# This test pins the absence of the old "flank repositioning" behaviour.
# If a future agent re-adds a `compute_aim_yaw_offset` helper or otherwise
# branches the camera yaw on aim_mode, the assertions below will alert by
# referencing methods that should not exist.
#
# Note: the aim-side selection rule (which flank fires) lives in
# test_input_aim_state.gd alongside the rest of the player-input invariants.
extends GutTest


func test_chase_camera_has_no_aim_repositioning_helper() -> void:
	# compute_aim_yaw_offset was removed in the "camera stays put in aim mode"
	# refactor. If you find yourself wanting to re-add it, re-read the JS
	# reference (game.js: camera formula does not branch on aim mode) and the
	# round-3 PR notes before doing so.
	assert_false(
		ChaseCamera.has_method("compute_aim_yaw_offset"),
		"compute_aim_yaw_offset must not exist — aim mode does not reposition the camera"
	)


func test_camera_tuning_has_no_aim_flank_yaw_offset() -> void:
	# Field was removed alongside the repositioning logic. Pinned so a future
	# .tres edit can't re-introduce it via the editor without also explaining
	# why the camera would need to reposition again.
	var t := CameraTuning.new()
	assert_false(
		"aim_flank_yaw_offset" in t,
		"CameraTuning.aim_flank_yaw_offset must not exist — aim mode does not reposition the camera"
	)
