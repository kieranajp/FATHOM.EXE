# Post-parity. Bulk crew counts + morale + food/time-at-sea factors.
class_name CrewState extends Resource

@export var gunners: int = 0
@export var sailors: int = 0
@export var riggers: int = 0
@export var morale: float = 50.0                # 0-100
@export var food_quality: float = 100.0
@export var days_at_sea: int = 0
