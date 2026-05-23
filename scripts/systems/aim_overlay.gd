# AimOverlay — 3D trajectory + reticle drawn while aim mode is active.
#
# Lives as a sibling under OpenSea so the WorldEnvironment glow applies. Uses
# ThickLineRenderer (billboarded view-aligned quads) — same pipeline as the
# ship/island/lighthouse meshes — so the lines read at consistent thickness on
# 4K. Previously emitted as PRIMITIVE_LINES which is hard-coded to 1px in
# Vulkan and disappeared against the bloom on high-DPI displays.
#
# Reads World.aim_state — empty dict means hide. Player publishes the dict.
#
# Visual elements (per issue spec):
#   1. Dashed firing cone boundaries (±π/4 at 240m) — drawn as dashed lines
#   2. Solid parabolic trajectory curve to reticle
#   3. Sea-level ring at reticle XZ
#   4. Vertical height guide from sea level to reticle
#   5. Crosshair at the reticle
#
# Dashing is faked by emitting only the "drawn" segments as edge pairs (the
# undrawn gap segments are simply absent from the edge list).
class_name AimOverlay extends Node3D

@export var player_path: NodePath
@export var tuning: CombatTuning

const OVERLAY_COLOR := Color("#ff9900")
const TRAJECTORY_SEGMENTS: int = 24
const CONE_DASH_LEN: float = 4.0  # metres per dash
const CONE_DASH_GAP: float = 4.0
const HEIGHT_DASH_LEN: float = 0.6
const HEIGHT_DASH_GAP: float = 0.6
const RING_SEGMENTS: int = 16
const RING_RADIUS: float = 6.0
const CROSSHAIR_HALF: float = 1.5  # metres at reticle

var _player: PlayerShip
var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh
var _material: StandardMaterial3D
# Scratch buffers — reused per frame to avoid per-frame allocation churn.
# Cleared at the top of every _rebuild call.
var _verts: PackedVector3Array = PackedVector3Array()
var _edges: PackedInt32Array = PackedInt32Array()

# Screen-space reticle telemetry — three Labels parented under a CanvasLayer
# that follow the projected reticle position. JS reference (game.js:3260-3280)
# draws AIM/RANGE/ELEV text in monospace orange beside the reticle crosshair.
var _label_layer: CanvasLayer
var _label_aim: Label
var _label_range: Label
var _label_elev: Label
const _LABEL_PIXEL_OFFSET_X: float = 18.0  # horizontal offset to clear the crosshair
const _LABEL_LINE_HEIGHT: float = 14.0     # vertical spacing between AIM/RANGE/ELEV


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/combat.tres") as CombatTuning
	if player_path != NodePath(""):
		_player = get_node_or_null(player_path) as PlayerShip

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = OVERLAY_COLOR
	_material.emission_enabled = true
	_material.emission = OVERLAY_COLOR
	_material.emission_energy_multiplier = 1.5
	_material.disable_fog = true
	# Disable backface culling so the billboarded thick-line quads render from
	# either side regardless of camera orbit (same as LineModel._build_material).
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "AimLines"
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = _material
	_mesh_instance.extra_cull_margin = 4096.0
	add_child(_mesh_instance)
	_mesh_instance.visible = false

	_build_telemetry_labels()


# Three screen-space Labels (AIM / RANGE / ELEV) anchored to the reticle's
# projected position. CanvasLayer keeps them on top of the 3D viewport without
# interacting with the HUD's existing CanvasLayer (different layer index).
# Monospace + orange to match the JS reference's terminal-panel aesthetic.
func _build_telemetry_labels() -> void:
	_label_layer = CanvasLayer.new()
	_label_layer.name = "ReticleTelemetry"
	# Layer 0 leaves the HUD CanvasLayer (default layer=1) on top. The reticle
	# labels live in 3D space conceptually, so they live BELOW the HUD chrome.
	_label_layer.layer = 0
	add_child(_label_layer)

	_label_aim = _make_label()
	_label_range = _make_label()
	_label_elev = _make_label()
	_label_layer.add_child(_label_aim)
	_label_layer.add_child(_label_range)
	_label_layer.add_child(_label_elev)
	_label_layer.visible = false


func _make_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_color_override("font_color", OVERLAY_COLOR)
	lbl.add_theme_font_size_override("font_size", 13)
	# Drop-shadow for readability against bright sea — matches HUD label styling.
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


