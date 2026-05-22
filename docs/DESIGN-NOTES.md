# Wireframe Pirate Game — Design Notes & Backlog

Captured from a chat about porting the JS prototype to Godot and fleshing out systems. Not a spec, just a dump of ideas worth not losing.

## Port to Godot

- Don't port line-by-line. Use the JS version as a playable spec, rebuild idiomatically.
- Tests are your design doc — read those before rebuilding.
- GDScript over C# for a weekend project (tight integration, hot reload).
- Mental shift: scene tree + signals, not classes with callbacks.
- Wireframe options in Godot:
  - 3D meshes + wireframe shader (flexible, clean)
  - ImmediateMesh drawing lines directly (closer to original Elite)
- Timebox "learn Godot basics" to ~2–3 hours before starting. "Your First 3D Game" tutorial is genuinely good.

## Aesthetic direction

- Wireframe + retro-CRT UI is the game's identity. Don't chase realism — it dissolves the question.
- Layers to deepen the look without going representational:
  - Particle effects for cannon fire
  - Screen-space CRT shader, scanlines
  - Bloom on bright wireframes
- Lean into the sci-fi-adjacent reading the aesthetic already implies. Stops the game needing to "behave like" the Caribbean.

## Crew system (next up)

- Crew morale, not just count/skill, is the underrated bit.
- Morale inputs: pay, food quality, rum, recent battles, time at sea, shore leave, spoils.
- Low morale → slower reload, refused orders, mutiny risk.
- Hybrid model: bulk crew as a number (gunners, sailors, riggers) + named officers (bosun, master gunner, sailing master, surgeon) with passive bonuses. Officers can be killed by grape — creates attachment without bookkeeping.

## Combat depth

- Systems damage interplay is where it sings:
  - Ball → hull → flooding → pumping (crew job) or sink
  - Chain → rigging/sails → speed loss → disengagement denial
  - Grape → crew → fewer guns crewed → cascading damage
- Decision space: kill or capture? Grape to soften, then board.
- **Boarding** is the natural endgame of grape damage. Doesn't need to be deep — Pirates!-style duel or quick resolution on crew count + morale + captain stat.
- Keep combat as a tax on bad route planning, not the main event.

## Cargo capacity as central tension

- Food, rum, ammo (ball/chain/grape), trade goods, repair supplies all compete for finite hold.
- Food spoilage: salt pork lasts, fresh provisions don't. Provisioning for long routes becomes a real decision.
- Spoiled food tanks morale faster than no food.

## Economy & trading

- Already solid: no perfect info, tavern gossip, supply/demand, archipelago variance.
- Possible additions:
  - Events that spike demand (wars, blockades, festivals)
  - Information asymmetry as gameplay — out-of-date market gazettes, rumour quality varying by source
  - Information itself as a resource

## Information & memory as resources (already implemented)

- **Tavern bribery**: pay tavern keeper for more accurate trade rumours. Meta-economy decision — spend on info to make better trading decisions.
  - Natural extensions: drunk patrons, suspicious strangers, rival captains as alternative info sources with different cost/reliability curves.
- **Ship stock persistence**: ships available at *some* ports, stock rotates slowly. Player remembers which port had the upgrade they want and saves toward it.
  - Gives ports identity, makes map memory matter, creates cross-session goals.
  - **Watch out**: tension with procgen archipelagos. If islands regenerate between runs, ship-in-port-X memory dies with the run. Fine for roguelike framing; needs handling if going persistent-world.

## Reputation system (not yet implemented)

- Branching consequences from port authority interactions.
- Faction standing affects: dock access, prices, inspection risk, whether ports trade with you at all.
- Smuggling routes / black market access for ports that won't trade legitimately.
- UI surfacing: at-a-glance on the map (lean on existing faction colour).

## Factions (currently colour-only)

- Cheapest high-leverage unlock: **contraband by jurisdiction**. Same good, legal here, illegal there, premium prices because of it. Plays into hold tension and reputation.
- **Letters of marque**: be a legal privateer for one faction = pirate to another. Free dramatic mechanic.
- **Faction wars** generate emergent content: war goods spike in price, blockades make routes dangerous, switching allegiance becomes a real choice.
- Diplomatic gradient: allied / friendly / neutral / tense / hostile / war. Each tier changes port behaviour (inspections, warning shots, full engagement).
- Naming: pseudo-historical with serial numbers filed off (Crown / Empire / Republic / Free Cities) might serve better than literal English/Spanish/French given the sci-fi-adjacent aesthetic.

