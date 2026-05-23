# WindSystem — global wind angle + speed + drift target.
#
# Public API (frozen by ARCHITECTURE.md):
#   var angle: float           (radians)
#   var speed: float           (knots)
#   var target_angle: float
#   var change_timer: float
#   func update(delta: float) -> void
#   func sailing_efficiency(player_yaw: float) -> float
#
# OpenSea (or any owning scene) is responsible for calling update(delta) each
# frame. We don't tick on _process because we want callers to choose when wind
# advances — useful for paused docked state, headless tests, etc.
#
# Headless-safe: _ready does not touch the scene tree.
extends Node

var angle: float = 0.0
var speed: float = 12.0
var target_angle: float = 0.0
var change_timer: float = 0.0

var tuning: WindTuning


func _ready() -> void:
	tuning = Tunings.wind
	angle = tuning.initial_angle
	target_angle = tuning.initial_angle
	speed = tuning.speed_knots
	change_timer = _roll_change_interval()


func update(delta: float) -> void:
	change_timer -= delta
	if change_timer <= 0.0:
		target_angle = randf() * TAU
		change_timer = _roll_change_interval()

	# Per-second easing. JS uses a fixed per-frame factor (0.02 @ 60 Hz);
	# we exponentialise so the same feel survives variable framerates.
	var lerp_factor: float = 1.0 - exp(-tuning.angle_lerp_rate * delta)
	angle = calculate_next_angle(angle, target_angle, lerp_factor)


func sailing_efficiency(player_yaw: float) -> float:
	return SailingMath.efficiency(player_yaw, angle)


# Pure helper, mirror of JS calculateNextWindAngle. Pulled out so it can be
# tested in isolation. Wraps via shortest-path around the 0/2π boundary.
#
# Convention: result is always in [0, TAU).
static func calculate_next_angle(current: float, target: float, lerp_factor: float) -> float:
	var diff: float = target - current
	while diff < -PI:
		diff += TAU
	while diff > PI:
		diff -= TAU
	var next_angle: float = fmod(current + diff * lerp_factor, TAU)
	if next_angle < 0.0:
		next_angle += TAU
	return next_angle


func _roll_change_interval() -> float:
	return tuning.change_min_seconds + randf() * (tuning.change_max_seconds - tuning.change_min_seconds)
