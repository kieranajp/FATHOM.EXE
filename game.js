/**
 * Vector Buccaneer - Main Game Controller
 * Manages the game loop, physics updates, input listeners, HUD rendering, and docking states.
 */

const Game = {
    canvas: null,
    ctx: null,
    lastTime: 0,
    time: 0,
    isDocked: false,
    activePort: null,
    currentDockView: 'menu', // 'menu' = main dock menu, 'market' = merchant market view
    depletedShipStock: {},
    marketTravelCount: 0,

    // Keyboard state
    keys: {
        w: false, a: false, s: false, d: false,
        q: false, e: false, space: false
    },

    // Mouse / Camera Orbit State
    mouse: {
        isDragging: false,
        isAiming: false,
        startX: 0,
        startY: 0,
        yaw: 0,   // Relative offset from ship's yaw (radians)
        pitch: 0  // Relative offset from default pitch (radians)
    },

    // Wind State
    wind: {
        speed: 12,        // Wind speed in knots
        angle: 0.8,       // Heading in radians (approx NE)
        targetAngle: 0.8,
        changeTimer: 10   // Seconds before wind shifts
    },

    // Faction Color System Registry
    FACTIONS: {
        player: {
            name: "Merchant",
            color: "#33ff33",
            colorRgb: "rgba(51, 255, 51, 0.3)",
            textClass: "neon-text-green",
            barClass: "bar-green",
            themeClass: "theme-green"
        },
        pirate: {
            name: "Pirate Raider",
            color: "#ff5555",
            colorRgb: "rgba(255, 85, 85, 0.3)",
            textClass: "neon-text-red",
            barClass: "bar-red",
            themeClass: "theme-red"
        },
        authority: {
            name: "Port Authority",
            color: "#3388ff",
            colorRgb: "rgba(51, 136, 255, 0.3)",
            textClass: "neon-text-blue",
            barClass: "bar-blue",
            themeClass: "theme-blue"
        },
        neutral: {
            name: "Neutral Trade",
            color: "#ffaa00",
            colorRgb: "rgba(255, 170, 0, 0.3)",
            textClass: "neon-text-amber",
            barClass: "bar-amber",
            themeClass: "theme-amber"
        }
    },

    // Ship Class Definitions (for dynamic health, speeds, cargo, hitboxes, and costs)
    SHIP_CLASSES: {
        dinghy: {
            name: "Dinghy",
            cost: 0,
            maxHealth: 100,
            baseMaxSpeed: 6.5,
            maxCargo: 100,
            firepower: 1,
            hitRadius: 4.0,
            hitHeight: 6.0
        },
        schooner: {
            name: "Schooner",
            cost: 250,
            maxHealth: 120,
            baseMaxSpeed: 7.2,
            maxCargo: 180,
            firepower: 1,
            hitRadius: 5.0,
            hitHeight: 7.0
        },
        sloop: {
            name: "Sloop",
            cost: 500,
            maxHealth: 150,
            baseMaxSpeed: 7.8,
            maxCargo: 120,
            firepower: 2,
            hitRadius: 6.0,
            hitHeight: 8.0
        },
        clipper: {
            name: "Clipper",
            cost: 1100,
            maxHealth: 180,
            baseMaxSpeed: 8.5,
            maxCargo: 280,
            firepower: 1,
            hitRadius: 7.0,
            hitHeight: 9.0
        },
        brigantine: {
            name: "Brigantine",
            cost: 1400,
            maxHealth: 220,
            baseMaxSpeed: 6.0,
            maxCargo: 300,
            firepower: 3,
            hitRadius: 7.5,
            hitHeight: 10.0
        },
        frigate: {
            name: "Frigate",
            cost: 2000,
            maxHealth: 300,
            baseMaxSpeed: 6.8,
            maxCargo: 180,
            firepower: 4,
            hitRadius: 8.0,
            hitHeight: 11.0
        },
        galleon: {
            name: "Galleon",
            cost: 2800,
            maxHealth: 380,
            baseMaxSpeed: 4.2,
            maxCargo: 450,
            firepower: 4,
            hitRadius: 9.0,
            hitHeight: 12.0
        },
        carrack: {
            name: "Carrack",
            cost: 3500,
            maxHealth: 450,
            baseMaxSpeed: 3.8,
            maxCargo: 550,
            firepower: 3,
            hitRadius: 9.5,
            hitHeight: 13.0
        },
        manofwar: {
            name: "Man-of-War",
            cost: 5500,
            maxHealth: 550,
            baseMaxSpeed: 4.8,
            maxCargo: 650,
            firepower: 6,
            hitRadius: 10.5,
            hitHeight: 14.0
        }
    },

    // Player Ship State
    player: {
        x: 0,
        y: 0,
        z: 0,
        yaw: 0,           // Heading (yaw) in radians
        pitch: 0,         // Pitch from waves
        roll: 0,          // Roll from waves + turn momentum
        speed: 0,
        baseMaxSpeed: 6.5, // Absolute top speed of Dinghy
        sailLevel: 2,     // 0 = Anchored, 1 = 25%, 2 = 50%, 3 = 75%, 4 = Full Sails
        rudder: 0,        // Steering input (-1 to 1)
        cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0, coffee: 0, cocoa: 0, textiles: 0, wood: 0 },
        maxCargo: 100,     // Starting cargo hold limit
        gold: 150,
        shipClass: 'dinghy',
        shipName: 'The Salty Seagull',
        health: 100,
        maxHealth: 100,
        reloadPort: 0,
        reloadStbd: 0,
        ammo: { ball: 10, chain: 0, grape: 0 },
        activeAmmo: 'ball',
        speedDebuffTimer: 0,
        aimSide: 'starboard',
        aimYawOffset: 0,
        aimRange: 120,
        aimHeight: 0,
        collisionImmunityTimer: 0
    },

    // World Registry (Archipelagos, Econ Pricing, and Tavern Rumors)
    ARCHIPELAGOS: [
        {
            name: "PIRATE'S CRADLE",
            sector: "SEC A-1",
            color: "#ffcc00",
            ports: [
                {
                    name: 'Port Royal',
                    x: 0, y: 0, z: 180,
                    size: 28, height: 18, model: null,
                    lighthousePos: { x: 0, y: 18, z: 0 },
                    color: '#ffcc00',
                    basePrices: {
                        rum: { buy: 20, sell: 20, isProducer: true },
                        tobacco: { buy: 25, sell: 25, isConsumer: true },
                        wood: { buy: 12, sell: 12, isProducer: true },
                        sugar: { buy: 15, sell: 15 },
                        coffee: { buy: 22, sell: 22 }
                    }
                },
                {
                    name: 'Nassau',
                    x: -180, y: 0, z: -60,
                    size: 22, height: 14, model: null,
                    lighthousePos: { x: 0, y: 14, z: 0 },
                    color: '#ff3366',
                    basePrices: {
                        rum: { buy: 20, sell: 20, isProducer: true },
                        tobacco: { buy: 25, sell: 25, isConsumer: true },
                        wood: { buy: 12, sell: 12 },
                        sugar: { buy: 15, sell: 15, isProducer: true },
                        coffee: { buy: 22, sell: 22 }
                    }
                },
                {
                    name: 'Tortuga',
                    x: 180, y: 0, z: -80,
                    size: 25, height: 16, model: null,
                    lighthousePos: { x: 0, y: 16, z: 0 },
                    color: '#ffaa00',
                    basePrices: {
                        rum: { buy: 20, sell: 20, isProducer: true },
                        tobacco: { buy: 25, sell: 25, isConsumer: true },
                        wood: { buy: 12, sell: 12 },
                        sugar: { buy: 15, sell: 15 },
                        coffee: { buy: 22, sell: 22, isConsumer: true }
                    }
                },
                {
                    name: 'Havana',
                    x: -100, y: 0, z: 220,
                    size: 26, height: 15, model: null,
                    lighthousePos: { x: 0, y: 15, z: 0 },
                    color: '#00ffcc',
                    basePrices: {
                        rum: { buy: 20, sell: 20, isConsumer: true },
                        tobacco: { buy: 25, sell: 25, isProducer: true },
                        wood: { buy: 12, sell: 12, isProducer: true },
                        sugar: { buy: 15, sell: 15 },
                        coffee: { buy: 22, sell: 22 }
                    }
                }
            ]
        },
        {
            name: "THE SPANISH MAIN",
            sector: "SEC B-2",
            color: "#ff3366",
            ports: [
                {
                    name: 'Maracaibo',
                    x: 0, y: 0, z: 200,
                    size: 27, height: 17, model: null,
                    lighthousePos: { x: 0, y: 17, z: 0 },
                    color: '#00ffcc',
                    basePrices: {
                        sugar: { buy: 15, sell: 15, isProducer: true },
                        spices: { buy: 30, sell: 30, isConsumer: true },
                        cocoa: { buy: 18, sell: 18, isProducer: true },
                        coffee: { buy: 22, sell: 22 },
                        textiles: { buy: 28, sell: 28 }
                    }
                },
                {
                    name: 'Cartagena',
                    x: -200, y: 0, z: -100,
                    size: 24, height: 15, model: null,
                    lighthousePos: { x: 0, y: 15, z: 0 },
                    color: '#ffcc00',
                    basePrices: {
                        sugar: { buy: 15, sell: 15, isProducer: true },
                        spices: { buy: 30, sell: 30, isConsumer: true },
                        cocoa: { buy: 18, sell: 18 },
                        coffee: { buy: 22, sell: 22, isProducer: true },
                        textiles: { buy: 28, sell: 28 }
                    }
                },
                {
                    name: 'Portobelo',
                    x: 160, y: 0, z: -120,
                    size: 23, height: 14, model: null,
                    lighthousePos: { x: 0, y: 14, z: 0 },
                    color: '#ff3366',
                    basePrices: {
                        sugar: { buy: 15, sell: 15, isConsumer: true },
                        spices: { buy: 30, sell: 30, isProducer: true },
                        cocoa: { buy: 18, sell: 18 },
                        coffee: { buy: 22, sell: 22 },
                        textiles: { buy: 28, sell: 28, isProducer: true }
                    }
                },
                {
                    name: 'Santiago',
                    x: -80, y: 0, z: 240,
                    size: 25, height: 16, model: null,
                    lighthousePos: { x: 0, y: 16, z: 0 },
                    color: '#ffaa00',
                    basePrices: {
                        sugar: { buy: 15, sell: 15 },
                        spices: { buy: 30, sell: 30, isProducer: true },
                        cocoa: { buy: 18, sell: 18, isConsumer: true },
                        coffee: { buy: 22, sell: 22 },
                        textiles: { buy: 28, sell: 28, isConsumer: true }
                    }
                }
            ]
        },
        {
            name: "SMUGGLER'S RUN",
            sector: "SEC C-3",
            color: "#00ffcc",
            ports: [
                {
                    name: 'Bermuda',
                    x: 0, y: 0, z: 220,
                    size: 26, height: 16, model: null,
                    lighthousePos: { x: 0, y: 16, z: 0 },
                    color: '#3399ff',
                    basePrices: {
                        tobacco: { buy: 25, sell: 25, isProducer: true },
                        spices: { buy: 30, sell: 30, isProducer: true },
                        wood: { buy: 12, sell: 12, isConsumer: true },
                        textiles: { buy: 28, sell: 28 },
                        cocoa: { buy: 18, sell: 18 }
                    }
                },
                {
                    name: 'Nassau Reef',
                    x: -220, y: 0, z: -40,
                    size: 22, height: 13, model: null,
                    lighthousePos: { x: 0, y: 13, z: 0 },
                    color: '#ff7700',
                    basePrices: {
                        tobacco: { buy: 25, sell: 25, isProducer: true },
                        spices: { buy: 30, sell: 30, isProducer: true },
                        wood: { buy: 12, sell: 12 },
                        textiles: { buy: 28, sell: 28, isConsumer: true },
                        cocoa: { buy: 18, sell: 18 }
                    }
                },
                {
                    name: 'Turk\'s Island',
                    x: 140, y: 0, z: -160,
                    size: 24, height: 15, model: null,
                    lighthousePos: { x: 0, y: 15, z: 0 },
                    color: '#9933ff',
                    basePrices: {
                        tobacco: { buy: 25, sell: 25, isConsumer: true },
                        spices: { buy: 30, sell: 30 },
                        wood: { buy: 12, sell: 12, isProducer: true },
                        textiles: { buy: 28, sell: 28, isProducer: true },
                        cocoa: { buy: 18, sell: 18 }
                    }
                },
                {
                    name: 'St. Augustine',
                    x: -120, y: 0, z: 180,
                    size: 25, height: 15, model: null,
                    lighthousePos: { x: 0, y: 15, z: 0 },
                    color: '#33cc33',
                    basePrices: {
                        tobacco: { buy: 25, sell: 25 },
                        spices: { buy: 30, sell: 30, isConsumer: true },
                        wood: { buy: 12, sell: 12, isProducer: true },
                        textiles: { buy: 28, sell: 28 },
                        cocoa: { buy: 18, sell: 18, isProducer: true }
                    }
                }
            ]
        }
    ],

    RUMORS: [
        "I hear Nassau's rum flows like water and sells for just 10 Doubloons! But down in the Spanish Main, the grandees are paying a premium of 45 Doubloons per barrel!",
        "A merchant from the south tells me the Spaniards in Santiago have a massive dry spell and are paying near 45 Doubloons for a single drop of imported Rum!",
        "Don't sell your Rum in Pirate's Cradle, matey! Gather a heavy load and transit to the Spanish Main, where the noble houses buy it up at over 40 Doubloons!",
        "Cartagena's plantations are practically giving away crates of Sugar at 8 Doubloons! Sail it to the eastern reef outposts in Smuggler's Run to sell it for 48 Doubloons!",
        "I spoke with a smuggler who claimed that in Bermuda, the high ladies are so starved for sweet Sugar they'll shell out 48 Doubloons for a single crate!",
        "A rich harvest of Sugar is sitting in Portobelo for 8 Doubloons. Sail deep north-east into Smuggler's Run and you'll find eager buyers paying near 50!",
        "Turk's Island has the finest weed and leaves. Tobacco bundles are cheap at 8 Doubloons, while the officers in Pirate's Cradle will gladly pay 42!",
        "If you slip into Tortuga with bundles of Turk's Island Tobacco, you can trade them to the local sea-dogs for a hefty margin of over 40 Doubloons!",
        "Bermuda's crop of Tobacco is so abundant it goes for 8 Doubloons, but back home in Port Royal's grand barracks they are buying it for 42!",
        "The stormy outposts of Smuggler's Run grow rare Spices for 12 Doubloons, but carrying them to the hot kitchens of the Spanish Main yields 42 Doubloons!",
        "Spices are gathered in Nassau Reef for just 12 Doubloons. Take them straight to Maracaibo's trade house and you'll pocket 42 Doubloons per sack!"
    ],

    // Navigation and sector tracking state
    currentArchipelagoIndex: 0,
    isMapOpen: false,
    isInventoryOpen: false,
    activeRumor: '',
    lastDrinkPurchased: false,

    // World Assets
    world: {
        ports: [],
        particles: [], // 3D floating sea spray particles (similar to stars in Elite!)
        enemies: [],
        projectiles: [],
        splashes: [],
        debris: []
    },

    // Combat & Alert States
    activeTarget: null,
    isEnforcerAlertActive: false,
    enforcerAlertTimer: 0,
    sirenTimer: 0,
    combatAlertText: '',
    combatAlertTimer: 0,

    // Setup game loop, context, and elements
    init: function() {
        this.canvas = document.getElementById('gameCanvas');
        const canvas = this.canvas;
        this.ctx = this.canvas.getContext('2d');
        this.resizeCanvas();
        window.addEventListener('resize', () => this.resizeCanvas());

        // Keyboard listeners
        window.addEventListener('keydown', (e) => this.handleKeyDown(e));
        window.addEventListener('keyup', (e) => this.handleKeyUp(e));

        canvas.addEventListener('contextmenu', (e) => e.preventDefault());
        
        canvas.addEventListener('mousedown', (e) => {
            if (this.isDocked) return;
            if (e.button === 2) {
                // Right click: start aiming
                this.mouse.isAiming = true;
                this.mouse.startX = e.clientX;
                this.mouse.startY = e.clientY;
                canvas.style.cursor = 'crosshair';
                
                // Active flank selector matches camera perspective (firing away from camera)
                this.player.aimSide = this.mouse.yaw >= 0 ? 'starboard' : 'port';
                
                // Reset aiming defaults for clean water-level target start
                this.player.aimYawOffset = 0;
                this.player.aimHeight = 0;
            } else if (e.button === 0) {
                if (this.mouse.isAiming) {
                    // Left-click while aiming fires the active flank!
                    this.fireBroadside(this.player.aimSide);
                } else {
                    // Standard camera orbit drag
                    this.mouse.isDragging = true;
                    this.mouse.startX = e.clientX;
                    this.mouse.startY = e.clientY;
                    canvas.style.cursor = 'grabbing';
                }
            }
        });

        window.addEventListener('mousemove', (e) => {
            if (this.mouse.isAiming) {
                const dx = e.clientX - this.mouse.startX;
                const dy = e.clientY - this.mouse.startY;
                
                // Dragging horizontally shifts the yaw angle (reduced sensitivity to 0.003 for 1.6x finer control)
                this.player.aimYawOffset += dx * 0.003;
                // Clamp yawOffset to firing flank cone limit of +/- 45°
                this.player.aimYawOffset = Math.max(-Math.PI / 4, Math.min(Math.PI / 4, this.player.aimYawOffset));
                
                // Dragging vertically shifts range, or height if Shift is held (decoupled & smoothed)
                if (e.shiftKey) {
                    // Holding Shift lets you adjust shot height directly (smooth sensitivity of 0.08)
                    this.player.aimHeight = Math.max(-10, Math.min(30, this.player.aimHeight - dy * 0.08));
                } else {
                    // Standard drag adjusts target range with premium fine-grained control (reduced from 0.8 to 0.25)
                    this.player.aimRange = Math.max(30, Math.min(240, this.player.aimRange - dy * 0.25));
                }
                
                this.mouse.startX = e.clientX;
                this.mouse.startY = e.clientY;
            } else if (this.mouse.isDragging) {
                const dx = e.clientX - this.mouse.startX;
                const dy = e.clientY - this.mouse.startY;
                
                this.mouse.yaw -= dx * 0.007;
                this.mouse.pitch = Math.max(-0.4, Math.min(0.8, this.mouse.pitch + dy * 0.007));
                
                this.mouse.startX = e.clientX;
                this.mouse.startY = e.clientY;
            }
        });

        window.addEventListener('mouseup', (e) => {
            if (e.button === 2) {
                this.mouse.isAiming = false;
                canvas.style.cursor = 'grab';
            } else {
                this.mouse.isDragging = false;
                canvas.style.cursor = 'grab';
            }
        });

        window.addEventListener('mouseleave', () => {
            this.mouse.isDragging = false;
            this.mouse.isAiming = false;
            canvas.style.cursor = 'grab';
        });

        // Touch support for trackpads and mobile devices
        canvas.addEventListener('touchstart', (e) => {
            if (this.isDocked || e.touches.length === 0) return;
            this.mouse.isDragging = true;
            this.mouse.startX = e.touches[0].clientX;
            this.mouse.startY = e.touches[0].clientY;
        }, { passive: true });

        window.addEventListener('touchmove', (e) => {
            if (!this.mouse.isDragging || e.touches.length === 0) return;
            const dx = e.touches[0].clientX - this.mouse.startX;
            const dy = e.touches[0].clientY - this.mouse.startY;
            
            this.mouse.yaw -= dx * 0.007;
            this.mouse.pitch = Math.max(-0.4, Math.min(0.8, this.mouse.pitch + dy * 0.007));
            
            this.mouse.startX = e.touches[0].clientX;
            this.mouse.startY = e.touches[0].clientY;
        }, { passive: true });

        window.addEventListener('touchend', () => {
            this.mouse.isDragging = false;
        });

        // Initialize dynamic player ship stats
        this.updatePlayerShipStats();

        // Load initial archipelago
        this.loadArchipelago(0, false);

        // Initialize 3D particles for spatial reference (sea spray / dust)
        for (let i = 0; i < 40; i++) {
            this.world.particles.push({
                x: (Math.random() - 0.5) * 300,
                y: Math.random() * 2,
                z: (Math.random() - 0.5) * 300
            });
        }

        // Start requestAnimationFrame loop
        this.lastTime = performance.now();
        requestAnimationFrame((t) => this.loop(t));
    },

    resizeCanvas: function() {
        // High-DPI canvas correction for sharp vector rendering
        const dpr = window.devicePixelRatio || 1;
        const rect = this.canvas.parentNode.getBoundingClientRect();
        this.canvas.width = rect.width * dpr;
        this.canvas.height = rect.height * dpr;
        this.ctx.scale(dpr, dpr);
        this.canvas.style.width = `${rect.width}px`;
        this.canvas.style.height = `${rect.height}px`;

        // Update focal length based on size
        Engine3D.camera.focalLength = rect.width * 0.75;
    },

    handleKeyDown: function(e) {
        if (!AudioEngine.initialized) {
            AudioEngine.init();
        }
        
        const key = e.key.toLowerCase();
        
        if (this.isTraveling) return;
        
        if (key === '`' || key === '~') {
            e.preventDefault();
            this.toggleDevMenu();
            return;
        }

        if (this.isDocked) {
            // Docked controls
            if (this.currentDockView === 'menu') {
                if (key === 'escape' || key === ' ') {
                    this.undock();
                } else if (key === 'm') {
                    this.openMarket();
                } else if (key === 't') {
                    this.openTavern();
                } else if (key === 's') {
                    this.openShipyard();
                }
            } else if (this.currentDockView === 'market' || this.currentDockView === 'tavern' || this.currentDockView === 'shipyard') {
                if (key === 'escape' || key === 'backspace') {
                    this.renderDockMenu();
                } else if (this.currentDockView === 'tavern') {
                    if (key === 'r') {
                        this.askBarkeep();
                    } else if (key === 'b') {
                        this.buyRound();
                    }
                }
            }
            return;
        }

        if (key === '1') {
            this.player.activeAmmo = 'ball';
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(600, 0.05);
        }
        if (key === '2') {
            this.player.activeAmmo = 'chain';
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(750, 0.05);
        }
        if (key === '3') {
            this.player.activeAmmo = 'grape';
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(900, 0.05);
        }

        if (key === 'w') this.keys.w = true;
        if (key === 's') this.keys.s = true;
        if (key === 'a') this.keys.a = true;
        if (key === 'd') this.keys.d = true;
        if (key === 'q') this.fireBroadside('port');
        if (key === 'e') this.fireBroadside('starboard');
        if (key === 'm') {
            this.toggleMap();
        }
        if (key === 'i') {
            this.toggleInventory();
        }
        if (key === 'escape') {
            if (this.isDevMenuOpen) {
                this.toggleDevMenu();
            } else if (this.isMapOpen) {
                this.toggleMap();
            } else if (this.isInventoryOpen) {
                this.toggleInventory();
            }
        }
        if (key === ' ') {
            // Spacebar tries to dock if close to port
            if (this.activePort) {
                this.dock();
            }
        }
    },

    handleKeyUp: function(e) {
        const key = e.key.toLowerCase();
        if (key === 'w') this.keys.w = false;
        if (key === 's') this.keys.s = false;
        if (key === 'a') this.keys.a = false;
        if (key === 'd') this.keys.d = false;
    },

    calculateSailingEfficiency: function(playerYaw, windAngle) {
        let diff = Math.abs(playerYaw - windAngle) % (Math.PI * 2);
        if (diff > Math.PI) diff = Math.PI * 2 - diff;

        // 0 to PI/4 (0 to 45 deg): Sailing directly into wind (in irons) - very high drag
        if (diff < Math.PI / 4) {
            return 0.05 * (diff / (Math.PI / 4));
        }
        // PI/4 to 3*PI/4 (45 to 135 deg): Tacking / reaching - peak efficiency
        if (diff < Math.PI * 0.75) {
            const t = (diff - Math.PI / 4) / (Math.PI * 0.5);
            return 0.05 + 0.95 * Math.sin(t * Math.PI / 2);
        }
        // 3*PI/4 to PI (135 to 180 deg): Running downwind - slightly lower than reach
        const t = (diff - Math.PI * 0.75) / (Math.PI * 0.25);
        return 1.0 - 0.25 * t;
    },

    // Sailing Physics: calculate wind efficiency (tacking)
    getSailingEfficiency: function() {
        return this.calculateSailingEfficiency(this.player.yaw, this.wind.angle);
    },

    // Ballistic Cylinder Collision Detection
    checkCylinderIntersection: function(px, py, pz, sx, sy, sz, hitRadius, hitHeight) {
        let dist = Math.hypot(px - sx, pz - sz);
        return dist < hitRadius && py >= sy - 1.0 && py <= sy + hitHeight;
    },

    // Vessel Damage States
    applyShipDamage: function(shipState, damageAmount) {
        if (!shipState) return false;
        shipState.health = Math.max(0, Math.min(shipState.maxHealth || 100, (shipState.health || 0) - damageAmount));
        return shipState.health <= 0;
    },

    // Helper to calculate total cargo (including ammunition, since ammo consumes cargo space!)
    getTotalCargoCount: function(playerState) {
        if (!playerState) return 0;
        let total = 0;
        if (playerState.cargo) {
            for (const key in playerState.cargo) {
                total += (playerState.cargo[key] || 0) * 10;
            }
        }
        if (playerState.ammo) {
            for (const key in playerState.ammo) {
                total += (playerState.ammo[key] || 0) * 0.2;
            }
        }
        return Math.round(total * 10) / 10;
    },

    // Cargo Economy Rules: validation of buy capability
    canBuyCargo: function(playerState, item, price) {
        if (!playerState) return { success: false, reason: "NO PLAYER STATE" };
        if (playerState.gold < price) {
            return { success: false, reason: "TRANSACTION FAILED: INSUFFICIENT GOLD!" };
        }
        const isAmmo = ['ball', 'chain', 'grape'].includes(item);
        const weight = isAmmo ? 0.2 : 10;
        const totalCargo = this.getTotalCargoCount(playerState);
        if (totalCargo + weight > (playerState.maxCargo || 0)) {
            return { success: false, reason: "TRANSACTION FAILED: CARGO HOLD FULL!" };
        }
        return { success: true };
    },

    // Cargo Economy Rules: validation of sell capability
    canSellCargo: function(playerState, item) {
        if (!playerState) return { success: false, reason: "NO PLAYER STATE" };
        const isAmmo = ['ball', 'chain', 'grape'].includes(item);
        const held = isAmmo ? (playerState.ammo && playerState.ammo[item] || 0) : (playerState.cargo && playerState.cargo[item] || 0);
        if (held <= 0) {
            return { success: false, reason: "TRANSACTION FAILED: NO CARGO HELD!" };
        }
        return { success: true };
    },

    // Shipyard Economy Rules: validation of ship class upgrade capability
    canUpgradeShip: function(playerState, targetClass) {
        if (!playerState) return { success: false, reason: "NO PLAYER STATE" };
        const registry = this.SHIP_CLASSES;
        const currentShip = registry[playerState.shipClass] || registry.dinghy;
        const targetShip = registry[targetClass];
        
        if (!targetShip) {
            return { success: false, reason: "INVALID SHIP CLASS" };
        }
        
        if (playerState.shipClass === targetClass) {
            return { success: false, reason: "ALREADY OWNED" };
        }
        
        const healthRatio = (playerState.health !== undefined && playerState.maxHealth) ? (playerState.health / playerState.maxHealth) : 1.0;
        const tradeInValue = Math.floor((currentShip.cost || 0) * 0.7 * healthRatio);
        const upgradeCost = Math.max(0, targetShip.cost - tradeInValue);
        
        if (playerState.gold < upgradeCost) {
            return { success: false, reason: "INSUFFICIENT GOLD" };
        }
        
        const totalCargo = this.getTotalCargoCount(playerState);
        if (totalCargo > targetShip.maxCargo) {
            return { success: false, reason: "CARGO HOLD OVERFLOW" };
        }
        
        return { success: true, cost: upgradeCost };
    },

    // AI Steering & Firing Decision State Machine
    calculateAISteering: function(enemy, target, dt) {
        let dx = target.x - enemy.x;
        let dz = target.z - enemy.z;
        let dist = Math.hypot(dx, dz);

        let yaw = enemy.yaw;
        let speed = enemy.speed;
        let rudder = enemy.rudder || 0;
        let fireSide = null;

        if (dist > 300) {
            // Patrol mode
            yaw += 0.15 * dt;
            speed = enemy.baseMaxSpeed * 0.4;
            rudder = 0;
        } else if (dist > 100) {
            // Chase mode
            let targetYaw = Math.atan2(dx, dz);
            let yawDiff = targetYaw - yaw;
            while (yawDiff < -Math.PI) yawDiff += Math.PI * 2;
            while (yawDiff > Math.PI) yawDiff -= Math.PI * 2;
            
            rudder = Math.max(-1, Math.min(1, yawDiff * 2));
            yaw += rudder * 0.8 * dt;
            speed = enemy.baseMaxSpeed * 0.8;
        } else {
            // Orbit and perpendicular Broadside mode
            let angleToTarget = Math.atan2(dx, dz);
            let orbitYaw = angleToTarget + Math.PI / 2;
            let yawDiff = orbitYaw - yaw;
            while (yawDiff < -Math.PI) yawDiff += Math.PI * 2;
            while (yawDiff > Math.PI) yawDiff -= Math.PI * 2;

            rudder = Math.max(-1, Math.min(1, yawDiff * 2.5));
            yaw += rudder * 1.2 * dt;
            speed = enemy.baseMaxSpeed * 0.7;

            // Fire check (Broadside alignment) using updated yaw
            let relAngle = angleToTarget - yaw;
            while (relAngle < -Math.PI) relAngle += Math.PI * 2;
            while (relAngle > Math.PI) relAngle -= Math.PI * 2;

            if ((enemy.reloadTimer || 0) <= 0) {
                if (Math.abs(relAngle - (-Math.PI / 2)) < 0.35) {
                    fireSide = 'port';
                } else if (Math.abs(relAngle - (Math.PI / 2)) < 0.35) {
                    fireSide = 'starboard';
                }
            }
        }

        // Normalize yaw to [0, 2*PI]
        yaw = yaw % (Math.PI * 2);
        if (yaw < 0) yaw += Math.PI * 2;

        return { yaw, speed, rudder, fireSide };
    },

    // Wind Drift smooth angle interpolation
    calculateNextWindAngle: function(currentAngle, targetAngle, lerpFactor = 0.02) {
        let windDiff = targetAngle - currentAngle;
        while (windDiff < -Math.PI) windDiff += Math.PI * 2;
        while (windDiff > Math.PI) windDiff -= Math.PI * 2;
        let nextAngle = (currentAngle + windDiff * lerpFactor) % (Math.PI * 2);
        if (nextAngle < 0) nextAngle += Math.PI * 2;
        return nextAngle;
    },

    // Port Market deterministic pricing
    calculatePortPrices: function(port) {
        if (!port || !port.basePrices) return {};
        
        const BASE_PRICES = {
            rum: 20,
            sugar: 15,
            tobacco: 25,
            spices: 30,
            coffee: 22,
            cocoa: 18,
            textiles: 28,
            wood: 12
        };

        // A deterministic unique seed per port name
        let portSeed = 0;
        for (let i = 0; i < port.name.length; i++) {
            portSeed += port.name.charCodeAt(i);
        }
        // Fluctuation wave between -0.15 and +0.15 based on travel count and seed
        const wave = Math.sin((this.marketTravelCount || 0) * 0.5 + portSeed);
        const fluctuation = 1.0 + wave * 0.15;

        const prices = {};
        for (const item in port.basePrices) {
            const baseConfig = port.basePrices[item];
            const base = BASE_PRICES[item] || baseConfig.buy || 20;
            
            let buyMult = 1.0;
            let sellMult = 0.75;
            
            if (baseConfig.isProducer) {
                buyMult = 0.6;
                sellMult = 0.4;
            } else if (baseConfig.isConsumer) {
                buyMult = 1.8;
                sellMult = 1.4;
            }
            
            let buyPrice = Math.round(base * buyMult * fluctuation);
            let sellPrice = Math.round(base * sellMult * fluctuation);
            
            // Ensure buyPrice is at least 1, and sellPrice is at least 1
            buyPrice = Math.max(1, buyPrice);
            sellPrice = Math.max(1, sellPrice);
            
            // Prevent infinite money exploit: sell price must be strictly less than buy price
            if (sellPrice >= buyPrice) {
                sellPrice = Math.max(1, buyPrice - 1);
            }
            
            prices[item] = {
                buy: buyPrice,
                sell: sellPrice,
                isProducer: baseConfig.isProducer || false,
                isConsumer: baseConfig.isConsumer || false
            };
        }
        return prices;
    },

    // Update player stats based on current ship class
    updatePlayerShipStats: function() {
        const stats = this.SHIP_CLASSES[this.player.shipClass] || this.SHIP_CLASSES.dinghy;
        this.player.maxHealth = stats.maxHealth;
        this.player.baseMaxSpeed = stats.baseMaxSpeed;
        this.player.maxCargo = stats.maxCargo;
        this.player.health = Math.min(this.player.health, this.player.maxHealth);
    },

    // Broadside cannon discharge with 3D arcs and momentum
    fireBroadside: function(side) {
        if (this.isDocked || this.isTraveling) return;

        // Cooldown check
        if (side === 'port') {
            if (this.player.reloadPort > 0) {
                AudioEngine.playBeep(200, 0.15); // buzz error
                return;
            }
        } else {
            if (this.player.reloadStbd > 0) {
                AudioEngine.playBeep(200, 0.15); // buzz error
                return;
            }
        }

        // Ammunition Stock check
        const activeAmmo = this.player.activeAmmo || 'ball';
        const ammoCount = this.player.ammo[activeAmmo] || 0;
        if (ammoCount <= 0) {
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) {
                AudioEngine.playBeep(150, 0.25); // warning buzz for empty ammo
            }
            return;
        }

        const stats = this.SHIP_CLASSES[this.player.shipClass] || this.SHIP_CLASSES.dinghy;
        const maxCannons = stats.firepower || 1;
        const count = Math.min(maxCannons, ammoCount);

        // Set cooldowns
        if (side === 'port') {
            this.player.reloadPort = 3.0; // 3-second cooldown
        } else {
            this.player.reloadStbd = 3.0; // 3-second cooldown
        }

        // Decrement ammo count by number of cannons fired
        this.player.ammo[activeAmmo] -= count;

        AudioEngine.playShoot();

        const fireYaw = (side === 'port') ? this.player.yaw - Math.PI / 2 : this.player.yaw + Math.PI / 2;
        const isUsingAimTarget = this.mouse.isAiming && (this.player.aimSide === side);

        // Precompute absolute aiming target coordinates
        let targetX = 0, targetY = 0, targetZ = 0;
        if (isUsingAimTarget) {
            const aimYaw = fireYaw + (this.player.aimYawOffset || 0);
            const aimRange = this.player.aimRange !== undefined ? this.player.aimRange : 120;
            targetX = this.player.x + Math.sin(aimYaw) * aimRange;
            targetY = this.player.aimHeight !== undefined ? this.player.aimHeight : 0;
            targetZ = this.player.z + Math.cos(aimYaw) * aimRange;
        }

        const v_original = 28.0;
        const elevRad = 15 * Math.PI / 180;

        for (let i = 0; i < count; i++) {
            let gunSpread = 0;
            if (count > 1) {
                gunSpread = ((i / (count - 1)) - 0.5) * 0.12;
            }

            let offsetDist = stats.hitRadius || 3.0;
            let startX = this.player.x + Math.sin(fireYaw) * offsetDist;
            let startY = this.player.y + 1.0;
            let startZ = this.player.z + Math.cos(fireYaw) * offsetDist;

            if (activeAmmo === 'grape') {
                // Grape fires a randomized 3D shrapnel buckshot cloud of 16 pellets per cannon!
                for (let j = 0; j < 16; j++) {
                    let vx, vy, vz;
                    
                    // Randomized 3D spread angles & velocity offsets (creates a premium buckshot cloud)
                    const randSpread = (Math.random() - 0.5) * 0.50; // Horizontal angle spread
                    const randVy = (Math.random() - 0.5) * 5.0;      // Vertical velocity jitter
                    const speedVar = 0.88 + Math.random() * 0.24;    // Velocity magnitude jitter (spreads shot in depth)

                    if (isUsingAimTarget) {
                        const pelletYaw = randSpread + gunSpread;
                        const dx = targetX - startX;
                        const dz = targetZ - startZ;
                        const rawDist = Math.hypot(dx, dz);
                        const D = Math.max(5, rawDist);

                        const dirYaw = Math.atan2(dx, dz) + pelletYaw;
                        const v_horiz = v_original * speedVar;
                        const T = D / v_horiz;

                        vy = (targetY - startY) / T + 0.5 * 9.81 * T + randVy;
                        vy = Math.max(-10, Math.min(45, vy)); // Safe clamp

                        vx = Math.sin(this.player.yaw) * this.player.speed + Math.sin(dirYaw) * v_horiz;
                        vz = Math.cos(this.player.yaw) * this.player.speed + Math.cos(dirYaw) * v_horiz;
                    } else {
                        const ballYaw = fireYaw + gunSpread + randSpread;
                        const v_pellet = v_original * speedVar;
                        const v_y = v_pellet * Math.sin(elevRad) + randVy;
                        const v_horiz = v_pellet * Math.cos(elevRad);

                        vx = Math.sin(this.player.yaw) * this.player.speed + Math.sin(ballYaw) * v_horiz;
                        vy = v_y;
                        vz = Math.cos(this.player.yaw) * this.player.speed + Math.cos(ballYaw) * v_horiz;
                    }

                    this.world.projectiles.push({
                        x: startX,
                        y: startY,
                        z: startZ,
                        vx: vx,
                        vy: vy,
                        vz: vz,
                        isPlayerOwned: true,
                        life: 0.8, // Shorter range: 0.8 seconds for balance
                        damage: 2, // Balanced down from 8 to prevent Galleon point-blank one-shot exploit
                        type: 'grape'
                    });
                }
            } else {
                // Ball or Chain standard firing
                let vx, vy, vz;
                let life = activeAmmo === 'chain' ? 2.2 : 4.0; // 2.2s for chain, 4.0s for ball
                let damage = activeAmmo === 'chain' ? 10 : 25; // 10 HP for chain, 25 HP for ball

                if (isUsingAimTarget) {
                    const dx = targetX - startX;
                    const dz = targetZ - startZ;
                    const rawDist = Math.hypot(dx, dz);
                    const D = Math.max(5, rawDist);

                    const dirYaw = Math.atan2(dx, dz) + gunSpread;
                    const v_horiz = v_original;
                    const T = D / v_original;

                    vy = (targetY - startY) / T + 0.5 * 9.81 * T;
                    vy = Math.max(-10, Math.min(45, vy)); // Safe clamp

                    vx = Math.sin(this.player.yaw) * this.player.speed + Math.sin(dirYaw) * v_horiz;
                    vz = Math.cos(this.player.yaw) * this.player.speed + Math.cos(dirYaw) * v_horiz;
                } else {
                    let ballYaw = fireYaw + gunSpread;
                    let v_y = v_original * Math.sin(elevRad);
                    let v_horiz = v_original * Math.cos(elevRad);

                    vx = Math.sin(this.player.yaw) * this.player.speed + Math.sin(ballYaw) * v_horiz;
                    vy = v_y;
                    vz = Math.cos(this.player.yaw) * this.player.speed + Math.cos(ballYaw) * v_horiz;
                }

                this.world.projectiles.push({
                    x: startX,
                    y: startY,
                    z: startZ,
                    vx: vx,
                    vy: vy,
                    vz: vz,
                    isPlayerOwned: true,
                    life: life,
                    damage: damage,
                    type: activeAmmo
                });
            }
        }

        // Port Authority Firing Violation check
        const distToPort = this.getDistanceToNearestPort();
        if (distToPort < 120) {
            this.alertPortAuthority(true, this.player);
        }
    },

    // AI broadside discharge
    fireBroadsideAI: function(side, enemy) {
        AudioEngine.playShoot();

        enemy.reloadTimer = enemy.shipClass === 'galleon' ? 5.0 : 4.0; // 5s for galleon, 4s for sloop

        const stats = this.SHIP_CLASSES[enemy.shipClass] || this.SHIP_CLASSES.sloop;
        const count = stats.firepower || 1;
        const fireYaw = (side === 'port') ? enemy.yaw - Math.PI / 2 : enemy.yaw + Math.PI / 2;

        const v_lateral = 25.0;
        const elevRad = 15 * Math.PI / 180;
        const v_y = v_lateral * Math.sin(elevRad);
        const v_horiz = v_lateral * Math.cos(elevRad);

        for (let i = 0; i < count; i++) {
            let spreadAngle = 0;
            if (count > 1) {
                spreadAngle = ((i / (count - 1)) - 0.5) * 0.12;
            }
            let ballYaw = fireYaw + spreadAngle;
            let vx = Math.sin(enemy.yaw) * enemy.speed + Math.sin(ballYaw) * v_horiz;
            let vy = v_y;
            let vz = Math.cos(enemy.yaw) * enemy.speed + Math.cos(ballYaw) * v_horiz;

            let offsetDist = stats.hitRadius || 3.0;
            let startX = enemy.x + Math.sin(fireYaw) * offsetDist;
            let startY = enemy.y + 1.0;
            let startZ = enemy.z + Math.cos(fireYaw) * offsetDist;

            this.world.projectiles.push({
                x: startX,
                y: startY,
                z: startZ,
                vx: vx,
                vy: vy,
                vz: vz,
                isPlayerOwned: false,
                life: 4.0
            });
        }

        // Port Authority Firing Violation check for pirates too (but not enforcers themselves)!
        if (enemy.isEnforcer) return;
        const distToPort = this.getDistanceToNearestPortFromCoords(enemy.x, enemy.z);
        if (distToPort < 120) {
            this.alertPortAuthority(false, enemy);
        }
    },

    // Get distance from arbitrary coordinates to nearest port
    getDistanceToNearestPortFromCoords: function(x, z) {
        let minDist = 999999;
        this.world.ports.forEach(port => {
            const dist = Math.hypot(port.x - x, port.z - z);
            if (dist < minDist) {
                minDist = dist;
            }
        });
        return minDist;
    },

    // Trigger enforcer spawning and klaxon alarms
    alertPortAuthority: function(isPlayerViolator, violatorShip) {
        // Prevent enforcers from alerting themselves
        if (violatorShip && violatorShip.isEnforcer) return;

        // Limit active enforcers to 1 to prevent infinite/heavy cascading spawns
        const activeEnforcer = this.world.enemies.find(e => e.isEnforcer && e.health > 0);
        if (activeEnforcer) {
            // If an enforcer is already active, we retarget it to the player if the player is the violator
            if (isPlayerViolator && activeEnforcer.target !== this.player) {
                activeEnforcer.target = this.player;
                this.isEnforcerAlertActive = true;
                this.enforcerAlertTimer = 5.0;
                this.sirenTimer = 0;
                this.combatAlertText = "!!! PORT AUTHORITY SECURITY ALERT !!! ENFORCER TARGETING YOU!";
                this.combatAlertTimer = 3.0;
                this.showSecurityAlertBanner();
            }
            return;
        }

        // Find the nearest port
        let nearestPort = null;
        let minDist = 999999;
        this.world.ports.forEach(port => {
            const dist = Math.hypot(port.x - violatorShip.x, port.z - violatorShip.z);
            if (dist < minDist) {
                minDist = dist;
                nearestPort = port;
            }
        });

        if (nearestPort) {
            // Spawn the Galleon enforcer exactly 100 units away from the player in the direction of the port.
            // This ensures it never spawns on top of the player while maintaining the vector of emerging from port waters.
            let dx = nearestPort.x - violatorShip.x;
            let dz = nearestPort.z - violatorShip.z;
            let len = Math.hypot(dx, dz) || 1;
            
            let spawnX = violatorShip.x + (dx / len) * 100;
            let spawnZ = violatorShip.z + (dz / len) * 100;

            const galleonStats = this.SHIP_CLASSES.galleon;
            let enforcer = {
                id: 'enforcer_' + Date.now() + '_' + Math.floor(Math.random()*100),
                x: spawnX,
                y: 0,
                z: spawnZ,
                yaw: Math.atan2(violatorShip.x - spawnX, violatorShip.z - spawnZ),
                pitch: 0,
                roll: 0,
                speed: 1.5,
                shipClass: 'galleon',
                color: this.FACTIONS.authority.color,
                faction: 'authority',
                scale: 1.6,
                health: galleonStats.maxHealth,
                maxHealth: galleonStats.maxHealth,
                firepower: galleonStats.firepower,
                baseMaxSpeed: galleonStats.baseMaxSpeed,
                hitRadius: galleonStats.hitRadius * 1.6,
                hitHeight: galleonStats.hitHeight * 1.6,
                reloadTimer: 0,
                isEnforcer: true,
                target: violatorShip
            };
            this.world.enemies.push(enforcer);

            if (isPlayerViolator) {
                this.isEnforcerAlertActive = true;
                this.enforcerAlertTimer = 5.0;
                this.sirenTimer = 0;
                this.combatAlertText = "!!! PORT AUTHORITY SECURITY ALERT !!! ILLEGAL DISCHARGE DETECTED. ENFORCER ENGAGED!";
                this.combatAlertTimer = 5.0;
                
                this.showSecurityAlertBanner();
            } else {
                this.combatAlertText = "!!! SECURITY ALARM !!! ILLEGAL FIRE DETECTED. ENFORCERS LAUNCHED!";
                this.combatAlertTimer = 4.0;
                AudioEngine.playAlarmSiren();
            }
        }
    },

    // Render HTML emergency warning banner overlay
    showSecurityAlertBanner: function() {
        let alertEl = document.getElementById('securityAlertBanner');
        if (!alertEl) {
            alertEl = document.createElement('div');
            alertEl.id = 'securityAlertBanner';
            alertEl.className = 'security-alert-modal theme-blue';
            alertEl.innerHTML = `
                <div class="alert-title">!!! SECURITY EXTREMIS !!!</div>
                <div class="alert-desc">ILLEGAL CANNON DISCHARGE NEAR HARBOR.<br>PORT SECURITY GALLEON ENFORCER DEPLOYED.</div>
            `;
            document.body.appendChild(alertEl);
        }
        alertEl.classList.remove('hidden');
        
        setTimeout(() => {
            if (alertEl) alertEl.classList.add('hidden');
        }, 4000);
    },

    // Display run-aground island collision warning banner overlay
    showCollisionAlert: function() {
        let alertEl = document.getElementById('collisionAlert');
        if (!alertEl) {
            alertEl = document.createElement('div');
            alertEl.id = 'collisionAlert';
            alertEl.className = 'security-alert-modal';
            alertEl.style.top = '140px';
            alertEl.innerHTML = `
                <div class="alert-title neon-text-red">!!! RUN AGROUND !!!</div>
                <div class="alert-desc" style="color: #ff3333; font-weight: bold; font-size: 0.8rem;">
                    ISLAND COLLISION: HULL DAMAGE DEALT (-10 HP)!
                </div>
            `;
            document.body.appendChild(alertEl);
        }
        alertEl.classList.remove('hidden');
        
        setTimeout(() => {
            if (alertEl) alertEl.classList.add('hidden');
        }, 3000);
    },

    // Spawns a pirate ship at a random ocean location
    spawnPirateShip: function() {
        let x = 0, z = 0, found = false;
        for (let attempt = 0; attempt < 50; attempt++) {
            x = (Math.random() - 0.5) * 600;
            z = (Math.random() - 0.5) * 600;
            
            let distToPlayer = Math.hypot(this.player.x - x, this.player.z - z);
            if (distToPlayer < 100) continue;

            let nearPort = false;
            this.world.ports.forEach(port => {
                if (Math.hypot(port.x - x, port.z - z) < 120) {
                    nearPort = true;
                }
            });
            if (nearPort) continue;

            found = true;
            break;
        }

        if (!found) {
            x = 250;
            z = 250;
        }

        const sloopStats = this.SHIP_CLASSES.sloop;
        this.world.enemies.push({
            id: 'pirate_' + Date.now() + '_' + Math.floor(Math.random()*1000),
            x: x,
            y: 0,
            z: z,
            yaw: Math.random() * Math.PI * 2,
            pitch: 0,
            roll: 0,
            speed: 3.5,
            shipClass: 'sloop',
            color: this.FACTIONS.pirate.color,
            faction: 'pirate',
            scale: 1.0,
            health: sloopStats.maxHealth,
            maxHealth: sloopStats.maxHealth,
            firepower: sloopStats.firepower,
            baseMaxSpeed: sloopStats.baseMaxSpeed,
            hitRadius: sloopStats.hitRadius,
            hitHeight: sloopStats.hitHeight,
            reloadTimer: Math.random() * 2.0,
            isEnforcer: false,
            target: this.player
        });
    },

    // Spawns spark lines fly out on impact
    spawnHitDebris: function(x, y, z, count) {
        for (let i = 0; i < count; i++) {
            this.world.debris.push({
                x: x,
                y: y,
                z: z,
                vx: (Math.random() - 0.5) * 15,
                vy: Math.random() * 10 + 2,
                vz: (Math.random() - 0.5) * 15,
                yaw: Math.random() * Math.PI * 2,
                pitch: Math.random() * Math.PI * 2,
                roll: Math.random() * Math.PI * 2,
                rotSpeedYaw: (Math.random() - 0.5) * 10,
                rotSpeedPitch: (Math.random() - 0.5) * 10,
                rotSpeedRoll: (Math.random() - 0.5) * 10,
                scale: 0.2 + Math.random() * 0.3,
                life: 0.8 + Math.random() * 0.4,
                isSpark: true
            });
        }
    },

    // Handles hostile or enforcer destruction with floating crates
    destroyEnemy: function(enemy) {
        for (let i = 0; i < 5; i++) {
            this.world.debris.push({
                x: enemy.x + (Math.random() - 0.5) * 4,
                y: enemy.y + Math.random() * 2,
                z: enemy.z + (Math.random() - 0.5) * 4,
                vx: (Math.random() - 0.5) * 8,
                vy: Math.random() * 6 + 4,
                vz: (Math.random() - 0.5) * 8,
                yaw: Math.random() * Math.PI * 2,
                pitch: Math.random() * Math.PI * 2,
                roll: Math.random() * Math.PI * 2,
                rotSpeedYaw: (Math.random() - 0.5) * 4,
                rotSpeedPitch: (Math.random() - 0.5) * 4,
                rotSpeedRoll: (Math.random() - 0.5) * 4,
                scale: 0.5 + Math.random() * 0.6,
                life: 3.5,
                isSpark: false
            });
        }

        AudioEngine.playCoin();

        let goldReward = enemy.isEnforcer ? 300 : 50;
        this.player.gold += goldReward;

        this.combatAlertText = `VICTORY! SUNK ${enemy.isEnforcer ? 'ENFORCER' : 'PIRATE'} (+${goldReward} D)`;
        this.combatAlertTimer = 4.0;
        
        if (this.activeTarget === enemy) {
            this.activeTarget = null;
        }
    },

    // Repawn repairs the player and wipes cargo
    handlePlayerDeath: function() {
        AudioEngine.playExplosion();
        alert("YOUR SHIP WAS SUNK!\nYour hull was destroyed, and all cargo was lost to the sea.\nFriendly local sailors rescued you and towed your ship back to NASSAU.");
        
        this.player.cargo = { rum: 0, sugar: 0, spices: 0, tobacco: 0 };
        this.player.health = this.player.maxHealth;
        
        let nearestPort = this.world.ports[0];
        if (nearestPort) {
            this.player.x = nearestPort.x;
            this.player.z = nearestPort.z - nearestPort.size - 25;
        } else {
            this.player.x = 0;
            this.player.z = 0;
        }
        this.player.y = 0;
        this.player.speed = 0;
        this.player.sailLevel = 0;
        this.player.yaw = 0;
        this.player.rudder = 0;
        
        this.isDocked = false;
        this.activePort = null;
        
        this.loadArchipelago(this.currentArchipelagoIndex, false);
    },

    // Aborts travel sequence and spawns mid-transit encounter
    triggerRadarIntercept: function() {
        this.isTraveling = false;
        
        document.getElementById('travelModal').classList.add('hidden');
        
        this.loadArchipelago(this.travelTargetIndex, false, true);
        
        this.player.x = 250 + (Math.random() - 0.5) * 100;
        this.player.z = -250 + (Math.random() - 0.5) * 100;
        this.player.y = 0;
        this.player.speed = 1.0;
        this.player.sailLevel = 2;
        this.player.yaw = Math.random() * Math.PI * 2;
        this.player.rudder = 0;

        this.world.enemies = [];
        this.world.projectiles = [];
        this.world.splashes = [];
        this.world.debris = [];

        const numPirates = 1 + Math.floor(Math.random() * 2);
        for (let i = 0; i < numPirates; i++) {
            let angle = Math.random() * Math.PI * 2;
            let dist = 80 + Math.random() * 30;
            let px = this.player.x + Math.sin(angle) * dist;
            let pz = this.player.z + Math.cos(angle) * dist;

            const sloopStats = this.SHIP_CLASSES.sloop;
            this.world.enemies.push({
                id: 'pirate_' + Date.now() + '_' + i,
                x: px,
                y: 0,
                z: pz,
                yaw: angle + Math.PI,
                pitch: 0,
                roll: 0,
                speed: 4.5,
                shipClass: 'sloop',
                color: this.FACTIONS.pirate.color,
                faction: 'pirate',
                scale: 1.0,
                health: sloopStats.maxHealth,
                maxHealth: sloopStats.maxHealth,
                firepower: sloopStats.firepower,
                baseMaxSpeed: sloopStats.baseMaxSpeed,
                hitRadius: sloopStats.hitRadius,
                hitHeight: sloopStats.hitHeight,
                reloadTimer: Math.random() * 1.5,
                isEnforcer: false,
                target: this.player
            });
        }

        this.combatAlertText = "WARNING: PIRATE BLOCKADE INTERCEPT. COUPLERS DE-ENGAGED!";
        this.combatAlertTimer = 6.0;
        AudioEngine.playAlarmSiren();
        
        this.showRadarInterceptAlert();
    },

    // Display travel de-coupling error overlay
    showRadarInterceptAlert: function() {
        let alertEl = document.getElementById('radarInterceptAlert');
        if (!alertEl) {
            alertEl = document.createElement('div');
            alertEl.id = 'radarInterceptAlert';
            alertEl.className = 'security-alert-modal';
            alertEl.style.top = '100px';
            alertEl.innerHTML = `
                <div class="alert-title neon-text-red">!!! TRANSIT EMERGENCY !!!</div>
                <div class="alert-desc" style="color: #ff3333; font-weight: bold; font-size: 0.8rem;">
                    RADAR WARNING: PIRATE BLOCKADE DETECTED IN WINDWARD CHANNEL.<br>
                    COUPLERS DE-ENGAGED. PLUNGED INTO OPEN OCEAN GRID!
                </div>
            `;
            document.body.appendChild(alertEl);
        }
        alertEl.classList.remove('hidden');
        
        setTimeout(() => {
            if (alertEl) alertEl.classList.add('hidden');
        }, 5000);
    },

    // Core physics loops for projectiles, splashes, debris and active AI steering
    updateCombatEngine: function(dt, getWaveHeight) {
        // 1. Update Projectiles
        this.world.projectiles = this.world.projectiles.filter(p => {
            p.x += p.vx * dt;
            p.z += p.vz * dt;
            p.vy -= 9.81 * dt;
            p.y += p.vy * dt;
            p.life -= dt;

            // Check water level splashdown
            const waveY = getWaveHeight(p.x, p.z);
            if (p.y <= waveY) {
                this.world.splashes.push({ x: p.x, z: p.z, r: 0.2, maxR: 3.5 + Math.random() * 1.5, life: 0.55 });
                AudioEngine.playSplash();
                return false;
            }

            // Check ship hits
            if (p.isPlayerOwned) {
                // Check hits on AI enemies
                for (let i = 0; i < this.world.enemies.length; i++) {
                    let enemy = this.world.enemies[i];
                    if (enemy.health <= 0) continue;

                    if (this.checkCylinderIntersection(p.x, p.y, p.z, enemy.x, enemy.y, enemy.z, enemy.hitRadius, enemy.hitHeight)) {
                        const dmg = p.damage !== undefined ? p.damage : 25;
                        const isSunk = this.applyShipDamage(enemy, dmg);
                        if (typeof AudioEngine !== 'undefined' && AudioEngine.playExplosion) {
                            AudioEngine.playExplosion();
                        }
                        this.spawnHitDebris(enemy.x, enemy.y + 2.0, enemy.z, 8);

                        if (p.type === 'chain') {
                            enemy.speedDebuffTimer = 5.0; // Shred rigging, speed deacceleration debuff for 5s
                        }

                        if (isSunk) {
                            this.destroyEnemy(enemy);
                        }
                        return false;
                    }
                }
            } else {
                // Check hits on player
                const playerStats = this.SHIP_CLASSES[this.player.shipClass] || this.SHIP_CLASSES.dinghy;
                if (this.checkCylinderIntersection(p.x, p.y, p.z, this.player.x, this.player.y, this.player.z, playerStats.hitRadius, playerStats.hitHeight)) {
                    const dmg = p.damage !== undefined ? p.damage : 15;
                    const isSunk = this.applyShipDamage(this.player, dmg);
                    if (typeof AudioEngine !== 'undefined' && AudioEngine.playExplosion) {
                        AudioEngine.playExplosion();
                    }
                    this.spawnHitDebris(this.player.x, this.player.y + 1.5, this.player.z, 8);

                    if (p.type === 'chain') {
                        this.player.speedDebuffTimer = 5.0; // Player speed deacceleration
                    }

                    this.combatAlertText = `!!! BRACE FOR IMPACT: HULL HIT (-${dmg} HP) !!!`;
                    this.combatAlertTimer = 2.5;

                    if (isSunk) {
                        this.handlePlayerDeath();
                    }
                    return false;
                }
            }

            return p.life > 0;
        });

        // 2. Update Splashes
        this.world.splashes = this.world.splashes.filter(s => {
            s.life -= dt;
            s.r += (s.maxR - s.r) * 5 * dt;
            return s.life > 0;
        });

        // 3. Update Debris/Sparks
        this.world.debris = this.world.debris.filter(d => {
            d.life -= dt;
            if (d.isSpark) {
                d.x += d.vx * dt;
                d.y += d.vy * dt;
                d.z += d.vz * dt;
                d.vy -= 9.8 * dt;
            } else {
                d.x += d.vx * dt;
                d.z += d.vz * dt;
                d.y = getWaveHeight(d.x, d.z) - 0.2;
                
                d.yaw += d.rotSpeedYaw * dt;
                d.pitch += d.rotSpeedPitch * dt;
                d.roll += d.rotSpeedRoll * dt;
                
                if (d.life < 1.0) {
                    d.y -= (1.0 - d.life) * 2.0 * dt;
                }
            }
            return d.life > 0;
        });

        // 4. Update Enemy AI steering state machines
        this.world.enemies = this.world.enemies.filter(enemy => {
            if (enemy.health <= 0) {
                enemy.y -= 2.0 * dt; // slowly sink
                return enemy.y > -35; // keep until it sinks below 35 units under water level
            }

            if (enemy.reloadTimer > 0) {
                enemy.reloadTimer -= dt;
            }

            if (enemy.speedDebuffTimer > 0) {
                enemy.speedDebuffTimer -= dt;
            }

            let target = enemy.target || this.player;
            const steering = this.calculateAISteering(enemy, target, dt);
            enemy.yaw = steering.yaw;
            enemy.speed = steering.speed;
            if (enemy.speedDebuffTimer > 0) {
                enemy.speed *= 0.5; // Apply Chain shot speed penalty
            }
            enemy.rudder = steering.rudder;

            if (steering.fireSide === 'port') {
                this.fireBroadsideAI('port', enemy);
            } else if (steering.fireSide === 'starboard') {
                this.fireBroadsideAI('starboard', enemy);
            }

            enemy.x += Math.sin(enemy.yaw) * enemy.speed * dt;
            enemy.z += Math.cos(enemy.yaw) * enemy.speed * dt;
            enemy.y = getWaveHeight(enemy.x, enemy.z);

            // Slope adjustments
            enemy.pitch = (getWaveHeight(enemy.x + Math.sin(enemy.yaw)*1.5, enemy.z + Math.cos(enemy.yaw)*1.5) - getWaveHeight(enemy.x - Math.sin(enemy.yaw)*1.5, enemy.z - Math.cos(enemy.yaw)*1.5)) / 3.0;
            enemy.roll = -enemy.rudder * enemy.speed * 0.05;

            return true;
        });

        // 5. Target selection scanner
        let closestHostile = null;
        let minHostileDist = 999999;
        this.world.enemies.forEach(e => {
            if (e.health > 0) {
                let dist = Math.hypot(e.x - this.player.x, e.z - this.player.z);
                if (dist < minHostileDist) {
                    minHostileDist = dist;
                    closestHostile = e;
                }
            }
        });

        if (closestHostile && minHostileDist < 200) {
            this.activeTarget = closestHostile;
        } else {
            this.activeTarget = null;
        }
    },

    dock: function() {
        if (!this.activePort) return;
        this.isDocked = true;
        this.currentDockView = 'menu';
        this.player.speed = 0;
        this.player.sailLevel = 0; // Drop anchor
        AudioEngine.playDockJingle();
        
        // Despawn hostile ships & in-flight cannonballs upon escape
        this.world.enemies = [];
        this.world.projectiles = [];
        this.isEnforcerAlertActive = false;
        this.sirenTimer = 0;
        this.activeTarget = null;
        
        const alertEl = document.getElementById('securityAlertBanner');
        if (alertEl) {
            alertEl.classList.add('hidden');
        }
        
        // Show main dock overlay
        document.getElementById('dockModal').classList.remove('hidden');
        document.getElementById('portTitle').innerText = `PORT OF ${this.activePort.name.toUpperCase()}`;
        
        this.renderDockMenu();
    },

    undock: function() {
        this.isDocked = false;
        this.player.sailLevel = 2; // Half sails
        this.player.collisionImmunityTimer = 4.0;
        AudioEngine.playBeep(600, 0.1);
        document.getElementById('dockModal').classList.add('hidden');
    },

    // Render Dock main menu
    renderDockMenu: function() {
        this.currentDockView = 'menu';
        const content = document.getElementById('portContent');
        const totalCargo = this.getTotalCargoCount(this.player);
        
        const labels = {
            rum: { name: 'Rum', suffix: 'barrels' },
            sugar: { name: 'Sugar', suffix: 'crates' },
            spices: { name: 'Spices', suffix: 'sacks' },
            tobacco: { name: 'Tobacco', suffix: 'bundles' },
            coffee: { name: 'Coffee', suffix: 'bags' },
            cocoa: { name: 'Cocoa', suffix: 'beans' },
            textiles: { name: 'Textiles', suffix: 'bolts' },
            wood: { name: 'Wood', suffix: 'logs' }
        };

        let manifestItemsHTML = '';
        for (const item in this.player.cargo) {
            const count = this.player.cargo[item] || 0;
            if (count > 0 && labels[item]) {
                manifestItemsHTML += `<li>${labels[item].name}: <span class="neon-text-green">${count} ${labels[item].suffix}</span></li>`;
            }
        }
        
        if (!manifestItemsHTML) {
            manifestItemsHTML = `<li style="opacity: 0.5;">[No commodities held]</li>`;
        }

        manifestItemsHTML += `
            <li style="border-top: 1px dashed rgba(0,255,255,0.2); padding-top: 4px; margin-top: 4px;">Ball Shot: <span class="neon-text-yellow">${this.player.ammo.ball} shot</span></li>
            <li>Chain Shot: <span class="neon-text-cyan">${this.player.ammo.chain} links</span></li>
            <li>Grape Shot: <span class="neon-text-orange">${this.player.ammo.grape} packs</span></li>
        `;
        
        content.innerHTML = `
            <div class="port-options">
                <div class="port-option active-option" onclick="Game.openMarket()">
                    <span class="option-tag">[M]</span>
                    <span class="option-desc neon-text-green">MERCHANT MARKET (Buy/Sell Cargo & Ammo)</span>
                </div>
                <div class="port-option active-option" onclick="Game.openTavern()">
                    <span class="option-tag">[T]</span>
                    <span class="option-desc neon-text-amber">TAVERN (Rumors & Gossip)</span>
                </div>
                <div class="port-option active-option" onclick="Game.openShipyard()">
                    <span class="option-tag">[S]</span>
                    <span class="option-desc neon-text-cyan">SHIPYARD (Upgrade Fleet / Buy Ships)</span>
                </div>
                <div class="divider"></div>
                <div class="port-option active-option" onclick="Game.undock()">
                    <span class="option-tag">[SPACE]</span>
                    <span class="option-desc blinking">SET SAIL!</span>
                </div>
            </div>

            <div class="port-status">
                <h3>SHIP MANIFEST</h3>
                <p>SHIP: <span class="neon-text-green">${this.player.shipName} (${this.player.shipClass.toUpperCase()})</span></p>
                <p>GOLD: <span class="neon-text-amber">${this.player.gold} Doubloons</span></p>
                <p>CARGO CARRIED: <span class="${totalCargo >= this.player.maxCargo ? 'neon-text-red' : 'neon-text-cyan'}">${totalCargo} / ${this.player.maxCargo}</span></p>
                <ul class="manifest-list">
                    ${manifestItemsHTML}
                </ul>
            </div>
        `;
    },

    openShipyard: function() {
        this.currentDockView = 'shipyard';
        this.renderShipyard();
    },

    renderShipyard: function() {
        const content = document.getElementById('portContent');
        const current = this.SHIP_CLASSES[this.player.shipClass] || this.SHIP_CLASSES.dinghy;
        
        let html = `
            <div class="market-view-container">
                <div class="market-header-row" style="grid-template-columns: 2fr 1.1fr 1.1fr 1.1fr 1fr 1.8fr;">
                    <span>VESSEL TYPE</span>
                    <span>SPEED</span>
                    <span>CARGO</span>
                    <span>HULL HP</span>
                    <span>GUNS</span>
                    <span>COMMISSION COST</span>
                </div>
                <div class="market-rows" style="max-height: 220px;">
        `;

        Object.keys(this.SHIP_CLASSES).forEach(classKey => {
            const ship = this.SHIP_CLASSES[classKey];
            const isOwned = this.player.shipClass === classKey;
            
            // Out of stock ships are hidden completely, unless active/owned
            const port = this.activePort;
            const inStock = port && port.shipStock && port.shipStock[classKey] > 0;
            if (!isOwned && !inStock) {
                return;
            }
            
            // Deltas
            const speedDiff = (ship.baseMaxSpeed - current.baseMaxSpeed).toFixed(1);
            let speedStr = `<span>${ship.baseMaxSpeed}</span>`;
            if (parseFloat(speedDiff) > 0) speedStr = `<span class="neon-text-green">${ship.baseMaxSpeed} (+${speedDiff})</span>`;
            if (parseFloat(speedDiff) < 0) speedStr = `<span class="neon-text-red">${ship.baseMaxSpeed} (${speedDiff})</span>`;

            const cargoDiff = ship.maxCargo - current.maxCargo;
            let cargoStr = `<span>${ship.maxCargo}</span>`;
            if (cargoDiff > 0) cargoStr = `<span class="neon-text-green">${ship.maxCargo} (+${cargoDiff})</span>`;
            if (cargoDiff < 0) cargoStr = `<span class="neon-text-red">${ship.maxCargo} (${cargoDiff})</span>`;

            const hpDiff = ship.maxHealth - current.maxHealth;
            let hpStr = `<span>${ship.maxHealth}</span>`;
            if (hpDiff > 0) hpStr = `<span class="neon-text-green">${ship.maxHealth} (+${hpDiff})</span>`;
            if (hpDiff < 0) hpStr = `<span class="neon-text-red">${ship.maxHealth} (${hpDiff})</span>`;

            const gunDiff = ship.firepower - current.firepower;
            let gunStr = `<span>${ship.firepower}</span>`;
            if (gunDiff > 0) gunStr = `<span class="neon-text-green">${ship.firepower} (+${gunDiff})</span>`;
            if (gunDiff < 0) gunStr = `<span class="neon-text-red">${ship.firepower} (${gunDiff})</span>`;

            let actionHTML = '';
            let costStr = '';
            
            if (isOwned) {
                costStr = `<span class="neon-text-green" style="font-weight: bold; text-shadow: 0 0 5px rgba(51, 255, 51, 0.4);">ACTIVE</span>`;
                actionHTML = `<button class="btn-trade btn-buy disabled" disabled>[ACTIVE]</button>`;
            } else {
                const validation = this.canUpgradeShip(this.player, classKey);
                const healthRatio = (this.player.health !== undefined && this.player.maxHealth) ? (this.player.health / this.player.maxHealth) : 1.0;
                const tradeInValue = Math.floor((current.cost || 0) * 0.7 * healthRatio);
                const upgradeCost = Math.max(0, ship.cost - tradeInValue);
                
                costStr = `<span class="neon-text-amber" style="font-weight: bold; text-shadow: 0 0 5px rgba(255, 170, 0, 0.4);" title="Cost: ${ship.cost} D, Trade-in: -${tradeInValue} D">${upgradeCost} D</span>`;
                
                if (validation.success) {
                    actionHTML = `<button class="btn-trade btn-buy active" onclick="Game.buyShip('${classKey}')">[COMMISSION]</button>`;
                } else {
                    if (validation.reason === "INSUFFICIENT GOLD") {
                        actionHTML = `<button class="btn-trade btn-buy disabled" disabled>[LOCKED]</button>`;
                    } else if (validation.reason === "CARGO HOLD OVERFLOW") {
                        actionHTML = `<button class="btn-trade btn-buy disabled" disabled style="color: var(--neon-red); border-color: var(--neon-red); text-shadow: 0 0 5px rgba(255,0,0,0.4);" title="Too much cargo to upgrade!">[OVERFLOW]</button>`;
                    } else {
                        actionHTML = `<button class="btn-trade btn-buy disabled" disabled>[LOCKED]</button>`;
                    }
                }
            }

            html += `
                <div class="market-row-item" style="grid-template-columns: 2fr 1.1fr 1.1fr 1.1fr 1fr 1.8fr; align-items: center; padding: 6px 10px;">
                    <span class="item-name" style="font-size: 0.85rem;">🛥️ ${ship.name}</span>
                    <span style="font-size: 0.8rem;">${speedStr}</span>
                    <span style="font-size: 0.8rem;">${cargoStr}</span>
                    <span style="font-size: 0.8rem;">${hpStr}</span>
                    <span style="font-size: 0.8rem;">${gunStr}</span>
                    <div style="display: flex; justify-content: space-between; align-items: center; width: 100%; padding-right: 5px;">
                        ${costStr}
                        ${actionHTML}
                    </div>
                </div>
            `;
        });

        html += `
                </div>
                
                <!-- shipyard transaction console -->
                <div class="market-console" id="shipyardConsole">
                    <p class="console-prompt neon-text-cyan">&gt; ROYAL DOCKYARD READY. VESSEL COMMISSIONING SYSTEMS ONLINE...</p>
                </div>

                <div class="market-footer">
                    <div class="market-telemetry">
                        <span>HULL: <span class="neon-text-green">${current.name.toUpperCase()}</span></span>
                        <span>GOLD: <span class="neon-text-amber">${this.player.gold} D</span></span>
                    </div>
                    <button class="btn-back" onclick="Game.renderDockMenu()">[ESC] RETURN TO DOCK</button>
                </div>
            </div>
        `;

        content.innerHTML = html;
    },

    buyShip: function(targetClass) {
        if (!this.isDocked || this.currentDockView !== 'shipyard') return;
        
        const validation = this.canUpgradeShip(this.player, targetClass);
        const consoleEl = document.getElementById('shipyardConsole');
        
        if (!validation.success) {
            if (consoleEl) {
                consoleEl.innerHTML = `<p class="console-prompt neon-text-red">&gt; TRANSACTION DENIED: ${validation.reason.toUpperCase()}</p>`;
            }
            AudioEngine.playBeep(200, 0.15);
            return;
        }
        
        // Execute transaction
        this.player.gold -= validation.cost;
        this.player.shipClass = targetClass;
        this.updatePlayerShipStats();
        this.player.health = Math.min(this.player.health, this.player.maxHealth);
        
        // Deplete stock at active port
        if (this.activePort) {
            if (!this.activePort.shipStock) {
                this.activePort.shipStock = {};
            }
            this.activePort.shipStock[targetClass] = 0;
            
            if (!this.depletedShipStock) {
                this.depletedShipStock = {};
            }
            const key = `${this.activePort.name}_${targetClass}`;
            this.depletedShipStock[key] = true;
        }
        
        if (consoleEl) {
            consoleEl.innerHTML = `<p class="console-prompt neon-text-green">&gt; DEED OF SALE CONFIRMED. WELCOME CAPTAIN OF THE ${this.SHIP_CLASSES[targetClass].name.toUpperCase()}!</p>`;
        }
        
        AudioEngine.playShoot(); // Celebrating broadside!
        
        // Re-render
        this.renderShipyard();
    },

    openTavern: function() {
        this.currentDockView = 'tavern';
        const content = document.getElementById('portContent');
        
        content.innerHTML = `
            <div class="tavern-view-container animate-flicker">
                <h3 class="neon-text-amber" style="margin-top: 0; letter-spacing: 1px;">THE SALTY TANKARD TAVERN</h3>
                <p style="font-size: 0.8rem; opacity: 0.8; margin-bottom: 15px;">A smoky hall filled with sailors, card players, and the smell of salted cod and cheap rum.</p>
                
                <div class="tavern-barkeep-panel">
                    <span style="font-size: 1.5rem;">🧑‍✈️</span>
                    <span class="neon-text-amber" style="font-weight: bold; letter-spacing: 1px;">THE BARKEEP</span>
                    
                    <div class="tavern-actions">
                        <button class="btn-tavern-action" onclick="Game.askBarkeep()">[R] CHAT WITH BARKEEP</button>
                        <button class="btn-tavern-action" onclick="Game.buyRound()">[B] BUY A ROUND (3 D)</button>
                    </div>
                </div>

                <div class="tavern-console" id="tavernConsole">
                    <span class="tavern-console-title">WHISPERS IN THE TAVERN:</span>
                    <p class="tavern-console-msg" id="tavernMessage">"Speak up, friend! What can I get ya?"</p>
                </div>

                <div class="market-footer" style="margin-top: 15px;">
                    <div>GOLD: <span class="neon-text-amber">${this.player.gold} D</span></div>
                    <button class="btn-back" onclick="Game.renderDockMenu()">[ESC] RETURN TO DOCK MENU</button>
                </div>
            </div>
        `;
    },

    askBarkeep: function() {
        AudioEngine.playBeep(800, 0.05);
        const gossip = [
            "Barkeep: 'The Spanish Main has been crawling with guard boats lately.'",
            "Barkeep: 'Some say there's treasure buried on Nassau Reef, but only fools go looking.'",
            "Barkeep: 'Mind the wind, cap'n. Sailing in irons will leave ya sitting duck for pirates!'",
            "Barkeep: 'The Smuggler's Run is a treacherous place. Watch out for shallow reefs!'",
            "Barkeep: 'I saw a three-masted galleon sail past yesterday. A beautiful sight, it was.'"
        ];
        const randomGossip = gossip[Math.floor(Math.random() * gossip.length)];
        document.getElementById('tavernMessage').innerText = randomGossip;
    },

    buyRound: function() {
        if (this.player.gold < 3) {
            AudioEngine.playBeep(180, 0.25);
            document.getElementById('tavernMessage').innerText = "Barkeep: 'Your purse is looking a bit light for buying rounds, mate!'";
            return;
        }
        this.player.gold -= 3;
        AudioEngine.playClink();
        
        // Update gold display in tavern footer
        const goldElements = document.querySelectorAll('.tavern-view-container .neon-text-amber');
        goldElements.forEach(el => {
            if (el.parentNode.innerHTML.includes('GOLD:')) {
                el.innerText = `${this.player.gold} D`;
            }
        });

        const rumor = this.RUMORS[Math.floor(Math.random() * this.RUMORS.length)];
        document.getElementById('tavernMessage').innerText = `Barkeep: 'Cheers, Cap'n! *clink* Here's a tip for ya: ${rumor}'`;
    },

    getDistanceToNearestPort: function() {
        if (!this.world.ports || this.world.ports.length === 0) return 9999;
        let minDist = Infinity;
        this.world.ports.forEach(port => {
            const dist = Math.hypot(this.player.x - port.x, this.player.z - port.z);
            if (dist < minDist) {
                minDist = dist;
            }
        });
        return minDist;
    },

    toggleMap: function() {
        if (this.isDocked) return;
        
        // Close inventory if open
        if (this.isInventoryOpen) {
            this.toggleInventory();
        }

        if (this.isMapOpen) {
            this.isMapOpen = false;
            document.getElementById('mapModal').classList.add('hidden');
            AudioEngine.playBeep(600, 0.05);
            return;
        }

        const dist = this.getDistanceToNearestPort();
        const errorEl = document.getElementById('mapErrorMsg');
        
        // Combat Proximity Lockout Check
        let hostilesClose = this.world.enemies.some(e => Math.hypot(e.x - this.player.x, e.z - this.player.z) < 160 && e.health > 0);
        if (hostilesClose) {
            AudioEngine.playBeep(180, 0.3);
            errorEl.innerText = `TRANSIT ERROR: HOSTILE VESSELS IN RANGE.\nREACH SAFE DISTANCE (> 160) TO PLOT SECTOR COURSE.`;
            errorEl.classList.remove('hidden');
            
            // Still open map, but with travel locked
            for (let i = 0; i < 3; i++) {
                const sectorEl = document.getElementById(`sector-${i}`);
                if (sectorEl) {
                    if (i === this.currentArchipelagoIndex) {
                        sectorEl.classList.add('active-sector');
                        const btnContainer = sectorEl.querySelector('.sector-btn-container');
                        if (btnContainer) {
                            btnContainer.innerHTML = `<span class="sector-status-tag neon-text-green">> ACTIVE LOC</span>`;
                        }
                    } else {
                        sectorEl.classList.remove('active-sector');
                        const btnContainer = sectorEl.querySelector('.sector-btn-container');
                        if (btnContainer) {
                            btnContainer.innerHTML = `<button class="btn-travel-action disabled" style="opacity: 0.5; cursor: not-allowed;" onclick="event.stopPropagation();">[LOCKED]</button>`;
                        }
                    }
                }
            }
            this.isMapOpen = true;
            document.getElementById('mapModal').classList.remove('hidden');
            AudioEngine.playBeep(880, 0.08);
            return;
        }

        if (dist < 50) {
            AudioEngine.playBeep(180, 0.3);
            errorEl.innerText = `TRANSIT ERROR: COASTAL REEF INTERFERENCE.\nREACH OPEN OCEAN (DISTANCE > 50) TO PLOT SECTOR COURSE. (CURRENT: ${dist.toFixed(1)})`;
            errorEl.classList.remove('hidden');
        } else {
            errorEl.classList.add('hidden');
        }

        for (let i = 0; i < 3; i++) {
            const sectorEl = document.getElementById(`sector-${i}`);
            if (sectorEl) {
                if (i === this.currentArchipelagoIndex) {
                    sectorEl.classList.add('active-sector');
                    const btnContainer = sectorEl.querySelector('.sector-btn-container');
                    if (btnContainer) {
                        btnContainer.innerHTML = `<span class="sector-status-tag neon-text-green">> ACTIVE LOC</span>`;
                    }
                } else {
                    sectorEl.classList.remove('active-sector');
                    const btnContainer = sectorEl.querySelector('.sector-btn-container');
                    if (btnContainer) {
                        if (dist < 50) {
                            btnContainer.innerHTML = `<button class="btn-travel-action disabled" style="opacity: 0.5; cursor: not-allowed;" onclick="event.stopPropagation();">[LOCKED]</button>`;
                        } else {
                            btnContainer.innerHTML = `<button class="btn-travel-action" onclick="Game.fastTravelTo(${i}); event.stopPropagation();">[FAST TRAVEL]</button>`;
                        }
                    }
                }
            }
        }

        this.isMapOpen = true;
        document.getElementById('mapModal').classList.remove('hidden');
        AudioEngine.playBeep(880, 0.08);
    },

    toggleInventory: function() {
        if (this.isDocked) return;
        
        if (this.isInventoryOpen) {
            this.isInventoryOpen = false;
            document.getElementById('inventoryModal').classList.add('hidden');
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(600, 0.05);
            return;
        }

        // Close map if open
        if (this.isMapOpen) {
            this.toggleMap();
        }

        this.isInventoryOpen = true;
        
        // Populate inventory fields dynamically
        const totalCargo = this.getTotalCargoCount(this.player);
        document.getElementById('invShipName').innerText = `${this.player.shipName} (${this.player.shipClass.toUpperCase()})`;
        document.getElementById('invGold').innerText = `${this.player.gold} Doubloons`;
        
        const cargoCarriedEl = document.getElementById('invCargoCarried');
        cargoCarriedEl.innerText = `${totalCargo} / ${this.player.maxCargo}`;
        if (totalCargo >= this.player.maxCargo) {
            cargoCarriedEl.className = 'neon-text-red';
        } else {
            cargoCarriedEl.className = 'neon-text-cyan';
        }
        
        const labels = {
            rum: { name: 'Rum', suffix: 'barrels' },
            sugar: { name: 'Sugar', suffix: 'crates' },
            spices: { name: 'Spices', suffix: 'sacks' },
            tobacco: { name: 'Tobacco', suffix: 'bundles' },
            coffee: { name: 'Coffee', suffix: 'bags' },
            cocoa: { name: 'Cocoa', suffix: 'beans' },
            textiles: { name: 'Textiles', suffix: 'bolts' },
            wood: { name: 'Wood', suffix: 'logs' }
        };

        let manifestItemsHTML = '';
        for (const item in this.player.cargo) {
            const count = this.player.cargo[item] || 0;
            if (count > 0 && labels[item]) {
                manifestItemsHTML += `<li>${labels[item].name}: <span class="neon-text-green">${count} ${labels[item].suffix}</span></li>`;
            }
        }
        
        if (!manifestItemsHTML) {
            manifestItemsHTML = `<li style="opacity: 0.5;">[No commodities held]</li>`;
        }

        manifestItemsHTML += `
            <li style="border-top: 1px dashed rgba(0,255,255,0.2); padding-top: 4px; margin-top: 4px;">Ball Shot: <span class="neon-text-yellow">${this.player.ammo.ball} shot</span></li>
            <li>Chain Shot: <span class="neon-text-cyan">${this.player.ammo.chain} links</span></li>
            <li>Grape Shot: <span class="neon-text-orange">${this.player.ammo.grape} packs</span></li>
        `;

        document.getElementById('invManifestList').innerHTML = manifestItemsHTML;
        document.getElementById('inventoryModal').classList.remove('hidden');
        if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(880, 0.05);
    },

    fastTravelTo: function(archIndex) {
        if (archIndex === this.currentArchipelagoIndex) {
            AudioEngine.playBeep(300, 0.1);
            return;
        }

        const dist = this.getDistanceToNearestPort();
        if (dist < 50) {
            AudioEngine.playBeep(180, 0.3);
            return;
        }

        // Hostile proximity double check
        let hostilesClose = this.world.enemies.some(e => Math.hypot(e.x - this.player.x, e.z - this.player.z) < 160 && e.health > 0);
        if (hostilesClose) {
            AudioEngine.playBeep(180, 0.3);
            return;
        }

        this.isMapOpen = false;
        document.getElementById('mapModal').classList.add('hidden');

        this.startTravelSequence(archIndex);
    },

    startTravelSequence: function(targetIndex) {
        this.travelSourceIndex = this.currentArchipelagoIndex;
        this.travelTargetIndex = targetIndex;
        this.travelProgress = 0;
        this.travelDuration = 4.5;
        
        // 25% chance of radar intercept between 30% and 70% progress
        this.willIntercept = Math.random() < 0.25;
        if (this.willIntercept) {
            this.interceptProgress = 0.3 + Math.random() * 0.4;
        } else {
            this.interceptProgress = 9.9;
        }
        
        document.getElementById('travelModal').classList.remove('hidden');
        
        this.isTraveling = true;
        this.player.speed = 0;
        this.player.sailLevel = 0;
        
        const routes = {
            '0-1': ['CROSSING WINDWARD PASSAGE', 'AVOIDING IMPERIAL PATROLS', 'ENTERING THE SPANISH MAIN'],
            '1-0': ['LEAVING IMPERIAL WATERS', 'NAVIGATING SHALLOW REEFS', 'APPROACHING PIRATE\'S CRADLE'],
            '1-2': ['SAILING SOUTH-EAST PASSAGE', 'CIRCUMVENTING ROUGH CURRENTS', 'REACHING SMUGGLER\'S RUN'],
            '2-1': ['LEAVING SMUGGLER\'S REEFS', 'PASSING VOLCANIC ATOLLS', 'ENTERING THE SPANISH MAIN'],
            '0-2': ['SAILING THE OPEN CARIBBEAN', 'CHARTING UNEXPLORED SEAS', 'ENTERING SMUGGLER\'S RUN'],
            '2-0': ['WESTWARD GALE FORCE RUN', 'AVOIDING COAT-TAIL PIRATES', 'APPROACHING PIRATE\'S CRADLE']
        };
        const key = `${this.travelSourceIndex}-${this.travelTargetIndex}`;
        this.travelLogPhrases = routes[key] || ['PLOTING SECTOR VECTOR', 'ENGAGING RETRO COUPLERS', 'TRANSIT SUCCESS'];
        
        this.lastTravelTime = performance.now();
        this.lastPingPct = -0.1;
        
        AudioEngine.playTravelSweep(0);

        this.tickTravelSequence();
    },

    tickTravelSequence: function() {
        if (!this.isTraveling) return;

        const now = performance.now();
        const dt = (now - this.lastTravelTime) / 1000;
        this.lastTravelTime = now;

        this.travelProgress += dt / this.travelDuration;

        // Check for radar intercepts
        if (this.willIntercept && this.travelProgress >= this.interceptProgress) {
            this.triggerRadarIntercept();
            return;
        }

        if (this.travelProgress >= 1.0) {
            this.travelProgress = 1.0;
            this.completeTravelSequence();
            return;
        }

        const currentPingPct = Math.floor(this.travelProgress * 10) / 10;
        if (currentPingPct > this.lastPingPct) {
            this.lastPingPct = currentPingPct;
            AudioEngine.playTravelSweep(this.travelProgress);
        }

        this.drawTravelCanvas();

        const pctText = `${Math.round(this.travelProgress * 100)}%`;
        document.getElementById('travelProgressPct').innerText = pctText;
        document.getElementById('travelProgressBar').style.width = pctText;

        const consoleEl = document.getElementById('travelConsole');
        const phaseIdx = Math.min(this.travelLogPhrases.length - 1, Math.floor(this.travelProgress * this.travelLogPhrases.length));
        const phrase = this.travelLogPhrases[phaseIdx];
        consoleEl.innerHTML = `<p class="travel-log">&gt; ${phrase} (${pctText})...</p>`;

        requestAnimationFrame(() => this.tickTravelSequence());
    },

    drawTravelCanvas: function() {
        const canvas = document.getElementById('travelCanvas');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        const w = canvas.width;
        const h = canvas.height;

        ctx.fillStyle = '#020402';
        ctx.fillRect(0, 0, w, h);

        const coords = [
            { x: 60, y: 100, name: "SEC A-1" },
            { x: 180, y: 40, name: "SEC B-2" },
            { x: 300, y: 110, name: "SEC C-3" }
        ];

        ctx.strokeStyle = 'rgba(51, 255, 51, 0.15)';
        ctx.lineWidth = 1;
        ctx.setLineDash([4, 6]);

        ctx.beginPath();
        ctx.moveTo(coords[0].x, coords[0].y);
        ctx.lineTo(coords[1].x, coords[1].y);
        ctx.lineTo(coords[2].x, coords[2].y);
        ctx.lineTo(coords[0].x, coords[0].y);
        ctx.stroke();

        const src = coords[this.travelSourceIndex];
        const tgt = coords[this.travelTargetIndex];

        ctx.strokeStyle = 'rgba(51, 255, 51, 0.6)';
        ctx.lineWidth = 2;
        ctx.setLineDash([6, 6]);
        ctx.beginPath();
        ctx.moveTo(src.x, src.y);
        ctx.lineTo(tgt.x, tgt.y);
        ctx.stroke();
        ctx.setLineDash([]);

        coords.forEach((c, idx) => {
            const isActive = idx === this.travelSourceIndex || idx === this.travelTargetIndex;
            
            ctx.strokeStyle = isActive ? '#33ff33' : 'rgba(51, 255, 51, 0.4)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.arc(c.x, c.y, 6, 0, Math.PI * 2);
            ctx.stroke();

            ctx.fillStyle = isActive ? '#33ff33' : 'rgba(51, 255, 51, 0.4)';
            ctx.beginPath();
            ctx.arc(c.x, c.y, 2, 0, Math.PI * 2);
            ctx.fill();

            ctx.font = '8px "Share Tech Mono", monospace';
            ctx.fillStyle = isActive ? '#33ff33' : 'rgba(51, 255, 51, 0.4)';
            ctx.fillText(c.name, c.x - 18, c.y - 10);
        });

        const shipX = src.x + (tgt.x - src.x) * this.travelProgress;
        const shipY = src.y + (tgt.y - src.y) * this.travelProgress;

        const dx = tgt.x - src.x;
        const dy = tgt.y - src.y;
        const angle = Math.atan2(dy, dx);

        const isVisible = Math.floor(performance.now() / 250) % 2 === 0;

        if (isVisible) {
            ctx.save();
            ctx.translate(shipX, shipY);
            ctx.rotate(angle + Math.PI/2);
            
            ctx.fillStyle = '#00ffff';
            ctx.shadowColor = '#00ffff';
            ctx.shadowBlur = 6;
            
            ctx.beginPath();
            ctx.moveTo(0, -6);
            ctx.lineTo(-4, 4);
            ctx.lineTo(4, 4);
            ctx.closePath();
            ctx.fill();
            
            ctx.restore();
        }
    },

    completeTravelSequence: function() {
        this.isTraveling = false;
        
        document.getElementById('travelModal').classList.add('hidden');
        
        this.marketTravelCount = (this.marketTravelCount || 0) + 1;
        
        this.loadArchipelago(this.travelTargetIndex, true);
        
        AudioEngine.playBeep(880, 0.15);
        setTimeout(() => {
            AudioEngine.playBeep(1100, 0.2);
        }, 100);

        this.player.sailLevel = 2;
        this.player.collisionImmunityTimer = 4.0;
    },

    loadArchipelago: function(archIndex, resetPlayerCoords, skipEnemySpawn = false) {
        this.currentArchipelagoIndex = archIndex;
        const arch = this.ARCHIPELAGOS[archIndex];
        
        this.world.ports = JSON.parse(JSON.stringify(arch.ports));
        
        this.world.ports.forEach((port, idx) => {
            port.prices = this.calculatePortPrices(port);

            // Deterministic pseudo-random seed to give each port unique, stable stocks
            const seedVal = port.name.charCodeAt(0) + (port.name.charCodeAt(port.name.length - 1) || 0) + idx;
            const ballChance = (seedVal % 10) / 10;
            const chainChance = ((seedVal * 3) % 10) / 10;
            const grapeChance = ((seedVal * 7) % 10) / 10;

            port.ammoStock = {
                ball: ballChance < 0.75 ? 8 + (seedVal % 15) : 0,
                chain: chainChance < 0.50 ? 4 + (seedVal % 8) : 0,
                grape: grapeChance < 0.40 ? 3 + (seedVal % 6) : 0
            };

            port.shipStock = {};
            Object.keys(this.SHIP_CLASSES).forEach(classKey => {
                if (classKey === 'dinghy') {
                    port.shipStock[classKey] = 1;
                    return;
                }
                const seedStr = port.name + "_" + classKey;
                let hash = 0;
                for (let i = 0; i < seedStr.length; i++) {
                    hash = (hash * 31 + seedStr.charCodeAt(i)) | 0;
                }
                const randVal = Math.abs(hash % 1000) / 1000;
                
                let chance = 0.0;
                if (classKey === 'schooner' || classKey === 'sloop') {
                    chance = 0.35;
                } else if (classKey === 'clipper' || classKey === 'brigantine') {
                    chance = 0.25;
                } else if (classKey === 'frigate' || classKey === 'galleon' || classKey === 'carrack') {
                    chance = 0.15;
                } else if (classKey === 'manofwar') {
                    chance = 0.08;
                }
                
                port.shipStock[classKey] = randVal < chance ? 1 : 0;
            });

            if (this.depletedShipStock) {
                Object.keys(this.SHIP_CLASSES).forEach(classKey => {
                    const key = `${port.name}_${classKey}`;
                    if (this.depletedShipStock[key]) {
                        port.shipStock[classKey] = 0;
                    }
                });
            }

            port.model = Models3D.generateIsland(1234 + idx * 567, port.size, port.height, 5, 12);
        });

        if (resetPlayerCoords) {
            this.player.x = 0;
            this.player.y = 0;
            this.player.z = 0;
            this.player.speed = 0;
            this.player.sailLevel = 0;
            this.player.yaw = 0;
            this.player.rudder = 0;
        }

        if (!skipEnemySpawn) {
            this.world.enemies = [];
            this.world.projectiles = [];
            this.world.splashes = [];
            this.world.debris = [];

            // Spawn normal pirates scaled by sector difficulty!
            let numPirates = 0;
            if (this.currentArchipelagoIndex === 0) {
                // Easy sector: Low chance (40% chance of 1 pirate, 60% chance of 0 pirates)
                numPirates = Math.random() < 0.4 ? 1 : 0;
            } else if (this.currentArchipelagoIndex === 1) {
                // Medium sector: Normal chance (exactly 1 pirate)
                numPirates = 1;
            } else {
                // Hard sector (Smuggler's Run): High threat (2 to 3 pirates)
                numPirates = 2 + Math.floor(Math.random() * 2);
            }

            for (let i = 0; i < numPirates; i++) {
                this.spawnPirateShip();
            }
        }

        document.getElementById('hudZone').innerText = arch.name;
    },

    openMarket: function() {
        this.currentDockView = 'market';
        this.renderMarket();
    },

    renderMarket: function() {
        const content = document.getElementById('portContent');
        const port = this.activePort;
        const totalCargo = this.getTotalCargoCount(this.player);
        
        let marketHTML = `
            <div class="market-view-container">
                <div class="market-header-row">
                    <span>COMMODITY</span>
                    <span>LOCAL BUY</span>
                    <span>LOCAL SELL</span>
                    <span>CARGO HELD</span>
                    <span>ACTIONS</span>
                </div>
                <div class="market-rows">
        `;

        const commodities = ['rum', 'sugar', 'tobacco', 'spices', 'coffee', 'cocoa', 'textiles', 'wood'];
        const labels = {
            rum: { name: 'Rum (barrels)', icon: '🥃' },
            sugar: { name: 'Sugar (crates)', icon: '🍬' },
            spices: { name: 'Spices (sacks)', icon: '🌶️' },
            tobacco: { name: 'Tobacco (bundles)', icon: '🍂' },
            coffee: { name: 'Coffee (bags)', icon: '☕' },
            cocoa: { name: 'Cocoa (beans)', icon: '🍫' },
            textiles: { name: 'Textiles (bolts)', icon: '🧣' },
            wood: { name: 'Wood (logs)', icon: '🪵' }
        };

        commodities.forEach(item => {
            if (!port.prices || !port.prices[item]) return; // Skip commodities not traded at this port!
            const price = port.prices[item];
            const held = this.player.cargo[item] || 0;
            const isProd = price.isProducer;
            const isCons = price.isConsumer;
            
            // Check affordability & capacity using canBuyCargo
            const validation = this.canBuyCargo(this.player, item, price.buy);
            const canBuy = validation.success;
            const canSell = held > 0;

            let badge = '';
            if (isProd) {
                badge = '<span class="producer-badge" style="background-color: #33ff33; color: #000; font-size: 8px; font-weight: bold; padding: 1px 3px; margin-left: 5px; border-radius: 2px;">PROD</span>';
            } else if (isCons) {
                badge = '<span class="consumer-badge" style="background-color: #ff3366; color: #fff; font-size: 8px; font-weight: bold; padding: 1px 3px; margin-left: 5px; border-radius: 2px;">CONS</span>';
            }

            marketHTML += `
                <div class="market-row-item">
                    <span class="item-name">${labels[item].icon} ${labels[item].name} ${badge}</span>
                    <span class="price-buy neon-text-cyan">${price.buy} D</span>
                    <span class="price-sell neon-text-amber">${price.sell} D</span>
                    <span class="qty-held ${held > 0 ? 'neon-text-green' : ''}">${held}</span>
                    <div class="action-buttons">
                        <button class="btn-trade btn-buy ${canBuy ? 'active' : 'disabled'}" onclick="Game.buyCargo('${item}')" ${canBuy ? '' : 'disabled'}>[BUY]</button>
                        <button class="btn-trade btn-sell ${canSell ? 'active' : 'disabled'}" onclick="Game.sellCargo('${item}')" ${canSell ? '' : 'disabled'}>[SELL]</button>
                    </div>
                </div>
            `;
        });

        // Add Ammunition and Refitting section (Selling ammo price is strictly 0!)
        const ammoTypes = ['ball', 'chain', 'grape'];
        const ammoLabels = {
            ball: { name: 'Ball Shot', icon: '⚽', buy: 2, sell: 0 },
            chain: { name: 'Chain Shot', icon: '⛓️', buy: 5, sell: 0 },
            grape: { name: 'Grape Shot', icon: '🍇', buy: 8, sell: 0 }
        };

        marketHTML += `
            <div class="market-divider" style="border-top: 1px dashed rgba(51, 255, 51, 0.3); margin: 6px 0; padding: 6px 10px; font-size: 0.75rem; color: var(--neon-amber); font-weight: bold; text-shadow: 0 0 5px rgba(255, 170, 0, 0.3); text-align: left;">
                &gt; AMMUNITION & REFITTING
            </div>
        `;

        ammoTypes.forEach(ammo => {
            const label = ammoLabels[ammo];
            const buyPrice = label.buy;
            const sellPrice = label.sell;
            const held = this.player.ammo[ammo] || 0;
            const portStock = (port.ammoStock && port.ammoStock[ammo] !== undefined) ? port.ammoStock[ammo] : 0;
            
            // Check affordability & capacity using canBuyCargo
            const validation = this.canBuyCargo(this.player, ammo, buyPrice);
            const canBuy = validation.success && portStock > 0;
            const canSell = held > 0;
            
            const stockText = portStock > 0 ? `${portStock} avail` : '<span class="neon-text-red">[OUT OF STOCK]</span>';
            
            marketHTML += `
                <div class="market-row-item">
                    <span class="item-name">${label.icon} ${label.name} <span style="font-size: 8px; opacity: 0.6; color: #00ffcc; margin-left: 5px;">(${stockText})</span></span>
                    <span class="price-buy neon-text-cyan">${buyPrice} D</span>
                    <span class="price-sell neon-text-amber">${sellPrice} D</span>
                    <span class="qty-held ${held > 0 ? 'neon-text-green' : ''}">${held}</span>
                    <div class="action-buttons">
                        <button class="btn-trade btn-buy ${canBuy ? 'active' : 'disabled'}" onclick="Game.buyCargo('${ammo}')" ${canBuy ? '' : 'disabled'}>[BUY]</button>
                        <button class="btn-trade btn-sell ${canSell ? 'active' : 'disabled'}" onclick="Game.sellCargo('${ammo}')" ${canSell ? '' : 'disabled'}>[SELL]</button>
                    </div>
                </div>
            `;
        });

        marketHTML += `
                </div>
                
                <!-- Blinking Terminal Transaction Log Console -->
                <div class="market-console" id="marketConsole">
                    <p class="console-prompt">&gt; READY FOR TRADE. SELECT COMMODITY...</p>
                </div>

                <div class="market-footer">
                    <div class="market-telemetry">
                        <span>GOLD: <span class="neon-text-amber">${this.player.gold} D</span></span>
                        <span>HOLD WEIGHT: <span class="${totalCargo >= this.player.maxCargo ? 'neon-text-red' : 'neon-text-cyan'}">${totalCargo} / ${this.player.maxCargo}</span></span>
                    </div>
                    <button class="btn-back" onclick="Game.renderDockMenu()">[ESC] RETURN TO DOCK MENU</button>
                </div>
            </div>
        `;
        
        content.innerHTML = marketHTML;
    },

    buyCargo: function(item) {
        if (!this.isDocked || this.currentDockView !== 'market') return;
        const port = this.activePort;
        
        const isAmmo = ['ball', 'chain', 'grape'].includes(item);
        const ammoLabels = {
            ball: { name: 'Ball Shot', buy: 2, sell: 0 },
            chain: { name: 'Chain Shot', buy: 5, sell: 0 },
            grape: { name: 'Grape Shot', buy: 8, sell: 0 }
        };
        
        const price = isAmmo ? ammoLabels[item].buy : (port.prices[item] ? port.prices[item].buy : 9999);

        // Validation for stock if it is ammo
        if (isAmmo) {
            const portStock = (port.ammoStock && port.ammoStock[item] !== undefined) ? port.ammoStock[item] : 0;
            if (portStock <= 0) {
                this.logMarketTransaction(`TRANSACTION FAILED: ${ammoLabels[item].name.toUpperCase()} IS OUT OF STOCK!`, true);
                if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) {
                    AudioEngine.playBeep(180, 0.25);
                }
                return;
            }
        }

        const validation = this.canBuyCargo(this.player, item, price);
        if (!validation.success) {
            this.logMarketTransaction(validation.reason, true);
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) {
                AudioEngine.playBeep(180, 0.25); // Warning beep
            }
            return;
        }

        // Complete transaction
        this.player.gold -= price;
        if (isAmmo) {
            this.player.ammo[item]++;
            if (port.ammoStock && port.ammoStock[item] !== undefined) {
                port.ammoStock[item]--;
            }
            this.logMarketTransaction(`TRANSACTION SUCCESS: BOUGHT 1 UNIT OF ${ammoLabels[item].name.toUpperCase()} FOR ${price} D`);
        } else {
            this.player.cargo[item]++;
            this.logMarketTransaction(`TRANSACTION SUCCESS: BOUGHT 1 UNIT OF ${item.toUpperCase()} FOR ${price} D`);
        }
        
        if (typeof AudioEngine !== 'undefined' && AudioEngine.playCoin) {
            AudioEngine.playCoin(); // Coin sound
        }
        
        // Re-render market view to update buttons and state
        this.renderMarket();
    },

    sellCargo: function(item) {
        if (!this.isDocked || this.currentDockView !== 'market') return;
        const port = this.activePort;
        
        const isAmmo = ['ball', 'chain', 'grape'].includes(item);
        const ammoLabels = {
            ball: { name: 'Ball Shot', buy: 2, sell: 0 },
            chain: { name: 'Chain Shot', buy: 5, sell: 0 },
            grape: { name: 'Grape Shot', buy: 8, sell: 0 }
        };
        
        const price = isAmmo ? ammoLabels[item].sell : (port.prices[item] ? port.prices[item].sell : 0);

        // Validation for stock/held
        const held = isAmmo ? (this.player.ammo[item] || 0) : (this.player.cargo[item] || 0);
        if (held <= 0) {
            this.logMarketTransaction(`TRANSACTION FAILED: NO ${isAmmo ? ammoLabels[item].name.toUpperCase() : item.toUpperCase()} HELD TO SELL!`, true);
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) {
                AudioEngine.playBeep(180, 0.25); // Warning beep
            }
            return;
        }

        // Complete transaction
        this.player.gold += price;
        if (isAmmo) {
            this.player.ammo[item]--;
            if (port.ammoStock && port.ammoStock[item] !== undefined) {
                port.ammoStock[item]++;
            }
            this.logMarketTransaction(`TRANSACTION SUCCESS: SOLD 1 UNIT OF ${ammoLabels[item].name.toUpperCase()} FOR ${price} D`);
        } else {
            this.player.cargo[item]--;
            this.logMarketTransaction(`TRANSACTION SUCCESS: SOLD 1 UNIT OF ${item.toUpperCase()} FOR ${price} D`);
        }
        
        if (typeof AudioEngine !== 'undefined' && AudioEngine.playCoin) {
            AudioEngine.playCoin(); // Coin sound
        }
        
        // Re-render market view
        this.renderMarket();
    },

    logMarketTransaction: function(message, isError = false) {
        const consoleEl = document.getElementById('marketConsole');
        if (consoleEl) {
            const colorClass = isError ? 'neon-text-red' : 'neon-text-green';
            consoleEl.innerHTML = `<p class="console-prompt ${colorClass} animate-flicker">&gt; ${message}</p>`;
        }
    },

    // Main updates
    update: function(dt) {
        if (this.isDocked || this.isTraveling) return;

        this.time += dt;

        // 1. Wind Angle Drift Simulation
        this.wind.changeTimer -= dt;
        if (this.wind.changeTimer <= 0) {
            this.wind.targetAngle = Math.random() * Math.PI * 2;
            this.wind.changeTimer = 25 + Math.random() * 30; // Shift every 25-55s
        }
        // Smoothly rotate wind angle
        this.wind.angle = this.calculateNextWindAngle(this.wind.angle, this.wind.targetAngle, 0.02);

        // 2. Process Sail & Steering Key Presses
        if (this.keys.w) {
            // Increase sails
            this.player.sailLevel = Math.min(4, this.player.sailLevel + 0.05);
            this.keys.w = false; // Trigger once per tap
            AudioEngine.playBeep(900, 0.02);
        }
        if (this.keys.s) {
            // Decrease sails
            this.player.sailLevel = Math.max(0, this.player.sailLevel - 0.05);
            this.keys.s = false; // Trigger once per tap
            AudioEngine.playBeep(700, 0.02);
        }

        // Steering Rudder (snappy rudder response & centering)
        if (this.keys.a) {
            this.player.rudder = Math.max(-1.0, this.player.rudder - 0.18);
        } else if (this.keys.d) {
            this.player.rudder = Math.min(1.0, this.player.rudder + 0.18);
        } else {
            this.player.rudder *= 0.6; // Rapid self-centering rudder
        }

        // Steer heading (snappy arcade steering with responsive minimum turn rate)
        const turnFactor = 1.8 + this.player.speed * 0.45;
        this.player.yaw += this.player.rudder * turnFactor * 0.22 * dt;

        // 3. Apply Sailing physics (Tacking & Drag)
        const windEfficiency = this.getSailingEfficiency();
        const sailPercent = this.player.sailLevel / 4;

        // Decay speed debuff timer
        if (this.player.speedDebuffTimer > 0) {
            this.player.speedDebuffTimer -= dt;
        }

        // Decay island collision immunity timer
        if (this.player.collisionImmunityTimer > 0) {
            this.player.collisionImmunityTimer -= dt;
        }

        let activeMaxSpeed = this.player.baseMaxSpeed;
        if (this.player.speedDebuffTimer > 0) {
            activeMaxSpeed *= 0.5; // 50% speed penalty when rigging/sails are shredded by Chain shot
        }
        const targetSpeed = activeMaxSpeed * sailPercent * windEfficiency;

        // Inertia transition
        this.player.speed += (targetSpeed - this.player.speed) * 0.04 * dt;

        // Update positions (with predictive island collision solver)
        const nextX = this.player.x + Math.sin(this.player.yaw) * this.player.speed * dt;
        const nextZ = this.player.z + Math.cos(this.player.yaw) * this.player.speed * dt;

        let collided = false;
        if (this.world && this.world.ports && !(this.player.collisionImmunityTimer > 0)) {
            const stats = this.SHIP_CLASSES[this.player.shipClass] || {};
            const shipRadius = stats.hitRadius || 4.0;
            
            for (let i = 0; i < this.world.ports.length; i++) {
                const port = this.world.ports[i];
                const dist = Math.hypot(port.x - nextX, port.z - nextZ);
                const collisionThreshold = port.size + shipRadius - 2.0;
                
                if (dist < collisionThreshold) {
                    collided = true;
                    
                    // Bounce back
                    this.player.speed = -2.5;
                    this.player.collisionImmunityTimer = 3.0;
                    
                    // Apply HP damage (-10 HP)
                    this.applyShipDamage(this.player, 10);
                    
                    // Spawn physical crash debris
                    this.spawnHitDebris(this.player.x, this.player.y + 1.5, this.player.z, 12);
                    
                    // Play explosion audio
                    if (typeof AudioEngine !== 'undefined' && AudioEngine.playExplosion) {
                        AudioEngine.playExplosion();
                    }
                    
                    // HTML run-aground emergency banner
                    this.showCollisionAlert();
                    break;
                }
            }
        }

        if (!collided) {
            this.player.x = nextX;
            this.player.z = nextZ;
        }

        // Update ambient wind synth pitch depending on sail speed
        AudioEngine.updateWindFrequency(this.player.speed / this.player.baseMaxSpeed);

        // 4. Riding the waves
        // Get the undulating ocean height function from engine
        const getWaveHeight = (x, z) => {
            const w1 = Math.sin(x * 0.05 + this.time * 1.5) * Math.cos(z * 0.05 + this.time * 1.2) * 1.6;
            const w2 = Math.sin(z * 0.12 - this.time * 2.0) * 0.5;
            return w1 + w2;
        };

        const px = this.player.x;
        const pz = this.player.z;
        this.player.y = getWaveHeight(px, pz);

        // Calculate 3D Pitch (slope along ship length)
        const bowDist = 2.0;
        const bowY = getWaveHeight(px + Math.sin(this.player.yaw) * bowDist, pz + Math.cos(this.player.yaw) * bowDist);
        const sternY = getWaveHeight(px - Math.sin(this.player.yaw) * bowDist, pz - Math.cos(this.player.yaw) * bowDist);
        this.player.pitch = (bowY - sternY) / (bowDist * 2);

        // Calculate 3D Roll (slope along ship width + centrifugal force!)
        const portDist = 1.0;
        const portY = getWaveHeight(px + Math.sin(this.player.yaw + Math.PI/2) * portDist, pz + Math.cos(this.player.yaw + Math.PI/2) * portDist);
        const stbdY = getWaveHeight(px + Math.sin(this.player.yaw - Math.PI/2) * portDist, pz + Math.cos(this.player.yaw - Math.PI/2) * portDist);
        // Ship tilts outward on sharp turns at high speed!
        const turnRoll = -this.player.rudder * this.player.speed * 0.08;
        this.player.roll = ((portY - stbdY) / (portDist * 2)) + turnRoll;

        // 5. Update Camera Chase Mechanics (Spherical Free Orbit Camera)
        const shipStats = this.SHIP_CLASSES[this.player.shipClass] || this.SHIP_CLASSES.dinghy;
        const r = 11.5 + (shipStats.hitRadius * 1.5); // Radius of orbit dynamically scaled by ship size
        const basePitch = 0.30; // Default vertical angle (~17 degrees, tilted higher for more horizon)
        const finalPitch = Math.max(0.05, Math.min(1.2, basePitch + this.mouse.pitch)); // limit vertical orbit
        const finalYaw = this.player.yaw + this.mouse.yaw;

        const targetCamX = this.player.x - Math.sin(finalYaw) * r * Math.cos(finalPitch);
        const targetCamZ = this.player.z - Math.cos(finalYaw) * r * Math.cos(finalPitch);
        const targetCamY = this.player.y + r * Math.sin(finalPitch) + Math.sin(this.time * 0.8) * 0.15; // Camera ocean bobbing

        // Camera spring lag (frame-rate independent easing)
        const ease = 1 - Math.exp(-6 * dt);
        Engine3D.camera.x += (targetCamX - Engine3D.camera.x) * ease;
        Engine3D.camera.z += (targetCamZ - Engine3D.camera.z) * ease;
        Engine3D.camera.y += (targetCamY - Engine3D.camera.y) * ease;

        // Decay camera orbit offsets back to 0 when not dragging or aiming
        if (!this.mouse.isDragging && !this.mouse.isAiming) {
            // Normalize yaw to [-PI, PI] for shortest-path decay wrapping
            while (this.mouse.yaw < -Math.PI) this.mouse.yaw += Math.PI * 2;
            while (this.mouse.yaw > Math.PI) this.mouse.yaw -= Math.PI * 2;

            // Decay speed (fast if steering, slow if cruising straight)
            const isSteering = this.keys.a || this.keys.d;
            const decayRate = isSteering ? 2.8 : 0.45;
            const easeFactor = 1 - Math.exp(-decayRate * dt);
            
            this.mouse.yaw += (0 - this.mouse.yaw) * easeFactor;
            this.mouse.pitch += (0 - this.mouse.pitch) * easeFactor;
        }

        // Look-At Rotation: Aim slightly ABOVE the ship to push the vessel toward the lower third of the screen!
        const targetLookY = this.player.y + (shipStats.hitHeight * 0.35); // Offset vertically to frame ship beautifully based on ship height
        const dx = this.player.x - Engine3D.camera.x;
        const dz = this.player.z - Engine3D.camera.z;
        const flatDist = Math.hypot(dx, dz);

        Engine3D.camera.yaw = Math.atan2(dx, dz);
        // Tilt slightly down to look at the framing target
        Engine3D.camera.pitch = Math.atan2(Engine3D.camera.y - targetLookY, flatDist);
        // Blend wave-rolling tilt for screen momentum
        Engine3D.camera.roll = this.player.roll * 0.3;

        // 6. Recycle 3D spatial particles around player
        this.world.particles.forEach(p => {
            const dx = p.x - this.player.x;
            const dz = p.z - this.player.z;
            // If particle is too far behind, warp it ahead
            if (dx < -150) p.x += 300;
            if (dx > 150) p.x -= 300;
            if (dz < -150) p.z += 300;
            if (dz > 150) p.z -= 300;
            // Animate particle slightly on waves
            p.y = getWaveHeight(p.x, p.z) - 0.5;
        });

        // 7. Check Port Proximities
        this.activePort = null;
        this.world.ports.forEach(port => {
            const dist = Math.hypot(port.x - this.player.x, port.z - this.player.z);
            if (dist < port.size + 15) {
                this.activePort = port;
            }
        });

        // 8. Combat, Threat and Alerts Updates
        // Low health CRT red border
        if (this.player.health < this.player.maxHealth * 0.3) {
            document.body.classList.add('low-health');
        } else {
            document.body.classList.remove('low-health');
        }

        // Blinking amber Harbor Security warning banner
        const distToPort = this.getDistanceToNearestPort();
        const noFireBanner = document.getElementById('noFireWarning');
        if (distToPort < 120) {
            noFireBanner.classList.remove('hidden');
        } else {
            noFireBanner.classList.add('hidden');
        }

        // Active Target overlay tracking
        const targetOverlay = document.getElementById('targetOverlay');
        if (this.activeTarget && this.activeTarget.health > 0) {
            targetOverlay.classList.remove('hidden');
            
            // Determine faction
            const factionType = this.activeTarget.isEnforcer ? 'authority' : 'pirate';
            const faction = this.FACTIONS[factionType];
            
            // 1. Update target panel border/shadow theme
            targetOverlay.classList.remove('theme-red', 'theme-blue', 'theme-green', 'theme-amber');
            targetOverlay.classList.add(faction.themeClass);
            
            // 2. Update target header text class
            const targetHeader = targetOverlay.querySelector('.target-header');
            if (targetHeader) {
                targetHeader.classList.remove('neon-text-red', 'neon-text-blue', 'neon-text-green', 'neon-text-amber');
                targetHeader.classList.add(faction.textClass);
            }
            
            // 3. Update target name and HP text classes
            const targetNameEl = document.getElementById('targetName');
            targetNameEl.innerText = this.activeTarget.isEnforcer ? 'PORT AUTHORITY GALLEON' : 'PIRATE SLOOP';
            
            const targetHPEl = document.getElementById('targetHP');
            const hpPercent = Math.round((this.activeTarget.health / this.activeTarget.maxHealth) * 100);
            targetHPEl.innerText = `${hpPercent}%`;
            targetHPEl.classList.remove('neon-text-red', 'neon-text-blue', 'neon-text-green', 'neon-text-amber');
            targetHPEl.classList.add(faction.textClass);
            
            // 4. Update target HP progress bar background classes
            const targetHPBar = document.getElementById('targetHPBar');
            targetHPBar.style.width = `${hpPercent}%`;
            targetHPBar.classList.remove('bar-red', 'bar-blue', 'bar-green', 'bar-amber');
            targetHPBar.classList.add(faction.barClass);
        } else {
            targetOverlay.classList.add('hidden');
        }

        // Call combat engine tick
        this.updateCombatEngine(dt, getWaveHeight);

        // Cooldown port/stbd decays
        if (this.player.reloadPort > 0) this.player.reloadPort = Math.max(0, this.player.reloadPort - dt);
        if (this.player.reloadStbd > 0) this.player.reloadStbd = Math.max(0, this.player.reloadStbd - dt);

        // Siren and Alerts timers
        if (this.isEnforcerAlertActive) {
            this.sirenTimer -= dt;
            if (this.sirenTimer <= 0) {
                AudioEngine.playAlarmSiren();
                this.sirenTimer = 0.8;
            }
        }
        
        let enforcersExist = this.world.enemies.some(e => e.isEnforcer && e.health > 0);
        if (!enforcersExist) {
            this.isEnforcerAlertActive = false;
        }

        if (this.combatAlertTimer > 0) {
            this.combatAlertTimer -= dt;
            if (this.combatAlertTimer <= 0) {
                this.combatAlertText = '';
            }
        }
    },

    // Render Canvas frame
    draw: function() {
        const width = this.canvas.width / (window.devicePixelRatio || 1);
        const height = this.canvas.height / (window.devicePixelRatio || 1);

        // Clear screen with retro pitch-black
        this.ctx.fillStyle = '#050508';
        this.ctx.fillRect(0, 0, width, height);

        // --- 1. RENDER 3D CONTENT ---
        // A. Sea grid
        Engine3D.drawOcean(this.ctx, this.time, this.player, Engine3D.camera);

        // B. Ports (Procedural Topographic Islands + Lighthouses)
        this.world.ports.forEach(port => {
            const portPos = { x: port.x, y: port.y, z: port.z };
            const portRot = { yaw: 0, pitch: 0, roll: 0 };
            
            // Draw island contours
            Engine3D.drawModel(this.ctx, port.model, portPos, portRot, 1, port.color, Engine3D.camera);

            // Draw Lighthouse structure on top
            const lhWorldPos = {
                x: port.x + port.lighthousePos.x,
                y: port.y + port.lighthousePos.y,
                z: port.z + port.lighthousePos.z
            };
            Engine3D.drawModel(this.ctx, Models3D.lighthouse, lhWorldPos, portRot, 0.6, '#ffffff', Engine3D.camera);

            // Draw spinning beacon lines (Elite style scanner beacon!)
            const beaconRot = { yaw: this.time * 0.6, pitch: 0, roll: 0 };
            const beamModel = {
                vertices: [
                    {x: 0, y: 14.5, z: 0},
                    {x: 0, y: 14.2, z: 35}, // Spotlight beam vector 35m long
                    {x: -6, y: 13.0, z: 34},
                    {x: 6, y: 13.0, z: 34}
                ],
                edges: [
                    [0, 1], [0, 2], [0, 3], [1, 2], [1, 3]
                ]
            };
            Engine3D.drawModel(this.ctx, beamModel, lhWorldPos, beaconRot, 0.6, '#ffff66', Engine3D.camera);
        });

        // C. Sea Spray particles (floating neon dust in water space)
        this.ctx.fillStyle = '#00ffff';
        this.world.particles.forEach(p => {
            const camPt = Engine3D.worldToCamera(p, Engine3D.camera);
            if (camPt.z >= Engine3D.camera.zNear) {
                const s = Engine3D.project(camPt, width, height, Engine3D.camera);
                const size = Math.max(1, (2.0 * Engine3D.camera.focalLength) / camPt.z);
                this.ctx.fillRect(s.x, s.y, size, size);
            }
        });

        // D. Player ship (rendered at player world position)
        const shipModel = Models3D[this.player.shipClass] || Models3D.dinghy;
        const playerPos = { x: this.player.x, y: this.player.y, z: this.player.z };
        const playerRot = { yaw: this.player.yaw, pitch: this.player.pitch, roll: this.player.roll, sailLevel: this.player.sailLevel };
        Engine3D.drawModel(this.ctx, shipModel, playerPos, playerRot, 1, this.FACTIONS.player.color, Engine3D.camera);

        // E. AI Ships / Enemies
        this.world.enemies.forEach(enemy => {
            const enemyModel = Models3D[enemy.shipClass] || Models3D.sloop;
            const enemyPos = { x: enemy.x, y: enemy.y, z: enemy.z };
            
            if (enemy.health > 0) {
                const enemyRot = { yaw: enemy.yaw, pitch: enemy.pitch, roll: enemy.roll };
                Engine3D.drawModel(this.ctx, enemyModel, enemyPos, enemyRot, enemy.scale || 1.0, enemy.color || this.FACTIONS.pirate.color, Engine3D.camera);

                // Target lock chevrons in 3D projection
                if (this.activeTarget === enemy) {
                    const camPt = Engine3D.worldToCamera({ x: enemy.x, y: enemy.y + ((enemy.hitHeight * 0.5) * (enemy.scale || 1.0)), z: enemy.z }, Engine3D.camera);
                    if (camPt.z >= Engine3D.camera.zNear) {
                        const screenPos = Engine3D.project(camPt, width, height, Engine3D.camera);
                        const size = Math.max(15, (65.0 * Engine3D.camera.focalLength) / camPt.z);
                        
                        const factionColor = enemy.color || this.FACTIONS.pirate.color;
                        this.ctx.strokeStyle = factionColor;
                        this.ctx.lineWidth = 1.5;
                        this.ctx.shadowColor = factionColor;
                        this.ctx.shadowBlur = 8;
                        
                        // Top-left
                        this.ctx.beginPath();
                        this.ctx.moveTo(screenPos.x - size, screenPos.y - size + 10);
                        this.ctx.lineTo(screenPos.x - size, screenPos.y - size);
                        this.ctx.lineTo(screenPos.x - size + 10, screenPos.y - size);
                        this.ctx.stroke();

                        // Top-right
                        this.ctx.beginPath();
                        this.ctx.moveTo(screenPos.x + size, screenPos.y - size + 10);
                        this.ctx.lineTo(screenPos.x + size, screenPos.y - size);
                        this.ctx.lineTo(screenPos.x + size - 10, screenPos.y - size);
                        this.ctx.stroke();

                        // Bottom-left
                        this.ctx.beginPath();
                        this.ctx.moveTo(screenPos.x - size, screenPos.y + size - 10);
                        this.ctx.lineTo(screenPos.x - size, screenPos.y + size);
                        this.ctx.lineTo(screenPos.x - size + 10, screenPos.y + size);
                        this.ctx.stroke();

                        // Bottom-right
                        this.ctx.beginPath();
                        this.ctx.moveTo(screenPos.x + size, screenPos.y + size - 10);
                        this.ctx.lineTo(screenPos.x + size, screenPos.y + size);
                        this.ctx.lineTo(screenPos.x + size - 10, screenPos.y + size);
                        this.ctx.stroke();

                        this.ctx.fillStyle = factionColor;
                        this.ctx.font = "bold 11px 'Share Tech Mono', 'Courier New', monospace";
                        this.ctx.textAlign = 'center';
                        this.ctx.fillText("< LOCK-ON >", screenPos.x, screenPos.y - size - 8);
                        
                        this.ctx.shadowBlur = 0;
                    }
                }
            } else {
                // Sinking ship rendering
                const enemyRot = { yaw: enemy.yaw, pitch: enemy.pitch + 0.2, roll: enemy.roll + 0.35 };
                const factionType = enemy.isEnforcer ? 'authority' : 'pirate';
                const translucentColor = this.FACTIONS[factionType].colorRgb;
                Engine3D.drawModel(this.ctx, enemyModel, enemyPos, enemyRot, enemy.scale || 1.0, translucentColor, Engine3D.camera);
            }
        });

        // E2. Retro 3D Tactical Aiming Overlay
        if (this.mouse.isAiming) {
            const side = this.player.aimSide;
            const fireYaw = (side === 'port') ? this.player.yaw - Math.PI / 2 : this.player.yaw + Math.PI / 2;
            const aimYaw = fireYaw + (this.player.aimYawOffset || 0);
            const aimRange = this.player.aimRange !== undefined ? this.player.aimRange : 120;
            const targetHeight = this.player.aimHeight !== undefined ? this.player.aimHeight : 0;
            
            const stats = this.SHIP_CLASSES[this.player.shipClass] || this.SHIP_CLASSES.dinghy;
            const offsetDist = stats.hitRadius || 3.0;
            
            const startX = this.player.x + Math.sin(fireYaw) * offsetDist;
            const startY = this.player.y + 1.0;
            const startZ = this.player.z + Math.cos(fireYaw) * offsetDist;
            
            const targetX = this.player.x + Math.sin(aimYaw) * aimRange;
            const targetY = targetHeight;
            const targetZ = this.player.z + Math.cos(aimYaw) * aimRange;
            
            this.ctx.save();
            this.ctx.strokeStyle = '#ff9900';
            this.ctx.shadowColor = '#ff9900';
            this.ctx.shadowBlur = 8;
            this.ctx.lineWidth = 1.5;
            
            const draw3DLine = (p1, p2, isDashed = false) => {
                const c1 = Engine3D.worldToCamera(p1, Engine3D.camera);
                const c2 = Engine3D.worldToCamera(p2, Engine3D.camera);
                const clipped = Engine3D.clipLine(c1, c2, Engine3D.camera.zNear);
                if (clipped) {
                    const s1 = Engine3D.project(clipped[0], width, height, Engine3D.camera);
                    const s2 = Engine3D.project(clipped[1], width, height, Engine3D.camera);
                    this.ctx.beginPath();
                    this.ctx.moveTo(s1.x, s1.y);
                    this.ctx.lineTo(s2.x, s2.y);
                    if (isDashed) {
                        this.ctx.setLineDash([4, 4]);
                    } else {
                        this.ctx.setLineDash([]);
                    }
                    this.ctx.stroke();
                }
            };
            
            // 1. Dashed firing cone boundaries out to max range (240m) at sea level (y = 0)
            const leftConeEnd = {
                x: this.player.x + Math.sin(fireYaw - Math.PI / 4) * 240,
                y: 0,
                z: this.player.z + Math.cos(fireYaw - Math.PI / 4) * 240
            };
            const rightConeEnd = {
                x: this.player.x + Math.sin(fireYaw + Math.PI / 4) * 240,
                y: 0,
                z: this.player.z + Math.cos(fireYaw + Math.PI / 4) * 240
            };
            
            draw3DLine({ x: startX, y: 0, z: startZ }, leftConeEnd, true);
            draw3DLine({ x: startX, y: 0, z: startZ }, rightConeEnd, true);
            
            // 2. Solid Parabolic Trajectory Target Curve (matches real physics equations)
            const dx_dist = targetX - startX;
            const dz_dist = targetZ - startZ;
            const D = Math.max(5, Math.hypot(dx_dist, dz_dist));
            const T = D / 28.0;
            let vy_start = (targetY - startY) / T + 0.5 * 9.81 * T;
            vy_start = Math.max(-10, Math.min(45, vy_start)); // Safe clamp matching physical solver

            const segments = 24;
            let prevPt = { x: startX, y: startY, z: startZ };
            for (let k = 1; k <= segments; k++) {
                const f = k / segments;
                const t = f * T;
                const currPt = {
                    x: startX + dx_dist * f,
                    y: startY + vy_start * t - 0.5 * 9.81 * t * t,
                    z: startZ + dz_dist * f
                };
                draw3DLine(prevPt, currPt, false);
                prevPt = currPt;
            }
            
            // 3. Sea-level ring projection at sea level under the reticle
            const ringPoints = 16;
            const ringRadius = 6.0;
            const ringPts = [];
            for (let i = 0; i <= ringPoints; i++) {
                const theta = (i / ringPoints) * Math.PI * 2;
                ringPts.push({
                    x: targetX + Math.sin(theta) * ringRadius,
                    y: 0,
                    z: targetZ + Math.cos(theta) * ringRadius
                });
            }
            for (let i = 0; i < ringPoints; i++) {
                draw3DLine(ringPts[i], ringPts[i+1], false);
            }
            
            // 4. Height guide line from sea level to reticle height
            draw3DLine({ x: targetX, y: 0, z: targetZ }, { x: targetX, y: targetY, z: targetZ }, true);
            
            // 5. 3D Cyber Crosshair at reticle position
            const reticleCam = Engine3D.worldToCamera({ x: targetX, y: targetY, z: targetZ }, Engine3D.camera);
            if (reticleCam.z >= Engine3D.camera.zNear) {
                const screenPos = Engine3D.project(reticleCam, width, height, Engine3D.camera);
                const size = Math.max(12, (50.0 * Engine3D.camera.focalLength) / reticleCam.z);
                
                this.ctx.setLineDash([]);
                
                // Outer circle
                this.ctx.beginPath();
                this.ctx.arc(screenPos.x, screenPos.y, size, 0, Math.PI * 2);
                this.ctx.stroke();
                
                // Inner dot
                this.ctx.fillStyle = '#ff9900';
                this.ctx.beginPath();
                this.ctx.arc(screenPos.x, screenPos.y, 2, 0, Math.PI * 2);
                this.ctx.fill();
                
                // Crosshair tick marks
                this.ctx.beginPath();
                this.ctx.moveTo(screenPos.x, screenPos.y - size);
                this.ctx.lineTo(screenPos.x, screenPos.y - size - 6);
                
                this.ctx.moveTo(screenPos.x, screenPos.y + size);
                this.ctx.lineTo(screenPos.x, screenPos.y + size + 6);
                
                this.ctx.moveTo(screenPos.x - size, screenPos.y);
                this.ctx.lineTo(screenPos.x - size - 6, screenPos.y);
                
                this.ctx.moveTo(screenPos.x + size, screenPos.y);
                this.ctx.lineTo(screenPos.x + size + 6, screenPos.y);
                this.ctx.stroke();
                
                // 6. HUD Telemetry Text
                this.ctx.shadowBlur = 0; // Disable blur for crisp text
                this.ctx.fillStyle = '#ff9900';
                this.ctx.font = "bold 12px 'Share Tech Mono', 'Courier New', monospace";
                this.ctx.textAlign = 'left';
                this.ctx.textBaseline = 'middle';
                
                const elevStr = targetY >= 0 ? `ELEV: +${targetY.toFixed(1)}m` : `DEPTH: ${targetY.toFixed(1)}m`;
                const textX = screenPos.x + size + 12;
                
                this.ctx.fillText(`AIM: ${side.toUpperCase()} FLANK`, textX, screenPos.y - 12);
                this.ctx.fillText(`RANGE: ${aimRange.toFixed(1)}m`, textX, screenPos.y);
                this.ctx.fillText(elevStr, textX, screenPos.y + 12);
                
                // Telemetry guide keybind hint
                this.ctx.font = "italic 10px 'Share Tech Mono', 'Courier New', monospace";
                this.ctx.fillStyle = '#ff9900aa'; // Slightly dimmed orange
                this.ctx.fillText("[SHIFT + DRAG TO ELEVATE]", textX, screenPos.y + 26);
            }
            
            this.ctx.restore();
        }

        // F. Projectiles
        this.world.projectiles.forEach(p => {
            if (p.type === 'chain') {
                const angle = p.life * 15.0;
                const r = 0.4;
                const p1 = { x: p.x + Math.sin(angle) * r, y: p.y, z: p.z + Math.cos(angle) * r };
                const p2 = { x: p.x - Math.sin(angle) * r, y: p.y, z: p.z - Math.cos(angle) * r };
                
                const camPt1 = Engine3D.worldToCamera(p1, Engine3D.camera);
                const camPt2 = Engine3D.worldToCamera(p2, Engine3D.camera);
                
                if (camPt1.z >= Engine3D.camera.zNear && camPt2.z >= Engine3D.camera.zNear) {
                    const s1 = Engine3D.project(camPt1, width, height, Engine3D.camera);
                    const s2 = Engine3D.project(camPt2, width, height, Engine3D.camera);
                    
                    // Draw neon yellow chain connection line
                    this.ctx.strokeStyle = '#ffff33';
                    this.ctx.lineWidth = 1.5;
                    this.ctx.beginPath();
                    this.ctx.moveTo(s1.x, s1.y);
                    this.ctx.lineTo(s2.x, s2.y);
                    this.ctx.stroke();
                    
                    // Draw two end dots in neon yellow
                    const size1 = Math.max(0.3, (0.225 * Engine3D.camera.focalLength) / camPt1.z);
                    const size2 = Math.max(0.3, (0.225 * Engine3D.camera.focalLength) / camPt2.z);
                    this.ctx.fillStyle = '#ffff33';
                    this.ctx.fillRect(s1.x - size1/2, s1.y - size1/2, size1, size1);
                    this.ctx.fillRect(s2.x - size2/2, s2.y - size2/2, size2, size2);
                }
            } else if (p.type === 'grape') {
                const camPt = Engine3D.worldToCamera(p, Engine3D.camera);
                if (camPt.z >= Engine3D.camera.zNear) {
                    const screenPos = Engine3D.project(camPt, width, height, Engine3D.camera);
                    const size = Math.max(0.2, (0.15 * Engine3D.camera.focalLength) / camPt.z);
                    this.ctx.fillStyle = '#ffff33';
                    this.ctx.strokeStyle = '#ffffaa';
                    this.ctx.lineWidth = 1;
                    this.ctx.fillRect(screenPos.x - size/2, screenPos.y - size/2, size, size);
                    this.ctx.strokeRect(screenPos.x - size/2, screenPos.y - size/2, size, size);
                }
            } else {
                // Ball or default
                const camPt = Engine3D.worldToCamera(p, Engine3D.camera);
                if (camPt.z >= Engine3D.camera.zNear) {
                    const screenPos = Engine3D.project(camPt, width, height, Engine3D.camera);
                    const size = Math.max(0.4, (0.3 * Engine3D.camera.focalLength) / camPt.z);
                    this.ctx.fillStyle = '#ffff33';
                    this.ctx.strokeStyle = '#ffffaa';
                    this.ctx.lineWidth = 1;
                    this.ctx.fillRect(screenPos.x - size/2, screenPos.y - size/2, size, size);
                    this.ctx.strokeRect(screenPos.x - size/2, screenPos.y - size/2, size, size);
                }
            }
        });

        // G. Splashes
        const getWaveHeight = (x, z) => {
            const w1 = Math.sin(x * 0.05 + this.time * 1.5) * Math.cos(z * 0.05 + this.time * 1.2) * 1.6;
            const w2 = Math.sin(z * 0.12 - this.time * 2.0) * 0.5;
            return w1 + w2;
        };
        this.ctx.strokeStyle = 'rgba(0, 255, 255, 0.7)';
        this.ctx.lineWidth = 1.5;
        this.world.splashes.forEach(s => {
            const numPoints = 12;
            const pts = [];
            for (let i = 0; i <= numPoints; i++) {
                const theta = (i / numPoints) * Math.PI * 2;
                const px = s.x + Math.sin(theta) * s.r;
                const pz = s.z + Math.cos(theta) * s.r;
                const py = getWaveHeight(px, pz);
                const camPt = Engine3D.worldToCamera({ x: px, y: py, z: pz }, Engine3D.camera);
                pts.push(camPt);
            }
            
            this.ctx.beginPath();
            let first = true;
            for (let i = 0; i < pts.length; i++) {
                const p1 = pts[i];
                const p2 = pts[(i + 1) % pts.length];
                const clipped = Engine3D.clipLine(p1, p2, Engine3D.camera.zNear);
                if (clipped) {
                    const s1 = Engine3D.project(clipped[0], width, height, Engine3D.camera);
                    const s2 = Engine3D.project(clipped[1], width, height, Engine3D.camera);
                    if (first) {
                        this.ctx.moveTo(s1.x, s1.y);
                        first = false;
                    }
                    this.ctx.lineTo(s2.x, s2.y);
                }
            }
            this.ctx.stroke();
        });

        // H. Debris
        this.world.debris.forEach(d => {
            if (d.isSpark) {
                const p1 = d;
                const p2 = { x: d.x - d.vx * 0.04, y: d.y - d.vy * 0.04, z: d.z - d.vz * 0.04 };
                const camP1 = Engine3D.worldToCamera(p1, Engine3D.camera);
                const camP2 = Engine3D.worldToCamera(p2, Engine3D.camera);
                const clipped = Engine3D.clipLine(camP1, camP2, Engine3D.camera.zNear);
                if (clipped) {
                    const s1 = Engine3D.project(clipped[0], width, height, Engine3D.camera);
                    const s2 = Engine3D.project(clipped[1], width, height, Engine3D.camera);
                    this.ctx.strokeStyle = '#ff7733';
                    this.ctx.lineWidth = 1;
                    this.ctx.beginPath();
                    this.ctx.moveTo(s1.x, s1.y);
                    this.ctx.lineTo(s2.x, s2.y);
                    this.ctx.stroke();
                }
            } else {
                const pos = { x: d.x, y: d.y, z: d.z };
                const rot = { yaw: d.yaw, pitch: d.pitch, roll: d.roll };
                Engine3D.drawModel(this.ctx, Models3D.cube, pos, rot, d.scale, '#ffaa66', Engine3D.camera);
            }
        });

        // I. Combat Alerts HUD print
        if (this.combatAlertText) {
            this.ctx.fillStyle = this.combatAlertText.includes("ALERT") || this.combatAlertText.includes("WARNING") || this.combatAlertText.includes("IMPACT") ? '#ff3333' : '#33ff33';
            this.ctx.font = "bold 13px 'Courier New', monospace";
            this.ctx.textAlign = 'center';
            this.ctx.shadowColor = this.ctx.fillStyle;
            this.ctx.shadowBlur = 6;
            this.ctx.fillText(this.combatAlertText, width / 2, 130);
            this.ctx.shadowBlur = 0;
        }

        // --- 2. RENDER RETRO HUD OVERLAY ---
        this.renderHUD(width, height);
    },

    // Modern styled retro HUD overlay mimicking elite panels
    renderHUD: function(width, height) {
        const stats = this.SHIP_CLASSES[this.player.shipClass] || this.SHIP_CLASSES.dinghy;

        // Draw docking message if close
        if (this.activePort) {
            const prompt = document.getElementById('dockPrompt');
            prompt.innerText = `[ PRESS SPACE TO DOCK AT ${this.activePort.name.toUpperCase()} ]`;
            prompt.classList.remove('hidden');
        } else {
            document.getElementById('dockPrompt').classList.add('hidden');
        }

        // Update HTML HUD meters
        // Hull HP
        document.getElementById('hudHP').innerText = `${Math.round(this.player.health)} / ${this.player.maxHealth}`;
        document.getElementById('hudHPBar').style.width = `${(this.player.health / this.player.maxHealth) * 100}%`;

        // Port Reload
        if (this.player.reloadPort > 0) {
            document.getElementById('hudReloadPort').innerText = `${(100 * (1.0 - this.player.reloadPort / 3.0)).toFixed(0)}%`;
            document.getElementById('hudReloadPortBar').style.width = `${(1.0 - this.player.reloadPort / 3.0) * 100}%`;
        } else {
            document.getElementById('hudReloadPort').innerText = "READY";
            document.getElementById('hudReloadPortBar').style.width = "100%";
        }

        // Stbd Reload
        if (this.player.reloadStbd > 0) {
            document.getElementById('hudReloadStbd').innerText = `${(100 * (1.0 - this.player.reloadStbd / 3.0)).toFixed(0)}%`;
            document.getElementById('hudReloadStbdBar').style.width = `${(1.0 - this.player.reloadStbd / 3.0) * 100}%`;
        } else {
            document.getElementById('hudReloadStbd').innerText = "READY";
            document.getElementById('hudReloadStbdBar').style.width = "100%";
        }

        // Update Ammunition HUD meters
        const active = this.player.activeAmmo || 'ball';
        
        const ballLbl = document.getElementById('lblAmmoBall');
        const ballVal = document.getElementById('hudAmmoBall');
        if (ballLbl && ballVal) {
            ballLbl.innerHTML = active === 'ball' ? "<span class='neon-text-green'>&gt; BALL (180m):</span>" : "BALL (180m):";
            ballVal.innerText = this.player.ammo.ball;
            ballVal.className = active === 'ball' ? "hud-value neon-text-green" : "hud-value neon-text-yellow";
        }
        
        const chainLbl = document.getElementById('lblAmmoChain');
        const chainVal = document.getElementById('hudAmmoChain');
        if (chainLbl && chainVal) {
            chainLbl.innerHTML = active === 'chain' ? "<span class='neon-text-green'>&gt; CHAIN (100m):</span>" : "CHAIN (100m):";
            chainVal.innerText = this.player.ammo.chain;
            chainVal.className = active === 'chain' ? "hud-value neon-text-green" : "hud-value neon-text-cyan";
        }
        
        const grapeLbl = document.getElementById('lblAmmoGrape');
        const grapeVal = document.getElementById('hudAmmoGrape');
        if (grapeLbl && grapeVal) {
            grapeLbl.innerHTML = active === 'grape' ? "<span class='neon-text-green'>&gt; GRAPE (60m):</span>" : "GRAPE (60m):";
            grapeVal.innerText = this.player.ammo.grape;
            grapeVal.className = active === 'grape' ? "hud-value neon-text-green" : "hud-value neon-text-orange";
        }

        // Speed dial
        const speedKts = (this.player.speed * 3.5).toFixed(1);
        document.getElementById('hudSpeed').innerText = `${speedKts} KTS`;
        document.getElementById('hudSpeedBar').style.width = `${(this.player.speed / this.player.baseMaxSpeed) * 100}%`;

        // Sails throttle dial
        document.getElementById('hudThrottleBar').style.height = `${(this.player.sailLevel / 4) * 100}%`;

        // Gold & Location
        document.getElementById('hudGold').innerText = `${this.player.gold} D`;
        document.getElementById('hudLocation').innerText = this.isDocked ? `DOCKED: ${this.activePort.name}` : `OPEN SEA`;

        // Compass Heading
        let yawDeg = Math.round((this.player.yaw * (180 / Math.PI)) % 360);
        if (yawDeg < 0) yawDeg += 360;
        const headings = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
        const headingIdx = Math.round(yawDeg / 45) % 8;
        document.getElementById('hudHeading').innerText = `${headingIdx === 0 || headingIdx === 4 ? '' : '0'}${yawDeg}° ${headings[headingIdx]}`;

        // Wind Dial
        let windDeg = Math.round((this.wind.angle * (180 / Math.PI)) % 360);
        if (windDeg < 0) windDeg += 360;
        const windHeadIdx = Math.round(windDeg / 45) % 8;
        
        const compassNeedle = document.getElementById('windNeedle');
        const relativeWindAngle = this.wind.angle - this.player.yaw;
        compassNeedle.style.transform = `rotate(${relativeWindAngle}rad)`;
        document.getElementById('hudWind').innerText = `${this.wind.speed} KTS ${headings[windHeadIdx]}`;
        
        // Sailing tacking status
        const efficiency = this.getSailingEfficiency();
        const tackingStatus = document.getElementById('hudTacking');
        if (efficiency < 0.15) {
            tackingStatus.innerText = "IN IRONS (HEADWIND)";
            tackingStatus.style.color = "#ff3333";
        } else if (efficiency > 0.85) {
            tackingStatus.innerText = "GOOD REACH (OPTIMAL)";
            tackingStatus.style.color = "#00ffcc";
        } else {
            tackingStatus.innerText = "TACKING / RUNNING";
            tackingStatus.style.color = "#ffcc00";
        }

        // Update ship name in left panel
        document.getElementById('hudShipName').innerText = `${this.player.shipName} (${stats.name.toUpperCase()})`;
    },

    // Core Animation Frame Loop
    loop: function(currentTime) {
        const dt = Math.min(0.05, (currentTime - this.lastTime) / 1000); // Caps time lag (60FPS is ~0.016)
        this.lastTime = currentTime;

        this.update(dt);
        this.draw();

        requestAnimationFrame((t) => this.loop(t));
    },

    // Developer diagnostic Menu controllers
    toggleDevMenu: function() {
        if (this.isTraveling) return;

        if (this.isDevMenuOpen) {
            this.isDevMenuOpen = false;
            const devModal = document.getElementById('devMenuModal');
            if (devModal) devModal.classList.add('hidden');
            if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(600, 0.05);
            return;
        }

        // Close other modals
        if (this.isMapOpen) this.toggleMap();
        if (this.isInventoryOpen) this.toggleInventory();

        this.isDevMenuOpen = true;

        // Populate dropdowns if empty or outdated
        const shipSelect = document.getElementById('devShipClassSelect');
        const spawnSelect = document.getElementById('devSpawnClassSelect');
        
        if (shipSelect && spawnSelect && shipSelect.options.length === 0) {
            shipSelect.innerHTML = '';
            spawnSelect.innerHTML = '';
            Object.keys(this.SHIP_CLASSES).forEach(classKey => {
                const stats = this.SHIP_CLASSES[classKey];
                
                const opt1 = document.createElement('option');
                opt1.value = classKey;
                opt1.textContent = `${stats.name.toUpperCase()} (Cost: ${stats.cost} D, HP: ${stats.maxHealth})`;
                shipSelect.appendChild(opt1);

                const opt2 = document.createElement('option');
                opt2.value = classKey;
                opt2.textContent = stats.name.toUpperCase();
                spawnSelect.appendChild(opt2);
            });
        }

        // Set selections to active states
        if (shipSelect) {
            shipSelect.value = this.player.shipClass;
        }
        if (spawnSelect && !spawnSelect.value) {
            spawnSelect.value = 'sloop';
        }

        // Populate current ammo inputs
        const ballInput = document.getElementById('devAmmoBall');
        const chainInput = document.getElementById('devAmmoChain');
        const grapeInput = document.getElementById('devAmmoGrape');
        if (ballInput) ballInput.value = this.player.ammo.ball;
        if (chainInput) chainInput.value = this.player.ammo.chain;
        if (grapeInput) grapeInput.value = this.player.ammo.grape;

        // Render commodity prices matrix
        this.renderDevPrices();

        const devModal = document.getElementById('devMenuModal');
        if (devModal) devModal.classList.remove('hidden');
        if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(880, 0.08);
    },

    adjustDevAmmo: function(type, delta) {
        if (!this.player.ammo) this.player.ammo = { ball: 0, chain: 0, grape: 0 };
        let current = parseInt(this.player.ammo[type]) || 0;
        let next = Math.max(0, Math.min(999, current + delta));
        this.player.ammo[type] = next;

        const input = document.getElementById(`devAmmo${type.charAt(0).toUpperCase() + type.slice(1)}`);
        if (input) input.value = next;

        if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(700, 0.05);
    },

    setDevAmmo: function(type, value) {
        if (!this.player.ammo) this.player.ammo = { ball: 0, chain: 0, grape: 0 };
        let next = Math.max(0, Math.min(999, parseInt(value) || 0));
        this.player.ammo[type] = next;

        const input = document.getElementById(`devAmmo${type.charAt(0).toUpperCase() + type.slice(1)}`);
        if (input) input.value = next;

        if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(700, 0.05);
    },

    changeDevShipClass: function(classKey) {
        if (!this.SHIP_CLASSES[classKey]) return;
        this.player.shipClass = classKey;
        this.updatePlayerShipStats();
        // Fully restore HP on ship swap
        this.player.health = this.player.maxHealth;

        // Update shipyard/dock/market rendering states if docked to prevent visual desync
        if (this.isDocked) {
            if (this.currentDockView === 'shipyard') {
                this.renderShipyard();
            } else if (this.currentDockView === 'market') {
                this.renderMarket();
            } else if (this.currentDockView === 'menu') {
                this.renderDockMenu();
            }
        }

        if (typeof AudioEngine !== 'undefined' && AudioEngine.playBeep) AudioEngine.playBeep(1000, 0.1);
    },

    spawnDevHostile: function() {
        const spawnSelect = document.getElementById('devSpawnClassSelect');
        if (!spawnSelect) return;
        
        const shipClass = spawnSelect.value;
        const stats = this.SHIP_CLASSES[shipClass] || this.SHIP_CLASSES.sloop;

        // Project coordinate 50m forward
        const dist = 50;
        const spawnX = this.player.x + Math.sin(this.player.yaw) * dist;
        const spawnZ = this.player.z + Math.cos(this.player.yaw) * dist;

        // Enemy points in opposite direction to face player
        const enemyYaw = (this.player.yaw + Math.PI) % (Math.PI * 2);

        const enemy = {
            id: 'dev_enemy_' + Date.now() + '_' + Math.floor(Math.random()*1000),
            x: spawnX,
            y: 0,
            z: spawnZ,
            yaw: enemyYaw,
            pitch: 0,
            roll: 0,
            speed: 0.5,
            shipClass: shipClass,
            color: this.FACTIONS.pirate.color,
            faction: 'pirate',
            scale: 1.0,
            health: stats.maxHealth,
            maxHealth: stats.maxHealth,
            firepower: stats.firepower,
            baseMaxSpeed: stats.baseMaxSpeed,
            hitRadius: stats.hitRadius,
            hitHeight: stats.hitHeight,
            reloadTimer: 2.0,
            isEnforcer: false,
            target: this.player
        };

        this.world.enemies.push(enemy);

        // Spawn vector debris/spark lines at coordinates
        this.spawnHitDebris(spawnX, 1.5, spawnZ, 15);

        if (typeof AudioEngine !== 'undefined' && AudioEngine.playExplosion) {
            AudioEngine.playExplosion();
        }

        const feedback = document.getElementById('devSpawnFeedback');
        if (feedback) {
            feedback.innerHTML = `SPAWNED HOSTILE <span class="neon-text-red">${stats.name.toUpperCase()}</span> 50M AHEAD!`;
            feedback.className = 'neon-text-green';
            setTimeout(() => {
                if (feedback.innerHTML.includes(stats.name.toUpperCase())) {
                    feedback.innerText = 'READY FOR SIMULATION';
                    feedback.className = '';
                }
            }, 3000);
        }
    },

    renderDevPrices: function() {
        const container = document.getElementById('devPriceMatrixContainer');
        const fluctEl = document.getElementById('devFluctIndex');
        if (!container) return;

        if (fluctEl) {
            fluctEl.innerText = `${this.marketTravelCount || 0} SECTORS VISITED`;
        }

        let html = `
            <div class="dev-table-scroll">
                <table class="dev-table">
                    <thead>
                        <tr>
                            <th>PORT / ARCHIPELAGO</th>
                            <th>RUM</th>
                            <th>SUG</th>
                            <th>TOB</th>
                            <th>SPI</th>
                            <th>COF</th>
                            <th>COC</th>
                            <th>TEX</th>
                            <th>WOD</th>
                        </tr>
                    </thead>
                    <tbody>
        `;

        const commodities = ['rum', 'sugar', 'tobacco', 'spices', 'coffee', 'cocoa', 'textiles', 'wood'];

        this.ARCHIPELAGOS.forEach(arch => {
            html += `
                <tr>
                    <td colspan="9" class="arch-header">${arch.name.toUpperCase()} (${arch.sector})</td>
                </tr>
            `;

            arch.ports.forEach(port => {
                // Calculate prices dynamically for real-time diagnostic output
                const prices = this.calculatePortPrices(port);
                
                html += `
                    <tr>
                        <td class="port-name-cell">${port.name}</td>
                `;

                commodities.forEach(item => {
                    const price = prices[item];
                    if (!price) {
                        html += `<td class="not-traded">-</td>`;
                    } else {
                        let badge = '';
                        if (price.isProducer) badge = '<span class="badge-prod"> P</span>';
                        else if (price.isConsumer) badge = '<span class="badge-cons"> C</span>';
                        
                        html += `
                            <td>
                                <span class="neon-text-cyan">${price.buy}</span>/<span class="neon-text-amber">${price.sell}</span>${badge}
                            </td>
                        `;
                    }
                });

                html += `
                    </tr>
                `;
            });
        });

        html += `
                    </tbody>
                </table>
            </div>
        `;

        container.innerHTML = html;
    }
};

// Start Game automatically on load
if (typeof window !== 'undefined') {
    window.addEventListener('load', () => {
        Game.init();
    });
}

// Export for Node/Vitest testing environment
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { Game };
}
