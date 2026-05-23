# Ship-model regression — sanity-checks all 9 .tres ports against the JS source.
#
# Not a snapshot test: we don't compare every vertex value (hundreds of
# numbers per model). Instead we assert the porting invariants:
#   - .tres loads as a LineModel.
#   - At least one vertex + one edge.
#   - edges.size() is even (flat (i0, i1) pair layout).
#   - All edge indices are in [0, vertices.size()).
#   - JS bow vertices had +Z; after the Z-flip the deepest bow Z is negative.
#   - Deformations (if any) carry the schema build_immediate_mesh expects.
#
# Catches the most likely regression: a future hand-edit that swaps the
# pair layout, removes the Z-flip, or drops a deformation field.
extends GutTest


const ALL_SHIPS := [
	"dinghy",
	"sloop",
	"galleon",
	"schooner",
	"clipper",
	"brigantine",
	"frigate",
	"carrack",
	"manofwar",
]


func test_all_ship_models_load_and_are_well_formed() -> void:
	for ship_id in ALL_SHIPS:
		var path := "res://data/models/%s.tres" % ship_id
		var model := load(path) as LineModel
		assert_not_null(model, "%s.tres should load as a LineModel" % ship_id)
		assert_gt(model.vertices.size(), 0, "%s has vertices" % ship_id)
		assert_gt(model.edges.size(), 0, "%s has edges" % ship_id)
		assert_eq(
			model.edges.size() % 2, 0,
			"%s edges must be flat (i0, i1) pairs — even count" % ship_id,
		)
		# Every edge endpoint must reference an in-range vertex; otherwise the
		# renderer silently drops the edge and the silhouette goes wrong.
		var n_verts := model.vertices.size()
		for i in range(model.edges.size()):
			var idx := model.edges[i]
			assert_true(
				idx >= 0 and idx < n_verts,
				"%s edge index %d out of range [0, %d)" % [ship_id, idx, n_verts],
			)


func test_z_flip_was_applied_bow_points_negative() -> void:
	# JS bows sat at the most-positive Z; after the (x, y, z) → (x, y, -z)
	# flip they should be at the most-negative Z in Godot space. Spot-check
	# by asserting the minimum Z is negative (bow). Dinghy vertex 0 specifically
	# must be (0, 1.5, -3) — the canonical reference from the issue spec.
	for ship_id in ALL_SHIPS:
		var model := load("res://data/models/%s.tres" % ship_id) as LineModel
		var min_z: float = INF
		for v in model.vertices:
			if v.z < min_z:
				min_z = v.z
		assert_lt(min_z, 0.0, "%s bow should be at -Z after flip" % ship_id)

	var dinghy := load("res://data/models/dinghy.tres") as LineModel
	assert_eq(
		dinghy.vertices[0], Vector3(0, 1.5, -3),
		"Dinghy bow vertex 0 is the canonical Z-flip reference",
	)


func test_deformations_schema_is_well_formed() -> void:
	# Models that ship sail deformations must carry the keys
	# LineModel._deformed_vertex reads: indices (PackedInt32Array), top_y, mast_z.
	for ship_id in ALL_SHIPS:
		var model := load("res://data/models/%s.tres" % ship_id) as LineModel
		for def in model.deformations:
			assert_true(def.has("indices"), "%s deformation needs indices" % ship_id)
			assert_true(def.has("top_y"), "%s deformation needs top_y" % ship_id)
			assert_true(def.has("mast_z"), "%s deformation needs mast_z" % ship_id)
			var indices = def["indices"]
			assert_true(
				indices is PackedInt32Array,
				"%s deformation indices must be PackedInt32Array" % ship_id,
			)
			assert_gt(indices.size(), 0, "%s deformation has at least one index" % ship_id)
			# Indices must reference real vertices.
			for idx in indices:
				assert_true(
					idx >= 0 and idx < model.vertices.size(),
					"%s deformation index %d out of range" % [ship_id, idx],
				)


func test_player_ship_loads_class_model() -> void:
	for class_id in ALL_SHIPS:
		GameState.ship.ship_class_id = class_id
		var player: PlayerShip = load("res://scripts/player/player_ship.gd").new()
		player.ocean_path = NodePath("")
		add_child_autofree(player)
		await get_tree().process_frame
		
		var expected := load("res://data/models/%s.tres" % class_id) as LineModel
		assert_not_null(player.get_ship_model(), "player ship model for %s should be loaded" % class_id)
		assert_eq(
			player.get_ship_model().vertices.size(),
			expected.vertices.size(),
			"vertex count for player class %s" % class_id
		)


func test_enemy_ship_loads_class_model() -> void:
	for class_id in ALL_SHIPS:
		var enemy := EnemyShip.new()
		enemy.ship_class_id = class_id
		add_child_autofree(enemy)
		await get_tree().process_frame
		
		var expected := load("res://data/models/%s.tres" % class_id) as LineModel
		assert_not_null(enemy.get_line_model(), "enemy ship model for %s should be loaded" % class_id)
		assert_eq(
			enemy.get_line_model().vertices.size(),
			expected.vertices.size(),
			"vertex count for enemy class %s" % class_id
		)
