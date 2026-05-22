# ARCHITECTURE — The Shared Contract

This is the contract every agent honours. Do not change it without explicit user approval. If you find yourself needing to, **stop and ask** rather than silently extending it — silent extensions cause merge collisions across parallel worktrees.

## Tech stack

- **Godot 4.7-beta3** (or later 4.7.x beta/stable as of pickup date).
- **GDScript** — no C#. No GDExtension unless a ticket explicitly calls for it.
- Right-handed coordinate system (Godot default). `+X` right, `+Y` up, `-Z` forward.
  - The JS prototype uses left-handed with `+Z` north. Treat JS `+Z` as Godot `-Z`. Document any other axis conversions in code comments.
- Desktop target. 120 Hz capable. Vsync on by default. HDR enabled in Project Settings.

## Folder layout

```
project.godot
.godot/                  # editor cache, gitignored
assets/
  shaders/
    wireframe.gdshader   # base wireframe-on-mesh shader
    crt_post.gdshader    # full-screen CRT effect
    glitch.gdshader      # stub for legendary galleon (post-parity)
  audio/
data/                    # static design resources (.tres)
  ships/
  ports/
  archipelagos/
  commodities/
  rumors/
  tuning/                # per-system tuning (combat, sailing, wind, etc.)
scenes/
  Main.tscn              # entry point, autoload host
  OpenSea.tscn           # gameplay scene
  Port.tscn              # docked scene
  Map.tscn               # strategic map overlay
  Travel.tscn            # fast travel sequence
  HUD.tscn               # CanvasLayer overlay
  ui/
    DockMenu.tscn
    Market.tscn
    Tavern.tscn
    Shipyard.tscn
scripts/
  autoload/              # singletons; see Autoload Registry below
  resources/             # extends Resource class definitions
  systems/               # non-autoload systems (ocean, ai_steering, etc.)
  player/
  enemies/
  combat/
  ui/
docs/
  ARCHITECTURE.md        # this file
  FOUNDATIONS.md
  AGENTS.md
  DESIGN-NOTES.md
```

## Autoload registry

Each autoload is one `.gd` file in `scripts/autoload/`. Register all of them in `project.godot` from the foundations phase, even if some are empty stubs.

| Autoload | Purpose |
|---|---|
| `EventBus` | Signal dispatch hub. Systems emit, others listen. Decouples cross-system calls. |
| `GameState` | Active run state: ship, cargo, gold, factions, officers, travel count. Persisted. |
| `World` | Transient scene state: enemies, projectiles, particles, debris. Not persisted. |
| `Economy` | Port price calculation. Reads `GameState.travel_count` + port `base_prices`. |
| `WindSystem` | Wind angle + speed + drift. Globally readable. |
| `TimeSystem` | In-world clock. Emits `hour_passed`, `day_passed`. Pauses when docked. |
| `AudioBus` | All sound playback. Wraps pool of `AudioStreamPlayer`. |
| `Persistence` | Save/load to `user://save.json`. Versioned schema. |

### Autoload public APIs (minimum surface)

```gdscript
# EventBus.gd — no logic, just signals
# (See Signal Vocabulary below.)

# GameState.gd
var ship: PlayerState         # ship class, cargo, gold, ammo, health
var current_archipelago_id: String
var current_port_id: String   # empty when at sea
var travel_count: int
var visited_archipelagos: Array[String]
var port_ship_stock: Dictionary  # port_id -> { class_id: int }
var factions: Dictionary         # faction_id -> FactionState (post-parity)
var crew: CrewState              # post-parity
var officers: Array[Officer]     # post-parity
func reset_new_game() -> void

# World.gd
var enemies: Array[EnemyShip]
var projectiles: Array            # active projectiles (Dictionary form for speed)
var particles: Array              # sea spray
var debris: Array
var splashes: Array
func clear() -> void               # called on scene change

# Economy.gd
func calculate_port_prices(port: PortDef) -> Dictionary

# WindSystem.gd
var angle: float                   # radians
var speed: float                   # knots
var target_angle: float
var change_timer: float
func update(delta: float) -> void  # called by OpenSea each frame
func sailing_efficiency(player_yaw: float) -> float

# TimeSystem.gd
var day: int
var hour: int
var is_paused: bool                # true while docked
func tick(delta: float) -> void

# AudioBus.gd
func play_beep(freq: float, duration: float) -> void
func play_shoot() -> void
func play_explosion() -> void
func play_splash() -> void
func play_dock_jingle() -> void
func update_wind_frequency(intensity: float) -> void
# Synth implementation is the audio ticket's problem; this is the contract.

# Persistence.gd
func save() -> void
func load() -> bool                # true if save existed and loaded ok
func has_save() -> bool
```

