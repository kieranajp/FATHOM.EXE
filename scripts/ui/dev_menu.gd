# DevMenu — diagnostic overlay toggled by backtick key at the main level.
# Provides ammo editing, ship class swapping, enemy spawning, and a price matrix.
extends CanvasLayer

const PORT_DIR := "res://data/ports/"
const COMMODITY_DIR := "res://data/commodities/"
const SHIP_DIR := "res://data/ships/"

# Dev-menu hostile spawns drop the enemy 50m ahead of the player — close
# enough for immediate combat testing (vs combat.tres spawn_min/max_distance
# = 80..200m for ambient pirate spawns). Kept as a const here rather than in
# combat tuning so this remains a "debug knob" not a balance knob.
const SPAWN_DISTANCE_M := 50.0

# All loaded resources
var _ports: Array[PortDef] = []
var _commodities: Array[Commodity] = []
var _ship_classes: Array[String] = [
	"dinghy", "sloop", "schooner", "brigantine", "clipper", "carrack", "frigate", "galleon", "manofwar"
]

# UI elements we need to reference
var _ammo_labels: Dictionary = {}
var _class_dropdown: OptionButton
var _spawn_dropdown: OptionButton
var _price_grid: GridContainer


func _ready() -> void:
	# Load commodities and ports
	_load_resources()

	# Create Backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.06, 0.05, 0.85) # Very dark green-grey translucent
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Main Layout Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 650)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	
	# Apply gorgeous styling
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.07, 0.98) # Solid CRT green terminal background
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.73, 0.0, 0.8) # Glowing amber border
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# Main vertical layout inside panel
	var v_main := VBoxContainer.new()
	v_main.add_theme_constant_override("separation", 16)
	panel.add_child(v_main)

	# Title Bar
	var title_lbl := Label.new()
	title_lbl.text = "FATHOM.EXE // DEV DIAGNOSTICS COMPUTER"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.73, 0.0, 1.0)) # Bright amber
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_main.add_child(title_lbl)

	# Subtitle / Footer helper
	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "[ ` ] OR [ESC] CLOSE DIAGNOSTICS MENU"
	subtitle_lbl.modulate = Color(1, 1, 1, 0.5)
	subtitle_lbl.add_theme_font_size_override("font_size", 11)
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_main.add_child(subtitle_lbl)

	# Horizontal separator
	var sep := HSeparator.new()
	v_main.add_child(sep)

	# Main horizontal body split: left column (controls), right column (price matrix)
	var h_body := HBoxContainer.new()
	h_body.add_theme_constant_override("separation", 32)
	h_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_main.add_child(h_body)

	# --- LEFT PANEL (Controls) ---
	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 20)
	left_v.custom_minimum_size.x = 420
	h_body.add_child(left_v)

	# Left Section 1: AMMO EDIT
	_build_ammo_section(left_v)

	# Left Section 2: SHIP CLASS SWAP
	_build_ship_swap_section(left_v)

	# Left Section 3: HOSTILE SPAWN
	_build_spawn_section(left_v)

	# --- RIGHT PANEL (Price Matrix) ---
	var right_v := VBoxContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_body.add_child(right_v)
	
	_build_price_matrix_section(right_v)

	# Initial refresh of all values
	refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_menu") or event.is_action_pressed("ui_cancel"):
		EventBus.dev_menu_toggled.emit(false)
		get_viewport().set_input_as_handled()


func _load_resources() -> void:
	# Load Commodities
	var dir := DirAccess.open(COMMODITY_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".tres"):
				var c := load(COMMODITY_DIR + fname) as Commodity
				if c != null:
					_commodities.append(c)
			fname = dir.get_next()
	# Sort commodities by ID so columns are stable
	_commodities.sort_custom(func(a, b): return a.id < b.id)

	# Load Ports
	dir = DirAccess.open(PORT_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".tres"):
				var p := load(PORT_DIR + fname) as PortDef
				if p != null:
					_ports.append(p)
			fname = dir.get_next()
	# Sort ports alphabetically by display name
	_ports.sort_custom(func(a, b): return a.display_name < b.display_name)