func _process(_delta: float) -> void:
	var aim: Dictionary = World.aim_state
	if aim == null or aim.is_empty() or _player == null or tuning == null:
		_mesh_instance.visible = false
		if _label_layer != null:
			_label_layer.visible = false
		return
	_mesh_instance.visible = true
	_rebuild(aim)
	_update_telemetry_labels(aim)


# Project the reticle into screen space and pin the three telemetry labels
# beside it. JS reference: game.js:3268-3279 — RANGE/ELEV in metres at 1dp,
# AIM line shows the active flank. Hidden when the camera can't see the
# reticle (behind the camera, off-screen) so we don't draw stale floating text.
func _update_telemetry_labels(aim: Dictionary) -> void:
	if _label_layer == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		_label_layer.visible = false
		return
	var reticle: Vector3 = aim.get("reticle", Vector3.ZERO)
	if cam.is_position_behind(reticle):
		_label_layer.visible = false
		return
	_label_layer.visible = true
	var screen: Vector2 = cam.unproject_position(reticle)

	# Match JS line ordering: AIM (above centre), RANGE (centre), ELEV/DEPTH
	# (below centre). All three offset right of the crosshair so the labels
	# don't obscure the target underneath.
	var side: String = String(aim.get("side", "starboard")).to_upper()
	var aim_range: float = float(aim.get("range", 0.0))
	var aim_height: float = float(aim.get("height", 0.0))

	_label_aim.text = "AIM: %s FLANK" % side
	_label_range.text = "RANGE: %dm" % int(round(aim_range))
	_label_elev.text = _format_elev_text(aim_height)

	# JS reference (game.js:3270-3274) positions the three lines at y-12 / y / y+12
	# relative to the crosshair centre, with textX = screenPos.x + size + 12.
	_label_aim.position = screen + Vector2(_LABEL_PIXEL_OFFSET_X, -_LABEL_LINE_HEIGHT)
	_label_range.position = screen + Vector2(_LABEL_PIXEL_OFFSET_X, 0.0)
	_label_elev.position = screen + Vector2(_LABEL_PIXEL_OFFSET_X, _LABEL_LINE_HEIGHT)


# Static so the format string contract can be pinned by a unit test without
# instancing AimOverlay + a scene tree.
static func _format_elev_text(height_m: float) -> String:
	if height_m >= 0.0:
		return "ELEV: +%dm" % int(round(height_m))
	# JS uses "DEPTH:" for negative aim — the cannon can't shoot below the
	# waterline so this is mainly used to flag wave troughs / sinking targets.
	return "DEPTH: %dm" % int(round(height_m))


# Public-but-underscored entry — exercised by test_aim_overlay.gd. Synthetic aim
# state is fed in and the resulting (_verts, _edges) buffers are inspected.
func _rebuild(aim: Dictionary) -> void:
	_verts.clear()
	_edges.clear()

	var side: String = String(aim.get("side", "starboard"))
	var fire_yaw: float = _player.yaw - PI / 2.0 if side == "port" else _player.yaw + PI / 2.0
	var hr: float = _player.ship_class.hit_radius if _player.ship_class != null else 3.0

	var start := Vector3(
		_player.global_position.x + sin(fire_yaw) * hr,
		_player.global_position.y + 1.0,
		_player.global_position.z + cos(fire_yaw) * hr,
	)
	var reticle: Vector3 = aim.get("reticle", Vector3.ZERO)

	# 1. Cone boundaries (dashed) — sea-level lines at fire_yaw ±aim_yaw_max.
	var max_range: float = tuning.aim_range_max
	var left_end := Vector3(
		_player.global_position.x + sin(fire_yaw - tuning.aim_yaw_max) * max_range,
		0.0,
		_player.global_position.z + cos(fire_yaw - tuning.aim_yaw_max) * max_range,
	)
	var right_end := Vector3(
		_player.global_position.x + sin(fire_yaw + tuning.aim_yaw_max) * max_range,
		0.0,
		_player.global_position.z + cos(fire_yaw + tuning.aim_yaw_max) * max_range,
	)
	_emit_dashed_line(
		Vector3(start.x, 0.0, start.z), left_end, CONE_DASH_LEN, CONE_DASH_GAP,
	)
	_emit_dashed_line(
		Vector3(start.x, 0.0, start.z), right_end, CONE_DASH_LEN, CONE_DASH_GAP,
	)

	# 2. Parabolic trajectory (solid). Same physics as Combat._spawn_ball_or_chain.
	_emit_trajectory(start, reticle)

	# 3. Sea-level ring at reticle XZ.
	_emit_ring(reticle, RING_RADIUS, RING_SEGMENTS)

	# 4. Vertical height guide (dashed) from sea level to reticle.
	_emit_dashed_line(
		Vector3(reticle.x, 0.0, reticle.z),
		reticle,
		HEIGHT_DASH_LEN, HEIGHT_DASH_GAP,
	)

	# 5. Crosshair: short axis-aligned arms through the reticle.
	_emit_crosshair(reticle)

	# Hand off to ThickLineRenderer. Camera resolves via viewport; in headless
	# tests get_camera_3d() returns null — in that case we still want the buffers
	# populated (for assertion) but skip the actual triangle emission.
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		_mesh.clear_surfaces()
		return
	var render_tuning := load("res://data/tuning/render.tres") as RenderTuning
	var thickness: float = 0.04
	if render_tuning != null:
		thickness = render_tuning.line_thickness_world
	ThickLineRenderer.rebuild(
		_mesh,
		_verts,
		_edges,
		cam.global_position,
		thickness,
		_material,
	)


