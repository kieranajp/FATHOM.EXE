# PortMesh — verify the lighthouse anchors to the *generated* island peak
# rather than to port.height. Saddle (seed%4==1) and atoll (seed%4==3) push the
# centre vertex well below the nominal height; previously the lighthouse sat at
# port.height and visibly floated above the mound. The fix is to read
# IslandGenerator.peak_height_for(seed, height_max) — this test pins it.
#
# See scripts/systems/port_mesh.gd, scripts/systems/island_generator.gd.
extends GutTest


# Call Economy.port_seed directly.
func _seed_for(port_id: String) -> int:
	return Economy.port_seed(port_id)


func _build_for_seed(seed_val: int, height: float) -> Node3D:
	var port_def := PortDef.new()
	port_def.id = "test_%d" % seed_val
	port_def.size = 25.0
	port_def.height = height
	port_def.color = Color.WHITE
	# Override the seed implicitly by choosing port_def.id whose codepoints sum
	# to the desired residue mod 4. Easier: call _build with crafted ids.
	return PortMesh.build(port_def)


func test_lighthouse_y_matches_peak_for_saddle_type() -> void:
	# Find a port_def id whose codepoint-sum % 4 == 1 (saddle).
	var port_def := PortDef.new()
	port_def.size = 25.0
	port_def.height = 15.0
	port_def.color = Color.WHITE
	# Brute search small ids until we hit saddle and atoll types.
	for n in range(100):
		port_def.id = "p%d" % n
		var seed_val: int = _seed_for(port_def.id)
		if abs(seed_val) % 4 == 1:
			var root := PortMesh.build(port_def)
			add_child_autofree(root)
			var lh := root.get_node("Lighthouse") as Node3D
			var expected := IslandGenerator.peak_height_for(seed_val, port_def.height)
			assert_almost_eq(lh.position.y, expected, 1e-4,
				"Saddle lighthouse y must match peak_height_for (got %f, want %f)" % [lh.position.y, expected])
			# And the expected peak is strictly less than port.height for saddle.
			assert_lt(lh.position.y, port_def.height,
				"Saddle peak should sit BELOW port.height — regression catches the old port.height anchor.")
			return
	fail_test("Did not find a saddle-type seed in p0..p99")


func test_lighthouse_y_matches_peak_for_atoll_type() -> void:
	var port_def := PortDef.new()
	port_def.size = 25.0
	port_def.height = 15.0
	port_def.color = Color.WHITE
	for n in range(100):
		port_def.id = "p%d" % n
		var seed_val: int = _seed_for(port_def.id)
		if abs(seed_val) % 4 == 3:
			var root := PortMesh.build(port_def)
			add_child_autofree(root)
			var lh := root.get_node("Lighthouse") as Node3D
			var expected := IslandGenerator.peak_height_for(seed_val, port_def.height)
			assert_almost_eq(lh.position.y, expected, 1e-4,
				"Atoll lighthouse y must match peak_height_for (got %f, want %f)" % [lh.position.y, expected])
			assert_lt(lh.position.y, port_def.height,
				"Atoll peak should sit BELOW port.height — regression catches the old port.height anchor.")
			return
	fail_test("Did not find an atoll-type seed in p0..p99")
