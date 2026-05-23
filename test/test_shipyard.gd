# Tests for Economy.can_upgrade_ship + Shipyard UI purchase wiring.
# JS reference: game.test.js:344-454.
extends GutTest

const SHIPYARD_SCENE := preload("res://scenes/ui/Shipyard.tscn")

var _shipyard_inst: Control


func before_each() -> void:
	GameState.reset_new_game()
	GameState.ship.gold = 2000
	GameState.ship.cargo = {}
	GameState.ship.ammo = { "ball": 0, "chain": 0, "grape": 0 }


func after_each() -> void:
	if is_instance_valid(_shipyard_inst):
		_shipyard_inst.free()


# --- Trade-in math --------------------------------------------------------

func test_upgrade_cost_with_full_hp_tradein() -> void:
	GameState.ship.ship_class_id = "sloop"
	GameState.ship.gold = 2000
	GameState.ship.health = 150.0 # sloop max HP
	# Sloop cost 500, trade-in = floor(500 * 0.7 * 1.0) = 350.
	# Brigantine cost 1400 → upgrade cost 1050.
	var result := Economy.can_upgrade_ship(GameState.ship, "brigantine")
	assert_true(result.success)
	assert_eq(int(result.cost), 1050)


func test_upgrade_cost_with_damaged_hull() -> void:
	GameState.ship.ship_class_id = "sloop"
	GameState.ship.gold = 2000
	GameState.ship.health = 75.0 # 50% of 150 max
	# Trade-in = floor(500 * 0.7 * 0.5) = 175. Brigantine = 1400 - 175 = 1225.
	var result := Economy.can_upgrade_ship(GameState.ship, "brigantine")
	assert_true(result.success)
	assert_eq(int(result.cost), 1225)


func test_tradein_exceeds_target_cost_yields_zero() -> void:
	GameState.ship.ship_class_id = "galleon"
	GameState.ship.gold = 100 # tiny gold; should still succeed because cost 0
	GameState.ship.health = 380.0 # galleon max HP
	# Galleon trade-in = floor(2800 * 0.7 * 1.0) = 1960. Sloop cost 500 → cost 0.
	var result := Economy.can_upgrade_ship(GameState.ship, "sloop")
	assert_true(result.success)
	assert_eq(int(result.cost), 0)


# --- Validation failures -------------------------------------------------

func test_insufficient_gold_blocks_upgrade() -> void:
	GameState.ship.ship_class_id = "dinghy"
	GameState.ship.gold = 100 # schooner costs 250, trade-in 0
	GameState.ship.health = 100.0
	var result := Economy.can_upgrade_ship(GameState.ship, "schooner")
	assert_false(result.success)
	assert_eq(result.reason, "INSUFFICIENT GOLD")


func test_cargo_overflow_blocks_upgrade() -> void:
	GameState.ship.ship_class_id = "clipper" # max_cargo 280
	GameState.ship.gold = 5000
	GameState.ship.health = 180.0
	# 20 units of commodities = 200 weight; sloop max_cargo = 120 → overflow.
	GameState.ship.cargo = { "rum": 10, "sugar": 10 }
	var result := Economy.can_upgrade_ship(GameState.ship, "sloop")
	assert_false(result.success)
	assert_eq(result.reason, "CARGO HOLD OVERFLOW")


func test_cargo_within_limit_passes() -> void:
	GameState.ship.ship_class_id = "clipper"
	GameState.ship.gold = 5000
	GameState.ship.health = 180.0
	# 10 commodities = 100 weight; sloop max_cargo = 120 → ok.
	GameState.ship.cargo = { "rum": 5, "sugar": 5 }
	var result := Economy.can_upgrade_ship(GameState.ship, "sloop")
	assert_true(result.success)


func test_already_owned_rejected() -> void:
	GameState.ship.ship_class_id = "sloop"
	GameState.ship.gold = 5000
	var result := Economy.can_upgrade_ship(GameState.ship, "sloop")
	assert_false(result.success)
	assert_eq(result.reason, "ALREADY OWNED")


func test_invalid_class_rejected() -> void:
	GameState.ship.ship_class_id = "dinghy"
	GameState.ship.gold = 5000
	var result := Economy.can_upgrade_ship(GameState.ship, "ufo")
	assert_false(result.success)
	assert_eq(result.reason, "INVALID SHIP CLASS")


# --- Shipyard UI purchase wiring -----------------------------------------

func _spawn_shipyard_at(port_id: String) -> void:
	GameState.current_port_id = port_id
	_shipyard_inst = SHIPYARD_SCENE.instantiate() as Control
	add_child(_shipyard_inst)


func test_buy_ship_swaps_class_restores_hp_updates_stock() -> void:
	GameState.ship.ship_class_id = "dinghy"
	GameState.ship.gold = 5000
	GameState.ship.health = 50.0
	_spawn_shipyard_at("tortuga")
	# Force stock so it's deterministic regardless of seed.
	GameState.port_ship_stock["tortuga"] = { "dinghy": 1, "schooner": 1, "sloop": 0 }
	_shipyard_inst._on_buy_pressed("schooner")
	assert_eq(GameState.ship.ship_class_id, "schooner")
	assert_almost_eq(GameState.ship.health, 120.0, 0.01) # schooner max HP
	# Schooner stock depleted to 0, dinghy stock incremented by 1.
	assert_eq(int(GameState.port_ship_stock["tortuga"]["schooner"]), 0)
	assert_eq(int(GameState.port_ship_stock["tortuga"]["dinghy"]), 2)


func test_buy_ship_deducts_gold() -> void:
	GameState.ship.ship_class_id = "dinghy"
	GameState.ship.gold = 500
	GameState.ship.health = 100.0
	_spawn_shipyard_at("tortuga")
	GameState.port_ship_stock["tortuga"] = { "schooner": 1 }
	# Schooner cost 250, dinghy trade-in 0 → 250.
	_shipyard_inst._on_buy_pressed("schooner")
	assert_eq(GameState.ship.gold, 250)
