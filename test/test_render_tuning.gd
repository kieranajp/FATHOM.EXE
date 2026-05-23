# Unit tests for RenderTuning and render.tres setup.
extends GutTest


func test_tuning_class_instantiation() -> void:
	var tuning := RenderTuning.new()
	assert_not_null(tuning, "RenderTuning should instantiate successfully")
	assert_eq(tuning.wireframe_glow_intensity, 4.0, "Should default to 4.0 glow intensity")
	assert_eq(tuning.wireframe_edge_thickness, 0.015, "Should default to 0.015 edge thickness")
	assert_eq(tuning.crt_warp_amount, 4.0, "Should default to 4.0 warp amount")



func test_tres_resource_loading() -> void:
	var tuning := load("res://data/tuning/render.tres") as RenderTuning
	assert_not_null(tuning, "render.tres should load successfully as RenderTuning")
	
	# Verify that the properties are loaded and have correct types and values
	assert_true(tuning.wireframe_glow_intensity > 0.0, "Glow intensity should be positive")
	assert_true(tuning.wireframe_edge_thickness > 0.0, "Edge thickness should be positive")
	assert_true(tuning.crt_warp_amount >= 0.0, "Warp amount should be non-negative")
	assert_true(tuning.crt_scanline_intensity >= 0.0, "Scanline intensity should be non-negative")
	assert_true(tuning.crt_scanline_frequency > 0.0, "Scanline frequency should be positive")
	assert_true(tuning.crt_vignette_intensity >= 0.0, "Vignette intensity should be non-negative")
	assert_true(tuning.crt_vignette_power > 0.0, "Vignette power should be positive")
	assert_true(tuning.crt_chromatic_aberration >= 0.0, "Chromatic aberration should be non-negative")
	assert_true(tuning.crt_flicker_intensity >= 0.0, "Flicker intensity should be non-negative")
	assert_true(tuning.crt_flicker_speed > 0.0, "Flicker speed should be positive")
