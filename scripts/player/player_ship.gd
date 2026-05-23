# PlayerShip — the player's vessel. Owns position, yaw/pitch/roll, speed, rudder.
#
# Drives:
#   - sailing physics via WindSystem.angle + SailingMath.efficiency
#   - buoyancy + pitch/roll from Ocean.get_wave_height
#   - predictive island collision against nodes in the "port" group
#   - input: W/S (sails), A/D (rudder), 1/2/3 (ammo), Space (aim mode flag)
#
# Reads (never writes) GameState.ship for ship class / sail level / ammo / etc.
# (sail_level is owned here in `_sail_level`; mirrored to GameState.ship for HUD.)
#
# Coordinate convention: Godot +Y up, -Z forward. yaw=0 → ship faces -Z.
# JS yaw=0 → +Z; the conversion is "add PI when porting JS code", but we
# express the physics in Godot's frame directly so there is nothing to convert
# at runtime. See docs/ARCHITECTURE.md § "Coordinate conversions".
class_name PlayerShip extends Node3D

const SHIP_DATA_DIR := "res://data/ships/"

@export var tuning: SailingTuning
@export var ocean_path: NodePath
@export var wireframe_material: ShaderMaterial

# Public per-frame state — readable by camera, HUD (T07), AI proximity (T05).
var yaw: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var speed: float = 0.0
var rudder: float = 0.0
var aim_mode: bool = false
var aim_side: String = "starboard"  # "port" | "starboard" — set when aim mode toggles
var collision_immunity_timer: float = 0.0
var speed_debuff_timer: float = 0.0  # filled in by combat (chain shot) later

var ship_class: ShipClass
var _ocean: Ocean
var _mesh_instance: MeshInstance3D
var _sail_level: float = 2.0
# Mouse state for camera flank-side selection — referenced by ChaseCamera.
var last_mouse_x_norm: float = 0.0  # -1..+1 relative to viewport centre


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/sailing.tres") as SailingTuning

	ship_class = _load_ship_class(GameState.ship.ship_class_id)
	_sail_level = GameState.ship.sail_level

	_build_placeholder_mesh()

	if ocean_path != NodePath(""):
		var ocean_node := get_node_or_null(ocean_path)
		if ocean_node is Ocean:
			_ocean = ocean_node as Ocean
			# Hand ourselves to Ocean so the grid follows us. F1's fallback
			# (first Camera3D) keeps working if this wire-up ever misses.
			_ocean.player_path = _ocean.get_path_to(self)


func _physics_process(delta: float) -> void:
	_tick_input(delta)
	_tick_sailing(delta)
	_tick_motion_and_collision(delta)
	_tick_waves()
	_apply_transform()
	GameState.ship.sail_level = _sail_level


# Public read accessors used by HUD/camera/etc.
func get_sail_level() -> float:
	return _sail_level


func get_speed_fraction() -> float:
	# 0..1 of the ship's max speed — used by audio (wind sfx pitch) and HUD.
	if ship_class == null or ship_class.base_max_speed <= 0.0:
		return 0.0
	return clampf(speed / ship_class.base_max_speed, -1.0, 1.0)


# Sign convention (Godot right-handed, +Y up, -Z forward):
#   positive rudder == starboard (right) turn == clockwise from above ==
#   NEGATIVE yaw delta. (Positive yaw is CCW about +Y, which swings the bow
#   from -Z towards -X — that's a port/left turn.)
#
# Don't flip this back without first re-reading docs/ARCHITECTURE.md
# § "Coordinate conversions from JS reference" — the JS prototype uses the
# opposite handedness and porting it naively reverses the steering.
# See test/test_steering.gd.
static func _compute_yaw_delta(rudder_value: float, turn_rate: float, delta: float) -> float:
	return -rudder_value * turn_rate * delta


