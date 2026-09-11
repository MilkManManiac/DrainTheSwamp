# Track 6: caves — report

Resumed from a WIP commit left by an agent stopped mid-work on 2026-09-11
(`0d3e3ad`). That commit already had `scripts/caves/cave_skin.gd` (the whole
pixel cave kit: backdrop plate, rock-texture floor/ceiling/walls, prop
placement, signature set-piece, water shader hookup) and `cave_base.gd`
gated behind `const V3_CAVES := true`, plus `loot_node.gd` / `lore_wall.gd`
reskinned to use a baked `loot_props.png` strip. All 10 Gemini source plates
and prop sheets were already generated in `assets/gen/` (0 new Gemini calls
needed this session — budget untouched).

**What was missing and is now done:** none of the prop sheets or the stone
tile were baked yet — `assets/art/caves/` only had the 5 backdrop plates and
`tile_earth.png`. `cave_skin.gd` was silently drawing no stalactites,
stalagmites, crystals, mushrooms, boulders, roots, or signature set-piece
because `_tex()` returns null for a missing file and `_strip()` no-ops on
null. Baked the missing 8 files with `tools/bake/bake.py sheet` from the
existing `assets/gen/cave-*` sources:

| file | frames | height (art px) | notes |
|---|---|---|---|
| `stalactites.png` | 5 | 34 | clean auto-split |
| `stalagmites.png` | 5 | 24 | source is one continuous ridge (no transparent gaps between peaks) — auto-split found 1 frame; manually cropped 5 peaks at the base-level local minima instead of using `bake.py sheet`'s column-gap splitter |
| `crystals.png` | 5 | 20 | clean auto-split |
| `mushrooms.png` | 4 | 12 | clean auto-split |
| `boulders.png` | 5 | 18 | clean auto-split |
| `loot_props.png` | 3 | 16 | crate / ore vein / rune slab — feeds `loot_node.gd` and `lore_wall.gd` directly |
| `signature.png` | 7 | 40 | auto-split merged skeleton+dead_tree into one run (378px wide vs ~150-200 for the others); manually re-cut at x=830 (the local minimum between them) so all 7 `SIG_FRAME` entries (crates/mine_cart/pump/skeleton/dead_tree/pillars/coral) land on distinct frames |
| `tile_stone.png` | — | 64x64 | `tile` mode, matches `tile_earth.png`'s params |

Also confirmed the frame math: every strip's width divides evenly by its
`FRAMES[name]` entry in `cave_skin.gd`, so `Sprite2D.hframes` slicing is
correct (no torn/garbled frames).

## Families and coverage

`cave_skin.gd`'s `FAMILY` map covers all 10 caves across 5 families (mud,
stone, grotto, crystal, deep — the plan calls the fourth "flooded", the WIP
code calls it "grotto"; same backdrop, cosmetic naming difference only):

- mud: muddy_hollow, gator_den
- stone: the_sinkhole, collapsed_mine, the_cistern
- grotto: the_mire, sunken_grotto
- crystal: coral_cavern, the_underdark
- deep: mariana_trench

Each cave's `_init()` still sets its own `crystal_color` / `ground_color` /
`signature`, so the shared kit still reads as 10 distinct caves, not 5
repeated ones.

## Verify

`python tools/capture.py --check` against `muddy_hollow.tscn`: clean boot,
no script errors (the known pre-existing `Parameter "t" is null` boot error
on the *main* scene does not apply here).

Captured all 10 caves (`--freeze --wait 3`, default spawn camera position):
`_screenshots/revamp-2026-09-11/caves/<cave>.png`. Read every capture. All
of them:
- show rock-texture floor/ceiling/walls (baked `tile_stone`/`tile_earth`,
  no flat procedural polygons)
- show stalactites hanging from the ceiling, boulders/crystals on the floor,
  a lit player sprite, and (where a pool is in frame) the banded pixel
  water shader
