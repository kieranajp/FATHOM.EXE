# Post-parity. Currently colour-only in JS; full reputation system lands later.
class_name FactionState extends Resource

@export var id: String
@export var display_name: String
@export var color: Color
@export var player_reputation: float = 0.0      # -100..100
