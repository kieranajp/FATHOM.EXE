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
