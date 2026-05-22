/**
 * Vector Buccaneer - 3D Wireframe Assets & Models
 * Holds 3D model definitions as vertices and edges, plus procedural generation functions.
 */

const Models3D = {
    // Cube model (for crates, debugging)
    cube: {
        vertices: [
            {x: -1, y: -1, z: -1}, // 0
            {x: 1, y: -1, z: -1},  // 1
            {x: 1, y: 1, z: -1},   // 2
            {x: -1, y: 1, z: -1},  // 3
            {x: -1, y: -1, z: 1},  // 4
            {x: 1, y: -1, z: 1},   // 5
            {x: 1, y: 1, z: 1},    // 6
            {x: -1, y: 1, z: 1}    // 7
        ],
        edges: [
            [0, 1], [1, 2], [2, 3], [3, 0], // Back face
            [4, 5], [5, 6], [6, 7], [7, 4], // Front face
            [0, 4], [1, 5], [2, 6], [3, 7], // Connecting edges
            [0, 2], [4, 6]                 // Cross details for crates
        ]
    },

    // A tiny starting boat: Dinghy
    dinghy: {
        vertices: [
            // Hull points (y-up is negative in standard canvas but we use standard math y-up as negative for canvas, let's treat Y as upward and reverse it in projection)
            {x: 0, y: 1.5, z: 3},    // 0 Bow top
            {x: 0, y: 0.2, z: 3},    // 1 Bow bottom
            {x: -1.2, y: 1.2, z: 0},  // 2 Port mid top
            {x: -0.8, y: 0.2, z: 0},  // 3 Port mid bottom
            {x: 1.2, y: 1.2, z: 0},   // 4 Starboard mid top
            {x: 0.8, y: 0.2, z: 0},   // 5 Starboard mid bottom
            {x: -0.9, y: 1.2, z: -2.5},// 6 Port stern top
            {x: -0.6, y: 0.2, z: -2.5},// 7 Port stern bottom
            {x: 0.9, y: 1.2, z: -2.5}, // 8 Starboard stern top
            {x: 0.6, y: 0.2, z: -2.5}, // 9 Starboard stern bottom
            
            // Mast
            {x: 0, y: 1.2, z: 0.5},   // 10 Mast base
            {x: 0, y: 6.0, z: 0.5},   // 11 Mast top
            
            // Sail (billowing back slightly, so z-value curves backward)
            {x: -1.8, y: 2.0, z: 0.3}, // 12 Sail lower port
            {x: 1.8, y: 2.0, z: 0.3},  // 13 Sail lower starboard
            {x: -1.2, y: 5.2, z: 0.5}, // 14 Sail upper port
            {x: 1.2, y: 5.2, z: 0.5},  // 15 Sail upper starboard
            {x: 0, y: 3.6, z: 1.2}     // 16 Billow center
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3], // Bow to port mid
            [0, 4], [1, 5], [4, 5],         // Bow to stbd mid
            [2, 6], [3, 7], [6, 7],         // Port mid to stern
            [4, 8], [5, 9], [8, 9],         // Stbd mid to stern
            [6, 8], [7, 9],                 // Stern transoms
            
            // Mast
            [10, 11],
            
            // Sail lines
            [11, 14], [11, 15],             // Upper yard attachments
            [14, 15],                       // Top yard
            [12, 13],                       // Bottom yard/boom
            [14, 12], [15, 13],             // Sail outer edges
            [11, 16], [16, 10],             // Middle billow seams
            [14, 16], [15, 16], [12, 16], [13, 16] // Billow ribbing
        ],
        sailDeformations: [
            { indices: [12, 13, 14, 15, 16], topY: 5.2, mastZ: 0.5 }
        ]
    },

    // A classic mid-tier ship: Sloop
    sloop: {
        vertices: [
            // Hull
            {x: 0, y: 2.2, z: 6},     // 0 Bow top
            {x: 0, y: 0.2, z: 6},     // 1 Bow bottom
            {x: -2.0, y: 1.8, z: 1.5}, // 2 Port mid top
            {x: -1.2, y: 0.2, z: 1.5}, // 3 Port mid bottom
            {x: 2.0, y: 1.8, z: 1.5},  // 4 Starboard mid top
            {x: 1.2, y: 0.2, z: 1.5},  // 5 Starboard mid bottom
            {x: -1.6, y: 2.0, z: -4.5},// 6 Port stern top
            {x: -1.0, y: 0.4, z: -4.5},// 7 Port stern bottom
            {x: 1.6, y: 2.0, z: -4.5}, // 8 Starboard stern top
            {x: 1.0, y: 0.4, z: -4.5}, // 9 Starboard stern bottom
            {x: 0, y: 3.5, z: 7.5},    // 10 Bowsprit top tip

            // Mainmast
            {x: 0, y: 1.5, z: 1.8},    // 11 Mainmast base
            {x: 0, y: 10.5, z: 1.8},   // 12 Mainmast top

            // Main Sail
            {x: -3.2, y: 3.0, z: 1.4}, // 13 Sail bottom left
            {x: 3.2, y: 3.0, z: 1.4},  // 14 Sail bottom right
            {x: -2.2, y: 9.0, z: 1.8}, // 15 Sail top left
            {x: 2.2, y: 9.0, z: 1.8},  // 16 Sail top right
            {x: 0, y: 6.0, z: 3.0},    // 17 Main sail billow center

            // Jib Sail (triangle in front)
            {x: 0, y: 9.0, z: 1.8},    // 18 Jib stay top
            {x: 0, y: 3.0, z: 6.8},    // 19 Jib stay bottom
            {x: -1.8, y: 3.2, z: 3.2}, // 20 Jib sail clew port
            {x: 1.8, y: 3.2, z: 3.2}   // 21 Jib sail clew stbd
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10], // Bowsprit structure

            // Masts
            [11, 12],

            // Main Sail
            [15, 16], [13, 14], // Yards
            [15, 13], [16, 14], // Edges
            [12, 17], [17, 11], // Seams
            [15, 17], [16, 17], [13, 17], [14, 17],

            // Jib Sail
            [18, 19], // Jib stay wire
            [18, 20], [19, 20], [20, 11], // Port Jib
            [18, 21], [19, 21], [21, 11]  // Starboard Jib
        ],
        sailDeformations: [
            { indices: [13, 14, 15, 16, 17], topY: 9.0, mastZ: 1.8 },
            { indices: [20, 21], topY: 9.0, mastZ: 1.8 } // Jib collapses toward stay top
        ]
    },

    // A massive late-game combat vessel: Galleon
    galleon: {
        vertices: [
            // Hull
            {x: 0, y: 3.5, z: 11},     // 0 Bow top
            {x: 0, y: 0.2, z: 11},     // 1 Bow bottom
            {x: -3.8, y: 2.8, z: 4},   // 2 Port mid top
            {x: -2.2, y: 0.2, z: 4},   // 3 Port mid bottom
            {x: 3.8, y: 2.8, z: 4},    // 4 Starboard mid top
            {x: 2.2, y: 0.2, z: 4},    // 5 Starboard mid bottom
            {x: -3.0, y: 4.8, z: -8},  // 6 Port stern top (High Poop Deck!)
            {x: -1.6, y: 0.6, z: -8},  // 7 Port stern bottom
            {x: 3.0, y: 4.8, z: -8},   // 8 Starboard stern top
            {x: 1.6, y: 0.6, z: -8},   // 9 Starboard stern bottom
            {x: 0, y: 5.0, z: 13.5},   // 10 Bowsprit

            // Foremast
            {x: 0, y: 2.5, z: 7.0},    // 11 Foremast base
            {x: 0, y: 12.0, z: 7.0},   // 12 Foremast top

            // Mainmast
            {x: 0, y: 2.0, z: 0.5},    // 13 Mainmast base
            {x: 0, y: 15.0, z: 0.5},   // 14 Mainmast top

            // Mizzenmast (stern)
            {x: 0, y: 3.2, z: -5.0},   // 15 Mizzenmast base
            {x: 0, y: 10.0, z: -5.0},  // 16 Mizzenmast top

            // Main Sail
            {x: -4.5, y: 3.8, z: 0.0}, // 17 Main bottom left
            {x: 4.5, y: 3.8, z: 0.0},  // 18 Main bottom right
            {x: -3.5, y: 12.5, z: 0.5},// 19 Main top left
            {x: 3.5, y: 12.5, z: 0.5}, // 20 Main top right
            {x: 0, y: 8.5, z: 2.5},    // 21 Main billow center

            // Fore Sail
            {x: -3.5, y: 3.8, z: 6.5}, // 22 Fore bottom left
            {x: 3.5, y: 3.8, z: 6.5},  // 23 Fore bottom right
            {x: -2.8, y: 10.5, z: 7.0},// 24 Fore top left
            {x: 2.8, y: 10.5, z: 7.0}, // 25 Fore top right
            {x: 0, y: 7.2, z: 8.5},    // 26 Fore billow center

            // Mizzen Lateen Sail (triangular fore-and-aft)
            {x: 0, y: 9.5, z: -5.0},   // 27 Mizzen peak
            {x: 0, y: 4.5, z: -3.5},   // 28 Mizzen tack (forward)
            {x: -2.0, y: 4.2, z: -7.0},// 29 Mizzen clew port
            {x: 2.0, y: 4.2, z: -7.0}  // 30 Mizzen clew stbd
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10],

            // Masts
            [11, 12], [13, 14], [15, 16],

            // Main Sail
            [19, 20], [17, 18], [19, 17], [20, 18],
            [14, 21], [21, 13], [19, 21], [20, 21], [17, 21], [18, 21],

            // Fore Sail
            [24, 25], [22, 23], [24, 22], [25, 23],
            [12, 26], [26, 11], [24, 26], [25, 26], [22, 26], [23, 26],

            // Mizzen Sail
            [27, 28], [28, 29], [27, 29],
            [27, 30], [28, 30], [27, 30]
        ],
        sailDeformations: [
            { indices: [17, 18, 19, 20, 21], topY: 12.5, mastZ: 0.5 }, // Main
            { indices: [22, 23, 24, 25, 26], topY: 10.5, mastZ: 7.0 }, // Fore
            { indices: [28, 29, 30], topY: 9.5, mastZ: -5.0 }         // Mizzen lateen
        ]
    },

    // 1. Sleek light cargo carrier with unequal masts: Schooner
    schooner: {
        vertices: [
            // Hull
            {x: 0, y: 2.0, z: 7.0},     // 0 Bow top
            {x: 0, y: 0.2, z: 7.0},     // 1 Bow bottom
            {x: -1.6, y: 1.5, z: 2.5},  // 2 Port mid top
            {x: -1.0, y: 0.2, z: 2.5},  // 3 Port mid bottom
            {x: 1.6, y: 1.5, z: 2.5},   // 4 Starboard mid top
            {x: 1.1, y: 0.2, z: 2.5},   // 5 Starboard mid bottom
            {x: -1.2, y: 1.6, z: -4.5}, // 6 Port stern top
            {x: -0.8, y: 0.3, z: -4.5}, // 7 Port stern bottom
            {x: 1.2, y: 1.6, z: -4.5},  // 8 Starboard stern top
            {x: 0.8, y: 0.3, z: -4.5},  // 9 Starboard stern bottom
            {x: 0, y: 3.0, z: 9.0},     // 10 Bowsprit (long)

            // Foremast (Shorter)
            {x: 0, y: 1.6, z: 3.5},     // 11 Foremast base
            {x: 0, y: 8.5, z: 3.5},     // 12 Foremast top

            // Mainmast (Taller)
            {x: 0, y: 1.4, z: -1.0},    // 13 Mainmast base
            {x: 0, y: 11.0, z: -1.0},   // 14 Mainmast top

            // Fore Sail
            {x: -2.4, y: 2.8, z: 3.3},  // 15 Sail bottom left
            {x: 2.4, y: 2.8, z: 3.3},   // 16 Sail bottom right
            {x: -1.6, y: 7.5, z: 3.5},  // 17 Sail top left
            {x: 1.6, y: 7.5, z: 3.5},   // 18 Sail top right
            {x: 0, y: 5.0, z: 4.3},     // 19 Sail billow center

            // Main Sail
            {x: -2.8, y: 2.6, z: -1.2}, // 20 Sail bottom left
            {x: 2.8, y: 2.6, z: -1.2},  // 21 Sail bottom right
            {x: -1.8, y: 9.5, z: -1.0}, // 22 Sail top left
            {x: 1.8, y: 9.5, z: -1.0},  // 23 Sail top right
            {x: 0, y: 5.8, z: -0.2}     // 24 Sail billow center
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10],

            // Masts
            [11, 12], [13, 14],

            // Fore Sail
            [17, 18], [15, 16], [17, 15], [18, 16],
            [12, 19], [19, 11], [17, 19], [18, 19], [15, 19], [16, 19],

            // Main Sail
            [22, 23], [20, 21], [22, 20], [23, 21],
            [14, 24], [24, 13], [22, 24], [23, 24], [20, 24], [21, 24]
        ],
        sailDeformations: [
            { indices: [15, 16, 17, 18, 19], topY: 8.5, mastZ: 3.5 },
            { indices: [20, 21, 22, 23, 24], topY: 11.0, mastZ: -1.0 }
        ]
    },

    // 2. Knife-thin hull, three forward-leaning (raked) extremely tall masts: Clipper
    clipper: {
        vertices: [
            // Hull
            {x: 0, y: 2.5, z: 9.0},     // 0 Bow top
            {x: 0, y: 0.2, z: 9.0},     // 1 Bow bottom
            {x: -1.3, y: 1.8, z: 3.0},  // 2 Port mid top (narrow!)
            {x: -0.7, y: 0.2, z: 3.0},  // 3 Port mid bottom
            {x: 1.3, y: 1.8, z: 3.0},   // 4 Starboard mid top
            {x: 0.7, y: 0.2, z: 3.0},   // 5 Starboard mid bottom
            {x: -1.0, y: 1.9, z: -5.0}, // 6 Port stern top
            {x: -0.5, y: 0.3, z: -5.0}, // 7 Port stern bottom
            {x: 1.0, y: 1.9, z: -5.0},  // 8 Starboard stern top
            {x: 0.5, y: 0.3, z: -5.0},  // 9 Starboard stern bottom
            {x: 0, y: 4.0, z: 11.5},    // 10 Bowsprit (long, upward sweep)

            // Foremast (raked)
            {x: 0, y: 2.0, z: 5.0},     // 11 Foremast base
            {x: 0, y: 11.0, z: 6.5},    // 12 Foremast top

            // Mainmast (very tall, raked)
            {x: 0, y: 1.8, z: 0.5},     // 13 Mainmast base
            {x: 0, y: 14.0, z: 2.0},    // 14 Mainmast top

            // Mizzenmast (raked)
            {x: 0, y: 2.0, z: -3.5},    // 15 Mizzenmast base
            {x: 0, y: 10.0, z: -2.0},   // 16 Mizzenmast top

            // Fore Sail
            {x: -2.2, y: 3.2, z: 5.1},  // 17 bottom-left
            {x: 2.2, y: 3.2, z: 5.1},   // 18 bottom-right
            {x: -1.6, y: 9.8, z: 6.2},  // 19 top-left
            {x: 1.6, y: 9.8, z: 6.2},   // 20 top-right
            {x: 0, y: 6.5, z: 6.5},     // 21 billow center

            // Main Sail
            {x: -2.8, y: 3.4, z: 0.6},  // 22 bottom-left
            {x: 2.8, y: 3.4, z: 0.6},   // 23 bottom-right
            {x: -2.0, y: 12.5, z: 1.8}, // 24 top-left
            {x: 2.0, y: 12.5, z: 1.8},  // 25 top-right
            {x: 0, y: 7.8, z: 2.2},     // 26 billow center

            // Mizzen Sail
            {x: -1.8, y: 3.0, z: -3.3}, // 27 bottom-left
            {x: 1.8, y: 3.0, z: -3.3},  // 28 bottom-right
            {x: -1.2, y: 8.8, z: -2.1}, // 29 top-left
            {x: 1.2, y: 8.8, z: -2.1},  // 30 top-right
            {x: 0, y: 5.9, z: -1.6}     // 31 billow center
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10],

            // Masts
            [11, 12], [13, 14], [15, 16],

            // Fore Sail
            [19, 20], [17, 18], [19, 17], [20, 18],
            [12, 21], [21, 11], [19, 21], [20, 21], [17, 21], [18, 21],

            // Main Sail
            [24, 25], [22, 23], [24, 22], [25, 23],
            [14, 26], [26, 13], [24, 26], [25, 26], [22, 26], [23, 26],

            // Mizzen Sail
            [29, 30], [27, 28], [29, 27], [30, 28],
            [16, 31], [31, 15], [29, 31], [30, 31], [27, 31], [28, 31]
        ],
        sailDeformations: [
            { indices: [17, 18, 19, 20, 21], topY: 11.0, mastZ: 6.5 },
            { indices: [22, 23, 24, 25, 26], topY: 14.0, mastZ: 2.0 },
            { indices: [27, 28, 29, 30, 31], topY: 10.0, mastZ: -2.0 }
        ]
    },

    // 3. Robust hull, two equal-height masts, fore-and-aft rigging: Brigantine
    brigantine: {
        vertices: [
            // Hull
            {x: 0, y: 2.4, z: 8.0},     // 0 Bow top
            {x: 0, y: 0.2, z: 8.0},     // 1 Bow bottom
            {x: -2.2, y: 1.8, z: 2.0},  // 2 Port mid top
            {x: -1.4, y: 0.2, z: 2.0},  // 3 Port mid bottom
            {x: 2.2, y: 1.8, z: 2.0},   // 4 Starboard mid top
            {x: 1.4, y: 0.2, z: 2.0},   // 5 Starboard mid bottom
            {x: -1.8, y: 2.2, z: -4.5}, // 6 Port stern top
            {x: -1.1, y: 0.4, z: -4.5}, // 7 Port stern bottom
            {x: 1.8, y: 2.2, z: -4.5},  // 8 Starboard stern top
            {x: 1.1, y: 0.4, z: -4.5},  // 9 Starboard stern bottom
            {x: 0, y: 3.4, z: 10.0},    // 10 Bowsprit

            // Masts (Equal heights)
            {x: 0, y: 1.8, z: 4.0},     // 11 Foremast base
            {x: 0, y: 10.5, z: 4.0},    // 12 Foremast top
            {x: 0, y: 1.6, z: -1.5},    // 13 Mainmast base
            {x: 0, y: 10.5, z: -1.5},   // 14 Mainmast top

            // Fore Sail
            {x: -2.8, y: 3.0, z: 3.8},  // 15 bottom-left
            {x: 2.8, y: 3.0, z: 3.8},   // 16 bottom-right
            {x: -2.0, y: 9.0, z: 4.0},  // 17 top-left
            {x: 2.0, y: 9.0, z: 4.0},   // 18 top-right
            {x: 0, y: 6.0, z: 4.8},     // 19 billow center

            // Gaff Main Sail (triangular lateen/gaff boom profile)
            {x: 0, y: 10.2, z: -1.5},   // 20 gaff peak
            {x: 0, y: 3.5, z: -1.0},    // 21 boom tack (forward)
            {x: -2.4, y: 3.2, z: -3.5}, // 22 clew port
            {x: 2.4, y: 3.2, z: -3.5}   // 23 clew stbd
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10],

            // Masts
            [11, 12], [13, 14],

            // Fore Sail
            [17, 18], [15, 16], [17, 15], [18, 16],
            [12, 19], [19, 11], [17, 19], [18, 19], [15, 19], [16, 19],

            // Gaff Main Sail
            [20, 21], [21, 22], [20, 22],
            [20, 23], [21, 23], [20, 23]
        ],
        sailDeformations: [
            { indices: [15, 16, 17, 18, 19], topY: 10.5, mastZ: 4.0 },
            { indices: [21, 22, 23], topY: 10.2, mastZ: -1.5 }
        ]
    },

    // 4. Low-profile military hull, three masts of equal height, aggressive prow angle: Frigate
    frigate: {
        vertices: [
            // Hull (sharp & aggressive)
            {x: 0, y: 2.6, z: 10.5},    // 0 Bow top
            {x: 0, y: 0.2, z: 10.5},    // 1 Bow bottom
            {x: -2.6, y: 2.2, z: 3.5},  // 2 Port mid top
            {x: -1.8, y: 0.2, z: 3.5},  // 3 Port mid bottom
            {x: 2.6, y: 2.2, z: 3.5},   // 4 Starboard mid top
            {x: 1.8, y: 0.2, z: 3.5},   // 5 Starboard mid bottom
            {x: -2.2, y: 2.4, z: -6.5}, // 6 Port stern top
            {x: -1.5, y: 0.4, z: -6.5}, // 7 Port stern bottom
            {x: 2.2, y: 2.4, z: -6.5},  // 8 Starboard stern top
            {x: 1.5, y: 0.4, z: -6.5},  // 9 Starboard stern bottom
            {x: 0, y: 4.2, z: 13.0},    // 10 Bowsprit (straight, military line)

            // Masts (Three equal-height)
            {x: 0, y: 2.2, z: 6.0},     // 11 Foremast base
            {x: 0, y: 11.5, z: 6.0},    // 12 Foremast top
            {x: 0, y: 2.0, z: 0.0},     // 13 Mainmast base
            {x: 0, y: 12.0, z: 0.0},    // 14 Mainmast top
            {x: 0, y: 2.2, z: -4.5},    // 15 Mizzenmast base
            {x: 0, y: 11.5, z: -4.5},   // 16 Mizzenmast top

            // Fore Sail
            {x: -3.0, y: 3.2, z: 5.8},  // 17 bottom-left
            {x: 3.0, y: 3.2, z: 5.8},   // 18 bottom-right
            {x: -2.2, y: 10.0, z: 6.0}, // 19 top-left
            {x: 2.2, y: 10.0, z: 6.0},  // 20 top-right
            {x: 0, y: 6.5, z: 7.2},     // 21 billow center

            // Main Sail
            {x: -3.4, y: 3.0, z: -0.2}, // 22 bottom-left
            {x: 3.4, y: 3.0, z: -0.2},  // 23 bottom-right
            {x: -2.5, y: 10.5, z: 0.0}, // 24 top-left
            {x: 2.5, y: 10.5, z: 0.0},  // 25 top-right
            {x: 0, y: 6.8, z: 1.2},     // 26 billow center

            // Mizzen Sail
            {x: -2.8, y: 3.2, z: -4.7}, // 27 bottom-left
            {x: 2.8, y: 3.2, z: -4.7},  // 28 bottom-right
            {x: -2.0, y: 10.0, z: -4.5},// 29 top-left
            {x: 2.0, y: 10.0, z: -4.5}, // 30 top-right
            {x: 0, y: 6.5, z: -3.7}     // 31 billow center
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10],

            // Masts
            [11, 12], [13, 14], [15, 16],

            // Fore Sail
            [19, 20], [17, 18], [19, 17], [20, 18],
            [12, 21], [21, 11], [19, 21], [20, 21], [17, 21], [18, 21],

            // Main Sail
            [24, 25], [22, 23], [24, 22], [25, 23],
            [14, 26], [26, 13], [24, 26], [25, 26], [22, 26], [23, 26],

            // Mizzen Sail
            [29, 30], [27, 28], [29, 27], [30, 28],
            [16, 31], [31, 15], [29, 31], [30, 31], [27, 31], [28, 31]
        ],
        sailDeformations: [
            { indices: [17, 18, 19, 20, 21], topY: 11.5, mastZ: 6.0 },
            { indices: [22, 23, 24, 25, 26], topY: 12.0, mastZ: 0.0 },
            { indices: [27, 28, 29, 30, 31], topY: 11.5, mastZ: -4.5 }
        ]
    },

    // 5. Extremely bulbous rounded "walnut" hull, towering castles, three short fat masts: Carrack
    carrack: {
        vertices: [
            // Hull (high bulbous fore/sterncastles, deep rounded mid-section)
            {x: 0, y: 4.5, z: 8.5},     // 0 Bow top (towering!)
            {x: 0, y: 0.2, z: 8.5},     // 1 Bow bottom
            {x: -3.5, y: 2.5, z: 1.5},  // 2 Port mid top (very wide)
            {x: -2.2, y: 0.2, z: 1.5},  // 3 Port mid bottom
            {x: 3.5, y: 2.5, z: 1.5},   // 4 Starboard mid top
            {x: 2.2, y: 0.2, z: 1.5},   // 5 Starboard mid bottom
            {x: -2.8, y: 5.2, z: -5.5}, // 6 Port stern top (towering stern)
            {x: -1.8, y: 0.6, z: -5.5}, // 7 Port stern bottom
            {x: 2.8, y: 5.2, z: -5.5},  // 8 Starboard stern top
            {x: 1.8, y: 0.6, z: -5.5},  // 9 Starboard stern bottom
            {x: 0, y: 5.2, z: 10.5},    // 10 Bowsprit

            // Masts (short & stocky)
            {x: 0, y: 3.0, z: 5.0},     // 11 Foremast base
            {x: 0, y: 10.0, z: 5.0},    // 12 Foremast top
            {x: 0, y: 2.2, z: -1.0},    // 13 Mainmast base
            {x: 0, y: 12.0, z: -1.0},   // 14 Mainmast top
            {x: 0, y: 3.8, z: -4.0},    // 15 Mizzenmast base
            {x: 0, y: 8.5, z: -4.0},    // 16 Mizzenmast top

            // Fore Sail
            {x: -3.5, y: 4.0, z: 4.8},  // 17 bottom-left
            {x: 3.5, y: 4.0, z: 4.8},   // 18 bottom-right
            {x: -2.4, y: 9.0, z: 5.0},  // 19 top-left
            {x: 2.4, y: 9.0, z: 5.0},   // 20 top-right
            {x: 0, y: 6.5, z: 6.2},     // 21 billow center

            // Main Sail
            {x: -4.0, y: 3.4, z: -1.3}, // 22 bottom-left
            {x: 4.0, y: 3.4, z: -1.3},  // 23 bottom-right
            {x: -2.8, y: 10.8, z: -1.0},// 24 top-left
            {x: 2.8, y: 10.8, z: -1.0}, // 25 top-right
            {x: 0, y: 7.0, z: 0.5},     // 26 billow center

            // Mizzen Sail
            {x: -2.2, y: 4.8, z: -4.2}, // 27 bottom-left
            {x: 2.2, y: 4.8, z: -4.2},  // 28 bottom-right
            {x: -1.5, y: 7.8, z: -4.0}, // 29 top-left
            {x: 1.5, y: 7.8, z: -4.0},  // 30 top-right
            {x: 0, y: 6.0, z: -3.2}     // 31 billow center
        ],
        edges: [
            // Hull
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10],

            // Masts
            [11, 12], [13, 14], [15, 16],

            // Fore Sail
            [19, 20], [17, 18], [19, 17], [20, 18],
            [12, 21], [21, 11], [19, 21], [20, 21], [17, 21], [18, 21],

            // Main Sail
            [24, 25], [22, 23], [24, 22], [25, 23],
            [14, 26], [26, 13], [24, 26], [25, 26], [22, 26], [23, 26],

            // Mizzen Sail
            [29, 30], [27, 28], [29, 27], [30, 28],
            [16, 31], [31, 15], [29, 31], [30, 31], [27, 31], [28, 31]
        ],
        sailDeformations: [
            { indices: [17, 18, 19, 20, 21], topY: 10.0, mastZ: 5.0 },
            { indices: [22, 23, 24, 25, 26], topY: 12.0, mastZ: -1.0 },
            { indices: [27, 28, 29, 30, 31], topY: 8.5, mastZ: -4.0 }
        ]
    },

    // 6. Giant three-masted flagship, high stern castles, dual-deck gunport details: Man-of-War
    manofwar: {
        vertices: [
            // Hull (gigantic, double rails for gunports)
            {x: 0, y: 4.6, z: 14.0},     // 0 Bow top
            {x: 0, y: 0.2, z: 14.0},     // 1 Bow bottom
            {x: -4.8, y: 3.4, z: 5.0},    // 2 Port mid top
            {x: -3.0, y: 0.2, z: 5.0},    // 3 Port mid bottom
            {x: 4.8, y: 3.4, z: 5.0},     // 4 Starboard mid top
            {x: 3.0, y: 0.2, z: 5.0},     // 5 Starboard mid bottom
            {x: -3.8, y: 6.2, z: -10.0},  // 6 Port stern top (Towering Poop)
            {x: -2.2, y: 0.8, z: -10.0},  // 7 Port stern bottom
            {x: 3.8, y: 6.2, z: -10.0},   // 8 Starboard stern top
            {x: 2.2, y: 0.8, z: -10.0},   // 9 Starboard stern bottom
            {x: 0, y: 6.5, z: 17.0},     // 10 Bowsprit (mega length)

            // Masts (Heavy massive setup)
            {x: 0, y: 3.2, z: 9.5},      // 11 Foremast base
            {x: 0, y: 14.5, z: 9.5},     // 12 Foremast top
            {x: 0, y: 2.6, z: 2.0},      // 13 Mainmast base
            {x: 0, y: 17.5, z: 2.0},     // 14 Mainmast top
            {x: 0, y: 4.2, z: -6.5},     // 15 Mizzenmast base
            {x: 0, y: 11.5, z: -6.5},    // 16 Mizzenmast top

            // Gun Deck trim lines (Double deck accentuation!)
            {x: -4.0, y: 1.8, z: 5.0},    // 17 Port mid lower deck rail
            {x: 4.0, y: 1.8, z: 5.0},     // 18 Stbd mid lower deck rail
            {x: -3.2, y: 2.4, z: -10.0},  // 19 Port stern lower deck rail
            {x: 3.2, y: 2.4, z: -10.0},   // 20 Stbd stern lower deck rail

            // Fore Sail
            {x: -4.4, y: 4.2, z: 9.2},   // 21 bottom-left
            {x: 4.4, y: 4.2, z: 9.2},    // 22 bottom-right
            {x: -3.2, y: 13.0, z: 9.5},  // 23 top-left
            {x: 3.2, y: 13.0, z: 9.5},   // 24 top-right
            {x: 0, y: 8.6, z: 11.5},     // 25 billow center

            // Main Sail
            {x: -5.0, y: 3.8, z: 1.5},   // 26 bottom-left
            {x: 5.0, y: 3.8, z: 1.5},    // 27 bottom-right
            {x: -3.8, y: 15.5, z: 2.0},  // 28 top-left
            {x: 3.8, y: 15.5, z: 2.0},   // 29 top-right
            {x: 0, y: 9.6, z: 4.5},      // 30 billow center

            // Mizzen Lateen Sail (Classic triangular sail)
            {x: 0, y: 11.0, z: -6.5},    // 31 Mizzen peak
            {x: 0, y: 5.5, z: -4.5},     // 32 Mizzen tack (forward)
            {x: -2.4, y: 5.2, z: -8.5},  // 33 Mizzen clew port
            {x: 2.4, y: 5.2, z: -8.5}    // 34 Mizzen clew stbd
        ],
        edges: [
            // Hull Outlines
            [0, 1], [0, 2], [1, 3], [2, 3],
            [0, 4], [1, 5], [4, 5],
            [2, 6], [3, 7], [6, 7],
            [4, 8], [5, 9], [8, 9],
            [6, 8], [7, 9],
            [0, 10], [1, 10],

            // Gun Deck Accent lines (Double deck details!)
            [3, 17], [17, 19], [19, 7],  // Port lower deck level
            [5, 18], [18, 20], [20, 9],  // Stbd lower deck level
            [2, 17], [4, 18], [6, 19], [8, 20], // Vertical structure support wire struts

            // Masts
            [11, 12], [13, 14], [15, 16],

            // Fore Sail
            [23, 24], [21, 22], [23, 21], [24, 22],
            [12, 25], [25, 11], [23, 25], [24, 25], [21, 25], [22, 25],

            // Main Sail
            [28, 29], [26, 27], [28, 26], [29, 27],
            [14, 30], [30, 13], [28, 30], [29, 30], [26, 30], [27, 30],

            // Mizzen lateen
            [31, 32], [32, 33], [31, 33],
            [31, 34], [32, 34], [31, 34]
        ],
        sailDeformations: [
            { indices: [21, 22, 23, 24, 25], topY: 14.5, mastZ: 9.5 },
            { indices: [26, 27, 28, 29, 30], topY: 17.5, mastZ: 2.0 },
            { indices: [32, 33, 34], topY: 11.0, mastZ: -6.5 }
        ]
    },

    // A beautiful 3D wireframe Lighthouse port tower
    lighthouse: {
        vertices: [
            // Circular base ring (8-sided)
            {x: -2.5, y: 0, z: -2.5}, // 0
            {x: 0, y: 0, z: -3.5},    // 1
            {x: 2.5, y: 0, z: -2.5},  // 2
            {x: 3.5, y: 0, z: 0},     // 3
            {x: 2.5, y: 0, z: 2.5},   // 4
            {x: 0, y: 0, z: 3.5},     // 5
            {x: -2.5, y: 0, z: 2.5},  // 6
            {x: -3.5, y: 0, z: 0},    // 7

            // Mid tower ring (narrower, 8-sided) at y=10
            {x: -1.5, y: 10, z: -1.5}, // 8
            {x: 0, y: 10, z: -2.0},    // 9
            {x: 1.5, y: 10, z: -1.5},  // 10
            {x: 2.0, y: 10, z: 0},     // 11
            {x: 1.5, y: 10, z: 1.5},   // 12
            {x: 0, y: 10, z: 2.0},     // 13
            {x: -1.5, y: 10, z: 1.5},  // 14
            {x: -2.0, y: 10, z: 0},    // 15

            // Gallery deck ring (wider flange) at y=11
            {x: -2.0, y: 11, z: -2.0}, // 16
            {x: 2.0, y: 11, z: -2.0},  // 17
            {x: 2.0, y: 11, z: 2.0},   // 18
            {x: -2.0, y: 11, z: 2.0},  // 19

            // Lantern room (narrower) at y=13.5
            {x: -1.0, y: 13.5, z: -1.0}, // 20
            {x: 1.0, y: 13.5, z: -1.0},  // 21
            {x: 1.0, y: 13.5, z: 1.0},   // 22
            {x: -1.0, y: 13.5, z: 1.0},  // 23

            // Roof cap peak at y=15.5
            {x: 0, y: 15.5, z: 0}       // 24
        ],
        edges: [
            // Base ring
            [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 0],
            // Mid ring
            [8, 9], [9, 10], [10, 11], [11, 12], [12, 13], [13, 14], [14, 15], [15, 8],
            // Vertical tower lines
            [0, 8], [1, 9], [2, 10], [3, 11], [4, 12], [5, 13], [6, 14], [7, 15],
            
            // Gallery flange
            [8, 16], [10, 17], [12, 18], [14, 19],
            [16, 17], [17, 18], [18, 19], [19, 16],

            // Lantern columns
            [16, 20], [17, 21], [18, 22], [19, 23],
            [20, 21], [21, 22], [22, 23], [23, 20],

            // Roof cap
            [20, 24], [21, 24], [22, 24], [23, 24]
        ]
    },

    // Procedurally generates a beautiful 3D wireframe topographic island
    // Returns a mesh object with { vertices, edges, color }
    generateIsland: function(seed, size, heightMax, ringsCount = 4, sectors = 12) {
        const vertices = [];
        const edges = [];
        
        // Simple deterministic random generator based on seed
        function random(s) {
            let x = Math.sin(s) * 10000;
            return x - Math.floor(x);
        }

        const islandType = Math.abs(seed) % 4;

        // 1. Generate peak (vertex 0) at the center
        let peakHeight = heightMax;
        if (islandType === 1) {
            peakHeight = heightMax * 0.4; // Saddle point height
        } else if (islandType === 3) {
            peakHeight = heightMax * 0.15; // Shallow lagoon center
        }
        vertices.push({ x: 0, y: peakHeight, z: 0 });

        // 2. Generate concentric rings
        // Ring 0 is the closest to the center (high altitude), Ring ringsCount-1 is sea level (widest)
        for (let r = 0; r < ringsCount; r++) {
            const fraction = (r + 1) / ringsCount; // 0.25, 0.5, 0.75, 1.0
            const radius = size * fraction;
            // Height falls off in a dome/volcanic profile
            const height = heightMax * Math.pow(1 - fraction, 1.5);

            for (let s = 0; s < sectors; s++) {
                const angle = (s / sectors) * Math.PI * 2;
                
                // Add noise perturbation to make the coastlines/slopes rugged
                const noiseSeed = seed + r * 17 + s * 31;
                const noiseDist = (random(noiseSeed) - 0.5) * (size * 0.15) * fraction;
                const noiseHeight = (random(noiseSeed + 5) - 0.5) * (heightMax * 0.15);

                let finalRadius = radius + noiseDist;
                let vx = Math.cos(angle) * finalRadius;
                let vz = Math.sin(angle) * finalRadius;
                let vy = height + noiseHeight;

                if (islandType === 0) {
                    // Volcanic Dome (standard uniform circular dome)
                    vy = Math.max(0, vy);
                } else if (islandType === 1) {
                    // Double-Peak Saddle
                    const heightMod = 0.2 + 0.8 * (0.5 + 0.5 * Math.cos(2 * angle));
                    const radiusMod = 0.8 + 0.4 * Math.abs(Math.cos(angle));
                    finalRadius = radius * radiusMod + noiseDist;
                    vx = Math.cos(angle) * finalRadius;
                    vz = Math.sin(angle) * finalRadius;
                    vy = Math.max(0, height * heightMod + noiseHeight);
                } else if (islandType === 2) {
                    // Elongated Barrier Ridge
                    const heightMod = 0.6 + 0.4 * Math.pow(Math.abs(Math.cos(angle)), 0.5);
                    vx = Math.cos(angle) * finalRadius * 1.6;
                    vz = Math.sin(angle) * finalRadius * 0.6;
                    vy = Math.max(0, height * heightMod + noiseHeight);
                } else if (islandType === 3) {
                    // Crescent Bay / Atoll
                    const angleMod = Math.sin(angle);
                    const radiusMod = 0.8 + 0.5 * angleMod;
                    const heightMod = Math.pow(Math.max(0, 0.4 + 0.6 * angleMod), 2);
                    finalRadius = radius * radiusMod + noiseDist;
                    vx = Math.cos(angle) * finalRadius;
                    vz = Math.sin(angle) * finalRadius;
                    vy = Math.max(0, height * heightMod + noiseHeight);
                }

                vertices.push({ x: vx, y: vy, z: vz });
            }
        }

        // 3. Generate Edges
        // Connect Peak to Ring 0
        for (let s = 0; s < sectors; s++) {
            const nextSector = (s + 1) % sectors;
            const r0Idx = 1 + s;
            const r0NextIdx = 1 + nextSector;
            
            edges.push([0, r0Idx]); // Peak to ring 0 vertex
            edges.push([r0Idx, r0NextIdx]); // Ring 0 circumferential line
        }

        // Connect concentric rings
        for (let r = 0; r < ringsCount - 1; r++) {
            const ringOffset = 1 + r * sectors;
            const nextRingOffset = 1 + (r + 1) * sectors;

            for (let s = 0; s < sectors; s++) {
                const nextSector = (s + 1) % sectors;
                
                const currV = ringOffset + s;
                const currVNext = ringOffset + nextSector;
                
                const outerV = nextRingOffset + s;
                const outerVNext = nextRingOffset + nextSector;

                edges.push([currV, outerV]);      // Radial lines connecting rings
                edges.push([outerV, outerVNext]); // Circumferential contour lines
                
                // Optional: diagonal triangulation lines for a more grid-like, hi-tech wireframe structure
                if ((s + r) % 2 === 0) {
                    edges.push([currV, outerVNext]);
                }
            }
        }

        return {
            vertices: vertices,
            edges: edges
        };
    }
};

// Expose models globally for browsers
if (typeof window !== 'undefined') {
    window.Models3D = Models3D;
}
