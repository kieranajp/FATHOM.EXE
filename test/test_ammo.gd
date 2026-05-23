# Regression test for Combat.fire_broadside ammo + projectile behaviour.
#
# Pinned to JS reference (main:game.test.js:455-595 ammo; 1329-1413 firepower).
#
# The signature differs from JS (pure helper vs Game.fireBroadside method) but
# the contract is identical: cooldown gate, ammo consumption = min(firepower,
# available), per-ammo life/damage/pellets.
extends GutTest

const TOL := 1.0e-3

var _tuning: CombatTuning


func before_each() -> void:
	_tuning = load("res://data/tuning/combat.tres") as CombatTuning


func _player_state(active_ammo: String = "ball", ammo: Dictionary = {}, firepower: int = 1) -> Dictionary:
	if ammo.is_empty():
		ammo = {"ball": 5, "chain": 2, "grape": 1}
	return {
		"x": 0.0, "y": 0.0, "z": 0.0,
		"yaw": 0.0, "speed": 0.0,
		"hit_radius": 3.0,
		"firepower": firepower,
		"reload_port": 0.0, "reload_stbd": 0.0,
		"active_ammo": active_ammo,
		"ammo": ammo,
		"is_player_owned": true,
	}


func test_deplete_one_ammo_unit_on_fire() -> void:
	var state: Dictionary = _player_state("ball")
	var projectiles: Array = []
	var ok: bool = Combat.fire_broadside(state, "port", _tuning, projectiles)
	assert_true(ok)
	assert_eq(int(state.ammo.ball), 4)
	assert_eq(projectiles.size(), 1)
	assert_eq(projectiles[0].type, "ball")
	assert_almost_eq(float(projectiles[0].life), 4.0, TOL)
	assert_almost_eq(float(projectiles[0].damage), 25.0, TOL)


func test_blocked_when_no_ammo() -> void:
	var state: Dictionary = _player_state("ball", {"ball": 0, "chain": 2, "grape": 1})
	var projectiles: Array = []
	var ok: bool = Combat.fire_broadside(state, "port", _tuning, projectiles)
	assert_false(ok)
	assert_eq(int(state.ammo.ball), 0)
	assert_eq(projectiles.size(), 0)
	# Cooldown not set when fire is blocked.
	assert_eq(float(state.reload_port), 0.0)


func test_chain_lifespan_and_damage() -> void:
	var state: Dictionary = _player_state("chain")
	var projectiles: Array = []
	Combat.fire_broadside(state, "port", _tuning, projectiles)
	assert_eq(int(state.ammo.chain), 1)
	assert_eq(projectiles[0].type, "chain")
	assert_almost_eq(float(projectiles[0].life), 2.2, TOL)
	assert_almost_eq(float(projectiles[0].damage), 10.0, TOL)


func test_grape_spawns_pellet_count_per_cannon() -> void:
	var state: Dictionary = _player_state("grape", {"ball": 5, "chain": 2, "grape": 1})
	var projectiles: Array = []
	Combat.fire_broadside(state, "port", _tuning, projectiles)
	assert_eq(int(state.ammo.grape), 0)
	# 16 pellets per cannon, firepower=1.
	assert_eq(projectiles.size(), 16)
	assert_eq(projectiles[0].type, "grape")
	assert_almost_eq(float(projectiles[0].life), 0.8, TOL)
	assert_almost_eq(float(projectiles[0].damage), 2.0, TOL)


func test_firepower_consumes_one_ammo_per_cannon() -> void:
	# Sloop firepower=2 → 2 ammo spent, 2 projectiles.
	var state: Dictionary = _player_state("ball", {"ball": 10, "chain": 0, "grape": 0}, 2)
	var projectiles: Array = []
	Combat.fire_broadside(state, "port", _tuning, projectiles)
	assert_eq(projectiles.size(), 2)
	assert_eq(int(state.ammo.ball), 8)


func test_partial_broadside_when_low_ammo() -> void:
	# Galleon firepower=4 with only 3 ball left → 3 projectiles, ammo to 0.
	var state: Dictionary = _player_state("ball", {"ball": 3, "chain": 0, "grape": 0}, 4)
	var projectiles: Array = []
	Combat.fire_broadside(state, "port", _tuning, projectiles)
	assert_eq(projectiles.size(), 3)
	assert_eq(int(state.ammo.ball), 0)


func test_reload_set_on_successful_fire() -> void:
	var state: Dictionary = _player_state("ball")
	Combat.fire_broadside(state, "starboard", _tuning, [])
	assert_almost_eq(float(state.reload_stbd), 3.0, TOL)
	assert_eq(float(state.reload_port), 0.0)


func test_cooldown_blocks_re_fire() -> void:
	var state: Dictionary = _player_state("ball")
	state.reload_port = 1.5
	var projectiles: Array = []
	var ok: bool = Combat.fire_broadside(state, "port", _tuning, projectiles)
	assert_false(ok)
	assert_eq(projectiles.size(), 0)
	# Ammo untouched.
	assert_eq(int(state.ammo.ball), 5)


func test_aim_mode_higher_target_yields_higher_vy() -> void:
	# Two shots at same range, different heights. JS test 922-935: high > low vy.
	var p_high: Dictionary = _player_state("ball")
	var aim_high := {"active": true, "side": "port", "yaw_offset": 0.0, "range": 100.0, "height": 15.0}
	var proj_high: Array = []
	Combat.fire_broadside(p_high, "port", _tuning, proj_high, null, aim_high)

	var p_low: Dictionary = _player_state("ball")
	var aim_low := {"active": true, "side": "port", "yaw_offset": 0.0, "range": 100.0, "height": -5.0}
	var proj_low: Array = []
	Combat.fire_broadside(p_low, "port", _tuning, proj_low, null, aim_low)

	assert_eq(proj_high.size(), 1)
	assert_eq(proj_low.size(), 1)
	assert_gt(float(proj_high[0].vy), float(proj_low[0].vy))
