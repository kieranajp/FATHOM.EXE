# InventoryScreen — modal cargo + gold display. Toggled by the `inventory`
# action (I key) at the HUD level. Closes on I or Escape.
#
# **Read-only.** No buy/sell from here — that's the market screen (T04).
# Listens passively for cargo_bought / cargo_sold via the parent HUD, which
# calls refresh() when open.
#
# When docked we show the current port's buy/sell columns; at sea we show base
# prices from the commodity defs as a navigation aid.
extends Control

const PORT_DIR := "res://data/ports/"
const COMMODITY_DIR := "res://data/commodities/"

@onready var _gold_label: Label = $Panel/V/Header/Gold
@onready var _capacity_label: Label = $Panel/V/Header/Capacity
@onready var _list_container: VBoxContainer = $Panel/V/Body/Scroll/List
# Only the price-column header is dynamic ("PORT BUY/SELL" vs "BASE PRICE").
@onready var _header_right: Label = $Panel/V/Body/HeaderRow/PriceHeader


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	# Allow Escape to close. The `inventory` key is handled at the HUD level
	# so the toggle works whether or not the inventory has focus.
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		visible = false
		EventBus.inventory_toggled.emit(false)
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	var ship_state: PlayerState = GameState.ship
	_gold_label.text = "GOLD:  %d D" % ship_state.gold

	var used := Economy.total_cargo_count(ship_state)
	var max_cargo := Economy.max_cargo_for(ship_state)
	var used_str := "%d" % int(used) if fmod(used, 1.0) == 0.0 else "%.1f" % used
	_capacity_label.text = "CARGO: %s / %d" % [used_str, max_cargo]

	var port_def := _current_port_def()
	if port_def != null:
		_header_right.text = "PORT  BUY / SELL"
	else:
		_header_right.text = "BASE PRICE"

	_clear_list()

	# Build rows in a stable order: alphabetical by item id. Iterate the union
	# of owned items + commodity defs so a player sees items they don't own (as
	# 0) while docked — useful for sell-side navigation.
	var ids := {}
	for k in ship_state.cargo.keys():
		ids[k] = true
	for path in _list_commodity_paths():
		var c := load(path) as Commodity
		if c != null:
			ids[c.id] = true

	var sorted := ids.keys()
	sorted.sort()

	for id in sorted:
		var row := _build_row(id, ship_state, port_def)
		_list_container.add_child(row)


func _build_row(id: String, ship_state: PlayerState, port_def: PortDef) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var commodity := _load_commodity(id)
	var label_text := id.to_upper()
	if commodity != null:
		label_text = commodity.short_code if commodity.short_code != "" else commodity.display_name.to_upper()

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.custom_minimum_size.x = 160
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "%d" % int(ship_state.cargo.get(id, 0))
	count_lbl.custom_minimum_size.x = 80
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count_lbl)

	var price_lbl := Label.new()
	if port_def != null and port_def.base_prices.has(id):
		var entry: Dictionary = port_def.base_prices[id]
		var buy: int = int(entry.get("buy", 0))
		var sell: int = int(entry.get("sell", 0))
		price_lbl.text = "%d / %d" % [buy, sell]
	elif commodity != null:
		price_lbl.text = "%d" % commodity.base_price
	else:
		price_lbl.text = "--"
	price_lbl.custom_minimum_size.x = 160
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)

	return row


func _clear_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()


func _current_port_def() -> PortDef:
	var id: String = GameState.current_port_id
	if id == "":
		return null
	var path := PORT_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PortDef


func _load_commodity(id: String) -> Commodity:
	var path := COMMODITY_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Commodity


func _list_commodity_paths() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(COMMODITY_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			out.append(COMMODITY_DIR + fname)
		fname = dir.get_next()
	return out


func _ship_max_cargo(ship_state: PlayerState) -> int:
	var path := "res://data/ships/" + ship_state.ship_class_id + ".tres"
	if ResourceLoader.exists(path):
		var sc := load(path) as ShipClass
		if sc != null:
			return sc.max_cargo
	return 100
