# FATHOM.EXE

> A retro-cybernetic, wireframe 3D sailing RPG built with vanilla HTML5, CSS3, and JavaScript. Navigate shifting winds, trade commodities, and engage in real-time tactical broadside battles in a sleek, vector-rendered ocean world.

---

## 🌊 Core Features

*   **Custom 3D Wireframe Vector Engine**: A high-performance, custom rendering pipeline that maps 3D objects, wave heights, and coordinate spaces into a gorgeous, CRT-glowing vector aesthetic.
*   **Physics-Based Sailing & Wind Mechanics**: Real tacking, drag, and sail efficiency calculations. Position your sails correctly relative to the wind for maximum velocity, or get caught "in irons" if sailing directly upwind.
*   **Tactical Naval Broadside Combat**: Fire standard balls for hull damage, chain shot to cripple enemy speed, or grapeshot buckshot clouds to shred enemy crew. Features dynamic ammunition consumption based on your ship class's firepower.
*   **Dynamic Chase Camera**: Fluid, spring-lagged chase camera that dynamically scales its orbit radius and vertical look-at height depending on the physical bounds of your vessel.
*   **Economic Trading System**: Purchase and sell commodities (Food, Textiles, Spices, Rum, Relics) across various ports across three main archipelagos. Watch for producer (`PROD`) and consumer (`CONS`) price fluctuations!
*   **Developer Diagnostics Overlay**: Tap backtick (`` ` ``) to trigger a secret retro diagnostic modal to inspect live global prices, swap ship hulls instantly, modify ammunition stocks, or spawn target practice hostiles.

---

## 🎮 How to Play

### Sailing & Steering
*   `W` - Deploy Sails (Accelerate)
*   `S` - Fur Sails (Decelerate)
*   `A` / `D` - Turn Rudder Port / Starboard

### Tactical Combat
*   `Q` or Left-Click while aiming Port - Fire Port Broadside
*   `E` or Left-Click while aiming Starboard - Fire Starboard Broadside
*   `Right-Click & Drag` - Free Camera Orbit
*   `Hold Space` - Activate Aiming Mode (Camera focuses to the flank, allowing mouse aiming with the firing arc overlay)

### Interface & HUD
*   `M` - Toggle Sector Chart (Map)
*   `I` - Open Cargo Hold & Inventory
*   `F` - Dock at Port (when close to a port buoy)
*   `1`, `2`, `3` - Switch active ammunition type (Ball, Chain, Grape)
*   `` ` `` (Backtick) - Secret Developer Diagnostics overlay

---

## 🛠️ Installation & Development

### Prerequisite
Make sure you have Node.js installed on your machine.

1. Clone the repository:
   ```bash
   git clone https://github.com/kieranajp/FATHOM.EXE.git
   cd FATHOM.EXE
   ```

2. Install dependencies (Vitest for unit testing):
   ```bash
   npm install
   ```

3. Run the game locally using a dev server or by opening `index.html` directly:
   ```bash
   npm run dev # or launch any local server (e.g. Live Server)
   ```

4. Run the comprehensive unit test suite:
   ```bash
   npm test
   ```

---

## 📝 License
This project is open-source and licensed under the ISC License.
