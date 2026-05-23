# Pins the aim-mode OR-gate. Mouse handling is integration plumbing and not
# worth a full input-fake, but the truth table for "either source activates
# aim_mode" is load-bearing — if a future edit reorders the operands to AND,
# Space-only or RMB-only aiming silently breaks.
#
# See scripts/player/player_ship.gd._compute_aim_mode.
extends GutTest


func test_neither_input_is_false() -> void:
	assert_false(PlayerShip._compute_aim_mode(false, false))


func test_right_mouse_only_is_true() -> void:
	assert_true(PlayerShip._compute_aim_mode(true, false))


func test_action_only_is_true() -> void:
	assert_true(PlayerShip._compute_aim_mode(false, true))


func test_both_inputs_is_true() -> void:
	assert_true(PlayerShip._compute_aim_mode(true, true))
