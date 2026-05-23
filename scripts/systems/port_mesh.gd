# PortMesh — placeholder island + lighthouse mesh builder.
#
# Produces a low-poly visual for a PortDef so the player can see ports at sea
# and crash into them. Box-only geometry — the wireframe shader's UV-based edge
# detection works cleanly on per-face-UV meshes (BoxMesh, PlaneMesh) but only
# the U seam reads as an edge on CylinderMesh. Sticking to boxes gives crisp
# vector silhouettes for the island plinth + lighthouse tower + cap.
#
# JS reference: game.js:3012-3042 (procedural topographic islands + lighthouse
# + spinning yellow beacon).
class_name PortMesh extends RefCounted

const WIREFRAME_SHADER := preload("res://assets/shaders/wireframe.gdshader")
const LIGHTHOUSE_COLOUR: Color = Color(1, 1, 1, 1)
const BEACON_COLOUR: Color = Color(1, 0.85, 0.2, 1)

# Builds the full visual for a port. Returns a Node3D parent containing the
# island mesh, lighthouse, and a beacon node that the caller can spin in
# _process. The beacon Node3D is exposed as a child named "Beacon".
static func build(port_def: PortDef) -> Node3D:
	var root := Node3D.new()
	root.name = "PortVisual"

	# Island: a flat rectangular plinth. Scales to port.size × port.size at the
	# waterline. Renders as a clean rectangle outline rather than a barely-visible
	# cylinder-with-one-seam.
	var island := MeshInstance3D.new()
	island.name = "Island"
	var island_mesh := BoxMesh.new()
	# Width / depth = port footprint diameter (2 × size — size was a radius).
	island_mesh.size = Vector3(port_def.size * 2.0, port_def.height, port_def.size * 2.0)
	island.mesh = island_mesh
	island.material_override = _make_wireframe_material(port_def.color)
	# BoxMesh is centred at origin; lift so the base sits at y=0 (waterline).
	island.position = Vector3(0.0, port_def.height * 0.5, 0.0)
	root.add_child(island)

	# Lighthouse: a tall column + a small cap, anchored on the island summit.
	# JS lighthousePos.y == port.height — same here.
	var lh_root := Node3D.new()
	lh_root.name = "Lighthouse"
	lh_root.position = Vector3(0.0, port_def.height, 0.0)
	root.add_child(lh_root)

	# Column — tall thin box. Wireframe shader renders all 12 edges cleanly,
	# so the silhouette reads as a proper architectural tower.
	var lh_column := MeshInstance3D.new()
	lh_column.name = "Column"
	var column_mesh := BoxMesh.new()
	column_mesh.size = Vector3(2.0, 8.0, 2.0)
	lh_column.mesh = column_mesh
	lh_column.material_override = _make_wireframe_material(LIGHTHOUSE_COLOUR)
	# Centre lifted so the column base sits on the island summit.
	lh_column.position = Vector3(0.0, 4.0, 0.0)
	lh_root.add_child(lh_column)

	# Cap — a wider, shorter cube perched on top of the column. Yellow to match
	# the beacon, suggesting the lit chamber under the lantern room.
	var lh_cap := MeshInstance3D.new()
	lh_cap.name = "Cap"
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(2.5, 1.5, 2.5)
	lh_cap.mesh = cap_mesh
	lh_cap.material_override = _make_wireframe_material(BEACON_COLOUR)
	# Sits on top of the 8m column → centre at y = 8 + 0.75.
	lh_cap.position = Vector3(0.0, 8.75, 0.0)
	lh_root.add_child(lh_cap)

	# Beacon: a Node3D that the Port script spins in _process. Carries a thin
	# yellow box stretched forward — a cheap "rotating spotlight beam" stand-in.
	var beacon := Node3D.new()
	beacon.name = "Beacon"
	# Anchor the spinner at the centre of the cap.
	beacon.position = Vector3(0.0, 8.75, 0.0)
	lh_root.add_child(beacon)

	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.2, 0.2, 8.0)
	beam.mesh = beam_mesh
	beam.material_override = _make_wireframe_material(BEACON_COLOUR)
	# Anchor one end at the lighthouse and extend along -Z (Godot forward).
	beam.position = Vector3(0.0, 0.0, -4.0)
	beacon.add_child(beam)

	return root


static func _make_wireframe_material(colour: Color) -> ShaderMaterial:
	# Shader expects glow_color as Vector3 (not Color) — see player_ship.gd and
	# OpenSea.tscn for the same convention. Other uniforms (core_color,
	# glow_intensity, edge_thickness) keep their shader defaults; the port mesh
	# doesn't have per-instance reasons to override them.
	var mat := ShaderMaterial.new()
	mat.shader = WIREFRAME_SHADER
	mat.set_shader_parameter("glow_color", Vector3(colour.r, colour.g, colour.b))
	return mat
