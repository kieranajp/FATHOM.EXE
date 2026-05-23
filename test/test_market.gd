# Tests for Economy buy/sell validation and the Market UI's transaction wiring.
# JS reference: game.test.js:116-174 (canBuyCargo / canSellCargo),
# game.test.js:597-705 (ammunition trading).
extends GutTest

const MARKET_SCENE := preload("res://scenes/ui/Market.tscn")

var _market_inst: Control


func before_each() -> void:
	GameState.reset_new_game()
	GameState.ship.gold = 100
	GameState.ship.cargo = {}
	GameState.ship.ammo = { "ball": 0, "chain": 0, "grape": 0 }


func after_each() -> void:
	if is_instance_valid(_market_inst):
		_market_inst.free()


# --- canBuyCargo ---------------------------------------------------------

func test_can_buy_succeeds_with_gold_and_space() -> void:
	GameState.ship.gold = 100
	GameState.ship.ship_class_id = "dinghy"
	GameState.ship.cargo = { "rum": 1, "sugar": 2 }
	var v := Economy.can_buy_cargo(GameState.ship, "sugar", 25)
	assert_true(v.success)


func test_can_buy_fails_on_insufficient_gold() -> void:
	GameState.ship.gold = 20
	GameState.ship.ship_class_id = "dinghy"
	var v := Economy.can_buy_cargo(GameState.ship, "sugar", 25)
	assert_false(v.success)
	assert_true((v.reason as String).contains("INSUFFICIENT GOLD"))


func test_can_buy_fails_when_hold_full() -> void:
	GameState.ship.gold = 100
	GameState.ship.ship_class_id = "dinghy"
	# Dinghy max_cargo = 100. 3 commodities * 10 = 30, plus 0 ammo. Fill it.
	GameState.ship.cargo = { "rum": 10 }
	GameState.ship.ammo = { "ball": 0, "chain": 0, "grape": 0 }
	var v := Economy.can_buy_cargo(GameState.ship, "sugar", 5)
	assert_false(v.success)
	assert_true((v.reason as String).contains("CARGO HOLD FULL"))


# --- canSellCargo --------------------------------------------------------

func test_can_sell_succeeds_when_holding() -> void:
	GameState.ship.cargo = { "sugar": 2 }
	var v := Economy.can_sell_cargo(GameState.ship, "sugar")
	assert_true(v.success)


func test_can_sell_fails_when_empty() -> void:
	GameState.ship.cargo = { "rum": 2 }
	var v := Economy.can_sell_cargo(GameState.ship, "sugar")
	assert_false(v.success)
	assert_true((v.reason as String).contains("NO CARGO HELD"))


# --- Ammo cargo weighting (JS test:597-606) ------------------------------

func test_ammo_counts_at_0_2_per_unit() -> void:
	GameState.ship.cargo = { "rum": 2, "sugar": 1 }
	GameState.ship.ammo = { "ball": 3, "chain": 0, "grape": 1 }
	# 3 commodities * 10 + 4 ammo * 0.2 = 30 + 0.8 = 30.8
	var total := Economy.total_cargo_count(GameState.ship)
	assert_almost_eq(total, 30.8, 0.05)


func test_ammo_buy_blocked_when_hold_full() -> void:
	# JS test:608-617 — maxCargo 40.2, cargo 4 commodities (40) + 1 ball (0.2) = 40.2.
	# Dinghy max_cargo is 100 in our spec, so reproduce shape, not exact numbers.
	# Sloop max_cargo = 120. Use commodities to push over the line.
	GameState.ship.ship_class_id = "sloop" # max_cargo 120
	GameState.ship.gold = 100
	GameState.ship.cargo = { "rum": 11 } # 11*10 = 110
	GameState.ship.ammo = { "ball": 50, "chain": 0, "grape": 0 } # +10 = 120, hold full
	var v := Economy.can_buy_cargo(GameState.ship, "ball", 2)
	assert_false(v.success)
	assert_true((v.reason as String).contains("CARGO HOLD FULL"))


