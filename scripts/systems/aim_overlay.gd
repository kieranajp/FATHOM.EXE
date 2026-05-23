# AimOverlay — 3D trajectory + reticle drawn while aim mode is active.
#
# Lives as a sibling under OpenSea so the WorldEnvironment glow applies. Uses
# ImmediateMesh + PRIMITIVE_LINES per the ARCHITECTURE.md convention for
# per-frame-regenerated geometry (same pattern as Ocean / LineModel).
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
# Dashing is faked by emitting short line segments with gaps — PRIMITIVE_LINES
# requires explicit vertex pairs.
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

	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "AimLines"
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = _material
	_mesh_instance.extra_cull_margin = 4096.0
	add_child(_mesh_instance)
	_mesh_instance.visible = false


func _process(_delta: float) -> void:
	var aim: Dictionary = World.aim_state
	if aim == null or aim.is_empty() or _player == null or tuning == null:
		_mesh_instance.visible = false
		return
	_mesh_instance.visible = true
	_rebuild(aim)


func _rebuild(aim: Dictionary) -> void:
	var side: String = String(aim.get("side", "starboard"))
	var fire_yaw: float = _player.yaw - PI / 2.0 if side == "port" else _player.yaw + PI / 2.0
	var hr: float = _player.ship_class.hit_radius if _player.ship_class != null else 3.0

	var start := Vector3(
		_player.global_position.x + sin(fire_yaw) * hr,
		_player.global_position.y + 1.0,
		_player.global_position.z + cos(fire_yaw) * hr,
	)
	var reticle: Vector3 = aim.get("reticle", Vector3.ZERO)

	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# 1. Cone boundaries (dashed) — sea-level lines at fire_yaw ±π/4 out to max.
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

	# 5. Crosshair: four short arms through the reticle along world axes.
	_emit_crosshair(reticle)

	_mesh.surface_end()


func _emit_dashed_line(a: Vector3, b: Vector3, dash_len: float, gap_len: float) -> void:
	var dir: Vector3 = b - a
	var total: float = dir.length()
	if total <= 0.0001:
		return
	dir = dir / total
	var t: float = 0.0
	while t < total:
		var t_end: float = minf(total, t + dash_len)
		_mesh.surface_add_vertex(a + dir * t)
		_mesh.surface_add_vertex(a + dir * t_end)
		t = t_end + gap_len


# Emits a parabolic curve from `start` to `target` modelling the same vy
# ballistic solution Combat uses. Skipping the muzzle velocity wash — we
# directly recompute the segments from the analytical solution.
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
		_mesh.surface_add_vertex(prev)
		_mesh.surface_add_vertex(curr)
		prev = curr


func _emit_ring(center: Vector3, radius: float, segments: int) -> void:
	var prev := Vector3(center.x + radius, 0.0, center.z)
	for i in range(1, segments + 1):
		var theta: float = float(i) / float(segments) * TAU
		var curr := Vector3(
			center.x + cos(theta) * radius,
			0.0,
			center.z + sin(theta) * radius,
		)
		_mesh.surface_add_vertex(prev)
		_mesh.surface_add_vertex(curr)
		prev = curr


func _emit_crosshair(center: Vector3) -> void:
	# X-axis arms.
	_mesh.surface_add_vertex(center + Vector3(-CROSSHAIR_HALF, 0.0, 0.0))
	_mesh.surface_add_vertex(center + Vector3(CROSSHAIR_HALF, 0.0, 0.0))
	# Y-axis arms.
	_mesh.surface_add_vertex(center + Vector3(0.0, -CROSSHAIR_HALF, 0.0))
	_mesh.surface_add_vertex(center + Vector3(0.0, CROSSHAIR_HALF, 0.0))
	# Z-axis arms.
	_mesh.surface_add_vertex(center + Vector3(0.0, 0.0, -CROSSHAIR_HALF))
	_mesh.surface_add_vertex(center + Vector3(0.0, 0.0, CROSSHAIR_HALF))
