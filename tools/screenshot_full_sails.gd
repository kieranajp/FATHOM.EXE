# Variant of screenshot_chasecam — overrides GameState.ship.sail_level to 4.0
# (full sails) before settling, then snapshots. Lets us verify the
# sail-deformation extends the sail to full billow when commanded.
#
#   timeout 15 godot --path . tools/ScreenshotFullSails.tscn
#   ls /tmp/fathom_full_sails.png
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const SETTLE_FRAMES := 60
const OUT_PATH := "/tmp/fathom_full_sails.png"


func _ready() -> void:
	# Stomp the saved sail_level before Main spawns so PlayerShip reads 4.0
	# on its first tick. The chase cam then composes the same frame as
	# screenshot_chasecam but with the sail fully unfurled.
	GameState.ship.sail_level = 4.0

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
