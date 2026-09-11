# Pixel-art revamp, round 2 — 2026-09-11

**Status: PAUSED 2026-09-11 (Wes: "save the remaining work for later"). Each track's partial work is committed as unverified WIP on its `v3/<track>` branch; see the progress log at the bottom for how to resume.** Continues `visual-direction-pick-2026-09-10.md` (Wes picked B, pixel art; overworld skinned; player A picked). This round finishes the job: everything that is still a procedural Polygon2D / ColorRect / smooth-font surface gets replaced in the same pixel language, using the same process (packs for repeats, Gemini for one-offs, bake to the art grid, capture, judge).

Wes, 2026-09-10 night: *"Massive improvement overall."* The direction is right; the gap is coverage. The remaining AI-tell is every place where the old procedural draw still shows next to real pixel art (pink billboards, smooth "Marsh 100.0%" labels, square green frogs, black nights, untouched caves, the HUD).

## What is done (do not redo)

- Sky x3 crossfade, sun/moon, far pines + cypress band on terrain, textured ground + surface tiles, bank vegetation (`scripts/world/skin.gd`)
- Drainsville as sprites incl. baked signs, window glow, string bulbs, bayou shack, east water tower sprite (`scripts/world/town.gd`)
- Player A sprite, 4-frame walk at 8 fps (`scripts/player/player_skin.gd`)
- Tooling (rebuilt this session, in repo): `tools/gen.py`, `tools/capture.py`, `tools/bake/bake.py` (see "Tools")

## What is still old (the work)

| # | Track | Owner files | What is wrong now | Done when |
|---|-------|-------------|-------------------|-----------|
| 1 | **water** | new `scripts/world/water_skin.gd`; `shaders/` new file | Water reads as invisible dark mud by day, black by night; shader sparkle/foam layers read as noise | Every basin reads as water at a glance in day / dusk / night, at drain 0 and drain 1; murk lifts with the heal grade; drained basins show cracked bed |
| 2 | **signage** | new `scripts/world/signage.gd` | Billboards are pink ColorRects with a smooth font; swamp name labels and the "+0.015 gal" float text are smooth Noto; SELL label is a bare Label; cave entrances | Wooden pixel billboards with Silkscreen text (story content preserved verbatim); wooden name posts per basin; pixel float text; cave mouth sprites |
| 3 | **props** | new `scripts/world/props.gd` | Pumps, camels, island house, politicians, helicopter are procedural polygons | Each is a sprite/strip in the pack language, anchored where the old node was, same state machine driving them |
| 4 | **critters + night** | new `scripts/world/critters.gd`, `scripts/world/night.gd` | Frogs/fish/turtles/tadpoles/fireflies/dragonflies/birds/butterflies are coloured squares; night is nearly black (see `v3b_pools_night.png`) | Tiny pixel critters (2-3 frame strips); night has a readable blue floor, warm lamp pools, glowing fireflies, star sprites, moon-lit water edge |
| 5 | **hud** | `scripts/ui/*`, `scenes/ui/*`, `assets/ui_theme.tres` | Silkscreen text over flat dark bars; empty touch-control boxes; green ColorRect progress bar; shop/menu panels are theme boxes | Pixel 9-slice wood/parchment panels, pixel progress bar, pixel icon buttons; same signals/API; readable at 720p; touch controls hidden on desktop |
| 6 | **caves** | `scripts/caves/*`, `scenes/caves/*` | Ten caves, all procedural polygons and lights | Shared pixel cave kit (rock tiles, stalactites, crystals, water, loot nodes, lore wall) plus one Gemini backdrop plate per cave *family* (mud / stone / flooded / crystal / deep); same gameplay, same lights |
| 7 | **title** | `scripts/title_screen.gd`, `scenes/title_screen.tscn` | Procedural title | Gemini key-art plate (Drainsville at dusk, pixel), pixel logo, Silkscreen menu, same buttons/signals |
| 8 | **player** | `scripts/player/player_skin.gd`, `assets/art/drainsville/player_*` | Every tool draws as a bucket; scoop is the old arm tween on a hidden node; lantern is ColorRects | Per-tool hand sprite overlay; 2-frame scoop strip; lantern sprite + light |

Each track runs as its own agent in its own git worktree on branch `v3/<track>` off `v3-pixel-art`. Merge order afterwards: hud, title, caves, player (disjoint files) then water, signage, props, critters+night (all add a switch block to `game_world.gd`).

## Rules every track follows