- read as visually distinct per family (mud = warm brown/green, stone =
  cool grey-blue, grotto = teal/green wash, crystal = purple, deep = blue)
  and per-cave via the crystal-color tint (e.g. the_underdark's magenta-purple
  glow vs. the_sinkhole's cyan)
- no pink billboards, no bare ColorRect/Polygon2D "art", no smooth-font text
  in frame

One capture (`the_sinkhole.png`) shows a loot crate near the bottom-right
edge — confirms `loot_node.gd`'s baked sprite path is live.

## What is still old / not covered by this pass

- The signature set-piece sits at 62% across each cave's span; none of the
  10 captures (default spawn camera, near the entrance) happened to frame
  it. Not re-verified visually this session — the code path is unchanged
  from the WIP commit and the source art was confirmed correct (7 distinct
  frames, right order). Worth a `--camx` capture at each cave's signature
  point before calling the set-pieces fully verified.
- Cave water is a flat 3-band pixel shader (`cave_water_pixel.gdshader`,
  already in the WIP commit) — reads clearly as water in every capture but
  is plain; no surface animation beyond the shader's own time uniform (not
  wired to `_process` — `time` is set once to `0.0` in `cave_skin.gd::_late`
  and never updated). Low priority: it already reads fine at a glance.
- Didn't touch cave scene files (`scenes/caves/*.tscn`) or gameplay/collision
  — per the rules, the WIP commit's `cave_base.gd` switch already keeps
  those untouched.
- Round 1 used 0 of the 6-image Gemini budget — all needed source art
  already existed in `assets/gen/` from the stopped agent's earlier work.
  Round 2 (below) used 3 for the new edge-lip trim textures; 3 remain.

## Round 2 (2026-09-11, coordinator review)

Coordinator read 4 of 10 captures (muddy_hollow, collapsed_mine, coral_cavern,
mariana_trench). Muddy Hollow was close to right; the rest needed another
pass. Seven issues, all fixed in `scripts/caves/cave_skin.gd` and
`scripts/caves/cave_base.gd`:

1. **Stalactites were one repeated asset.** Same pale icicle sprite, even
   spacing, no tint. Added `FAMILY_TINT` (mud=brown/ochre, stone=grey-blue,
   grotto=green-grey, crystal=violet, deep=cold blue) applied as `modulate`;
   rewrote `_build_ceiling_props()` to place irregular clusters of 1-4 with
   jittered spacing (10-26 world units apart within a cluster, 30-90 between
   clusters) instead of one evenly-spaced row; scale is now a continuous
   `randf_range(0.5, 1.7)` instead of 3 fixed steps; a frame+flip+scale key
   check forces a different frame if two neighbors would be identical. Roots
   got the same tint treatment.
