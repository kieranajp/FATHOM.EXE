# Tunings — global autoload that lazily caches each tuning .tres resource by name.
# Exposes typed getters for complete editor autocompletion and type safety.
extends Node

var _cache: Dictionary = {}

func get_tuning(name: String) -> Resource:
	if _cache.has(name):
		return _cache[name]
	var path := "res://data/tuning/" + name + ".tres"
	if ResourceLoader.exists(path):
		var res := load(path)
		_cache[name] = res
		return res
	push_warning("Tunings: tuning file '%s' not found at %s" % [name, path])
	return null

var combat: CombatTuning:
	get: return get_tuning("combat") as CombatTuning

var combat_visuals: CombatVisualsTuning:
	get: return get_tuning("combat_visuals") as CombatVisualsTuning

var sailing: SailingTuning:
	get: return get_tuning("sailing") as SailingTuning

var camera: CameraTuning:
	get: return get_tuning("camera") as CameraTuning

var dock: DockTuning:
	get: return get_tuning("dock") as DockTuning

var render: RenderTuning:
	get: return get_tuning("render") as RenderTuning

var audio: AudioTuning:
	get: return get_tuning("audio") as AudioTuning

var economy: EconomyTuning:
	get: return get_tuning("economy") as EconomyTuning

var time: TimeTuning:
	get: return get_tuning("time") as TimeTuning

var travel: TravelTuning:
	get: return get_tuning("travel") as TravelTuning

var wind: WindTuning:
	get: return get_tuning("wind") as WindTuning

var map: MapTuning:
	get: return get_tuning("map") as MapTuning

var tavern: TavernTuning:
	get: return get_tuning("tavern") as TavernTuning

var respawn: RespawnTuning:
	get: return get_tuning("respawn") as RespawnTuning

var world: WorldTuning:
	get: return get_tuning("world") as WorldTuning

var hud: HudTuning:
	get: return get_tuning("hud") as HudTuning
