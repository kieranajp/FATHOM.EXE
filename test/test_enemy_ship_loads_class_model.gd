# T47 — EnemyShip visual respects ship_class_id.
#
# Regression for the bug where enemy_ship.gd::_build_mesh hardcoded
# `dinghy.tres`, causing all pirates to render as 1.6×-scaled dinghies
# regardless of their nominal class. Mirrors the same load path
# PlayerShip uses (player_ship.gd::_build_placeholder_mesh).
extends GutTest


# Helper — spawn an EnemyShip with the given class id and tease out its
# internal _line_model (which is what build_mesh_instance was called on).
# Adding to the tree triggers _ready → _build_mesh.
func _spawn(class_id: String, faction: String = "pirate") -> EnemyShip:
	var enemy := EnemyShip.new()
	enemy.ship_class_id = class_id
	enemy.faction_id = faction
	add_child_autofree(enemy)
	return enemy


func test_sloop_loads_sloop_model() -> void:
	var enemy := _spawn("sloop")
	var expected := load("res://data/models/sloop.tres") as LineModel
	assert_not_null(enemy._line_model, "sloop EnemyShip should build a LineModel")
	assert_eq(
		enemy._line_model.vertices.size(), expected.vertices.size(),
		"sloop EnemyShip should load sloop.tres, not dinghy.tres",
	)
	assert_eq(
		enemy._line_model.edges.size(), expected.edges.size(),
		"sloop edge count must match sloop.tres",
	)


func test_galleon_loads_galleon_model() -> void:
	var enemy := _spawn("galleon", "authority")
	var expected := load("res://data/models/galleon.tres") as LineModel
	assert_not_null(enemy._line_model, "galleon EnemyShip should build a LineModel")
	assert_eq(
		enemy._line_model.vertices.size(), expected.vertices.size(),
		"galleon EnemyShip should load galleon.tres, not dinghy.tres",
	)
	# Crucially, sloop and galleon are different shapes — if both still landed
	# on the dinghy template, both vertex counts would match dinghy (17). This
	# pair-wise assertion is what catches the regression.
	var dinghy := load("res://data/models/dinghy.tres") as LineModel
	assert_ne(
		expected.vertices.size(), dinghy.vertices.size(),
		"galleon model should differ from dinghy — otherwise the regression test is meaningless",
	)


func test_missing_class_falls_back_to_dinghy() -> void:
	# An unknown class id should fall back without crashing — same defensive
	# behaviour PlayerShip uses.
	var enemy := _spawn("does_not_exist_qwerty")
	var dinghy := load("res://data/models/dinghy.tres") as LineModel
	assert_not_null(enemy._line_model, "missing-class EnemyShip should still build a model")
	assert_eq(
		enemy._line_model.vertices.size(), dinghy.vertices.size(),
		"unknown class id should fall back to dinghy",
	)


func test_color_is_faction_tinted() -> void:
	var pirate := _spawn("sloop", "pirate")
	var authority := _spawn("galleon", "authority")
	assert_eq(pirate._line_model.color, Factions.color_for("pirate"))
	assert_eq(authority._line_model.color, Factions.color_for("authority"))
