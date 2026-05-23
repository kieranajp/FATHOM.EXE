# WindSystem — global wind angle, speed, drift target.
# OpenSea calls update(delta) each frame; sailing code calls sailing_efficiency.
# Owner: stub from F1. Real implementation lands with T02 (player ship / sailing).
extends Node

var angle: float = 0.0           # radians
var speed: float = 5.0           # knots
var target_angle: float = 0.0
var change_timer: float = 0.0


func update(_delta: float) -> void:
	push_warning("WindSystem.update stub — T02")


func sailing_efficiency(_player_yaw: float) -> float:
	push_warning("WindSystem.sailing_efficiency stub — T02")
	return 1.0
