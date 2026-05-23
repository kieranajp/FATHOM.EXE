class_name Projectile extends Resource

@export var x: float = 0.0
@export var y: float = 0.0
@export var z: float = 0.0
@export var vx: float = 0.0
@export var vy: float = 0.0
@export var vz: float = 0.0
@export var life: float = 0.0
@export var damage: float = 0.0
@export var type: String = "ball"
@export var attacker: Object = null  # PlayerShip or EnemyShip
@export var is_player_owned: bool = false
@export var faction_id: String = "pirate"

static func create(dict: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.x = float(dict.get("x", 0.0))
	p.y = float(dict.get("y", 0.0))
	p.z = float(dict.get("z", 0.0))
	p.vx = float(dict.get("vx", 0.0))
	p.vy = float(dict.get("vy", 0.0))
	p.vz = float(dict.get("vz", 0.0))
	p.life = float(dict.get("life", 0.0))
	p.damage = float(dict.get("damage", 0.0))
	p.type = String(dict.get("type", "ball"))
	p.attacker = dict.get("attacker", null)
	p.is_player_owned = bool(dict.get("is_player_owned", false))
	p.faction_id = String(dict.get("faction_id", "pirate"))
	return p