# Appends a pair of (vertex, vertex) edge endpoints into the scratch buffers,
# returning the resulting edge pair indices for the curious. Helper so the
# emitters below stay readable.
func _push_edge(a: Vector3, b: Vector3) -> void:
	var i0: int = _verts.size()
	_verts.append(a)
	_verts.append(b)
	_edges.append(i0)
	_edges.append(i0 + 1)


# Dashed line — emits the "drawn" segments only; gaps are simply absent from
# the edge list. Matches the original PRIMITIVE_LINES emission pattern.
func _emit_dashed_line(a: Vector3, b: Vector3, dash_len: float, gap_len: float) -> void:
	var dir: Vector3 = b - a
	var total: float = dir.length()
	if total <= 0.0001:
		return
	dir = dir / total
	var t: float = 0.0
	while t < total:
		var t_end: float = minf(total, t + dash_len)
		_push_edge(a + dir * t, a + dir * t_end)
		t = t_end + gap_len


# Emits a parabolic curve from `start` to `target` modelling the same vy
# ballistic solution Combat uses. The curve is sampled at TRAJECTORY_SEGMENTS
# points and emitted as consecutive straight segments — already thick-line-
# friendly.
func _emit_trajectory(start: Vector3, target: Vector3) -> void:
	var dx: float = target.x - start.x
	var dz: float = target.z - start.z
	var d: float = maxf(tuning.min_aim_distance, sqrt(dx * dx + dz * dz))
	var t_total: float = d / tuning.muzzle_velocity
	var vy_start: float = (target.y - start.y) / t_total + 0.5 * tuning.gravity * t_total
	vy_start = clampf(vy_start, tuning.vy_clamp_min, tuning.vy_clamp_max)
	var prev: Vector3 = start
	for k in range(1, TRAJECTORY_SEGMENTS + 1):
		var f: float = float(k) / float(TRAJECTORY_SEGMENTS)
		var t: float = f * t_total
		var curr := Vector3(
			start.x + dx * f,
			start.y + vy_start * t - 0.5 * tuning.gravity * t * t,
			start.z + dz * f,
		)
		_push_edge(prev, curr)
		prev = curr


# Horizontal ring as `segments` straight segments. Each segment is one edge
# pair in the buffer — ThickLineRenderer billboards each.
func _emit_ring(center: Vector3, radius: float, segments: int) -> void:
	var prev := Vector3(center.x + radius, 0.0, center.z)
	for i in range(1, segments + 1):
		var theta: float = float(i) / float(segments) * TAU
		var curr := Vector3(
			center.x + cos(theta) * radius,
			0.0,
			center.z + sin(theta) * radius,
		)
		_push_edge(prev, curr)
		prev = curr


# Three orthogonal cross arms centred on `center`. Six edge pairs total — small
# enough to enumerate inline.
func _emit_crosshair(center: Vector3) -> void:
	_push_edge(
		center + Vector3(-CROSSHAIR_HALF, 0.0, 0.0),
		center + Vector3(CROSSHAIR_HALF, 0.0, 0.0),
	)
	_push_edge(
		center + Vector3(0.0, -CROSSHAIR_HALF, 0.0),
		center + Vector3(0.0, CROSSHAIR_HALF, 0.0),
	)
	_push_edge(
		center + Vector3(0.0, 0.0, -CROSSHAIR_HALF),
		center + Vector3(0.0, 0.0, CROSSHAIR_HALF),
	)
