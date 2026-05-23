# WorldTuning — numbers for the ocean grid and other transient-world visuals.
# Authored in data/tuning/world.tres; loaded by systems/ocean.gd (T01) and any
# future world-rendering systems (particle counts, draw distances, etc.).
class_name WorldTuning extends Tuning

@export var grid_radius: float = 160.0
@export var grid_spacing: float = 8.0

# Sea spray — cyan particles drifting around the player for scale + motion.
# JS reference: game.js:556 (40 particles in a 300m box, recycled when they
# drift outside ±150m). We use a slightly higher count by default; the
# wrap radius still matches.
@export var spray_particle_count: int = 80
@export var spray_radius: float = 150.0
@export var spray_size: float = 0.8
