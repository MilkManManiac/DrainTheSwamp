# Track 8 — player

Owner files: `scripts/player/player_skin.gd`, `scripts/player/player.gd`, `assets/art/drainsville/player_*`, `tools/bake/bake_tools.py`, `tools/bake/paint_out_bucket.py`.

## Status: done (round 2, after coordinator review)

### Round 1 — resumed from usage-limit WIP

A previous agent on this track was stopped mid-work by a usage limit. Its
commit (`38f70eca`, "v3 player: WIP") had already generated the Gemini
sheets, painted the baked-in bucket out of the base idle/walk strips, and
rewritten `player_skin.gd` with the per-tool overlay architecture, but
`bake_tools.py` had a bug (only read one row of the actual 5x2 tools grid)
so it had never produced any `tool_*.png`, and `player_a_scoop.png` had
never been baked — `TOOLS`/`HAND["a"]["scoop"]` held placeholder guesses.
Round 1 (commit `c2af327`) fixed the row-reading bug, baked all 9 tools and
the scoop strip, and wired real grip/anchor values.

### Round 2 — coordinator review fixes (this round)

The coordinator read back round 1's captures and found four problems.
Fixed all four:

1. **Tools didn't read.** The un-outlined, un-lifted first bake blended
   into the dark ground — barely visible at zoom 3, invisible at default
   zoom. Fixed in `tools/bake/bake_tools.py`:
   - Every tool sprite now gets a 1px outline in the player's own outline
     colour (sampled live from `player_a_idle.png`'s darkest opaque pixel)
     and a brightness/saturation lift (`ImageEnhance`, ~1.3x) before
     quantizing, so it separates from shadow the way the player sprite does.
   - `wheelbarrow` (11→20 art px), `barrel` (11→16), `water_wagon` (12→20)
     are now baked much bigger and **plant on the ground beside the
     player's feet** instead of trying to fit in the hand — new
     `GROUND_TOOLS` table + `GROUND_OFFSET` in `player_skin.gd`, with its
     own code path in `_refresh_tool()`/`_process()` that skips the hand
     anchor and the walk/scoop rotation swing (equip pop-in scale is kept).
   - `spoon`'s source art is very tall/thin (75:275); at the old height=7
     it baked to a 2px-wide sliver with no legible shape. Bumped to
     height=14 so the bowl and handle stay distinguishable.
   - `hose` bumped 8→10 art px for the same readability reason.
2. **Splash particles.** Were flat sky-blue ColorRects several art px
   across with a single straight-line random-hop tween. In `player.gd`:
   - Recoloured to a 3-tone water palette (`SPLASH_MAIN`/`SPLASH_DEEP`/
     `SPLASH_HI`) matching `scripts/world/water_skin.gd`'s CLEAR surf/hi
     bands on `v3/water` (read via `git show v3/water:scripts/world/water_skin.gd`),
     fully opaque.
   - Size capped at 1-2 world units (art px) everywhere; only count/spread/
     life scale by tool now, not dot size.
   - Real motion: two-stage tween (rise ease-out, fall ease-in) instead of
     one linear hop, so it reads as a short ballistic arc; per-dot random
     stagger (0-0.05s) so a big splash (water_wagon: 24 dots) fans out
     instead of drawing as one solid bar in the first frame.
   - Fixed a timing bug in the same pass: the fade tween's delay+duration
     could exceed the position tween's total life, so the dot's
     `queue_free()` callback (fired at exactly `life`) was cutting the fade
     off early. Now `delay + duration == life` exactly.
   - Verified: `scoop_splash.png` shows individual small teal/mint squares
     scattered in an arc, not a block.
3. **Scoop bend frame looked washed out/ghosted next to idle.** Not an
   alpha bug — `player_a_scoop.png`'s alpha was already hard 0/255,
   matching idle/walk. The scoop source (`scoop-sheet-a.jpg`) is a
   different Gemini generation with a flatter, cooler, less saturated
   look (measured: mean HSV saturation 0.448 vs idle's 0.548). Re-baked
   from a colour-corrected copy of the source (`ImageEnhance.Color` 1.45x,
   `Contrast` 1.08x, `Brightness` 1.04x, plus a small manual R+10/G-8/B-4
   channel shift to cut the greenish cast) through the same
   `tools/bake/bake.py sheet` recipe. Side-by-side with idle it now reads
   as the same character in a different pose, not a different, flatter
   sprite; some residual softness remains on the hat since the source
   lighting genuinely differs, but it no longer reads as broken/ghosted.
4. **`lantern_night.png` artifacts, investigated:**
   - The pale grey-blue rectangle (~890-1190, 435-500 in that capture) is
     `game_world.gd::_build_billboards()`'s sign panel `ColorRect`
     (`sign_bg`, `blue_tint` ≈ `Color(0.78,0.82,0.90)`) sitting unlit at
     night near camx 1050 — **not** ours; the old lantern ColorRects
     (`wire`/`cap`/`lantern_glass`/`base`/`lantern_flame`) are confirmed
     hidden — `player_skin.gd::_build_lantern()` sets every `CanvasItem`
     child of `player.lantern_node` invisible before adding the new
     sprite. Confirmed by re-reading the code and by the rectangle's
     position (near a ridge boundary, independent of the player). Left
     alone — **signage** track's territory.
   - The warm yellow-green orb at the player's hand is our lantern's own
     `PointLight2D` (`player.gd::_setup_lantern`/`_update_lantern`,
     untouched this round) — working as intended, modest and warm.
   - The second green-yellow orb off to the side is not player-owned:
     `game_world.gd::_build_pool_glow_lights()` creates one
     `PointLight2D` per basin tinted by `SWAMP_WATER_COLORS[i]`; it's
     independent of the player and doesn't track him. Left alone per the
     coordinator's instruction ("if fireflies/world lights, say so and
     leave them").
   - Noted but out of scope: the `"+0.0000 gal"` floating text is large
     and in the default (Noto) font, not Silkscreen — that label is
     `player.gd::_scoop_feedback()`'s `_spawn_floating_text`, which reads
     as **signage** track territory (rule 7, text-in-world font) since it's
     a HUD-language choice, not a sprite; flagged, not changed here to
     avoid stepping on that track's font pass.

## What now works

- Every tool (spoon/cup/bucket/shovel/hose = hand-held; wheelbarrow/
  barrel/water_wagon = ground-set beside the feet) draws as its own
  outlined, brightened baked sprite — no tool draws as a bucket, and it's
  identifiable at both default zoom and zoom 3 (see captures).
- Scoop: the 3-frame bend/low strip plays bend→low→low→bend off the
  `scooped` signal, colour-matched to idle/walk, with a matching small
  water-coloured splash arc that fades out cleanly.
- Lantern: baked sprite + overbright flame pixel + unchanged
  `PointLight2D` glow/flicker/sway; confirmed nothing from the old
  ColorRect draw leaks through.
- Character A, 4-frame walk at 8 fps and the 16x32 collision: untouched.

## Assets

- Source (Gemini, generated by the round-1 agent before this track's own
  session): `assets/gen/tools-row.jpg`, `assets/gen/scoop-sheet-a.jpg`.
  **Gemini budget: 1 image left**, still unused (no new Gemini calls any
  round — round 2's colour fix used a local `ImageEnhance` pass on the
  existing source, not a regeneration).
- Baked/rebaked this round: all 9 `assets/art/drainsville/tool_*.png`
  (bigger + outlined + lifted), `assets/art/drainsville/player_a_scoop.png`
  (colour-corrected).
- Unchanged from round 1: `player_a_idle.png`, `player_a_walk.png`.

## Captures (read back, `_screenshots/revamp-2026-09-11/player/`)

`--camx 1050` (clear hillside spot east of spawn, avoids both the spawn
billboard and the first pools' unfixed water murk):

- `idle.png` — idle pose, default tool (water wagon), zoom 3.
- `tool_<id>.png` (zoom 3) and `tool_<id>_default.png` (no --zoom, i.e.
  default in-game zoom) for all 8 non-lantern tools
  (bucket/shovel/wheelbarrow/barrel/water_wagon/hose/spoon/cup),
  `DTS_TOOL=<id>` — every one reads as a distinct, outlined shape at both
  zoom levels; wheelbarrow/barrel/water_wagon visibly plant on the ground
  next to him rather than in his hand.
- `scoop_bend.png` — bent scoop pose with the ground-set water_wagon prop
  unaffected by the pose, small teal splash dots arcing above.
- `scoop_splash.png` — timed closer to the burst's start; individual 1-2px
  water-coloured squares, not a block.
- `lantern_night.png` — the three-artifact scene from the coordinator's
  review (billboard rectangle, lantern glow, pool-glow orb), re-captured
  and re-confirmed against the current code.

`python tools/capture.py --check` prints only the known pre-existing
`ERROR: Parameter "t" is null.` boot line — clean per the track rules.

## What is still old / rough edges

- Only character A has a measured `HAND` table; B/C fall back to a
  hip-guess anchor if ever selected via `DTS_CHAR`.
- The scoop bend frame's hat/skin tone is still very slightly cooler than
  idle's even after the colour-match pass — the two Gemini generations
  genuinely differ in lighting, and a channel-shift correction can only
  get so close without hand-editing pixels. Readable and no longer
  "washed out," not a perfect match.
- `assets/gen/tools-row.jpg` still has Gemini's duplicate barrel frame;
  `bake_tools.py` drops it programmatically, but if that source image is
  ever regenerated, re-check the row layout still matches (5x2 grid,
  9 wanted items).

## Notes for other tracks

- Nothing outside `player`'s owned files was touched.
- **signage**: the spawn billboard (camx ~900) visually overlaps a
  standing player at zoom 3; its `ColorRect` sign panel also reads as a
  flat grey-blue box when unlit at night (see `lantern_night.png`); and
  the `"+0.0000 gal"` scoop float text (`player.gd::_spawn_floating_text`,
  called from `_scoop_feedback`) is in the default Noto font at a large
  size, not Silkscreen — all flagged, none fixed here.
- **water**: the first pools (camx 1300-2000) are still visibly dark/murky
  by day.
