# PortMesh — procedural topographic island + LineModel lighthouse + beacon.
#
# Island plinth: runtime-generated via IslandGenerator (JS-port of
# Models3D.generateIsland). Replaces the box-mesh "yellow plinth" — the
# generator produces a peak, concentric rings, and per-port shape variation
# from a deterministic seed derived from port.id.
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

const LIGHTHOUSE_MODEL := preload("res://data/models/lighthouse.tres")
const BEACON_COLOUR: Color = Color(1, 0.85, 0.2, 1)

# Builds the full visual for a port. Returns a Node3D parent containing the
# island plinth, lighthouse, and a beacon node that the caller can spin in
# _process. The beacon Node3D is exposed as a child named "Beacon".
static func build(port_def: PortDef) -> Node3D:
	var root := Node3D.new()
	root.name = "PortVisual"

	# All meshes use ThickLineMesh for resolution-independent line width.
	# See RenderTuning.line_thickness_world. Lighthouse + island also bump
	# emission to read crisply at distance, and use distance-linear thickness
	# scaling so the ribbon stays visible at the ~540m chase-cam range to a
	# distant island. Without scaling the authored 0.06m ribbon subtends
	# ~0.1px at that distance and effectively vanishes.
	var render_tuning := load("res://data/tuning/render.tres") as RenderTuning
	var lh_emission: float = 1.5
	var thickness: float = 0.04
	var ref_dist: float = 0.0
	if render_tuning != null:
		lh_emission = render_tuning.lighthouse_emission_energy
		thickness = render_tuning.line_thickness_world
		ref_dist = render_tuning.line_thickness_reference_distance

	# Island: procedural topographic LineModel. Seed deterministically off the
	# port id so the same port reads the same silhouette every session — same
	# pattern Economy uses for stocks/pricing (see Economy.port_seed).
	var island_seed: int = _port_id_seed(port_def.id)
	var island_model := IslandGenerator.generate(island_seed, port_def.size, port_def.height)
	island_model.color = port_def.color
	var island := island_model.build_thick_mesh_instance(1.0, thickness, 1.5, ref_dist)
	island.name = "Island"
	root.add_child(island)

	# Lighthouse: LineModel anchored on the island summit. The JS lighthouse
	# has y=0..15.5 so it sits on top with no extra Y offset.
	var lh_root := Node3D.new()
	lh_root.name = "Lighthouse"
	lh_root.position = Vector3(0.0, port_def.height, 0.0)
	root.add_child(lh_root)

	var lh_mesh := LIGHTHOUSE_MODEL.build_thick_mesh_instance(1.0, thickness, lh_emission, ref_dist)
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
	var beam := beam_model.build_thick_mesh_instance(1.0, thickness, 1.5, ref_dist)
	beam.name = "Beam"
	beacon.add_child(beam)

	return root


# Deterministic seed from port id — same algorithm as Economy.port_seed (sum
# of unicode codepoints). Duplicated rather than imported because Economy is
# an autoload singleton and this static builder is called before scene-tree
# entry in some test paths. Keep them numerically identical.
static func _port_id_seed(port_id: String) -> int:
	var total: int = 0
	for i in range(port_id.length()):
		total += port_id.unicode_at(i)
	return total
