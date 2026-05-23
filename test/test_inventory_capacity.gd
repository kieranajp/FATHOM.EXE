# Unit tests for inventory capacity calculation and display
extends GutTest

func before_each() -> void:
	GameState.reset_new_game()


func test_economy_total_cargo_count_weighting() -> void:
	var state := PlayerState.new()
	# Commodities (weight = 10 each)
	state.cargo = { "rum": 2, "sugar": 3 }
	# Ammo (weight = 0.2 each)
	state.ammo = { "ball": 5, "chain": 10 }

	# Rum (2 * 10) + Sugar (3 * 10) = 50.0
	# Ball (5 * 0.2) + Chain (10 * 0.2) = 3.0
	# Total expected = 53.0
	var expected := Economy.total_cargo_count(state)
	assert_eq(expected, 53.0, "Cargo (20 + 30) + Ammo (1 + 2) = 53.0")


# Display-side coverage intentionally limited to the pure helper above.
# An earlier draft instantiated HUD.tscn directly to assert the rendered label,
# but doing so leaked state into test_map_travel (CombatSystem._ready holds
# refs that were queue_free'd before the next test ran). The fix in
# inventory_screen.gd routes through Economy.total_cargo_count, so the pure
# test transitively guarantees the display can't drift unless someone bypasses
# the helper — at which point this file should be revisited.
