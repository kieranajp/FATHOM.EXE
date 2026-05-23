class_name Commodity extends Resource

@export var id: String
@export var display_name: String
@export var short_code: String                  # 3-letter HUD code
@export var base_price: int
@export var contraband_in: Array[String]        # faction ids; post-parity
