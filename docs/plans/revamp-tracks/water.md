# Track 1: water — report

Branch `v3/water`, worktree `dts-wt/water`. Resumed from a prior agent's
usage-limit WIP commit (`da14160`), not restarted.

## What was already there (inherited, kept)

- `scripts/world/water_skin.gd`: draws every basin's water as a pixel-shader
  Polygon2D over `game_world.gd`'s `water_polygons` geometry (traced by
  reference, old draw hidden by ref, never re-tuned) plus a foam-rim
  Polygon2D and a cracked-mud bed Polygon2D that fades in as the basin
  drains. Palette is decided on the CPU per basin per frame (murk→clear by
  heal grade, day/dusk/night blend, per-basin hue identity) and pushed into
  `shaders/pixel_water.gdshader`, which only bands (flat depth bands, no
  gradients) and dashes two rows of scrolling 1px highlight pixels — both
  quantized to the art grid.
- `scripts/game_world.gd`: `const V3_WATER := true` switch; skips the old
  sparkle/foam/shimmer/lily/ripple/drained-bed builders (each gated with an
  early `if V3_WATER: return`) and adds the new `water_skin` child in
  `_ready()`. Old nodes stay alive but hidden (other code still indexes
  them by array position).
- `assets/art/drainsville/cracked_mud.png` (baked, x2) + Gemini source
  `assets/gen/cracked-mud-tile.png` — 1 of the 3-image water budget already
  spent by the prior agent. **I spent 0 further Gemini images** (budget
  note said 1 remained; unused — the fixes below were code/palette only).

## What I found broken and fixed

1. **Small basins rendered as a flat, undifferentiated color — no bands, no
   foam, no highlight dashes.** `_inner()` shrinks the water polygon by 2px
   on the bank sides via `Geometry2D.offset_polygon`; on narrow/small basins
   this can return empty or a degenerate sliver, which made `_inner` return
   an empty polygon so the shaded water Polygon2D drew nothing — only the
   full-size foam-rim Polygon2D showed, as one flat color. Fixed by falling
   back to the un-shrunk polygon whenever the offset collapses
   (`scripts/world/water_skin.gd`, `_inner()`), so the banded/dashed water
   always draws; the only loss on a collapsed basin is the 2px rim inset.
2. **Murky (low-heal) water read as invisible dirt/grass by day, per the
   plan's own diagnosis.** The `MURKY` palette was a yellow-olive
   (`Color(0.60,0.60,0.34)` top tone etc.) that sat almost exactly on top of
   the game's grass/dirt hues (both high R≈G, low B) — confirmed visually:
   a 100%-full, fully-murky basin was indistinguishable from the pasture
   next to it. Re-tuned `MURKY` blue-forward (still darker/siltier than the
   `CLEAR` palette, so heal still visibly brightens it) so it reads as
   water — silty swamp water, not lawn — at any time of day. See
   `MURKY` const in `water_skin.gd`.

Both were real rendering bugs, not just capture-state artifacts — verified
by forcing `DTS_FILL`/`DTS_DRAIN` directly (see Verification) rather than
trusting the shared save file's current progress.

## Verification

`tools/capture.py` only exposes `--drain` (heal grade), not fill level, so
its captures ride whatever fill the shared save (`user://save_data.json`,
shared across all 8 worktrees — same Godot project name) happens to be at.
That save had drifted to Day 11 / mostly-drained by the time I ran this, so
I drove the Godot binary directly with `DTS_FILL` set (0.0 / 1.0) alongside
`DTS_CAMX` / `DTS_TOD` / `DTS_DRAIN` to get deterministic full/drained
shots without touching the shared save file. All captures below re-saved
over the existing filenames in
`_screenshots/revamp-2026-09-11/water/` (read back and confirmed):

- `pools1500_{day,dusk,night}_{d0,d1}.png` — small "Swamp" basin, full
  water, drain(heal) 0 and 1, three times of day. All read clearly as
  water: banded, foam-rimmed, highlight dashes visible, murky-blue by day
  at d0, clear teal at d1, readable dim blue floor at night.
- `pools1500_day_drained.png` + a zoomed follow-up — fill 0, cracked
  flagstone-mud bed visible and clearly distinct from the surrounding
  swirly dirt-wall texture.
- `pools2200_{day,dusk,night}_{d0,d1}.png`, `zoom2200_day_d0.png` — large
  "Lake" basin, same matrix; this one always looked correct (wide enough
  that the rim-offset bug never triggered) and still does.
- `tools/capture.py --check` (headless boot/parse): only the pre-existing
  baseline `ERROR: Parameter "t" is null.` — no new errors introduced.

## What's still old / out of scope

- Foam rim is a single flat color from `pal[0].lightened(0.22)` — reads
  fine but is not itself pixel-dashed; left as-is, not part of the
  "reads as water" bar and lower risk to leave alone.
- Dusk lighting washes the whole scene orange via the existing post-process
  shader (untouched, out of scope) — water is still legible under it, just
  worth knowing the dusk captures look uniformly warm, not a water-track
  artifact.
- Did not touch terrain / `terrain_points`; `tests/terrain_walkable.gd`
  does not exist on this branch, so it was not run (per instructions).

## For the integrator

- Files touched: `scripts/world/water_skin.gd` (the two fixes above),
  `scripts/game_world.gd` (inherited switch block, unchanged by me).
- The shared save file at
  `%APPDATA%/Godot/app_userdata/Drain The Swamp/save_data.json` is common
  to every worktree (same `config/name`). Any track's captures can drift
  it; use `DTS_FILL` directly (not exposed by `capture.py`, but read by
  `water_skin.gd`'s `_fill_override`) if you need a deterministic
  full/drained shot regardless of save state.
- Merge should be a straight cherry-pick of the `V3_WATER` switch block
  (already isolated with `if V3_WATER: return` guards) plus the two new
  files; no other track file touched.
