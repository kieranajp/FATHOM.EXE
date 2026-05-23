# Regression test for the wave-height contract (see
# docs/ARCHITECTURE.md § "The wave-height contract"). If you're refactoring
# Ocean and these fail, you've changed the equation — that's a contract change,
# not a bug in this test.
#
# Expected values were computed independently against the canonical JS formula:
#   sin(x*0.05 + t*1.5) * cos(z*0.05 + t*1.2) * 1.6 + sin(z*0.12 - t*2.0) * 0.5
extends GutTest

const TOL := 1.0e-5


func _new_ocean() -> Ocean:
	# Plain instantiation — no add_child, so _ready never fires and we don't
	# need a tuning resource or a viewport. get_wave_height is pure maths.
	return Ocean.new()


func test_origin_at_t_zero_is_flat() -> void:
	# sin(0)*cos(0)*1.6 + sin(0)*0.5 = 0. The one value we can verify by hand.
	var ocean := _new_ocean()
	assert_almost_eq(ocean.get_wave_height(0.0, 0.0, 0.0), 0.0, TOL)
	ocean.free()


func test_sample_at_positive_xz_and_t_one() -> void:
	var ocean := _new_ocean()
	assert_almost_eq(ocean.get_wave_height(10.0, 5.0, 1.0), -0.317408292016446, TOL)
	ocean.free()


func test_sample_at_negative_x_and_fractional_t() -> void:
	var ocean := _new_ocean()
	assert_almost_eq(ocean.get_wave_height(-20.0, 30.0, 2.5), -0.6214489192841752, TOL)
	ocean.free()
