# Main scene root. Hosts the active scene under SceneRoot.
# F1: loads OpenSea.tscn as the smoke scene; quits on Escape.
# Later tickets swap SceneRoot.child via a proper scene router.
extends Node

const OPEN_SEA := preload("res://scenes/OpenSea.tscn")

@onready var scene_root: Node = $SceneRoot


func _ready() -> void:
	scene_root.add_child(OPEN_SEA.instantiate())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