## World structure

- Fixed archipelagos + procgen within = good structure. Keep it.
- Give each archipelago identity (tropical trading hub, naval stronghold, pirate haven, storm-wracked frontier).
- Procgen with rules, not random scatter — pirate archipelago has hidden coves and fewer patrols, naval one has choke points and patrol routes.
- Fast travel should cost (time, supplies, risk) — otherwise it undermines the trading layer. "Open sea leg with abstracted random events" beats instant teleport.
- Make procgen ports memorable: distinctive NPC, unique good, or quirk — even if assembled from a pool.

## Ambush triggers (currently random roll)

- Random rolls age badly — players learn it's dice and stop engaging with route choice.
- Better inputs:
  - Route danger rating (informed by tavern gossip)
  - Cargo value (pirates have port spies)
  - Reputation (infamous pirates hunted by navy, infamous smugglers ambushed by rivals)
  - Ship profile (juicy merchantman vs lean sloop)
  - Time of day / weather (fog and night favour ambushers)
- **Show risk before committing.** Hidden rolls feel like cheating even when fair.

## No-fire zones (already implemented)

- Ports have no-fire zones. Violations spawn a port authority galleon.
- Applies to pirates too — emergent tactic: run for port, hold fire, let the pursuing pirate spawn your rescue.
- Possible extensions:
  - Faction-aware response (English port reacts to Spanish ship firing nearby — diplomatic incident territory)
  - Reputation/bounty credit if pirate gets sunk by authority while chasing you
  - Smarter pirate AI that breaks off near the boundary — creates "hanging back, waiting" tension
  - Abuse mitigation if needed: cooldown on authority response, or "authority remembers" rep hit. Don't pre-emptively fix.

## Environmental / ambient

- Flotsam already in. Hooks for future use:
  - Battle debris (environmental storytelling)
  - Salvageable cargo
  - Message-in-a-bottle events
  - Denser flotsam in dangerous waters

## Cosmic horror angle (optional, if leaning sci-fi)

- Wireframe lends itself to "things in the deeps that should not be charted."
- Sunless Sea / Dredge territory.
- Tavern gossip becomes considerably more unsettling.

## Title

**FATHOM.EXE**

Triple meaning: unit of depth / the verb (to comprehend) / the abyss itself. Scales with player arc — checking depth charts early, fathoming politics mid-game, fathoming what the glitched galleon means by the end.

## Open questions

- Stay vibe-coded JS, port to Godot, or both (JS as prototype, Godot as the "real" version)?
- Meta-progression layer between sessions, or pure session-based?
- How heavy to go on the sci-fi reading vs keeping it ambiguous?

## Endgame design (10-hour run target)

### Core structure: port ownership as phase shift

Not a victory screen but a *graduation* from trading game to strategic game. Phase shift in gameplay verbs:
- Develop the port (shipyard, taverns, walls, market — affects regional economy)
- Defend the port (rival pirates, faction navies, the legendary galleon)
- Manipulate economy (set prices, control specific goods regionally)
- Political consequences (taking a faction port starts a war; building from hidden cove invites discovery)

### Pacing (rough)

- Hours 1–3: Learn the loop. Trading, ambushes, first upgrades.
- Hours 3–6: Mastery. Trusted route, gossip network, real money.
- Hours 6–8: The signal. Hints that ports can be taken/bought start appearing.
- Hours 8–10: Conquest and consequences. Take a port, deal with fallout, fortify.
- Climax: Legendary galleon siege.
- Close: Retirement screen scoring the player's life.

### Multiple paths to port ownership

Don't gate behind one playstyle. Options:
- Buy from corrupt governor
- Take by force
- Build from hidden cove
- Inherit from a dying captain (quest line)

Each suits different playstyles. All lead to the same endgame event.

### The legendary galleon (final assault)

