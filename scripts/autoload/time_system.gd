# TimeSystem — in-world clock. Emits hour_passed / day_passed via EventBus.
# Pauses when docked (GameState.current_port_id != "").
# Owner: stub from F1. Real implementation lands with T03 (port/dock).
extends Node

var day: int = 1
var hour: int = 8
var is_paused: bool = false


func tick(_delta: float) -> void:
	push_warning("TimeSystem.tick stub — T03")
