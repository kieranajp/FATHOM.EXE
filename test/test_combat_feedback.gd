# T42 — combat HUD-message emissions.
#
# Drives CombatSystem's projectile hit-check paths directly with stub
# player + enemy nodes, capturing EventBus.hud_message to assert the right
# severity/text fires on damage, sink, and chain-debuff.
#
# Doesn't exercise port lookup / no-fire-zone (covered by test_enforcer_retarget).
extends GutTest

var _system: CombatSystem
var _enemies_root: Node3D
var _player: PlayerShip
var _hud_messages: Array = []


func _on_hud_message(text: String, severity: String) -> void:
	_hud_messages.append({"text": text, "severity": severity})


func before_each() -> void:
	GameState.reset_new_game()
	World.clear()
	_hud_messages = []

	_enemies_root = Node3D.new()
	add_child_autofree(_enemies_root)

	_system = CombatSystem.new()
	_enemies_root.add_child(_system)
	_system.tuning = load("res://data/tuning/combat.tres") as CombatTuning
	_system.set("_enemies_root", _enemies_root)

	# A minimal PlayerShip — _ready will set ship_class from the dinghy default.
	_player = PlayerShip.new()
	add_child_autofree(_player)
	# Park player at origin.
	_player.global_position = Vector3.ZERO
	_system.set("_player", _player)

	EventBus.hud_message.connect(_on_hud_message)


func after_each() -> void:
	if EventBus.hud_message.is_connected(_on_hud_message):
		EventBus.hud_message.disconnect(_on_hud_message)
	for e in World.enemies:
		if e is Node and is_instance_valid(e):
			(e as Node).queue_free()
	World.clear()


func _spawn_enemy_at(pos: Vector3, health: float = 100.0) -> EnemyShip:
	# Use the public spawn entry so the EnemyShip._ready loads ship_class
	# (sloop default has hit_radius/hit_height set; that's what the hit check
	# needs).
	var enemy := _system.spawn_enemy(pos, "sloop", "pirate", _player, false)
	if enemy != null:
		enemy.health = health
		enemy.max_health = max(enemy.max_health, health)
	return enemy


func test_player_damaged_emits_brace_for_impact() -> void:
	# Synthetic enemy-owned ball projectile sitting on top of the player.
	var projectile := {
		"x": 0.0, "y": 0.0, "z": 0.0,
		"vx": 0.0, "vy": 0.0, "vz": 0.0,
		"life": 1.0,
		"is_player_owned": false,
		"type": "ball",
		"damage": 15.0,
		"attacker": null,
	}
	var hit: bool = _system._check_hits_against_player(projectile)
	assert_true(hit, "projectile at player position should register a hit")

	var brace := _hud_messages.filter(func(m): return String(m["text"]).begins_with("BRACE FOR IMPACT"))
	assert_eq(brace.size(), 1, "exactly one BRACE FOR IMPACT message")
	assert_eq(brace[0]["severity"], "alert")
	assert_true(String(brace[0]["text"]).contains("-15 HP"), "damage value should be in the banner")


func test_enemy_sunk_emits_enemy_down() -> void:
	var enemy := _spawn_enemy_at(Vector3(0.0, 0.0, 0.0), 10.0)
	assert_not_null(enemy, "spawn_enemy should succeed")

	var projectile := {
		"x": 0.0, "y": 0.0, "z": 0.0,
		"vx": 0.0, "vy": 0.0, "vz": 0.0,
		"life": 1.0,
		"is_player_owned": true,
		"type": "ball",
		"damage": 100.0,  # overkill
		"attacker": _player,
	}
	var hit: bool = _system._check_hits_against_enemies(projectile)
	assert_true(hit, "overkill projectile on enemy should register a hit")

	var sunk_msgs := _hud_messages.filter(func(m): return m["text"] == "ENEMY DOWN")
	assert_eq(sunk_msgs.size(), 1, "exactly one ENEMY DOWN message on sink")
	assert_eq(sunk_msgs[0]["severity"], "info")


func test_enemy_damaged_but_alive_does_not_emit_enemy_down() -> void:
	var enemy := _spawn_enemy_at(Vector3(0.0, 0.0, 0.0), 100.0)
	assert_not_null(enemy)

	var projectile := {
		"x": 0.0, "y": 0.0, "z": 0.0,
		"vx": 0.0, "vy": 0.0, "vz": 0.0,
		"life": 1.0,
		"is_player_owned": true,
		"type": "ball",
		"damage": 10.0,
		"attacker": _player,
	}
	_system._check_hits_against_enemies(projectile)

	var sunk_msgs := _hud_messages.filter(func(m): return m["text"] == "ENEMY DOWN")
	assert_eq(sunk_msgs.size(), 0, "no ENEMY DOWN when the enemy survives the hit")


func test_chain_shot_emits_rigging_damaged_warning() -> void:
	var projectile := {
		"x": 0.0, "y": 0.0, "z": 0.0,
		"vx": 0.0, "vy": 0.0, "vz": 0.0,
		"life": 1.0,
		"is_player_owned": false,
		"type": "chain",
		"damage": 5.0,
		"attacker": null,
	}
	_system._check_hits_against_player(projectile)

	var rigging := _hud_messages.filter(func(m): return String(m["text"]).begins_with("RIGGING DAMAGED"))
	assert_eq(rigging.size(), 1, "exactly one RIGGING DAMAGED message on chain-shot hit")
	assert_eq(rigging[0]["severity"], "warning")
	assert_gt(_player.speed_debuff_timer, 0.0, "chain shot should apply speed debuff to player")
