# Fast Travel transit animation and arrival handler (T08)
#
# Target plumbing: main.gd instantiates this scene, sets target_archipelago
# directly (regular var), then adds it under SceneRoot. There is no fallback —
# caller is responsible for setting target_archipelago before _ready runs.
class_name Travel extends Control

var target_archipelago: ArchipelagoDef
var tuning: TravelTuning

var _time_elapsed: float = 0.0
var _travel_duration: float = 3.0
var _is_storm: bool = false

var _stars: Array[Dictionary] = []
const STAR_COUNT := 100


func _ready() -> void:
	tuning = load("res://data/tuning/travel.tres") as TravelTuning
	assert(target_archipelago != null, "Travel scene mounted without target_archipelago — main.gd must set this before add_child")

	# Roll storm chance from tuning
	_is_storm = randf() < tuning.storm_chance
	if _is_storm:
		_travel_duration = tuning.calm_duration_seconds + tuning.storm_extension_seconds
		# Emit warnings slightly deferred so UI registers it
		call_deferred("_emit_storm_message")
	else:
		_travel_duration = tuning.calm_duration_seconds
		call_deferred("_emit_calm_message")

	# Initialize warp starfield particles
	for i in range(STAR_COUNT):
		var angle := randf() * TAU
		var dir := Vector2.from_angle(angle)
		var dist := randf() * 600.0
		_stars.append({
			"pos": dir * dist,
			"dir": dir,
			"speed": 80.0 + randf() * 200.0
		})


func _emit_storm_message() -> void:
	EventBus.hud_message.emit("Storm-tossed seas slow your passage.", "warning")


func _emit_calm_message() -> void:
	EventBus.hud_message.emit("Open sea is calm.", "info")


func _process(delta: float) -> void:
	_time_elapsed += delta
	
	if _time_elapsed >= _travel_duration:
		set_process(false)
		_complete_travel()
		return
		
	# Update warp lines
	var center := Vector2(960, 540)
	var speed_mult := 1.0 + (_time_elapsed * 2.0)
	
	for star in _stars:
		star.pos += star.dir * star.speed * speed_mult * delta
		# Loop particle if it goes off screen
		if star.pos.length() > 1100.0:
			star.pos = star.dir * (randf() * 30.0)
			
	queue_redraw()


func _complete_travel() -> void:
	# Update GameState fields upon safe arrival
	GameState.current_archipelago_id = target_archipelago.id
	if not target_archipelago.id in GameState.visited_archipelagos:
		GameState.visited_archipelagos.append(target_archipelago.id)
	GameState.travel_count += 1

	# archipelago_changed is owned by Travel — Travel is the source of truth for
	# arrival, since it's the only place that mutates current_archipelago_id.
	# main.gd handles scene mounting; OpenSea's _ready re-spawns ports from
	# GameState so the happy-path doesn't even need this signal, but HUD and
	# any future listener do.
	EventBus.archipelago_changed.emit(target_archipelago)
	# Transition back to sea gameplay
	EventBus.travel_completed.emit(target_archipelago)


func _draw() -> void:
	var center := Vector2(960, 540)
	var font := ThemeDB.fallback_font
	
	# Draw starfield warp lines
	var line_color := Color(0.0, 1.0, 0.8, 0.6) if not _is_storm else Color(1.0, 0.4, 0.2, 0.6) # Teal calm vs Amber storm
	
	for star in _stars:
		var p1: Vector2 = center + star.pos
		# Draw trailing line proportional to speed/time
		var trail_length: float = 10.0 + (_time_elapsed * 20.0)
		var p2: Vector2 = center + star.pos - star.dir * trail_length
		draw_line(p1, p2, line_color, 1.5)

		
	# Render strategic HUD overlay
	var text_color := Color("#33ff33")
	var dest_name := target_archipelago.display_name.to_upper()
	var label_text := "TRANSITING TO " + dest_name + "..."
	if _is_storm:
		label_text = "NAVIGATING STORM SEAS TO " + dest_name + "..."
		
	# Pulse warning frame if storm
	if _is_storm:
		var warn_color := Color(1.0, 0.3, 0.1, 0.2 * (0.5 + sin(_time_elapsed * 10.0) * 0.5))
		draw_rect(Rect2(50, 50, 1820, 980), warn_color, false, 8.0)

	draw_string(font, Vector2(960, 480), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, text_color)
	
	# Progress bar
	var bar_width := 400.0
	var bar_height := 8.0
	var bar_x := 960.0 - bar_width / 2.0
	var bar_y := 520.0
	var pct := clampf(_time_elapsed / _travel_duration, 0.0, 1.0)
	
	# Outer border
	draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_width + 4, bar_height + 4), text_color * 0.5, false, 1.5)
	# Inner fill
	draw_rect(Rect2(bar_x, bar_y, bar_width * pct, bar_height), text_color, true)
	
	# Percentage display
	var pct_text := str(int(pct * 100)) + "%"
	draw_string(font, Vector2(960, 560), pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, text_color * 0.8)