Final assault on the player's port. Combines climactic combat with sci-fi reveal.

**Sci-fi tip**: galleon is *visibly wrong* — Gatling gun / rotary cannon / experimental weapon. Reveals world has more going on than wooden ships and powder. Sequel hook.

**Two paths to victory, same event**:
- **Combat path**: fight the galleon directly with late-game ship + upgrades.
- **Political path**: built faction clout through the mid-game arrives as allied fleets at the siege.

This is the key design move — same climactic moment, different ways of arriving at it. Makes mid-game political decisions feel weighted bc rep literally becomes naval support.

### Clout-to-fleet mechanics (options)

- **Tiered rep**: each faction at max = N warships at siege. Legible, min-maxable.
- **Named captains via quest completions**: specific contracts unlock specific captains/ships. More flavour, more authored content.
- **Hybrid**: faction rep gives generic fleet; quests give named captains and special ships. Combination is what makes siege spectacular vs adequate.

### Stylistic violation as boss design

**Ontological violation, not colour swap.** The galleon appears to be made of different stuff than the world it inhabits. Wireframe universe + pixelated/glitching galleon = instant legibility that it doesn't belong, without needing lore to explain.

This also implies the wireframe rendering is *itself* a representation of the world, not the world itself — the galleon is the thing that breaks the rendering. Sells the sci-fi/cosmic horror reading without committing to either.

**Specific effects to combine**:
- Pixelation at silhouette edges, more solid toward centre — suggests "imperfectly resolved" by the world's rendering
- Polygon tearing / vertex jumps, intermittent, like data corruption
- Wrong shader: solid-flat colour in a wireframe world. Looks like a hole in reality. Or CRT scanlines.
- Audio glitch on top: short dropouts, digital artefacts when in line of sight
- HUD acknowledges the problem: wind telemetry glitches near it, contacts list shows `VESSEL TYPE: [UNKNOWN]` or `[CORRUPTED]` or `[ERROR]`

**Technically cheaper than a hero asset.** Standard wireframe galleon mesh + glitch shader stack. Shader work scales; the asset itself is reused. Lots of Godot glitch shader work to stand on.

### First sighting: pre-climax encounter

Don't let the player just turn up at the siege having never seen it. First sighting needs to be an *event*:

- Tavern gossip earlier mentions strange sails on the horizon. Player thinks nothing of it.
- Mid-passage, routine trade run, alone on open sea, something appears at edge of draw distance.
- HUD pings contact but icon flickers, IFF can't classify.
- Player turns to look: pixelated, glitching, *huge*, moves wrong.
- It doesn't engage. Passes. HUD glitches until out of range. Player is alone again.
- Next port: tavern full of people who saw it too. Old captains with stories.

Player should be *afraid* of meeting it again before they fight it. The horror is in the implication that something in their world doesn't fit their world's rules.

### Foreshadowing requirements

Galleon needs to be feared before fought:
- Tavern gossip from mid-game
- Glimpse on horizon during a trade run
- A destroyed port still smouldering, attributed to it
- Maybe one survivor who saw it

### Design watch-outs

- **Political path must feel active, not passive.** Player can't just spectate while allied fleet does the work. Their flagship is the command vessel; fleet only operates if they survive; killing blow must be theirs.
- **Don't gate port ownership behind one specific path.** Trader-pacifist who played beautifully for 8 hours deserves an endgame too.
- **Avoid arbitrary number-go-up endings.** "Reach 1m doubloons" doesn't change game-shape. Endgame should *play different*, not just longer.

### Cosmic horror as flavour layer (not main endgame)

Optional thread woven through:
- Tavern rumours of things in the deeps
- Charts hinting at ports that shouldn't exist
- One of the takeable ports is *wrong* (cheaper to take, locals are strange, gods are wrong)
- Sequel/DLC seed rather than mandatory third act

### Ending: retirement scoring

After surviving the siege, player chooses when to formally retire. Game scores their life:
- Wealth, infamy, fleet size, ports held, factions allied/destroyed
- Named crew survived / died
- Notable events
- "And so the legend of [captain name] passed into tavern song..."

Pirates! style. Gives the player agency over their ending and makes the close feel earned.
