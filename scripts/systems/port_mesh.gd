# PortMesh — placeholder island + lighthouse mesh builder.
#
# Produces a low-poly visual for a PortDef so the player can see ports at sea
# and crash into them. Geometry is intentionally crude (a cone + a cylinder
# stack) — T09 owns the final wireframe-shaded look.
#
# JS reference: game.js:3012-3042 (procedural topographic islands + lighthouse
# + spinning yellow beacon).
class_name PortMesh extends RefCounted

# Material approach mirrors player_ship.gd's placeholder: unshaded
# StandardMaterial3D with emission_energy_multiplier ~ 1.5 so the silhouette
# reads against the bloom/AgX tonemapped ocean.
const EMISSION_ENERGY: float = 1.5
const LIGHTHOUSE_COLOUR: Color = Color(1, 1, 1, 1)
const BEACON_COLOUR: Color = Color(1, 1, 0.4, 1)

# Builds the full visual for a port. Returns a Node3D parent containing the
# island mesh, lighthouse, and a beacon node that the caller can spin in
# _process. The beacon Node3D is exposed as a child named "Beacon".
static func build(port_def: PortDef) -> Node3D:
	var root := Node3D.new()
	root.name = "PortVisual"

	# Island: stretched cylinder. Radius == port.size at the waterline, tapering
	# narrower as it rises. CylinderMesh's top/bottom radius gives us that for
	# free.
	var island := MeshInstance3D.new()
	island.name = "Island"
	var island_mesh := CylinderMesh.new()
	island_mesh.bottom_radius = port_def.size
	island_mesh.top_radius = port_def.size * 0.55
	island_mesh.height = port_def.height
	island_mesh.radial_segments = 12
	island_mesh.rings = 2
	island.mesh = island_mesh
	island.material_override = _make_emissive_material(port_def.color)
	# CylinderMesh is centred at origin; lift so the base sits at y=0 (waterline).
	island.position = Vector3(0.0, port_def.height * 0.5, 0.0)
	root.add_child(island)

	# Lighthouse: a thin column + a small cap, anchored on the island summit.
	# JS lighthousePos.y == port.height — same here.
	var lh_root := Node3D.new()
	lh_root.name = "Lighthouse"
	lh_root.position = Vector3(0.0, port_def.height, 0.0)
	root.add_child(lh_root)

	var lh_column := MeshInstance3D.new()
	lh_column.name = "Column"
	var column_mesh := CylinderMesh.new()
	column_mesh.bottom_radius = 1.2
	column_mesh.top_radius = 0.9
	column_mesh.height = 4.0
	column_mesh.radial_segments = 8
	lh_column.mesh = column_mesh
	lh_column.material_override = _make_emissive_material(LIGHTHOUSE_COLOUR)
	lh_column.position = Vector3(0.0, 2.0, 0.0)
	lh_root.add_child(lh_column)

	var lh_cap := MeshInstance3D.new()
	lh_cap.name = "Cap"
	var cap_mesh := CylinderMesh.new()
	# Small cone — bottom > top radius gives a tapered hat.
	cap_mesh.bottom_radius = 1.3
	cap_mesh.top_radius = 0.1
	cap_mesh.height = 1.2
	cap_mesh.radial_segments = 8
	lh_cap.mesh = cap_mesh
	lh_cap.material_override = _make_emissive_material(LIGHTHOUSE_COLOUR)
	lh_cap.position = Vector3(0.0, 4.6, 0.0)
	lh_root.add_child(lh_cap)

	# Beacon: a Node3D that the Port script spins in _process. Carries a thin
	# yellow box stretched forward — a cheap "rotating spotlight beam" stand-in.
	var beacon := Node3D.new()
	beacon.name = "Beacon"
	beacon.position = Vector3(0.0, 4.0, 0.0)
	lh_root.add_child(beacon)

	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.2, 0.2, 8.0)
	beam.mesh = beam_mesh
	beam.material_override = _make_emissive_material(BEACON_COLOUR)
	# Anchor one end at the lighthouse and extend along -Z (Godot forward).
	beam.position = Vector3(0.0, 0.0, -4.0)
	beacon.add_child(beam)

	return root


static func _make_emissive_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = EMISSION_ENERGY
	mat.disable_fog = true
	return mat
