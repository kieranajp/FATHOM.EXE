# Strategic Map travel lockout test suite
extends GutTest

var _travel_tuning: TravelTuning

class MockEnemy:
	var health: float = 100.0
	var global_position: Vector3 = Vector3.ZERO
	
	func _init(hp: float, pos: Vector3) -> void:
		health = hp
		global_position = pos


func before_all() -> void:
	_travel_tuning = load("res://data/tuning/travel.tres") as TravelTuning


func test_lockout_when_docked_or_near_port() -> void:
	var player_pos := Vector3(0, 0, 0)
	var enemies: Array = []
	var active_port := PortDef.new() # Non-null port (simulating proximity)
	
	# Act
	var result := MapScreen.check_travel_lockout(player_pos, enemies, active_port, _travel_tuning)
	
	# Assert
	assert_false(result.allowed, "Travel should be disallowed when in port proximity")
	assert_eq(result.reason, "TOO_CLOSE_TO_PORT", "Reason should be TOO_CLOSE_TO_PORT")


func test_lockout_when_hostile_nearby() -> void:
	var player_pos := Vector3(0, 0, 0)
	# Default lockout radius is 160m. Mock an enemy at 100m away.
	var nearby_enemy := MockEnemy.new(100.0, Vector3(100.0, 0, 0))
	var enemies: Array = [nearby_enemy]
	var active_port: PortDef = null
	
	# Act
	var result := MapScreen.check_travel_lockout(player_pos, enemies, active_port, _travel_tuning)
	
	# Assert
	assert_false(result.allowed, "Travel should be disallowed when an active hostile is nearby")
	assert_eq(result.reason, "HOSTILES_NEARBY", "Reason should be HOSTILES_NEARBY")


func test_allowed_when_hostile_is_sunk() -> void:
	var player_pos := Vector3(0, 0, 0)
	# Mock an enemy at 100m away, but sunk (health = 0)
	var sunk_enemy := MockEnemy.new(0.0, Vector3(100.0, 0, 0))
	var enemies: Array = [sunk_enemy]
	var active_port: PortDef = null
	
	# Act
	var result := MapScreen.check_travel_lockout(player_pos, enemies, active_port, _travel_tuning)
	
	# Assert
	assert_true(result.allowed, "Travel should be allowed when nearby enemies are sunk")


func test_allowed_when_hostiles_are_far_away() -> void:
	var player_pos := Vector3(0, 0, 0)
	# Lockout radius is 160m. Mock an enemy at 200m away.
	var far_enemy := MockEnemy.new(100.0, Vector3(200.0, 0, 0))
	var enemies: Array = [far_enemy]
	var active_port: PortDef = null
	
	# Act
	var result := MapScreen.check_travel_lockout(player_pos, enemies, active_port, _travel_tuning)
	
	# Assert
	assert_true(result.allowed, "Travel should be allowed when hostiles are outside the lockout radius")


func test_lockout_with_dictionary_mocks() -> void:
	var player_pos := Vector3(0, 0, 0)
	var dict_enemy := {
		"health": 80.0,
		"global_position": Vector3(50.0, 0.0, 0.0)
	}
	var enemies: Array = [dict_enemy]
	var active_port: PortDef = null
	
	# Act
	var result := MapScreen.check_travel_lockout(player_pos, enemies, active_port, _travel_tuning)
	
	# Assert
	assert_false(result.allowed, "Travel should support dictionary mock objects and reject travel")
	assert_eq(result.reason, "HOSTILES_NEARBY")
