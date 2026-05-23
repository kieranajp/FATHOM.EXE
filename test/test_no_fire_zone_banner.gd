# Test suite for No-Fire Zone Proximity Banner
extends GutTest

var _combat_system: CombatSystem
var _player: PlayerShip
var _port: Port


func before_each() -> void:
	GameState.reset_new_game()
	World.clear()
	
	# Instantiate a minimal scene with CombatSystem, PlayerShip, and a Port
	_combat_system = CombatSystem.new()
	_player = PlayerShip.new()
	_player.name = "PlayerShip"
	
	_port = Port.new()
	var port_def := PortDef.new()
	port_def.id = "test_port"
	port_def.display_name = "Test Port"
	port_def.position = Vector3(0, 0, 0)
	_port.port_def = port_def
	_port.add_to_group("port")
	
	get_tree().root.add_child(_combat_system)
	get_tree().root.add_child(_player)
	get_tree().root.add_child(_port)
	
	# Wire player inside CombatSystem
	_combat_system._player = _player
	_combat_system.tuning = load("res://data/tuning/combat.tres") as CombatTuning


func after_each() -> void:
	_combat_system.queue_free()
	_player.queue_free()
	_port.queue_free()
	World.clear()


func test_proximity_zone_flag() -> void:
	# Port is at (0, 0, 0). Place player at (50, 0, 0) - within 120m
	_player.global_position = Vector3(50, 0, 0)
	_combat_system._tick_no_fire_zone_proximity()
	assert_true(World.is_in_no_fire_zone, "Should be inside no-fire zone at 50m")
	
	# Move player to (150, 0, 0) - beyond 120m
	_player.global_position = Vector3(150, 0, 0)
	_combat_system._tick_no_fire_zone_proximity()
	assert_false(World.is_in_no_fire_zone, "Should be outside no-fire zone at 150m")
