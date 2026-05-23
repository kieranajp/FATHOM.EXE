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
# Layout follows the JS prototype's terminal-panel aesthetic — bordered
# PanelContainers per region (NAVIGATION / STATUS / SAILS / BATTLE TELEMETRY /
# CONTROLS) plus the centre overlays (alert, target, dock prompt) and the
# bottom-right clock. The data wiring is unchanged from T07; only the visual
# layout differs.
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

# --- NAVIGATION panel (top-left) ---
@onready var _root: Control = $Root
@onready var _ship_name_value: Label = $Root/NavPanel/V/ShipRow/Value
@onready var _speed_value: Label = $Root/NavPanel/V/SpeedRow/Value
@onready var _speed_bar: Control = $Root/NavPanel/V/SpeedBar
@onready var _speed_fill: ColorRect = $Root/NavPanel/V/SpeedBar/Fill
@onready var _course_value: Label = $Root/NavPanel/V/CourseRow/Value

# --- STATUS panel (top-right) ---
@onready var _purse_value: Label = $Root/StatusPanel/V/PurseRow/Value
@onready var _zone_value: Label = $Root/StatusPanel/V/ZoneRow/Value
@onready var _sector_value: Label = $Root/StatusPanel/V/SectorRow/Value
@onready var _compass: Control = $Root/StatusPanel/V/WindRow/Compass
@onready var _wind_value: Label = $Root/StatusPanel/V/WindRow/WindReadout/WindValue
@onready var _tacking_value: Label = $Root/StatusPanel/V/WindRow/WindReadout/Tacking

# --- SAILS panel (middle-left, narrow vertical) ---
@onready var _sails_track: Control = $Root/SailsPanel/V/Body/Track
@onready var _sails_fill: ColorRect = $Root/SailsPanel/V/Body/Track/Fill
@onready var _sails_labels: VBoxContainer = $Root/SailsPanel/V/Body/Labels

# Mapping: sail_level 4 == FULL (top label), 0 == ANCH (bottom label). Indexed
# top-down to match the VBox children order in the scene.
const _SAILS_LABEL_COUNT := 5
var _SAILS_ACTIVE_COLOR := Factions.color_for("player")
const _SAILS_INACTIVE_COLOR := Color(0.2, 1, 0.4, 0.4)

# --- BATTLE TELEMETRY panel ---
@onready var _hp_value: Label = $Root/BattlePanel/V/HPRow/Value
@onready var _hp_bar: Control = $Root/BattlePanel/V/HPBar
@onready var _hp_fill: ColorRect = $Root/BattlePanel/V/HPBar/Fill
@onready var _reload_port_value: Label = $Root/BattlePanel/V/PortRow/Value
@onready var _reload_port_bar: Control = $Root/BattlePanel/V/PortBar
@onready var _reload_port_fill: ColorRect = $Root/BattlePanel/V/PortBar/Fill
@onready var _reload_stbd_value: Label = $Root/BattlePanel/V/StbdRow/Value
@onready var _reload_stbd_bar: Control = $Root/BattlePanel/V/StbdBar
@onready var _reload_stbd_fill: ColorRect = $Root/BattlePanel/V/StbdBar/Fill
@onready var _ammo_ball_name: Label = $Root/BattlePanel/V/BallRow/Name
@onready var _ammo_ball_value: Label = $Root/BattlePanel/V/BallRow/Value
@onready var _ammo_chain_name: Label = $Root/BattlePanel/V/ChainRow/Name
@onready var _ammo_chain_value: Label = $Root/BattlePanel/V/ChainRow/Value
@onready var _ammo_grape_name: Label = $Root/BattlePanel/V/GrapeRow/Name
@onready var _ammo_grape_value: Label = $Root/BattlePanel/V/GrapeRow/Value

# --- Top-centre alerts banner ---
@onready var _alert_panel: PanelContainer = $Root/Alert
@onready var _alert_label: Label = $Root/Alert/Label
@onready var _alert_timer: Timer = $Root/Alert/Timer

