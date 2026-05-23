# SailingTuning — numbers for sailing physics: speed easing, steering response,
# rudder centering, etc. Authored in data/tuning/sailing.tres.
#
# The efficiency curve constants (0.05, 0.95, 0.75, PI/4, 3PI/4) are not in this
# resource: they are part of the curve's shape, pinned to the JS reference test
# values in test/test_sailing.gd. If you want to retune the *shape* of the curve,
# update the curve function AND the regression tests as a coordinated change.
class_name SailingTuning extends Tuning

# Speed easing toward target_speed (per-second factor). JS uses 0.04 * dt with
# dt in seconds — frame-rate dependent in JS. Here we use exp() easing for
# frame-rate independence; the multiplier picks the time-to-reach. ~4 s to 95%.
@export var speed_ease_rate: float = 1.2

# Rudder dynamics. JS: rudder ± 0.18 per "key tick", * 0.6 self-center per tick.
# We use per-second rates so behaviour is dt-independent.
@export var rudder_input_rate: float = 6.0      # rad/s of rudder per key held
@export var rudder_max: float = 1.0
@export var rudder_center_rate: float = 6.0     # how fast rudder eases to 0 on release

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
