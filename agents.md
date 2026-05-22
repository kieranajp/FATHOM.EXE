# FATHOM.EXE - AI Agent Handbook

This guide details architecture decisions, spatial math, and environmental state hooks that are critical for AI development but not immediately obvious from code syntax.

---

### 1. Spatial Math & Coordinate System
*   **Coordinate Spaces**: Left-handed system. $+X$ represents East, $+Z$ represents North, $+Y$ represents altitude (upward).
*   **Wave Alignment**: `getWaveHeight(x, z)` returns the sea-surface elevation at any coordinate using nested sines. This is the single source of truth for vessel buoyancy, pitch/roll tilt, and particle bobbing.
*   **Broadside Angles**: Port is defined as $\text{yaw} - \frac{\pi}{2}$, Starboard as $\text{yaw} + \frac{\pi}{2}$. Aiming offsets (`aimYawOffset`) are added to these angles.

### 2. Execution & Global Namespaces
*   **Global Singletons**: The core modules `Engine3D` (renderer), `AudioEngine` (Web Audio synths), `Models3D` (procedural assets), and `Game` are globally scoped singletons.
*   **Render Loop**: `Game.update(dt)` runs under `requestAnimationFrame` on a continuous tick. Do not block this thread or introduce synchronous delays.

### 3. Modality & State Machine
*   **UI Modals**: `this.isDocked`, `this.isTraveling`, and HTML modal classes (`.hidden`) act as state gates. Firing broadsides or movement updates must check these flags to prevent phantom physics or controls.
*   **Dev Menu Key**: Backtick (`` ` ``) toggles diagnostic modal, closes active overlays, and sets keyboard capture state to prevent inputs leaking into vessel steering.

### 4. Headless Testing Environment
*   **Vitest Environment**: Unit tests run in headless Node.js. Browser globals (`document`, `window`, `AudioEngine`, `Engine3D`) are stubbed in `game.test.js` under `beforeEach`. 
*   **Physics Easing Snapping**: When testing camera mechanics or movement, run `Game.update(10.0)` multiple times to fully snap exponential easings (`1 - Math.exp(-k * dt)`) and verify stable targets.
