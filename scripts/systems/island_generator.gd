# IslandGenerator — runtime LineModel for a topographic island plinth.
#
# Direct port of JS Models3D.generateIsland (main:models3d.js:722). Replaces
# the box-mesh + wireframe-shader plinth that PortMesh used previously: that
# read as "floating yellow box at the horizon" because there were no rings,
# no peak, and no per-island shape variation.
#
# Four island types determined by abs(seed) % 4:
#   0 — volcanic dome      (uniform circular dome)
#   1 — double-peak saddle (heightMod from cos(2θ))
#   2 — barrier ridge      (elongated 1.6 × 0.6 in xz)
#   3 — crescent atoll     (radius + height mod by sin(θ))
#
# The JS deterministic RNG (`sin(s) * 10000`, fractional part) is preserved so
# the same seed produces the same island shape every session — the player can
# learn an archipelago's silhouette.
#
# AXIS CONVERSION: JS is left-handed (+Z forward); Godot is right-handed (-Z
# forward). Z-flip applied on output (vz → -vz) per LineModel convention.
class_name IslandGenerator extends RefCounted


# Mirrors JS `random(s)`: deterministic 0..1 fractional from sin(s) * 10000.
# Used as a simple per-vertex jitter source, not a real PRNG — the values
# come out lumpy by design (the JS prototype wanted "rugged" not "uniform").
static func _rand(s: float) -> float:
	var x: float = sin(s) * 10000.0
	return x - floor(x)


# Generate a topographic island LineModel.
#
# seed         — deterministic per-port int (e.g. Economy.port_seed(port.id))
# size         — outer radius of the island base (port.size)
# height_max   — peak height in metres (port.height)
# rings_count  — concentric ring count (JS default 4)
# sectors      — vertices per ring (JS default 12)
static func generate(
	island_seed: int, size: float, height_max: float, rings_count: int = 4, sectors: int = 12
) -> LineModel:
	var verts := PackedVector3Array()
	var edges := PackedInt32Array()

	var island_type: int = abs(island_seed) % 4

	# 1. Peak vertex (index 0). Saddle/atoll keep the centre low.
	var peak_height: float = height_max
	if island_type == 1:
		peak_height = height_max * 0.4
	elif island_type == 3:
		peak_height = height_max * 0.15
	verts.append(Vector3(0.0, peak_height, 0.0))  # z=0 → no flip needed

	# 2. Concentric rings. Ring 0 is innermost (high), ring rings_count-1 is
	# outermost (sea level). Per-vertex jitter via the JS sin-fract RNG.
	for r in range(rings_count):
		var fraction: float = float(r + 1) / float(rings_count)
		var radius: float = size * fraction
		var height: float = height_max * pow(1.0 - fraction, 1.5)

		for s in range(sectors):
			var angle: float = (float(s) / float(sectors)) * TAU

			var noise_seed: float = float(island_seed + r * 17 + s * 31)
			var noise_dist: float = (_rand(noise_seed) - 0.5) * (size * 0.15) * fraction
			var noise_height: float = (_rand(noise_seed + 5.0) - 0.5) * (height_max * 0.15)

			var final_radius: float = radius + noise_dist
			var vx: float = cos(angle) * final_radius
			var vz: float = sin(angle) * final_radius
			var vy: float = height + noise_height

			if island_type == 0:
				# Volcanic dome — clamp to sea level, no other mods.
				vy = maxf(0.0, vy)
			elif island_type == 1:
				# Double-peak saddle — height/radius modulate with 2θ / |cos θ|.
				var height_mod: float = 0.2 + 0.8 * (0.5 + 0.5 * cos(2.0 * angle))
				var radius_mod: float = 0.8 + 0.4 * absf(cos(angle))
				final_radius = radius * radius_mod + noise_dist
				vx = cos(angle) * final_radius
				vz = sin(angle) * final_radius
				vy = maxf(0.0, height * height_mod + noise_height)
			elif island_type == 2:
				# Elongated barrier ridge — stretch x ×1.6, squash z ×0.6.
				var height_mod_2: float = 0.6 + 0.4 * pow(absf(cos(angle)), 0.5)
				vx = cos(angle) * final_radius * 1.6
				vz = sin(angle) * final_radius * 0.6
				vy = maxf(0.0, height * height_mod_2 + noise_height)
			elif island_type == 3:
				# Crescent / atoll — open lagoon on the -sin(θ) side.
				var angle_mod: float = sin(angle)
				var radius_mod_3: float = 0.8 + 0.5 * angle_mod
				var height_mod_3: float = pow(maxf(0.0, 0.4 + 0.6 * angle_mod), 2.0)
				final_radius = radius * radius_mod_3 + noise_dist
				vx = cos(angle) * final_radius
				vz = sin(angle) * final_radius
				vy = maxf(0.0, height * height_mod_3 + noise_height)

			# Z-flip on output (JS left-handed → Godot right-handed).
			verts.append(Vector3(vx, vy, -vz))

	# 3. Edges. Peak → ring 0; concentric rings + radial spokes; optional
	# diagonal triangulation for grid-like hi-tech wireframe feel.
	# Peak (vertex 0) to ring 0 + ring-0 circumferential.
	for s in range(sectors):
		var next_sector: int = (s + 1) % sectors
		var r0_idx: int = 1 + s
		var r0_next_idx: int = 1 + next_sector
		edges.append(0)
		edges.append(r0_idx)
		edges.append(r0_idx)
		edges.append(r0_next_idx)

	# Concentric ring connections.
	for r in range(rings_count - 1):
		var ring_offset: int = 1 + r * sectors
		var next_ring_offset: int = 1 + (r + 1) * sectors
		for s in range(sectors):
			var next_sector_inner: int = (s + 1) % sectors
			var curr_v: int = ring_offset + s
			var outer_v: int = next_ring_offset + s
			var outer_v_next: int = next_ring_offset + next_sector_inner

			# Radial spoke from inner ring to outer ring.
			edges.append(curr_v)
			edges.append(outer_v)
			# Outer-ring circumferential.
			edges.append(outer_v)
			edges.append(outer_v_next)
			# Diagonal triangulation on a checkerboard pattern.
			if (s + r) % 2 == 0:
				edges.append(curr_v)
				edges.append(outer_v_next)

	var model := LineModel.new()
	model.vertices = verts
	model.edges = edges
	return model
