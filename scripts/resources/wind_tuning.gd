# WindTuning — numbers for the WindSystem autoload.
# Authored in data/tuning/wind.tres.
class_name WindTuning extends Tuning

# Wind angle lerp factor per frame in JS (0.02). To stay frame-rate independent
# we treat this as a per-second rate via exp() easing in WindSystem.
# JS @ 60 Hz, factor 0.02 ≈ time-constant of 50 frames ≈ 0.83 s.
# A per-second rate of ~1.2 reproduces the same feel.
@export var angle_lerp_rate: float = 1.2

# Target reshuffle cadence (seconds). JS: 25 + random()*30 → 25..55.
@export var change_min_seconds: float = 25.0
@export var change_max_seconds: float = 55.0

# Constant wind speed (knots) — for now. Variable wind is post-parity.
@export var speed_knots: float = 12.0

# Initial angle on boot (radians). Headless tests want determinism; play feels
# better with a non-zero starting direction so the first tack has bite.
@export var initial_angle: float = 0.0
