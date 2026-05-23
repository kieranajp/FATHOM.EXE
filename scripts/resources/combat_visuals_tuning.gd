# CombatVisualsTuning — numbers for the projectile / splash / debris renderer.
#
# Authored in data/tuning/combat_visuals.tres; loaded by
# systems/combat_visuals.gd. Visuals are pure consumers of World.projectiles /
# World.splashes / World.debris — these knobs only affect appearance, not
# gameplay, so they live in their own .tres rather than colonising CombatTuning.
class_name CombatVisualsTuning extends Tuning

# --- Projectiles. ---
# Trail = a short line segment along the projectile's velocity, drawn each
# frame. The factor is the fraction of one second's worth of velocity we
# subtract from the current position to find the tail. Matches the JS render
# code (game.js: `d.x - d.vx * 0.04` for sparks; we use the same idea for
# projectiles to give the bullet a sense of motion).
@export var projectile_trail_factor: float = 0.04

# Chain shot offset — paired dots dance around the projectile centre at
# `chain_visual_speed * life` angle, `chain_visual_radius` metres apart.
# Mirrors JS chain rendering (game.js:3289).
@export var chain_visual_radius: float = 0.4
@export var chain_visual_speed: float = 15.0

# Colour overrides. Projectile colour is decided by attacker faction first;
# if no faction info is available we fall back to is_player_owned (cyan vs.
# faction-red). Default colours are duplicated in code as constants for the
# fallback path.
@export var projectile_emission_energy: float = 2.5

# Head marker size for ball/grape projectiles, in metres.
#
# Round-4 drew a 3-axis "+" of line ticks at the head — invisibly thin on a
# 4K display (PRIMITIVE_LINES is 1px in Vulkan). Round-5 swapped to a camera-
# facing FILLED quad in a dedicated PRIMITIVE_TRIANGLES surface but didn't
# disable backface culling, so the entire head vanished (Godot's default
# CULL_BACK eats both triangles when their normal `cam_right × cam_up`
# = `cam_basis.z` points away from the camera's look direction). Round-6
# fixes that on the material side and authors the size as the quad's
# half-extent in world metres — `projectile_ball_size = 1.0` → 2.0m square.
#
# Grape pellets get their own (smaller) size so the cluster reads as many
# tiny dots rather than a single fat blob.
# `projectile_head_size` is retained for chain-shot tick scaling.
@export var projectile_ball_size: float = 1.0
@export var projectile_grape_size: float = 0.5
@export var projectile_head_size: float = 0.6

# --- Splashes. ---
# Horizontal ring at sea level; alpha scales with life / splash_life. The
# segment count balances roundness vs. cost — 16 is plenty for a brief flash.
@export var splash_ring_segments: int = 16
@export var splash_emission_energy: float = 1.5
@export var splash_color: Color = Color(0.0, 1.0, 1.0, 1.0)  # cyan

# --- Debris (sparks + crates). ---
@export var spark_color: Color = Color(1.0, 0.467, 0.2, 1.0)  # JS #ff7733
@export var spark_emission_energy: float = 1.5
@export var crate_emission_energy: float = 1.2

# Crate spawn on enemy sink. Five small wireframe cubes ride the wave near the
# sinking ship; lifetime is long enough that the player sees them rise/fall on
# at least one swell.
@export var crate_count_on_sink: int = 5
@export var crate_lifetime_seconds: float = 5.0
@export var crate_spawn_radius: float = 4.0       # initial XZ spread, metres
@export var crate_initial_outward_speed: float = 1.5  # m/s lateral push
@export var crate_scale: float = 0.45             # cube.tres is 2m across — scale down
@export var crate_color: Color = Color(1.0, 0.667, 0.4, 1.0)  # JS #ffaa66

# Crate rotation rate per axis (rad/s, randomised within ±this).
@export var crate_rot_speed_max: float = 1.2