func _build_ammo_section(parent: Node) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	parent.add_child(container)

	var header := Label.new()
	header.text = "--- AMMO QUANTITY EDITOR ---"
	header.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.9)) # Neon green
	header.add_theme_font_size_override("font_size", 13)
	container.add_child(header)

	var ammo_types := ["ball", "chain", "grape"]
	for type in ammo_types:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		container.add_child(row)

		var lbl := Label.new()
		lbl.text = type.to_upper()
		lbl.custom_minimum_size.x = 100
		row.add_child(lbl)

		# Minus 10 button
		var btn_minus_10 := Button.new()
		btn_minus_10.text = "-10"
		btn_minus_10.custom_minimum_size.x = 45
		btn_minus_10.pressed.connect(func(): _adjust_ammo(type, -10))
		row.add_child(btn_minus_10)

		# Minus 1 button
		var btn_minus_1 := Button.new()
		btn_minus_1.text = "-"
		btn_minus_1.custom_minimum_size.x = 35
		btn_minus_1.pressed.connect(func(): _adjust_ammo(type, -1))
		row.add_child(btn_minus_1)

		# Count display
		var count_lbl := Label.new()
		count_lbl.text = "000"
		count_lbl.custom_minimum_size.x = 50
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ammo_labels[type] = count_lbl
		row.add_child(count_lbl)

		# Plus 1 button
		var btn_plus_1 := Button.new()
		btn_plus_1.text = "+"
		btn_plus_1.custom_minimum_size.x = 35
		btn_plus_1.pressed.connect(func(): _adjust_ammo(type, 1))
		row.add_child(btn_plus_1)

		# Plus 10 button
		var btn_plus_10 := Button.new()
		btn_plus_10.text = "+10"
		btn_plus_10.custom_minimum_size.x = 45
		btn_plus_10.pressed.connect(func(): _adjust_ammo(type, 10))
		row.add_child(btn_plus_10)


func _build_ship_swap_section(parent: Node) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	parent.add_child(container)

	var header := Label.new()
	header.text = "--- SHIP CLASS SWAPPER ---"
	header.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.9)) # Neon green
	header.add_theme_font_size_override("font_size", 13)
	container.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	container.add_child(row)

	_class_dropdown = OptionButton.new()
	_class_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cls in _ship_classes:
		_class_dropdown.add_item(cls.to_upper())
	row.add_child(_class_dropdown)

	var btn_apply := Button.new()
	btn_apply.text = "APPLY SWAP"
	btn_apply.pressed.connect(_on_apply_ship_swap)
	row.add_child(btn_apply)


func _build_spawn_section(parent: Node) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	parent.add_child(container)

	var header := Label.new()
	header.text = "--- SPAWN PIRATE RAIDER ---"
	header.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.9)) # Neon green
	header.add_theme_font_size_override("font_size", 13)
	container.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	container.add_child(row)

	_spawn_dropdown = OptionButton.new()
	_spawn_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cls in _ship_classes:
		_spawn_dropdown.add_item(cls.to_upper())
	# Default to sloop as is typical
	var sloop_idx := _ship_classes.find("sloop")
	if sloop_idx != -1:
		_spawn_dropdown.selected = sloop_idx
	row.add_child(_spawn_dropdown)

	var btn_spawn := Button.new()
	btn_spawn.text = "SPAWN 50M AHEAD"
	btn_spawn.pressed.connect(_on_spawn_pirate)
	row.add_child(btn_spawn)


func _build_price_matrix_section(parent: Node) -> void:
	var header := Label.new()
	header.text = "--- COMMODITY PRICE MATRIX (PORT BUY / SELL) ---"
	header.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.9)) # Neon green
	header.add_theme_font_size_override("font_size", 13)
	parent.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 400
	parent.add_child(scroll)

	# Columns: 1 for Port name + 8 commodities = 9 columns
	_price_grid = GridContainer.new()
	_price_grid.columns = 9
	_price_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price_grid.add_theme_constant_override("h_separation", 12)
	_price_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_price_grid)


func refresh_all() -> void:
	# 1. Update Ammo labels
	var ship_state: PlayerState = GameState.ship
	if ship_state != null and ship_state.ammo != null:
		for type in _ammo_labels.keys():
			var count = ship_state.ammo.get(type, 0)
			_ammo_labels[type].text = "%d" % int(count)

	# 2. Update Class Dropdown selection
	if ship_state != null:
		var current_cls := ship_state.ship_class_id
		var idx := _ship_classes.find(current_cls)
		if idx != -1:
			_class_dropdown.selected = idx

	# 3. Rebuild Price Matrix
	_rebuild_price_matrix()


