# DockMenu — placeholder for the docked-at-port UI.
#
# Owns four buttons: Market / Tavern / Shipyard / Undock.
# Market/Tavern/Shipyard are stubs for T04/T05; they emit a HUD message and do
# nothing else. Undock emits port_undocked — Main listens and swaps the scene
# back to OpenSea (and grants the new PlayerShip its collision immunity).
extends Control

const PORT_DIR := "res://data/ports/"

@onready var _title: Label = $Panel/V/Title
@onready var _sector: Label = $Panel/V/Sector
@onready var _market_btn: Button = $Panel/V/Buttons/Market
@onready var _tavern_btn: Button = $Panel/V/Buttons/Tavern
@onready var _shipyard_btn: Button = $Panel/V/Buttons/Shipyard
@onready var _undock_btn: Button = $Panel/V/Buttons/Undock


func _ready() -> void:
	_market_btn.pressed.connect(_on_market_pressed)
	_tavern_btn.pressed.connect(_on_tavern_pressed)
	_shipyard_btn.pressed.connect(_on_shipyard_pressed)
	_undock_btn.pressed.connect(_on_undock_pressed)

	var port_def := _load_current_port()
	if port_def != null:
		_title.text = "PORT OF %s" % port_def.display_name.to_upper()
		# Sector lookup via archipelago resource so T04 etc don't have to
		# reverse-map port→archipelago later.
		var arch_path: String = "res://data/archipelagos/" + port_def.archipelago_id + ".tres"
		if ResourceLoader.exists(arch_path):
			var arch: ArchipelagoDef = load(arch_path) as ArchipelagoDef
			if arch != null:
				_sector.text = "%s — %s" % [arch.display_name, arch.sector]
	else:
		_title.text = "PORT OF ???"
		_sector.text = ""


func _load_current_port() -> PortDef:
	var port_id: String = GameState.current_port_id
	if port_id == "":
		return null
	var path := PORT_DIR + port_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PortDef


func _on_market_pressed() -> void:
	EventBus.hud_message.emit("Market coming soon (T04)", "info")


func _on_tavern_pressed() -> void:
	EventBus.hud_message.emit("Tavern coming soon (T05)", "info")


func _on_shipyard_pressed() -> void:
	EventBus.hud_message.emit("Shipyard coming soon (T04)", "info")


func _on_undock_pressed() -> void:
	GameState.current_port_id = ""
	# Main listens for port_undocked, swaps the scene, and grants immunity.
	EventBus.port_undocked.emit()
