# Compass dial — circular HUD widget showing wind direction relative to ship.
#
# Cheap _draw-based widget. The dial is a circle with N/S/E/W tick marks; a
# needle points toward the source of the wind, rotated by `needle_angle`
# (radians, Control-frame CW-positive). When needle_angle == 0 the needle
# points straight up (= wind coming from ahead = headwind).
#
# Convention pinned in test/test_hud_wind_needle.gd — the HUD computes the
# rotation via `HudScript.wind_needle_rotation(yaw, wind_angle)` and sets it
# on this Control via `set_needle_angle`. We don't recompute here.
extends Control


@export var ring_color: Color = Color("#ffaa00")
@export var tick_color: Color = Color("#ffaa00")
@export var needle_color: Color = Color("#ffaa00")
@export var label_color: Color = Color("#ffaa00")

var _needle_angle: float = 0.0


func _ready() -> void:
	# We're a passive visual. Don't eat input meant for the canvas underneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_needle_angle(radians: float) -> void:
	if absf(radians - _needle_angle) < 1e-4:
		return
	_needle_angle = radians
	queue_redraw()


func _draw() -> void:
	var rect_size := size
	var centre := rect_size * 0.5
	var radius: float = minf(rect_size.x, rect_size.y) * 0.5 - 2.0

	# Outer ring.
	draw_arc(centre, radius, 0.0, TAU, 48, ring_color, 1.0, true)

	# Cardinal tick marks (small outward stubs at N/E/S/W).
	for i in 4:
		# i=0 -> N (up), 1 -> E, 2 -> S, 3 -> W. Control space is CW-positive
		# with -Y = up, so North corresponds to angle = -PI/2 from +X.
		var ang := -PI * 0.5 + (PI * 0.5) * float(i)
		var dir := Vector2(cos(ang), sin(ang))
		var inner := centre + dir * (radius - 4.0)
		var outer := centre + dir * radius
		draw_line(inner, outer, tick_color, 1.0, true)

	# N label.
	var font := get_theme_default_font()
	var fsize := 8
	if font != null:
		var n := "N"
		var n_size := font.get_string_size(n, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		draw_string(font, Vector2(centre.x - n_size.x * 0.5, centre.y - radius + n_size.y * 0.4), n, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, label_color)

	# Needle — a line from centre up to (radius - 6), rotated by _needle_angle.
	# In Control space, +Y is down, so "up" = -Y direction. A rotation of 0
	# leaves the needle straight up. See needle_direction() for the math.
	var needle_len := radius - 6.0
	var needle_dir := needle_direction(_needle_angle)
	var tip := centre + needle_dir * needle_len
	draw_line(centre, tip, needle_color, 2.0, true)

	# Arrowhead at the tip (small triangle pointing along needle_dir).
	var perp := Vector2(-needle_dir.y, needle_dir.x)
	var back := tip - needle_dir * 5.0
	var p1 := back + perp * 3.0
	var p2 := back - perp * 3.0
	draw_polygon(PackedVector2Array([tip, p1, p2]), PackedColorArray([needle_color, needle_color, needle_color]))

	# Centre hub.
	draw_circle(centre, 2.0, needle_color)


# Pure helper — turns a Control-frame rotation (CW-positive, 0 == straight up)
# into a unit screen-space direction vector. Pinned by tests.
#   angle = 0      -> ( 0, -1) (up = north)
#   angle = PI/2   -> ( 1,  0) (right = east)
#   angle = -PI/2  -> (-1,  0) (left = west)
#   angle = PI     -> ( 0,  1) (down = south)
static func needle_direction(angle_radians: float) -> Vector2:
	return Vector2(sin(angle_radians), -cos(angle_radians))
