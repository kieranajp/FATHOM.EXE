# T42 — enforcer retarget on a second no-fire-zone violation.
#
# Drives `CombatSystem._handle_no_fire_zone_violation` directly with synthetic
# violators so we don't need a port group or PortDef proximity check. The
# helper is the same one `_check_no_fire_zone` calls after locating the
# nearest port, so this covers the retarget/no-op branches.
extends GutTest

var _system: CombatSystem
var _enemies_root: Node3D
var _port_node: Node3D
var _port_def: PortDef
var _violator_a: Node3D
var _violator_b: Node3D
var _hud_messages: Array = []


func _on_hud_message(text: String, severity: String) -> void:
	_hud_messages.append({"text": text, "severity": severity})


func before_each() -> void:
	# Fresh World state so prior tests don't bleed enforcer refs in.
	World.clear()
	_hud_messages = []

	_enemies_root = Node3D.new()
	add_child_autofree(_enemies_root)

	_system = CombatSystem.new()
	# Skip _ready's port-group/ocean/player lookups — we wire the minimum the
	# spawn path actually touches.
	_enemies_root.add_child(_system)
	_system.tuning = load("res://data/tuning/combat.tres") as CombatTuning
	# Reach into the private field directly: the autoload-free unit test can't
	# build a full PlayerShip, and spawn_enemy only uses _enemies_root.
	_system.set("_enemies_root", _enemies_root)

	# Synthetic port + violators. PortDef is a Resource; only used as the
	# `near_port` argument and re-emitted on the EventBus.
	_port_def = PortDef.new()
	_port_def.id = "test_port"
	_port_node = Node3D.new()
	add_child_autofree(_port_node)
	_port_node.global_position = Vector3(200.0, 0.0, 0.0)

	_violator_a = Node3D.new()
	add_child_autofree(_violator_a)
	_violator_a.global_position = Vector3(0.0, 0.0, 0.0)

	_violator_b = Node3D.new()
	add_child_autofree(_violator_b)
	_violator_b.global_position = Vector3(50.0, 0.0, 0.0)

	EventBus.hud_message.connect(_on_hud_message)


func after_each() -> void:
	if EventBus.hud_message.is_connected(_on_hud_message):
		EventBus.hud_message.disconnect(_on_hud_message)
	# Free any spawned enforcer/enemy so it doesn't outlive the test.
	for e in World.enemies:
		if e is Node and is_instance_valid(e):
			(e as Node).queue_free()
	World.clear()


func test_first_violation_spawns_enforcer_and_alerts() -> void:
	_system._handle_no_fire_zone_violation(_violator_a, _port_def, _port_node)

	assert_true(World.enforcer_alert_active, "alert should latch after first spawn")
	assert_not_null(World.enforcer, "World.enforcer should be set")
	assert_true(World.enforcer is EnemyShip, "World.enforcer should be an EnemyShip")
	var enforcer := World.enforcer as EnemyShip
	assert_true(enforcer.is_enforcer, "spawned ship should be flagged is_enforcer")
	assert_eq(enforcer.target, _violator_a, "fresh enforcer targets the first violator")
	# "PORT AUTHORITY ALERTED" should be on the bus.
	var spawn_msgs := _hud_messages.filter(func(m): return m["text"] == "PORT AUTHORITY ALERTED")
	assert_eq(spawn_msgs.size(), 1, "exactly one PORT AUTHORITY ALERTED hud_message")
	assert_eq(spawn_msgs[0]["severity"], "alert")


func test_second_violation_by_new_violator_retargets() -> void:
	# Seed: existing enforcer targeting violator A.
	_system._handle_no_fire_zone_violation(_violator_a, _port_def, _port_node)
	var enforcer := World.enforcer as EnemyShip
	assert_eq(enforcer.target, _violator_a)
	var enemy_count_before := World.enemies.size()
	_hud_messages.clear()

	# Second violation by a different ship — should retarget, not spawn.
	_system._handle_no_fire_zone_violation(_violator_b, _port_def, _port_node)

	assert_eq(World.enemies.size(), enemy_count_before, "no new enforcer should spawn")
	assert_eq(World.enforcer, enforcer, "the same enforcer remains the singleton")
	assert_eq(enforcer.target, _violator_b, "enforcer should be retargeted to violator B")
	var redirected := _hud_messages.filter(func(m): return m["text"] == "ENFORCER REDIRECTED")
	assert_eq(redirected.size(), 1, "exactly one ENFORCER REDIRECTED hud_message")
	assert_eq(redirected[0]["severity"], "alert")


func test_second_violation_by_same_violator_is_no_op() -> void:
	_system._handle_no_fire_zone_violation(_violator_a, _port_def, _port_node)
	var enforcer := World.enforcer as EnemyShip
	var enemy_count_before := World.enemies.size()
	_hud_messages.clear()

	# Same violator again — no retarget, no hud_message spam.
	_system._handle_no_fire_zone_violation(_violator_a, _port_def, _port_node)

	assert_eq(World.enemies.size(), enemy_count_before, "no new enforcer should spawn")
	assert_eq(enforcer.target, _violator_a, "target unchanged")
	var redirected := _hud_messages.filter(func(m): return m["text"] == "ENFORCER REDIRECTED")
	assert_eq(redirected.size(), 0, "no ENFORCER REDIRECTED hud_message when already targeting")
