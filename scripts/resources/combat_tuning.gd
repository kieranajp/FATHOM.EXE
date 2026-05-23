# CombatTuning — numbers for ammo, damage, reload, projectile life, AI thresholds.
# Authored in data/tuning/combat.tres; loaded by combat-side systems.
#
# All numeric constants used by the combat subsystem live here per ARCHITECTURE.md
# § "Tuning". Magic numbers in scripts are a code-review bug. Values pinned to
# the JS prototype on `main` — see game.test.js for the canonical spec.
class_name CombatTuning extends Tuning

# --- Ammo: damage, life (seconds), pellets-per-cannon. ---
@export var ball_damage: float = 25.0
@export var ball_life: float = 4.0
@export var chain_damage: float = 10.0
@export var chain_life: float = 2.2
@export var chain_debuff_seconds: float = 5.0
@export var grape_damage: float = 2.0
@export var grape_life: float = 0.8
@export var grape_pellets: int = 16

# --- Reload (per side, seconds). ---
@export var reload_seconds: float = 3.0
@export var ai_reload_seconds: float = 4.0
@export var ai_galleon_reload_seconds: float = 5.0

# --- Projectile launch physics. ---
@export var muzzle_velocity: float = 28.0       # player ball/chain horizontal m/s
@export var ai_muzzle_velocity: float = 25.0    # enemy lateral m/s
@export var gravity: float = 9.81               # m/s^2 (projectile + ballistic solver)
@export var elev_degrees: float = 15.0          # fixed (no-aim) elevation, degrees
@export var cannon_spread: float = 0.12         # +/- spread per cannon, radians
@export var grape_spread: float = 0.50          # +/- pellet horizontal spread, radians
@export var grape_vy_jitter: float = 5.0        # +/- vertical velocity jitter
@export var grape_speed_min: float = 0.88       # speed-magnitude multiplier floor
@export var grape_speed_max: float = 1.12       # speed-magnitude multiplier ceiling
@export var vy_clamp_min: float = -10.0         # ballistic solver clamps
@export var vy_clamp_max: float = 45.0
@export var min_aim_distance: float = 5.0       # solver floor (avoid div by zero)

# --- Aim mode. ---
@export var aim_range_min: float = 30.0
# aim_range_max is clamped to the BALL projectile's physically reachable range
# at default elevation. The ballistic solver in Combat._spawn_ball_or_chain sets
# t = d / muzzle, then the projectile silently despawns when life expires —
# so any reticle distance d > muzzle * ball_life simply puts a shot mid-air
# at life=0 with no splash. With muzzle=28 and ball_life=4.0 the cap is 112m;
# we round down to 110m to give a small safety margin. Don't raise this
# without also raising ball_life (and re-checking chain_life undershoot).
# See test_combat_aim_range.gd for the regression pin.
@export var aim_range_max: float = 110.0
@export var aim_range_default: float = 80.0
@export var aim_yaw_max: float = PI / 4.0       # +/- pi/4 cone
@export var aim_height_min: float = -10.0
@export var aim_height_max: float = 30.0
@export var aim_mouse_yaw_rate: float = 0.005   # rad per pixel of mouse delta
@export var aim_mouse_range_rate: float = 0.5   # metres per pixel
@export var aim_mouse_height_rate: float = 0.10 # metres per pixel (shift-held)

# --- Hit detection. ---
# JS impl: dist < hit_radius && py >= sy - 1.0 && py <= sy + hit_height.
# The 1.0 wave-trough leniency is the spec, not a tuning lever — kept here so
# tests reference the same constant.
@export var hit_y_below_leniency: float = 1.0

# --- Target acquisition + spawning. ---
@export var target_acquire_range: float = 200.0
@export var spawn_min_distance: float = 150.0
@export var spawn_max_distance: float = 250.0
# Legacy uniform spawn count (pre-T48). Kept as a fallback in case a future
# spawner path bypasses the tier-aware helper; the ambient initial-spawn path
# now goes through spawn_count_for_tier() and ignores these.
@export var spawn_initial_count_min: int = 1
@export var spawn_initial_count_max: int = 2

# --- T48: tier-aware ambient spawn counts. ---
# Mirror of the JS difficulty curve (game.js:2451-2475):
#   tier 1 (Pirate's Cradle):  40% chance of 1 pirate, else calm
#   tier 2 (Spanish Main):     exactly 1 pirate
#   tier 3 (Smuggler's Run):   2..3 pirates uniform
# Only the ambient initial-spawn path consults these — the T39 intercept path
# (World.pending_intercept_count) is explicit and unaffected.
@export_range(0.0, 1.0) var low_tier_spawn_chance: float = 0.4
@export var low_tier_max_count: int = 1
@export var medium_tier_count: int = 1
@export var high_tier_min_count: int = 2
@export var high_tier_max_count: int = 3

# --- No-fire zone. ---
@export var no_fire_zone_radius: float = 120.0

# --- Sinking. ---
@export var sink_descent_rate: float = 2.0      # m/s while sinking
@export var sink_despawn_y: float = -35.0       # remove after y drops below this

# --- AI state-machine thresholds. ---
@export var ai_patrol_distance: float = 300.0
@export var ai_chase_distance: float = 100.0
@export var ai_patrol_speed_fraction: float = 0.4
@export var ai_chase_speed_fraction: float = 0.8
@export var ai_orbit_speed_fraction: float = 0.7
@export var ai_patrol_yaw_rate: float = 0.15    # rad/s drift
@export var ai_chase_yaw_rate: float = 0.8
@export var ai_orbit_yaw_rate: float = 1.2
@export var ai_chain_debuff_speed_mult: float = 0.5
@export var ai_fire_angle_tolerance: float = 0.35  # rad off ±pi/2 for fire

# --- Splash / debris. ---
@export var splash_max_radius_base: float = 3.5
@export var splash_max_radius_jitter: float = 1.5
@export var splash_life: float = 0.55
@export var debris_count_on_hit: int = 8

# --- Ship physics. ---
# Separate from sailing_tuning.roll_factor so enemy ship feel can be tuned
# independently of the player's roll response.
@export var enemy_roll_factor: float = 0.05


# T48 — Map an ArchipelagoDef.risk_tier (1/2/3) to an ambient spawn count.
# Non-deterministic by design: tier 1 and tier 3 roll RNG. Tests should call
# this many times and assert distribution shape, or assert on the underlying
# fields (low_tier_spawn_chance, high_tier_min/max_count) directly. Out-of-
# range tiers fall back to 1 so a misconfigured archipelago still ticks the
# ambient threat without going silent or going apocalyptic.
func spawn_count_for_tier(tier: int) -> int:
	match tier:
		1:
			return low_tier_max_count if randf() < low_tier_spawn_chance else 0
		2:
			return medium_tier_count
		3:
			return randi_range(high_tier_min_count, high_tier_max_count)
		_:
			return 1
