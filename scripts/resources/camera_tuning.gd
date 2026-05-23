# CameraTuning — chase camera params. Authored in data/tuning/camera.tres.
class_name CameraTuning extends Tuning

# Orbit radius scales with the ship's hit_radius:
#   radius = base_orbit + ship.hit_radius * radius_scale_factor
# JS: r = 11.5 + hitRadius * 1.5 — these defaults match.
@export var base_orbit: float = 11.5
@export var radius_scale_factor: float = 1.5

# Default vertical orbit angle (radians). JS used 0.30 (~17°), but
# user-reported playtesting wanted a higher view to show the pentagonal hull
# top-down (see PR notes on godot-fix-vector-rendering). Bumped to 0.5 (~28°).
@export var base_pitch: float = 0.5
@export var min_pitch: float = 0.05
@export var max_pitch: float = 1.2

# Spring-lag ease rate. JS uses 1 - exp(-6*dt).
@export var follow_ease_rate: float = 6.0

# Mouse drag sensitivity (rad per pixel of drag).
@export var mouse_pitch_sensitivity: float = 0.005
@export var mouse_yaw_sensitivity: float = 0.005

# Decay rates back to neutral when right-mouse is released and not aiming.
# JS: 2.8 while steering, 0.45 while cruising.
@export var offset_decay_steering: float = 2.8
@export var offset_decay_cruising: float = 0.45

# How much of the player roll bleeds into camera roll. JS: 0.3.
@export var roll_blend: float = 0.3

# Look-at framing — aim slightly ABOVE the ship; JS uses hit_height * 0.35.
@export var look_height_factor: float = 0.35

# Ambient camera bobbing amplitude / frequency.
@export var bob_amplitude: float = 0.15
@export var bob_frequency: float = 0.8

# Aim mode (space held) freezes orbit at the active flank. JS uses ±PI/2 offset.
@export var aim_flank_yaw_offset: float = PI / 2.0
