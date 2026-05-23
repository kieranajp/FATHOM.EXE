# Regression test for the port proximity helper.
#
# Pinned to JS reference at game.js:2909:
#   if (dist < port.size + 15) { activePort = port }
# i.e. strict less-than against `port.size + threshold`. Y axis is ignored.
#
# This is load-bearing: T04 (market) and T05 (tavern) gate on
# World.active_port being set, which is set by the proximity tick, which is
# itself a thin wrapper around Port.is_in_proximity. Break this, break docking.
extends GutTest

const SIZE: float = 25.0
const THRESHOLD: float = 15.0


func test_player_on_port_is_in_proximity() -> void:
	var player := Vector3.ZERO
	var port := Vector3.ZERO
	assert_true(Port.is_in_proximity(player, port, SIZE, THRESHOLD))


func test_player_just_inside_threshold() -> void:
	# Distance = SIZE + 14, threshold edge is SIZE + 15. Inside.
	var player := Vector3.ZERO
	var port := Vector3(SIZE + 14.0, 0.0, 0.0)
	assert_true(Port.is_in_proximity(player, port, SIZE, THRESHOLD))


func test_player_just_outside_threshold() -> void:
	# Distance = SIZE + 16, threshold edge is SIZE + 15. Outside.
	var player := Vector3.ZERO
	var port := Vector3(SIZE + 16.0, 0.0, 0.0)
	assert_false(Port.is_in_proximity(player, port, SIZE, THRESHOLD))


func test_threshold_edge_is_exclusive() -> void:
	# Strict less-than: distance == SIZE + 15 is NOT in proximity.
	# JS uses `<`, we mirror.
	var player := Vector3.ZERO
	var port := Vector3(SIZE + THRESHOLD, 0.0, 0.0)
	assert_false(Port.is_in_proximity(player, port, SIZE, THRESHOLD))


func test_y_axis_is_ignored() -> void:
	# Wave height can shift the ship's Y but ports stay anchored; the proximity
	# check must be flat. Same XZ distance, very different Y → still inside.
	var player := Vector3(0.0, 50.0, 0.0)
	var port := Vector3(0.0, -50.0, 5.0)
	assert_true(Port.is_in_proximity(player, port, SIZE, THRESHOLD))


func test_diagonal_distance() -> void:
	# 3-4-5 triangle: distance == 5. With SIZE=0, threshold=5, 5 is NOT inside.
	var player := Vector3.ZERO
	var port := Vector3(3.0, 0.0, 4.0)
	assert_false(Port.is_in_proximity(player, port, 0.0, 5.0))
	# But threshold=6 catches it.
	assert_true(Port.is_in_proximity(player, port, 0.0, 6.0))
