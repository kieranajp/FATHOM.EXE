# AGENTS — Worktree & Ticket Workflow

How parallel agents work on this project. Model-agnostic — Claude, Gemini, anything that can read a markdown ticket and run a CLI is fine.

## Branch model

- `main` — frozen JS reference prototype.
- `godot` — orphan branch. The Godot rebuild. All tickets target this.
- `godot-T<NN>-<slug>` — one branch per ticket, branched from `godot`. PR target = `godot`.

## Worktree pattern

Run each ticket in its own worktree so agents don't trip over each other:

```sh
# from the repo root
git worktree add ../FATHOM.EXE-T03 -b godot-T03-port-and-dock godot
cd ../FATHOM.EXE-T03
# agent runs here
```

When done:

```sh
git push -u origin godot-T03-port-and-dock
gh pr create --base godot --fill --body "Closes #<issue-number>"
# after merge:
cd ../FATHOM.EXE
git worktree remove ../FATHOM.EXE-T03
```

## Reading order for any agent picking up a ticket

1. `docs/ARCHITECTURE.md` — the shared contract. **The agent must follow it.**
2. `docs/DESIGN-NOTES.md` — design intent, post-parity roadmap.
3. The GitHub issue body — scope, acceptance criteria, dependencies.
4. Existing code on the `godot` branch — particularly any system the ticket integrates with.

The JS prototype on `main` is a **playable reference spec**, not a port target. Read its tests (`game.test.js`) for mechanical rules. Do not transliterate code.

## Rules of engagement

- **Honour the contract.** Don't invent new autoloads, signals, or resource fields. If you need one, comment on the issue and pause.
- **Numbers go in `.tres` files** (see ARCHITECTURE.md "Tuning"). Magic numbers in scripts are a code-review bug.
- **One signal, one source.** If you emit `ship_sunk`, only do it from where the ship actually sinks. Don't double-fire from a wrapper.
- **Wave height has one definition** in `Ocean.get_wave_height`. Don't copy the formula anywhere else.
- **Stub forward, don't block.** If a system you need is owned by a not-yet-merged ticket, stub the call site (use the autoload's declared API) and proceed.
- **No DOM-style coupling.** UI never reaches into game systems directly. It listens on `EventBus` and reads from `GameState` / `World`.
- **Don't touch other tickets' files.** If you must (e.g. extending a Resource schema), call it out in the PR and expect a conflict.

## What a good ticket PR looks like

- Title: `T<NN>: <one-line summary>`
- Body: `Closes #<N>`, a brief description of what changed, and any deviations from the issue.
- Diff scoped to the ticket — no drive-by cleanups in unrelated files.
- All new scripts have `class_name` if they're reusable.
- All new tunable numbers in a `.tres` under `data/tuning/`.
- `godot --path . --headless --quit` exits 0.
- Smoke-run in editor shows no errors.
- New systems hook the right signals on EventBus.

## Conflict resolution

If two parallel tickets need to extend the same file (e.g. both add fields to `PlayerState`):
- The first PR to merge wins.
- The second rebases on `godot` and reconciles.
- If reconciliation is non-trivial, comment on both issues and escalate to the user.

## Architecture changes

`docs/ARCHITECTURE.md` is the contract. Changing it mid-flight risks all in-flight tickets.

- Proposed change → comment on a tracking issue → user approves → single dedicated PR that updates only the doc → all open ticket branches rebase.
- Never sneak a contract change into a feature PR.

## CI / quality bars (future)

Not in place yet. When set up, expect:
- Headless boot check
- gdformat / static check
- Smoke run that loads each scene root once

Until then, manual smoke run per PR.
