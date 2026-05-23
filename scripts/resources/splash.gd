class_name Splash extends Resource

@export var x: float = 0.0
@export var z: float = 0.0
@export var r: float = 0.2
@export var max_r: float = 1.0
@export var life: float = 0.0

static func create(dict: Dictionary) -> Splash:
	var s := Splash.new()
	s.x = float(dict.get("x", 0.0))
	s.z = float(dict.get("z", 0.0))
	s.r = float(dict.get("r", 0.2))
	s.max_r = float(dict.get("max_r", 1.0))
	s.life = float(dict.get("life", 0.0))
	return s
