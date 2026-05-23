# World — transient scene state (enemies, projectiles, particles, debris).
# Not persisted. Cleared on scene change.
# Owner: stub from F1. Filled in by T04 (combat) / T05 (AI) / T07 (FX).
extends Node

var enemies: Array = []        # Array[EnemyShip] once that class exists (T05)
var projectiles: Array = []    # Dictionary form for speed
var particles: Array = []      # sea spray
var debris: Array = []
var splashes: Array = []

# The port the player is currently within proximity of. Set by the proximity
# tick in OpenSea (T03); null when at sea. Distinct from
# GameState.current_port_id which only flips on dock/undock.
var active_port: PortDef = null


func clear() -> void:
	enemies.clear()
	projectiles.clear()
	particles.clear()
	debris.clear()
	splashes.clear()
	active_port = null
