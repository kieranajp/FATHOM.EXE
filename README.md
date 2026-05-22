# FATHOM.EXE — Godot Branch

Orphan branch for the Godot rebuild. The JS prototype is frozen on `main` and serves as the playable reference spec.

The rebuild is executed by parallel agents working in worktrees, each picking up a single GitHub issue. Workflow lives in [`docs/AGENTS.md`](docs/AGENTS.md).

## Documents

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — shared contract. Every agent reads this first.
- [`docs/FOUNDATIONS.md`](docs/FOUNDATIONS.md) — supervised first-phase scope.
- [`docs/AGENTS.md`](docs/AGENTS.md) — worktree + ticket workflow.
- [`docs/DESIGN-NOTES.md`](docs/DESIGN-NOTES.md) — design intent + post-parity roadmap.

## Stack

- **Godot 4.7-beta3** (released 22 May 2026). HDR output, AreaLight3D, regression-focused beta.
- **GDScript** primary. No C#.
- Desktop target. 120 Hz capable. Vsync on by default.
- Right-handed coords (Godot default). The JS convention of `+Z north` maps to Godot `-Z forward`.

## Running

After foundations land:

```sh
godot --path .
```

Or open `project.godot` in the Godot editor.

## Parity goal

Get to feature parity with the JS prototype on `main`, then start building beyond it (crew, reputation, contraband, glitch galleon). See `docs/DESIGN-NOTES.md`.