# Input. Right-mouse + space are handled in _unhandled_input so the camera can
# read drag deltas via the same event stream. _physics_process handles held
# keys via Input.is_action_pressed for frame-rate independent ramping.
func _tick_input(delta: float) -> void:
	# Sail level: smooth ramp while held (the issue spec asks for smooth, not stepped).
	if Input.is_action_pressed("sail_up"):
		_sail_level = minf(4.0, _sail_level + tuning.sail_ramp_rate * delta)
	if Input.is_action_pressed("sail_down"):
		_sail_level = maxf(0.0, _sail_level - tuning.sail_ramp_rate * delta)

	# Rudder: accumulate while held, self-centre on release. Per-second rates
	# so the feel is consistent at any framerate.
	var rudder_input := 0.0
	if Input.is_action_pressed("steer_port"):
		rudder_input -= 1.0
	if Input.is_action_pressed("steer_starboard"):
		rudder_input += 1.0

	if rudder_input != 0.0:
		rudder = clampf(rudder + rudder_input * tuning.rudder_input_rate * delta, -tuning.rudder_max, tuning.rudder_max)
	else:
		# Exponential decay toward 0 — frame-rate independent.
		var center_ease: float = 1.0 - exp(-tuning.rudder_center_rate * delta)
		rudder = lerpf(rudder, 0.0, center_ease)

	# Aim mode flag. Camera does the actual flank-yaw freeze; T06 will hook
	# firing to this state.
	var was_aim := aim_mode
	aim_mode = Input.is_action_pressed("aim")
	if aim_mode and not was_aim:
		# Lock the active flank based on where the mouse was last. JS picks port
		# vs starboard from the camera yaw offset; we use the simpler "which
		# side of screen the mouse last was on" since the camera offset state
		# lives on ChaseCamera and we want PlayerShip oblivious to that.
		aim_side = "starboard" if last_mouse_x_norm >= 0.0 else "port"


func _unhandled_input(event: InputEvent) -> void:
	# Ammo selection — single-shot inputs.
	if event.is_action_pressed("ammo_ball"):
		GameState.ship.active_ammo = "ball"
	elif event.is_action_pressed("ammo_chain"):
		GameState.ship.active_ammo = "chain"
	elif event.is_action_pressed("ammo_grape"):
		GameState.ship.active_ammo = "grape"

	# Mouse position tracking — used at the moment aim engages (above).
	if event is InputEventMouseMotion:
		var vp := get_viewport()
		if vp != null:
			var size := vp.get_visible_rect().size
			if size.x > 0.0:
				last_mouse_x_norm = (event.position.x / size.x) * 2.0 - 1.0


func _tick_sailing(delta: float) -> void:
	# Decay collision immunity + speed debuff timers.
	if collision_immunity_timer > 0.0:
		collision_immunity_timer = maxf(0.0, collision_immunity_timer - delta)
	if speed_debuff_timer > 0.0:
		speed_debuff_timer = maxf(0.0, speed_debuff_timer - delta)

	# Steering: rudder rotates the ship. Turn rate scales with speed so a
	# stopped ship turns slowly (realistic), an accelerating one snappy.
	var turn_rate: float = (tuning.turn_factor + speed * tuning.turn_factor_speed) * tuning.turn_scale
	yaw += _compute_yaw_delta(rudder, turn_rate, delta)

	# Compute target speed: max_speed * sail_percent * efficiency * debuff.
	var efficiency: float = SailingMath.efficiency(yaw, WindSystem.angle)
	var sail_percent: float = _sail_level / 4.0
	var max_speed: float = ship_class.base_max_speed if ship_class != null else 6.0
	if speed_debuff_timer > 0.0:
		max_speed *= 0.5
	var target_speed: float = max_speed * sail_percent * efficiency

	# Exponential easing toward target. Frame-rate independent.
	var ease: float = 1.0 - exp(-tuning.speed_ease_rate * delta)
	speed = lerpf(speed, target_speed, ease)


func _tick_motion_and_collision(delta: float) -> void:
	# Predicted next position. Godot yaw=0 → -Z.
	var next_x: float = global_position.x - sin(yaw) * speed * delta
	var next_z: float = global_position.z - cos(yaw) * speed * delta

	if collision_immunity_timer <= 0.0:
		var ship_radius: float = ship_class.hit_radius if ship_class != null else 4.0
		# Iterate ports via the typed Port class (T03). Group membership is how
		# ports announce themselves; collision stays decoupled from spawn logic.
		for node in get_tree().get_nodes_in_group("port"):
			if not (node is Port):
				continue
			var port := node as Port
			if port.port_def == null:
				continue
			var dx: float = port.global_position.x - next_x
			var dz: float = port.global_position.z - next_z
			var threshold: float = port.port_def.size + ship_radius + tuning.collision_radius_margin
			if Vector2(dx, dz).length() < threshold:
				_handle_collision(port)
				return  # don't update position; keep current x/z for the bounce

	global_position.x = next_x
	global_position.z = next_z


