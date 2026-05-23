# ChaseCamera — spring-lagged orbit camera. Sibling of PlayerShip (not a child)
# so position lag works naturally; if it were parented to the ship it would
# rigidly track yaw and we'd lose the "swing" feel.
#
# Left-mouse drag adds a relative pitch/yaw offset; offsets decay to zero
# when released (faster while steering, slower while cruising — JS feel).
# Right-mouse hold → aim mode (PlayerShip owns the flag); camera freezes
# orbit at the active flank yaw (±π/2). Space remains a keyboard alternative
# for aim mode.
#
# Left-click is multiplexed with PlayerShip's "fire while aiming" handler —
# we only treat LMB as orbit-drag when `_player.aim_mode` is false. When
# aiming, the camera ignores LMB so PlayerShip's _unhandled_input gets it
# (sibling event order in OpenSea.tscn — verify before adding set_input_as_handled).
class_name ChaseCamera extends Camera3D

@export var tuning: CameraTuning
@export var player_path: NodePath

var _player: PlayerShip
var _drag_offset_yaw: float = 0.0
var _drag_offset_pitch: float = 0.0
var _is_dragging: bool = false


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/camera.tres") as CameraTuning
	if player_path != NodePath(""):
		var node := get_node_or_null(player_path)
		if node is PlayerShip:
			_player = node as PlayerShip


func _process(delta: float) -> void:
	if _player == null:
		return

	# Decay drag offsets to zero whenever no orbit drag is active AND we're not
	# in aim mode. Aim mode is a hard pin — see the "freeze" branch below.
	if not _is_dragging and not _player.aim_mode:
		var steering := (
			Input.is_action_pressed("steer_port")
			or Input.is_action_pressed("steer_starboard")
		)
		var decay_rate: float = tuning.offset_decay_steering if steering else tuning.offset_decay_cruising
		var ease: float = 1.0 - exp(-decay_rate * delta)
		# Wrap drag yaw to [-PI, PI] before decaying so shortest-path is taken.
		while _drag_offset_yaw < -PI:
			_drag_offset_yaw += TAU
		while _drag_offset_yaw > PI:
			_drag_offset_yaw -= TAU
		_drag_offset_yaw = lerpf(_drag_offset_yaw, 0.0, ease)
		_drag_offset_pitch = lerpf(_drag_offset_pitch, 0.0, ease)

	# Compose final orbit angles.
	var final_yaw: float = _player.yaw + _drag_offset_yaw
	if _player.aim_mode:
		# Camera positions opposite the firing flank so the ship doesn't block
		# the view of targets to that side — i.e. firing AWAY from camera.
		# aim_side names the *firing* flank (port = -π/2 fire_yaw, starboard =
		# +π/2 fire_yaw — see player_ship._tick_aim_state). To put the camera
		# on the opposite side, invert when starboard.
		var flank_offset: float = compute_aim_yaw_offset(
			_player.aim_side, tuning.aim_flank_yaw_offset
		)
		final_yaw = _player.yaw + flank_offset
	var final_pitch: float = clampf(
		tuning.base_pitch + _drag_offset_pitch, tuning.min_pitch, tuning.max_pitch
	)

	# Orbit radius scales with ship size.
	var hit_radius: float = 4.0
	if _player.ship_class != null:
		hit_radius = _player.ship_class.hit_radius
	var r: float = tuning.base_orbit + hit_radius * tuning.radius_scale_factor

	# Target position: orbit behind the ship, lifted by pitch * radius. Godot
	# yaw=0 → -Z. The "behind" direction for yaw is +sin/+cos (opposite of the
	# ship's forward velocity, which is -sin/-cos).
	var pp: Vector3 = _player.global_position
	var cos_pitch: float = cos(final_pitch)
	var sin_pitch: float = sin(final_pitch)
	var t: float = Time.get_ticks_msec() / 1000.0
	var bob: float = sin(t * tuning.bob_frequency) * tuning.bob_amplitude

	var target_x: float = pp.x + sin(final_yaw) * r * cos_pitch
	var target_z: float = pp.z + cos(final_yaw) * r * cos_pitch
	var target_y: float = pp.y + r * sin_pitch + bob

	# Spring lag — frame-rate independent.
	var ease_pos: float = 1.0 - exp(-tuning.follow_ease_rate * delta)
	global_position = global_position.lerp(Vector3(target_x, target_y, target_z), ease_pos)

	# Look-at framing: aim a bit above the ship. Blend a fraction of player
	# roll for screen momentum.
	var look_height: float = 0.0
	if _player.ship_class != null:
		look_height = _player.ship_class.hit_height * tuning.look_height_factor
	var look_target: Vector3 = pp + Vector3(0.0, look_height, 0.0)
	look_at(look_target, Vector3.UP)
	# Apply roll bleed on top of look_at. look_at zeroes roll, so rotate around
	# local Z to add it back.
	rotate_object_local(Vector3.FORWARD, _player.roll * tuning.roll_blend)


# Read accessor for the accumulated LMB-drag yaw offset. PlayerShip uses this
# to pick the firing flank when aim mode toggles on — JS picks based on the
# camera orbit offset (game.js:458), not the cursor X. Exposed via a getter
# rather than the bare field so PlayerShip can keep _drag_offset_yaw private
# to the camera.
func get_drag_yaw_offset() -> float:
	return _drag_offset_yaw


# Static so test code can pin the camera-vs-firing-flank invariant without
# spinning up a scene tree. Returns the yaw offset (from player.yaw) where the
# chase camera should sit when aiming at `side`. The camera is placed OPPOSITE
# the firing flank so it can see across the ship to the targets.
static func compute_aim_yaw_offset(side: String, magnitude: float) -> float:
	# side == "port"      → firing port (-π/2)      → camera on starboard (+magnitude)
	# side == "starboard" → firing starboard (+π/2) → camera on port      (-magnitude)
	if side == "starboard":
		return -magnitude
	return magnitude


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# LMB-drag is camera orbit, but only when not aiming. When the ship
			# is in aim_mode, LMB means "fire active flank" — let PlayerShip
			# handle it instead. On press while aiming we leave _is_dragging
			# alone; on release we always clear in case aim_mode was exited
			# mid-drag (otherwise the drag would silently stick).
			if mb.pressed:
				if _player == null or not _player.aim_mode:
					_is_dragging = true
			else:
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		_drag_offset_yaw += mm.relative.x * tuning.mouse_yaw_sensitivity
		_drag_offset_pitch += mm.relative.y * tuning.mouse_pitch_sensitivity
