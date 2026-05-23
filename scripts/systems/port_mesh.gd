# PortMesh — island plinth + LineModel lighthouse + spinning beacon.
#
# Island plinth: stays as a box-mesh + wireframe-shader rectangle — the JS
# prototype used a procedural topographic island we don't need to replicate
# yet; the rectangle is the simplest read of "land".
#
# Lighthouse: ported as a LineModel (octagonal base + mid ring + gallery
# flange + lantern room + peaked cap) from JS models3d.js. The wireframe
# shader can't draw any of those non-box edges so the line-primitive renderer
# does the work — same pipeline as the ocean grid.
#
# Beacon: a small spinning child node carrying a beam line-segment.
#
# JS reference: game.js:3012-3042 (procedural island + lighthouse + spinner).
class_name PortMesh extends RefCounted

const WIREFRAME_SHADER := preload("res://assets/shaders/wireframe.gdshader")
const LIGHTHOUSE_MODEL := preload("res://data/models/lighthouse.tres")
const BEACON_COLOUR: Color = Color(1, 0.85, 0.2, 1)

# Builds the full visual for a port. Returns a Node3D parent containing the
# island plinth, lighthouse, and a beacon node that the caller can spin in
# _process. The beacon Node3D is exposed as a child named "Beacon".
static func build(port_def: PortDef) -> Node3D:
	var root := Node3D.new()
	root.name = "PortVisual"

	# Island: a flat rectangular plinth. Scales to port.size × port.size at the
	# waterline. Renders as a clean rectangle outline (wireframe-shader on a box
	# IS the right tool here — all edges are box-aligned).
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

	# Lighthouse: LineModel anchored on the island summit. The JS lighthouse
	# has y=0..15.5 so it sits on top with no extra Y offset.
	var lh_root := Node3D.new()
	lh_root.name = "Lighthouse"
	lh_root.position = Vector3(0.0, port_def.height, 0.0)
	root.add_child(lh_root)

	var lh_mesh := LIGHTHOUSE_MODEL.build_mesh_instance(1.0)
	lh_mesh.name = "Tower"
	lh_root.add_child(lh_mesh)

	# Beacon: a Node3D the Port script spins in _process. Carries a beam line
	# segment (also a LineModel so it blooms via the same emissive pipeline).
	var beacon := Node3D.new()
	beacon.name = "Beacon"
	# Anchor the spinner at the centre of the lantern room (~y=14 in lighthouse
	# local coords; lh_root is already lifted by port.height so this is local).
	beacon.position = Vector3(0.0, 14.0, 0.0)
	lh_root.add_child(beacon)

	var beam_model := LineModel.new()
	beam_model.color = BEACON_COLOUR
	# Beam goes from the lantern outward along -Z (Godot forward). 8m long
	# matches the previous box-beam length.
	beam_model.vertices = PackedVector3Array(
		[Vector3.ZERO, Vector3(0.0, 0.0, -8.0)]
	)
	beam_model.edges = PackedInt32Array([0, 1])
	var beam := beam_model.build_mesh_instance(1.0)
	beam.name = "Beam"
	beacon.add_child(beam)

	return root


static func _make_wireframe_material(colour: Color) -> ShaderMaterial:
	# Shader expects glow_color as Vector3 (not Color) — see OpenSea.tscn for
	# the same convention. Other uniforms (core_color, glow_intensity,
	# edge_thickness) keep their shader defaults; the island plinth doesn't
	# have per-instance reasons to override them.
	var mat := ShaderMaterial.new()
	mat.shader = WIREFRAME_SHADER
	mat.set_shader_parameter("glow_color", Vector3(colour.r, colour.g, colour.b))
	return mat
