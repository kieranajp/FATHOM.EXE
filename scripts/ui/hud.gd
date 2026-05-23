# HUD — CanvasLayer overlay. All telemetry: sailing, combat, alerts, inventory
# toggle, dock prompt, target panel, clock, gold/location.
#
# Hard rule: **purely a consumer**. Reads from autoloads (GameState, World,
# WindSystem, TimeSystem) and listens on EventBus. Never writes game state.
#
# Hides while docked (Port scene). Self-managed via port_docked / port_undocked.
# That keeps the parent (Main) ignorant of HUD existence, which is the right
# direction of dependency.
#
# Defensive against T06 (combat / active_target / reload timers) and T11 (real
# clock ticks): renders sensible defaults until those land.
#
# Cache child node references in _ready (no per-frame $Path lookups). The 120Hz
# target lives or dies on this.
#
# Bars: plain `Control` nodes with a `Bg` ColorRect (outline + dark backdrop)
# and a `Fill` ColorRect child. _set_fill_fraction sizes Fill in place. We
# don't use Godot's ProgressBar because the styling cost (theme overrides per
# bar) exceeds the value when every bar is one ColorRect-on-ColorRect.
extends CanvasLayer

const ARCHIPELAGO_DIR := "res://data/archipelagos/"

@export var tuning: HudTuning

# --- Sailing telemetry (left panel) ---
@onready var _root: Control = $Root
@onready var _ship_name_label: Label = $Root/Left/ShipName
@onready var _hp_bar: Control = $Root/Left/Sailing/HPRow/Bar
@onready var _hp_fill: ColorRect = $Root/Left/Sailing/HPRow/Bar/Fill
@onready var _hp_value: Label = $Root/Left/Sailing/HPRow/Value
@onready var _speed_bar: Control = $Root/Left/Sailing/SpeedRow/Bar
@onready var _speed_fill: ColorRect = $Root/Left/Sailing/SpeedRow/Bar/Fill
@onready var _speed_value: Label = $Root/Left/Sailing/SpeedRow/Value
@onready var _throttle_bar: Control = $Root/Left/Sailing/ThrottleRow/Bar
@onready var _throttle_fill: ColorRect = $Root/Left/Sailing/ThrottleRow/Bar/Fill
@onready var _throttle_value: Label = $Root/Left/Sailing/ThrottleRow/Value
@onready var _heading_value: Label = $Root/Left/Sailing/HeadingRow/Value
@onready var _wind_value: Label = $Root/Left/Sailing/WindRow/Value
@onready var _wind_needle: ColorRect = $Root/Left/Sailing/WindRow/Compass/Needle
@onready var _tacking_value: Label = $Root/Left/Sailing/TackingRow/Value

# --- Combat readiness (right panel) ---
@onready var _reload_port_bar: Control = $Root/Right/Combat/PortReloadRow/Bar
@onready var _reload_port_fill: ColorRect = $Root/Right/Combat/PortReloadRow/Bar/Fill
@onready var _reload_port_value: Label = $Root/Right/Combat/PortReloadRow/Value
@onready var _reload_stbd_bar: Control = $Root/Right/Combat/StbdReloadRow/Bar
@onready var _reload_stbd_fill: ColorRect = $Root/Right/Combat/StbdReloadRow/Bar/Fill
@onready var _reload_stbd_value: Label = $Root/Right/Combat/StbdReloadRow/Value
@onready var _ammo_ball_name: Label = $Root/Right/Combat/AmmoBox/BallRow/Name
@onready var _ammo_ball_value: Label = $Root/Right/Combat/AmmoBox/BallRow/Value
@onready var _ammo_chain_name: Label = $Root/Right/Combat/AmmoBox/ChainRow/Name
@onready var _ammo_chain_value: Label = $Root/Right/Combat/AmmoBox/ChainRow/Value
@onready var _ammo_grape_name: Label = $Root/Right/Combat/AmmoBox/GrapeRow/Name
@onready var _ammo_grape_value: Label = $Root/Right/Combat/AmmoBox/GrapeRow/Value

