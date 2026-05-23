# World — transient scene state (enemies, projectiles, particles, debris).
# Not persisted. Cleared on scene change.
# Owner: stub from F1. Filled in by T06 (combat) / T07 (HUD reads) / FX tickets.
extends Node

var enemies: Array = []        # Array[EnemyShip] (typed at use site to avoid an autoload→class dependency)

var projectiles: Array[Projectile] = []:
	set(val):
		projectiles = _ensure_projectiles(val)

var debris: Array[Debris] = []:
	set(val):
		debris = _ensure_debris(val)

var splashes: Array[Splash] = []:
	set(val):
		splashes = _ensure_splashes(val)

# The port the player is currently within proximity of. Set by the proximity
# tick in OpenSea (T03); null when at sea. Distinct from
# GameState.current_port_id which only flips on dock/undock.
var active_port: PortDef = null

# T06: currently-locked enemy target (closest hostile in range, or null).
# HUD reads this for lock-on UI.
var active_target: Node = null

# T06: aim-mode state. Populated by PlayerShip each frame while aim_mode is
# true; consumed by AimOverlay (3D lines) and HUD (telemetry text). Empty when
# not aiming. Schema:
#   active: bool
#   side: String         "port" | "starboard"
#   yaw_offset: float    rad, clamped to ±pi/4
#   range: float         metres, 30..240
#   height: float        metres, -10..30
#   reticle: Vector3     world-space target point
var aim_state: Dictionary = {}

# T06: enforcer alert flag. The authority response spawns one galleon on the
# first no-fire-zone violation per session; this latch prevents a second spawn
# until the active enforcer is sunk/de-aggros (combat_system flips it back).
var enforcer_alert_active: bool = false

# T42: reference to the currently-active enforcer (EnemyShip with is_enforcer).
# Typed as Node to avoid an autoload→class dependency, same as `active_target`.
# Set by CombatSystem.spawn_enemy when is_enforcer=true; cleared when the
# enforcer dies (alongside `enforcer_alert_active`). Used by the retarget path
# to switch an existing enforcer onto a new violator.
var enforcer: Node = null

# T39: pending pirate-intercept count. Set by ui/travel.gd when a fast-travel
# trip is intercepted; consumed and cleared by systems/enemy_spawner.gd on the
# next initial-spawn tick. 0 means "no pending intercept" (normal seed only).
var pending_intercept_count: int = 0

# Proximity flag continuously computed by CombatSystem each tick (T50 warning banner)
var is_in_no_fire_zone: bool = false


func clear() -> void:
	enemies.clear()
	projectiles.clear()
	debris.clear()
	splashes.clear()
	active_port = null
	active_target = null
	aim_state = {}
	enforcer_alert_active = false
	enforcer = null
	pending_intercept_count = 0
	is_in_no_fire_zone = false


func _ensure_projectiles(val: Array) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for item in val:
		if item is Projectile:
			out.append(item)
		elif item is Dictionary:
			out.append(Projectile.create(item))
	return out


func _ensure_debris(val: Array) -> Array[Debris]:
	var out: Array[Debris] = []
	for item in val:
		if item is Debris:
			out.append(item)
		elif item is Dictionary:
			out.append(Debris.create(item))
	return out


func _ensure_splashes(val: Array) -> Array[Splash]:
	var out: Array[Splash] = []
	for item in val:
		if item is Splash:
			out.append(item)
		elif item is Dictionary:
			out.append(Splash.create(item))
	return out
