# TravelTuning — numbers for the Fast Travel transit sequence (T08).
# Authored in data/tuning/travel.tres; loaded by ui/travel.gd and the
# travel_completed handler on autoload/time_system.gd.
class_name TravelTuning extends Tuning

# Probability (0..1) that a trip rolls a storm and takes the longer duration.
@export var storm_chance: float = 0.3

# Base transit time for a calm passage, in real-time seconds.
@export var calm_duration_seconds: float = 3.0

# Extra real-time seconds added on top of calm_duration_seconds when a storm rolls.
# Storm total = calm_duration_seconds + storm_extension_seconds.
@export var storm_extension_seconds: float = 2.0

# In-world hours that the clock advances on fast-travel arrival, regardless of
# whether the trip rolled calm or storm.
@export var hours_per_trip: int = 6