# --- Top-left: gold + location ---
@onready var _gold_label: Label = $Root/TopLeft/Gold
@onready var _location_label: Label = $Root/TopLeft/Location

# --- Top-centre alerts banner ---
@onready var _alert_panel: Panel = $Root/Alert
@onready var _alert_label: Label = $Root/Alert/Label
@onready var _alert_timer: Timer = $Root/Alert/Timer

# --- Top-centre target panel ---
@onready var _target_panel: Panel = $Root/Target
@onready var _target_name: Label = $Root/Target/V/Name
@onready var _target_hp_text: Label = $Root/Target/V/HPRow/Value
@onready var _target_hp_bar: Control = $Root/Target/V/HPRow/Bar
@onready var _target_hp_fill: ColorRect = $Root/Target/V/HPRow/Bar/Fill
@onready var _target_panel_bg: ColorRect = $Root/Target/Border

# --- Bottom-centre dock prompt ---
@onready var _dock_prompt: Label = $Root/DockPrompt

# --- Bottom-right clock ---
@onready var _clock_label: Label = $Root/Clock

# --- Low-HP red overlay ---
@onready var _low_hp_overlay: ColorRect = $Root/LowHPOverlay

# --- Inventory modal (separate Control sibling of Root) ---
@onready var _inventory_screen: Control = $Inventory

var _low_hp_flash_t: float = 0.0
const _BASE_HP_COLOR: Color = Color("#33ff33")
const _LOW_HP_COLOR: Color = Color("#ff5555")
const _NEUTRAL_COLOR: Color = Color("#cccccc")


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/hud.tres") as HudTuning

	_alert_panel.visible = false
	_target_panel.visible = false
	_dock_prompt.visible = false
	_low_hp_overlay.visible = false
	_inventory_screen.visible = false

	_alert_timer.one_shot = true
	_alert_timer.timeout.connect(_on_alert_timeout)

	EventBus.hud_message.connect(_on_hud_message)
	EventBus.port_proximity_entered.connect(_on_port_proximity_entered)
	EventBus.port_proximity_exited.connect(_on_port_proximity_exited)
	EventBus.port_docked.connect(_on_port_docked)
	EventBus.port_undocked.connect(_on_port_undocked)
	EventBus.archipelago_changed.connect(_on_archipelago_changed)
	EventBus.inventory_toggled.connect(_on_inventory_toggled)
	EventBus.cargo_bought.connect(_on_cargo_changed)
	EventBus.cargo_sold.connect(_on_cargo_changed)
	EventBus.hour_passed.connect(_on_hour_passed)

	_refresh_location()
	_refresh_clock()
	_refresh_ship_name()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		var open := not _inventory_screen.visible
		_inventory_screen.visible = open
		EventBus.inventory_toggled.emit(open)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Inventory keeps refreshing independently (always visible/hidden); the
	# main HUD body is skipped when docked.
	if _root.visible:
		_tick_sailing_panel()
		_tick_combat_panel()
		_tick_target_panel()
		_tick_gold()
		_tick_low_hp_flash(delta)
		_refresh_clock()


# -------- Sailing telemetry --------

