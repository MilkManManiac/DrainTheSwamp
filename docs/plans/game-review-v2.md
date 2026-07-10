> **SUPERSEDED (2026-07-09)** by `full-audit-2026-07.md` (the 2026-07 five-track audit and its phased plan).

# Game Review v2 — Full Audit & Roadmap

## Date: 2026-02-17

---

## 1. Current State Summary

### What Exists
- 10 overworld pools (Puddle → The Atlantic): 5 gal to 10B gal, exponential scaling
- 8 manual/semi-auto tools (Hands → Water Wagon): output 1.15^level, cost 1.30^level
- 6 upgrades: Rain Collector, Splash Guard, Auto-Seller, Lucky Charm, Auto-Scooper, Lantern
- 7 stats: Carrying Cap, Move Speed, Stamina, Stamina Regen, Water Value, Scoop Power, Drain Mastery
- 1 camel (auto-carry water to shop, capped at 1, speed capped at 8 upgrades)
- 10 caves (one per pool), each with 1-3 internal pools, loot nodes, and lore walls
- Full day/night cycle (5 min) with 30+ responsive visual systems
- Weather (rain + lightning)
- 12+ procedural creature types (fish, frogs, turtles, tadpoles, dragonflies, butterflies, fireflies, birds, crickets, owl, seaweed, bioluminescent plants)
- Custom shaders: water (reflection, sparkle, foam, caustics), terrain (noise+striation), post-process (bloom, shimmer, grain, vignette)
- Gradient sky, volumetric clouds, sun/moon arcs, shooting stars, aurora
- HUD, Shop (3 tabs), Menu panel
- Auto-save every 30s, save version 15
- Cave lore tells a 10-part conspiracy story

### What's Working Great
- **Visual world is outstanding.** The density of animated creatures, weather, day/night responsive systems makes the world genuinely feel alive.
- **Early game flow (Puddle through Bog)** has a satisfying purchase-progress rhythm. New tools become affordable roughly when you finish each pool.
- **Cave lore progression** tells a coherent conspiracy story from strange markings → military presence → government containment → black site → "the source of all water."
- **Economy rebalance v4** is solid. Cost outpaces output (1.30 vs 1.15), asymptotic caps on Splash Guard/Lantern prevent trivializing mechanics.
- **Per-pool water customization** (unique colors, shader params, wave behavior) gives each area its own character.
- **Fish dying when pools drain** is poignant environmental storytelling.

---

## 2. The 3 Biggest Problems

### Problem 1: Walking is the #1 Fun-Killer
The world is 5,500px wide. The shop is at x=30. Late-game pools start at x=3000+. At max movement speed (capped at 5 levels, ~211 px/s), the player spends **70%+ of their time walking** — not scooping, not buying, not strategizing. Just walking back and forth.

The camel helps somewhat (auto-carries water to shop) but is limited to 1 with small capacity. The Auto-Seller upgrade eliminates sell trips but only when inventory is full. The core problem remains: the player must physically walk to each pool to scoop.

### Problem 2: No Meaningful Idle Income
- Rain Collector caps at ~$5/s (negligible when pools cost $2K+/gal)
- Elephant worker was removed (visual + shop UI gone, backend code is dead)
- Pump system from design doc is not visible in the world
- After mid-game, the **only** way to progress is manual scooping of millions of gallons

This is where most players would quit. The late game is pure grind with no mechanical variety.

