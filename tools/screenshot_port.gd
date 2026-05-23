# Port-visibility screenshot — verifies the island base + column + lighthouse
# all render with the ThickLineRenderer fallback-perpendicular fix from
# round-4. The chase-cam shot has ports at horizon distance (>500m), too far
# to see the island base clearly; this harness teleports the player ~80m off
# the nearest port and reframes the chase camera for a clean view.
#
# Usage:
#   timeout 30 godot --path . tools/ScreenshotPort.tscn
#   ls /tmp/fathom_port.png
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const OUT_PATH := "/tmp/fathom_port.png"


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

	# Find the first port in the scene and teleport ~80m away from it.
	var ports := get_tree().get_nodes_in_group("port")
	if ports.is_empty():
		push_error("No Port in scene")
		get_tree().quit()
		return
	var port: Node3D = ports[0] as Node3D
	# Stop ship motion so the chase cam doesn't chase a moving target.
	player.set_sail_level(0.0)
	player.speed = 0.0
	# Offset to the +X direction of the port — gives a flank view of the island.
	player.global_position = port.global_position + Vector3(50.0, 0.0, 0.0)
	player.yaw = -PI / 2.0  # face the port (towards -X)

	for _i in 60:
		await get_tree().process_frame

	# Override the chase cam to pose for a clean port shot — looking from above
	# the player down at the port. Strip the chase-cam script so its _process
	# doesn't snap back to the orbit pose. (Same trick as tools/screenshot.gd.)
	var cam := main.find_child("ChaseCamera", true, false) as Camera3D
	if cam != null:
		cam.set_script(null)
		cam.global_position = port.global_position + Vector3(40.0, 35.0, 40.0)
		cam.look_at(port.global_position + Vector3(0.0, 8.0, 0.0), Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(OUT_PATH)
	if err != OK:
		push_error("Save failed: %s" % str(err))
	else:
		print("Saved %s" % OUT_PATH)
	get_tree().quit()
