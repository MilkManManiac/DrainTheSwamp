# Draining the Swamp — 2D → Steam/App Roadmap

**Decision (2026-06-03):** Ship the **2D version** (the fully-built game on `master`, `scripts/game_world.gd`) as the product. **Release target: Steam + app stores.** Web export becomes a *demo* channel, not the primary constraint — so the `v2-3d-overhaul` branch and its forward_plus/web-export tension are **shelved**. This removes the "web vs. desktop renderer" fork entirely.

This roadmap synthesizes a 5-agent deep review (mechanics/feel, economy/scaling, visuals, story/satire, tools). Items are tagged **P0** (blocks "feels finished"), **P1** (high impact, moderate effort), **P2** (ambitious / "made by AI" tier). Each item cites the real file:line where relevant.

> **Why Steam/app instead of web changes things:** no WASM payload budget, no SharedArrayBuffer/COOP-COEP headaches, heavier audio/music is fine, and we can assume gamepad + (mobile) touch. But it raises the polish bar — Steam players expect audio, settings, save safety, and a non-janky first 5 minutes. Keep a web demo build for r/incremental_games reach (instant-play is the genre's lifeblood).

---

## The headline problems (what this roadmap fixes)

1. **Zero audio in the entire game.** No `AudioStreamPlayer`, no audio files. Single biggest quality gap.
2. **Economy is a staircase with a ~100× endgame wall** — 99.5% of all gallons live in the last 2 pools, while throughput is hard-capped at 150×.
3. **Walk-heavy fetch loop** — scoop → walk to far-left shop → sell → walk back. Sell-trip tax grows with pool distance.
4. **Caves give $0** — `loot_data` is empty everywhere despite full reward plumbing in `loot_node.gd`.
5. **Best jokes are the most skippable** (cave-gated); plot is delivered via flow-freezing modals; no ambient channel for the long grind.
6. **Design-doc pillars missing** — no bosses, no idle income, no dive/keycard caves.
7. **Dev cheats (F4/F5) ship in builds** and a latent crash bug in stat scaling.

---

## P0 — Blocks "feels finished" (do these first)

### P0.1 — Audio system (biggest single quality jump)
- Add an `AudioManager` autoload + buses (Master / SFX / Music / Ambient) with volume settings.
- **Minimum viable set:** randomized-pitch scoop *splosh* (per-tool variation), sell *cha-ching*, tool-equip click, pool-complete fanfare, UI clicks, ambient swamp loop (day + night variants), rain/thunder tied to existing weather (`game_world.gd:4556`).
- Source plan: CC0 ambience bed from OpenGameArt/Freesound + targeted SFX from ElevenLabs (paid, commercial-safe). Adaptive music via Godot's built-in `AudioStreamInteractive` (NOT Godot-Mixing-Desk — that's 3.x only).
- Hook points already exist: scoop signal in `player.gd`, sell in `game_world.gd:4540/5215`, pool-complete celebration `game_world.gd:4234`.

### P0.2 — Fix the early-game grind (first 5 minutes = highest bounce risk)
- Start stamina 5 with flat 2/scoop = ~2 scoops then a multi-second wait. Goal: **first meaningful upgrade within ~30s**, "just one more scoop" cadence under ~1s between scoops.
- Raise starting stamina or lower early scoop cost; make the first 2–3 tools cheaper; bump early carry capacity so the first sell-walk pays off.

### P0.3 — Remove dev cheats from release builds
- `player.gd:70-82` — F4 (+$100k) and F5 (noclip fly). Gate behind a debug flag or strip for release.

### P0.4 — Fix latent crash + scoop honesty bugs
- `game_manager.gd:390,401` — `get_stat_value`/`get_stat_value_at_level` read `defn["per_level"]` which **no stat defines**; the `else` branch is a live landmine. Guard with `.get("per_level", 0.0)` or remove.
- `player.gd:348` — scoop "+gal" popup is computed from tool output *before* knowing actual drained amount, so it lies near pool-empty/bag-full. Return the real float from `try_scoop()` and display that.