func _rebuild_price_matrix() -> void:
	# Clear existing children
	for child in _price_grid.get_children():
		child.queue_free()

	# Create Table Headers
	var header_style := Label.new()
	header_style.text = "PORT"
	header_style.add_theme_color_override("font_color", Color(1.0, 0.73, 0.0, 1.0))
	header_style.add_theme_font_size_override("font_size", 11)
	_price_grid.add_child(header_style)

	for c in _commodities:
		var code := c.short_code if c.short_code != "" else c.display_name.substr(0, 3).to_upper()
		var col_header := Label.new()
		col_header.text = code
		col_header.add_theme_color_override("font_color", Color(1.0, 0.73, 0.0, 1.0))
		col_header.add_theme_font_size_override("font_size", 11)
		col_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_price_grid.add_child(col_header)

	# Create Row per Port
	for port in _ports:
		# Cell 1: Port Name
		var port_lbl := Label.new()
		port_lbl.text = port.display_name.to_upper()
		port_lbl.add_theme_font_size_override("font_size", 11)
		_price_grid.add_child(port_lbl)

		# Price mapping for this port
		var prices := Economy.calculate_port_prices(port)

		for c in _commodities:
			var cell_lbl := Label.new()
			cell_lbl.add_theme_font_size_override("font_size", 10)
			cell_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

			if prices.has(c.id):
				var entry: Dictionary = prices[c.id]
				var buy: int = int(entry.get("buy", 0))
				var sell: int = int(entry.get("sell", 0))
				
				# Highlight producers or consumers
				if entry.get("is_producer", false):
					cell_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 0.85)) # Green tinted producer
				elif entry.get("is_consumer", false):
					cell_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 0.85)) # Red tinted consumer
				else:
					cell_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7)) # Neutral grey
				
				cell_lbl.text = "%d/%d" % [buy, sell]
			else:
				cell_lbl.text = "--"
				cell_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1.0))

			_price_grid.add_child(cell_lbl)


func _adjust_ammo(type: String, delta: int) -> void:
	var ship_state: PlayerState = GameState.ship
	if ship_state != null and ship_state.ammo != null:
		var current = int(ship_state.ammo.get(type, 0))
		ship_state.ammo[type] = max(0, current + delta)
		# Update UI
		refresh_all()


func _on_apply_ship_swap() -> void:
	var idx := _class_dropdown.selected
	if idx < 0 or idx >= _ship_classes.size():
		return
	var selected_class_id := _ship_classes[idx]
	var ship_state: PlayerState = GameState.ship
	if ship_state != null:
		# Update GameState class
		ship_state.ship_class_id = selected_class_id
		
		# Restore HP: load class stats
		var path := SHIP_DIR + selected_class_id + ".tres"
		if ResourceLoader.exists(path):
			var sc := load(path) as ShipClass
			if sc != null:
				ship_state.health = sc.max_health
		
		# Find PlayerShip node in active scene tree to trigger visual rebuild
		var scene_root := get_tree().root
		var player := scene_root.find_child("PlayerShip", true, false)
		if player != null and player.has_method("update_ship_class"):
			player.update_ship_class()

		# Trigger immediate UI refresh
		refresh_all()


func _on_spawn_pirate() -> void:
	var idx := _spawn_dropdown.selected
	if idx < 0 or idx >= _ship_classes.size():
		return
	var selected_class_id := _ship_classes[idx]

	var scene_root := get_tree().root
	var player := scene_root.find_child("PlayerShip", true, false) as Node3D
	if player == null:
		# Revert gracefully if player isn't mounted (e.g. headless tests or menus)
		EventBus.hud_message.emit("SPAWN FAILED: NO PLAYER SHIP FOUND", "warning")
		return

	# Places a pirate ~50m ahead of the player
	# In Godot, player's forward vector is -global_transform.basis.z
	var forward := -player.global_transform.basis.z
	var spawn_pos := player.global_position + forward * SPAWN_DISTANCE_M

	var spawner := scene_root.find_child("EnemySpawner", true, false)
	if spawner != null and spawner.has_method("spawn_at"):
		var enemy = spawner.spawn_at(selected_class_id, spawn_pos, "pirate")
		if enemy != null:
			EventBus.hud_message.emit("SPAWNED PIRATE (%s) 50M AHEAD" % selected_class_id.to_upper(), "info")
		else:
			EventBus.hud_message.emit("SPAWN FAILED: ENEMY SPAWNER REFUSED", "warning")
	else:
		EventBus.hud_message.emit("SPAWN FAILED: NO ENEMY SPAWNER IN SCENE", "warning")
