# EnemyShip — non-player vessel. Pirate raiders or authority enforcers.
#
# Owns its pose (x, y, z, yaw, pitch, roll), HP, reload timers, and visual
# (LineModel mesh rebuilt from the dinghy template, tinted by faction).
#
# Lifecycle: instantiated by EnemySpawner / authority response. Driven each
# tick by CombatSystem which calls AISteering.calculate_ai_steering, updates
# pose, samples wave height, and fires broadsides via Combat.fire_broadside.
#
# Sinking: when health hits 0, CombatSystem rotates pitch/roll and descends
# the node by sink_descent_rate per second until y < sink_despawn_y, then
# removes the node.
class_name EnemyShip extends Node3D

@export var ship_class_id: String = "sloop"
@export var faction_id: String = "pirate"
@export var is_enforcer: bool = false

# Per-instance state — most are mutated by CombatSystem.
var ship_class: ShipClass
var max_health: float = 100.0
var health: float = 100.0
var speed: float = 0.0
var rudder: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var reload_port: float = 0.0
var reload_stbd: float = 0.0
var reload_timer: float = 0.0  # AI uses a single timer (mirrors JS); both sides share it
var speed_debuff_timer: float = 0.0
var is_sinking: bool = false
var target: Node = null  # PlayerShip or another enemy; AISteering reads .x/.z

# Display name for HUD lock-on. Overridable so the authority enforcer reads
# "PORT AUTHORITY GALLEON" instead of the generic class name.
var display_name: String = "PIRATE RAIDER"

# Visual.
var _line_model: LineModel
var _mesh_instance: MeshInstance3D
var _ocean: Ocean

const SHIP_DATA_DIR := "res://data/ships/"


func _ready() -> void:
	ship_class = ShipClass.load_or_default(ship_class_id)
	if ship_class != null:
		max_health = ship_class.max_health
		health = ship_class.max_health
	_build_mesh()


# Called by spawner / combat system once the node is in the tree.
func wire_ocean(ocean: Ocean) -> void:
	_ocean = ocean


func get_ocean() -> Ocean:
	return _ocean


# Returns a Dictionary snapshot of fields AISteering / Combat need.
# Mirroring is one-way: the system reads, then writes back via the public
# setters below.
func as_state_dict() -> Dictionary:
	return {
		"x": global_position.x,
		"y": global_position.y,
		"z": global_position.z,
		"yaw": yaw,
		"speed": speed,
		"rudder": rudder,
		"reload_timer": reload_timer,
		"reload_port": reload_port,
		"reload_stbd": reload_stbd,
		"base_max_speed": ship_class.base_max_speed if ship_class != null else 5.0,
		"firepower": ship_class.firepower if ship_class != null else 1,
		"hit_radius": ship_class.hit_radius if ship_class != null else 4.0,
		"hit_height": ship_class.hit_height if ship_class != null else 6.0,
		"ship_class_id": ship_class_id,
		"is_player_owned": false,
		"faction_id": faction_id,
	}


# Apply a state dictionary back to the node fields. Used by CombatSystem after
# fire_broadside / AISteering have mutated the dict in place.
func apply_state_dict(state: Dictionary) -> void:
	yaw = float(state.get("yaw", yaw))
	speed = float(state.get("speed", speed))
	rudder = float(state.get("rudder", rudder))
	reload_port = float(state.get("reload_port", reload_port))
	reload_stbd = float(state.get("reload_stbd", reload_stbd))
	# AI reload_timer mirrors whichever side just fired — keep them in sync.
	reload_timer = maxf(reload_port, reload_stbd)





# Visual: class-specific LineModel tinted by faction. Mirrors the player ship's
# load path (player_ship.gd::_build_placeholder_mesh) — we resolve a per-class
# .tres from data/models/<ship_class_id>.tres, fall back to the dinghy if it's
# missing, then override the model colour with the faction tint.
func _build_mesh() -> void:
	var model_path := "res://data/models/" + ship_class_id + ".tres"
	if not ResourceLoader.exists(model_path):
		push_warning("EnemyShip: model %s missing, falling back to dinghy" % ship_class_id)
		model_path = "res://data/models/dinghy.tres"
	var template := load(model_path) as LineModel
	if template == null:
		push_warning("EnemyShip: model failed to load (%s)" % model_path)
		return
	_line_model = template.duplicate() as LineModel
	_line_model.color = Factions.color_for(faction_id)

	# Per-class .tres already encodes silhouette + scale; build at 1.0 so the
	# authored coords win. Faction tint comes from the colour override above.
	# ThickLineMesh gives the same resolution-independent line width as the
	# player ship — see RenderTuning.line_thickness_world.
	var render_tuning := load("res://data/tuning/render.tres") as RenderTuning
	var thickness: float = 0.04
	var ref_dist: float = 0.0
	if render_tuning != null:
		thickness = render_tuning.line_thickness_world
		ref_dist = render_tuning.line_thickness_reference_distance
	# Distant enemies on the horizon get fatter ribbons to stay visible; the
	# max(1.0, dist/ref) clamp leaves nearby enemies at the authored width.
	var inst: MeshInstance3D = _line_model.build_thick_mesh_instance(1.0, thickness, 1.5, ref_dist)
	inst.name = "ShipVisual"
	_mesh_instance = inst
	add_child(inst)


# Roll/pitch are written by CombatSystem after wave sampling; the basis
# composition happens here so the node updates atomically.
func apply_transform() -> void:
	var b := Basis()
	b = b.rotated(Vector3.UP, yaw)
	b = b.rotated(b.x, pitch)
	b = b.rotated(b.z, roll)
	transform.basis = b


func get_line_model() -> LineModel:
	return _line_model