func _tick_sailing_panel() -> void:
	var ship_state: PlayerState = GameState.ship
	var player := _find_player()

	# Hull HP.
	var max_hp: float = _player_max_hp(ship_state)
	var hp: float = ship_state.health
	_hp_value.text = "%d / %d" % [int(round(hp)), int(round(max_hp))]
	var hp_frac: float = clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_set_fill_fraction(_hp_fill, _hp_bar, hp_frac)
	var low := hp_frac < tuning.low_hp_threshold
	_hp_fill.color = _LOW_HP_COLOR if low else _BASE_HP_COLOR

	# Speed.
	if player != null:
		var max_speed: float = _player_max_speed(player)
		var kts := player.speed * 3.5
		_speed_value.text = "%.1f KTS" % kts
		var speed_frac: float = clampf(player.speed / max_speed, 0.0, 1.0) if max_speed > 0.0 else 0.0
		_set_fill_fraction(_speed_fill, _speed_bar, speed_frac)
	else:
		_speed_value.text = "-- KTS"
		_set_fill_fraction(_speed_fill, _speed_bar, 0.0)

	# Sail throttle (vertical).
	var sail_frac: float = clampf(ship_state.sail_level / 4.0, 0.0, 1.0)
	_throttle_value.text = "%d / 4" % int(round(ship_state.sail_level))
	_set_fill_fraction(_throttle_fill, _throttle_bar, sail_frac)

	# Heading.
	var yaw: float = player.yaw if player != null else 0.0
	var heading_deg := yaw_to_compass_deg(yaw)
	_heading_value.text = "%03d°  %s  HEADING" % [heading_deg, compass_label(heading_deg)]

	# Wind label + needle.
	var wind_deg := angle_to_compass_deg(WindSystem.angle)
	_wind_value.text = "%d KTS  %s" % [int(round(WindSystem.speed)), compass_label(wind_deg)]
	# Needle rotation: wind direction relative to ship's bow. JS:
	#   rotate(wind.angle - player.yaw)
	# In our frame, both angles share -Z=forward, so subtract directly. The
	# needle pivot is set in the scene at the centre of the compass.
	_wind_needle.rotation = WindSystem.angle - yaw

	# Sailing status (efficiency-tier text + colour).
	var efficiency: float = SailingMath.efficiency(yaw, WindSystem.angle)
	var status := sailing_status(efficiency)
	_tacking_value.text = status.text
	_tacking_value.add_theme_color_override("font_color", status.color)


