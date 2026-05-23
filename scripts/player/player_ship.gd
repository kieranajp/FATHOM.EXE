# PlayerShip — the player's vessel. Owns position, yaw/pitch/roll, speed, rudder.
#
# Drives:
#   - sailing physics via WindSystem.angle + SailingMath.efficiency
#   - buoyancy + pitch/roll from Ocean.get_wave_height
#   - predictive island collision against nodes in the "port" group
#   - input: W/S (sails), A/D (rudder), 1/2/3 (ammo), RMB-hold or Space (aim
#     mode flag), LMB-while-aiming or Q/E (fire flank)
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
# Optional explicit NodePath to the ChaseCamera. When empty, we fall back to a
# group lookup (`chase_camera` group on the camera node). Used to pick the
# firing flank when aim mode toggles on — JS reads camera yaw, not cursor X.
@export var chase_camera_path: NodePath

# Public per-frame state — readable by camera, HUD (T07), AI proximity (T05).
var yaw: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var speed: float = 0.0
var rudder: float = 0.0
var aim_mode: bool = false
var aim_side: String = "starboard"  # "port" | "starboard" — set when aim mode toggles
var collision_immunity_timer: float = 0.0
var speed_debuff_timer: float = 0.0  # filled in by combat (chain shot)

# Combat state — written by CombatSystem (countdown) and Combat.fire_broadside
# (set to reload_seconds on a successful broadside). HUD reads these for the
# reload bars.
var reload_port: float = 0.0
var reload_stbd: float = 0.0

# Aim-mode reticle params. Mouse drag while aim_mode is held adjusts these,
# clamped to the limits in CombatTuning. Combat reads them via the aim dict.
var aim_yaw_offset: float = 0.0   # ±π/4
var aim_range: float = 120.0      # 30..240
var aim_height: float = 0.0       # -10..30
# Reticle world position — recomputed each frame; cached so AimOverlay reads it
# once per frame rather than re-deriving.
var aim_reticle_world: Vector3 = Vector3.ZERO

var ship_class: ShipClass
var _ocean: Ocean
var _mesh_instance: MeshInstance3D
# Held references for the per-frame sail-deformation rebuild. The model carries
# `deformations`; we drive `open_factor = _sail_level / 4.0` each frame so the
# sail collapses to the yard at anchor and reaches full billow at sails-full.
var _ship_model: LineModel
var _ship_mesh: ImmediateMesh
var _sail_level: float = 2.0
# Mouse state for camera flank-side selection — referenced by ChaseCamera.
# (Aim-side selection no longer uses this — see _aim_side_from_camera_yaw —
# kept around so other consumers reading it don't break.)
var last_mouse_x_norm: float = 0.0  # -1..+1 relative to viewport centre
# Right-mouse-hold drives aim mode. Kept as a field (not Input.is_mouse_button_pressed)
# so _unhandled_input is the single source of truth and the test helper can
# pin the OR-logic without faking globals.
var _right_mouse_held: bool = false


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
	_tick_sail_deformation()
	_tick_aim_state()
	GameState.ship.sail_level = _sail_level

	# Wind frequency updates with ship speed (Issue 49)
	var intensity: float = clampf(speed / ship_class.base_max_speed, 0.0, 1.0) if ship_class != null and ship_class.base_max_speed > 0.0 else 0.0
	AudioBus.update_wind_frequency(intensity)


# Recomputes the aim reticle + publishes World.aim_state. AimOverlay and HUD
# read this every frame; if aim_mode is off, we clear the dict so consumers
# can branch cheaply.
func _tick_aim_state() -> void:
	if not aim_mode:
		if not World.aim_state.is_empty():
			World.aim_state = {}
		return
	var fire_yaw: float = yaw - PI / 2.0 if aim_side == "port" else yaw + PI / 2.0
	var aim_yaw: float = fire_yaw + aim_yaw_offset
	aim_reticle_world = Vector3(
		global_position.x + sin(aim_yaw) * aim_range,
		aim_height,
		global_position.z + cos(aim_yaw) * aim_range,
	)
	World.aim_state = {
		"active": true,
		"side": aim_side,
		"yaw_offset": aim_yaw_offset,
		"range": aim_range,
		"height": aim_height,
		"reticle": aim_reticle_world,
	}


