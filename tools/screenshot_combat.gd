# Combat-visuals screenshot harness — boots Main, spawns a pirate sloop in
# front of the player, then drives a multi-stage scenario producing:
#   /tmp/fathom_combat_projectiles.png — broadside mid-flight (cyan cannonballs)
#   /tmp/fathom_combat_hit.png         — sparks on ship hit / splash on water
#   /tmp/fathom_combat_sink.png        — floating crates after enemy sinks
#
# Use case: visual verification for T47 (issue #47). A single shot doesn't
# catch every element — projectiles fly ~1-2s, splashes pop briefly on water
# hit, crates only spawn on enemy sink — so we sequence the actions.
#
# Also dumps a sloop+galleon "spawn-pose" comparison shot
#   /tmp/fathom_ship_classes.png   — pirate sloop + authority galleon side-by-side
# to verify Part B (enemy ship class visuals).
#
# Usage:
#   timeout 60 godot --path . tools/ScreenshotCombat.tscn
extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const OUT_DIR := "/tmp"


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)

	# Let the scene tree finish wiring (chase-cam settle + open-sea ready).
	for _i in 30:
		await get_tree().process_frame

	var player := main.find_child("PlayerShip", true, false) as PlayerShip
	var combat := main.find_child("CombatSystem", true, false) as CombatSystem
	if player == null or combat == null:
		push_error("Combat screenshot: missing PlayerShip/CombatSystem")
		get_tree().quit()
		return

	# Drop sails so the player doesn't drift away from the spawn formation. The
	# chase cam follows the player; if the player moves the spawned enemies
	# fall behind quickly.
	player.set_sail_level(0.0)
	player.speed = 0.0

	# --- Shot 1: ship-class silhouettes (Part B). ---
	# Spawn a pirate sloop and an authority galleon side by side, dead ahead.
	# Both should be visible in the chase cam frame with their distinct
	# silhouettes (sloop = small triangular, galleon = larger, multi-mast).
	var sloop_pos: Vector3 = player.global_position + Vector3(-20.0, 0.0, -60.0)
	var galleon_pos: Vector3 = player.global_position + Vector3(20.0, 0.0, -60.0)
	combat.spawn_enemy(sloop_pos, "sloop", "pirate", player, false)
	combat.spawn_enemy(galleon_pos, "galleon", "authority", player, true)
	# Settle a few frames so the wave-ride + transform composition is applied.
	for _i in 12:
		await get_tree().process_frame
	_snap("ship_classes")

	# --- Shot 2: projectiles in flight. ---
	# Both broadsides simultaneously so we hit both sloop and galleon.
	combat.player_fire("port")
	combat.player_fire("starboard")
	# Snap a couple of frames into flight — close enough that projectiles are
	# still near the player (visible in foreground) but moving fast enough that
	# the velocity-based trail tail extends behind them.
	for _i in 6:
		await get_tree().process_frame
	print("Projectiles alive: ", World.projectiles.size())
	_snap("projectiles")

	# --- Shot 3: hit + splashes + sparks. ---
	# Let the first broadside resolve. ball_life = 4s; muzzle vel 28 m/s; at 65m
	# the projectile lands around 2.3s = 138 frames. After that we have splash
	# rings (life 0.55s = 33 frames) and spark debris (life 1.5-2s).
	for _i in 110:
		await get_tree().process_frame
	# At this point splashes from the missed shots should be visible and any
	# hits on the sloop spawned spark debris that's still alive.
	_snap("hit")

	# --- Shot 4: enemy sink → crates. ---
	# Force-kill the sloop so we don't have to grind it down with broadsides.
	# _begin_sink spawns crates near the sloop's current world pos; the chase
	# cam shows them riding the wave for a few seconds.
	var sloop: EnemyShip = null
	for e in World.enemies:
		if e is EnemyShip and (e as EnemyShip).faction_id == "pirate":
			sloop = e as EnemyShip
			break
	if sloop != null:
		print("Forcing sink on sloop at ", sloop.global_position)
		# Move it closer in case combat AI drifted it away.
		sloop.global_position = player.global_position + Vector3(-15.0, 0.0, -40.0)
		Combat.apply_ship_damage(sloop, sloop.max_health * 2.0, sloop.max_health)
		combat.call("_begin_sink", sloop, player)
	# Wait long enough that crates have spread out and ridden a wave.
	for _i in 90:
		await get_tree().process_frame
	var crate_count := 0
	for d in World.debris:
		if not bool(d.get("is_spark", false)):
			crate_count += 1
	print("Crates alive: ", crate_count, " / total debris: ", World.debris.size())
	_snap("sink")

	print("Combat screenshots done")
	get_tree().quit()


func _snap(suffix: String) -> void:
	var path := "%s/fathom_combat_%s.png" % [OUT_DIR, suffix]
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		push_error("Save failed (%s): %s" % [path, str(err)])
	else:
		print("Saved %s" % path)
