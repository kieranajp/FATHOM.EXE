# IslandGenerator — regression tests for the JS-ported procedural island.
#
# Load-bearing because the generator's edge layout has to satisfy LineModel's
# "edges is flat (i0, i1, …) pairs" invariant, and the four island-type code
# paths each have their own vertex placement. A regression in any one of
# those branches is invisible to gameplay but ugly on screen.
#
# See scripts/systems/island_generator.gd, scripts/systems/port_mesh.gd.
extends GutTest


func test_same_seed_same_vertices() -> void:
	var a := IslandGenerator.generate(42, 25.0, 15.0)
	var b := IslandGenerator.generate(42, 25.0, 15.0)
	assert_eq(a.vertices.size(), b.vertices.size())
	assert_eq(a.edges.size(), b.edges.size())
	for i in range(a.vertices.size()):
		assert_eq(a.vertices[i], b.vertices[i], "Vertex %d should match" % i)


func test_vertex_count_matches_formula() -> void:
	# 1 peak + rings_count * sectors ring vertices.
	var m := IslandGenerator.generate(1, 25.0, 15.0, 4, 12)
	assert_eq(m.vertices.size(), 1 + 4 * 12, "1 peak + 4 rings × 12 sectors")


func test_edges_are_flat_pairs() -> void:
	var m := IslandGenerator.generate(1, 25.0, 15.0)
	assert_eq(m.edges.size() % 2, 0, "Edge count must be even (flat pairs)")


func test_no_out_of_range_edge_indices() -> void:
	var m := IslandGenerator.generate(7, 25.0, 15.0)
	var n := m.vertices.size()
	for e in m.edges:
		assert_true(e >= 0, "Edge index >= 0")
		assert_true(e < n, "Edge index %d < vertex count %d" % [e, n])


func test_peak_is_vertex_zero_and_centered() -> void:
	# Peak is always vertex 0 — port_mesh and any caller relies on this.
	var m := IslandGenerator.generate(0, 25.0, 15.0)
	assert_eq(m.vertices[0].x, 0.0, "Peak x = 0")
	assert_eq(m.vertices[0].z, 0.0, "Peak z = 0")
	assert_true(m.vertices[0].y > 0.0, "Peak y > 0")


func test_each_island_type_produces_wellformed_model() -> void:
	# abs(seed) % 4 → 0..3 — cover every branch. Seeds chosen so abs(s)%4
	# hits each of 0, 1, 2, 3 in turn.
	for type_idx in range(4):
		var m := IslandGenerator.generate(type_idx, 25.0, 15.0)
		assert_true(m.vertices.size() > 0, "Type %d has vertices" % type_idx)
		assert_true(m.edges.size() > 0, "Type %d has edges" % type_idx)
		assert_eq(m.edges.size() % 2, 0, "Type %d edges are paired" % type_idx)


func test_saddle_peak_is_lower_than_dome() -> void:
	# Island type 1 (saddle, seed %4 == 1) lowers the peak to 0.4 × height_max.
	# Island type 0 (dome, seed %4 == 0) keeps full height. Pinning the
	# height-mod branches so a regression in those lines stays visible.
	var dome := IslandGenerator.generate(0, 25.0, 15.0)
	var saddle := IslandGenerator.generate(1, 25.0, 15.0)
	assert_almost_eq(dome.vertices[0].y, 15.0, 1e-4, "Dome peak = height_max")
	assert_almost_eq(saddle.vertices[0].y, 6.0, 1e-4, "Saddle peak = 0.4 × height_max")


func test_atoll_peak_is_shallow() -> void:
	# Island type 3 (atoll) caps the peak at 0.15 × height_max.
	var atoll := IslandGenerator.generate(3, 25.0, 15.0)
	assert_almost_eq(atoll.vertices[0].y, 2.25, 1e-4, "Atoll peak = 0.15 × height_max")


func test_outer_ring_radius_scales_with_size() -> void:
	# Outer ring (r = rings_count-1) vertices should sit roughly at size
	# distance from centre (dome type — no x/z mods). Allow JS-rng noise of
	# ~15% × size for jitter.
	var m := IslandGenerator.generate(0, 100.0, 50.0, 4, 12)
	# First outer-ring vertex index: 1 + (rings_count-1) * sectors = 1 + 3*12 = 37.
	var v := m.vertices[37]
	var r2 := v.x * v.x + v.z * v.z
	assert_true(r2 > 70.0 * 70.0, "Outer ring radius > 70 (≈85% of size)")
	assert_true(r2 < 130.0 * 130.0, "Outer ring radius < 130 (≈115% of size)")