### P0.5 — Settings + save safety (Steam baseline)
- Volume sliders, fullscreen/windowed, key rebinding stub, and a confirmable "delete save."
- Save system is already robust/versioned (`game_manager.gd:969-1090`) — keep it; just expose UI and confirm migration covers any new fields added below.

---

## P1 — High impact, moderate effort

### P1.1 — Economy rebalance (kill the staircase + endgame wall)
Real numbers extracted from `game_manager.gd`. Apply these:

| Lever | Current | Proposed | Where |
|---|---|---|---|
| Tool output / level | `1.15^lvl` | `1.20^lvl` | `get_tool_output` L372 |
| Tool upgrade cost / level | `1.30^lvl` | `1.18^lvl` | `get_tool_upgrade_cost` L421 |
| Swamp volume / tier | ×10 | ×6 | `swamp_definitions` L26 |
| money_per_gallon | irregular ×2 | `25 × 1.6^i` | L26-37 |
| scoop_power cap | 10× | 50× (or uncap, `1.10^lvl`) | `stat_definitions` L108 |
| water_value cap | 15× | 100× | L108 |
| stamina cost | flat 2 | `2 × tool_order` (or √output) | `get_stamina_cost` L409 |

- **Fix the tool-upgrade trap:** output `1.15` vs cost `1.30` makes every "Up" a worsening deal. Match them (`1.20` output / `1.18` cost).
- **Crush the endgame wall:** last 2 pools hold 99.5% of gallons vs 150× throughput cap. Lower late volumes (×6/tier) AND lift the caps so power keeps growing.
- **Carry-capacity floor** to kill "single-scoop trip" grind: `effective_capacity = max(carry_stat, tool_output × 4)`.
- Delete/rewrite `docs/plans/economy-rebalance-v4.md` — it's stale (references removed stats).
- **Lock these with GdUnit4 tests** (cost curves, tier unlocks, save round-trip) — incremental balance bugs are silent.

### P1.2 — Monetize the caves
- Every `loot_data: {}` is empty (e.g. `muddy_hollow.gd:52`, `mariana_trench.gd:69`). `loot_node.gd` already supports `reward_money` / `reward_stat_levels` / `reward_tool_unlock`.
- Populate with `reward_money ≈ 0.5–1× parent swamp value` + occasional stat/tool rewards. Gives caves a reason to exist and smooths each new pool's grind.

### P1.3 — Cut the sell-trip tax
- Pick one: (a) sell-from-anywhere satchel radius, (b) cheaper/earlier camel or allow >1 (currently capped at 1, gated behind Gator Den), or (c) a sell point per region.

### P1.4 — Juice the SELL moment (current dopamine peak is muffled)
- Selling is a passive Area2D side-effect. Add: coin-burst → counter, big *cha-ching*, bag-empty squash, screen flash scaled to amount. **Unify the two sell paths** (`game_world.gd:4546` body_entered vs `:5215` continuous) so VFX always fire.

### P1.5 — Ambient news-ticker channel (story pacing fix)
- Add a non-interrupting ticker/radio line at HUD bottom that cycles drain-%-tied satire *during* the grind. Fills the dead Act 3–4 stretches (Bayou/Atlantic are 30+ min with one newspaper).
- Surfaces the best jokes (Consultant, wiretaps) that are currently cave-gated and skippable.

### P1.6 — Movement + carry feel
- Add accel/friction to `player.gd:104` (currently instant velocity) for weight + a landing squash.
- Visible carry bag/bucket on the character that fills up — makes capacity upgrades tangible.

### P1.7 — Stagger cave unlocks by drain threshold
- All caves currently unlock at `drain_threshold: 0.0` (`game_manager.gd:254`) — i.e. instantly. Restore the design-doc 90%/75%/50% staggering for the "water drops → secret revealed" payoff.

---

## P2 — Ambitious / "made by AI" tier

