# Ocean — single source of truth for sea elevation, and the wave grid renderer.
#
# CONTRACT (see docs/ARCHITECTURE.md § "The wave-height contract"):
#   Anything that needs sea elevation calls get_wave_height(x, z). The formula
#   lives here exactly once. No copies anywhere else in the repo.
#
# Rendering: per-frame ImmediateMesh of cyan grid lines around the tracked
# position (player, or camera as fallback). Final styling (glow, scanlines)
# lands with T09 — this ticket only emits a plain unshaded line grid.
class_name Ocean extends Node3D

# Optional explicit player node. If unset (or invalid at runtime) the grid
# falls back to following the first Camera3D it can find — this lets the
# smoke scene work standalone before T02 lands the player ship.
@export var player_path: NodePath = ^""
@export var tuning: WorldTuning

const GRID_COLOR := Color("#00ffcc")

# A line snapped to an 8-unit cell drifts visibly as the camera moves; snapping
# the grid origin to the spacing makes the lattice feel stationary in worldspace
# while still rendering only the local neighbourhood. Cheap and worth it.
var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _material: StandardMaterial3D
var _fallback_camera: Camera3D


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/world.tres") as WorldTuning

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = GRID_COLOR
	_material.emission_enabled = true
	_material.emission = GRID_COLOR
	_material.emission_energy_multiplier = 1.5
	_material.vertex_color_use_as_albedo = false
	_material.disable_fog = true

	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Grid"
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.material_override = _material
	# Grid is huge and regenerates around the camera every frame — culling it
	# by its (always stale) AABB causes flicker, so we mark it always-visible.
	_mesh_instance.extra_cull_margin = 16384.0
	add_child(_mesh_instance)


# THE wave-height formula. Ported from the JS prototype (engine3d.js:202 et al).
# t is in seconds since boot. Hardcoded constants are part of the equation, not
# tuning — tunable visual params (radius, spacing) live in WorldTuning.
func get_wave_height(x: float, z: float) -> float:
	var t: float = Time.get_ticks_msec() / 1000.0
	var w1: float = sin(x * 0.05 + t * 1.5) * cos(z * 0.05 + t * 1.2) * 1.6
	var w2: float = sin(z * 0.12 - t * 2.0) * 0.5
	return w1 + w2


func _process(_delta: float) -> void:
	var center: Vector3 = _resolve_center()
	_rebuild_grid(center)


func _resolve_center() -> Vector3:
	if player_path != ^"":
		var node := get_node_or_null(player_path)
		if node is Node3D:
			return (node as Node3D).global_position
	if _fallback_camera == null or not is_instance_valid(_fallback_camera):
		_fallback_camera = get_viewport().get_camera_3d()
	if _fallback_camera != null:
		return _fallback_camera.global_position
	return Vector3.ZERO


func _rebuild_grid(center: Vector3) -> void:
	var radius: float = tuning.grid_radius
	var spacing: float = tuning.grid_spacing
	# Snap origin to spacing so the lattice stays put in world space.
	var cx: float = floor(center.x / spacing) * spacing
	var cz: float = floor(center.z / spacing) * spacing
	var line_count: int = int(radius / spacing)

	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# X-aligned lines (constant z, varying x): one per row.
	for i in range(-line_count, line_count + 1):
		var z: float = cz + i * spacing
		_emit_line_along_x(cx - radius, cx + radius, z, spacing)

	# Z-aligned lines (constant x, varying z): one per column.
	for i in range(-line_count, line_count + 1):
		var x: float = cx + i * spacing
		_emit_line_along_z(x, cz - radius, cz + radius, spacing)

	_immediate_mesh.surface_end()


# Emit a polyline sampled at `spacing` along X, with y = get_wave_height(x,z).
# PRIMITIVE_LINES needs paired vertices, so each segment goes (prev, curr).
func _emit_line_along_x(x_start: float, x_end: float, z: float, spacing: float) -> void:
	var x: float = x_start
	var prev := Vector3(x, get_wave_height(x, z), z)
	x += spacing
	while x <= x_end + 0.0001:
		var curr := Vector3(x, get_wave_height(x, z), z)
		_immediate_mesh.surface_add_vertex(prev)
		_immediate_mesh.surface_add_vertex(curr)
		prev = curr
		x += spacing


func _emit_line_along_z(x: float, z_start: float, z_end: float, spacing: float) -> void:
	var z: float = z_start
	var prev := Vector3(x, get_wave_height(x, z), z)
	z += spacing
	while z <= z_end + 0.0001:
		var curr := Vector3(x, get_wave_height(x, z), z)
		_immediate_mesh.surface_add_vertex(prev)
		_immediate_mesh.surface_add_vertex(curr)
		prev = curr
		z += spacing
