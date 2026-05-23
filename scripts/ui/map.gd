# Strategic Map Screen UI script (T08)
#
# Per-archipelago map position + radius live on ArchipelagoDef (data-driven).
# Cosmetic/animation numbers live on data/tuning/map.tres (MapTuning).
class_name MapScreen extends Control

const ARCHIPELAGO_DIR := "res://data/archipelagos/"
const PORT_DIR := "res://data/ports/"
const KNOWN_ARCHIPELAGO_IDS: Array[String] = ["pirates_cradle", "spanish_main", "smugglers_run"]

var _archipelagos: Dictionary = {}        # arch_id -> ArchipelagoDef
var _ports_cache: Dictionary = {}         # arch_id -> Array[PortDef]
var _tuning: MapTuning
var _travel_tuning: TravelTuning

var _pulse_timer: float = 0.0
var _hovered_id: String = ""


# Pure helper — maps an ArchipelagoDef.risk_tier (1/2/3) to its short label.
# Pulled out static so tests can hit it without spinning up the scene.
static func risk_label_for_tier(risk_tier: int) -> String:
	match risk_tier:
		3:
			return "HIGH"
		2:
			return "MED"
		_:
			return "LOW"


# Pure helper — maps risk_tier to its faction-style colour for the map label.
# Cyan = safe-ish, amber = caution, red = bad time.
static func risk_color_for_tier(risk_tier: int) -> Color:
	match risk_tier:
		3:
			return Color("#ff3333")
		2:
			return Color("#ffaa33")
		_:
			return Color("#33ddff")


# Pure hit-test helper — given a click point and an archipelago def, returns
# true if the click landed inside (or exactly on the edge of) the archipelago's
# circle. Pulled out so unit tests can hammer it without spinning up the scene.
static func hit_test(point: Vector2, arch: ArchipelagoDef) -> bool:
	if arch == null:
		return false
	return point.distance_to(arch.map_position) <= arch.map_radius


# Pure helper — returns the id of the first archipelago whose circle the point
# lands inside, or "" if none. Iteration order matches the input list, which
# means callers should pass them in z-order (top-most first) if there's any
# overlap risk.
static func pick_archipelago(point: Vector2, archs: Array) -> String:
	for arch in archs:
		var a := arch as ArchipelagoDef
		if a != null and hit_test(point, a):
			return a.id
	return ""


func _ready() -> void:
	_tuning = load("res://data/tuning/map.tres") as MapTuning
	_travel_tuning = load("res://data/tuning/travel.tres") as TravelTuning

	# Pre-load archipelago data
	for arch_id in KNOWN_ARCHIPELAGO_IDS:
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
		var new_hover: String = pick_archipelago(event.position, _archipelagos.values())
		if new_hover != _hovered_id:
			_hovered_id = new_hover
			queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var hit_id: String = pick_archipelago(event.position, _archipelagos.values())
			if hit_id != "":
				_handle_archipelago_click(hit_id)
				get_viewport().set_input_as_handled()


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
		var center: Vector2 = arch.map_position
		var radius: float = arch.map_radius
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
		draw_arc(center, radius, 0, TAU, 64, draw_color, _tuning.circle_line_width, true)

		# 2. Draw hover highlight ring or pulsing current highlight
		if is_current:
			var pulse: float = 1.0 + sin(_pulse_timer * _tuning.pulse_speed) * 0.05
			var pulse_color := Color("#33ff33") # Glowing green for current ship home
			draw_arc(center, radius * pulse, 0, TAU, 64, pulse_color, 2.0, true)
		elif is_hovered:
			# Bold hover ring
			var hover_color := draw_color
			hover_color.a = 0.5
			draw_arc(center, radius + 4.0, 0, TAU, 64, hover_color, 2.0, true)

		# 3. Draw Archipelago Name and Sector
		var text_color := draw_color
		var title_text := arch.display_name
		var sector_text := "SECTOR: " + arch.sector

		draw_string(font, center + Vector2(-120, -radius - 20), title_text, HORIZONTAL_ALIGNMENT_LEFT, 240, font_size, text_color)
		draw_string(font, center + Vector2(-120, -radius - 5), sector_text, HORIZONTAL_ALIGNMENT_LEFT, 240, small_font_size, text_color * 0.8)

		# 3b. Risk-tier label (T39) — sits under the circle so it's legible
		# against the dimmed unvisited tint, and stays clear of the port dots
		# inside the circle.
		var risk_label: String = "RISK: " + risk_label_for_tier(arch.risk_tier)
		var risk_color: Color = risk_color_for_tier(arch.risk_tier)
		if not is_visited:
			risk_color.a = 0.35  # dim risk colour for unvisited sectors too
		draw_string(font, center + Vector2(-120, radius + 18), risk_label, HORIZONTAL_ALIGNMENT_LEFT, 240, small_font_size, risk_color)

		# 3c. Hover tooltip — show the exact intercept percentage so the
		# player can weigh the dice before clicking. Anchored below the risk
		# label so it never collides with the port dots inside the circle.
		if is_hovered and _travel_tuning != null:
			var pct: int = int(round(_travel_tuning.intercept_chance_for_tier(arch.risk_tier) * 100.0))
			var tip_text: String = "PIRATE INTERCEPT: " + str(pct) + "%"
			draw_string(font, center + Vector2(-120, radius + 34), tip_text, HORIZONTAL_ALIGNMENT_LEFT, 240, small_font_size, risk_color * 0.9)

		# 4. Draw internal Ports
		var ports: Array[PortDef] = _ports_cache.get(arch_id, [])
		for port_def in ports:
			# Project 3D position onto 2D local space
			var local_pos := Vector2(port_def.position.x, port_def.position.z) * _tuning.port_scale
			var port_screen_pos := center + local_pos

			# Draw small port dot
			draw_circle(port_screen_pos, 4.0, draw_color)

			# Draw port name slightly offset
			draw_string(font, port_screen_pos + Vector2(8, 4), port_def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, small_font_size, draw_color * 0.9)

		# 5. Draw Blinking Player Ship Indicator on current sector
		if is_current:
			var show_blink: bool = fmod(_pulse_timer * _tuning.blink_speed, 2.0) < 1.0
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