# Refreshes the ship mesh each tick to apply the sail-billow deformation at the
# current `_sail_level`. Cost is trivial — 17 verts × 28 edges = 56 surface
# vertex submissions per tick. Mirrors Ocean's rebuild-in-place pattern (keeps
# the same ImmediateMesh ref, just clears + re-emits surfaces).
func _tick_sail_deformation() -> void:
	if _ship_model == null or _ship_mesh == null:
		return
	var open_factor: float = clampf(_sail_level / 4.0, 0.0, 1.0)
	_ship_model.rebuild_immediate_mesh(_ship_mesh, 1.0, open_factor)


# Public read accessors used by HUD/camera/etc.
func get_sail_level() -> float:
	return _sail_level


# Public writer used by the death-respawn handler (scripts/main.gd) to reset
# the sail when the player is teleported to a port. Clamped to the 0..4 input
# domain so callers can't push us out of bounds.
func set_sail_level(value: float) -> void:
	_sail_level = clampf(value, 0.0, 4.0)
	GameState.ship.sail_level = _sail_level


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


# Aim-mode OR-gate. Either input source activates it; the helper exists purely
# so a unit test can pin the truth table without instancing PlayerShip + a
# Viewport. See test/test_input_aim_state.gd.
static func _compute_aim_mode(right_mouse_held: bool, aim_action_pressed: bool) -> bool:
	return right_mouse_held or aim_action_pressed


# Aim-mode yaw drag — sign is negated because the chase camera now sits on
# the OPPOSITE side of the firing flank (see ChaseCamera.compute_aim_yaw_offset).
# That mirroring means a mouse-drag-right in screen space is a left-drag in
# the firing-flank's local frame. JS reference (game.js:497) uses `+ dx`, but
# JS placed the camera on the SAME side as firing, so we invert here to keep
# the on-screen reticle moving with the cursor.
static func _compute_aim_yaw_delta(mouse_dx: float, rate: float) -> float:
	return -mouse_dx * rate


# Aim-side selection from camera yaw offset. Mirrors JS game.js:458 —
# `aimSide = mouse.yaw >= 0 ? 'starboard' : 'port'` where `mouse.yaw` is the
# accumulated LMB-drag yaw on the orbit camera, not the cursor X. Static so the
# unit test can pin the truth table without a scene tree.
#
# >= 0 (not just > 0) so a freshly-zeroed camera defaults to starboard, matching JS.
static func _aim_side_from_camera_yaw(camera_yaw_offset: float) -> String:
	return "starboard" if camera_yaw_offset >= 0.0 else "port"


# Resolves the ChaseCamera reference. Prefers the explicit NodePath; falls
# back to a `chase_camera` group lookup so the wire-up works even if the export
# isn't set in the scene. Returns null if neither resolves (headless tests).
func _get_chase_camera() -> ChaseCamera:
	if chase_camera_path != NodePath(""):
		var node := get_node_or_null(chase_camera_path)
		if node is ChaseCamera:
			return node as ChaseCamera
	var tree := get_tree()
	if tree == null:
		return null
	var cam := tree.get_first_node_in_group("chase_camera")
	if cam is ChaseCamera:
		return cam as ChaseCamera
	return null


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

	# Aim mode flag. Camera does the actual flank-yaw freeze; firing reads it
	# via _unhandled_input's LMB branch. RMB-hold is the primary input; Space
	# is kept as a keyboard alternative for trackpad/keyboard-only players.
	var was_aim := aim_mode
	aim_mode = _compute_aim_mode(_right_mouse_held, Input.is_action_pressed("aim"))
	if aim_mode and not was_aim:
		# Lock the active flank based on the ChaseCamera's accumulated drag yaw
		# offset — matches JS game.js:458 (`mouse.yaw >= 0 ? starboard : port`).
		# Previous logic read `last_mouse_x_norm` (the bare cursor position),
		# which defaulted to 0 → always-starboard when the cursor hadn't moved.
		var camera := _get_chase_camera()
		var camera_yaw: float = camera.get_drag_yaw_offset() if camera != null else 0.0
		aim_side = _aim_side_from_camera_yaw(camera_yaw)


