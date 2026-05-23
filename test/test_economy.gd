# Regression tests for Economy.calculate_port_prices — the pricing formula
# that ties trading profitability to port identity + travel_count.
#
# JS reference: game.js:855-914 (formula) and game.test.js:316-355 (spec).
# The JS-spec test seeds with port.name = "Nassau" (capitalised). We replicate
# those exact values here by setting id = "Nassau" on the test PortDef.
extends GutTest

const TOL := 1.0e-4


func before_each() -> void:
	GameState.reset_new_game()


func _make_port(id_str: String, base_prices: Dictionary) -> PortDef:
	var p := PortDef.new()
	p.id = id_str
	p.display_name = id_str
	p.base_prices = base_prices
	return p


# --- Spec: JS test reproduction (game.test.js:316-339) -------------------

func test_nassau_prices_match_js_reference() -> void:
	GameState.travel_count = 0
	# JS seeded with "Nassau" (sum of char codes = 619), wave = sin(619),
	# fluctuation = 1.0 + sin(619)*0.15 ≈ 0.9841.
	# rum producer:    buy = round(20 * 0.6 * 0.9841) = 12, sell = round(20 * 0.4 * 0.9841) = 8.
	# tobacco consumer: buy = round(25 * 1.8 * 0.9841) = 44, sell = round(25 * 1.4 * 0.9841) = 34.
	var port := _make_port("Nassau", {
		"rum": { "buy": 10, "sell": 12, "is_producer": true },
		"sugar": { "buy": 22, "sell": 26 },
		"tobacco": { "buy": 35, "sell": 42, "is_consumer": true },
	})
	var prices := Economy.calculate_port_prices(port)
	assert_eq(int(prices.rum.buy), 12, "rum producer buy")
	assert_eq(int(prices.rum.sell), 8, "rum producer sell")
	assert_true(prices.rum.is_producer, "rum is_producer flag")
	assert_eq(int(prices.tobacco.buy), 44, "tobacco consumer buy")
	assert_eq(int(prices.tobacco.sell), 34, "tobacco consumer sell")
	assert_true(prices.tobacco.is_consumer, "tobacco is_consumer flag")


func test_null_port_returns_empty() -> void:
	assert_eq(Economy.calculate_port_prices(null), {})


# --- Producer / consumer / default multiplier coverage --------------------

func test_producer_multipliers_applied() -> void:
	GameState.travel_count = 0
	# Pick a seed where fluctuation ≈ 1.0 so we can sanity-check raw multipliers.
	# We don't need an exact match here — just that producer is < default.
	var port := _make_port("port_a", {
		"rum": { "buy": 20, "sell": 20, "is_producer": true },
	})
	var port_default := _make_port("port_a", {
		"rum": { "buy": 20, "sell": 20 },
	})
	var p_prod := Economy.calculate_port_prices(port)
	var p_def := Economy.calculate_port_prices(port_default)
	# Same seed, same fluctuation — producer buy MUST be strictly cheaper.
	assert_true(int(p_prod.rum.buy) < int(p_def.rum.buy), "producer cheaper than default")


func test_consumer_multipliers_applied() -> void:
	GameState.travel_count = 0
	var port := _make_port("port_b", {
		"rum": { "buy": 20, "sell": 20, "is_consumer": true },
	})
	var port_default := _make_port("port_b", {
		"rum": { "buy": 20, "sell": 20 },
	})
	var p_cons := Economy.calculate_port_prices(port)
	var p_def := Economy.calculate_port_prices(port_default)
	assert_true(int(p_cons.rum.buy) > int(p_def.rum.buy), "consumer pricier than default")


# --- Sell < buy clamp (anti-exploit) --------------------------------------

func test_sell_strictly_less_than_buy_always() -> void:
	# Hit every multiplier × a sweep of travel_counts so we'd catch any edge
	# where rounding lets sell == buy.
	var configs := [
		{}, # default
		{ "is_producer": true },
		{ "is_consumer": true },
	]
	for cfg in configs:
		for tc in range(0, 50):
			GameState.travel_count = tc
			var port := _make_port("seed_" + str(tc), {
				"rum": { "buy": 20, "sell": 20 }.merged(cfg),
			})
			var prices := Economy.calculate_port_prices(port)
			assert_true(
				int(prices.rum.sell) < int(prices.rum.buy),
				"sell<buy at tc=%d cfg=%s (buy=%d sell=%d)" % [
					tc, str(cfg), int(prices.rum.buy), int(prices.rum.sell)
				]
			)


# --- Travel-count drift ---------------------------------------------------

func test_prices_change_with_travel_count() -> void:
	# Same port, different travel_count → different prices (fluctuation moves).
	var port := _make_port("Nassau", {
		"rum": { "buy": 20, "sell": 20 },
	})
	GameState.travel_count = 0
	var a := Economy.calculate_port_prices(port)
	GameState.travel_count = 3
	var b := Economy.calculate_port_prices(port)
	# At least one of buy/sell should differ — wave_frequency * 3 is large
	# enough to shift the sine input meaningfully.
	assert_true(
		int(a.rum.buy) != int(b.rum.buy) or int(a.rum.sell) != int(b.rum.sell),
		"prices should change with travel_count"
	)


# --- port_seed determinism -----------------------------------------------

func test_port_seed_is_sum_of_char_codes() -> void:
	# N=78 a=97 s=115 s=115 a=97 u=117 → 619
	assert_eq(Economy.port_seed("Nassau"), 619)
	# Empty string is 0.
	assert_eq(Economy.port_seed(""), 0)


# --- Determinism across calls --------------------------------------------

func test_calculate_port_prices_is_pure() -> void:
	# Calling twice with the same state should produce identical output.
	var port := _make_port("Nassau", {
		"rum": { "buy": 20, "sell": 20, "is_producer": true },
		"tobacco": { "buy": 25, "sell": 25, "is_consumer": true },
	})
	GameState.travel_count = 7
	var a := Economy.calculate_port_prices(port)
	var b := Economy.calculate_port_prices(port)
	assert_eq(a, b, "pure function — same input, same output")
