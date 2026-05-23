class_name Debris extends Resource

@export var id: int = 0
@export var x: float = 0.0
@export var y: float = 0.0
@export var z: float = 0.0
@export var vx: float = 0.0
@export var vy: float = 0.0
@export var vz: float = 0.0
@export var life: float = 0.0
@export var yaw: float = 0.0
@export var pitch: float = 0.0
@export var roll: float = 0.0
@export var rot_speed_yaw: float = 0.0
@export var rot_speed_pitch: float = 0.0
@export var rot_speed_roll: float = 0.0
@export var is_spark: bool = true

static func create(dict: Dictionary) -> Debris:
	var d := Debris.new()
	d.id = int(dict.get("id", 0))
	d.x = float(dict.get("x", 0.0))
	d.y = float(dict.get("y", 0.0))
	d.z = float(dict.get("z", 0.0))
	d.vx = float(dict.get("vx", 0.0))
	d.vy = float(dict.get("vy", 0.0))
	d.vz = float(dict.get("vz", 0.0))
	d.life = float(dict.get("life", 0.0))
	d.yaw = float(dict.get("yaw", 0.0))
	d.pitch = float(dict.get("pitch", 0.0))
	d.roll = float(dict.get("roll", 0.0))
	d.rot_speed_yaw = float(dict.get("rot_speed_yaw", 0.0))
	d.rot_speed_pitch = float(dict.get("rot_speed_pitch", 0.0))
	d.rot_speed_roll = float(dict.get("rot_speed_roll", 0.0))
	d.is_spark = bool(dict.get("is_spark", true))
	return d
