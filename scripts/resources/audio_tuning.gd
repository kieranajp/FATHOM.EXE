# AudioTuning — numbers for volume offsets and properties per audio cue.
# Authored in data/tuning/audio.tres; loaded by AudioBus singleton.
class_name AudioTuning extends Tuning

@export var sfx_volume_db: float = 0.0
@export var music_volume_db: float = 0.0
@export var ambient_volume_db: float = 0.0

@export var beep_volume_db: float = -6.0
@export var shoot_volume_db: float = -3.0
@export var explosion_volume_db: float = -3.0
@export var splash_volume_db: float = -4.0
@export var dock_jingle_volume_db: float = -3.0
@export var coin_volume_db: float = -6.0
@export var clink_volume_db: float = -4.0
@export var travel_sweep_volume_db: float = -6.0
@export var siren_volume_db: float = -6.0
@export var low_buzz_volume_db: float = -4.0

@export var wind_volume_db: float = -12.0
@export var waves_volume_db: float = -12.0

@export var wind_base_pitch: float = 1.0
