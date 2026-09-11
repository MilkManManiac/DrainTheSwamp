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
- Used 0 of the 6-image Gemini budget — all needed source art already
  existed in `assets/gen/` from the stopped agent's earlier work.

## For other tracks

- `scripts/caves/loot_node.gd` and `scripts/caves/lore_wall.gd` now depend
  on `assets/art/caves/loot_props.png` existing (frame 0 = crate/cash,
  frame 1 = ore vein/stat-tool-camel reward, frame 2 = rune slab/lore). If
  another track touches loot/lore visuals elsewhere, this is the new asset.
- No edits made outside `scripts/caves/*`, `scenes/caves/*` (untouched),
  and `assets/art/caves/*` — nothing another track needs to merge around.
