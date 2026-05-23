# Economy — port pricing, cargo/ammo trade validation, deterministic stocks.
#
# Pricing mirrors the JS reference (game.js:855-914):
#   - Per-port seed = sum of character codes in port id.
#   - Wave = sin(travel_count * freq + seed); fluctuation = 1.0 + wave * amplitude.
#   - Producer / consumer / default mults applied, then rounded, clamped to >=1,
#     and sell strictly < buy (anti-exploit clamp).
#
# Source-of-truth tuning lives in data/tuning/economy.tres. The JS port "name"
# field maps to our PortDef.id (snake_case); the JS-spec test uses "Nassau" as
# the seed input, so test_economy.gd seeds with capitalised display_names where
# it's reproducing the JS expected values directly.
extends Node

const SHIPS_DIR := "res://data/ships/"
const TUNING_PATH := "res://data/tuning/economy.tres"

const COMMODITY_DIR := "res://data/commodities/"
const AMMO_ITEMS: Array[String] = ["ball", "chain", "grape"]

var _tuning: EconomyTuning
var _base_prices: Dictionary = {}


func _ready() -> void:
	_load_base_prices()
	if ResourceLoader.exists(TUNING_PATH):
		_tuning = load(TUNING_PATH) as EconomyTuning
	else:
		_tuning = EconomyTuning.new()


func _load_base_prices() -> void:
	_base_prices.clear()
	var dir := DirAccess.open(COMMODITY_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".tres"):
				var path := COMMODITY_DIR + fname
				var c := load(path) as Commodity
				if c != null:
					_base_prices[c.id] = c.base_price
			fname = dir.get_next()


func get_tuning() -> EconomyTuning:
	if _tuning == null:
		_tuning = EconomyTuning.new()
	return _tuning


# Deterministic per-port seed used by both pricing and initial stocks.
# Sum of character codes in the seed string (typically port id).
func port_seed(seed_str: String) -> int:
	var total: int = 0
	for i in range(seed_str.length()):
		total += seed_str.unicode_at(i)
	return total


# Calculate buy/sell prices for a port. Returns {} for null input.
# Output schema: { item_id: { "buy": int, "sell": int,
#                             "is_producer": bool, "is_consumer": bool } }
func calculate_port_prices(port: PortDef) -> Dictionary:
	if port == null or port.base_prices == null:
		return {}
	var t := get_tuning()
	# Seed off the same string the JS uses (port.name). Our PortDef.id matches
	# the JS field semantically (a unique, stable per-port string).
	var seed := port_seed(port.id)
	var wave := sin(GameState.travel_count * t.wave_frequency + seed)
	var fluctuation := 1.0 + wave * t.wave_amplitude
	var prices: Dictionary = {}
	for item in port.base_prices:
		var cfg: Dictionary = port.base_prices[item]
		var base: int = _base_prices.get(item, cfg.get("buy", 20))
		var is_producer: bool = cfg.get("is_producer", false)
		var is_consumer: bool = cfg.get("is_consumer", false)
		var buy_mult := t.default_buy_mult
		var sell_mult := t.default_sell_mult
		if is_producer:
			buy_mult = t.producer_buy_mult
			sell_mult = t.producer_sell_mult
		elif is_consumer:
			buy_mult = t.consumer_buy_mult
			sell_mult = t.consumer_sell_mult
		var buy_price: int = int(round(base * buy_mult * fluctuation))
		var sell_price: int = int(round(base * sell_mult * fluctuation))
		buy_price = max(1, buy_price)
		sell_price = max(1, sell_price)
		# Anti-exploit: sell must be strictly less than buy.
		if sell_price >= buy_price:
			sell_price = max(1, buy_price - 1)
		prices[item] = {
			"buy": buy_price,
			"sell": sell_price,
			"is_producer": is_producer,
			"is_consumer": is_consumer,
		}
	return prices


