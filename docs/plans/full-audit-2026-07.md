# Full Project Audit & Improvement Plan — 2026-07-06

> **Progress log**
> - 2026-07-06: Phase 0 complete (commit `fe34eb9`) — saves hardened, dev button gated,
>   hold-to-scoop, stamina wall, Windows preset (first desktop export verified), CI bump.
> - 2026-07-07: Phase 1 items 1–6 complete (commits `e668f28`…) — murk grade rebalanced,
>   sky/night lifted, sky artifacts killed (framing fronds, band edges), camera framing raised,
>   soil strata, cave exposure + entry framing (root cause: cave camera never `make_current()`),
>   town day/night light gating + wall repaint + billboard fit, UI theme + Silkscreen pixel font.
>   NOTE: all captures before 2026-07-07 are gamma-dark (linear-vs-sRGB hook bug, now fixed) —
>   brightness in the appendix screenshots overstates the problem. Item 7 (ArtGen pilot) pending —
>   needs ComfyUI running + user taste picks on generated candidates.
> - 2026-07-07: Phase 2 items 1-8, 10 complete (commits `cd25b6b`..`a1074d3`) — curve fix
>   (1.15/1.28 + x2 milestones, invariant tests in tests/economy_invariants.gd), pumps +
>   offline progress (save v19), prestige numbers rework (250K scale, multiplicative,
>   War Chest tools), cave air meter + Daring Bonus + drain thresholds restored, camel/hose
>   un-trapped, east tower sell point + Overflow Valve, HUD rates + influence progress,
>   contextual onboarding hints. REMAINING in Phase 2: item 9 (music/ambient — needs a
>   listening session, not automatable headless) and the fuller prestige mechanic-unlock
>   ladder (P1 pump discount shipped; P2-P4 pending design with story tie-in).
> - 2026-07-09: Phase 3 (story) complete in one pass — (a) walk-to-the-island ending:
>   pool-9 completion now shows "IT'S GONE" and RELEASES the player; the climax fires at
>   the island (`jeff_area`, formerly dead code) with a binary choice ("Hand over the List /
>   Swing") branching NA-road vs CIA-road ending newspapers (3 new NA papers written);
>   (b) burner phone: 12 one-shot NA texts (queued dark-styled `show_document_popup`
>   variant; triggers: first sell, pools 1/3/5/7/8/9, first lore read, first prestige)
>   gated by persisted `story_flags` (save v20); (c) NA in prestige: SELL OUT confirm line,
>   NA tooltip notes on all 4 upgrades, dead-drop mailbox interactable (scripts/world/
>   dead_drop.gd, arc-aware: teaser → field box → dispensary); (d) surfaces: ticker
>   re-enabled throttled (1 fading headline/45s + prestige pool), milestone popups get
>   rotating quips (also fixed literal "%%" bug), Guest List rewritten deadpan,
>   prestige-aware Puddle paper; (e) story-rework.md reconciled (Goodwell kept-but-demoted,
>   NA naming canonical). Verified: headless boot + trench scene clean, economy invariants
>   ALL PASS. NOT yet play-verified: island choice UI, phone popup pacing.
> - 2026-07-09 (cont.): Phase 4 items 1 & 4(partial) + Phase 2 prestige-ladder leftover —
>   (a) shop panel in-place refresh: money ticks update affordability/labels via
>   registered updaters; full rebuilds only on structural signals (fixes tooltips dying
>   every 0.3s); (b) "The Arrangement" perk ladder: P2 camel caravan (herd cap x3),
>   P3 NA courier basin in caves (auto-sell near entrance) + auto-read lore walls,
>   P4 periodic 2x buyback windows (45s every ~5min, announced) — each with an NA text
>   and a ladder display in the Influence tab; invariant tests extended; (c) town
>   extracted to scripts/world/town.gd (~510 lines out of the god-file), glow arrays move
>   with it, DTS_SHOT A/B diff confirmed within same-build animation noise floor;
>   (d) six dead plan docs marked SUPERSEDED. Still open in Phase 4: shared VisualFX
>   helper, remaining god-file modules, touch-input verification, controller support,
>   web perf pass.
>
> **NEXT SESSION — start here**
> 1. **Playtest feedback first.** Phase 2 shipped unplayed (curves, pumps, air meter,
>    Overflow Valve, east tower). Get the user's read on: hold-to-scoop feel, stamina,
>    murk-grade brightness in real play, pump pacing/cost, cave air timing (90s+30s),
>    Daring Bonus clarity. Tune numbers from specific moments, not vibes.
>    Also do one windowed sanity pass: pump prop renders at a pool rim, air bar shows in
>    caves, tower spawns after Bog (all verified headless only so far).
> 2. **Music/ambient** (Phase 2 item 9, the last CRITICAL silence). Music bus exists
>    (audio_manager.gd:78). Decide procedural vs licensed loops WITH the user listening.
>    Minimum: overworld day / night / cave ambient beds + one melodic loop.
> 3. **Phase 3 (story week)** — all prerequisites in place:
>    a. Walk-to-the-island ending: stop `_trigger_endgame()` firing on pool-9 completion;
>       release the player onto the seabed; trigger at the existing `jeff_area`
>       (`player_near_jeff` game_world.gd — currently dead code); binary choice
>       ("Hand over the List / Swing") branching the final newspapers (CIA set exists,
>       write ~2 NA papers).
>    b. Minimum-viable NA phone: reuse `SceneManager.show_lore_popup` as
>       "MESSAGE RECEIVED — a Friend"; ~12 texts from story-rework.md on existing
>       triggers (first sell, pools 1/3/5/7, first prestige, first lore read).
>    c. Fuse NA into prestige fiction: SELL OUT confirm = NA text; one handler line per
>       prestige upgrade tooltip; make the town dropbox interactable (lore_wall Area2D
>       pattern) — teaser pre-reveal, NA dispensary post-prestige.
>    d. Feed high-frequency surfaces: ticker mix 2 generic/4 stage (news_ticker.gd:93),
>       milestone-popup one-liners, Guest List rewrite (mariana_trench.gd:104),
>       prestige-aware newspaper variant. Re-enable the ticker throttled (hud.gd:201).
>    e. Update story-rework.md: Goodwell kept-but-demoted; agency name is
>       Northwind Analytics everywhere.
> 4. **Phase 4 quick wins when touching those files anyway**: town.gd extraction +
>    shared VisualFX helper (2-4h, pixel-diff with DTS_SHOT); verify touch input
>    (`emulate_mouse_from_touch=false` likely breaks all Control taps,
>    touch_controls.gd:176); shop in-place refresh instead of 0.3s rebuild.
> 5. **Deferred**: ArtGen hero-prop pilot (needs ComfyUI + user seed picks); controller
>    support; achievements/stats screen; god-file split; web perf pass; merge to master +
>    web deploy when the user calls the build good.

Produced from five parallel audit tracks on branch `v2-2d-polish` (37 commits ahead of master):
four specialist code audits (gameplay/economy, story/writing, UX/UI, architecture) plus a
screenshot-based visual audit using fresh `DTS_SHOT` captures of the town (day/night), pool
areas (murky/drained/dusk), five caves, and boot. Captures in `_screenshots/audit-2026-07/`.

---

## Executive verdict

The game is **a good skeleton wearing a bad presentation**. The physical scoop→carry→sell
loop, the signal-driven architecture, the juice layer (per-tool splashes, coin-fly, milestone
particles), and the newspaper/cave-document comedy writing are all genuinely above par. What's
broken is everything a player actually experiences in the first hour:

1. **It looks like night all the time.** The murk color-grade (undrained state) crushes
   daytime to near-darkness. This — not the assets — is the single biggest reason it "looks shit."
2. **The economy contains zero decisions.** Tool output growth and cost growth are both 1.20,
   so payback time is constant forever; you just press Up.
3. **Caves are black screens with no mechanics.** ~90% of pixels are near-black, half the
   screen is unpainted void at spawn, and the loop is walk-right-press-SPACE with no risk.
4. **The story spec is ~5% implemented** and the ending skips the game's built-and-waiting
   climax (the island with 7 politician figures) in favor of a newspaper dump.
5. **The UI is prototype-grade**: no Theme, no font, no music, a dev "Test Endgame" button on
   the title screen, a 5-scoop stamina wall in minute one.

None of these require new engine tech or an art-style pivot to fix. Estimated total to a
demo-worthy build: **4–6 focused weeks** following the phases below.

---

## Part 1 — Findings by area

### 1.1 Visuals (screenshot-judged against the ArtGen rubric)

**The murk grade is the top ROI fix.** A/B captures at identical time-of-day
(`DTS_TOD=0.4`, i.e. full day) with `DTS_DRAIN=0` vs `1` prove it: undrained day renders as
deep-navy near-night; drained is a pleasant bright day. Contributors stack multiplicatively:

- Post-process saturation lerps to **0.62** when undrained (`game_world.gd:6566`) and warmth to −0.028.
- Sky lerps 28% toward sickly grey-green `HEAL_SKY_MURKY` (`game_world.gd:6657`), on top of an
  already-dark `SKY_DAY[0] = (0.22, 0.38, 0.72)` (`game_world.gd:712`).
- Murky fog at 2× drained density (`game_world.gd:6617,6622`) over the horizon.
- `GROUND_COLOR` dark brown only lerps to warm `(0.54, 0.42, 0.22)` as you drain (`game_world.gd:6627`)
  — and dirt fills most of the frame (next point).

Since the player is undrained ~the whole game, the shipped look IS the murk look. **Rule for the
fix: murk should shift hue and saturation, never luminance.** A midday murky swamp should read as
hazy, sickly, olive — not dark. Keep the drained "golden" endpoint; raise the murky endpoint's value floor.

**Composition wastes 50–70% of every frame on featureless dirt.** The terrain cross-section
below the ground line is a single flat brown noise fill occupying most of the screen at default
zoom; the actual game (town, pools, sky) lives in a strip across the top. Fix with some mix of:
camera vertical offset / tighter default zoom so the playfield centers; and/or make the
underground earn its screen space — strata bands, roots, rocks, buried junk (satire props:
drums labeled "DEFINITELY NOT TOXIC", filing cabinets), and a visible water-table line that
drops as pools drain (mechanical storytelling for free).

**Town: the problem is art, not scene structure.** Buildings are small flat dark boxes with
floating default-font labels ("PAWN", "DINER"); the satirical billboards — signature props —
are flat white rectangles whose default-font text overflows the sign shape
(`VOTE SWAMPSWORTH` board clips "SWAMPSWORTH"). The string lights and lit windows are the one
charming element and prove the lighting pipeline works. The town needs: real storefront
silhouettes (porches, awnings, signage planks with fitted text), vertex-color painterly shading
(already the codebase's cheapest win per `docs/godot-dev-notes.md`), foreground props, and NPC
silhouettes. See Part 2 for the scene-split question.

**Caves fail on exposure and framing, not content.** All five captured caves are ~90% pixels
below ~10% luminance; the per-cave signature set-pieces and textured rock shader (which IS
there, faintly visible) are invisible. Two concrete bugs:
- **Spawn void**: player spawns 24px from the cave's left edge (`cave_base.gd:1913`) and the
  camera limit extends only 20px past it (`cave_base.gd:1931`) — yet nearly half the viewport
  at spawn shows unpainted black. Spawn the player deeper in and/or paint the entry wall.
- **Exposure**: ambient `CanvasModulate(0.54, 0.56, 0.63)` (`cave_base.gd:67`) over dark rock
  albedo with too-few fill lights crushes everything. Caves need a readable value structure:
  lit pockets (crystals/pools/set-pieces) at 3–5× current brightness with real falloff, plus a
  raised ambient floor so rock texture reads. Judge each cave to "biome identifiable in a
  2-second glance" — currently coral/gator/underdark are indistinguishable silhouettes.

**Night is unplayable** — near-black except string lights. Raise the night ambient floor
(`_get_cycle_color` night `(0.28, 0.32, 0.58)` is fine, but stacked grades crush it) and give
night a job (fireflies, lit windows, lantern gameplay) or shorten it.

**Sky artifacts**: large dark swoosh shapes and a translucent grey trapezoid band sit in the
sky near the sun in multiple captures (visible top-right in town/boot shots); a lens-like white
ellipse hovers below the sun. Find and fix (likely far-hills / cloud polygons with wrong color
or z-order).

**Strategic option — the procedural ceiling.** Even with everything above fixed, flat-color
Polygon2D primitives cap out on the rubric's "surface detail" dimension. The ArtGen pipeline
(pixel-art assets generated via ComfyUI, finished with the existing shader/lighting stack —
Eastward/Sea-of-Stars blend) is built and waiting. Recommended: fix grading/composition first
(Phase 1), then pilot ArtGen on the three highest-visibility hero props — town storefronts,
billboards, cave set-pieces — and A/B against procedural before committing broadly.

### 1.2 Gameplay & economy

- **Flat treadmill (CRITICAL)**: output `pow(1.20, level)` (`game_manager.gd:396`) vs cost
  `pow(1.20, level)` (`game_manager.gd:467`) → payback constant forever, no walls, no decisions.
  At endgame it inverts: upgrade payback ≈ 0.0002s; "play" is pressing Up 37 times.
  `economy-rebalance-v4.md` predicted exactly this and its fix was reverted.
- **No idle tier (CRITICAL for the genre)**: only upgrades are auto-scooper + lantern
  (`game_manager.gd:245-262`); no pumps, no offline progress (no timestamp in the save at all).
- **Prestige is dead math (HIGH)**: first payout is 1 Influence (`floor(sqrt(lifetime/1M))`,
  `game_manager.gd:912`), cheapest upgrade costs 2 (`game_manager.gd:924-927`). Bonuses are
  +8%/level additive in a ×10-per-tier game. Nothing new unlocks; optimal play is re-grinding
  the boring first 5 pools (sqrt is concave).
- **Caves: no mechanics (HIGH)**: all `drain_threshold: 0.0` (unlocked instantly,
  `game_manager.gd:274-285`); no air/hazard/failure state; loot is one keypress; Mariana Trench
  pays $90T (1.8× the final pool's own completion reward) for zero risk. GDD promised diving
  gear/TNT/lung capacity — none exist. No sell point in caves forces exit-shop-reenter loops.
- **Early-game keypress tax (HIGH)**: no hold-to-scoop (`is_action_just_pressed`,
  `player.gd:278`); Pond ≈ 1,250–2,500 presses; stamina (5 max) walls the primary verb in
  minute one; Auto-Scooper ($500) unaffordable until the grind is nearly over.
- **Dead systems (MED)**: stamina irrelevant after ~$60 of regen; carrying-capacity cost grows
  slower than its value (always-buy); power stats cap at ~end of Lake leaving one live purchase;
  camel (1 gal, cap 1, worsening cost curve) and hose (excluded from scoop_power, blocks manual)
  are strictly-worse traps that teach "automation is a scam."
- **One sell point** for a 5,500px world at speed cap ~211px/s → late-game verb is walking.
  Water tower is annotated "future auto-sell point" (`game_world.gd:5151`) — build it.

### 1.3 Story, writing, satire

- **Keep the writing** — it's specific, both-parties-guilty, observational. Best-in-repo: the
  bucket wiretap (`collapsed_mine.gd:82`), the Consultant's degrading quarterly reports, the
  bank's "please stop labeling transfers as 'swamp stuff'" (`the_cistern.gd:102`).
- **The rework spec (`story-rework.md`, Northwind Analytics) is ~5% implemented**: no phone, no
  NA strings anywhere, dead-drop is a decorative mailbox (`game_world.gd:5444`), one ending, no
  choice. NOTE: agency name is **Northwind Analytics** — "Directorate" (used in some session
  notes) appears nowhere in the repo.
- **The climax skips itself (CRITICAL)**: pool 9 completion freezes the player and scrolls 4
  newspapers (`game_world.gd:4390-4427`) — while the fully-built island, mansion, and 7
  politician figures (`_build_island_politicians`) sit unreached, and the `player_near_jeff`
  proximity flag (`game_world.gd:289,4327`) is dead code. The fix is nearly free.
- **The highest-frequency text surfaces have no author**: milestone popups are UI mush
  ("Bog — 50% drained!"), ticker is diluted 8-generic-to-3-stage per rebuild
  (`news_ticker.gd:93-108`), prestige "SELL OUT"/Kickback/Muscle/War Chest have zero fiction,
  the government's sabotage water-add-back happens as an unexplained screen shake
  (`game_world.gd:4909-4919`), and the Guest List — the final reveal — is the game's only
  humorless text (`mariana_trench.gd:104`).
- **Goodwell contradiction**: spec says drop him; implementation completed his (good!) 10-paper
  arc. Decision: **keep him as the News channel's subject, demote from protagonist-adjacent;
  NA takes the second-voice slot.** Update `story-rework.md` to match.
- **Prestige replays the story verbatim** — no seen-flags, no prestige-aware variants.

### 1.4 UX / UI / feel

- **Ship-blockers**: "Test Endgame" dev button on the title screen, not debug-gated
  (`title_screen.gd:226-228`); zero music/ambient audio (`audio_manager.gd:47-49,382-384`);
  touch mode sets `Input.emulate_mouse_from_touch = false` (`touch_controls.gd:176`) which
  likely makes every Control (shop buttons, menu, sliders) unresponsive to taps, and all
  upgrade info is hover-tooltip-only → invisible on touch.
- **Onboarding is one dismissable text popup** (`game_world.gd:629-635`) that lists ARROW KEYS
  (WASD is primary), omits mouse-scoop, and can be dismissed by the SPACE the player is mashing.
  No shop direction hint, no bag-full nudge, no first-affordable-upgrade nudge (cave entrances
  have a floating hint — reuse that system).
- **No Theme resource, no font anywhere** — styling is per-node overrides duplicated with
  different implementations across files (`shop_panel.gd:835` vs `menu_panel.gd:157`).
- **No rates anywhere** ($/s, gal/s), no gallon formatting (`+0.0004 gal` floats; no
  `format_gallons`), no next-Influence progress.
- **Bugs**: money label turns permanently green after first big earn (`hud.gd:84-90` vs gold in
  `hud.tscn`); shop rebuilds its whole tree every 0.3s while open (`shop_panel.gd:26-58`),
  killing hover/tooltips mid-interaction; news ticker — the funniest ambient system — is
  disabled (`hud.gd:201-202`).
- **No controller support** (zero joypad events in `project.godot`), no rebinding, no
  reduce-motion/shake toggle (grain + chromatic aberration always on).
- Keep: auto-scoop-after-3s-idle (quietly brilliant), tool-scaled juice, shop tooltips with
  next-level deltas, milestone celebrations, settings persistence.

### 1.5 Architecture & platform

- **`game_world.gd` is a 7,795-line god-file** (~170 functions; `_ready` calls ~60 builders;
  `_process` is 1,009 lines) building a **9,429-node** world (4,298 Polygon2D, 2,864 ColorRect,
  721 Line2D). Caves, by contrast, are the pattern to copy: 10 subclasses are ~90–170-line pure
  data configs over one 2,245-line template — no dedup needed there.
- **Save system will eat a player's run (CRITICAL for Steam)**: `save_manager.gd:22-28` writes
  the live file directly (no tmp+rename, no .bak); on corrupt load it silently starts fresh and
  the 30s autosave **overwrites the recoverable file**. Also: no future-version guard (Steam
  Cloud from a newer build → older build silently destroys new fields); web build loses up to
  30s on tab close (`WM_CLOSE` doesn't fire in browsers).
- **No Windows export preset exists** (`export_presets.cfg` has only Web) — the Forward+/HDR
  desktop path has never been exercised through an export. CI image still pinned to godot-ci 4.4
  vs local 4.6.3.
- **Web perf risk**: the 1,009-line `_process` iterates ~30 critter/FX collections per frame in
  GDScript with no camera-proximity gating; `hint_screen_texture` water ×10 pools + fullscreen
  post rect forces back-buffer copies on GL Compatibility.
- **FX plumbing duplicated** between game_world and cave_base (`_emit` HDR helper, debug-shot
  hook, radial light texture, ripples/drips) — divergence bugs waiting.

---

## Part 2 — The town question (direct answer)

**Should the town be a separate scene? No — and yes, later, additively.**

- The shop (sell point) is on the town shelf and selling is the highest-frequency action in the
  game; putting a scene transition on it taxes the core loop. Camel automation also paths to
  the shop in overworld coordinates.
- The town's actual coupling to game_world is tiny: build-once, zero `_process` entries, zero
  signal subscriptions, touches only `terrain_y_at(x)` + the `_emit` helper. **Extract it to
  `scripts/world/town.gd` (Node2D child) — ~2–4 hours, pixel-identical, verified by DTS_SHOT
  diff.** This removes ~600 lines from the god-file and is a prerequisite for anything else.
- The town *looks* terrible because of art (flat boxes, floating labels, primitive billboards),
  not because it shares a scene. Fix the art in-world (Phase 1).
- If we later want interiors (shop interior, city hall, NPC dialogue), add them as cave-style
  sub-scenes behind doors — additive, keeps the exterior strip and sell loop untouched.

---

## Part 3 — Phased improvement plan

### Phase 0 — Ship-blockers & one-liners (≈1 day)
| # | Fix | Where | Effort |
|---|-----|-------|--------|
| 0.1 | Gate "Test Endgame" behind `OS.is_debug_build()` | `title_screen.gd:226` | XS |
| 0.2 | Atomic saves: tmp+rename, rotating `.bak`, preserve corrupt file, future-version guard, save-on-key-events for web | `save_manager.gd`, `game_manager.gd:1190` | S |
| 0.3 | Add Windows export preset + first desktop export smoke test (HDR glow, fullscreen, save path) | `export_presets.cfg` | S |
| 0.4 | Hold-to-scoop (`is_action_pressed` + existing 0.3s cooldown) | `player.gd:278` | XS |
| 0.5 | Stamina: start max ~20 + faster regen (kill the minute-one wall) | `game_manager.gd:450-454` | XS |
| 0.6 | Fix money-label green bug | `hud.gd:89` | XS |
| 0.7 | Sabotage add-back popup + ticker line at the moment it fires | `game_world.gd:4917` | XS |
| 0.8 | Bump CI godot-ci image 4.4 → 4.6 | `.github/workflows/deploy-web.yml` | XS |

### Phase 1 — Make it look like a game (≈1 week, screenshot-driven per dev-notes loop)
1. **Murk grade rebalance** — murk changes hue/sat only, never luminance. Raise saturation
   floor 0.62→~0.85, cut sky murk-lerp 0.28→~0.12 but shift it olive, raise `GROUND_COLOR`
   value, thin the murk fog. Gate: A/B `DTS_DRAIN` captures at TOD 0.25/0.4/0.7/0.9 — midday
   murky must read as *day*. (M)
2. **Cave exposure + framing** — raise `CanvasModulate` floor, 3–5× light energy on set-pieces/
   crystals with falloff, spawn player deeper in / paint the entry wall, per-cave 2-second
   biome-identity gate judged from fresh captures. (M)
3. **Composition** — camera offset/zoom so dirt ≤ ~35% of frame; underground detail pass
   (strata, roots, buried satire props, dropping water-table line). (M)
4. **Town art pass (in-world)** — storefront silhouettes with porches/awnings, fitted sign text
   (sized font, plank backboards), vertex-color shading, 2–3 NPC silhouettes, foreground props.
   Fix billboard text overflow; rewrite billboard copy per story audit (the planned sharper
   lines were cut for softer ones). (L)
5. **Night floor + sky artifact hunt** (swooshes, trapezoid band, sun ellipse). (S)
6. **UI theme**: one `ui_theme.tres` + one pixel font project-wide; delete per-node override
   duplication. (S)
7. **ArtGen pilot (parallel/optional)**: generate hero-prop replacements for billboards,
   one storefront, one cave set-piece; A/B vs procedural before wider adoption. (M)

### Phase 2 — Make it play like a game (≈1–2 weeks)
1. **Curve fix**: output growth 1.15 / cost growth 1.28 + ×2 milestone every 10 tool levels;
   add GdUnit4 curve tests (payback must increase per level; first prestige can afford ≥1
   upgrade) so a retune can't silently flatten it again. (S)
2. **Pumps + offline progress**: per-pool pump (0.1× best tool output, visible sprite,
   10 levels), `last_saved_unix` in save, offline grant `rate × min(away, 8h) × 0.5`. The #1
   retention feature for Steam. (M)
3. **Prestige rework**: scale 1M→250K; upgrade costs {1,1,2,1}; kickback/muscle multiplicative
   ×1.25/level; **each prestige count unlocks a mechanic** (P1 pumps purchasable, P2 camel
   caravan ×3, P3 cave sell-basin + auto-lore, P4 timed 2× sell-window events). (M)
4. **Cave risk/reward**: 90s swamp-gas air meter (+30s per pool drained, +lantern), eject
   losing carried water at 0, ×1.5 "Daring Bonus" loot above 50% air; restore
   `drain_threshold: 0.5` so cave discovery is a reveal. (M)
5. **Sell-trip fix**: water-tower auto-sell point (already stubbed) after Bog + "Satchel Valve"
   sell-anywhere-at-60% upgrade. (S)
6. **Un-trap camel & hose**: camel capacity = 25% of player cap, cap 3; hose gets
   `sqrt(scoop_power)` and runs alongside manual scooping. (S)
7. **Stamina**: cost scales with tool tier + regen pause after scoop (burst resource), or
   delete the system entirely — no dead UI. (S)
8. **Onboarding**: contextual floating prompts (reuse cave-hint system) — first-water scoop
   hint, bag-full → shop arrow, first-affordable-upgrade nudge; fix tutorial copy (WASD,
   mouse). (M)
9. **Music + ambient** on the existing buses (2 loops minimum: overworld day/night or
   overworld/cave). (M)
10. **HUD info layer**: $/s + gal/s lines, `format_gallons()`, next-Influence progress. (S)

### Phase 3 — Make it mean something (story, ≈1 week)
1. **Walk-to-the-island ending**: on pool-9 completion show "IT'S GONE" paper, then release the
   player onto the drained seabed (helicopter circling) and trigger the ending at the existing
   `jeff_area`; add the binary choice ("Hand over the List / Swing") branching the final two
   newspapers — CIA set exists, write ~2 NA papers ("DRAINER VANISHES"). (S–M)
2. **Minimum-viable phone**: reuse `show_lore_popup` as "MESSAGE RECEIVED — a Friend"; ~12 NA
   texts (spec already contains the best lines) on existing triggers (first sell, pools
   1/3/5/7, first prestige, first lore read). (S)
3. **Fuse NA into prestige**: SELL OUT confirm becomes an NA text; Kickback/Muscle/Cap
   Hike/War Chest each get one handler line; dead-drop mailbox becomes interactable
   (lore-wall Area2D pattern) — teaser text pre-reveal, NA dispensary post-prestige. (S)
4. **Feed the high-frequency surfaces**: ticker mix 2-generic/4-stage + prestige-aware lines;
   milestone popups get rotating one-liners; rewrite the Guest List in the game's deadpan voice;
   one prestige-aware newspaper variant. (S–M)
5. **Update `story-rework.md`**: Goodwell kept-but-demoted (News channel subject), NA is the
   second voice; reconcile naming (Northwind Analytics everywhere). (XS)

### Phase 4 — Structure, platform, polish (parallel / ongoing)
1. **Town extraction to `scripts/world/town.gd`** + shared `VisualFX` static helper (kills
   game_world↔cave_base FX duplication). DTS_SHOT pixel-parity check. (S)
2. **god-file split** (one module per pass, screenshot-diff each): world_data (Resource),
   sky_atmosphere, terrain, water_system, wildlife, camels, island_endgame, cave_entrances,
   post_fx. The 1,009-line `_process` dissolves into per-module updates. (L, incremental)
3. **Web perf pass**: pool transient nodes, camera-proximity gating for critters, compat-only
   water simplification (no refraction), node-budget CI check. (M)
4. **Input coverage**: controller bindings + UI focus wiring (Steam Deck), fix touch
   (`emulate_mouse_from_touch` — verify or re-enable + filter in gameplay), shop refresh
   in-place instead of 0.3s rebuild. (M)
5. **Achievements + stats screen** (lifetime gallons/scoops/trips; ~20 Steam achievements) +
   re-enable news ticker throttled (one headline/~45s, fade in/out). (M)
6. **Definitions out of GameManager** (tools/stats/upgrades/caves → data file), newspaper UI
   out of scene_manager. (M)
7. **Docs hygiene**: delete/rewrite `economy-rebalance-v4.md` (it tunes systems that don't
   exist); mark superseded plan docs. (S)

### Suggested sequencing
Week 1: Phase 0 + Phase 1 items 1–3 (grade, caves, composition — the "it looks shit" fixes).
Week 2: Phase 1 items 4–6 + Phase 2 items 1–2 (town art, theme; curves, pumps).
Week 3: Phase 2 items 3–10 (prestige, caves, onboarding, audio).
Week 4: Phase 3 (story) + Phase 4 items 1, 4.
Ongoing: Phase 4 rest, ArtGen pilot verdict.

---

## Appendix — capture index (2026-07-06, `_screenshots/audit-2026-07/`)

| File | Setup | Key observation |
|------|-------|-----------------|
| title.png | boot, no flags | Boots into Day-106 save; "Midday" label over near-night visuals (murk grade) |
| town_day.png | CAMX −220, TOD 0.35 | Flat box buildings, billboard text overflow, dirt-dominated frame, sky artifacts |
| town_night.png | CAMX −220, TOD 0.9 | Near-black; string lights/windows the only readable (and charming) elements |
| pools_east_day.png | CAMX 400, TOD 0.4 | Full daytime rendering as night — murk grade evidence A |
| pools_drained.png | CAMX 400, TOD 0.4, DRAIN 1 | Same time-of-day, bright pleasant day — murk grade evidence B |
| pools_mid/far_day.png | CAMX 900/1600 | Same pattern; water barely reads; 60%+ dirt frames |
| pools_dusk.png | CAMX 700, TOD 0.72 | Unreadably dark outside lantern radius |
| cave_*.png (×5) | direct scene load, FREEZE 1 | ~90% black; half-frame spawn void; biomes indistinguishable |
