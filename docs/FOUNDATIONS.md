# FOUNDATIONS — Supervised First Phase

One agent. Human in the loop. Goal: a bootable Godot project with the full architecture skeleton in place, so subsequent parallel tickets can fire safely.

**Reading order before starting:** `docs/ARCHITECTURE.md` (the contract), this file, then `docs/DESIGN-NOTES.md` for design intent.

## Deliverable

A `godot` branch HEAD where:

1. `godot --path . --headless --quit` exits 0 with no errors or warnings.
2. `godot --path .` opens the editor, loads `Main.tscn`, and shows the smoke scene without errors.
3. Pressing F5 (Run Project) launches the game window, displays the smoke scene, exits cleanly with Escape.
4. All autoloads from ARCHITECTURE.md are registered and have a `.gd` file (stubs allowed, but with declared public API per the contract).
5. All Resource classes from ARCHITECTURE.md exist with declared `@export` fields.
6. EventBus declares every signal listed in ARCHITECTURE.md.
7. At least one sample `.tres` exists per Resource type, validating that the schemas compile and instantiate.
8. README "Running" section is verified.

## Scope (what to build)

### 1. Project file

`project.godot` with:
- Application name `FATHOM.EXE`
- Main scene `res://scenes/Main.tscn`
- Rendering method `forward_plus` (HDR + bloom needs it)
- Window size 1920×1080, resizable
- Vsync on
- Max FPS 120 (`application/run/max_fps = 120`)
- Forward+ HDR enabled (`rendering/viewport/hdr_2d = true` if applicable; configure WorldEnvironment for 3D HDR)
- Input map (see below)

### 2. Input map

| Action | Key | Notes |
|---|---|---|
| `sail_up` | W | hold-or-tap accepted (sail level rises while held) |
| `sail_down` | S | |
| `steer_port` | A | |
| `steer_starboard` | D | |
| `fire_port` | Q | |
| `fire_starboard` | E | |
| `aim` | Space | hold |
| `ammo_ball` | 1 | |
| `ammo_chain` | 2 | |
| `ammo_grape` | 3 | |
| `dock` | F | |
| `map` | M | toggle |
| `inventory` | I | toggle |
| `dev_menu` | Backquote (\`) | toggle |
| `quit` | Escape | only for foundations smoke scene; later this opens a menu |
| `aim_elevate_modifier` | Shift | combined with aim drag |

Mouse buttons: left click + right click + drag handled in scripts, not Input Map.

### 3. Autoloads

Register all eight in `project.godot`:
```
[autoload]
EventBus="*res://scripts/autoload/event_bus.gd"
GameState="*res://scripts/autoload/game_state.gd"
World="*res://scripts/autoload/world.gd"
Economy="*res://scripts/autoload/economy.gd"
WindSystem="*res://scripts/autoload/wind_system.gd"
TimeSystem="*res://scripts/autoload/time_system.gd"
AudioBus="*res://scripts/autoload/audio_bus.gd"
Persistence="*res://scripts/autoload/persistence.gd"
```

Each file:
- `extends Node`
- Declares the public API surface in ARCHITECTURE.md, even if function bodies are `pass` or `push_warning("stub")`
- Has a header comment naming the ticket(s) expected to fill it in

`EventBus.gd` is the exception: declare every signal from the vocabulary. No stubs.

### 4. Resource classes

Under `scripts/resources/`, write each `class_name` file from ARCHITECTURE.md with `@export` fields exactly matching the schema. Defaults are fine.

### 5. Sample data resources

To prove the schemas compile, create one of each:
- `data/ships/dinghy.tres` — stats from JS `SHIP_CLASSES.dinghy`
- `data/commodities/rum.tres` — base price 20, short code `RUM`
- `data/archipelagos/pirates_cradle.tres` — sector `SEC A-1`, colour `#ffcc00`, port list `["port_royal"]`
- `data/ports/port_royal.tres` — position `Vector3(0, 0, 180)`, size 28, archipelago `pirates_cradle`, faction `neutral`, plus the JS base prices
- `data/tuning/combat.tres` — placeholder file with one `@export` field (`ball_damage = 25`) just to validate Tuning resource works

### 6. Shader stubs

Create three empty/minimal files so subsequent tickets have somewhere to land changes:
- `assets/shaders/wireframe.gdshader` — minimal shader that draws the mesh as unlit lines (use `fill = wireframe` on the material if simpler, or a proper edge shader; either acceptable for foundations)
- `assets/shaders/crt_post.gdshader` — pass-through (no-op) full-screen shader
- `assets/shaders/glitch.gdshader` — empty stub with a comment "T-glitch ticket fills this in"

### 7. Scenes

#### `scenes/Main.tscn`
- Root `Node`
- A `Node` child called `SceneRoot` (placeholder for current loaded scene)
- A `_ready()` script that loads `OpenSea.tscn` as a child of `SceneRoot`. (For foundations, OpenSea is the smoke scene.)
- Also handles Escape → quit, for now.

#### `scenes/OpenSea.tscn` (smoke version)
- `Node3D` root
- `Camera3D` positioned at `Vector3(0, 5, 10)` looking at origin
- `MeshInstance3D` with a `BoxMesh` at origin, scaled `Vector3(2, 1, 4)`, using a `ShaderMaterial` with `wireframe.gdshader` — this is the "ship" placeholder
- `DirectionalLight3D` (off-camera angle)
- `WorldEnvironment` with HDR tonemap (Filmic or AgX), bloom subtle
- A `Label3D` reading "FATHOM.EXE foundations smoke scene" floating above the cube

#### `scenes/HUD.tscn`
- Empty `CanvasLayer` with a single `Label` reading "HUD pending" in the corner. Just to prove the layer works.

#### Empty placeholder scenes (just root nodes + a TODO label):
- `scenes/Port.tscn`
- `scenes/Map.tscn`
- `scenes/Travel.tscn`
- `scenes/ui/DockMenu.tscn`
- `scenes/ui/Market.tscn`
- `scenes/ui/Tavern.tscn`
- `scenes/ui/Shipyard.tscn`

### 8. Verification

Before opening a PR:
- `godot --path . --headless --quit` exits 0
- Run Project → smoke scene renders the wireframe cube, no console errors
- Editor → "Project → Project Settings → Autoload" shows all eight
- Each `.tres` sample opens in the inspector and shows the expected fields

## Out of scope (these are future tickets, do not implement)

- Ocean wave grid rendering (T01)
- Player ship physics (T02)
- Any combat
- Any UI beyond the smoke labels
- Any audio
- Any save/load logic
- Any economy logic
- Any AI

## Out of scope but tempting

Resist:
- Pre-populating `data/` with all JS ports and ships. **One sample per resource type, no more.** Subsequent tickets own their data.
- "Just sketching" the ocean shader. **It's its own ticket.**
- Writing helper utility scripts that "feel useful". If it's not on the deliverable list above, it doesn't go in.

## On completion

- Open a PR against `godot` branch.
- Title: `foundations: bootable skeleton + architecture stubs`
- Closes issue `#1` (foundations).
- Mention any deviations from ARCHITECTURE.md that surfaced. If anything required changing the contract, that must be a separate commit with explicit user sign-off.
