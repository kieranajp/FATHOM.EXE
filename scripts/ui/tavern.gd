# Tavern — docked-at-port tavern UI.
#
# Allows chatting with the barkeep (random rumors) and buying rounds
# (bribery for profitable arbitrage rumors).
extends Control

const RUMORS_DIR := "res://data/rumors/"
const TUNING_PATH := "res://data/tuning/tavern.tres"

@onready var _message_label: Label = $Panel/V/Console/ConsoleV/Message
@onready var _gold_label: Label = $Panel/V/Footer/Gold
@onready var _ask_btn: Button = $Panel/V/BarkeepPanel/Actions/Ask
@onready var _buy_btn: Button = $Panel/V/BarkeepPanel/Actions/Buy
@onready var _leave_btn: Button = $Panel/V/Footer/Leave

var _tuning: TavernTuning
var _rumor_pool: Array[RumorDef] = []


func _ready() -> void:
	# Load tuning resource
	if ResourceLoader.exists(TUNING_PATH):
		_tuning = load(TUNING_PATH) as TavernTuning
	else:
		_tuning = TavernTuning.new() # fallback defaults
		
	# Populate buttons label with correct cost
	_buy_btn.text = "Buy a Round (%d D)" % _tuning.drink_cost

	# Load all rumors from resources
	_load_rumors()

	# Connect buttons
	_ask_btn.pressed.connect(_on_ask_pressed)
	_buy_btn.pressed.connect(_on_buy_pressed)
	_leave_btn.pressed.connect(_on_leave_pressed)

	# Restore previous active rumor text if any, else show initial greeting
	if GameState.active_rumor != "":
		_message_label.text = GameState.active_rumor
	else:
		_message_label.text = "\"Speak up, friend! What can I get ya?\""

	_update_gold_display()


func _unhandled_input(event: InputEvent) -> void:
	# Ignore input events if we are not visible or active
	if not is_visible_in_tree():
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_on_ask_pressed()
				get_viewport().set_input_as_handled()
			KEY_B:
				_on_buy_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_on_leave_pressed()
				get_viewport().set_input_as_handled()


func _load_rumors() -> void:
	_rumor_pool.clear()
	var dir := DirAccess.open(RUMORS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var path = file_name
				if path.ends_with(".remap"):
					path = path.replace(".remap", "")
				if path.ends_with(".tres"):
					var rumor = load(RUMORS_DIR + path) as RumorDef
					if rumor != null:
						_rumor_pool.append(rumor)
			file_name = dir.get_next()
	else:
		push_error("Tavern: Failed to open rumors directory: %s" % RUMORS_DIR)


func _update_gold_display() -> void:
	_gold_label.text = "GOLD: %d D" % GameState.ship.gold


func _on_ask_pressed() -> void:
	AudioBus.play_beep(800.0, 0.05)

	if _rumor_pool.is_empty():
		_message_label.text = "\"Rumour has it the pool is empty, mate!\""
		GameState.active_rumor = _message_label.text
		return

	var chosen_rumor: RumorDef = null
	if GameState.last_drink_purchased:
		# Bribed: select a rumor using weighted random (biased toward higher profit ratings)
		chosen_rumor = _get_weighted_random_rumor()
		GameState.last_drink_purchased = false
		# Barkeep prefaces the highly profitable tip
		_message_label.text = "\"Cheers, Cap'n! Here's a choice tip for ya:\n\n%s\"" % chosen_rumor.text
	else:
		# Free: select rumor uniformly at random
		chosen_rumor = _rumor_pool.pick_random()
		# Standard barkeep preface
		_message_label.text = "\"Well, whispers say:\n\n%s\"" % chosen_rumor.text

	GameState.active_rumor = _message_label.text


func _get_weighted_random_rumor() -> RumorDef:
	if _rumor_pool.is_empty():
		return null
		
	var total_weight := 0
	for r in _rumor_pool:
		total_weight += r.profit_rating
		
	if total_weight == 0:
		return _rumor_pool.pick_random()

	var roll := randi_range(1, total_weight)
	var current_sum := 0
	for r in _rumor_pool:
		current_sum += r.profit_rating
		if roll <= current_sum:
			return r
			
	return _rumor_pool.back()


func _on_buy_pressed() -> void:
	var cost = _tuning.drink_cost
	if GameState.ship.gold < cost:
		AudioBus.play_beep(180.0, 0.25)
		_message_label.text = "\"Barkeep: 'Your purse is looking a bit light for buying rounds, mate!'\""
		EventBus.hud_message.emit("Insufficient gold!", "warning")
		return

	# Deduct gold and apply bribery flag
	GameState.ship.gold -= cost
	GameState.last_drink_purchased = true
	
	AudioBus.play_beep(1000.0, 0.1) # Clink retro replacement
	_update_gold_display()
	
	_message_label.text = "\"Cheers, Cap'n! *clink* Ask me again and I'll tell ya the finest trade gossip I know!\""
	EventBus.hud_message.emit("Bought a round for %d D!" % cost, "info")


func _on_leave_pressed() -> void:
	AudioBus.play_beep(800.0, 0.05)
	queue_free()
