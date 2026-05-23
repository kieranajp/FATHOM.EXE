# SailingTuning — numbers for sailing physics: speed easing, steering response,
# rudder centering, etc. Authored in data/tuning/sailing.tres.
#
# The efficiency curve constants (0.05, 0.95, 0.75, PI/4, 3PI/4) are not in this
# resource: they are part of the curve's shape, pinned to the JS reference test
# values in test/test_sailing.gd. If you want to retune the *shape* of the curve,
# update the curve function AND the regression tests as a coordinated change.
class_name SailingTuning extends Tuning

# Speed easing toward target_speed.
#
# CONVENTION: per-second rate, used via `1 - exp(-rate * dt)` in player_ship.gd.
# rate=k means the gap to target closes at fraction `k` per second in the
# continuous limit; time-to-X-of-gap-remaining = ln(1/X)/k. E.g. with k=0.04,
# 6 → 1 kn (target 0) takes ln(6)/0.04 ≈ 44.8 s.
#
# JS reference: `speed += (target - speed) * 0.04 * dt` (game.js:2773) — Euler
# integration of dv/dt = 0.04 * (target - speed), i.e. continuous rate k=0.04.
# DO NOT bump this to make ships "snappier" — see in-irons playtest feedback;
# JS feel is deliberately slow so being caught head-to-wind isn't instant death.
@export var speed_ease_rate: float = 0.04

# Rudder dynamics. JS: rudder ± 0.18 per "key tick", * 0.6 self-center per tick.
# We use per-second rates so behaviour is dt-independent (see speed_ease_rate
# comment above for the convention).
#
# rudder_center_rate JS equivalence: `rudder *= 0.6` per frame @ 60 Hz →
# continuous rate -ln(0.6)*60 ≈ 30.6/s. The wheel snaps to centre fast.
@export var rudder_input_rate: float = 6.0      # rad/s of rudder per key held
@export var rudder_max: float = 1.0
@export var rudder_center_rate: float = 30.6    # how fast rudder eases to 0 on release

# Steering response: turn_rate = (turn_factor + speed * turn_factor_speed) * rudder * turn_scale
@export var turn_factor: float = 1.8
@export var turn_factor_speed: float = 0.45
@export var turn_scale: float = 0.22

# Sail level ramp — JS bumps 0.05 per key tick; we want a smooth ramp.
@export var sail_ramp_rate: float = 1.5         # units/sec when W/S held

# Wave buoyancy sampling distances (metres).
@export var bow_sample_distance: float = 2.0
@export var beam_sample_distance: float = 1.0

# Centrifugal-style roll term: roll += -rudder * speed * roll_factor.
@export var roll_factor: float = 0.08

# Island collision tuning.
@export var collision_bounce_speed: float = -2.5
@export var collision_immunity_seconds: float = 3.0
@export var collision_damage: float = 10.0
@export var collision_radius_margin: float = -2.0  # JS uses (port.size + ship.hitRadius - 2.0)
