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


static func load_or_default(class_id: String) -> ShipClass:
	var path := "res://data/ships/" + class_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("ShipClass: '%s' not found at %s — using runtime default" % [class_id, path])
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
	return load(path) as ShipClass
