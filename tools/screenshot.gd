# Screenshot harness — loads the Main scene, waits a few frames so the ocean
# settles, optionally re-frames the camera for a profile shot of the ship, then
# saves a PNG of the viewport to /tmp/fathom_shot_<timestamp>.png and quits.
#
# Intended for the aesthetic-pass verification flow:
#   timeout 12 godot --path . tools/Screenshot.tscn
#   ls /tmp/fathom_shot_*.png
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const SETTLE_FRAMES := 30  # half a second at 60fps — enough for one wave settle


func _ready() -> void:
	# Mount the real game under this temporary harness root.
	var main := MAIN_SCENE.instantiate()
	add_child(main)

	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	# Try to re-frame: pose the chase camera at a 3/4 angle behind-and-above the
	# player so the composite ship (hull + bowsprit + mast + yard + sail) and a
	# nearby lighthouse can both read in one shot. Fall back silently if the
	# camera or player isn't where we expect — the screenshot still saves.
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var player := tree.current_scene.find_child("PlayerShip", true, false) as Node3D
		var cam := tree.current_scene.find_child("ChaseCamera", true, false) as Camera3D
		if player != null and cam != null:
			# Override the chase-camera by removing its script so its _process
			# doesn't immediately snap back. Cheaper than poking at its tuning.
			cam.set_script(null)
			var off := Vector3(8.0, 6.0, 12.0)  # behind-right-above
			cam.global_position = player.global_position + off
			cam.look_at(player.global_position + Vector3(0, 1.5, 0), Vector3.UP)
			# Give the engine one more frame to render the new pose.
			await get_tree().process_frame
			await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var ts := str(Time.get_unix_time_from_system()).split(".")[0]
	var path := "/tmp/fathom_shot_%s.png" % ts
	var err := image.save_png(path)
	if err != OK:
		push_error("Screenshot save failed: %s" % str(err))
	else:
		print("Saved %s" % path)
	get_tree().quit()
