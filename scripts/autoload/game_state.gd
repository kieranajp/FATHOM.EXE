# GameState — persisted run state (ship, gold, cargo, factions, etc).
# Owner: stub from F1. Save/load wired in by T08 (Persistence).
# Combat/economy tickets will read & mutate fields; do not bypass.
extends Node

var ship: PlayerState                            # ship class, cargo, gold, ammo, health
var current_archipelago_id: String = ""
var current_port_id: String = ""                 # empty when at sea
var travel_count: int = 0
var visited_archipelagos: Array[String] = []
var port_ship_stock: Dictionary = {}             # port_id -> { class_id: int }
var factions: Dictionary = {}                    # faction_id -> FactionState (post-parity)
var crew: CrewState                              # post-parity
var officers: Array[Officer] = []                # post-parity
var active_rumor: String = ""
var last_drink_purchased: bool = false
var day: int = 1
var hour: int = 8


func _ready() -> void:
	# Default to a fresh game so other autoloads can read a non-null PlayerState.
	# Real boot flow (load save vs new game) lands with Persistence/T08.
	reset_new_game()


func reset_new_game() -> void:
	ship = PlayerState.new()
	# Default start archipelago — T08 (save/load) will overwrite when resuming a
	# saved run, T08 (map) will mutate via fast-travel. Stays in lockstep with
	# the JS reference (game.js:2740 spawns the player in Pirate's Cradle).
	current_archipelago_id = "pirates_cradle"
	current_port_id = ""
	travel_count = 0
	visited_archipelagos = []
	port_ship_stock = {}
	factions = {}
	crew = CrewState.new()
	officers = []
	active_rumor = ""
	last_drink_purchased = false
	day = 1
	hour = 8
