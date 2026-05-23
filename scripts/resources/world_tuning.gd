# WorldTuning — numbers for the ocean grid and other transient-world visuals.
# Authored in data/tuning/world.tres; loaded by systems/ocean.gd (T01) and any
# future world-rendering systems (particle counts, draw distances, etc.).
class_name WorldTuning extends Tuning

@export var grid_radius: float = 160.0
@export var grid_spacing: float = 8.0
