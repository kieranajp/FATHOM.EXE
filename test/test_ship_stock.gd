# Tests for Economy.initial_ship_stock / ammo_stock determinism and
# GameState.port_ship_stock persistence across dock cycles.
# JS reference: game.test.js:705-833.
extends GutTest


func before_each() -> void:
	GameState.reset_new_game()


# --- Determinism ---------------------------------------------------------

func test_initial_ship_stock_is_deterministic() -> void:
	# Same input id → identical output dictionary across calls.
	var a := Economy.initial_ship_stock("tortuga")
	var b := Economy.initial_ship_stock("tortuga")
	assert_eq(a, b, "initial_ship_stock should be a pure function of port id")


func test_initial_ship_stock_differs_per_port() -> void:
	# Different ports should produce (usually) different stocks. We only need
	# to assert at least one class differs to prove the seed is wired up.
	var a := Economy.initial_ship_stock("tortuga")
	var b := Economy.initial_ship_stock("havana")
	var differs := false
	for key in a:
		if int(a[key]) != int(b.get(key, 0)):
			differs = true
			break
	assert_true(differs, "different ports should yield different ship stock")


func test_dinghy_always_in_stock() -> void:
	# JS fallback: dinghy stock = 1 unconditionally.
	for pid in ["tortuga", "havana", "nassau", "cartagena", "bermuda"]:
		var stock := Economy.initial_ship_stock(pid)
		assert_eq(int(stock.get("dinghy", -1)), 1, "dinghy stock at %s" % pid)


func test_initial_ammo_stock_is_deterministic() -> void:
	var a := Economy.initial_ammo_stock("tortuga")
	var b := Economy.initial_ammo_stock("tortuga")
	assert_eq(a, b)


# --- ensure_port_stocks --------------------------------------------------

func test_ensure_port_stocks_populates_on_first_call() -> void:
	assert_false(GameState.port_ship_stock.has("tortuga"))
	assert_false(GameState.port_ammo_stock.has("tortuga"))
	Economy.ensure_port_stocks("tortuga")
	assert_true(GameState.port_ship_stock.has("tortuga"))
	assert_true(GameState.port_ammo_stock.has("tortuga"))


func test_ensure_port_stocks_does_not_overwrite() -> void:
	# Pre-populate with a known value — ensure_port_stocks must leave it alone.
	GameState.port_ship_stock["tortuga"] = { "dinghy": 1, "schooner": 0 }
	GameState.port_ammo_stock["tortuga"] = { "ball": 99, "chain": 0, "grape": 0 }
	Economy.ensure_port_stocks("tortuga")
	assert_eq(int(GameState.port_ship_stock["tortuga"]["schooner"]), 0)
	assert_eq(int(GameState.port_ammo_stock["tortuga"]["ball"]), 99)


# --- Depletion persists across "dock cycles" -----------------------------

func test_purchased_ship_stock_persists() -> void:
	# Simulate a purchase: depletion is stored in port_ship_stock.
	GameState.port_ship_stock["tortuga"] = { "schooner": 1, "sloop": 1 }
	GameState.port_ship_stock["tortuga"]["schooner"] = 0
	# A "dock cycle" undocks then redocks — ensure_port_stocks must NOT
	# regenerate the entry, so depletion persists.
	Economy.ensure_port_stocks("tortuga")
	assert_eq(int(GameState.port_ship_stock["tortuga"]["schooner"]), 0)
	assert_eq(int(GameState.port_ship_stock["tortuga"]["sloop"]), 1)


func test_purchased_ammo_stock_persists() -> void:
	GameState.port_ammo_stock["tortuga"] = { "ball": 5, "chain": 1, "grape": 0 }
	GameState.port_ammo_stock["tortuga"]["ball"] = 0
	Economy.ensure_port_stocks("tortuga")
	assert_eq(int(GameState.port_ammo_stock["tortuga"]["ball"]), 0)
	assert_eq(int(GameState.port_ammo_stock["tortuga"]["chain"]), 1)
