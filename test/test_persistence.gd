# Unit tests for Persistence (T12).
#
# Covers: round-trip restore, corrupted save handling, missing-file behaviour,
# schema-drift tolerance (missing fields default), version mismatch fallback.
extends GutTest

const SAVE_PATH := "user://save.json"

var _hud_messages: Array = []


func _on_hud_message(text: String, severity: String) -> void:
	_hud_messages.append({"text": text, "severity": severity})


func before_each() -> void:
	# Clean slate: reset GameState and delete any prior save artifact.
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


func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _write_raw(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_has_save_false_when_no_file() -> void:
	assert_false(Persistence.has_save(), "has_save should be false when no save file exists")


func test_load_returns_false_when_no_file() -> void:
	assert_false(Persistence.load(), "load should return false when no save file exists")


func test_round_trip_restores_all_fields() -> void:
	# Populate non-default state across GameState and PlayerState
	GameState.day = 17
	GameState.hour = 21
	GameState.current_archipelago_id = "rotting_caribbean"
	GameState.current_port_id = "port_royal"
	GameState.travel_count = 5
	GameState.visited_archipelagos = ["pirates_cradle", "rotting_caribbean"]
	GameState.active_rumor = "the_lost_galleon"
	GameState.last_drink_purchased = true
	GameState.port_ship_stock = {"port_royal": {"schooner": 1, "sloop": 0}}

	GameState.ship.ship_class_id = "schooner"
	GameState.ship.ship_name = "The Black Wager"
	GameState.ship.gold = 999
	GameState.ship.health = 42.5
	GameState.ship.cargo = {"rum": 7, "sugar": 3}
	GameState.ship.ammo = {"ball": 5, "chain": 2, "grape": 1}
	GameState.ship.active_ammo = "chain"
	GameState.ship.sail_level = 3.0

	GameState.crew.gunners = 4
	GameState.crew.sailors = 12
	GameState.crew.morale = 75.0

	Persistence.save()
	assert_true(Persistence.has_save(), "Save file should exist after save()")

	# Clobber state, then load
	GameState.reset_new_game()
	assert_eq(GameState.day, 1, "Sanity: reset clears day")
	assert_eq(GameState.ship.gold, 150, "Sanity: reset clears gold")

	var loaded: bool = Persistence.load()
	assert_true(loaded, "load() should return true on successful restore")

	# Top-level fields
	assert_eq(GameState.day, 17)
	assert_eq(GameState.hour, 21)
	assert_eq(GameState.current_archipelago_id, "rotting_caribbean")
	assert_eq(GameState.current_port_id, "port_royal")
	assert_eq(GameState.travel_count, 5)
	assert_eq(GameState.visited_archipelagos, ["pirates_cradle", "rotting_caribbean"] as Array[String])
	assert_eq(GameState.active_rumor, "the_lost_galleon")
	assert_true(GameState.last_drink_purchased)
	assert_almost_eq(float(GameState.port_ship_stock["port_royal"]["schooner"]), 1.0, 0.001)

	# PlayerState
	assert_eq(GameState.ship.ship_class_id, "schooner")
	assert_eq(GameState.ship.ship_name, "The Black Wager")
	assert_eq(GameState.ship.gold, 999)
	assert_almost_eq(GameState.ship.health, 42.5, 0.001)
	# JSON numerics deserialise as floats; compare with tolerance.
	assert_almost_eq(float(GameState.ship.cargo["rum"]), 7.0, 0.001)
	assert_almost_eq(float(GameState.ship.ammo["chain"]), 2.0, 0.001)
	assert_eq(GameState.ship.active_ammo, "chain")
	assert_almost_eq(GameState.ship.sail_level, 3.0, 0.001)

	# CrewState
	assert_eq(GameState.crew.gunners, 4)
	assert_eq(GameState.crew.sailors, 12)
	assert_almost_eq(GameState.crew.morale, 75.0, 0.001)


func test_round_trip_port_ammo_stock() -> void:
	GameState.port_ammo_stock = {
		"port_royal": {"ball": 5, "chain": 10, "grape": 15}
	}
	Persistence.save()
	
	GameState.reset_new_game()
	assert_eq(GameState.port_ammo_stock, {} as Dictionary)
	
	var loaded := Persistence.load()
	assert_true(loaded)
	assert_almost_eq(float(GameState.port_ammo_stock["port_royal"]["ball"]), 5.0, 0.001)
	assert_almost_eq(float(GameState.port_ammo_stock["port_royal"]["chain"]), 10.0, 0.001)
	assert_almost_eq(float(GameState.port_ammo_stock["port_royal"]["grape"]), 15.0, 0.001)


func test_round_trip_factions() -> void:
	GameState.factions = {
		"pirates": {"id": "pirates", "display_name": "Pirates", "player_reputation": -50.0}
	}
	Persistence.save()
	
	GameState.reset_new_game()
	assert_eq(GameState.factions, {} as Dictionary)
	
	var loaded := Persistence.load()
	assert_true(loaded)
	assert_eq(GameState.factions["pirates"]["id"], "pirates")
	assert_eq(GameState.factions["pirates"]["display_name"], "Pirates")
	assert_almost_eq(float(GameState.factions["pirates"]["player_reputation"]), -50.0, 0.001)


func test_corrupted_save_returns_false_and_warns() -> void:
	_write_raw("this is not valid json {{{")
	var loaded: bool = Persistence.load()
	assert_false(loaded, "load() should return false on corrupted save")
	assert_eq(_hud_messages.size(), 1, "exactly one hud_message should fire")
	assert_eq(_hud_messages[0]["severity"], "warning", "severity should be 'warning'")
	assert_true(
		String(_hud_messages[0]["text"]).contains("corrupted"),
		"warning text should mention corruption"
	)


func test_version_mismatch_returns_false_and_warns() -> void:
	_write_save({
		"save_version": 999,
		"day": 5,
	})
	var loaded: bool = Persistence.load()
	assert_false(loaded, "load() should return false on version mismatch")
	assert_eq(_hud_messages.size(), 1, "exactly one hud_message should fire")
	assert_eq(_hud_messages[0]["severity"], "warning")
	assert_true(
		String(_hud_messages[0]["text"]).contains("version"),
		"warning text should mention version"
	)
	# State must NOT be applied on version mismatch
	assert_eq(GameState.day, 1, "day should not be overwritten on version mismatch")


func test_schema_drift_missing_fields_use_defaults() -> void:
	# Minimal valid save with only save_version + a couple of fields; all other
	# fields missing — load should succeed and defaults should fill in.
	_write_save({
		"save_version": 1,
		"day": 9,
		"player_state": {
			"gold": 500,
			# ship_name missing → should default
			# ammo missing → should default
		},
		# current_archipelago_id, visited_archipelagos, etc. all missing
	})

	var loaded: bool = Persistence.load()
	assert_true(loaded, "load() should succeed even with missing fields")

	# Specified fields applied
	assert_eq(GameState.day, 9)
	assert_eq(GameState.ship.gold, 500)

	# Missing fields fell back to defaults
	assert_eq(GameState.hour, 8, "missing hour defaults to 8")
	assert_eq(
		GameState.current_archipelago_id, "pirates_cradle",
		"missing archipelago defaults to pirates_cradle"
	)
	assert_eq(GameState.ship.ship_name, "The Salty Seagull", "missing ship_name defaults")
	assert_almost_eq(float(GameState.ship.ammo["ball"]), 10.0, 0.001, "missing ammo defaults")
	assert_eq(GameState.visited_archipelagos.size(), 0, "missing visited list defaults to empty")


func test_port_docked_triggers_save() -> void:
	# Simulate the autosave hook firing
	assert_false(Persistence.has_save(), "no save before dock")
	GameState.ship.gold = 777
	EventBus.port_docked.emit(null)
	# Give the deferred path a chance — port_docked is synchronous, so this is just a guard
	assert_true(Persistence.has_save(), "save file should exist after port_docked")

	# Reset and reload to confirm the autosave actually captured the state
	GameState.reset_new_game()
	assert_eq(GameState.ship.gold, 150)
	assert_true(Persistence.load())
	assert_eq(GameState.ship.gold, 777, "autosave should have captured the pre-dock state")