func _unhandled_input(event: InputEvent) -> void:
	# Ammo selection — single-shot inputs.
	if event.is_action_pressed("ammo_ball"):
		GameState.ship.active_ammo = "ball"
	elif event.is_action_pressed("ammo_chain"):
		GameState.ship.active_ammo = "chain"
	elif event.is_action_pressed("ammo_grape"):
		GameState.ship.active_ammo = "grape"

	# Mouse buttons: RMB drives aim mode, LMB-while-aiming fires the active
	# flank. LMB-when-NOT-aiming falls through here (we don't consume it) so
	# ChaseCamera's _unhandled_input can pick it up for orbit drag.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_mouse_held = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and aim_mode:
			_request_fire(aim_side)

	# Fire broadsides — Q (port) / E (starboard). Kept as keyboard alternatives
	# alongside LMB-while-aiming. Routed through the CombatSystem node in
	# OpenSea; it owns the projectile spawn + ammo bookkeeping. We forward via
	# EventBus' fire signals? No — there is no fire-request signal in the
	# locked vocabulary (per ARCHITECTURE.md). Look up the system directly
	# via the scene tree.
	if event.is_action_pressed("fire_port"):
		_request_fire("port")
	elif event.is_action_pressed("fire_starboard"):
		_request_fire("starboard")

	# Mouse motion: track screen-X for the aim-side decision, and drive aim
	# parameter drag while aim_mode is held.
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var vp := get_viewport()
		if vp != null:
			var size := vp.get_visible_rect().size
			if size.x > 0.0:
				last_mouse_x_norm = (mm.position.x / size.x) * 2.0 - 1.0
		if aim_mode:
			_tick_aim_drag(mm)


# Mouse-drag → aim parameter updates while aim_mode is active. Horizontal drag
# adjusts yaw_offset (±π/4) and range (30..240). Hold Shift (aim_elevate_modifier)
# to drag vertical for aim_height (-10..30).
func _tick_aim_drag(event: InputEventMouseMotion) -> void:
	var combat_tuning := _combat_tuning()
	if combat_tuning == null:
		return
	var elevate := Input.is_action_pressed("aim_elevate_modifier")
	if elevate:
		# Drag up = elevate; mouse Y grows down in Godot.
		aim_height = clampf(
			aim_height - event.relative.y * combat_tuning.aim_mouse_height_rate,
			combat_tuning.aim_height_min,
			combat_tuning.aim_height_max,
		)
	else:
		aim_yaw_offset = clampf(
			aim_yaw_offset + _compute_aim_yaw_delta(event.relative.x, combat_tuning.aim_mouse_yaw_rate),
			-combat_tuning.aim_yaw_max,
			combat_tuning.aim_yaw_max,
		)
		aim_range = clampf(
			aim_range - event.relative.y * combat_tuning.aim_mouse_range_rate,
			combat_tuning.aim_range_min,
			combat_tuning.aim_range_max,
		)


