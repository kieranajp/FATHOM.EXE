# MapTuning — cosmetic/animation numbers for the Strategic Map (T08).
# Per-archipelago position/radius live on ArchipelagoDef, not here.
# Authored in data/tuning/map.tres; loaded by ui/map.gd.
class_name MapTuning extends Tuning

# Scale factor applied to a port's 3D world position when projecting it onto
# the 2D map circle for the archipelago.
@export var port_scale: float = 0.15

# Line width for archipelago boundary rings.
@export var circle_line_width: float = 1.5

# Multiplier on the pulse timer for the "you are here" ring animation.
@export var pulse_speed: float = 5.0

# Multiplier on the pulse timer for the blinking player-ship indicator.
@export var blink_speed: float = 3.0