# --- Top-centre target panel ---
@onready var _target_panel: PanelContainer = $Root/Target
@onready var _target_name: Label = $Root/Target/V/Name
@onready var _target_hp_text: Label = $Root/Target/V/HPRow/Value
@onready var _target_hp_bar: Control = $Root/Target/V/HPRow/Bar
@onready var _target_hp_fill: ColorRect = $Root/Target/V/HPRow/Bar/Fill

# --- Bottom-centre dock prompt ---
@onready var _dock_prompt: Label = $Root/DockPrompt

# --- Bottom-right clock ---
@onready var _clock_label: Label = $Root/Clock

# --- Low-HP red overlay ---
@onready var _low_hp_overlay: ColorRect = $Root/LowHPOverlay

# --- Inventory modal (separate Control sibling of Root) ---
@onready var _inventory_screen: Control = $Inventory

var _low_hp_flash_t: float = 0.0
const _BASE_HP_COLOR: Color = Color("#ff5555")  # battle-panel HP bar is red-themed
const _LOW_HP_COLOR: Color = Color("#ff3333")
const _NEUTRAL_COLOR: Color = Color(0.85, 0.85, 0.85, 0.9)

var _no_fire_banner: Label


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/tuning/hud.tres") as HudTuning

	# Bump UI scale uniformly. Playtest flagged the bordered-panel HUD as
	# smaller than the JS reference; ui_scale lives on HudTuning so it can be
	# re-tuned without code edits.
	#
	# Approach: scale the Root Control and shrink its size to viewport / scale
	# so right/bottom-anchored panels still anchor to the screen edge after
	# scaling. A naive CanvasLayer.transform.scaled() multiplies positions but
	# does NOT resize Root, so right-anchored panels (StatusPanel, Clock) go
	# off-screen — the Root-level approach keeps anchors honest. Re-applied on
	# viewport resize so it stays correct after window resize.
	_apply_ui_scale()
	get_viewport().size_changed.connect(_apply_ui_scale)

	_alert_panel.visible = false
	_target_panel.visible = false
	_dock_prompt.visible = false
	_low_hp_overlay.visible = false
	_inventory_screen.visible = false

	# Dynamic NoFireZoneBanner initialization (Issue 50)
	_no_fire_banner = Label.new()
	_no_fire_banner.text = "[ HARBOR SECURITY: NO-FIRE ZONE ]"
	_no_fire_banner.add_theme_color_override("font_color", Color("#ffaa33")) # Amber color
	_no_fire_banner.add_theme_font_size_override("font_size", 13)
	_no_fire_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_fire_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_fire_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_no_fire_banner.offset_left = -180.0
	_no_fire_banner.offset_right = 180.0
	_no_fire_banner.offset_top = 150.0
	_no_fire_banner.offset_bottom = 175.0
	_no_fire_banner.visible = false
	_root.add_child(_no_fire_banner)

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


func _apply_ui_scale() -> void:
	# Scale + size compensation. Root is anchored full-rect (anchor_right=1,
	# anchor_bottom=1) so its size tracks the viewport at runtime. We override
	# size after the scale so anchored children evaluate against the shrunken
	# (logical) rect, then the scale multiplies it back up to fill the screen.
	var scale: float = maxf(tuning.ui_scale, 0.01)
	_root.scale = Vector2(scale, scale)
	_root.pivot_offset = Vector2.ZERO
	var vp_size: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	# Disable anchors temporarily so we can set an explicit size that overrides
	# the parent-driven full-rect sizing.
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.position = Vector2.ZERO
	_root.size = vp_size / scale


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
		_tick_nav_panel()
		_tick_status_panel()
		_tick_sails_panel()
		_tick_combat_panel()
		_tick_target_panel()
		_tick_low_hp_flash(delta)
		_refresh_clock()
		
		# Toggle NoFireZoneBanner visibility based on World state (Issue 50)
		if _no_fire_banner != null:
			_no_fire_banner.visible = World.is_in_no_fire_zone


# -------- NAVIGATION panel --------

func _tick_nav_panel() -> void:
	var player := _find_player()

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

	# Course/heading.
	var yaw: float = player.yaw if player != null else 0.0
	var heading_deg := yaw_to_compass_deg(yaw)
	_course_value.text = "%03d° %s" % [heading_deg, compass_label(heading_deg)]


