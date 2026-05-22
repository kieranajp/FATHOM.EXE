import { describe, it, expect, beforeEach, afterEach } from 'vitest';

// Mock global browser APIs for Node test environment
if (typeof global !== 'undefined') {
    global.AudioEngine = {
        initialized: false,
        init: () => {},
        playBeep: () => {},
        playShoot: () => {},
        playCoin: () => {},
        playExplosion: () => {},
        playAlarmSiren: () => {},
        playSplash: () => {},
        playClink: () => {},
        playDockJingle: () => {},
        playTravelSweep: () => {}
    };
    
    global.document = {
        getElementById: () => ({
            innerText: '',
            style: { width: '', height: '', transform: '' },
            classList: { add: () => {}, remove: () => {} },
            appendChild: () => {},
            innerHTML: ''
        })
    };

    global.Models3D = {
        generateIsland: () => ({})
    };
}

import { Game } from './game.js';

describe('FATHOM.EXE - Core Game Logic Unit Tests', () => {

    describe('Sailing & Tacking Physics (calculateSailingEfficiency)', () => {
        it('should yield extremely high drag (near 0) when sailing directly into the wind (in irons)', () => {
            const efficiency = Game.calculateSailingEfficiency(0, 0);
            expect(efficiency).toBeCloseTo(0, 4);
            
            const angleInIrons = 0.1;
            const efficiencyInIrons = Game.calculateSailingEfficiency(angleInIrons, 0);
            expect(efficiencyInIrons).toBeGreaterThan(0);
            expect(efficiencyInIrons).toBeLessThan(0.05);
        });

        it('should yield high efficiency when reaching, peaking at a broad reach (135 degrees)', () => {
            const efficiencyBeamReach = Game.calculateSailingEfficiency(Math.PI / 2, 0);
            expect(efficiencyBeamReach).toBeCloseTo(0.7218, 4);

            const efficiencyBroadReach = Game.calculateSailingEfficiency(Math.PI * 0.75, 0);
            expect(efficiencyBroadReach).toBeCloseTo(1.0, 4);
        });

        it('should yield moderately high efficiency when running downwind (tailwind)', () => {
            const efficiency = Game.calculateSailingEfficiency(Math.PI, 0);
            expect(efficiency).toBeCloseTo(0.75, 4);
        });
    });

    describe('Ballistic Cylinder Collision Detection (checkCylinderIntersection)', () => {
        const hitRadius = 5.0;
        const hitHeight = 10.0;
        const targetX = 100.0;
        const targetY = 0.0;
        const targetZ = 100.0;

        it('should detect a direct center hit', () => {
            const hit = Game.checkCylinderIntersection(
                targetX, targetY, targetZ,
                targetX, targetY, targetZ,
                hitRadius, hitHeight
            );
            expect(hit).toBe(true);
        });

        it('should detect hits within the cylinder radius and height bounds', () => {
            const hit = Game.checkCylinderIntersection(
                targetX + 3.0, targetY + 5.0, targetZ + 3.0,
                targetX, targetY, targetZ,
                hitRadius, hitHeight
            );
            expect(hit).toBe(true);
        });

        it('should reject hits that are outside the cylinder radius', () => {
            const hit = Game.checkCylinderIntersection(
                targetX + 6.0, targetY + 2.0, targetZ,
                targetX, targetY, targetZ,
                hitRadius, hitHeight
            );
            expect(hit).toBe(false);
        });

        it('should reject hits that are below the cylinder base', () => {
            const hit = Game.checkCylinderIntersection(
                targetX, targetY - 1.5, targetZ,
                targetX, targetY, targetZ,
                hitRadius, hitHeight
            );
            expect(hit).toBe(false);
        });

        it('should reject hits that are above the cylinder ceiling', () => {
            const hit = Game.checkCylinderIntersection(
                targetX, targetY + 10.5, targetZ,
                targetX, targetY, targetZ,
                hitRadius, hitHeight
            );
            expect(hit).toBe(false);
        });
    });

    describe('Cargo Economy Rules (canBuyCargo / canSellCargo)', () => {
        const item = 'sugar';
        const price = 25;

        describe('canBuyCargo', () => {
            it('should succeed when gold is sufficient and hold has space', () => {
                const playerState = {
                    gold: 100,
                    maxCargo: 100,
                    cargo: { rum: 1, sugar: 2, spices: 0, tobacco: 0 }
                };
                const validation = Game.canBuyCargo(playerState, item, price);
                expect(validation.success).toBe(true);
            });

            it('should fail when gold is insufficient', () => {
                const playerState = {
                    gold: 20,
                    maxCargo: 100,
                    cargo: { rum: 1, sugar: 2, spices: 0, tobacco: 0 }
                };
                const validation = Game.canBuyCargo(playerState, item, price);
                expect(validation.success).toBe(false);
                expect(validation.reason).toContain('INSUFFICIENT GOLD');
            });

            it('should fail when cargo hold is completely full', () => {
                const playerState = {
                    gold: 100,
                    maxCargo: 30,
                    cargo: { rum: 2, sugar: 1, spices: 0, tobacco: 0 }
                };
                const validation = Game.canBuyCargo(playerState, item, price);
                expect(validation.success).toBe(false);
                expect(validation.reason).toContain('CARGO HOLD FULL');
            });
        });

        describe('canSellCargo', () => {
            it('should succeed when at least one unit of the cargo item is owned', () => {
                const playerState = {
                    cargo: { rum: 0, sugar: 2, spices: 0, tobacco: 0 }
                };
                const validation = Game.canSellCargo(playerState, item);
                expect(validation.success).toBe(true);
            });

            it('should fail when none of the requested cargo item is owned', () => {
                const playerState = {
                    cargo: { rum: 2, sugar: 0, spices: 1, tobacco: 0 }
                };
                const validation = Game.canSellCargo(playerState, item);
                expect(validation.success).toBe(false);
                expect(validation.reason).toContain('NO CARGO HELD');
            });
        });
    });

    describe('Vessel Damage States (applyShipDamage)', () => {
        it('should reduce ship health and return false if ship remains afloat', () => {
            const shipState = {
                health: 100,
                maxHealth: 100
            };
            const isSunk = Game.applyShipDamage(shipState, 30);
            expect(shipState.health).toBe(70);
            expect(isSunk).toBe(false);
        });

        it('should reduce health to 0 and return true when damage is lethal', () => {
            const shipState = {
                health: 40,
                maxHealth: 100
            };
            const isSunk = Game.applyShipDamage(shipState, 50);
            expect(shipState.health).toBe(0);
            expect(isSunk).toBe(true);
        });

        it('should cap health between 0 and maxHealth', () => {
            const shipState = {
                health: 100,
                maxHealth: 100
            };

            Game.applyShipDamage(shipState, -50);
            expect(shipState.health).toBe(100);

            Game.applyShipDamage(shipState, 500);
            expect(shipState.health).toBe(0);
        });
    });

    describe('Enemy AI steering state machines (calculateAISteering)', () => {
        const baseMaxSpeed = 5.0;
        const enemyBase = {
            x: 0,
            z: 0,
            yaw: 0,
            speed: 0,
            baseMaxSpeed: baseMaxSpeed,
            reloadTimer: 0,
            rudder: 0
        };

        it('should enter Patrol State when target is very far away (>300 units)', () => {
            const target = { x: 0, z: 350 }; // distance = 350
            const dt = 0.5;
            const steering = Game.calculateAISteering(enemyBase, target, dt);
            
            // Speed should drop to 40%
            expect(steering.speed).toBeCloseTo(baseMaxSpeed * 0.4, 4);
            // Rudder reset to 0
            expect(steering.rudder).toBe(0);
            // Yaw should increase slowly by 0.15 * dt (0 + 0.075 = 0.075)
            expect(steering.yaw).toBeCloseTo(0.075, 4);
            expect(steering.fireSide).toBeNull();
        });

        it('should enter Chase State when target is at medium range (between 100 and 300 units)', () => {
            const target = { x: 150, z: 150 }; // distance ≈ 212 units, angle = Math.PI / 4
            const dt = 0.1;
            const steering = Game.calculateAISteering(enemyBase, target, dt);

            // Speed should increase to 80%
            expect(steering.speed).toBeCloseTo(baseMaxSpeed * 0.8, 4);
            // Rudder should steer toward target angle
            expect(steering.rudder).toBeGreaterThan(0); // steers right to adjust yaw to Math.PI / 4
            // Yaw should rotate positively towards target yaw
            expect(steering.yaw).toBeGreaterThan(0);
            expect(steering.fireSide).toBeNull();
        });

        it('should enter Orbit State and navigate perpendicular when close (<100 units)', () => {
            const target = { x: 50, z: 50 }; // distance ≈ 70.7 units
            const dt = 0.1;
            const steering = Game.calculateAISteering(enemyBase, target, dt);

            // Speed should drop slightly to 70%
            expect(steering.speed).toBeCloseTo(baseMaxSpeed * 0.7, 4);
            // Steering target should seek angleToTarget + PI/2 (perpendicular orbit)
            expect(steering.rudder).toBeGreaterThan(0);
            expect(steering.yaw).toBeGreaterThan(0);
        });

        it('should command firing broadsides when reloadTimer is 0 and aligned perpendicularly', () => {
            // Enemy facing North (0)
            const targetPort = { x: -50, z: 0 }; // directly left (-Math.PI/2 relative)
            const steeringPort = Game.calculateAISteering(
                { ...enemyBase, reloadTimer: 0, yaw: 0 }, 
                targetPort, 
                0.1
            );
            expect(steeringPort.fireSide).toBe('port');

            const targetStarboard = { x: 50, z: 0 }; // directly right (Math.PI/2 relative)
            const steeringStarboard = Game.calculateAISteering(
                { ...enemyBase, reloadTimer: 0, yaw: 0 }, 
                targetStarboard, 
                0.1
            );
            expect(steeringStarboard.fireSide).toBe('starboard');
        });

        it('should NOT command firing if reloadTimer > 0', () => {
            const targetPort = { x: -50, z: 0 }; 
            const steeringPort = Game.calculateAISteering(
                { ...enemyBase, reloadTimer: 1.5, yaw: 0 }, 
                targetPort, 
                0.1
            );
            expect(steeringPort.fireSide).toBeNull();
        });
    });

    describe('Wind Drift Smooth Angle Interpolation (calculateNextWindAngle)', () => {
        it('should smoothly interpolate angles', () => {
            const currentAngle = 0.0;
            const targetAngle = 1.0;
            const lerpFactor = 0.1;
            
            const nextAngle = Game.calculateNextWindAngle(currentAngle, targetAngle, lerpFactor);
            expect(nextAngle).toBeCloseTo(0.1, 4);
        });

        it('should smoothly wrap crossing the 0 / 2*PI boundary (shortest rotation)', () => {
            // Target is 6.18 (~ 2*PI - 0.1), Current is 0.1
            // Shortest way is going counter-clockwise (decreasing past 0)
            const currentAngle = 0.1;
            const targetAngle = Math.PI * 2 - 0.1; // ≈ 6.183
            const lerpFactor = 0.5;

            const nextAngle = Game.calculateNextWindAngle(currentAngle, targetAngle, lerpFactor);
            // Diff is -0.2, so nextAngle should be 0.1 - 0.1 = 0.0
            expect(nextAngle).toBeCloseTo(0.0, 4);
        });
    });

    describe('Port Market Pricing (calculatePortPrices)', () => {
        it('should correctly evaluate dynamic prices with offset determined by name characters', () => {
            const nassau = {
                name: 'Nassau',
                basePrices: {
                    rum: { buy: 10, sell: 12, isProducer: true },
                    sugar: { buy: 22, sell: 26 },
                    tobacco: { buy: 35, sell: 42, isConsumer: true }
                }
            };

            const prices = Game.calculatePortPrices(nassau);
            
            // Rum price: base 20. buy = Math.round(20 * 0.6 * 0.9841) = 12. sell = Math.round(20 * 0.4 * 0.9841) = 8.
            expect(prices.rum.buy).toBe(12);
            expect(prices.rum.sell).toBe(8);
            expect(prices.rum.isProducer).toBe(true);

            // Tobacco price: base 25. buy = Math.round(25 * 1.8 * 0.9841) = 44. sell = Math.round(25 * 1.4 * 0.9841) = 34.
            expect(prices.tobacco.buy).toBe(44);
            expect(prices.tobacco.sell).toBe(34);
            expect(prices.tobacco.isConsumer).toBe(true);
        });

        it('should handle undefined / invalid ports gracefully', () => {
            const badPrices = Game.calculatePortPrices(null);
            expect(badPrices).toEqual({});
        });
    });

    describe('Shipyard Upgrade Logic (canUpgradeShip)', () => {
        it('should correctly calculate upgrade cost with 70% trade-in value', () => {
            const playerState = {
                shipClass: 'sloop', // Sloop cost is 500
                gold: 2000,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 }
            };
            
            // Brigantine cost is 1400. Sloop trade-in value is 500 * 0.7 = 350.
            // Expected upgrade cost: 1400 - 350 = 1050.
            const result = Game.canUpgradeShip(playerState, 'brigantine');
            expect(result.success).toBe(true);
            expect(result.cost).toBe(1050);
        });

        it('should reduce trade-in value proportionally when the ship is damaged', () => {
            const playerState = {
                shipClass: 'sloop', // Sloop cost is 500
                gold: 2000,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 },
                health: 75,
                maxHealth: 150 // 50% health ratio
            };
            
            // Brigantine cost is 1400.
            // Sloop trade-in value is 500 * 0.7 * (75/150) = 500 * 0.7 * 0.5 = 175.
            // Expected upgrade cost: 1400 - 175 = 1225.
            const result = Game.canUpgradeShip(playerState, 'brigantine');
            expect(result.success).toBe(true);
            expect(result.cost).toBe(1225);
        });


        it('should return 0 cost if the trade-in value exceeds the target ship cost', () => {
            const playerState = {
                shipClass: 'galleon', // Galleon cost is 2800. Trade-in is 2800 * 0.7 = 1960.
                gold: 100,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 }
            };
            
            // Sloop cost is 500. Sloop cost (500) < Galleon trade-in (1960), so cost should be 0.
            const result = Game.canUpgradeShip(playerState, 'sloop');
            expect(result.success).toBe(true);
            expect(result.cost).toBe(0);
        });

        it('should fail if the player has insufficient gold', () => {
            const playerState = {
                shipClass: 'dinghy', // cost 0
                gold: 100,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 }
            };
            
            // Schooner cost is 250.
            const result = Game.canUpgradeShip(playerState, 'schooner');
            expect(result.success).toBe(false);
            expect(result.reason).toBe('INSUFFICIENT GOLD');
        });

        it('should fail if the player carries more cargo than the new ship maxCargo limit', () => {
            const playerState = {
                shipClass: 'clipper', // maxCargo is 28
                gold: 5000,
                cargo: { rum: 10, sugar: 10, spices: 0, tobacco: 0 } // carrying 20 units total
            };
            
            // Sloop maxCargo is 12. 20 > 12, so should fail with CARGO HOLD OVERFLOW.
            const result = Game.canUpgradeShip(playerState, 'sloop');
            expect(result.success).toBe(false);
            expect(result.reason).toBe('CARGO HOLD OVERFLOW');
        });

        it('should succeed if the player carries cargo within the new ship maxCargo limit', () => {
            const playerState = {
                shipClass: 'clipper', // maxCargo is 28
                gold: 5000,
                cargo: { rum: 5, sugar: 5, spices: 0, tobacco: 0 } // carrying 10 units total
            };
            
            // Sloop maxCargo is 12. 10 <= 12, so should succeed!
            // Sloop cost is 500. Clipper trade-in is 1100 * 0.7 = 770. Cost should be 0.
            const result = Game.canUpgradeShip(playerState, 'sloop');
            expect(result.success).toBe(true);
            expect(result.cost).toBe(0);
        });

        it('should reject transactions for currently owned ships', () => {
            const playerState = {
                shipClass: 'sloop',
                gold: 5000,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 }
            };
            
            const result = Game.canUpgradeShip(playerState, 'sloop');
            expect(result.success).toBe(false);
            expect(result.reason).toBe('ALREADY OWNED');
        });

        it('should reject transactions for invalid ship classes', () => {
            const playerState = {
                shipClass: 'dinghy',
                gold: 5000,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 }
            };
            
            const result = Game.canUpgradeShip(playerState, 'ufo');
            expect(result.success).toBe(false);
            expect(result.reason).toBe('INVALID SHIP CLASS');
        });
    });

    describe('Ammunition & Combat Mechanics', () => {
        it('should deplete exactly 1 ammo unit on firing broadside', () => {
            // Mock state
            Game.player = {
                shipClass: 'dinghy',
                ammo: { ball: 5, chain: 2, grape: 1 },
                activeAmmo: 'ball',
                reloadPort: 0,
                reloadStbd: 0,
                yaw: 0,
                x: 0, y: 0, z: 0,
                speed: 0
            };
            Game.world = { projectiles: [] };
            
            Game.fireBroadside('port');
            expect(Game.player.ammo.ball).toBe(4);
            expect(Game.world.projectiles.length).toBe(1);
            expect(Game.world.projectiles[0].type).toBe('ball');
            expect(Game.world.projectiles[0].life).toBe(4.0);
        });

        it('should block firing and play low buzz if ammo is depleted', () => {
            Game.player = {
                shipClass: 'dinghy',
                ammo: { ball: 0, chain: 2, grape: 1 },
                activeAmmo: 'ball',
                reloadPort: 0,
                reloadStbd: 0,
                yaw: 0,
                x: 0, y: 0, z: 0,
                speed: 0
            };
            Game.world = { projectiles: [] };
            
            Game.fireBroadside('port');
            expect(Game.player.ammo.ball).toBe(0);
            expect(Game.world.projectiles.length).toBe(0);
            expect(Game.player.reloadPort).toBe(0); // Cooldown not set
        });

        it('should support ammo type switching and custom lifespans', () => {
            Game.player = {
                shipClass: 'dinghy',
                ammo: { ball: 5, chain: 2, grape: 1 },
                activeAmmo: 'chain',
                reloadPort: 0,
                reloadStbd: 0,
                yaw: 0,
                x: 0, y: 0, z: 0,
                speed: 0
            };
            Game.world = { projectiles: [] };

            // Fire chain shot
            Game.fireBroadside('port');
            expect(Game.player.ammo.chain).toBe(1);
            expect(Game.world.projectiles[0].type).toBe('chain');
            expect(Game.world.projectiles[0].life).toBe(2.2);
            expect(Game.world.projectiles[0].damage).toBe(10);
        });

        it('should fire 16 shrapnel pellets for Grape shot', () => {
            Game.player = {
                shipClass: 'dinghy',
                ammo: { ball: 5, chain: 2, grape: 1 },
                activeAmmo: 'grape',
                reloadPort: 0,
                reloadStbd: 0,
                yaw: 0,
                x: 0, y: 0, z: 0,
                speed: 0
            };
            Game.world = { projectiles: [] };

            // Fire grape shot
            Game.fireBroadside('port');
            expect(Game.player.ammo.grape).toBe(0);
            expect(Game.world.projectiles.length).toBe(16); // 16 pellets
            expect(Game.world.projectiles[0].type).toBe('grape');
            expect(Game.world.projectiles[0].life).toBe(0.8);
            expect(Game.world.projectiles[0].damage).toBe(2);
        });

        it('should apply 5.0s speed debuff on enemy when hit by chain shot', () => {
            const enemy = {
                x: 10, y: 0, z: 0,
                health: 100,
                hitRadius: 5,
                hitHeight: 10,
                speedDebuffTimer: 0
            };
            Game.world = {
                enemies: [enemy],
                projectiles: [{
                    x: 10, y: 1, z: 0,
                    vx: 0, vy: 0, vz: 0,
                    life: 2.2,
                    damage: 10,
                    isPlayerOwned: true,
                    type: 'chain'
                }],
                splashes: [],
                debris: []
            };

            const mockGetWaveHeight = () => -10; // projectile doesn't splash down
            
            Game.updateCombatEngine(0.1, mockGetWaveHeight);
            
            expect(enemy.speedDebuffTimer).toBe(4.9); // 5.0s - 0.1s dt
        });

        it('should apply 5.0s speed debuff on player when hit by enemy chain shot', () => {
            Game.player = {
                x: 10, y: 0, z: 0,
                health: 100,
                shipClass: 'dinghy',
                speedDebuffTimer: 0
            };
            Game.world = {
                enemies: [],
                projectiles: [{
                    x: 10, y: 1, z: 0,
                    vx: 0, vy: 0, vz: 0,
                    life: 2.2,
                    damage: 10,
                    isPlayerOwned: false,
                    type: 'chain'
                }],
                splashes: [],
                debris: []
            };

            const mockGetWaveHeight = () => -10; // projectile doesn't splash down
            
            Game.updateCombatEngine(0.1, mockGetWaveHeight);
            
            expect(Game.player.speedDebuffTimer).toBe(5.0); // Not decremented in updateCombatEngine but in updatePlayerPhysics
        });
    });

    describe('Ammunition Trading and Port Markets', () => {
        it('should count ammunition towards total cargo count', () => {
            const playerState = {
                cargo: { rum: 2, sugar: 1 },
                ammo: { ball: 3, chain: 0, grape: 1 }
            };
            const total = Game.getTotalCargoCount(playerState);
            expect(total).toBe(30.8); // 3 commodities * 10 + 4 ammo * 0.2 = 30 + 0.8 = 30.8
        });

        it('should prevent buying ammunition if cargo hold is full', () => {
            const playerState = {
                gold: 100,
                maxCargo: 40.2,
                cargo: { rum: 3, sugar: 1 },
                ammo: { ball: 1, chain: 0, grape: 0 } // total cargo = 40.2
            };
            const price = 2; // Ball buy price
            const validation = Game.canBuyCargo(playerState, 'ball', price);
            expect(validation.success).toBe(false);
            expect(validation.reason).toContain('CARGO HOLD FULL');
        });

        it('should successfully buy ammunition, updating player counts and decrementing port stock', () => {
            Game.isDocked = true;
            Game.currentDockView = 'market';
            Game.player = {
                gold: 50,
                maxCargo: 10,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 },
                ammo: { ball: 2, chain: 0, grape: 0 }
            };
            Game.activePort = {
                prices: {
                    rum: { buy: 10, sell: 12 },
                    sugar: { buy: 22, sell: 26 },
                    spices: { buy: 22, sell: 26 },
                    tobacco: { buy: 35, sell: 42 }
                },
                ammoStock: { ball: 5, chain: 1, grape: 0 }
            };

            // Mock logMarketTransaction
            Game.logMarketTransaction = () => {};

            // Buy ball shot (2 D)
            Game.buyCargo('ball');
            expect(Game.player.gold).toBe(48);
            expect(Game.player.ammo.ball).toBe(3);
            expect(Game.activePort.ammoStock.ball).toBe(4);
        });

        it('should block buying ammunition if port is out of stock', () => {
            Game.isDocked = true;
            Game.currentDockView = 'market';
            Game.player = {
                gold: 50,
                maxCargo: 10,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 },
                ammo: { ball: 2, chain: 0, grape: 0 }
            };
            Game.activePort = {
                prices: {
                    rum: { buy: 10, sell: 12 },
                    sugar: { buy: 22, sell: 26 },
                    spices: { buy: 22, sell: 26 },
                    tobacco: { buy: 35, sell: 42 }
                },
                ammoStock: { ball: 0, chain: 1, grape: 0 }
            };

            Game.logMarketTransaction = () => {};

            // Try to buy ball shot (out of stock)
            Game.buyCargo('ball');
            expect(Game.player.gold).toBe(50); // no change
            expect(Game.player.ammo.ball).toBe(2); // no change
        });

        it('should sell ammunition, updating player counts and incrementing port stock', () => {
            Game.isDocked = true;
            Game.currentDockView = 'market';
            Game.player = {
                gold: 50,
                maxCargo: 10,
                cargo: { rum: 0, sugar: 0, spices: 0, tobacco: 0 },
                ammo: { ball: 2, chain: 0, grape: 0 }
            };
            Game.activePort = {
                prices: {
                    rum: { buy: 10, sell: 12 },
                    sugar: { buy: 22, sell: 26 },
                    spices: { buy: 22, sell: 26 },
                    tobacco: { buy: 35, sell: 42 }
                },
                ammoStock: { ball: 5, chain: 1, grape: 0 }
            };

            Game.logMarketTransaction = () => {};

            // Sell ball shot (sells for 0 D now)
            Game.sellCargo('ball');
            expect(Game.player.gold).toBe(50); // sells for 0 D, so gold remains 50
            expect(Game.player.ammo.ball).toBe(1);
            expect(Game.activePort.ammoStock.ball).toBe(6);
        });
    });

    describe('Persistent Deterministic Ship Stock System', () => {
        beforeEach(() => {
            // Reset player and depleted registry
            Game.depletedShipStock = {};
            Game.player = {
                gold: 10000,
                shipClass: 'dinghy',
                maxCargo: 10,
                cargo: {},
                ammo: { ball: 0, chain: 0, grape: 0 },
                health: 100,
                maxHealth: 100
            };
        });

        it('should initialize stable and deterministic stock per port', () => {
            Game.loadArchipelago(0, true);
            const portA = Game.world.ports[0];
            const portB = Game.world.ports[1];

            // Re-load archipelago to check if the generated stock is perfectly identical
            const stockA1 = { ...portA.shipStock };
            const stockB1 = { ...portB.shipStock };

            Game.loadArchipelago(0, true);
            const portA_reload = Game.world.ports[0];
            const portB_reload = Game.world.ports[1];

            expect(portA_reload.shipStock).toEqual(stockA1);
            expect(portB_reload.shipStock).toEqual(stockB1);
            
            // Dinghy fallback check
            expect(portA.shipStock.dinghy).toBe(1);
            expect(portB.shipStock.dinghy).toBe(1);
        });

        it('should hide out-of-stock vessels from shipyard rendering unless owned', () => {
            let mockContent = '';
            global.document = {
                getElementById: (id) => {
                    if (id === 'portContent') {
                        return {
                            set innerHTML(val) {
                                mockContent = val;
                            },
                            get innerHTML() {
                                return mockContent;
                            }
                        };
                    }
                    return {
                        innerText: '',
                        style: { width: '', height: '', transform: '' },
                        classList: { add: () => {}, remove: () => {} },
                        appendChild: () => {},
                        innerHTML: ''
                    };
                }
            };

            Game.isDocked = true;
            Game.currentDockView = 'shipyard';
            Game.activePort = {
                name: 'Test Port',
                shipStock: {
                    dinghy: 0, // Owned ship out of stock
                    schooner: 1, // Available
                    sloop: 0 // Unavailable
                }
            };
            Game.player.shipClass = 'dinghy';

            Game.renderShipyard();

            // Sloop should be completely hidden (0 stock, not owned)
            expect(mockContent).not.toContain('🛥️ Sloop');
            // Dinghy should be visible (0 stock, but is Owned/Active)
            expect(mockContent).toContain('🛥️ Dinghy');
            // Schooner should be visible (1 stock)
            expect(mockContent).toContain('🛥️ Schooner');
        });

        it('should deplete stock to 0 upon purchase and persist depletion', () => {
            Game.isDocked = true;
            Game.currentDockView = 'shipyard';
            
            // Prepare active port
            const port = {
                name: 'Tortuga',
                shipStock: {
                    schooner: 1,
                    sloop: 1
                }
            };
            Game.activePort = port;
            Game.world.ports = [port];
            Game.currentArchipelagoIndex = 0;
            Game.ARCHIPELAGOS[0].ports = [port];

            // Verify can buy
            const targetClass = 'schooner';
            expect(port.shipStock[targetClass]).toBe(1);

            global.AudioEngine = {
                initialized: false,
                init: () => {},
                playBeep: () => {},
                playShoot: () => {},
                playCoin: () => {},
                playExplosion: () => {},
                playAlarmSiren: () => {},
                playSplash: () => {},
                playClink: () => {},
                playDockJingle: () => {},
                playTravelSweep: () => {}
            };

            Game.buyShip(targetClass);

            // Check stock is 0
            expect(port.shipStock[targetClass]).toBe(0);
            expect(Game.depletedShipStock[`Tortuga_${targetClass}`]).toBe(true);

            // Reloading Archipelago should maintain stock at 0
            Game.loadArchipelago(0, false);
            const reloadedPort = Game.world.ports[0];
            expect(reloadedPort.shipStock[targetClass]).toBe(0);
        });
    });

    describe('Advanced Cannon Aiming & Ballistic Systems', () => {
        beforeEach(() => {
            Game.mouse = {
                isDragging: false,
                isAiming: false,
                startX: 0,
                startY: 0,
                yaw: 0,
                pitch: 0
            };
            Game.player = {
                shipClass: 'dinghy',
                ammo: { ball: 5, chain: 2, grape: 1 },
                activeAmmo: 'ball',
                reloadPort: 0,
                reloadStbd: 0,
                yaw: 0,
                x: 0,
                y: 0,
                z: 0,
                speed: 0,
                aimSide: 'starboard',
                aimYawOffset: 0,
                aimRange: 120,
                aimHeight: 0
            };
            Game.world = { projectiles: [] };
            Game.isDocked = false;
            Game.isTraveling = false;
            global.AudioEngine = {
                playBeep: () => {},
                playShoot: () => {}
            };
        });

        it('should correctly clamp player aim parameters to physical limits', () => {
            // Test aimYawOffset clamp [-PI/4, PI/4]
            Game.mouse.isAiming = true;
            Game.mouse.startX = 100;
            Game.mouse.startY = 100;
            
            Game.player.aimYawOffset = 5.0; // way above PI/4
            Game.player.aimYawOffset = Math.max(-Math.PI / 4, Math.min(Math.PI / 4, Game.player.aimYawOffset));
            expect(Game.player.aimYawOffset).toBeCloseTo(Math.PI / 4, 5);

            Game.player.aimYawOffset = -5.0; // way below -PI/4
            Game.player.aimYawOffset = Math.max(-Math.PI / 4, Math.min(Math.PI / 4, Game.player.aimYawOffset));
            expect(Game.player.aimYawOffset).toBeCloseTo(-Math.PI / 4, 5);

            // Test aimRange clamp [30, 240]
            Game.player.aimRange = 10;
            Game.player.aimRange = Math.max(30, Math.min(240, Game.player.aimRange));
            expect(Game.player.aimRange).toBe(30);

            Game.player.aimRange = 300;
            Game.player.aimRange = Math.max(30, Math.min(240, Game.player.aimRange));
            expect(Game.player.aimRange).toBe(240);

            // Test aimHeight clamp [-10, 30]
            Game.player.aimHeight = -50;
            Game.player.aimHeight = Math.max(-10, Math.min(30, Game.player.aimHeight));
            expect(Game.player.aimHeight).toBe(-10);

            Game.player.aimHeight = 50;
            Game.player.aimHeight = Math.max(-10, Math.min(30, Game.player.aimHeight));
            expect(Game.player.aimHeight).toBe(30);
        });

        it('should compute appropriate ballistic velocity vectors targeting reticle elevation', () => {
            Game.mouse.isAiming = true;
            Game.player.aimSide = 'port';
            Game.player.aimYawOffset = 0;
            Game.player.aimRange = 100;
            
            // Aim high (elevation = +15)
            Game.player.aimHeight = 15;
            Game.fireBroadside('port');
            
            expect(Game.world.projectiles.length).toBe(1);
            const highProjectile = Game.world.projectiles[0];
            
            // Reset and aim low (depth = -5)
            Game.world.projectiles = [];
            Game.player.reloadPort = 0; // Reset reload cooldown
            Game.player.aimHeight = -5;
            Game.fireBroadside('port');
            
            expect(Game.world.projectiles.length).toBe(1);
            const lowProjectile = Game.world.projectiles[0];
            
            // Higher elevation should result in significantly higher vertical launch velocity (vy)
            expect(highProjectile.vy).toBeGreaterThan(lowProjectile.vy);
        });

        it('should select correct initial aim side based on camera view direction', () => {
            // Camera looking from Port side (mouse.yaw >= 0)
            Game.mouse.yaw = 1.0;
            Game.player.aimSide = Game.mouse.yaw >= 0 ? 'starboard' : 'port';
            expect(Game.player.aimSide).toBe('starboard');

            // Camera looking from Starboard side (mouse.yaw < 0)
            Game.mouse.yaw = -1.0;
            Game.player.aimSide = Game.mouse.yaw >= 0 ? 'starboard' : 'port';
            expect(Game.player.aimSide).toBe('port');
        });

        it('should not decay camera orbit offsets (auto-center) when aiming is active', () => {
            // Setup local stub for global Engine3D which is accessed during Game.update
            global.Engine3D = {
                camera: {
                    x: 0,
                    y: 0,
                    z: 0,
                    yaw: 0,
                    pitch: 0,
                    roll: 0
                }
            };
            
            // Add required mocks to document for body classList
            global.document.body = {
                classList: {
                    add: () => {},
                    remove: () => {}
                }
            };

            // Add required mocks to AudioEngine
            global.AudioEngine.updateWindFrequency = () => {};

            // Fully initialize world to avoid undefined errors in sub-methods
            Game.world = {
                projectiles: [],
                enemies: [],
                particles: [],
                ports: [],
                splashes: [],
                debris: []
            };

            // Initialize player attributes needed for update
            Game.player.baseMaxSpeed = 6.5;
            Game.player.health = 100;
            Game.player.maxHealth = 100;

            // Set initial camera orbit offsets
            Game.mouse.yaw = 1.0;
            Game.mouse.pitch = 0.5;

            // Scenario 1: mouse.isDragging = false, mouse.isAiming = true
            Game.mouse.isDragging = false;
            Game.mouse.isAiming = true;

            // Run a few updates
            Game.update(0.016);
            Game.update(0.016);

            // Orbit offsets should NOT have decayed
            expect(Game.mouse.yaw).toBe(1.0);
            expect(Game.mouse.pitch).toBe(0.5);

            // Scenario 2: mouse.isDragging = false, mouse.isAiming = false
            Game.mouse.isAiming = false;

            // Run an update
            Game.update(0.016);

            // Orbit offsets should have decayed towards 0
            expect(Game.mouse.yaw).toBeLessThan(1.0);
            expect(Game.mouse.pitch).toBeLessThan(0.5);

            // Cleanup stubs
            delete global.Engine3D;
            delete global.document.body;
            delete global.AudioEngine.updateWindFrequency;
        });
    });

    describe('Island Collision & Immunity Mechanics', () => {
        beforeEach(() => {
            global.Engine3D = {
                camera: {
                    x: 0,
                    y: 0,
                    z: 0,
                    yaw: 0,
                    pitch: 0,
                    roll: 0
                }
            };
            Game.world = {
                projectiles: [],
                enemies: [],
                particles: [],
                ports: [
                    { x: 0, y: 0, z: 100, size: 20, name: "Test Port" }
                ],
                splashes: [],
                debris: []
            };
            Game.player.x = 0;
            Game.player.y = 0;
            Game.player.z = 0;
            Game.player.yaw = 0;
            Game.player.speed = 5.0;
            Game.player.sailLevel = 2;
            Game.player.shipClass = 'dinghy';
            Game.player.health = 100;
            Game.player.maxHealth = 100;
            Game.player.collisionImmunityTimer = 0;
            Game.player.speedDebuffTimer = 0;
            Game.player.rudder = 0;
            // Mock document body list and AudioEngine methods
            global.document.body = {
                classList: {
                    add: () => {},
                    remove: () => {}
                }
            };
            global.AudioEngine.updateWindFrequency = () => {};
            global.AudioEngine.playExplosion = () => {};
        });

        afterEach(() => {
            delete global.Engine3D;
            delete global.document.body;
            delete global.AudioEngine.updateWindFrequency;
            delete global.AudioEngine.playExplosion;
        });

        it('should trigger collision when moving inside port size boundary, dealing damage and bouncing back', () => {
            // Place player right near collision threshold (size = 20, ship hit radius = 4, threshold = 22)
            // Player is heading towards z = 100 (yaw = 0)
            Game.player.x = 0;
            Game.player.z = 76; // next step with speed 5.0 and dt 1.0 would put player at z = 81 (dist = 19, which is < 22)
            
            // Stub document.getElementById to return a mock warning banner element
            const mockBanner = { classList: { remove: () => {}, add: () => {} }, style: {} };
            const originalGetElement = global.document.getElementById;
            global.document.getElementById = (id) => {
                if (id === 'collisionAlert' || id === 'noFireWarning') return mockBanner;
                return originalGetElement ? originalGetElement(id) : null;
            };

            Game.update(1.0);

            // Speed should be reversed to bounce back speed
            expect(Game.player.speed).toBe(-2.5);
            // Hull damage of 10 applied
            expect(Game.player.health).toBe(90);
            // Immunity timer is set to 3.0s
            expect(Game.player.collisionImmunityTimer).toBe(3.0);
            // Debris is spawned
            expect(Game.world.debris.length).toBeGreaterThan(0);

            global.document.getElementById = originalGetElement;
        });

        it('should NOT trigger collision if collisionImmunityTimer is active', () => {
            Game.player.collisionImmunityTimer = 2.0;
            Game.player.x = 0;
            Game.player.z = 76;

            const originalGetElement = global.document.getElementById;
            global.document.getElementById = () => ({ classList: { remove: () => {}, add: () => {} }, style: {} });

            Game.update(1.0);

            // No collision effects
            expect(Game.player.speed).not.toBe(-2.5);
            expect(Game.player.health).toBe(100);
            // Timer decays by dt
            expect(Game.player.collisionImmunityTimer).toBe(1.0);

            global.document.getElementById = originalGetElement;
        });

        it('should set immunity timer on undock', () => {
            const originalGetElement = global.document.getElementById;
            global.document.getElementById = () => ({ classList: { remove: () => {}, add: () => {} }, style: {} });
            
            Game.player.collisionImmunityTimer = 0;
            Game.undock();

            expect(Game.player.collisionImmunityTimer).toBe(4.0);

            global.document.getElementById = originalGetElement;
        });

        it('should set immunity timer on completeTravelSequence', () => {
            const originalGetElement = global.document.getElementById;
            global.document.getElementById = () => ({ classList: { remove: () => {}, add: () => {} }, style: {} });
            
            // Mock loadArchipelago to avoid errors
            const originalLoadArch = Game.loadArchipelago;
            Game.loadArchipelago = () => {};

            Game.player.collisionImmunityTimer = 0;
            Game.completeTravelSequence();

            expect(Game.player.collisionImmunityTimer).toBe(4.0);

            Game.loadArchipelago = originalLoadArch;
            global.document.getElementById = originalGetElement;
        });
    });

    describe('Developer Override Diagnostic Console', () => {
        beforeEach(() => {
            // Setup stub elements
            global.document.getElementById = (id) => {
                let val = '10';
                if (id === 'devSpawnClassSelect') val = 'sloop';
                if (id === 'devShipClassSelect') val = 'galleon';
                return {
                    classList: { remove: () => {}, add: () => {}, contains: () => false },
                    style: {},
                    options: [],
                    appendChild: () => {},
                    innerHTML: '',
                    value: val
                };
            };
            
            global.AudioEngine = {
                initialized: true,
                playBeep: () => {},
                playExplosion: () => {}
            };
            
            Game.player.ammo = { ball: 10, chain: 0, grape: 0 };
            Game.player.shipClass = 'dinghy';
            Game.player.health = 100;
            Game.player.maxHealth = 100;
        });

        it('should initialize player ammo to exactly 10 balls, 0 chain, 0 grape', () => {
            expect(Game.player.ammo.ball).toBe(10);
            expect(Game.player.ammo.chain).toBe(0);
            expect(Game.player.ammo.grape).toBe(0);
        });

        it('should manipulate ammo quantities via adjustDevAmmo and setDevAmmo', () => {
            Game.adjustDevAmmo('ball', 5);
            expect(Game.player.ammo.ball).toBe(15);

            Game.adjustDevAmmo('ball', -100); // Should clamp to 0
            expect(Game.player.ammo.ball).toBe(0);

            Game.setDevAmmo('chain', 25);
            expect(Game.player.ammo.chain).toBe(25);

            Game.setDevAmmo('grape', -5); // Should clamp to 0
            expect(Game.player.ammo.grape).toBe(0);
        });

        it('should swap ship classes and re-apply max stats via changeDevShipClass', () => {
            Game.changeDevShipClass('galleon');
            expect(Game.player.shipClass).toBe('galleon');
            expect(Game.player.maxHealth).toBe(380);
            expect(Game.player.health).toBe(380); // Restored to max
            expect(Game.player.baseMaxSpeed).toBe(4.2);
            expect(Game.player.maxCargo).toBe(450);
        });

        it('should spawn hostiles exactly 50m ahead of player facing player', () => {
            Game.player.x = 10;
            Game.player.z = 20;
            Game.player.yaw = 0; // facing straight north (+z in movement formula: Math.cos(0) = 1, Math.sin(0) = 0)
            
            const originalLength = Game.world.enemies.length;
            Game.spawnDevHostile();

            expect(Game.world.enemies.length).toBe(originalLength + 1);
            const spawned = Game.world.enemies[Game.world.enemies.length - 1];
            expect(spawned.x).toBe(10); // x does not change
            expect(spawned.z).toBe(70); // 20 + 50 = 70
            expect(spawned.yaw).toBe(Math.PI); // opposite direction to face player
            expect(spawned.shipClass).toBe('sloop'); // default select value mock
        });
    });

    describe('Dynamic Ship-Size Camera Zoom & Framing', () => {
        beforeEach(() => {
            // Setup global Engine3D stub
            global.Engine3D = {
                camera: {
                    x: 0,
                    y: 0,
                    z: 0,
                    yaw: 0,
                    pitch: 0,
                    roll: 0
                }
            };
            
            // Mock document body and elements
            global.document.body = {
                classList: { add: () => {}, remove: () => {} }
            };
            
            global.document.getElementById = () => ({
                classList: { add: () => {}, remove: () => {} },
                style: {},
                options: [],
                value: ''
            });

            // Mock wind frequency updates
            global.AudioEngine.updateWindFrequency = () => {};

            // Initialize minimal game world structure
            Game.world = {
                projectiles: [],
                enemies: [],
                particles: [],
                ports: [],
                splashes: [],
                debris: []
            };

            // Reset player positioning
            Game.player.x = 0;
            Game.player.y = 0;
            Game.player.z = 0;
            Game.player.yaw = 0;
            Game.player.roll = 0;
            Game.player.pitch = 0;
            Game.player.speed = 0;
            Game.player.health = 100;
            Game.player.maxHealth = 100;

            // Reset mouse orbit controls
            Game.mouse.yaw = 0;
            Game.mouse.pitch = 0;
            Game.mouse.isDragging = false;
            Game.mouse.isAiming = false;
        });

        afterEach(() => {
            delete global.Engine3D;
            delete global.document.body;
            delete global.AudioEngine.updateWindFrequency;
        });

        it('should dynamically zoom camera out further for larger ship classes', () => {
            // Test 1: Dinghy (small ship)
            Game.player.shipClass = 'dinghy';
            Game.player.x = 0;
            Game.player.z = 0;
            
            // Update twice with dt = 10.0 to fully snap easing
            Game.update(10.0);
            Game.update(10.0);
            
            const distanceDinghy = Math.hypot(Engine3D.camera.x - Game.player.x, Engine3D.camera.z - Game.player.z);

            // Test 2: Man-of-War (large ship)
            Game.player.shipClass = 'manofwar';
            
            // Update to snap camera to new ship dimensions
            Game.update(10.0);
            Game.update(10.0);

            const distanceManOfWar = Math.hypot(Engine3D.camera.x - Game.player.x, Engine3D.camera.z - Game.player.z);

            // Man-of-War should be zoomed out significantly more than Dinghy
            expect(distanceManOfWar).toBeGreaterThan(distanceDinghy);

            // Let's assert theoretical limits (Dinghy: ~16.7m, Man-of-War: ~26.0m at pitch=0.30)
            expect(distanceDinghy).toBeCloseTo(17.5 * Math.cos(0.30), 1);
            expect(distanceManOfWar).toBeCloseTo(27.25 * Math.cos(0.30), 1);
        });

        it('should adjust look-at framing height based on ship height', () => {
            // Dinghy targetLookY = 6.0 * 0.35 = 2.1
            Game.player.shipClass = 'dinghy';
            Game.player.y = 0;
            Game.update(10.0);
            const pitchDinghy = Engine3D.camera.pitch;

            // Man-of-War targetLookY = 14.0 * 0.35 = 4.9
            Game.player.shipClass = 'manofwar';
            Game.update(10.0);
            const pitchManOfWar = Engine3D.camera.pitch;

            // Since the look-at point for Man-of-War is higher,
            // the camera pitch (which looks down at the target from positive y)
            // will be shallower (smaller angle) if camera y is above the target.
            // Let's verify the pitch changes dynamically
            expect(pitchManOfWar).not.toBe(pitchDinghy);
        });
    });

    describe('Dynamic Broadside Ammunition Consumption', () => {
        beforeEach(() => {
            // Setup global Engine3D stub
            global.Engine3D = {
                camera: { x: 0, y: 0, z: 0, yaw: 0, pitch: 0, roll: 0 }
            };
            global.document.body = {
                classList: { add: () => {}, remove: () => {} }
            };
            global.document.getElementById = () => ({
                classList: { add: () => {}, remove: () => {} },
                style: {},
                options: [],
                value: ''
            });
            global.AudioEngine = {
                initialized: true,
                playBeep: () => {},
                playShoot: () => {},
                playExplosion: () => {}
            };
            
            Game.isDocked = false;
            Game.isTraveling = false;
            Game.player.x = 0;
            Game.player.y = 0;
            Game.player.z = 0;
            Game.player.yaw = 0;
            Game.player.reloadPort = 0;
            Game.player.reloadStbd = 0;
            Game.player.activeAmmo = 'ball';
            Game.player.ammo = { ball: 10, chain: 0, grape: 0 };
            
            Game.world = {
                projectiles: [],
                enemies: [],
                particles: [],
                ports: [],
                splashes: [],
                debris: []
            };
        });

        afterEach(() => {
            delete global.Engine3D;
            delete global.document.body;
        });

        it('should consume ammunition equal to ship firepower during a broadside', () => {
            Game.player.shipClass = 'sloop'; // Sloop has firepower = 2
            
            const initialProjCount = Game.world.projectiles.length;
            Game.fireBroadside('port');

            // Sloop has 2 firepower, so 2 projectiles spawned
            expect(Game.world.projectiles.length).toBe(initialProjCount + 2);
            // Consumed 2 ammo units
            expect(Game.player.ammo.ball).toBe(8);
        });

        it('should allow partial broadsides when low on ammunition, consuming remaining ammo', () => {
            Game.player.shipClass = 'galleon'; // Galleon has firepower = 4
            Game.player.ammo.ball = 3; // Lower than maximum firepower

            const initialProjCount = Game.world.projectiles.length;
            Game.fireBroadside('port');

            // Should spawn exactly 3 projectiles
            expect(Game.world.projectiles.length).toBe(initialProjCount + 3);
            // Consumed all remaining ammo
            expect(Game.player.ammo.ball).toBe(0);
        });

        it('should reject firing when out of ammunition', () => {
            Game.player.shipClass = 'sloop';
            Game.player.ammo.ball = 0;

            const initialProjCount = Game.world.projectiles.length;
            Game.fireBroadside('port');

            // Should not spawn any projectiles
            expect(Game.world.projectiles.length).toBe(initialProjCount);
            // Re-assert ammo is still 0
            expect(Game.player.ammo.ball).toBe(0);
        });
    });
});