1. **Reskin, don't rewrite.** Gameplay, state machines, signals, save data, the heal grade, the post-process shader, the story text: untouched. Only what the pixels are made of changes.
2. **Quarantine the old draw.** Open the old `_build_*` only to learn (a) where it is called, (b) what positions/state it reads, (c) which nodes other code references afterwards (keep those names alive, even as empty containers). Never re-tune it. Gate it off with a `const V3_<TRACK> := true` switch in `game_world.gd` (or `cave_base.gd`) and build the replacement in your own new module.
3. **`game_world.gd` edits are switches only**: the const, `if V3_X: return` / `if not V3_X:` guards at the top of the old builders, and one block that instantiates your module next to where `skin` is created in `_ready`. No other edits there; four tracks share that file and I merge by hand.
4. **Art grid.** 1 art px = 1 world unit = 2 screen px at 720p. Sprites placed at `scale = 0.5` with `TEXTURE_FILTER_NEAREST` on the parent. Bake everything through `tools/bake/bake.py` so the palette and grid match the town. Nothing bilinear, nothing rotated by odd angles, no ColorRect or Polygon2D as *art* (shadows / fills / murk overlays are fine).
5. **Packs for repeats, Gemini for one-offs.** Packs live in `assets/art/{gothicvania_town,gothicvania_swamp,craftpix_swamp,admurin_dock}` (licences in `assets/art/LICENSES.md`; add a credit line if you use a new pack). Gemini via `python tools/gen.py "<prompt>" --out assets/gen --name <thing>` (serialized by a lock; never call the raw tool). **Budget per track is fixed** (below); the daily cap is shared by everyone.
6. **Gemini prompt spine** (keep the look consistent): `16-bit pixel art game sprite, chunky pixels, no anti-aliasing, limited 32-color palette, dark outlines, muted swampy greens and browns, side view, single subject centered, flat solid magenta background #FF00FF, nothing else.` Add the subject. For plates drop the magenta line and say `16:9 wide`. For sprite sheets: `one row of N poses left to right, evenly spaced, same character` and bake with `--row`.
7. **Text in the world is Silkscreen** (`assets/fonts/Silkscreen-Regular.ttf`, sizes 8/16 only) or baked into the sprite. Never Noto / the default font. Numbers use VT323 if Silkscreen is too wide.
8. **Verify before you show.** `python tools/capture.py --check` must print clean. Then windowed captures into `_screenshots/revamp-2026-09-11/<track>/` — at least day (`--tod 0.3`), dusk (`--tod 0.62`) and night (`--tod 0.85`) for anything in the overworld; look at the HUD's DAY/NIGHT label to confirm the phase. Read every capture back and judge it against the town captures in `_screenshots/lookdev-2026-09-10/fix_town.png`: same pixel density, same outline weight, same saturation. If it doesn't sit next to the town, it isn't done.
9. **Release gate (Wes's AI-tell check).** Nothing that reads as programmer art. No duplicated identical sprites in a row (flip, vary, offset). No decorative emoji anywhere. Consistency beats peak: one screen where everything matches beats two screens where half does.
10. **Commit on your branch** per round, message prefixed `v3 <track>:`; do not push, do not merge, do not touch files outside your ownership (if you have to, do the minimum and call it out in your report).
11. **Report** to `docs/plans/revamp-tracks/<track>.md`: what changed, assets generated (source + bake), captures, what is still old, anything another track needs to know. Wes reads these.

## Gemini budgets (images, today)

water 3 · signage 6 · props 12 · critters+night 4 · hud 5 · caves 15 · title 5 · player 4 — 54 of the 70 daily cap.

## Tools

- `python tools/capture.py --out X.png [--camx N] [--tod T] [--zoom Z] [--drain D] [--char a] [--scene res://scenes/caves/gator_den.tscn --freeze] [--wait S]` — imports if needed, launches windowed, saves the frame, kills the game, prints script errors from the log. `--check` for a headless parse/boot test.
- `python tools/gen.py "<prompt>" --out assets/gen --name <thing>` — Gemini image, machine-wide lock. 20-40 s each. Prints a JSON line with the path.
- `python tools/bake/bake.py sprite|sheet|plate|tile SRC DST --height H [--width W] [--colors 32] [--key magenta|white|none] [--despill] [--row R] [--crop l,t,r,b]` — Gemini picture to game texture (keyed, trimmed, LANCZOS to the art grid, quantized, x2 NEAREST).
- Useful world X for `--camx`: town ≈ 900 (spawn), first pools 1300-2000, east tower 2800, later basins run to ≈ 5400 (`terrain_points` in `game_world.gd::_build_terrain`).

## Progress log

- 2026-09-11 — plan written; tools rebuilt (`tools/`) after the old bake scripts were lost with a session scratchpad; `.gdignore` added to `.claude/` and `_screenshots/` so Godot stops importing captures; eight track agents launched in worktrees under `C:/Users/weshu/CodeProjects/dts-wt/`.
- 2026-09-11 (later) — **PAUSED.** All eight track agents hit the account usage limit mid-work. Their partial work (new modules, baked sprites, Gemini sources, some captures, HUD/cave/player script edits) was uncommitted in the worktrees under `C:/Users/weshu/CodeProjects/dts-wt/`; it is now committed as `v3 <track>: WIP (agent stopped by usage limit, unverified)` on each `v3/<track>` branch and pushed. None of it is captured, reviewed, or merged. Wes: "save the remaining work for later." To resume: relaunch each track against its worktree with its original prompt plus "read your WIP commit first (`git show --stat HEAD`) and continue from it, do not restart"; spent Gemini images are in each branch's `assets/gen/`, so budgets should be reduced by what is already there. Meanwhile fixed a walkability bug he hit (stuck in the drained Swamp basin) and added `tests/terrain_walkable.gd`.
