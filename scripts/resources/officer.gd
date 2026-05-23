# Post-parity. Declared now so EventBus signal signatures resolve.
class_name Officer extends Resource

@export var id: String
@export var display_name: String
@export var role: String                        # bosun, master_gunner, sailing_master, surgeon
@export var alive: bool = true
@export var passive_bonus: Dictionary           # stat key -> multiplier or delta
