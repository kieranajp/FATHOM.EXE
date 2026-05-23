# RespawnTuning — numbers for the player-death respawn flow.
# Authored in data/tuning/respawn.tres; loaded by scripts/main.gd's death handler.
#
# JS reference: game.js:1399 handlePlayerDeath — cargo is wiped, gold halved,
# health refilled, player teleported to the nearest port in the current
# archipelago. Sail level is reset so the respawned player isn't barrelling at
# the docks.
class_name RespawnTuning extends Tuning

# Fraction of gold retained on death. JS used 0.5 (handlePlayerDeath wiped
# cargo only; we halve gold per the T37 issue brief for a meatier penalty).
@export var gold_retention_fraction: float = 0.5

# Sail level the player respawns with. 2.0 == half-mast; gentle ease out of port.
@export var default_sail_level: float = 2.0
