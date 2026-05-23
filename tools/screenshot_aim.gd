# Aim-overlay screenshot — boots Main, publishes a synthetic aim_state into
# the World autoload to force AimOverlay to draw the trajectory + cone + ring
# + crosshair, then snaps. Used to verify the round-4 thick-line refactor
# (overlay was 1px-PRIMITIVE_LINES before — invisibly thin on 4K bloom).
#
# Usage:
#   timeout 30 godot --path . tools/ScreenshotAim.tscn
#   ls /tmp/fathom_aim.png
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const OUT_PATH := "/tmp/fathom_aim.png"


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	for _i in 30:
		await get_tree().process_frame

	var player := main.find_child("PlayerShip", true, false) as PlayerShip
	if player == null:
		push_error("No PlayerShip in scene")
		get_tree().quit()
		return
	player.set_sail_level(0.0)
	player.speed = 0.0

	# Simulate "RMB held" — PlayerShip._physics_process reads this each tick to
	# compute aim_mode. Setting the flag directly gets stomped (line 249 of
	# player_ship.gd). The internal _right_mouse_held variable is enough; the
	# class doesn't expose a setter so we set() by name.
	player.set("_right_mouse_held", true)
	player.set("aim_side", "port")  # port = camera default behind-ship view shows firing arc
	player.set("aim_yaw_offset", 0.0)
	player.set("aim_range", 100.0)
	player.set("aim_height", 8.0)
	for _i in 30:
		await get_tree().process_frame

	# Reframe the chase cam to a 3/4 above-and-behind angle so the trajectory
	# arc, reticle ring, and dashed cone are all visible in one shot. Strip the
	# script so its _process doesn't snap back to default orbit.
	var cam := main.find_child("ChaseCamera", true, false) as Camera3D
	if cam != null:
		cam.set_script(null)
		# Player at origin, facing -Z; firing port (left) means reticle at ~-X.
		cam.global_position = player.global_position + Vector3(-30.0, 40.0, 30.0)
		cam.look_at(player.global_position + Vector3(-50.0, 0.0, 0.0), Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(OUT_PATH)
	if err != OK:
		push_error("Save failed: %s" % str(err))
	else:
		print("Saved %s" % OUT_PATH)
	get_tree().quit()