## EventBus signal vocabulary

The full list. Tickets may not invent new signals without ARCHITECTURE.md update. If you need one, **note it in the PR and ask**.

```gdscript
# scripts/autoload/EventBus.gd
extends Node

# Combat
signal cannon_fired(side: String, ammo_type: String, ship: Node)
signal projectile_spawned(projectile: Dictionary)
signal projectile_hit(victim: Node, damage: float, ammo_type: String, attacker: Node)
signal projectile_splashed(x: float, z: float)
signal ship_damaged(ship: Node, amount: float, ammo_type: String)
signal ship_sunk(ship: Node, sunk_by: Node)
signal player_death

# Navigation
signal port_proximity_entered(port: PortDef)
signal port_proximity_exited
signal port_docked(port: PortDef)
signal port_undocked
signal archipelago_changed(archipelago: ArchipelagoDef)
signal travel_started(target: ArchipelagoDef)
signal travel_completed(target: ArchipelagoDef)
signal island_collided(port: PortDef, ship: Node)

# Economy
signal cargo_bought(item: String, amount: int, price: int)
signal cargo_sold(item: String, amount: int, price: int)
signal ship_purchased(class_id: String)
signal market_transaction_failed(reason: String)

# Time
signal hour_passed(day: int, hour: int)
signal day_passed(day: int)

# Authority / alerts
signal no_fire_zone_violated(violator: Node, near_port: PortDef)
signal enforcer_alert_started
signal enforcer_alert_ended

# UI
signal hud_message(text: String, severity: String)  # severity: info, warning, alert
signal map_toggled(open: bool)
signal inventory_toggled(open: bool)
signal dev_menu_toggled(open: bool)

# Post-parity (declared now, used later)
signal morale_changed(delta: float, reason: String)
signal officer_killed(officer: Officer)
signal reputation_changed(faction: String, delta: float)
signal contraband_detected(item: String, port: PortDef)
```

## The wave-height contract

**Single source of truth.** Living on `Ocean` node in `OpenSea.tscn`:

```gdscript
func get_wave_height(x: float, z: float) -> float
```

Anything that needs sea elevation — ships, particles, splashes, projectiles bobbing on water, debris floats — calls this. **No copies allowed anywhere else in the codebase.** Violating this is a merge-blocker.

If `Ocean` is not in the active scene (e.g. inside `Port.tscn`), wave height is undefined; gameplay there doesn't need it.

## Resource schemas

All `extends Resource` classes live under `scripts/resources/`. Each exports fields as `@export var`. Foundations creates schemas with sensible defaults; data tickets populate `.tres` files.

```gdscript
# scripts/resources/ship_class.gd
class_name ShipClass extends Resource
@export var id: String
@export var display_name: String
@export var cost: int = 0
@export var max_health: float = 100.0
@export var base_max_speed: float = 6.0
@export var max_cargo: int = 100
@export var firepower: int = 1
@export var hit_radius: float = 4.0
@export var hit_height: float = 6.0
@export var mesh_scene: PackedScene             # optional; if null, use placeholder
```

```gdscript
# scripts/resources/port_def.gd
class_name PortDef extends Resource
@export var id: String
@export var display_name: String
@export var position: Vector3
@export var size: float = 25.0
@export var height: float = 15.0
@export var archipelago_id: String
@export var faction_id: String                  # post-parity meaningful; default "neutral"
@export var color: Color
@export var base_prices: Dictionary             # item_id -> { "buy": int, "sell": int, "is_producer": bool, "is_consumer": bool }
```

```gdscript
# scripts/resources/archipelago_def.gd
class_name ArchipelagoDef extends Resource
@export var id: String
@export var display_name: String
@export var sector: String                      # e.g. "SEC A-1"
@export var color: Color
@export var port_ids: Array[String]
```

```gdscript
# scripts/resources/commodity.gd
class_name Commodity extends Resource
@export var id: String
@export var display_name: String
@export var short_code: String                  # 3-letter HUD code
@export var base_price: int
@export var contraband_in: Array[String]        # faction ids; post-parity
```

```gdscript
# scripts/resources/officer.gd  (post-parity)
class_name Officer extends Resource
@export var id: String
@export var display_name: String
@export var role: String                        # bosun, master_gunner, sailing_master, surgeon
@export var alive: bool = true
@export var passive_bonus: Dictionary           # stat key -> multiplier or delta
```

```gdscript
# scripts/resources/crew_state.gd  (post-parity)
class_name CrewState extends Resource
@export var gunners: int = 0
@export var sailors: int = 0
@export var riggers: int = 0
@export var morale: float = 50.0                # 0-100
@export var food_quality: float = 100.0
@export var days_at_sea: int = 0
```

