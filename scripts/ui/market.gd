# Market — docked port commodity & ammunition trading UI.
#
# Reads prices from Economy.calculate_port_prices, ammo prices from
# Economy.ammo_*_price, ammo stock from GameState.port_ammo_stock. Mutates
# GameState.ship.gold / cargo / ammo and the port's ammo_stock entry on
# successful transactions. Emits cargo_bought / cargo_sold /
# market_transaction_failed.
extends Control

const PORT_DIR := "res://data/ports/"
const COMMODITY_DIR := "res://data/commodities/"
const COMMODITY_ORDER: Array[String] = [
	"rum", "sugar", "tobacco", "spices",
	"coffee", "cocoa", "textiles", "wood",
]
const AMMO_ORDER: Array[String] = ["ball", "chain", "grape"]
const AMMO_LABELS: Dictionary = {
	"ball": "Ball Shot",
	"chain": "Chain Shot",
	"grape": "Grape Shot",
}

@onready var _rows: VBoxContainer = $Panel/V/Scroll/Rows
@onready var _message: Label = $Panel/V/Console/Message
@onready var _gold_label: Label = $Panel/V/Footer/Gold
@onready var _hold_label: Label = $Panel/V/Footer/Hold
@onready var _leave_btn: Button = $Panel/V/Footer/Leave

var _port: PortDef
var _prices: Dictionary  # item_id -> { buy, sell, is_producer, is_consumer }
var _commodities: Dictionary  # id -> Commodity


func _ready() -> void:
	_leave_btn.pressed.connect(_on_leave_pressed)
	_load_commodity_catalogue()
	_port = _load_current_port()
	if _port == null:
		_message.text = "> ERROR: NO ACTIVE PORT"
		return
	Economy.ensure_port_stocks(_port.id)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_leave_pressed()
		get_viewport().set_input_as_handled()


func _load_current_port() -> PortDef:
	var pid := GameState.current_port_id
	if pid == "":
		return null
	var path := PORT_DIR + pid + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PortDef


func _load_commodity_catalogue() -> void:
	_commodities = {}
	for id in COMMODITY_ORDER:
		var path := COMMODITY_DIR + id + ".tres"
		if ResourceLoader.exists(path):
			_commodities[id] = load(path) as Commodity


# Full refresh: recalc prices, rebuild rows, refresh footer telemetry.
func _refresh() -> void:
	_prices = Economy.calculate_port_prices(_port)
	for child in _rows.get_children():
		child.queue_free()
	# Commodity rows — only those listed in port.base_prices (the port traded set).
	for cid in COMMODITY_ORDER:
		if _prices.has(cid):
			_rows.add_child(_build_commodity_row(cid))
	# Ammo divider + rows.
	_rows.add_child(_build_divider("AMMUNITION & REFITTING"))
	for ammo in AMMO_ORDER:
		_rows.add_child(_build_ammo_row(ammo))
	_update_footer()