func _tick_low_hp_flash(delta: float) -> void:
	var ship_state: PlayerState = GameState.ship
	var max_hp: float = _player_max_hp(ship_state)
	var hp_frac: float = clampf(ship_state.health / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0
	if hp_frac < tuning.low_hp_threshold:
		_low_hp_overlay.visible = true
		_low_hp_flash_t += delta
		# Subtle pulse: alpha 0.10..0.30 at 1.5Hz. Not a seizure simulator.
		var pulse := (sin(_low_hp_flash_t * TAU * 1.5) + 1.0) * 0.5
		var alpha := 0.10 + pulse * 0.20
		var c := _LOW_HP_COLOR
		c.a = alpha
		_low_hp_overlay.color = c
	else:
		_low_hp_overlay.visible = false
		_low_hp_flash_t = 0.0


# -------- Combat readiness panel --------

func _tick_combat_panel() -> void:
	var port_reload := _read_reload("port")
	var stbd_reload := _read_reload("starboard")
	_apply_reload(_reload_port_bar, _reload_port_fill, _reload_port_value, port_reload)
	_apply_reload(_reload_stbd_bar, _reload_stbd_fill, _reload_stbd_value, stbd_reload)

	var ship_state: PlayerState = GameState.ship
	var active: String = ship_state.active_ammo
	var ammo: Dictionary = ship_state.ammo
	_set_ammo_row(_ammo_ball_name, _ammo_ball_value, "BALL  (180m)", ammo.get("ball", 0), active == "ball")
	_set_ammo_row(_ammo_chain_name, _ammo_chain_value, "CHAIN (100m)", ammo.get("chain", 0), active == "chain")
	_set_ammo_row(_ammo_grape_name, _ammo_grape_value, "GRAPE  (60m)", ammo.get("grape", 0), active == "grape")


# Returns a fraction in [0, 1] where 1.0 == ready. T06 owns reload timers;
# until they're wired in, both sides always read READY.
func _read_reload(_side: String) -> float:
	return 1.0


func _apply_reload(bar: Control, fill: ColorRect, value_label: Label, frac: float) -> void:
	_set_fill_fraction(fill, bar, frac)
	if frac >= 1.0:
		value_label.text = "READY"
	else:
		value_label.text = "%d%%" % int(round(frac * 100.0))


func _set_ammo_row(name_label: Label, value_label: Label, base_text: String, count: int, active: bool) -> void:
	if active:
		name_label.text = "> " + base_text
		name_label.add_theme_color_override("font_color", Factions.color_for("player"))
		value_label.add_theme_color_override("font_color", Factions.color_for("player"))
	else:
		name_label.text = "  " + base_text
		name_label.add_theme_color_override("font_color", _NEUTRAL_COLOR)
		value_label.add_theme_color_override("font_color", _NEUTRAL_COLOR)
	value_label.text = str(count)


# -------- Target panel --------

func _tick_target_panel() -> void:
	# World.active_target is owned by T06. Until it lands the field may not
	# exist on World; go through `in` + `get()` defensively rather than tripping
	# on a missing var. Once T06 ships and declares it, this still works.
	var target: Variant = null
	if "active_target" in World:
		target = World.get("active_target")

	if target == null:
		_target_panel.visible = false
		return

	# Defensive shape probing. T06 will likely give us an EnemyShip with
	# .health / .max_health / .faction_id. Anything else falls back gracefully.
	var faction_id: String = "pirate"
	var max_hp: float = 1.0
	var hp: float = 1.0
	var display_name: String = "UNKNOWN CONTACT"

	if typeof(target) == TYPE_OBJECT and target != null:
		if "faction_id" in target:
			faction_id = str(target.get("faction_id"))
		if "max_health" in target:
			max_hp = float(target.get("max_health"))
		if "health" in target:
			hp = float(target.get("health"))
		if "display_name" in target:
			display_name = str(target.get("display_name"))
		elif faction_id == "authority":
			display_name = "PORT AUTHORITY GALLEON"
		elif faction_id == "pirate":
			display_name = "PIRATE RAIDER"

	var faction := Factions.info(faction_id)
	_target_panel.visible = true
	_target_name.text = display_name
	_target_name.add_theme_color_override("font_color", faction.color)
	var hp_frac: float = clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_target_hp_text.text = "%d%%" % int(round(hp_frac * 100.0))
	_target_hp_text.add_theme_color_override("font_color", faction.color)
	_set_fill_fraction(_target_hp_fill, _target_hp_bar, hp_frac)
	_target_hp_fill.color = faction.color
	_target_panel_bg.color = Color(faction.color.r, faction.color.g, faction.color.b, 0.18)


# -------- Gold + location --------

func _tick_gold() -> void:
	_gold_label.text = "%d  D" % GameState.ship.gold


func _refresh_location() -> void:
	var arch_id := GameState.current_archipelago_id
	if arch_id == "":
		_location_label.text = "OPEN SEA"
		return
	var arch_path := ARCHIPELAGO_DIR + arch_id + ".tres"
	if ResourceLoader.exists(arch_path):
		var arch := load(arch_path) as ArchipelagoDef
		if arch != null:
			_location_label.text = "%s — %s" % [arch.display_name, arch.sector]
			return
	_location_label.text = "OPEN SEA"


# -------- Clock --------

func _refresh_clock() -> void:
	_clock_label.text = "DAY %d   %02d:00" % [TimeSystem.day, TimeSystem.hour]


# -------- Ship name (static; refreshed on archipelago / load) --------

func _refresh_ship_name() -> void:
	var ship_state: PlayerState = GameState.ship
	var class_label := ship_state.ship_class_id.to_upper()
	var path := "res://data/ships/" + ship_state.ship_class_id + ".tres"
	if ResourceLoader.exists(path):
		var sc := load(path) as ShipClass
		if sc != null and sc.display_name != "":
			class_label = sc.display_name.to_upper()
	_ship_name_label.text = "%s  (%s)" % [ship_state.ship_name.to_upper(), class_label]


# -------- Signal handlers --------

func _on_hud_message(text: String, severity: String) -> void:
	_alert_label.text = text
	_alert_label.add_theme_color_override("font_color", _color_for_severity(severity))
	_alert_panel.visible = true
	# Replace existing message (don't queue) — keeps the HUD calm per issue spec.
	_alert_timer.stop()
	_alert_timer.start(tuning.alert_duration)


func _on_alert_timeout() -> void:
	_alert_panel.visible = false


func _on_port_proximity_entered(port: PortDef) -> void:
	_dock_prompt.text = "[ F ] DOCK AT %s" % port.display_name.to_upper()
	_dock_prompt.visible = true


func _on_port_proximity_exited() -> void:
	_dock_prompt.visible = false


func _on_port_docked(_port: PortDef) -> void:
	_root.visible = false


func _on_port_undocked() -> void:
	_root.visible = true
	_refresh_location()


func _on_archipelago_changed(_arch: ArchipelagoDef) -> void:
	_refresh_location()


func _on_inventory_toggled(open: bool) -> void:
	# External code can force-toggle inventory via the signal. Act on mismatch
	# only to avoid signal loops.
	if _inventory_screen.visible != open:
		_inventory_screen.visible = open


func _on_cargo_changed(_item: String, _amount: int, _price: int) -> void:
	if _inventory_screen.visible and _inventory_screen.has_method("refresh"):
		_inventory_screen.call("refresh")


func _on_hour_passed(_day: int, _hour: int) -> void:
	_refresh_clock()


# -------- Helpers --------

# Yaw → compass degrees, [0, 360). yaw=0 → 0° N.
# Godot uses -Z = forward = "north" by convention. Positive yaw rotates CCW
# about +Y (so the bow swings towards -X = west); a CW (eastward) turn is
# *negative* yaw. Hence `heading = -yaw`.
#
# See test/test_hud_compass.gd for the regression assertions.
static func yaw_to_compass_deg(yaw_radians: float) -> int:
	var deg := -rad_to_deg(yaw_radians)
	deg = fmod(deg, 360.0)
	if deg < 0.0:
		deg += 360.0
	var d := int(round(deg)) % 360
	if d < 0:
		d += 360
	return d


static func angle_to_compass_deg(angle_radians: float) -> int:
	return yaw_to_compass_deg(angle_radians)


# 8-point compass label from degrees. 0=N, 45=NE, … 315=NW.
static func compass_label(deg: int) -> String:
	const LABELS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var idx := int(round(float(deg) / 45.0)) % 8
	if idx < 0:
		idx += 8
	return LABELS[idx]


# Sailing-status tier classification — pure function so a test can pin it.
# Returns {text: String, color: Color}.
static func sailing_status(efficiency: float) -> Dictionary:
	if efficiency < 0.15:
		return {"text": "IN IRONS (HEADWIND)", "color": Color("#ff3333")}
	if efficiency > 0.85:
		return {"text": "GOOD REACH (OPTIMAL)", "color": Color("#00ffcc")}
	return {"text": "TACKING / RUNNING", "color": Color("#ffcc00")}


func _color_for_severity(severity: String) -> Color:
	match severity:
		"alert":
			return Color("#ff3333")
		"warning":
			return Color("#ffcc00")
		_:
			return Color("#00ffcc")


func _player_max_hp(ship_state: PlayerState) -> float:
	# Pull max from the ship-class resource (canonical) when available; else
	# fall back to current health so a fresh PlayerState reads as 100%, not 0%.
	var path := "res://data/ships/" + ship_state.ship_class_id + ".tres"
	if ResourceLoader.exists(path):
		var sc := load(path) as ShipClass
		if sc != null:
			return sc.max_health
	return maxf(ship_state.health, 1.0)


func _player_max_speed(player: PlayerShip) -> float:
	if player == null or player.ship_class == null:
		return 6.0
	return player.ship_class.base_max_speed


func _find_player() -> PlayerShip:
	# PlayerShip lives in the active sub-scene (OpenSea). It can be absent
	# (Port scene, headless tests). The lookup walks the scene tree once per
	# frame — negligible against 120Hz at our scale.
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.current_scene
	if root == null:
		return null
	return root.find_child("PlayerShip", true, false) as PlayerShip


# Set the fill of a `Bar` Control to a fraction of its full size. Orientation
# is detected from the parent's aspect — tall+narrow = vertical (sail throttle).
func _set_fill_fraction(fill: ColorRect, bar: Control, frac: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	var bg_size := bar.size
	if bg_size.y > bg_size.x:
		fill.size.x = bg_size.x
		fill.size.y = bg_size.y * frac
		fill.position.x = 0.0
		fill.position.y = bg_size.y - fill.size.y
	else:
		fill.size.y = bg_size.y
		fill.size.x = bg_size.x * frac
		fill.position = Vector2.ZERO