# -------- STATUS panel (purse + zone + wind telemetry) --------

func _tick_status_panel() -> void:
	# Purse.
	_purse_value.text = "%d D" % GameState.ship.gold

	# Wind label + needle. Needle rotation matches the regression-pinned
	# convention; the compass dial widget interprets 0 == straight up = wind
	# from ahead.
	var player := _find_player()
	var yaw: float = player.yaw if player != null else 0.0
	var wind_deg := angle_to_compass_deg(WindSystem.angle)
	_wind_value.text = "%d KTS %s" % [int(round(WindSystem.speed)), compass_label(wind_deg)]
	if _compass.has_method("set_needle_angle"):
		_compass.call("set_needle_angle", wind_needle_rotation(yaw, WindSystem.angle))

	# Sailing status (efficiency-tier text + colour).
	var efficiency: float = SailingMath.efficiency(yaw, WindSystem.angle)
	var status := sailing_status(efficiency)
	_tacking_value.text = status.text
	_tacking_value.add_theme_color_override("font_color", status.color)


# -------- SAILS panel --------

func _tick_sails_panel() -> void:
	var ship_state: PlayerState = GameState.ship
	var sail_level: float = clampf(ship_state.sail_level, 0.0, 4.0)
	var sail_frac: float = sail_level / 4.0

	# Vertical fill from the bottom up.
	var bg_size := _sails_track.size
	var fill_h := bg_size.y * sail_frac
	_sails_fill.size = Vector2(bg_size.x, fill_h)
	_sails_fill.position = Vector2(0.0, bg_size.y - fill_h)

	# Highlight the active label. sail_level 4 == top label (FULL); 0 == bottom
	# (ANCH). Round to nearest int so a 1.7 sail-level highlights "3/4".
	var active_idx := _SAILS_LABEL_COUNT - 1 - int(round(sail_level))
	active_idx = clampi(active_idx, 0, _SAILS_LABEL_COUNT - 1)
	for i in _SAILS_LABEL_COUNT:
		var lbl := _sails_labels.get_child(i) as Label
		if lbl == null:
			continue
		var active := i == active_idx
		lbl.add_theme_color_override("font_color", _SAILS_ACTIVE_COLOR if active else _SAILS_INACTIVE_COLOR)
		lbl.text = ("> " + _sails_label_text(i)) if active else ("  " + _sails_label_text(i))


func _sails_label_text(i: int) -> String:
	match i:
		0: return "FULL"
		1: return "3/4"
		2: return "HALF"
		3: return "1/4"
		4: return "ANCH"
		_: return ""


# -------- BATTLE TELEMETRY panel --------

func _tick_combat_panel() -> void:
	var ship_state: PlayerState = GameState.ship

	# Hull HP.
	var max_hp: float = _player_max_hp(ship_state)
	var hp: float = ship_state.health
	_hp_value.text = "%d / %d" % [int(round(hp)), int(round(max_hp))]
	var hp_frac: float = clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_set_fill_fraction(_hp_fill, _hp_bar, hp_frac)
	var low := hp_frac < tuning.low_hp_threshold
	_hp_fill.color = _LOW_HP_COLOR if low else _BASE_HP_COLOR

	# Reload bars (still stubbed at READY until T06 lands).
	var port_reload := _read_reload("port")
	var stbd_reload := _read_reload("starboard")
	_apply_reload(_reload_port_bar, _reload_port_fill, _reload_port_value, port_reload)
	_apply_reload(_reload_stbd_bar, _reload_stbd_fill, _reload_stbd_value, stbd_reload)

	# Ammo.
	var active: String = ship_state.active_ammo
	var ammo: Dictionary = ship_state.ammo
	_set_ammo_row(_ammo_ball_name, _ammo_ball_value, "BALL (180m):", ammo.get("ball", 0), active == "ball")
	_set_ammo_row(_ammo_chain_name, _ammo_chain_value, "CHAIN (100m):", ammo.get("chain", 0), active == "chain")
	_set_ammo_row(_ammo_grape_name, _ammo_grape_value, "GRAPE (60m):", ammo.get("grape", 0), active == "grape")