func _build_divider(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = "> " + text
	lbl.add_theme_color_override("font_color", Color(1, 0.667, 0, 1))
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl


func _build_commodity_row(cid: String) -> Control:
	var info: Dictionary = _prices[cid]
	var commodity: Commodity = _commodities.get(cid)
	var display_name: String = commodity.display_name if commodity != null else cid.capitalize()
	var badge := ""
	if info.get("is_producer", false):
		badge = " [PRODUCER]"
	elif info.get("is_consumer", false):
		badge = " [CONSUMER]"
	var held: int = int(GameState.ship.cargo.get(cid, 0))
	var row := _make_row(
		display_name + badge,
		info.buy,
		info.sell,
		held,
		Callable(self, "_on_buy_pressed").bind(cid),
		Callable(self, "_on_sell_pressed").bind(cid),
	)
	return row


func _build_ammo_row(ammo: String) -> Control:
	var buy: int = Economy.ammo_buy_price(ammo)
	var sell: int = Economy.ammo_sell_price(ammo)
	var held: int = int(GameState.ship.ammo.get(ammo, 0))
	var stock_dict: Dictionary = GameState.port_ammo_stock.get(_port.id, {})
	var stock: int = int(stock_dict.get(ammo, 0))
	var stock_text := " (%d avail)" % stock if stock > 0 else " [OUT OF STOCK]"
	var row := _make_row(
		AMMO_LABELS[ammo] + stock_text,
		buy,
		sell,
		held,
		Callable(self, "_on_buy_pressed").bind(ammo),
		Callable(self, "_on_sell_pressed").bind(ammo),
	)
	return row


func _make_row(item_text: String, buy_price: int, sell_price: int, held: int,
	buy_cb: Callable, sell_cb: Callable) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = item_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_stretch_ratio = 3.0
	name_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(name_lbl)

	var buy_lbl := Label.new()
	buy_lbl.text = "%d D" % buy_price
	buy_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_lbl.add_theme_color_override("font_color", Color(0, 1, 0.8, 1))
	buy_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(buy_lbl)

	var sell_lbl := Label.new()
	sell_lbl.text = "%d D" % sell_price
	sell_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_lbl.add_theme_color_override("font_color", Color(1, 0.733333, 0, 1))
	sell_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(sell_lbl)

	var held_lbl := Label.new()
	held_lbl.text = str(held)
	held_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	held_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	held_lbl.add_theme_font_size_override("font_size", 12)
	if held > 0:
		held_lbl.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
	hbox.add_child(held_lbl)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_stretch_ratio = 2.0
	actions.alignment = BoxContainer.ALIGNMENT_CENTER

	var buy_btn := Button.new()
	buy_btn.text = "[BUY]"
	buy_btn.pressed.connect(buy_cb)
	actions.add_child(buy_btn)

	var sell_btn := Button.new()
	sell_btn.text = "[SELL]"
	sell_btn.pressed.connect(sell_cb)
	actions.add_child(sell_btn)

	hbox.add_child(actions)
	return hbox


func _update_footer() -> void:
	_gold_label.text = "GOLD: %d D" % GameState.ship.gold
	var total := Economy.total_cargo_count(GameState.ship)
	var maxc := Economy.max_cargo_for(GameState.ship)
	_hold_label.text = "HOLD: %s / %d" % [_format_weight(total), maxc]


func _format_weight(w: float) -> String:
	# Drop trailing .0 for tidiness, keep one decimal otherwise.
	if abs(w - round(w)) < 0.05:
		return "%d" % int(round(w))
	return "%.1f" % w


# --- Transactions --------------------------------------------------------

func _on_buy_pressed(item: String) -> void:
	var is_ammo := Economy.is_ammo(item)
	# Ammo stock check first (canBuyCargo doesn't know about port stock).
	if is_ammo:
		var stock_dict: Dictionary = GameState.port_ammo_stock.get(_port.id, {})
		var stock: int = int(stock_dict.get(item, 0))
		if stock <= 0:
			var reason := "TRANSACTION FAILED: %s OUT OF STOCK!" % AMMO_LABELS[item].to_upper()
			_fail(reason)
			return
	var price := _buy_price_for(item)
	var validation := Economy.can_buy_cargo(GameState.ship, item, price)
	if not validation.success:
		_fail(validation.reason)
		return
	GameState.ship.gold -= price
	if is_ammo:
		GameState.ship.ammo[item] = int(GameState.ship.ammo.get(item, 0)) + 1
		var stock_dict2: Dictionary = GameState.port_ammo_stock.get(_port.id, {})
		stock_dict2[item] = int(stock_dict2.get(item, 0)) - 1
		GameState.port_ammo_stock[_port.id] = stock_dict2
	else:
		GameState.ship.cargo[item] = int(GameState.ship.cargo.get(item, 0)) + 1
	EventBus.cargo_bought.emit(item, 1, price)
	AudioBus.play_beep(800.0, 0.05)
	_message.text = "> BOUGHT 1 %s FOR %d D" % [item.to_upper(), price]
	_refresh()


func _on_sell_pressed(item: String) -> void:
	var validation := Economy.can_sell_cargo(GameState.ship, item)
	if not validation.success:
		_fail(validation.reason)
		return
	var price := _sell_price_for(item)
	GameState.ship.gold += price
	if Economy.is_ammo(item):
		GameState.ship.ammo[item] = int(GameState.ship.ammo.get(item, 0)) - 1
		var stock_dict: Dictionary = GameState.port_ammo_stock.get(_port.id, {})
		stock_dict[item] = int(stock_dict.get(item, 0)) + 1
		GameState.port_ammo_stock[_port.id] = stock_dict
	else:
		GameState.ship.cargo[item] = int(GameState.ship.cargo.get(item, 0)) - 1
	EventBus.cargo_sold.emit(item, 1, price)
	AudioBus.play_beep(900.0, 0.05)
	_message.text = "> SOLD 1 %s FOR %d D" % [item.to_upper(), price]
	_refresh()


func _buy_price_for(item: String) -> int:
	if Economy.is_ammo(item):
		return Economy.ammo_buy_price(item)
	var entry: Dictionary = _prices.get(item, {})
	return int(entry.get("buy", 0))


func _sell_price_for(item: String) -> int:
	if Economy.is_ammo(item):
		return Economy.ammo_sell_price(item)
	var entry: Dictionary = _prices.get(item, {})
	return int(entry.get("sell", 0))


func _fail(reason: String) -> void:
	_message.text = "> " + reason
	AudioBus.play_beep(180.0, 0.2)
	EventBus.market_transaction_failed.emit(reason)


func _on_leave_pressed() -> void:
	AudioBus.play_beep(800.0, 0.05)
	queue_free()