func _tick_waves() -> void:
	if _ocean == null:
		# Headless / no-ocean — y stays at 0, no pitch/roll.
		return

	var px: float = global_position.x
	var pz: float = global_position.z
	var y: float = _ocean.get_wave_height(px, pz)

	# Bow / stern delta drives pitch. Sample distance from tuning.
	var bow_d: float = tuning.bow_sample_distance
	var bow_y: float = _ocean.get_wave_height(px - sin(yaw) * bow_d, pz - cos(yaw) * bow_d)
	var stern_y: float = _ocean.get_wave_height(px + sin(yaw) * bow_d, pz + cos(yaw) * bow_d)
	pitch = (bow_y - stern_y) / (bow_d * 2.0)

	# Port / stbd delta drives roll, plus the centrifugal-style turn term.
	# Port is +90° from heading, stbd is -90° (mirror of JS, sign-flipped axes).
	var beam_d: float = tuning.beam_sample_distance
	var port_y: float = _ocean.get_wave_height(
		px - sin(yaw + PI / 2.0) * beam_d, pz - cos(yaw + PI / 2.0) * beam_d
	)
	var stbd_y: float = _ocean.get_wave_height(
		px - sin(yaw - PI / 2.0) * beam_d, pz - cos(yaw - PI / 2.0) * beam_d
	)
	var turn_roll: float = -rudder * speed * tuning.roll_factor
	roll = ((port_y - stbd_y) / (beam_d * 2.0)) + turn_roll

	global_position.y = y


func _apply_transform() -> void:
	# Compose yaw -> pitch -> roll into the node's basis.
	var b := Basis()
	b = b.rotated(Vector3.UP, yaw)
	b = b.rotated(b.x, pitch)
	b = b.rotated(b.z, roll)
	transform.basis = b


func _handle_collision(port: Port) -> void:
	GameState.ship.health = maxf(0.0, GameState.ship.health - tuning.collision_damage)
	speed = tuning.collision_bounce_speed
	collision_immunity_timer = tuning.collision_immunity_seconds

	# port.port_def is non-null by construction (collision loop filters it),
	# so the signal always carries a real PortDef.
	EventBus.island_collided.emit(port.port_def, self)


func _load_ship_class(class_id: String) -> ShipClass:
	var path := SHIP_DATA_DIR + class_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("PlayerShip: ship class '%s' not found at %s — using runtime default" % [class_id, path])
		var fallback := ShipClass.new()
		fallback.id = class_id
		return fallback
	return load(path) as ShipClass


# Player visual: a LineModel rendered as PRIMITIVE_LINES — pentagonal hull,
# mast, billowing sail with ribbing. Coordinates ported verbatim from the JS
# prototype's `dinghy` model (see data/models/dinghy.tres + the comment on
# that file for the JS→Godot Z-flip).
#
# `_mesh_instance` continues to point at the resulting MeshInstance3D so
# downstream code (and future tickets) that needs a "ship visual" handle
# still has one — same convention the old ShipMesh.build_player path used.
#
# The wireframe_material export is kept on the class for backwards-compat
# with OpenSea.tscn (until the next scene-cleaning ticket removes the
# export); it is intentionally unused here — LineModel ships its own
# unshaded-emissive StandardMaterial3D.
func _build_placeholder_mesh() -> void:
	var model := load("res://data/models/dinghy.tres") as LineModel
	if model == null:
		push_warning("PlayerShip: dinghy model failed to load")
		return

	# Player faction green per ARCHITECTURE.md § "Rendering decisions". Override
	# the model's stored colour so the resource can be reused for non-player
	# dinghies later with a different tint.
	var player_green := Color("#33ff33")
	model = model.duplicate() as LineModel
	model.color = player_green

	# JS dinghy coords are in metres. The JS canvas renderer used scale=1 for
	# the player too (game.js sea-spray block), so no extra scale is needed.
	var inst := model.build_mesh_instance(1.0)
	inst.name = "ShipVisual"
	_mesh_instance = inst
	add_child(inst)

