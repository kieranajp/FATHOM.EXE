# SailingMath — pure helpers for the sailing efficiency curve.
#
# This module holds the curve constants (0.05, 0.95, 0.75, PI/4, 3PI/4) because
# they define the *shape* of the curve, not balance numbers. They are pinned to
# the JS reference test values (game.test.js:38-61) — see test/test_sailing.gd
# for the regression assertions.
#
# To retune the SHAPE of the curve: update this file AND the regression tests
# in one coordinated change. To retune SCALE / balance (max speed, etc.): use
# data/tuning/sailing.tres instead.
class_name SailingMath


# Sailing efficiency for a given player heading vs wind direction.
#
# JS reference: Game.calculateSailingEfficiency, game.js:675-693.
#   - 0..π/4 (in irons):           linear ramp 0..0.05
#   - π/4..3π/4 (reaching):        0.05 + 0.95 * sin(t*π/2), t ∈ [0,1] → peaks 1.0 at 3π/4
#   - 3π/4..π (running):           1.0 - 0.25 * t, t ∈ [0,1] → 0.75 at π
#
# The angle convention is "heading minus wind, wrapped into [0, π]" — i.e. how
# far off-wind you are sailing, irrespective of port vs starboard tack. Curve
# is symmetric: efficiency(yaw, 0) == efficiency(-yaw, 0).
static func efficiency(player_yaw: float, wind_angle: float) -> float:
	var diff: float = fmod(abs(player_yaw - wind_angle), TAU)
	if diff > PI:
		diff = TAU - diff

	# In irons (head to wind).
	if diff < PI / 4.0:
		return 0.05 * (diff / (PI / 4.0))

	# Reaching — peak at the broad reach (3π/4).
	if diff < PI * 0.75:
		var t: float = (diff - PI / 4.0) / (PI * 0.5)
		return 0.05 + 0.95 * sin(t * PI / 2.0)

	# Running downwind — slightly slower than a broad reach.
	var tr: float = (diff - PI * 0.75) / (PI * 0.25)
	return 1.0 - 0.25 * tr
