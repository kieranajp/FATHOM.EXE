# Tests for the T37 player-death handler in scripts/main.gd.
#
# The handler is wired to EventBus.player_death in Main._ready. When the GUT
# runner boots, Godot mounts the project's `run/main_scene` (Main.tscn) under
# /root, which means Main._ready has already fired and is listening. We can
# just emit player_death and observe the side effects on GameState / EventBus
# / Persistence — no need to instantiate our own Main.
extends GutTest

const SAVE_PATH := "user://save.json"

var _hud_messages: Array = []


func _on_hud_message(text: String, severity: String) -> void:
	_hud_messages.append({"text": text, "severity": severity})


func before_each() -> void:
	GameState.reset_new_game()
	_hud_messages = []
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	EventBus.hud_message.connect(_on_hud_message)


func after_each() -> void:
	if EventBus.hud_message.is_connected(_on_hud_message):
		EventBus.hud_message.disconnect(_on_hud_message)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_death_restores_health_to_ship_class_max() -> void:
	GameState.ship.health = 0.0
	EventBus.player_death.emit()
	# Dinghy max_health is 100.0 (data/ships/dinghy.tres).
	assert_almost_eq(GameState.ship.health, 100.0, 0.001)


func test_death_clears_cargo() -> void:
	GameState.ship.cargo = {"rum": 5, "sugar": 2}
	EventBus.player_death.emit()
	assert_eq(GameState.ship.cargo.size(), 0, "cargo should be wiped on death")


func test_death_halves_gold() -> void:
	GameState.ship.gold = 200
	EventBus.player_death.emit()
	assert_eq(GameState.ship.gold, 100, "gold should be halved by gold_retention_fraction (0.5)")


func test_death_handles_odd_gold_via_floor() -> void:
	GameState.ship.gold = 7
	EventBus.player_death.emit()
	# floor(0.5 * 7) == 3
	assert_eq(GameState.ship.gold, 3, "odd-gold halving must floor")


func test_death_teleports_to_nearest_port_in_archipelago() -> void:
	# Pirate's Cradle ports include port_royal (0, 0, -540), nassau (-540, 0, 180),
	# tortuga, havana. Without a PlayerShip in the test tree the handler can't
	# physically move it, but it must still pick the nearest port and name it
	# in the HUD alert. From origin the closest pirates_cradle port is Port Royal
	# (the others are >540 units away; havana/tortuga sit further still).
	GameState.current_archipelago_id = "pirates_cradle"
	EventBus.player_death.emit()
	assert_eq(_hud_messages.size(), 1, "exactly one hud_message should fire")
	var msg: Dictionary = _hud_messages[0]
	assert_eq(msg["severity"], "alert")
	assert_true(
		String(msg["text"]).contains("PORT ROYAL"),
		"alert should name the nearest port. Got: %s" % msg["text"]
	)


func test_death_emits_hud_alert() -> void:
	EventBus.player_death.emit()
	assert_eq(_hud_messages.size(), 1)
	assert_eq(_hud_messages[0]["severity"], "alert")
	assert_true(String(_hud_messages[0]["text"]).contains("SUNK"))


func test_death_resets_sail_level() -> void:
	# Without a PlayerShip mounted, the handler still has to leave the
	# persisted state coherent — sail_level on PlayerState should be 2.0
	# (default_sail_level from data/tuning/respawn.tres).
	GameState.ship.sail_level = 4.0
	EventBus.player_death.emit()
	assert_almost_eq(GameState.ship.sail_level, 2.0, 0.001)


func test_death_triggers_autosave() -> void:
	GameState.ship.gold = 200
	GameState.ship.cargo = {"rum": 5}
	assert_false(Persistence.has_save(), "no save before death")
	EventBus.player_death.emit()
	assert_true(Persistence.has_save(), "death handler should autosave")

	# Confirm the autosave captured the *post-penalty* state — that's the
	# whole point: reloading after death must not let the player dodge it.
	GameState.reset_new_game()
	assert_true(Persistence.load())
	assert_eq(GameState.ship.gold, 100, "saved gold should be the halved value")
	assert_eq(GameState.ship.cargo.size(), 0, "saved cargo should be empty")


func test_player_death_preserves_ship_class() -> void:
	GameState.ship.ship_class_id = "schooner"
	GameState.ship.gold = 200
	EventBus.player_death.emit()
	await get_tree().process_frame
	assert_eq(GameState.ship.ship_class_id, "schooner", "ship class survives death")
	assert_eq(GameState.ship.gold, 100, "gold halved as expected (regression net)")
