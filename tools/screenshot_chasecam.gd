# Chase-cam screenshot harness — boots the Main scene, lets the camera settle
# at its actual chase position (no manual re-framing), saves a PNG.
#
# Use case: aesthetic-pass verification where we want to see the same shot the
# player sees, not a posed beauty shot. Sibling to tools/screenshot.gd which
# overrides the camera transform for a fixed 3/4 angle.
#
#   timeout 15 godot --path . tools/ScreenshotChasecam.tscn
#   ls /tmp/fathom_chasecam.png
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const SETTLE_FRAMES := 60  # 1 second at 60fps — chase-cam spring-lag should
                           # fully converge to its orbit target.
const OUT_PATH := "/tmp/fathom_chasecam.png"


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)

	for _i in SETTLE_FRAMES:
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(OUT_PATH)
	if err != OK:
		push_error("Screenshot save failed: %s" % str(err))
	else:
		print("Saved %s" % OUT_PATH)
	get_tree().quit()
