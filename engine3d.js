/**
 * Vector Buccaneer - 3D Wireframe Rendering Engine
 * Handles coordinate transformations, camera projections, clipping, and canvas line drawing.
 */

const Engine3D = {
    // Camera configuration
    camera: {
        x: 0,
        y: 8,       // Camera height above sea level
        z: -18,     // Camera distance behind ship
        yaw: 0,     // Left-right angle (radians)
        pitch: 0.2, // Up-down angle (radians)
        roll: 0,     // Tilt angle (radians)
        focalLength: 500, // Distance to projection screen
        zNear: 0.5   // Near clipping plane
    },

    // Convert world space coordinates to camera space
    worldToCamera: function(point, cam) {
        // 1. Translate point relative to camera
        const dx = point.x - cam.x;
        const dy = point.y - cam.y;
        const dz = point.z - cam.z;

        // 2. Rotate around Y-axis (Yaw) - corrected direction to align with clockwise movement
        const cosY = Math.cos(cam.yaw);
        const sinY = Math.sin(cam.yaw);
        const x1 = dx * cosY - dz * sinY;
        const z1 = dx * sinY + dz * cosY;
        const y1 = dy;

        // 3. Rotate around X-axis (Pitch)
        const cosP = Math.cos(-cam.pitch);
        const sinP = Math.sin(-cam.pitch);
        const x2 = x1;
        const y2 = y1 * cosP - z1 * sinP;
        const z2 = y1 * sinP + z1 * cosP;

        // 4. Rotate around Z-axis (Roll)
        const cosR = Math.cos(-cam.roll);
        const sinR = Math.sin(-cam.roll);
        const x3 = x2 * cosR - y2 * sinR;
        const y3 = x2 * sinR + y2 * cosR;
        const z3 = z2;

        return { x: x3, y: y3, z: z3 };
    },

    // Project camera-space coordinates to 2D screen coordinates
    project: function(camPoint, width, height, cam) {
        const screenX = width / 2 + (camPoint.x * cam.focalLength) / camPoint.z;
        const screenY = height / 2 - (camPoint.y * cam.focalLength) / camPoint.z;
        return { x: screenX, y: screenY };
    },

    // Clips a line segment (p1 -> p2) against the near clipping plane (z = zNear)
    // Returns an array of two camera-space points [c1, c2], or null if discarded
    clipLine: function(p1, p2, zNear) {
        // If both points are behind the near plane, discard the line
        if (p1.z < zNear && p2.z < zNear) {
            return null;
        }

        // If both points are in front, return unchanged
        if (p1.z >= zNear && p2.z >= zNear) {
            return [p1, p2];
        }

        // Otherwise, clip the line (one point behind, one in front)
        const t = (zNear - p1.z) / (p2.z - p1.z);
        const clippedPoint = {
            x: p1.x + t * (p2.x - p1.x),
            y: p1.y + t * (p2.y - p1.y),
            z: zNear
        };

        if (p1.z < zNear) {
            return [clippedPoint, p2];
        } else {
            return [p1, clippedPoint];
        }
    },

    // Render a 3D wireframe model onto the 2D canvas
    // position: {x, y, z}, rotation: {yaw, pitch, roll}, scale: number
    drawModel: function(ctx, model, position, rotation, scale, color, cam) {
        const dpr = window.devicePixelRatio || 1;
        const width = ctx.canvas.width / dpr;
        const height = ctx.canvas.height / dpr;

        // Precompute local rotation matrices
        const cosY = Math.cos(rotation.yaw || 0);
        const sinY = Math.sin(rotation.yaw || 0);
        const cosP = Math.cos(rotation.pitch || 0);
        const sinP = Math.sin(rotation.pitch || 0);
        const cosR = Math.cos(rotation.roll || 0);
        const sinR = Math.sin(rotation.roll || 0);

        // Transform all model vertices to Camera Space
        const cameraVertices = [];
        for (let i = 0; i < model.vertices.length; i++) {
            const v = model.vertices[i];
            
            // Dynamic sail raising/lowering (model space scaling)
            let vx = v.x;
            let vy = v.y;
            let vz = v.z;

            if (model.sailDeformations) {
                const sailLvl = rotation.sailLevel !== undefined ? rotation.sailLevel : 4;
                const f = sailLvl / 4;
                for (let j = 0; j < model.sailDeformations.length; j++) {
                    const def = model.sailDeformations[j];
                    if (def.indices.includes(i)) {
                        vy = def.topY + (vy - def.topY) * f;
                        vz = def.mastZ + (vz - def.mastZ) * f;
                        break;
                    }
                }
            }

            // 1. Scale
            const sx = vx * scale;
            const sy = vy * scale;
            const sz = vz * scale;

            // 2. Rotate locally around Yaw, Pitch, Roll
            // Roll (Z)
            const rx1 = sx * cosR - sy * sinR;
            const ry1 = sx * sinR + sy * cosR;
            const rz1 = sz;

            // Pitch (X)
            const rx2 = rx1;
            const ry2 = ry1 * cosP - rz1 * sinP;
            const rz2 = ry1 * sinP + rz1 * cosP;

            // Yaw (Y) - Clockwise rotation to align with game physics heading and camera
            const rx3 = rx2 * cosY + rz2 * sinY;
            const ry3 = ry2;
            const rz3 = -rx2 * sinY + rz2 * cosY;

            // 3. Translate to world position
            const wx = rx3 + position.x;
            const wy = ry3 + position.y;
            const wz = rz3 + position.z;

            // 4. Transform to camera space
            const camPoint = this.worldToCamera({ x: wx, y: wy, z: wz }, cam);
            cameraVertices.push(camPoint);
        }

        // Draw edges
        ctx.beginPath();
        for (let i = 0; i < model.edges.length; i++) {
            const edge = model.edges[i];
            const p1 = cameraVertices[edge[0]];
            const p2 = cameraVertices[edge[1]];

            // Clip line against near plane
            const clipped = this.clipLine(p1, p2, cam.zNear);
            if (clipped) {
                const s1 = this.project(clipped[0], width, height, cam);
                const s2 = this.project(clipped[1], width, height, cam);

                ctx.moveTo(s1.x, s1.y);
                ctx.lineTo(s2.x, s2.y);
            }
        }

        // Draw with vector glow effect
        ctx.strokeStyle = color;
        
        // Step 1: Draw the ambient glow layer
        ctx.shadowColor = color;
        ctx.shadowBlur = 8;
        ctx.lineWidth = 2.5;
        ctx.stroke();

        // Step 2: Draw the bright inner core layer
        ctx.shadowBlur = 0;
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1;
        ctx.stroke();
    },

    // Draw the procedural wireframe ocean wave grid
    drawOcean: function(ctx, time, playerPos, cam) {
        const dpr = window.devicePixelRatio || 1;
        const width = ctx.canvas.width / dpr;
        const height = ctx.canvas.height / dpr;
        const color = '#00ffcc'; // Sea Cyan

        // Generate grid lines in X and Z directions around the player
        const gridSize = 160;       // Total ocean tracking radius
        const gridSpacing = 8;      // Distance between grid lines
        const playerGridX = Math.round(playerPos.x / gridSpacing) * gridSpacing;
        const playerGridZ = Math.round(playerPos.z / gridSpacing) * gridSpacing;

        // ocean wave equation
        function getWaveHeight(x, z) {
            // Mix multiple sine waves for rich wave patterns
            const w1 = Math.sin(x * 0.05 + time * 1.5) * Math.cos(z * 0.05 + time * 1.2) * 1.6;
            const w2 = Math.sin(z * 0.12 - time * 2.0) * 0.5;
            return w1 + w2;
        }

        const linesToDraw = [];

        // 1. Z-aligned lines (running forward/backward)
        for (let gx = playerGridX - gridSize; gx <= playerGridX + gridSize; gx += gridSpacing) {
            let lastCamPt = null;
            for (let gz = playerGridZ - gridSize; gz <= playerGridZ + gridSize; gz += gridSpacing) {
                const gy = getWaveHeight(gx, gz);
                const camPt = this.worldToCamera({ x: gx, y: gy, z: gz }, cam);

                if (lastCamPt) {
                    const clipped = this.clipLine(lastCamPt, camPt, cam.zNear);
                    if (clipped) {
                        linesToDraw.push([
                            this.project(clipped[0], width, height, cam),
                            this.project(clipped[1], width, height, cam)
                        ]);
                    }
                }
                lastCamPt = camPt;
            }
        }

        // 2. X-aligned lines (running left/right)
        for (let gz = playerGridZ - gridSize; gz <= playerGridZ + gridSize; gz += gridSpacing) {
            let lastCamPt = null;
            for (let gx = playerGridX - gridSize; gx <= playerGridX + gridSize; gx += gridSpacing) {
                const gy = getWaveHeight(gx, gz);
                const camPt = this.worldToCamera({ x: gx, y: gy, z: gz }, cam);

                if (lastCamPt) {
                    const clipped = this.clipLine(lastCamPt, camPt, cam.zNear);
                    if (clipped) {
                        linesToDraw.push([
                            this.project(clipped[0], width, height, cam),
                            this.project(clipped[1], width, height, cam)
                        ]);
                    }
                }
                lastCamPt = camPt;
            }
        }

        // Draw all ocean lines in a single canvas path for performance
        ctx.beginPath();
        for (let i = 0; i < linesToDraw.length; i++) {
            const line = linesToDraw[i];
            ctx.moveTo(line[0].x, line[0].y);
            ctx.lineTo(line[1].x, line[1].y);
        }

        ctx.strokeStyle = color;
        ctx.shadowColor = color;
        ctx.shadowBlur = 6;
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // Draw thin inner white core
        ctx.shadowBlur = 0;
        ctx.strokeStyle = '#e0ffff';
        ctx.lineWidth = 0.5;
        ctx.stroke();

        return getWaveHeight; // Return height equation for ship alignment
    }
};

// Expose engine globally for browsers
if (typeof window !== 'undefined') {
    window.Engine3D = Engine3D;
}
