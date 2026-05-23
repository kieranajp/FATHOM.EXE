# Factions — static lookup for faction visual identity (colour, display name).
#
# Colours are pinned to ARCHITECTURE.md § "Rendering decisions":
#   player    — green  #33ff33
#   pirate    — red    #ff5555
#   authority — blue   #3388ff
#   neutral   — amber  #ffaa00
#
# These are identity, not balance, so they live as constants here rather than
# in a tuning .tres. T06 will spawn faction-themed enemy ships against the
# same registry; T07 (HUD) reads it for target panel + ammo/UI tinting.
#
# Why a static class and not a FactionState resource? FactionState exists for
# *runtime* state (reputation, etc.) and is post-parity. The colour+name pair
# is a fixed lookup — no need to author a .tres per faction yet. Promote to
# full FactionState resources when reputation matters.
class_name Factions


const UNKNOWN := {
	"id": "unknown",
	"display_name": "UNKNOWN",
	"color": Color("#888888"),
}

const REGISTRY := {
	"player": {
		"id": "player",
		"display_name": "PLAYER",
		"color": Color("#33ff33"),
	},
	"pirate": {
		"id": "pirate",
		"display_name": "PIRATE",
		"color": Color("#ff5555"),
	},
	"authority": {
		"id": "authority",
		"display_name": "PORT AUTHORITY",
		"color": Color("#3388ff"),
	},
	"neutral": {
		"id": "neutral",
		"display_name": "NEUTRAL",
		"color": Color("#ffaa00"),
	},
}


# Returns the registry dictionary for `id`, or UNKNOWN if not found. Callers
# read `.color` / `.display_name` from the result.
#
# Named `info` rather than `get` because GDScript reserves `get` (Object.get
# shadow) at the class-symbol level — `Factions.get(...)` won't resolve as a
# static method call.
static func info(id: String) -> Dictionary:
	return REGISTRY.get(id, UNKNOWN)


static func color_for(id: String) -> Color:
	return info(id).color
