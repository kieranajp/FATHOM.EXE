# Unit tests for the Tavern UI and rumor selection logic.
extends GutTest

const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")
const RUMOR_DEF := preload("res://scripts/resources/rumor_def.gd")

var _tavern_inst: Control


func before_each() -> void:
	GameState.reset_new_game()
	# Ensure the player starts with plenty of gold for testing
	GameState.ship.gold = 100


func after_each() -> void:
	if is_instance_valid(_tavern_inst):
		_tavern_inst.free()


func test_instantiation() -> void:
	_tavern_inst = TAVERN_SCENE.instantiate() as Control
	assert_not_null(_tavern_inst, "Tavern scene should instantiate successfully")
	add_child(_tavern_inst)
	assert_true(_tavern_inst.is_inside_tree(), "Tavern should enter the tree")


func test_initial_state() -> void:
	_tavern_inst = TAVERN_SCENE.instantiate() as Control
	# Initially, active_rumor is empty, so it should display greeting
	assert_eq(GameState.active_rumor, "", "Initial GameState.active_rumor should be empty")
	assert_false(GameState.last_drink_purchased, "Initial GameState.last_drink_purchased should be false")
	
	add_child(_tavern_inst)
	var label = _tavern_inst.find_child("Message") as Label
	assert_not_null(label)
	assert_true(label.text.contains("Speak up, friend!"), "Greeting should be shown")


func test_buy_round_success() -> void:
	_tavern_inst = TAVERN_SCENE.instantiate() as Control
	add_child(_tavern_inst)
	
	# Start with 50 gold
	GameState.ship.gold = 50
	_tavern_inst._update_gold_display()
	
	# Buy a round
	_tavern_inst._on_buy_pressed()
	
	# Expect gold reduced by 10 (drink_cost default)
	assert_eq(GameState.ship.gold, 40, "Gold should be decremented by drink cost")
	assert_true(GameState.last_drink_purchased, "last_drink_purchased flag should be set")
	
	var label = _tavern_inst.find_child("Message") as Label
	assert_true(label.text.contains("Cheers, Cap'n!"), "Cheers greeting should be shown")


func test_buy_round_failure_insufficient_gold() -> void:
	_tavern_inst = TAVERN_SCENE.instantiate() as Control
	add_child(_tavern_inst)
	
	# Start with 5 gold (not enough for 10 D drink)
	GameState.ship.gold = 5
	_tavern_inst._update_gold_display()
	
	# Buy a round
	_tavern_inst._on_buy_pressed()
	
	# Expect failure
	assert_eq(GameState.ship.gold, 5, "Gold should remain unchanged on failure")
	assert_false(GameState.last_drink_purchased, "last_drink_purchased flag should not be set")
	
	var label = _tavern_inst.find_child("Message") as Label
	assert_true(label.text.contains("purse is looking a bit light"), "Error message should be shown")


func test_weighted_rumor_selection() -> void:
	_tavern_inst = TAVERN_SCENE.instantiate() as Control
	add_child(_tavern_inst)
	
	# Create some mock rumors in the rumor pool
	var r1 = RUMOR_DEF.new()
	r1.id = "low_profit"
	r1.text = "Low profit"
	r1.profit_rating = 1
	
	var r2 = RUMOR_DEF.new()
	r2.id = "high_profit"
	r2.text = "High profit"
	r2.profit_rating = 1000000 # extremely high weight
	
	var rumors: Array[RumorDef] = []
	rumors.append(r1)
	rumors.append(r2)
	_tavern_inst._rumor_pool = rumors
	
	# With last_drink_purchased = true, weighted selection should almost certainly pick r2
	GameState.last_drink_purchased = true
	_tavern_inst._on_ask_pressed()
	
	assert_true(GameState.active_rumor.contains("High profit"), "Weighted selection should pick the high profit rumor")
	assert_false(GameState.last_drink_purchased, "last_drink_purchased should be cleared after ask")


func test_unweighted_rumor_selection() -> void:
	_tavern_inst = TAVERN_SCENE.instantiate() as Control
	add_child(_tavern_inst)
	
	# Create mock rumors
	var r1 = RUMOR_DEF.new()
	r1.id = "r1"
	r1.text = "Rumor 1"
	r1.profit_rating = 100
	
	var rumors: Array[RumorDef] = []
	rumors.append(r1)
	_tavern_inst._rumor_pool = rumors
	
	# With last_drink_purchased = false, standard selection
	GameState.last_drink_purchased = false
	_tavern_inst._on_ask_pressed()
	
	assert_true(GameState.active_rumor.contains("Rumor 1"), "Unweighted selection should pick from pool")
