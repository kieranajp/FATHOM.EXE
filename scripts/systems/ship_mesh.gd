# ShipMesh — placeholder composite ship-mesh builder.
#
# Returns a Node3D containing the silhouette parts (hull, bowsprit, mast, yard,
# sail) each as a `MeshInstance3D` so the wireframe shader's per-face UV edge
# detection draws clean rectangular outlines.
#
# Geometry is intentionally box-only: the wireframe shader's UV-based edge
# detection works cleanly on BoxMesh / QuadMesh (per-face UVs) but renders only
# a single seam on CylinderMesh — see `port_mesh.gd` for the matching note.
#
# Inspired by the JS prototype's dinghy / sloop in models3d.js (see
# `main:models3d.js`), but boxified — a future post-parity ticket may swap in
# proper hand-modelled hull/sail geometry per ship class.
#
# Local convention: Godot +Y up, -Z forward (matches PlayerShip yaw=0 → -Z).
class_name ShipMesh extends RefCounted


# Builds a composite player-ship visual. Caller supplies the wireframe
# ShaderMaterial template (typically from the OpenSea.tscn sub-resource) plus
# the colour/intensity/edge-thickness so each part shares one configured
# material instance.
#
# Returns the assembled Node3D plus the hull MeshInstance3D as a convenience
# (PlayerShip used to keep `_mesh_instance = hull` so existing references stay
# intact).
static func build_player(
	wireframe_material: ShaderMaterial,
	glow_color_v3: Vector3,
	glow_intensity: float,
	edge_thickness: float
) -> Dictionary:
	var root := Node3D.new()
	root.name = "ShipVisual"

	# One material shared across all parts — same colour and look. Duplicate the
	# template so per-instance shader params don't leak back into the scene
	# sub-resource. If the caller didn't supply one, build a fresh ShaderMaterial
	# from the wireframe shader so headless tests can still use this helper.
	var mat: ShaderMaterial
	if wireframe_material != null:
		mat = wireframe_material.duplicate() as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/wireframe.gdshader")
	mat.set_shader_parameter("glow_color", glow_color_v3)
	mat.set_shader_parameter("glow_intensity", glow_intensity)
	mat.set_shader_parameter("edge_thickness", edge_thickness)

	# --- Hull: long box along -Z (forward). Lowered slightly so the deck reads
	# near the waterline. Box edges render cleanly under the wireframe shader.
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(2.0, 1.0, 5.0)
	hull.mesh = hull_mesh
	hull.material_override = mat
	# Top of hull at y ≈ 0.5 — visible above waterline; centre at y=0.
	hull.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(hull)

	# --- Bowsprit: thin spar jutting forward off the bow. Forward = -Z.
	var bowsprit := MeshInstance3D.new()
	bowsprit.name = "Bowsprit"
	var bow_mesh := BoxMesh.new()
	bow_mesh.size = Vector3(0.2, 0.2, 1.5)
	bowsprit.mesh = bow_mesh
	bowsprit.material_override = mat
	# Half the bowsprit length past the bow (hull bow at z = -2.5).
	bowsprit.position = Vector3(0.0, 0.45, -2.5 - 0.75)
	root.add_child(bowsprit)

	# --- Mast: vertical box rising from amidships.
	var mast := MeshInstance3D.new()
	mast.name = "Mast"
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(0.2, 4.0, 0.2)
	mast.mesh = mast_mesh
	mast.material_override = mat
	# Mast base at deck (y=0.5), top at y=4.5 — so centre is y=2.5.
	mast.position = Vector3(0.0, 2.5, 0.0)
	root.add_child(mast)

	# --- Yard arm: horizontal box near the top of the mast, perpendicular to
	# the bowsprit. Spans ±X.
	var yard := MeshInstance3D.new()
	yard.name = "Yard"
	var yard_mesh := BoxMesh.new()
	yard_mesh.size = Vector3(3.0, 0.15, 0.15)
	yard.mesh = yard_mesh
	yard.material_override = mat
	# Near top of mast at y=4.3.
	yard.position = Vector3(0.0, 4.3, 0.0)
	root.add_child(yard)

	# --- Sail: flat quad hung below the yard. PlaneMesh has 4 edges per face
	# (per-face UVs) so the wireframe shader will draw a rectangle. The diagonal
	# triangulation seam isn't a UV edge so it won't appear — that's fine.
	var sail := MeshInstance3D.new()
	sail.name = "Sail"
	var sail_mesh := PlaneMesh.new()
	sail_mesh.size = Vector2(2.8, 3.0)
	# PlaneMesh defaults orient FACE_Y (lying flat). Rotate to face along ±Z so
	# the sail stands vertical underneath the yard.
	sail_mesh.orientation = PlaneMesh.FACE_Z
	sail.mesh = sail_mesh
	sail.material_override = mat
	# Centre the sail vertically between the yard (y=4.3) and the deck (y=0.5).
	# Mid-point ≈ y=2.8; slight forward bias so it reads as a billowing front sail.
	sail.position = Vector3(0.0, 2.8, 0.1)
	root.add_child(sail)

	return {"root": root, "hull": hull}
