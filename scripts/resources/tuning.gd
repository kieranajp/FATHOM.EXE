# Tuning — base class for per-system tuning resources.
# Concrete .tres files in data/tuning/ (combat, sailing, wind, camera, economy, world)
# extend this and declare their own @export fields. Foundations ships only combat.tres
# as a smoke test; T-tuning fills the rest.
class_name Tuning extends Resource

# Combat tuning fields (used by data/tuning/combat.tres for the F1 smoke test).
# Other systems extend or add their own fields as their tickets land.
@export var ball_damage: float = 25.0
