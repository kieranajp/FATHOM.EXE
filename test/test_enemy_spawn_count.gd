# T48 — pirate spawn count scales with ArchipelagoDef.risk_tier.
#
# Pins the CombatTuning.spawn_count_for_tier helper to the JS difficulty curve:
#   tier 1: 0 or 1 (40% chance of 1)
#   tier 2: exactly 1
#   tier 3: 2..3 uniform
#   other:  defaults to 1 (fail-safe)
#
# The helper is non-deterministic (randf / randi_range under the hood) so the
# tier-1 and tier-3 tests are statistical — they run many trials and assert
# that the observed mean lands within a generous envelope around the tuning
# value. Envelope sized for ~200 trials so the suite isn't flaky; documented
# at each call site.
extends GutTest

const TRIALS_LOW: int = 200
const TRIALS_HIGH: int = 200
const TRIALS_MED: int = 50
# +/-0.1 around the tuning mean is wide enough that a healthy 0.4-chance roll
# over 200 trials lands inside ~99% of the time, but tight enough to catch a
# regression that inverts the chance (0.6) or zeros it out.
const LOW_MEAN_TOLERANCE: float = 0.1

var _tuning: CombatTuning


func before_each() -> void:
	# Load the shipped .tres so the test also pins the authored defaults, not
	# just the script-default values.
	_tuning = load("res://data/tuning/combat.tres") as CombatTuning
	assert_not_null(_tuning, "combat.tres loads as CombatTuning")


# ---- Tuning values are authored as expected ----------------------------------

func test_shipped_tuning_pins_curve_shape() -> void:
	# Regression net against an accidental edit to combat.tres that breaks the
	# tier curve (e.g. swapping low <-> high). Mirrors game.js:2451-2475.
	assert_eq(_tuning.low_tier_spawn_chance, 0.4, "low_tier_spawn_chance = 0.4")
	assert_eq(_tuning.low_tier_max_count, 1, "low_tier_max_count = 1")
	assert_eq(_tuning.medium_tier_count, 1, "medium_tier_count = 1")
	assert_eq(_tuning.high_tier_min_count, 2, "high_tier_min_count = 2")
	assert_eq(_tuning.high_tier_max_count, 3, "high_tier_max_count = 3")


# ---- Tier 1: 0 or 1, mean ≈ low_tier_spawn_chance ----------------------------

func test_tier_one_count_is_zero_or_one() -> void:
	# Over TRIALS_LOW trials every result must be 0 or 1 — never anything else.
	# This is the structural invariant, separate from the statistical mean
	# check below.
	for _i in TRIALS_LOW:
		var c: int = _tuning.spawn_count_for_tier(1)
		assert_true(c == 0 or c == 1, "tier 1 count is 0 or 1, got %d" % c)


func test_tier_one_mean_within_envelope() -> void:
	# Statistical: empirical mean over TRIALS_LOW trials should land within
	# +/-LOW_MEAN_TOLERANCE of low_tier_spawn_chance. With p=0.4 and n=200, the
	# normal-approx std-dev is ~0.035, so a 0.1 envelope is ~3 sigma — wide
	# enough to be non-flaky, tight enough to catch a chance inversion or zero.
	var hits: int = 0
	for _i in TRIALS_LOW:
		if _tuning.spawn_count_for_tier(1) == 1:
			hits += 1
	var mean: float = float(hits) / float(TRIALS_LOW)
	assert_almost_eq(
		mean, _tuning.low_tier_spawn_chance, LOW_MEAN_TOLERANCE,
		"tier 1 mean (%f) within +/-%f of low_tier_spawn_chance (%f)" % [
			mean, LOW_MEAN_TOLERANCE, _tuning.low_tier_spawn_chance,
		],
	)


# ---- Tier 2: always exactly 1 -----------------------------------------------

func test_tier_two_is_always_one() -> void:
	# Deterministic — no RNG path on tier 2. 50 trials is overkill but cheap
	# and makes the "no surprises" assertion explicit.
	for _i in TRIALS_MED:
		assert_eq(
			_tuning.spawn_count_for_tier(2), 1,
			"tier 2 always returns medium_tier_count (1)",
		)


# ---- Tier 3: 2..3 uniform ---------------------------------------------------

func test_tier_three_count_in_bounds() -> void:
	# Structural: every result must land in [high_tier_min_count,
	# high_tier_max_count]. randi_range is inclusive on both ends.
	for _i in TRIALS_HIGH:
		var c: int = _tuning.spawn_count_for_tier(3)
		assert_true(
			c >= _tuning.high_tier_min_count and c <= _tuning.high_tier_max_count,
			"tier 3 count in [%d, %d], got %d" % [
				_tuning.high_tier_min_count, _tuning.high_tier_max_count, c,
			],
		)


func test_tier_three_covers_both_bounds() -> void:
	# Statistical-ish: over TRIALS_HIGH trials both min and max should appear
	# at least once. With p=0.5 of each across a [2,3] uniform, P(never hits
	# one bound over 200 trials) ~= 0.5^200 ≈ 0, so this is effectively
	# deterministic but catches a regression that pins the result to a single
	# bound.
	var saw_min: bool = false
	var saw_max: bool = false
	for _i in TRIALS_HIGH:
		var c: int = _tuning.spawn_count_for_tier(3)
		if c == _tuning.high_tier_min_count:
			saw_min = true
		if c == _tuning.high_tier_max_count:
			saw_max = true
		if saw_min and saw_max:
			break
	assert_true(saw_min, "tier 3 hits high_tier_min_count at least once over %d trials" % TRIALS_HIGH)
	assert_true(saw_max, "tier 3 hits high_tier_max_count at least once over %d trials" % TRIALS_HIGH)


# ---- Out-of-range tiers fall back to 1 --------------------------------------

func test_unknown_tier_defaults_to_one() -> void:
	# Mirrors the TravelTuning convention: a misconfigured archipelago should
	# still tick ambient threat rather than going silent. Default = 1 (one
	# pirate).
	assert_eq(_tuning.spawn_count_for_tier(0), 1, "tier 0 defaults to 1")
	assert_eq(_tuning.spawn_count_for_tier(-1), 1, "tier -1 defaults to 1")
	assert_eq(_tuning.spawn_count_for_tier(4), 1, "tier 4 defaults to 1")
	assert_eq(_tuning.spawn_count_for_tier(99), 1, "tier 99 defaults to 1")
