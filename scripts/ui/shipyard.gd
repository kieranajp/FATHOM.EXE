# Shipyard — docked port ship-class upgrade UI.
#
# Reads available ships from GameState.port_ship_stock[port_id], delegates
# upgrade validation + cost math to Economy.can_upgrade_ship. On purchase:
# deducts gold, swaps ship_class_id, restores HP to new max, decrements stock
# for new class, increments stock for old class, emits ship_purchased.
#
# Out-of-stock ships are hidden unless the player currently owns that class
# (in which case they're rendered as ACTIVE, per JS reference).
extends Control

const PORT_DIR := "res://data/ports/"
const SHIPS_DIR := "res://data/ships/"
# Display order — high to low cost roughly mirrors JS. Out-of-list classes
# still render (appended after this list) but it keeps the headline ones grouped.
const SHIP_ORDER: Array[String] = [
	"dinghy", "schooner", "sloop", "clipper",
	"brigantine", "frigate", "galleon", "carrack", "manofwar",
]

@onready var _rows: VBoxContainer = $Panel/V/Scroll/Rows
@onready var _message: Label = $Panel/V/Console/Message
@onready var _hull_label: Label = $Panel/V/Footer/Hull
@onready var _gold_label: Label = $Panel/V/Footer/Gold
@onready var _leave_btn: Button = $Panel/V/Footer/Leave

var _port: PortDef
var _ships: Dictionary  # class_id -> ShipClass


func _ready() -> void:
	_leave_btn.pressed.connect(_on_leave_pressed)
	_load_ship_catalogue()
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


func _load_ship_catalogue() -> void:
	_ships = {}
	var dir := DirAccess.open(SHIPS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var clean := fname
			if clean.ends_with(".remap"):
				clean = clean.replace(".remap", "")
			if clean.ends_with(".tres"):
				var class_id := clean.get_basename()
				var path := SHIPS_DIR + clean
				var sc := load(path) as ShipClass
				if sc != null:
					_ships[class_id] = sc
		fname = dir.get_next()


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var current_id := GameState.ship.ship_class_id
	var stock: Dictionary = GameState.port_ship_stock.get(_port.id, {})
	# Render in canonical order, then any unrecognised ids after.
	var rendered: Dictionary = {}
	for cid in SHIP_ORDER:
		if _ships.has(cid):
			_maybe_add_row(cid, current_id, stock)
			rendered[cid] = true
	for cid in _ships:
		if not rendered.has(cid):
			_maybe_add_row(cid, current_id, stock)
	_update_footer()


func _maybe_add_row(class_id: String, current_id: String, stock: Dictionary) -> void:
	var sc: ShipClass = _ships[class_id]
	var is_owned := current_id == class_id
	var in_stock: int = int(stock.get(class_id, 0))
	if not is_owned and in_stock <= 0:
		return
	_rows.add_child(_build_row(sc, is_owned))


func _build_row(sc: ShipClass, is_owned: bool) -> Control:
	var current: ShipClass = _ships.get(GameState.ship.ship_class_id)
	if current == null:
		current = _ships.get("dinghy")
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = sc.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_stretch_ratio = 2.0
	name_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(name_lbl)

	hbox.add_child(_stat_label(sc.base_max_speed, current.base_max_speed))
	hbox.add_child(_stat_label(sc.max_cargo, current.max_cargo))
	hbox.add_child(_stat_label(sc.max_health, current.max_health))
	hbox.add_child(_stat_label(sc.firepower, current.firepower))

	var cost_box := HBoxContainer.new()
	cost_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_box.size_flags_stretch_ratio = 2.0
	cost_box.alignment = BoxContainer.ALIGNMENT_CENTER

	if is_owned:
		var active_lbl := Label.new()
		active_lbl.text = "ACTIVE"
		active_lbl.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
		active_lbl.add_theme_font_size_override("font_size", 12)
		cost_box.add_child(active_lbl)
	else:
		var validation := Economy.can_upgrade_ship(GameState.ship, sc.id)
		var cost: int = int(validation.get("cost", _preview_cost(sc)))
		var cost_lbl := Label.new()
		cost_lbl.text = "%d D" % cost
		cost_lbl.add_theme_color_override("font_color", Color(1, 0.733333, 0, 1))
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_box.add_child(cost_lbl)

		var btn := Button.new()
		if validation.success:
			btn.text = "[COMMISSION]"
			btn.pressed.connect(Callable(self, "_on_buy_pressed").bind(sc.id))
		else:
			match validation.reason:
				"CARGO HOLD OVERFLOW":
					btn.text = "[OVERFLOW]"
				_:
					btn.text = "[LOCKED]"
			btn.disabled = true
		cost_box.add_child(btn)

	hbox.add_child(cost_box)
	return hbox


func _preview_cost(sc: ShipClass) -> int:
	# Used when can_upgrade_ship fails (no cost field returned) — show the
	# raw post-trade-in number so the player understands what gold gap they're
	# looking at, rather than a blank.
	var current: ShipClass = _ships.get(GameState.ship.ship_class_id)
	var current_cost: int = current.cost if current != null else 0
	var current_max_hp: float = current.max_health if current != null else 100.0
	var ratio: float = 1.0
	if current_max_hp > 0.0:
		ratio = GameState.ship.health / current_max_hp
	var trade_in := int(floor(current_cost * Economy.get_tuning().ship_tradein_fraction * ratio))
	return max(0, sc.cost - trade_in)


func _stat_label(value: float, baseline: float) -> Label:
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	var diff: float = value - baseline
	if abs(value - round(value)) < 0.05 and abs(baseline - round(baseline)) < 0.05:
		lbl.text = "%d" % int(round(value))
	else:
		lbl.text = "%.1f" % value
	if diff > 0.01:
		lbl.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
	elif diff < -0.01:
		lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	return lbl


func _update_footer() -> void:
	var current: ShipClass = _ships.get(GameState.ship.ship_class_id)
	_hull_label.text = "HULL: %s" % (current.display_name.to_upper() if current != null else "?")
	_gold_label.text = "GOLD: %d D" % GameState.ship.gold


func _on_buy_pressed(target_id: String) -> void:
	var validation := Economy.can_upgrade_ship(GameState.ship, target_id)
	if not validation.success:
		_fail(validation.reason)
		return
	var cost: int = int(validation.cost)
	var old_id := GameState.ship.ship_class_id
	GameState.ship.gold -= cost
	GameState.ship.ship_class_id = target_id
	var new_class: ShipClass = _ships.get(target_id)
	if new_class != null:
		GameState.ship.health = new_class.max_health
	# Update stock for both classes at this port. New class depletes by 1 to 0,
	# old class incremented by 1 so a player could in principle trade back.
	var stock: Dictionary = GameState.port_ship_stock.get(_port.id, {})
	stock[target_id] = max(0, int(stock.get(target_id, 0)) - 1)
	stock[old_id] = int(stock.get(old_id, 0)) + 1
	GameState.port_ship_stock[_port.id] = stock
	EventBus.ship_purchased.emit(target_id)
	AudioBus.play_beep(1200.0, 0.15)
	var name: String = new_class.display_name.to_upper() if new_class != null else target_id.to_upper()
	_message.text = "> DEED OF SALE CONFIRMED. WELCOME CAPTAIN OF THE %s!" % name
	_refresh()


func _fail(reason: String) -> void:
	_message.text = "> TRANSACTION DENIED: %s" % reason
	AudioBus.play_beep(180.0, 0.2)
	EventBus.market_transaction_failed.emit(reason)


func _on_leave_pressed() -> void:
	AudioBus.play_beep(800.0, 0.05)
	queue_free()
