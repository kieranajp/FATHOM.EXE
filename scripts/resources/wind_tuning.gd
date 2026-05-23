# WindTuning — numbers for the WindSystem autoload.
# Authored in data/tuning/wind.tres.
class_name WindTuning extends Tuning

# Wind angle drift toward target_angle.
#
# CONVENTION: per-second rate, used via `1 - exp(-rate * dt)` in WindSystem
# (matches sailing_tuning.gd's convention). rate=k means the angular gap to
# target closes at fraction `k` per second in the continuous limit; half-life
# = ln(2)/k. At k=1.2 the half-life is ~0.58 s and 99% closes in ~3.8 s.
#
# JS reference: `nextAngle = currentAngle + diff * 0.02` per frame @ 60 Hz
# (game.js:849) — equivalent continuous rate -ln(1-0.02)*60 ≈ 1.21/s. The angle
# converges quickly after a target reshuffle, then sits stable until the next
# 25–55s timer expires. Don't lower this past JS feel without a design call.
@export var angle_lerp_rate: float = 1.2

# Target reshuffle cadence (seconds). JS: 25 + random()*30 → 25..55.
@export var change_min_seconds: float = 25.0
@export var change_max_seconds: float = 55.0

# Constant wind speed (knots) — for now. Variable wind is post-parity.
@export var speed_knots: float = 12.0

# Initial angle on boot (radians). Headless tests want determinism; play feels
# better with a non-zero starting direction so the first tack has bite.
@export var initial_angle: float = 0.0
