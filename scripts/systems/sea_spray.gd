# SeaSpray — cyan particles drifting around the player. Sells motion + scale.
#
# Port of the JS prototype's `world.particles` (game.js:556 init, :2892 recycle,
# :3044 render). Each particle is a tiny emissive BoxMesh that rides the wave
# surface. When a particle drifts more than `spray_radius` from the player on
# either axis we wrap it to the opposite side — same trick the JS does.
#
# Position update happens in _process so the wave-ride stays synced with the
# camera's frame-rate. Cheap: ~80 BoxMeshes is nothing on a desktop GPU and the
# wave-height call is the same single source-of-truth function ships use.
class_name SeaSpray extends Node3D

@export var tuning: WorldTuning
@export var ocean_path: NodePath
@export var player_path: NodePath

const SPRAY_COLOUR := Color("#00ffff")
const WAVE_Y_OFFSET: float = -0.5  # JS sinks particles 0.5m below the surface

var _ocean: Ocean
var _player: Node3D
var _particles: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/world.tres") as WorldTuning

	if ocean_path != NodePath(""):
		var on := get_node_or_null(ocean_path)
		if on is Ocean:
			_ocean = on as Ocean
	if player_path != NodePath(""):
		var pn := get_node_or_null(player_path)
		if pn is Node3D:
			_player = pn as Node3D

	# Shared mesh + material — cuts allocation cost. Per-instance state lives on
	# the MeshInstance3D transform; no per-particle material variation needed.
	var box := BoxMesh.new()
	var s: float = tuning.spray_size
	box.size = Vector3(s, s, s)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SPRAY_COLOUR
	mat.emission_enabled = true
	mat.emission = SPRAY_COLOUR
	mat.emission_energy_multiplier = 1.5
	mat.disable_fog = true

	# Seed at deterministic positions so the field doesn't shimmer differently
	# across boots — playtesting reproducibility is worth a fixed seed.
	_rng.seed = 0x5EA5_FA7E

	var origin: Vector3 = _player_pos()
	for _i in range(tuning.spray_particle_count):
		var inst := MeshInstance3D.new()
		inst.mesh = box
		inst.material_override = mat
		var x: float = origin.x + (_rng.randf() - 0.5) * tuning.spray_radius * 2.0
		var z: float = origin.z + (_rng.randf() - 0.5) * tuning.spray_radius * 2.0
		var y: float = _wave_y(x, z)
		inst.position = Vector3(x, y, z)
		add_child(inst)
		_particles.append(inst)


func _process(_delta: float) -> void:
	if _particles.is_empty():
		return
	var origin: Vector3 = _player_pos()
	var r: float = tuning.spray_radius
	for inst in _particles:
		var p: Vector3 = inst.position
		# Wrap on each axis when the particle drifts past ±radius from the
		# player. Mirror of JS game.js:2895-2900.
		var dx: float = p.x - origin.x
		var dz: float = p.z - origin.z
		if dx < -r:
			p.x += r * 2.0
		elif dx > r:
			p.x -= r * 2.0
		if dz < -r:
			p.z += r * 2.0
		elif dz > r:
			p.z -= r * 2.0
		p.y = _wave_y(p.x, p.z)
		inst.position = p


func _player_pos() -> Vector3:
	if _player != null and is_instance_valid(_player):
		return _player.global_position
	return Vector3.ZERO


func _wave_y(x: float, z: float) -> float:
	# Single source of truth — only Ocean owns the wave formula (see
	# ARCHITECTURE.md § "The wave-height contract"). Fall back to a flat surface
	# if the ocean isn't wired up yet (headless tests, smoke scenes).
	if _ocean != null:
		return _ocean.get_wave_height(x, z) + WAVE_Y_OFFSET
	return WAVE_Y_OFFSET
