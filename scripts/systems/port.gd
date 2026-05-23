# Port — typed wrapper around a PortDef in the scene tree.
#
# Replaces T02's `Node3D.set_meta("port_def", …)` convention with a real class
# so downstream tickets can read `port.port_def.id` / `port.port_def.faction_id`
# without going through `get_meta`.
#
# Lifecycle: OpenSea instantiates a Port per port in the current archipelago,
# sets `port_def`, adds it to the scene. _ready spawns the mesh + adds the node
# to the "port" group so player_ship.gd's collision iterator picks it up.
class_name Port extends Node3D

@export var port_def: PortDef
@export var tuning: DockTuning

var _beacon: Node3D


func _ready() -> void:
	if port_def == null:
		push_warning("Port: no port_def assigned; not added to scene")
		return

	if tuning == null:
		tuning = Tunings.dock

	add_to_group("port")
	global_position = port_def.position

	var visual := PortMesh.build(port_def)
	add_child(visual)
	_beacon = visual.get_node_or_null("Lighthouse/Beacon") as Node3D


func _process(delta: float) -> void:
	if _beacon != null and tuning != null:
		_beacon.rotate_y(tuning.beacon_spin_rate * delta)


# Pure proximity check — extracted as a static so test/test_port_proximity.gd
# can call it without spinning up a scene tree.
#
# Returns true when the player is within `port_size + threshold` of the port
# on the XZ plane. Y is ignored (ships float on the surface; ports are anchored
# to the seabed but only their footprint matters for proximity).
#
# JS reference: game.js:2909 — `dist < port.size + 15`. We treat the comparison
# as strict-less-than to match.
static func is_in_proximity(
	player_pos: Vector3,
	port_pos: Vector3,
	port_size: float,
	threshold: float
) -> bool:
	var dx: float = port_pos.x - player_pos.x
	var dz: float = port_pos.z - player_pos.z
	return Vector2(dx, dz).length() < port_size + threshold
