class_name ShipClass extends Resource

@export var id: String
@export var display_name: String
@export var cost: int = 0
@export var max_health: float = 100.0
@export var base_max_speed: float = 6.0
@export var max_cargo: int = 100
@export var firepower: int = 1
@export var hit_radius: float = 4.0
@export var hit_height: float = 6.0
@export var mesh_scene: PackedScene             # optional; if null, use placeholder


# Returns null when the .tres file is missing. Callers that need to REJECT
# unknown ids (e.g. shipyard upgrade validation) use this variant.
static func load_or_null(class_id: String) -> ShipClass:
	var path := "res://data/ships/" + class_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ShipClass


# Returns a synthesised default ShipClass when the .tres is missing. Callers
# that need a "show something rather than crash" fallback (HUD, mesh build,
# cargo capacity lookup) use this variant.
static func load_or_default(class_id: String) -> ShipClass:
	var cls := load_or_null(class_id)
	if cls != null:
		return cls
	push_warning("ShipClass: '%s' not found at res://data/ships/ — using runtime default" % class_id)
	var fallback := ShipClass.new()
	fallback.id = class_id
	fallback.display_name = class_id.to_upper()
	fallback.max_health = 100.0
	fallback.base_max_speed = 5.0
	fallback.max_cargo = 100
	fallback.firepower = 1
	fallback.hit_radius = 4.0
	fallback.hit_height = 6.0
	return fallback
