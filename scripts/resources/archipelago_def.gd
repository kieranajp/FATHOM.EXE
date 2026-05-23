class_name ArchipelagoDef extends Resource

@export var id: String
@export var display_name: String
@export var sector: String                      # e.g. "SEC A-1"
@export var color: Color
@export var port_ids: Array[String]

# Strategic-map placement: where this archipelago's circle is drawn on
# scripts/ui/map.gd, and the circle's radius in screen pixels (also used as the
# click hit-test radius). Kept on the def (not on a tuning .tres) because it's
# a per-archipelago concern, not a system-wide knob.
@export var map_position: Vector2 = Vector2.ZERO
@export var map_radius: float = 150.0

# Route-risk tier (T39): 1 = low, 2 = medium, 3 = high. Drives the fast-travel
# pirate-intercept chance (see TravelTuning.*_intercept_chance) and is rendered
# as a label on the strategic map so the player can weigh "fast but dangerous"
# vs "slow but safe". Per-archipelago concern, so it lives on the def, not a
# tuning .tres.
@export_range(1, 3) var risk_tier: int = 1