```gdscript
# scripts/resources/faction_state.gd  (post-parity)
class_name FactionState extends Resource
@export var id: String
@export var display_name: String
@export var color: Color
@export var player_reputation: float = 0.0      # -100..100
```

```gdscript
# scripts/resources/player_state.gd
class_name PlayerState extends Resource
@export var ship_class_id: String = "dinghy"
@export var ship_name: String = "The Salty Seagull"
@export var gold: int = 150
@export var health: float = 100.0
@export var cargo: Dictionary = {}              # item_id -> int
@export var ammo: Dictionary = { "ball": 10, "chain": 0, "grape": 0 }
@export var active_ammo: String = "ball"
@export var sail_level: float = 2.0             # 0..4
```

```gdscript
# scripts/resources/tuning.gd
class_name Tuning extends Resource
# Each tuning .tres is a flat bag of numbers per system.
# E.g. data/tuning/combat.tres: ball_damage, chain_damage, grape_damage,
# ball_life, chain_life, grape_life, reload_seconds, pellet_count, …
```

## Tuning

**Every numeric constant lives in a `.tres` Tuning resource.** Hardcoded magic numbers in scripts (other than 0, 1, and obviously-constant maths) are a code-review bug. Lets the user tweak balance in the editor without redeploying agents.

Suggested tuning files:
- `data/tuning/combat.tres` — damage, lifespans, reload, pellet count
- `data/tuning/sailing.tres` — sail efficiency curve params, turn factor, drag
- `data/tuning/wind.tres` — change cadence min/max, lerp factor
- `data/tuning/camera.tres` — chase distance multiplier, pitch, ease rate
- `data/tuning/economy.tres` — producer/consumer multipliers, fluctuation amplitude
- `data/tuning/world.tres` — particle counts, draw distances, ocean grid params

## Rendering decisions

- **Wireframe via shader on `MeshInstance3D`**, not `ImmediateMesh`. This is non-negotiable — it's what makes the legendary galleon's glitch shader possible later. Single shared material `wireframe.gdshader`; per-instance shader params for faction colour.
- **Ocean grid renders via `ImmediateMesh` in `Ocean` node** (no geometry interaction needed — it's pure visual).
- **`WorldEnvironment`** with bloom + tonemap, HDR enabled.
- **Full-screen post-process** via `CanvasLayer` + `ColorRect` + `crt_post.gdshader`.
- **Glow colour by faction** passed as shader uniform: green (player), red (pirate), blue (authority), amber (neutral).

## Save format

`user://save.json` — JSON for now. Resources serialised by `id`, not by reference. Schema versioned:

```json
{
  "save_version": 1,
  "day": 1,
  "hour": 8,
  "player_state": { ... },
  "current_archipelago_id": "pirates_cradle",
  "current_port_id": "",
  "visited_archipelagos": ["pirates_cradle"],
  "port_ship_stock": { "port_royal": { "schooner": 1, "sloop": 0 } },
  "travel_count": 0,
  "factions": {},
  "crew": {},
  "officers": []
}
```

Save on `port_docked`. Load on Main scene boot if `Persistence.has_save()`.

## Naming conventions

- Files: `snake_case.gd`, scenes `PascalCase.tscn`.
- Classes: `class_name PascalCase`.
- Functions, variables: `snake_case`.
- Signals: `snake_case`, **past tense or imperative** — `ship_sunk` not `sink_ship`.
- Constants: `SCREAMING_SNAKE_CASE`.
- Resource `id` fields: `snake_case` strings.
- Branch names: `godot-T<NN>-short-slug` (e.g. `godot-T03-port-and-dock`).
- PR target: `godot` branch, never `main`.

## Coordinate conversions from JS reference

- JS yaw is rotation about Y, with `0` pointing along `+Z` (north). Godot yaw conventionally `0` points along `-Z` (forward). **Add `PI` to JS yaw values when porting**, or rotate the entire world frame — pick one and document.
- JS broadside: port = `yaw - PI/2`, starboard = `yaw + PI/2`. Same in Godot.
- JS wave equation: `sin(x*0.05 + t*1.5) * cos(z*0.05 + t*1.2) * 1.6 + sin(z*0.12 - t*2.0) * 0.5`. Reproduce in `Ocean.get_wave_height`. **Identical formula** unless tuning ticket changes it explicitly.

## Things that are NOT in this contract (and shouldn't be assumed)

- Specific node hierarchies inside scenes — tickets own their scenes.
- Specific Control layout for UI — UI tickets pick layouts.
- Mesh geometry — ship/port models are owned by aesthetics tickets.
- Game balance numbers — owned by tuning `.tres` files.
- Audio synth implementation — owned by the audio ticket.