### P2.1 — Reactive, living world
- Wire up the fish that already have unused `alive`/`death_timer` fields (`game_world.gd:2252`) to flop as pools empty.
- Frogs flee, birds scatter on big splashes, fireflies swarm the lantern at night, mud cracks spread as a pool dries. ~40 ambient systems already exist — make 3–4 *react to the player*. This reactivity is what reads as "wow."

### P2.2 — The world visibly heals as you drain it
- Drive ambient color/lighting from total-drain fraction: murky green/desaturated → clear/warm. On-theme for the satire (you're "cleaning up the swamp"), pure code, huge perceived effort.

### P2.3 — A satisfying water surface
- 2D water shader: refraction + foam at the waterline + subtle caustics on exposed mud. Water is literally the game's subject; current rendering is the weakest hero surface. Reference godotshaders.com (CC0/MIT).

### P2.4 — At least one boss minigame
- "The Filibuster" is nearly free: the sabotage re-flood already exists (`game_world.gd:4242`) — turn it into a timed out-pump duel gated at the midpoint. Restores a missing design pillar and a memorable spike.

### P2.5 — Idle income (closes the "idle game" expectation gap)
- The doc promises an idle tier; there's none (hose is a 20s manual timer, auto-scooper needs standing still). Add one real idle pump that drains slowly while away. Steam/app players expect AFK progress.

### P2.6 — Story depth
- Tier the newspaper *voice* (press-release PR-speak vs frantic wiretap vs clipped memo), not just paper texture.
- Decide the weirdness turn: commit to a genre-shift (the cryptid/lizard reveal the brief promised but the code never delivers) around Reservoir/Lagoon, or cut the promise. The escalation currently only ever means "more money was stolen" — it needs a category jump to surprise.
- Reactive headlines: "He did it with a BUCKET" is hardcoded even if you used a pump — cheap reactivity win wasted.
- Move 1–2 Consultant beats out of caves into the unskippable newspaper channel.

### P2.7 — Refactor the 6,480-line monolith (tech debt)
- `game_world.gd` does parallax, terrain, ~40 particle systems, weather, shop, caves, camels, endgame, day/night. Per-pixel dither/strata loops spawn hundreds of nodes. Profile node count and decompose before adding much more — and before mobile/app perf matters.

---

## Tooling to adopt

| Tool | Why | License |
|---|---|---|
| **GodotBigNumberClass** | Table-stakes formatting for the 18-tier economy; floats will lose precision | MIT |
| **Dialogue Manager 4** | Standard for lore/boss/ending text | MIT |
| **ElevenLabs SFX** | Full cohesive sound set fast | Paid, commercial-safe |
| **CC0 ambience** (OpenGameArt/Freesound) | Layered swamp bed | CC0 |
| **AudioStreamInteractive** (built-in) | Adaptive music | Native |
| **Material Maker** | Procedural textures, zero AI-copyright risk | Free/OSS |
| **GdUnit4 + PlayGodot** (via `godot` skill) | Lock economy math + core-loop smoke tests | — |

Existing Claude Code skills to lean on: `godot` (build/test/export/deploy), `algorithmic-art` (escalating cave carvings/glyphs), `canvas-design` (faux-redacted government documents), `verify`, `code-review`.

**AI-asset caveat:** you can *ship* AI-generated assets, but US copyright likely won't protect them — keep prompt/seed logs, avoid living-artist-style and real-politician-voice prompts.

---

## Suggested execution order

1. **Sprint 1 (P0):** Audio system → early-grind fix → strip cheats → fix crash/scoop bugs → settings menu. *Outcome: the game stops feeling unfinished.*
2. **Sprint 2 (P1):** Economy rebalance + GdUnit4 tests → monetize caves → sell juice → sell-trip fix. *Outcome: the 30-hour middle/endgame becomes paced.*
3. **Sprint 3 (P1/P2):** News ticker + story pacing → reactive world + drain-heals-world → water shader. *Outcome: the "wow" layer.*
4. **Sprint 4 (P2):** Boss minigame + idle income → monolith refactor → Steam page/app packaging. *Outcome: shippable.*

Each sprint ends with a `verify` pass and a deployable build.