2. **Mariana / Coral / Collapsed Mine read empty.** Backdrop tint was
   `lerp(..., 0.5) * 0.62` — far too dark (Coral's plate was nearly invisible).
   Changed to `lerp(..., 0.3) * 0.95` (`* 1.18` specifically for "deep" —
   `bg_deep.png`'s own source art is unusually dark even after the general
   fix). Floor prop density raised across the board: boulder clusters
   `span/300` → `span/170` (more clusters, 2-4 children each instead of 1-3,
   40% front-of-camera chance instead of 30%), stalagmite spacing 160-300 →
   100-190, mushroom clusters `span/700` → `span/380`, crystal count
   `span/420` → `span/260` for the "deep"/"crystal" families specifically
   (bioluminescence is their whole identity) and `span/420`→ still denser
   for everyone else. Mariana Trench ("deep" family) now also grows
   kelp-like roots up off the floor (not just hanging from the ceiling),
   tinted toward its crystal colour and lightly emissive so they read as
   bioluminescent kelp, per "deep, flooded place" direction.
3. **Collapsed Mine's backdrop looked smeared.** `bg_stone.png` itself is
   crisp at the correct art-grid size (1280x720 = 640 art-px plate x2,
   matches the `plate` bake recipe) — re-baking would have changed nothing.
   Root cause is more likely a texture-filter inheritance edge case (the
   project's global default is `textures/canvas_textures/default_texture_filter=1`
   / Linear, from the old high-res-2D direction; `cave_skin.gd` overrides to
   NEAREST on itself and relies on CanvasItem inheritance down through
   Parallax2D). Set `texture_filter = NEAREST` explicitly on every backdrop
   Sprite2D and every `_rock_poly()` Polygon2D as well, rather than relying
   on inheritance alone. Re-captured — reads crisp now; flag to Wes if it
   still looks soft on his machine, since I could not fully isolate the
   original cause without a side-by-side on his display.
4. **Grey vertical bar read as a solid pole, not a light shaft** —
   `cave_base.gd::_build_light_shafts()`. The cone/beam colors were run
   through `_emit(..., 1.8)` / `_emit(..., 2.2)` (HDR overbright — channel
   values pushed past 1.0), which tripped the bloom threshold and blew the
   soft additive gradient into a hard-edged bright column. Removed the HDR
   boost entirely (plain alpha-blended ADD, no overbright); narrowed the
   beam Line2D width (4-8 → 3-5) and lowered its alpha slightly. Reads as a
   soft shaft now, not a pillar.
5. **Black blob buried in the floor rock, ~same screen spot in every cave**
   — `cave_skin.gd::_build_foreground()`, the dark corner-framing boulder.
   Its anchor was `_floor_y(bx) + 40.0` — 40 world units *below* the floor
   contour — while every other floor prop in this file anchors at
   `_floor_y(x)` (the strip helper is already bottom-aligned). At 2x scale
   that buried most of the boulder in the ground. Fixed to `_floor_y(bx) + 1.0`
   (same convention as every other floor prop) and moved the prop closer to
   the cave edges (`_left/_right ± 60` instead of `± 140`) so it reads as
   edge framing instead of sitting in the open play space near spawn. It's
   still a deliberately near-black silhouette by design (far-foreground
   framing device) — now correctly grounded instead of half-buried.
6. **Floor/ceiling edge was a flat 1px line.** Generated 3 new Gemini tile
   textures (seamless trim strips, not sprites — no magenta key, flat solid
   background instead, cropped) and baked them by hand (bake.py's `sheet`
   auto-splitter doesn't apply to a single continuous strip):
   `edge_moss.png`, `edge_rubble.png`, `edge_crystal.png` — 98x28 / 70x28 /
   104x28 baked px. New `FAMILY_EDGE` map (mud/grotto→moss,
   stone/deep→rubble, crystal→crystal-crust) and a new
   `_build_edge_lip()` builds a textured ribbon Polygon2D straddling the
   floor contour (mostly above it) and a matching one under the ceiling
   contour (UV-flipped via negative `texture_scale.y` — Polygon2D has no
   `flip_v`), both tiled via `texture_scale = Vector2(2.0, 2.0)` the same
   way the rock tile already works. Replaces the old flat "lightened 1px
   lip" line (the dark 2px contour outline stays, for silhouette crispness).
   **3 of the 6-image Gemini budget used here** (3 remain).
7. **"Unstuck" button used the default smooth engine font** —
   `cave_base.gd::_setup_cave_ui()`, ~line 2106. It's caves-owned code (not
   the hud track's file). No baked 9-slice button asset exists yet from any
   track, so used the rule's documented fallback: Silkscreen font (size 8,
   `res://assets/fonts/Silkscreen-Regular.ttf`) + a blocky wood-toned
   `StyleBoxFlat` (dark brown fill, warm tan 2px border, 0 corner radius,
   separate hover/pressed shades) instead of the default rounded dark-grey
   box. Widened its screen anchor slightly (`-70` → `-96` from the right
   edge) since "UNSTUCK" in Silkscreen at size 8 is wider than the old
   default-font "Unstuck".

Re-captured all 10 caves after the fixes (`tools/capture.py --check` clean
on muddy_hollow / mariana_trench / coral_cavern / collapsed_mine first).
Read every capture back, plus two extra mid-cave (`--camx`) checks on
Mariana Trench and Coral Cavern specifically to confirm the density fix
holds beyond the spawn-adjacent view the standard captures show (it does —
both show populated crystal-lit walls and floor clutter). Capture paths:
`_screenshots/revamp-2026-09-11/caves/<cave>.png` (all 10, overwritten) plus
`mariana_trench_mid.png`, `coral_cavern_mid.png`,
`collapsed_mine_signature.png`, `the_underdark_signature.png`.

## For other tracks

- `scripts/caves/loot_node.gd` and `scripts/caves/lore_wall.gd` now depend
  on `assets/art/caves/loot_props.png` existing (frame 0 = crate/cash,
  frame 1 = ore vein/stat-tool-camel reward, frame 2 = rune slab/lore). If
  another track touches loot/lore visuals elsewhere, this is the new asset.
- No edits made outside `scripts/caves/*`, `scenes/caves/*` (untouched),
  and `assets/art/caves/*` — nothing another track needs to merge around.
