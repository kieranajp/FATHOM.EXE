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


func test_inventory_capacity_display_matches_economy() -> void:
	var hud := load("res://scenes/HUD.tscn").instantiate()
	get_tree().root.add_child(hud)

	var inventory = hud.get_node("Inventory")
	assert_not_null(inventory, "Inventory screen should exist on HUD")

	# Set some custom cargo and ammo
	GameState.ship.cargo = { "rum": 5 }
	GameState.ship.ammo = { "ball": 3 }

	# Refresh inventory UI to update labels
	inventory.refresh()

	var capacity_label: Label = inventory.get_node("Panel/V/Header/Capacity")
	assert_not_null(capacity_label, "Capacity label should exist under inventory Panel/V/Header/Capacity")

	# Expected display: used cargo is 5 * 10 + 3 * 0.2 = 50.6. Max cargo for default dinghy is 100.
	var expected_used := Economy.total_cargo_count(GameState.ship)
	var expected_max := Economy.max_cargo_for(GameState.ship)
	var expected_used_str := "%d" % int(expected_used) if fmod(expected_used, 1.0) == 0.0 else "%.1f" % expected_used
	var expected_text := "CARGO: %s / %d" % [expected_used_str, expected_max]

	assert_eq(capacity_label.text, expected_text, "Capacity display text should show the weighted used / max cargo")

	hud.queue_free()