func _tick_low_hp_flash(delta: float) -> void:
	var ship_state: PlayerState = GameState.ship
	var max_hp: float = _player_max_hp(ship_state)
	var hp_frac: float = clampf(ship_state.health / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0
	if hp_frac < tuning.low_hp_threshold:
		_low_hp_overlay.visible = true
		_low_hp_flash_t += delta
		var pulse := (sin(_low_hp_flash_t * TAU * 1.5) + 1.0) * 0.5
		var alpha := 0.10 + pulse * 0.20
		var c := _LOW_HP_COLOR
		c.a = alpha
		_low_hp_overlay.color = c
	else:
		_low_hp_overlay.visible = false
		_low_hp_flash_t = 0.0


# Returns a fraction in [0, 1] where 1.0 == ready. T06 wires the timers on
# PlayerShip (reload_port / reload_stbd); CombatSystem decrements them. Reads
# defensively in case PlayerShip is absent (headless tests, Port scene).
func _read_reload(side: String) -> float:
	var player := _find_player()
	if player == null:
		return 1.0
	var reload_seconds: float = 3.0  # mirrors CombatTuning.reload_seconds default
	var remaining: float = 0.0
	if side == "port":
		remaining = player.reload_port
	else:
		remaining = player.reload_stbd
	if remaining <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / reload_seconds, 0.0, 1.0)


func _apply_reload(bar: Control, fill: ColorRect, value_label: Label, frac: float) -> void:
	_set_fill_fraction(fill, bar, frac)
	if frac >= 1.0:
		value_label.text = "READY"
		value_label.add_theme_color_override("font_color", Color("#00ffcc"))
	else:
		value_label.text = "%d%%" % int(round(frac * 100.0))
		value_label.add_theme_color_override("font_color", Color("#ffcc00"))


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


# -------- Zone/sector + clock + ship name (event-driven, not per-frame) --------

func _refresh_location() -> void:
	var arch_id := GameState.current_archipelago_id
	if arch_id == "":
		_zone_value.text = "OPEN SEA"
		_sector_value.text = "OPEN SEA"
		return
	var arch_path := ARCHIPELAGO_DIR + arch_id + ".tres"
	if ResourceLoader.exists(arch_path):
		var arch := load(arch_path) as ArchipelagoDef
		if arch != null:
			_zone_value.text = arch.display_name
			_sector_value.text = arch.sector if arch.sector != "" else "OPEN SEA"
			return
	_zone_value.text = "OPEN SEA"
	_sector_value.text = "OPEN SEA"


func _refresh_clock() -> void:
	_clock_label.text = "DAY %d   %02d:00" % [TimeSystem.day, TimeSystem.hour]


func _refresh_ship_name() -> void:
	var ship_state: PlayerState = GameState.ship
	var class_label := ship_state.ship_class_id.to_upper()
	var path := "res://data/ships/" + ship_state.ship_class_id + ".tres"
	if ResourceLoader.exists(path):
		var sc := load(path) as ShipClass
		if sc != null and sc.display_name != "":
			class_label = sc.display_name.to_upper()
	_ship_name_value.text = "%s (%s)" % [ship_state.ship_name.to_upper(), class_label]


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


# Wind-needle rotation, in radians, for the HUD compass dial.
#
# JS reference (game.js:3508) uses `wind.angle - player.yaw` with a CSS
# `transform: rotate(...)` — CSS is CW-positive on-screen and JS yaw is also
# CW-positive on-screen, so the two conventions agree visually.
#
# In Godot the conventions disagree: `Control.rotation` is CW-positive on
# screen, but yaw/wind angles in our world frame are CCW-positive (right-hand
# rule about +Y up). So we negate the JS-canonical formula to get the right
# visual rotation: at yaw=0 with wind from the west (wind_angle=+PI/2 by our
# compass convention — see test_hud_compass.gd), the needle must point left,
# i.e. negative Control.rotation.
#
# See test/test_hud_wind_needle.gd for the regression assertions.
static func wind_needle_rotation(yaw_radians: float, wind_angle_radians: float) -> float:
	return yaw_radians - wind_angle_radians


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
