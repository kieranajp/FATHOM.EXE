class_name PortDef extends Resource

@export var id: String
@export var display_name: String
@export var position: Vector3
@export var size: float = 25.0
@export var height: float = 15.0
@export var archipelago_id: String
@export var faction_id: String = "neutral"      # post-parity meaningful
@export var color: Color
# base_prices schema (inner dict untyped — typed Dictionary disallows nested typing):
#   item_id (String) -> {
#       "buy": int,
#       "sell": int,
#       "is_producer": bool,
#       "is_consumer": bool,
#   }
@export var base_prices: Dictionary