# --- Market UI integration ----------------------------------------------

func _spawn_market_at_port(port_id: String) -> void:
	GameState.current_port_id = port_id
	_market_inst = MARKET_SCENE.instantiate() as Control
	add_child(_market_inst)


func test_buy_commodity_updates_gold_and_cargo() -> void:
	GameState.ship.gold = 500
	GameState.ship.ship_class_id = "dinghy"
	_spawn_market_at_port("tortuga")
	# Rum is a producer at Tortuga — should be buyable.
	var prices: Dictionary = _market_inst._prices
	assert_true(prices.has("rum"))
	var rum_buy: int = int(prices.rum.buy)
	var initial_gold: int = GameState.ship.gold
	_market_inst._on_buy_pressed("rum")
	assert_eq(GameState.ship.gold, initial_gold - rum_buy)
	assert_eq(int(GameState.ship.cargo.get("rum", 0)), 1)


func test_sell_commodity_updates_gold_and_cargo() -> void:
	GameState.ship.gold = 100
	GameState.ship.ship_class_id = "dinghy"
	GameState.ship.cargo = { "rum": 2 }
	_spawn_market_at_port("tortuga")
	var prices: Dictionary = _market_inst._prices
	var rum_sell: int = int(prices.rum.sell)
	_market_inst._on_sell_pressed("rum")
	assert_eq(GameState.ship.gold, 100 + rum_sell)
	assert_eq(int(GameState.ship.cargo.get("rum", 0)), 1)


func test_sell_with_no_cargo_fails_silently() -> void:
	GameState.ship.gold = 100
	GameState.ship.cargo = { "rum": 0 }
	_spawn_market_at_port("tortuga")
	_market_inst._on_sell_pressed("rum")
	# No mutation occurred.
	assert_eq(GameState.ship.gold, 100)
	assert_eq(int(GameState.ship.cargo.get("rum", 0)), 0)


func test_buy_ammo_decrements_port_stock() -> void:
	GameState.ship.gold = 100
	GameState.ship.ship_class_id = "dinghy"
	_spawn_market_at_port("tortuga")
	# Force stock so the test isn't at the mercy of the deterministic seed.
	GameState.port_ammo_stock["tortuga"] = { "ball": 5, "chain": 0, "grape": 0 }
	_market_inst._on_buy_pressed("ball")
	assert_eq(int(GameState.ship.ammo["ball"]), 1) # before_each set ball=0
	assert_eq(int(GameState.port_ammo_stock["tortuga"]["ball"]), 4)


func test_buy_ammo_blocked_when_out_of_stock() -> void:
	GameState.ship.gold = 100
	GameState.ship.ship_class_id = "dinghy"
	_spawn_market_at_port("tortuga")
	GameState.port_ammo_stock["tortuga"] = { "ball": 0, "chain": 0, "grape": 0 }
	var initial_gold: int = GameState.ship.gold
	var initial_ball: int = int(GameState.ship.ammo["ball"])
	_market_inst._on_buy_pressed("ball")
	assert_eq(GameState.ship.gold, initial_gold, "gold unchanged when out of stock")
	assert_eq(int(GameState.ship.ammo["ball"]), initial_ball, "ammo unchanged")


func test_sell_ammo_increments_port_stock() -> void:
	GameState.ship.gold = 50
	GameState.ship.ship_class_id = "dinghy"
	GameState.ship.ammo = { "ball": 2, "chain": 0, "grape": 0 }
	_spawn_market_at_port("tortuga")
	GameState.port_ammo_stock["tortuga"] = { "ball": 5, "chain": 1, "grape": 0 }
	_market_inst._on_sell_pressed("ball")
	# Ball sell price is 0 by default → gold unchanged.
	assert_eq(GameState.ship.gold, 50)
	assert_eq(int(GameState.ship.ammo["ball"]), 1)
	assert_eq(int(GameState.port_ammo_stock["tortuga"]["ball"]), 6)