### Problem 3: Invisible Progression
- No pool progress UI (can't see how much of each pool is drained)
- No cave unlock notifications (player must discover by walking to the right spot)
- No minimap or world position indicator in a 5,500px world
- No milestones or celebrations for partial drain progress
- No quest system or progression guide — player must figure out what to do next

---

## 3. Bugs & Issues

### Already Fixed (This Session)
| Bug | Fix |
|-----|-----|
| F1/F2/F3 free money cheats, F5 fly mode | Removed entirely from player.gd |
| Loot key typo "move_speed" vs "movement_speed" | Fixed in muddy_hollow.gd and mariana_trench.gd |
| Tool tooltip showing 1.30x growth (actual 1.15x) | Fixed in shop_panel.gd |
| Lucky Charm tooltip showing 1.35x/80% cap (actual 1.20x/60%) | Fixed in shop_panel.gd |
| Auto-Scooper tooltip showing 0.88/0.1s (actual 0.92/0.5s) | Fixed in shop_panel.gd |
| Lantern tooltip showing old scaling formula | Fixed — shows fixed values now |
| format_money only handled up to $M | Now handles K, M, B, T, Qa, Qi |
| Loot rewards bypassed max_level caps | Added clamping in loot_node.gd |

### Still Present
| Bug | Severity | Location |
|-----|----------|----------|
| Cave drain_threshold = 0.0 (requires 100% drain, not 50%) | HIGH | game_manager.gd CAVE_DEFINITIONS |
| Splash Guard tooltip uses old `pow(0.82, level+1)` formula | MEDIUM | shop_panel.gd:608-609 |
| cycle_progress not saved (time of day resets on load) | MEDIUM | save_manager.gd / game_manager.gd |
| Elephant backend code is all dead/unreachable | LOW | game_manager.gd lines 225-265, 670-690, 847-915 |
| water_body.gd is unused dead code | LOW | scripts/water/water_body.gd |
| No save data validation on load (negative money, etc.) | LOW | game_manager.gd load_save_data() |
| Save file is unencrypted plain JSON | LOW | save_manager.gd |

---

## 4. Economy & Balance Analysis

### Pool Progression Estimates
| Pool | Gallons | $/gal | Approx Tool Tier | Est. Time to Drain |
|------|---------|-------|-------------------|-------------------|
| Puddle | 5 | $25 | Hands | ~5 min |
| Pond | 50 | $50 | Spoon | ~15 min |
| Marsh | 500 | $100 | Cup | ~25 min |
| Bog | 5,000 | $250 | Bucket | ~45 min |
| Swamp | 50,000 | $500 | Shovel | ~2 hr |
| Lake | 500,000 | $1,000 | Wheelbarrow | ~6 hr |
| Reservoir | 5,000,000 | $2,000 | Barrel | ~15 hr |
| Lagoon | 50,000,000 | $4,000 | Water Wagon | ~40+ hr |
| Bayou | 500,000,000 | $8,000 | Upgrades only | ~100+ hr |
| The Atlantic | 10,000,000,000 | $15,000 | Upgrades only | ~500+ hr |

These assume continuous scooping at base tool output. Scoop Power and Drain Mastery improve these significantly, but the 10x gallon jumps with only ~2x $/gal increases create dramatic slowdowns in late game.

### Dead Periods
- **Early game (Puddle → Bog)**: Pacing is good. Clear goals, regular purchases.
- **Mid game (Swamp → Lake)**: First dead period. Walking distance becomes the bottleneck. Player spends more time walking than scooping.
- **Late game (Reservoir+)**: Severe. No meaningful idle income. Millions of gallons by hand. This is where players quit.

### Upgrade Meaningfulness
| Upgrade | Useful? | Notes |
|---------|---------|-------|
| Rain Collector | Early only | $0.50/s base becomes irrelevant by pool 4 |
| Splash Guard | Always | Stamina reduction stays relevant throughout |
| Auto-Seller | Yes (once) | Eliminates sell trips — huge QoL |
| Lucky Charm | Moderate | 2x money is nice but RNG-dependent |
| Auto-Scooper | Yes | Core QoL, pairs with Splash Guard |
| Lantern | Yes (once) | Needed for caves, capped at level 1 |

### Missing Upgrade Paths
- No clear investment guidance for new players
- Water Value is the most powerful multiplier but buried in "Power Stats"
- Movement Speed cap of 5 feels artificially limiting in a 5,500px world
- No upgrade that addresses the walking problem
- No idle income upgrade that scales into late game

---

## 5. Cave System Analysis

### Cave Loot Inventory
| Cave | Key Rewards |
|------|-------------|
| Muddy Hollow | Lantern+3, free Spoon, $200 + MoveSpeed+2 |
| Gator Den | Free Bucket, Lantern+2, $1.5K + ScoopPower+3 |
| The Sinkhole | $8K, ScoopPower+4, $10K from pools |
| Collapsed Mine | $40K, free Wheelbarrow, $100K from pools |
| The Mire | $200K, DrainMastery+5, $1M from pools |
| Sunken Grotto | $2M, CarryCap+8, $1M from pools |
| The Cistern | $10M, free WaterWagon, $25M+ from pools |
| Coral Cavern | $50M, WaterValue+12, $60M from pools |
| The Underdark | $250M, DrainMastery+15, $100M from pools |
| Mariana Trench | $1B, ALL stats+10, $500M+ from pools |

### Cave Issues
- drain_threshold = 0.0 means 100% drain required (should be 50%)
- No sell point inside caves — player must exit, walk to shop, sell, walk back, re-enter
- Late-game cave pools (millions of gallons) require hundreds of exit-sell-reenter cycles
- Lantern rewards (Lantern+3, +2) are wasted since lantern is capped at level 1
- Movement speed +2 from Muddy Hollow could push past max_level 5 (now clamped)

---

## 6. Design Doc Gap Analysis

### From game-design-doc.md (~30% Implemented)
| Feature | Status |
|---------|--------|
| 9 of 18 planned tools | Implemented |
| Boss fights (3 political bosses at 33/66/100%) | NOT implemented |
| Wild card tools (Aquifer Drill, Tsunami Machine, The Final Drain) | NOT implemented |
| World events (rainstorms refilling pools, drain tax) | NOT implemented |
| Prestige / New Game+ | NOT implemented |
| Endgame sequence / credits | NOT implemented |
| Narrative payoff (lizard people reveal) | NOT implemented |
| Diving gear, TNT, keycards (cave gating) | NOT implemented |

### From graphical-overhaul.md (~85% Implemented)
| Feature | Status |
|---------|--------|
| Parallax backgrounds | NOT implemented |
| Per-tool scoop particles | NOT implemented |
| Water drip trail behind player | NOT implemented |
| Footprints in mud | NOT implemented |
| Player idle animations | NOT implemented |
| Tool equip animation | NOT implemented |
| Dithered terrain transitions | NOT implemented |
| Biome tinting per pool area | NOT implemented |

### From caves-v2.md (Partially Done)
| Feature | Status |
|---------|--------|
| 10 caves | Implemented (expanded from v2's 5) |
| The Base (endgame government facility) | NOT implemented |
| Cave entrance visual progression (crack before opening) | NOT implemented |

---

## 7. Roadmap — Prioritized Tiers

### Tier 1: Fix What's Broken
Quick fixes, mostly one-liners. Should be done immediately.

1. **Set cave drain_threshold to 0.5** for all 10 caves in CAVE_DEFINITIONS
2. **Fix Splash Guard tooltip** to use actual formula: `1.0 - 0.75 * (1.0 - exp(-0.25 * (level+1)))`
3. **Save cycle_progress** in save/load (add to get_save_data and load_save_data)
4. **Remove dead elephant code** from game_manager.gd (constants, state vars, computed properties, actions, save/load references)
5. **Delete water_body.gd** (unused)

### Tier 2: Kill the Walking Problem
The single biggest quality-of-life improvement possible.

6. **Teleport stones** — Purchasable fast-travel points placed near pool clusters. Buy a stone at the shop ($X), it gets placed at the current pool. Click/interact to warp between unlocked stones. 3-4 stones across the world would eliminate 80% of walking.
7. **Mobile sell cart** — A sell point that appears near whatever pool the player is currently draining. Could be an upgrade purchase ($10K?) or automatic after draining your first pool. Eliminates the shop-return trip entirely.
8. **Raise movement speed cap** from 5 to 10, or add a separate "Sprint" upgrade in the Upgrades tab that gives a short burst of 2-3x speed on cooldown.

### Tier 3: Add Idle Income
Addresses the late-game grind wall. Without this, the game effectively ends at Reservoir.

9. **Pumps** — Purchasable per-pool. Visible in the world (small animated sprite on the shore). Slowly drains the pool in the background. Output: `0.001 * pow(1.15, level)` fraction per second. Upgrade cost scales with pool tier. This is the core idle mechanic the game needs.
10. **More camels** — Raise the camel cap from 1 to 3-5. Each camel auto-carries water to the shop independently. Creates a visible caravan that gets busier as you progress.
11. **Scale Rain Collector** — Instead of flat $/s, make it percentage-based: earns a fraction of the most valuable pool's $/gal rate. Something like `base_fraction * pool_money_per_gal * level_multiplier`. This keeps it relevant throughout the game.

### Tier 4: Make Progress Visible
Addresses the "invisible progression" problem.

12. **Pool progress bars** — Small colored bars floating above each pool in the world showing drain %. Or a HUD element that shows the current pool's progress when nearby.
13. **Cave unlock notifications** — When a pool hits 50% drained, show a floating text notification: "Cave found: [Name]!" with a screen shake. The `cave_unlocked` signal already exists — just connect it to a visible popup.
14. **World minimap** — Small corner minimap showing player position, pool locations (colored by drain progress), cave entrances, and shop location. Essential for a 5,500px world.
15. **Drain milestones** — At 25%, 50%, 75%, 100% drain on each pool, trigger a celebration: particle burst, floating text, brief screen effect. Give the player regular dopamine hits during long grinds.

### Tier 5: Endgame & Content
Gives the game a real conclusion and replayability.

16. **The Base** — Endgame government facility cave. Unlocks after draining The Atlantic (or at 50% drain). Contains the narrative payoff: evidence of the government flooding program, the lizard people conspiracy, the "source" of all the water. Final loot: massive stat bonuses or a prestige unlock.
17. **Endgame credits sequence** — When The Atlantic is 100% drained, trigger a special sequence: the water recedes to reveal... something. A cutscene or text crawl summarizing the conspiracy. Roll credits. The player "won."
18. **New Game+** — After credits, offer to restart with a permanent bonus (2x base scoop, or keep one stat, or start with a tool). Gives hardcore players a reason to replay with the knowledge and optimization skills they've built.
19. **Boss encounters** — From the design doc: 3 political bosses at 33/66/100% total drain. Could be simple minigames (dodge projectiles while scooping, outpace a water refill, etc.) or narrative encounters with choices.

### Tier 6: Visual Polish
Nice-to-have improvements that enhance feel.

20. **Per-tool scoop particles** — Hands: tiny splash. Cup: small splash. Bucket: medium splash + drips. Barrel: big splash + spray. Water Wagon: massive splash + screen shake. Makes each tool feel distinct and powerful.
21. **Parallax background** — Treeline silhouette, distant hills, cloud layer behind the terrain. Adds tremendous depth to the flat world.
22. **Player idle animations** — Breathing motion, occasional look-around, tool fidget when standing still. Makes the player character feel alive.
23. **Footprints & water trail** — Footprints in mud near water edges, water drips behind player when carrying water. Environmental immersion.
24. **Purchase confirmation** — "Buy [item] for $X?" dialog for purchases over $1K. Prevents accidental expensive purchases.
25. **Cave sell point** — A small puddle or basin near cave entrances where the player can sell water without exiting. Eliminates the tedious exit-sell-reenter cycle for cave pools.

---

## 8. Quick Wins (< 30 min each)

These are small changes with outsized impact:

1. Cave drain_threshold 0.0 → 0.5 (10 lines)
2. Save cycle_progress (2 lines in save, 2 in load)
3. Splash Guard tooltip fix (2 lines)
4. Cave unlock floating text (already have signal, just connect to HUD)
5. Pool drain % in HUD when near a pool (few lines in hud.gd)
6. Delete dead code (water_body.gd, elephant code)
7. Raise movement speed cap from 5 to 8-10

---

## 9. What Would Make This Game Great

The foundation is already excellent. The visual world is genuinely impressive — the creature density, day/night responsiveness, and shader work rival polished indie games. The cave lore creates genuine narrative intrigue. The economy rebalance is well-researched and properly implemented.

What's missing is the **mid-to-late game loop**. The early game has a tight scoop → sell → buy cycle with regular power spikes. But after pool 5-6, the game becomes a walking simulator punctuated by scooping. The three fixes that would transform this from "impressive tech demo" to "actually fun game" are:

1. **Fast travel** (kills walking tedium)
2. **Pumps or idle workers** (creates passive progress, lets player log off and come back to gains)
3. **Visible milestones** (gives the player constant feedback that they're making progress)

With those three systems, the game would have a complete and satisfying loop from Puddle to Atlantic.
