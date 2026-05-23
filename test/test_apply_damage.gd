# Regression test for ship damage / health clamping. Values pinned to the JS
# reference (main:game.test.js:174-207). Tests the Dictionary-form helper since
# that mirrors the JS shape one-for-one; the Object-form (Combat.apply_ship_damage)
# delegates to identical clamp logic and is covered indirectly by the combat
# integration smoke run.
extends GutTest


func test_subtracts_and_returns_false_when_afloat() -> void:
	var ship: Dictionary = {"health": 100.0, "max_health": 100.0}
	var sunk: bool = Combat.apply_ship_damage_dict(ship, 30.0)
	assert_eq(ship.health, 70.0)
	assert_false(sunk)


func test_returns_true_when_lethal() -> void:
	var ship: Dictionary = {"health": 40.0, "max_health": 100.0}
	var sunk: bool = Combat.apply_ship_damage_dict(ship, 50.0)
	assert_eq(ship.health, 0.0)
	assert_true(sunk)


func test_caps_health_between_zero_and_max() -> void:
	var ship: Dictionary = {"health": 100.0, "max_health": 100.0}

	# Negative damage does NOT heal — health stays clamped at max.
	Combat.apply_ship_damage_dict(ship, -50.0)
	assert_eq(ship.health, 100.0)

	# Overkill clamps to 0.
	Combat.apply_ship_damage_dict(ship, 500.0)
	assert_eq(ship.health, 0.0)


func test_handles_missing_fields() -> void:
	# Defensive: empty dict shouldn't crash; returns false.
	var ship: Dictionary = {}
	var sunk: bool = Combat.apply_ship_damage_dict(ship, 10.0)
	assert_false(sunk)
