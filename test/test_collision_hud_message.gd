# Test suite for Run-Aground collision HUD message
extends GutTest

var _hud_messages: Array = []


func before_each() -> void:
	GameState.reset_new_game()
	_hud_messages = []
	EventBus.hud_message.connect(_on_hud_message)


func after_each() -> void:
	EventBus.hud_message.disconnect(_on_hud_message)


func _on_hud_message(text: String, severity: String) -> void:
	_hud_messages.append({"text": text, "severity": severity})


func test_collision_emits_hud_message() -> void:
	# Instantiate a PlayerShip and call _handle_collision
	var player = PlayerShip.new()
	player.tuning = load("res://data/tuning/sailing.tres") as SailingTuning
	
	var port = Port.new()
	var port_def := PortDef.new()
	port_def.display_name = "Tortuga"
	port.port_def = port_def
	
	player._handle_collision(port)
	
	assert_eq(_hud_messages.size(), 1, "Should emit exactly one HUD message")
	var msg = _hud_messages[0]
	assert_true(msg.text.contains("RUN AGROUND"), "Message should contain 'RUN AGROUND'")
	assert_true(msg.text.contains("TORTUGA"), "Message should contain the port name")
	assert_eq(msg.severity, "alert", "Severity should be alert")
	
	player.free()
	port.free()
