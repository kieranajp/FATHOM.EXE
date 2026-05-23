# Persistence — save/load to user://save.json. Versioned, schema-tolerant.
#
# Triggers:
#   - Save: EventBus.port_docked (autosave on dock)
#   - Load: Main._ready() if has_save()
#
# SCHEMA NOTES:
#   When adding a new persisted field, add it to BOTH _build_payload and
#   _apply_payload, with a sensible default in _apply_payload via .get(key, default).
#   Missing fields on load fall back to defaults — additive changes don't bump
#   the version. Bump SAVE_VERSION only for non-additive changes (renames,
#   removals, restructures).
#
# Persisted fields (current):
#   Top-level:        save_version, saved_at, day, hour,
#                     current_archipelago_id, current_port_id,
#                     visited_archipelagos, travel_count,
#                     active_rumor, last_drink_purchased,
#                     port_ship_stock, port_ammo_stock, factions, crew, officers,
#                     player_state
#   player_state:     ship_class_id, ship_name, gold, health,
#                     cargo, ammo, active_ammo, sail_level
#   crew:             gunners, sailors, riggers, morale, food_quality, days_at_sea
#
# Persistence is one-way: only _apply_payload writes to GameState. Other code
# should never call it.
extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1


func _ready() -> void:
	EventBus.port_docked.connect(_on_port_docked)


func save() -> void:
	var data: Dictionary = _build_payload()
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Persistence: failed to open save file for write: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Persistence: failed to read save file: %s" % SAVE_PATH)
		return false
	var text: String = file.get_as_text()
	file.close()

	# Use JSON instance API rather than JSON.parse_string so a parse failure
	# returns an error code instead of pushing an engine error to stderr.
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK or not (json.data is Dictionary):
		EventBus.hud_message.emit("Save file corrupted; starting new game.", "warning")
		return false

	var data: Dictionary = json.data
	var version: int = int(data.get("save_version", -1))
	if version != SAVE_VERSION:
		EventBus.hud_message.emit("Save file version mismatch; starting new game.", "warning")
		return false

	_apply_payload(data)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _build_payload() -> Dictionary:
	var ship: PlayerState = GameState.ship
	var crew: CrewState = GameState.crew

	var player_state_dict: Dictionary = {}
	if ship != null:
		player_state_dict = {
			"ship_class_id": ship.ship_class_id,
			"ship_name": ship.ship_name,
			"gold": ship.gold,
			"health": ship.health,
			"cargo": ship.cargo.duplicate(true),
			"ammo": ship.ammo.duplicate(true),
			"active_ammo": ship.active_ammo,
			"sail_level": ship.sail_level,
		}

	var crew_dict: Dictionary = {}
	if crew != null:
		crew_dict = {
			"gunners": crew.gunners,
			"sailors": crew.sailors,
			"riggers": crew.riggers,
			"morale": crew.morale,
			"food_quality": crew.food_quality,
			"days_at_sea": crew.days_at_sea,
		}

	return {
		"save_version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"day": GameState.day,
		"hour": GameState.hour,
		"player_state": player_state_dict,
		"current_archipelago_id": GameState.current_archipelago_id,
		"current_port_id": GameState.current_port_id,
		"visited_archipelagos": GameState.visited_archipelagos.duplicate(),
		"travel_count": GameState.travel_count,
		"active_rumor": GameState.active_rumor,
		"last_drink_purchased": GameState.last_drink_purchased,
		"port_ship_stock": GameState.port_ship_stock.duplicate(true),
		"port_ammo_stock": GameState.port_ammo_stock.duplicate(true),
		"factions": GameState.factions.duplicate(true),
		"crew": crew_dict,
		"officers": [],  # post-parity; Officer resources not yet serialised
	}


# Schema-tolerant apply: each field is read with a default fall-back, so old
# saves or in-flight T04/T06 fields landing later won't crash.
func _apply_payload(data: Dictionary) -> void:
	# Top-level scalars
	GameState.day = int(data.get("day", 1))
	GameState.hour = int(data.get("hour", 8))
	GameState.current_archipelago_id = String(data.get("current_archipelago_id", "pirates_cradle"))
	GameState.current_port_id = String(data.get("current_port_id", ""))
	GameState.travel_count = int(data.get("travel_count", 0))
	GameState.active_rumor = String(data.get("active_rumor", ""))
	GameState.last_drink_purchased = bool(data.get("last_drink_purchased", false))

	# Typed Array[String] — rebuild from untyped JSON array
	var visited_raw: Array = data.get("visited_archipelagos", [])
	var visited: Array[String] = []
	for entry in visited_raw:
		visited.append(String(entry))
	GameState.visited_archipelagos = visited

	GameState.port_ship_stock = (data.get("port_ship_stock", {}) as Dictionary).duplicate(true)
	GameState.port_ammo_stock = (data.get("port_ammo_stock", {}) as Dictionary).duplicate(true)
	GameState.factions = (data.get("factions", {}) as Dictionary).duplicate(true)

	# PlayerState — create fresh, overlay persisted fields onto defaults
	var ps_data: Dictionary = data.get("player_state", {})
	var ps: PlayerState = PlayerState.new()
	ps.ship_class_id = String(ps_data.get("ship_class_id", ps.ship_class_id))
	ps.ship_name = String(ps_data.get("ship_name", ps.ship_name))
	ps.gold = int(ps_data.get("gold", ps.gold))
	ps.health = float(ps_data.get("health", ps.health))
	ps.cargo = (ps_data.get("cargo", ps.cargo) as Dictionary).duplicate(true)
	ps.ammo = (ps_data.get("ammo", ps.ammo) as Dictionary).duplicate(true)
	ps.active_ammo = String(ps_data.get("active_ammo", ps.active_ammo))
	ps.sail_level = float(ps_data.get("sail_level", ps.sail_level))
	GameState.ship = ps

	# CrewState — same overlay pattern
	var crew_data: Dictionary = data.get("crew", {})
	var crew: CrewState = CrewState.new()
	crew.gunners = int(crew_data.get("gunners", crew.gunners))
	crew.sailors = int(crew_data.get("sailors", crew.sailors))
	crew.riggers = int(crew_data.get("riggers", crew.riggers))
	crew.morale = float(crew_data.get("morale", crew.morale))
	crew.food_quality = float(crew_data.get("food_quality", crew.food_quality))
	crew.days_at_sea = int(crew_data.get("days_at_sea", crew.days_at_sea))
	GameState.crew = crew

	# Officers — post-parity; not yet serialised. Reset to empty.
	GameState.officers = []


func _on_port_docked(_port: PortDef) -> void:
	save()
