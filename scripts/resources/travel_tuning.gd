# TravelTuning — numbers for the Fast Travel transit sequence (T08).
# Authored in data/tuning/travel.tres; loaded by ui/travel.gd and the
# travel_completed handler on autoload/time_system.gd.
class_name TravelTuning extends Tuning

# Proximity (in metres) to hostile ships that blocks fast travel.
@export var travel_lockout_hostile_radius: float = 160.0

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

# Probability (0..1) that a fast-travel rolls a pirate intercept, looked up by
# the route's ArchipelagoDef.risk_tier (T39). Intercept aborts the trip,
# transitions back to OpenSea in the source archipelago, and spawns 1-2 sloops
# next to the player. Storm and intercept are independent rolls; if both fire,
# intercept wins (pirates are more dramatic than weather).
@export_range(0.0, 1.0) var low_intercept_chance: float = 0.10
@export_range(0.0, 1.0) var medium_intercept_chance: float = 0.25
@export_range(0.0, 1.0) var high_intercept_chance: float = 0.45


# Map an ArchipelagoDef.risk_tier (1/2/3) to its intercept probability. Out-of-
# range tiers clamp to low so unconfigured archipelagos fail safe.
func intercept_chance_for_tier(risk_tier: int) -> float:
	match risk_tier:
		3:
			return high_intercept_chance
		2:
			return medium_intercept_chance
		_:
			return low_intercept_chance