# Ammo buy/sell price lookup. Sell is 0 by default (refit value).
func ammo_buy_price(ammo: String) -> int:
	var t := get_tuning()
	match ammo:
		"ball": return t.ammo_ball_buy
		"chain": return t.ammo_chain_buy
		"grape": return t.ammo_grape_buy
	return 0


func ammo_sell_price(ammo: String) -> int:
	var t := get_tuning()
	match ammo:
		"ball": return t.ammo_ball_sell
		"chain": return t.ammo_chain_sell
		"grape": return t.ammo_grape_sell
	return 0


func is_ammo(item: String) -> bool:
	return AMMO_ITEMS.has(item)


# Total cargo weight: commodity * 10 + ammo * 0.2. Rounded to 0.1 to dodge
# float noise (matches JS Math.round(total * 10) / 10).
func total_cargo_count(ship: PlayerState) -> float:
	if ship == null:
		return 0.0
	var t := get_tuning()
	var total: float = 0.0
	if ship.cargo != null:
		for k in ship.cargo:
			total += float(ship.cargo[k]) * t.commodity_weight
	if ship.ammo != null:
		for k in ship.ammo:
			total += float(ship.ammo[k]) * t.ammo_weight
	return round(total * 10.0) / 10.0


# Max cargo capacity of the player's current ship (looked up by ship_class_id).
# Defaults to dinghy's max_cargo if the class file is missing.
func max_cargo_for(ship: PlayerState) -> int:
	if ship == null:
		return 0
	var cls := _load_ship_class(ship.ship_class_id)
	if cls == null:
		return 100
	return cls.max_cargo


func _load_ship_class(class_id: String) -> ShipClass:
	var path := SHIPS_DIR + class_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ShipClass


# Buy-cargo validation. Returns { "success": bool, "reason": String (on fail) }.
func can_buy_cargo(ship: PlayerState, item: String, price: int) -> Dictionary:
	if ship == null:
		return { "success": false, "reason": "NO PLAYER STATE" }
	if ship.gold < price:
		return { "success": false, "reason": "TRANSACTION FAILED: INSUFFICIENT GOLD!" }
	var t := get_tuning()
	var weight := t.ammo_weight if is_ammo(item) else t.commodity_weight
	var total := total_cargo_count(ship)
	if total + weight > float(max_cargo_for(ship)):
		return { "success": false, "reason": "TRANSACTION FAILED: CARGO HOLD FULL!" }
	return { "success": true }


# Sell-cargo validation.
func can_sell_cargo(ship: PlayerState, item: String) -> Dictionary:
	if ship == null:
		return { "success": false, "reason": "NO PLAYER STATE" }
	var held: int = 0
	if is_ammo(item):
		held = int(ship.ammo.get(item, 0)) if ship.ammo != null else 0
	else:
		held = int(ship.cargo.get(item, 0)) if ship.cargo != null else 0
	if held <= 0:
		return { "success": false, "reason": "TRANSACTION FAILED: NO CARGO HELD!" }
	return { "success": true }


# Shipyard upgrade validation. Mirrors JS canUpgradeShip exactly.
# Returns { "success": bool, "cost": int (on success), "reason": String (on fail) }.
func can_upgrade_ship(ship: PlayerState, target_class_id: String) -> Dictionary:
	if ship == null:
		return { "success": false, "reason": "NO PLAYER STATE" }
	var target := _load_ship_class(target_class_id)
	if target == null:
		return { "success": false, "reason": "INVALID SHIP CLASS" }
	if ship.ship_class_id == target_class_id:
		return { "success": false, "reason": "ALREADY OWNED" }
	var current := _load_ship_class(ship.ship_class_id)
	if current == null:
		current = _load_ship_class("dinghy")
	var current_cost: int = current.cost if current != null else 0
	var current_max_hp: float = current.max_health if current != null else 100.0
	var health_ratio: float = 1.0
	if current_max_hp > 0.0:
		health_ratio = ship.health / current_max_hp
	var t := get_tuning()
	var trade_in: int = int(floor(current_cost * t.ship_tradein_fraction * health_ratio))
	var upgrade_cost: int = max(0, target.cost - trade_in)
	if ship.gold < upgrade_cost:
		return { "success": false, "reason": "INSUFFICIENT GOLD" }
	if total_cargo_count(ship) > float(target.max_cargo):
		return { "success": false, "reason": "CARGO HOLD OVERFLOW" }
	return { "success": true, "cost": upgrade_cost }


