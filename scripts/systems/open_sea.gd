# OpenSea — script attached to the OpenSea scene root. Owns the per-frame tick
# for systems that need to advance only when the player is at sea (i.e. paused
# when docked). For now that's just WindSystem; TimeSystem will get added when
# T08 wires the docked-pause flow.
extends Node3D


func _process(delta: float) -> void:
	WindSystem.update(delta)
