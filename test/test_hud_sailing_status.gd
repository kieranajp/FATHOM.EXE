# Regression tests for the HUD sailing-status tier classification.
#
# Three tiers, two boundaries:
#   efficiency < 0.15                       → IN IRONS (HEADWIND)   red
#   0.15 <= efficiency <= 0.85              → TACKING / RUNNING     amber
#   efficiency > 0.85                       → GOOD REACH (OPTIMAL)  cyan
#
# T04 / T08 might fiddle with adjacent code and accidentally shift these
# boundaries; this guards them.
extends GutTest

const HudScript := preload("res://scripts/ui/hud.gd")


func test_just_below_irons_boundary_is_irons() -> void:
	var s := HudScript.sailing_status(0.149)
	assert_eq(s.text, "IN IRONS (HEADWIND)")


func test_just_above_irons_boundary_is_tacking() -> void:
	var s := HudScript.sailing_status(0.151)
	assert_eq(s.text, "TACKING / RUNNING")


func test_exact_irons_boundary_is_tacking() -> void:
	# < 0.15 is irons; 0.15 itself sits in the tacking band.
	var s := HudScript.sailing_status(0.15)
	assert_eq(s.text, "TACKING / RUNNING")


func test_just_below_reach_boundary_is_tacking() -> void:
	var s := HudScript.sailing_status(0.849)
	assert_eq(s.text, "TACKING / RUNNING")


func test_just_above_reach_boundary_is_good_reach() -> void:
	var s := HudScript.sailing_status(0.851)
	assert_eq(s.text, "GOOD REACH (OPTIMAL)")


func test_exact_reach_boundary_is_tacking() -> void:
	# > 0.85 is good reach; 0.85 itself sits in tacking.
	var s := HudScript.sailing_status(0.85)
	assert_eq(s.text, "TACKING / RUNNING")


func test_zero_efficiency_is_irons() -> void:
	var s := HudScript.sailing_status(0.0)
	assert_eq(s.text, "IN IRONS (HEADWIND)")


func test_full_efficiency_is_good_reach() -> void:
	var s := HudScript.sailing_status(1.0)
	assert_eq(s.text, "GOOD REACH (OPTIMAL)")