# Forwards a fire input to the CombatSystem. Lookup is cheap (one find_child)
# and only runs on key-down events, so we don't bother caching.
func _request_fire(side: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		return
	var combat := root.find_child("CombatSystem", true, false) as CombatSystem
	if combat == null:
		return
	combat.player_fire(side)


# Loads the shared CombatTuning. Cached on the node so repeated mouse-drag
# events don't thrash the resource cache.
var _combat_tuning_cached: CombatTuning
func _combat_tuning() -> CombatTuning:
	if _combat_tuning_cached == null:
		_combat_tuning_cached = load("res://data/tuning/combat.tres") as CombatTuning
	return _combat_tuning_cached


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
	var dmg: float = tuning.collision_damage if tuning != null else 10.0
	GameState.ship.health = maxf(0.0, GameState.ship.health - dmg)
	speed = tuning.collision_bounce_speed if tuning != null else -2.0
	collision_immunity_timer = tuning.collision_immunity_seconds if tuning != null else 3.0

	var port_name := "REEF"
	var port_def: PortDef = null
	if port != null and port.port_def != null:
		port_def = port.port_def
		port_name = port_def.display_name
	
	EventBus.hud_message.emit(
		"RUN AGROUND AT %s — HULL DAMAGE (-%d HP)" % [port_name.to_upper(), int(dmg)],
		"alert"
	)

	if port_def != null:
		EventBus.island_collided.emit(port_def, self)


func _load_ship_class(class_id: String) -> ShipClass:
	var path := SHIP_DATA_DIR + class_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("PlayerShip: ship class '%s' not found at %s — using runtime default" % [class_id, path])
		var fallback := ShipClass.new()
		fallback.id = class_id
		return fallback
	return load(path) as ShipClass


# Player visual: a LineModel rendered as PRIMITIVE_LINES — pentagonal hull,
# masts, billowing sails with ribbing. Coordinates ported verbatim from the
# JS prototype's per-class models (see data/models/*.tres + the comment on
# each file for the JS→Godot Z-flip).
#
# Selection is class-based: we load `data/models/<ship_class_id>.tres`. If
# the file is missing (e.g. a future class added to ShipClass before its
# model is ported) we fall back to the dinghy so the player isn't invisible.
#
# `_mesh_instance` continues to point at the resulting MeshInstance3D so
# downstream code (and future tickets) that needs a "ship visual" handle
# still has one.
#
# The wireframe_material export is kept on the class for backwards-compat
# with OpenSea.tscn (until the next scene-cleaning ticket removes the
# export); it is intentionally unused here — LineModel ships its own
# unshaded-emissive StandardMaterial3D.
func _build_placeholder_mesh() -> void:
	var class_id: String = GameState.ship.ship_class_id
	var model_path := "res://data/models/" + class_id + ".tres"
	if not ResourceLoader.exists(model_path):
		push_warning("PlayerShip: ship model %s missing, falling back to dinghy" % class_id)
		model_path = "res://data/models/dinghy.tres"
	var model := load(model_path) as LineModel
	if model == null:
		push_warning("PlayerShip: ship model failed to load (%s)" % model_path)
		return

	# Player faction green per ARCHITECTURE.md § "Rendering decisions". Override
	# the model's stored colour so the resource can be reused for non-player
	# dinghies later with a different tint.
	var player_green := Color("#33ff33")
	model = model.duplicate() as LineModel
	model.color = player_green

	# JS dinghy coords are in metres. The JS canvas renderer used scale=1 for
	# the player too (game.js sea-spray block), so no extra scale is needed.
	# Player ship bumps emission energy above LineModel's default 1.5 — see
	# RenderTuning.player_ship_emission_energy. Bloom is exponential past the
	# HDR threshold, so a higher multiplier reads as thicker on screen even
	# though PRIMITIVE_LINES can't actually change line pixel width.
	var render_tuning := load("res://data/tuning/render.tres") as RenderTuning
	var emission_energy: float = 1.5
	if render_tuning != null:
		emission_energy = render_tuning.player_ship_emission_energy
	var inst := model.build_mesh_instance(1.0, emission_energy)
	inst.name = "ShipVisual"
	_mesh_instance = inst
	# Hold refs so _tick_sail_deformation can rebuild the existing mesh each
	# frame at open_factor = _sail_level / 4. The model is the (already
	# duplicated) per-instance copy — safe to keep.
	_ship_model = model
	_ship_mesh = inst.mesh as ImmediateMesh
	add_child(inst)
	# Apply initial deformation so the boot-state sail level matches what the
	# player will see in the first physics tick.
	_tick_sail_deformation()


func get_ship_model() -> LineModel:
	return _ship_model


# Rebuilds the ship mesh and reloads the ShipClass resource when the class is changed at runtime (T38 dev menu).
func update_ship_class() -> void:
	var old_visual := get_node_or_null("ShipVisual")
	if old_visual != null:
		old_visual.queue_free()
	
	ship_class = _load_ship_class(GameState.ship.ship_class_id)
	_build_placeholder_mesh()

