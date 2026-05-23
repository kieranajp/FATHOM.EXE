# Strategic Map Screen UI script (T08)
extends Control

const ARCHIPELAGO_DIR := "res://data/archipelagos/"
const PORT_DIR := "res://data/ports/"

const ARCHIPELAGO_POSITIONS = {
	"pirates_cradle": Vector2(500, 300),
	"spanish_main": Vector2(960, 540),
	"smugglers_run": Vector2(1420, 780)
}

const CIRCLE_RADIUS := 150.0
const PORT_SCALE := 0.15

var _archipelagos: Dictionary = {}
var _ports_cache: Dictionary = {}  # arch_id -> Array[PortDef]

var _pulse_timer: float = 0.0
var _hovered_id: String = ""


func _ready() -> void:
	# Pre-load archipelago data
	for arch_id in ARCHIPELAGO_POSITIONS.keys():
		var path: String = ARCHIPELAGO_DIR + arch_id + ".tres"

		if ResourceLoader.exists(path):
			var arch := load(path) as ArchipelagoDef
			if arch != null:
				_archipelagos[arch_id] = arch
				
				# Pre-load ports for this archipelago
				var port_defs: Array[PortDef] = []
				for port_id in arch.port_ids:
					var p_path := PORT_DIR + port_id + ".tres"
					if ResourceLoader.exists(p_path):
						var port := load(p_path) as PortDef
						if port != null:
							port_defs.append(port)
				_ports_cache[arch_id] = port_defs


func _process(delta: float) -> void:
	_pulse_timer += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") or event.is_action_pressed("quit"):
		EventBus.map_toggled.emit(false)
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventMouseMotion:
		var new_hover := ""
		for arch_id in ARCHIPELAGO_POSITIONS.keys():
			var center: Vector2 = ARCHIPELAGO_POSITIONS[arch_id]
			if event.position.distance_to(center) <= CIRCLE_RADIUS:
				new_hover = arch_id
				break
		if new_hover != _hovered_id:
			_hovered_id = new_hover
			queue_redraw()
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			for arch_id in ARCHIPELAGO_POSITIONS.keys():
				var center: Vector2 = ARCHIPELAGO_POSITIONS[arch_id]
				if event.position.distance_to(center) <= CIRCLE_RADIUS:
					_handle_archipelago_click(arch_id)
					get_viewport().set_input_as_handled()
					break


func _handle_archipelago_click(arch_id: String) -> void:
	if arch_id == GameState.current_archipelago_id:
		return  # Already there
		
	var arch: ArchipelagoDef = _archipelagos.get(arch_id)
	if arch != null:
		# Fast travel begins
		EventBus.travel_started.emit(arch)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 16
	var small_font_size := 12
	
	# Draw background grid decoration (retro sector style)
	_draw_background_decorations(font)

	for arch_id in _archipelagos.keys():
		var arch: ArchipelagoDef = _archipelagos[arch_id]
		var center: Vector2 = ARCHIPELAGO_POSITIONS[arch_id]
		var base_color: Color = arch.color
		
		var is_current: bool = (arch_id == GameState.current_archipelago_id)
		var is_visited: bool = (arch_id in GameState.visited_archipelagos or is_current)
		var is_hovered: bool = (arch_id == _hovered_id)
		
		# Set alpha based on visited state
		var draw_color := base_color
		if not is_visited:
			draw_color.a = 0.25  # Dimmed unvisited
		else:
			draw_color.a = 1.0   # Lit visited
			
		# 1. Draw circular vector boundary ring
		draw_arc(center, CIRCLE_RADIUS, 0, TAU, 64, draw_color, 1.5, true)
		
		# 2. Draw hover highlight ring or pulsing current highlight
		if is_current:
			var pulse: float = 1.0 + sin(_pulse_timer * 5.0) * 0.05
			var pulse_color := Color("#33ff33") # Glowing green for current ship home
			draw_arc(center, CIRCLE_RADIUS * pulse, 0, TAU, 64, pulse_color, 2.0, true)
		elif is_hovered:
			# Bold hover ring
			var hover_color := draw_color
			hover_color.a = 0.5
			draw_arc(center, CIRCLE_RADIUS + 4.0, 0, TAU, 64, hover_color, 2.0, true)

		# 3. Draw Archipelago Name and Sector
		var text_color := draw_color
		var title_text := arch.display_name
		var sector_text := "SECTOR: " + arch.sector
		
		draw_string(font, center + Vector2(-120, -CIRCLE_RADIUS - 20), title_text, HORIZONTAL_ALIGNMENT_LEFT, 240, font_size, text_color)
		draw_string(font, center + Vector2(-120, -CIRCLE_RADIUS - 5), sector_text, HORIZONTAL_ALIGNMENT_LEFT, 240, small_font_size, text_color * 0.8)

		# 4. Draw internal Ports
		var ports: Array[PortDef] = _ports_cache.get(arch_id, [])
		for port_def in ports:
			# Project 3D position onto 2D local space
			var local_pos := Vector2(port_def.position.x, port_def.position.z) * PORT_SCALE
			var port_screen_pos := center + local_pos
			
			# Draw small port dot
			draw_circle(port_screen_pos, 4.0, draw_color)
			
			# Draw port name slightly offset
			draw_string(font, port_screen_pos + Vector2(8, 4), port_def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, small_font_size, draw_color * 0.9)

		# 5. Draw Blinking Player Ship Indicator on current sector
		if is_current:
			var show_blink: bool = fmod(_pulse_timer * 3.0, 2.0) < 1.0
			if show_blink:
				var ship_pos := center + Vector2(0, -15)
				var points := PackedVector2Array([
					ship_pos + Vector2(0, -10),
					ship_pos + Vector2(-8, 8),
					ship_pos + Vector2(8, 8)
				])
				draw_colored_polygon(points, Color("#33ff33"))


func _draw_background_decorations(font: Font) -> void:
	# Draw thin retro background lines and frame
	var border_color := Color(0.1, 0.2, 0.15, 0.4)
	var text_color := Color(0.4, 0.5, 0.45, 0.6)
	
	# Horizontal grid lines
	for y in [150, 300, 450, 600, 750, 900]:
		draw_line(Vector2(50, y), Vector2(1870, y), border_color, 1.0)
		
	# Vertical grid lines
	for x in [240, 480, 720, 960, 1200, 1440, 1680]:
		draw_line(Vector2(x, 50), Vector2(x, 1030), border_color, 1.0)
		
	# Inner framing
	draw_rect(Rect2(50, 50, 1820, 980), border_color, false, 2.0)
	
	# Header & Footer text
	draw_string(font, Vector2(70, 90), "FATHOM.EXE // STRATEGIC NAVIGATION COMPUTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, text_color)
	draw_string(font, Vector2(1480, 90), "SYSTEM CLOCK: ACTIVE", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, text_color)
	draw_string(font, Vector2(70, 1010), "[M/ESC] EXIT MAP   |   [LEFT CLICK] SELECT ARCHIPELAGO FOR FAST TRAVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
