# Unit tests for RenderTuning and render.tres setup.
extends GutTest


func test_tuning_class_instantiation() -> void:
	var tuning := RenderTuning.new()
	assert_not_null(tuning, "RenderTuning should instantiate successfully")
	assert_eq(tuning.wireframe_glow_intensity, 4.0, "Should default to 4.0 glow intensity")
	assert_eq(tuning.wireframe_edge_thickness, 0.015, "Should default to 0.015 edge thickness")
	# Bloom defaults — keep tests honest if these tweak later.
	assert_true(tuning.bloom_intensity > 0.0, "Bloom intensity defaults positive")
	assert_true(tuning.bloom_hdr_threshold > 0.0, "Bloom HDR threshold defaults positive")



func test_tres_resource_loading() -> void:
	var tuning := load("res://data/tuning/render.tres") as RenderTuning
	assert_not_null(tuning, "render.tres should load successfully as RenderTuning")

	# Verify that the properties are loaded and have correct types and values.
	assert_true(tuning.wireframe_glow_intensity > 0.0, "Glow intensity should be positive")
	assert_true(tuning.wireframe_edge_thickness > 0.0, "Edge thickness should be positive")
	assert_true(tuning.bloom_intensity > 0.0, "Bloom intensity should be positive")
	assert_true(tuning.bloom_strength > 0.0, "Bloom strength should be positive")
	assert_true(tuning.bloom_bloom >= 0.0, "Bloom mix should be non-negative")
	assert_true(tuning.bloom_hdr_threshold >= 0.0, "Bloom HDR threshold should be non-negative")
	# Wireframe ALBEDO = glow_color * glow_intensity. If the threshold is at or
	# above that, nothing blooms — guard the canonical bloom-chain invariant.
	assert_true(
		tuning.bloom_hdr_threshold < tuning.wireframe_glow_intensity,
		"Threshold must be below wireframe glow_intensity for wires to bloom"
	)
	# Per-target emission knobs — pinned positive + above LineModel's default
	# 1.5 so a regression that strips them out of the .tres is loud.
	assert_true(
		tuning.player_ship_emission_energy >= 1.5,
		"Player ship emission energy should sit at or above LineModel's default 1.5"
	)
	assert_true(
		tuning.lighthouse_emission_energy >= 1.5,
		"Lighthouse emission energy should sit at or above LineModel's default 1.5"
	)
