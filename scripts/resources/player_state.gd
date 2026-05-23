class_name PlayerState extends Resource

@export var ship_class_id: String = "dinghy"
@export var ship_name: String = "The Salty Seagull"
@export var gold: int = 150
@export var health: float = 100.0
@export var cargo: Dictionary = {}              # item_id (String) -> int
@export var ammo: Dictionary = { "ball": 10, "chain": 0, "grape": 0 }
@export var active_ammo: String = "ball"
@export var sail_level: float = 2.0             # 0..4