# Deterministic initial ammo stock for a port. Mirrors JS loadArchipelago:
#   seedVal = port_name.first_char + port_name.last_char  (JS adds idx, but we
#   want a value stable independent of archipelago load order, so we use the
#   summed port-id seed instead — still deterministic per port).
# Returns { "ball": int, "chain": int, "grape": int }.
func initial_ammo_stock(port_id: String) -> Dictionary:
	if port_id == "":
		return { "ball": 0, "chain": 0, "grape": 0 }
	var seed_val := port_id.unicode_at(0) + port_id.unicode_at(port_id.length() - 1)
	var ball_chance := float(seed_val % 10) / 10.0
	var chain_chance := float((seed_val * 3) % 10) / 10.0
	var grape_chance := float((seed_val * 7) % 10) / 10.0
	return {
		"ball": 8 + (seed_val % 15) if ball_chance < 0.75 else 0,
		"chain": 4 + (seed_val % 8) if chain_chance < 0.50 else 0,
		"grape": 3 + (seed_val % 6) if grape_chance < 0.40 else 0,
	}


# Deterministic initial ship stock for a port. Mirrors JS loadArchipelago
# shipStock loop: dinghy always 1, other classes get 0 or 1 from a hash of
# "<port_id>_<class_id>" compared against a per-tier chance.
# Returns { class_id: int }.
func initial_ship_stock(port_id: String) -> Dictionary:
	var stock: Dictionary = {}
	# Walk the ships directory to discover all class ids without hardcoding them.
	var dir := DirAccess.open(SHIPS_DIR)
	if dir == null:
		return { "dinghy": 1 }
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var name_clean := fname
			if name_clean.ends_with(".remap"):
				name_clean = name_clean.replace(".remap", "")
			if name_clean.ends_with(".tres"):
				var class_id := name_clean.get_basename()
				if class_id == "dinghy":
					stock[class_id] = 1
				else:
					var hash_val: int = 0
					var seed_str := port_id + "_" + class_id
					for i in range(seed_str.length()):
						# JS: hash = (hash * 31 + char) | 0  (int32 truncation)
						hash_val = _i32(hash_val * 31 + seed_str.unicode_at(i))
					var rand_val := float(abs(hash_val) % 1000) / 1000.0
					var chance := _stock_chance_for(class_id)
					stock[class_id] = 1 if rand_val < chance else 0
		fname = dir.get_next()
	if not stock.has("dinghy"):
		stock["dinghy"] = 1
	return stock


# Per-tier stock probability lookup. Tiers mirror JS classification.
func _stock_chance_for(class_id: String) -> float:
	match class_id:
		"schooner", "sloop": return 0.35
		"clipper", "brigantine": return 0.25
		"frigate", "galleon", "carrack": return 0.15
		"manofwar": return 0.08
	return 0.0


# Force a Godot int into a signed 32-bit range, matching JS `x | 0` semantics
# used in the hash loop above. Without this, GDScript's 64-bit ints would
# diverge from the JS reference once the hash accumulates above 2^31.
func _i32(x: int) -> int:
	var v: int = x & 0xFFFFFFFF
	if v >= 0x80000000:
		v -= 0x100000000
	return v


# Ensure ammo + ship stock exists for this port, generating on first visit
# from the deterministic seed. Called by the dock flow / Market / Shipyard
# before reading stock.
func ensure_port_stocks(port_id: String) -> void:
	if port_id == "":
		return
	if not GameState.port_ammo_stock.has(port_id):
		GameState.port_ammo_stock[port_id] = initial_ammo_stock(port_id)
	if not GameState.port_ship_stock.has(port_id):
		GameState.port_ship_stock[port_id] = initial_ship_stock(port_id)
