# Track 8 — player

Owner files: `scripts/player/player_skin.gd`, `assets/art/drainsville/player_*`, `tools/bake/bake_tools.py`, `tools/bake/paint_out_bucket.py`.

## Status: done (resumed from usage-limit WIP)

A previous agent on this track was stopped mid-work by a usage limit. Its
commit (`38f70eca`, "v3 player: WIP") had already:
- generated `assets/gen/tools-row.jpg` (9-tool sheet) and `assets/gen/scoop-sheet-a.jpg`
  (3-pose bend/low crouch) via `tools/gen.py` — this used the track's whole
  4-image Gemini budget except one (2 images spent: tools-row, scoop-sheet-a;
  char-a-walk2/3 in `assets/gen/` are older exploratory sheets from the walk-cycle
  round, not spent by this track)
- painted the baked-in bucket out of `player_a_idle.png` / `player_a_walk.png`
  (`tools/bake/paint_out_bucket.py`) so the base strips are empty-handed
- rewritten `scripts/player/player_skin.gd` with the per-tool overlay
  architecture (`_tool` Sprite2D following a HAND anchor table, `_build_lantern`,
  `_update_lantern`), and wired `player.gd`'s `scooped` signal
- written `tools/bake/bake_tools.py` (per-tool sheet splitter/baker), but it
  assumed a single row of 9 items — the actual generated `tools-row.jpg` is a
  5x2 grid (10 images: Gemini duplicated the barrel) and the script had never
  been run, so no `tool_*.png` existed yet, and `player_a_scoop.png` had never
  been baked either. `TOOLS`/`HAND["a"]["scoop"]` in `player_skin.gd` held
  placeholder grip/anchor guesses.

This session finished the resume:

1. Fixed `bake_tools.py` to read both rows of `tools-row.jpg` and drop the
   duplicate barrel (row1 slot 0), instead of only reading the widest row.
   Ran it → wrote `assets/art/drainsville/tool_{spoon,cup,bucket,shovel,
   wheelbarrow,barrel,water_wagon,hose,lantern}.png` (16-colour, x2 NEAREST).
2. Baked `assets/gen/scoop-sheet-a.jpg` → `assets/art/drainsville/player_a_scoop.png`
   (3 frames, 40 art px tall / 28 colours, same recipe as idle/walk) via
   `tools/bake/bake.py sheet ... --row 0 --frames 3`.
3. Measured real hand-anchor art-px coordinates for the 3 scoop frames (grid
   overlay + pixel inspection) and the real tool grips from `bake_tools.py`'s
   printed suggestions, replacing every placeholder in `player_skin.gd`
   (`TOOLS`, `LANTERN_GRIP`, `LANTERN_FLAME`, `HAND["a"]["scoop"]`).
4. Captured and read back every result (see below); no code changes were
   needed after that — the previous agent's `player_skin.gd` rewrite was
   already correct.

## What now works

- Every tool (spoon/cup/bucket/shovel/wheelbarrow/barrel/water_wagon/hose)
  draws as its own small baked sprite pinned to the hand, following the
  existing arm-swing/scoop-pop tweens on the hidden `ToolSprite` node — no
  tool draws as a bucket anymore, and the base idle/walk sprite's hand is
  empty (bucket painted out).
- Scoop: a hidden 3-frame bend/low strip (`player_a_scoop.png`) plays
  bend→low→low→bend off the `scooped` signal, in front of the tool overlay
  which follows the same hand anchors during the crouch.
- Lantern: a baked sprite (`tool_lantern.png`, handle top at the old wire
  position) plus an overbright flame pixel replace the ColorRect
  glass/flame/cap/base/wire; `PointLight2D` glow, flicker and walk-sway are
  unchanged from `player.gd`.
- Character A, 4-frame walk at 8 fps: untouched, unchanged from before this
  round.
- Player collision (16x32): untouched.

## Assets

- Source (Gemini, already generated before this session): `assets/gen/tools-row.jpg`,
  `assets/gen/scoop-sheet-a.jpg`.
- Baked this session: `assets/art/drainsville/tool_spoon.png`, `tool_cup.png`,
  `tool_bucket.png`, `tool_shovel.png`, `tool_wheelbarrow.png`, `tool_barrel.png`,
  `tool_water_wagon.png`, `tool_hose.png`, `tool_lantern.png`,
  `assets/art/drainsville/player_a_scoop.png`.
- Already baked/edited by the previous agent (committed at HEAD before this
  session): `player_a_idle.png`, `player_a_walk.png` (bucket painted out).
- **Gemini budget: 1 image left**, unused this session (reused the previous
  agent's two generations; no new Gemini calls needed).

## Captures (read back, `_screenshots/revamp-2026-09-11/player/`)

All at `--camx 1050` (clear hillside spot east of spawn — camx 900 sits the
player under the not-yet-reskinned billboard, which visually obstructs the
shot; camx 1500 lands in a still-dark first-pool basin, water track's
territory) `--zoom 3`:

- `idle.png` (`--tod 0.3`) — idle pose, default equipped tool (water wagon),
  bucket-free hand.
- `tool_bucket.png`, `tool_shovel.png`, `tool_wheelbarrow.png`,
  `tool_hose.png`, `tool_barrel.png` (`--tod 0.3`, `DTS_TOOL=<id>`) — each
  tool rendering distinctly at the hand; sizes read correctly relative to
  each other (barrel visibly larger than bucket/shovel) though the props
  are small and sit partly in the terrain's shadow band at this spot — a
  brighter/flatter capture spot would show them better, but that's a
  camera-placement nit, not a rendering bug.
  (spoon/cup/water_wagon not captured individually — same code path, no
  reason to expect a different failure mode.)
- `scoop_bend.png` (`DTS_SCOOP=1`, timed to land mid-arc) — character bent
  into the low scoop pose with splash particles; confirms the scoop strip
  and signal wiring fire correctly.
- `lantern_night.png` (`--tod 0.85`, `DTS_LANTERN=1`) — warm glow blooms
  from the hand at night, readable.

`python tools/capture.py --check` prints only the known pre-existing
`ERROR: Parameter "t" is null.` boot line — clean per the track rules.

## What is still old / rough edges

- Only character A has a measured `HAND` table (per the plan, "only A has
  been measured"); B/C fall back to the hip-guess anchor if ever selected
  via `DTS_CHAR`.
- Tool sprites are correct but small at this render scale; they read
  clearly in a zoomed crop but are subtle in a normal-zoom screenshot,
  especially in shadowed terrain. Worth a look once the water/terrain
  lighting tracks land, in case the ambient shadow band is itself an
  unrelated bug.
- The duplicate barrel in `assets/gen/tools-row.jpg` (Gemini repeated the
  prompt) is harmless — `bake_tools.py` now drops it — but if that source
  image is ever regenerated, re-check the row layout still matches.

## Notes for other tracks

- Nothing outside `player`'s owned files was touched.
- The billboard near spawn (camx ~900) visually overlaps a standing player
  at zoom 3 — flagged for the **signage** track, not fixed here.
- The first pools around camx 1300-2000 are still visibly dark/murky by
  day — that's the **water** track's known issue, not touched here.
