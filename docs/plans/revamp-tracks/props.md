# props track report — 2026-09-11

## Round 1 (resume from WIP)

Resumed from a WIP commit left by a previous agent that hit the account usage
limit (`23b7694`). Its `scripts/world/props.gd`, `tools/bake/bake_props.py`,
and `game_world.gd` switch edits were sound; the gen-source images were
already in `assets/gen/` from that agent's spend. Baked them, found and fixed
a real bug (pump roots at `z_index = -1` sat *underneath* the per-pool murk
tint in `skin.gd` — pumps were fully built and positioned but 100% invisible
in game at every level), and verified all five with captures. Committed as
`v3 props: bake remaining assets, fix pump z-order bug, verify all five`.

## Round 2 (coordinator review + fixes)

Coordinator read `pumps_day`/`camels_day`/`island_day`/`heli_day` and called
out four problems. Camels were already good (pack-quality, correctly
anchored) and untouched this round.

### 1. Pumps didn't read — fixed with new art

The baked pump art (rust-brown/black, matching the source Gemini gen) was
functionally correct — right position, right z-order, right animation — but
visually inseparable from the near-black pit interior, exactly as the
coordinator described ("small featureless brown/orange box"). A modulate
brightness lift wasn't enough. Regenerated both pump sources via
`tools/gen.py` with an explicit bright/saturated/thick-outline prompt:

- `assets/gen/prop-pump-small-v2.png` — verdigris-green cast-iron hand pump,
  brass handle, coiled hose. 3-pose row (handle up/mid/down).
- `assets/gen/prop-pump-big-v2.jpg` — red industrial pump engine with a big
  yellow spoked flywheel, gauge, black intake pipe. 2-pose row (flywheel at
  two angles, doubling as the "running" animation cue).

Rebaked (`tools/bake/bake_props.py`, `JOBS` updated to point at the v2
sources, big pump now 2 frames not 3) into `prop_pump_small.png` (34 art px
tall) / `prop_pump_big.png` (40 art px tall) — both inside the requested
24-40 art px range, and now two visually distinct machines (hand pump vs.
engine) instead of two palette variants of the same silhouette. Removed the
now-unneeded modulate hack in `build_pump()`. The two pump levels are
unmistakable at a glance and the flywheel/piston frame-cycle already in
`_tick_pumps()` reads as motion once the sprite itself is visible.

Verified with dedicated per-pump captures, camera parked directly on each
basin (not the earlier `--camx 1380` wide shot, which put one pump off-frame
and the other behind the player): `pump_big_day/dusk/night.png` (Bog basin,
level 7), `pump_small_day/dusk/night.png` (Swamp basin, level 2). Both read
clearly day and dusk; night is still weak (see "still old" below — shared
with the whole-map night-darkness issue, not a pump-specific problem).
`pumps_wide_day/dusk/night.png` kept for basin-in-context reference.

**Gemini spend: 2 of the 6-image allowance** (pump small + pump big).

### 2 & 3. Island slab / politicians — fixed, then descoped mid-round

Fixed the flat black rectangle under the mansion: it was our own
`V3_island_fill` Polygon2D (`_build_island()`), a fixed-size flat-colour
rectangle that didn't follow the actual terrain contour. Replaced it with a
polygon that hugs `world._get_terrain_y_at(x)` along the mansion's footprint
(so it only fills the actual wedge between the mansion's flat baseline and
the sloped hillside) and textured it with `ground_dirt` like the rest of the
terrain instead of a flat fill colour. The separate dark block further right
in that same capture is a pool's water-murk tint (not ours) — noted for the
water track.

Fixed the "crowd of dark green zombies": `_skin_politicians()` was rendering
all 7 `politician_nodes` at their original ~8-world-unit native spacing
(overlapping bodies) inside the porch's shadow line. Changed to render only
3 of the 7 (`POLI_VISIBLE := [0, 3, 6]`, index 3 is Jeff, kept for the
interaction `Area2D`), spread them `POLI_EXTRA_SPACING = 30` world units
apart, and pushed them `POLI_FORWARD_Y = 9` world units off the porch onto
the lawn/steps in front of it. Also regenerated the politician source
(the original was too dark/muted to read as "suited politicians" even once
decrowded): `assets/gen/prop-politicians-v2.png`, 5 distinct suits with
white shirts, coloured ties (red/blue/striped), visible faces, one with a
briefcase, 2 rows (idle pose A/B) for the existing fidget-swap animation.
Rebaked `prop_politicians_a/b.png` (5 frames each, `bake_props.py` and the
`FRAMES` dict updated). Result: 3 clearly separated, suited, distinct
politicians standing in front of the porch. **Gemini spend: 1 image.**

Both fixes work and boot clean (`--check` stayed clean throughout) —
captured in `island_day/dusk/night.png` (camera at `--camx 5600` so the
player doesn't spawn on top of Jeff and block the shot).

**Then Wes descoped end-game visuals mid-round** (island house, politicians,
helicopter aren't final and may change): stopped further work on all three.
Since what's built works and boots clean, it stays behind `V3_PROPS` as
committed rather than being reverted — nothing looks worse than the old
procedural draw, and reverting working, verified code would have been pure
churn. No further polishing pass was done on these three after the descope
landed.

### 4. Helicopter rotor artifact — fixed; capture-framing not pursued (descoped)

Found the cause of the stray diagonal line in the second rotor frame: row 0
of the helicopter source has a rotor pose whose strut fragment the
connected-component frame splitter (`bake_props.split_frames_cc`) merges in
at the wrong angle. Row 1 of the same source has a clean two-pose pair
(single blade / spinning "X" blur) with no artifact and arguably a better
"running" read. Switched `bake_props.py`'s `prop_helicopter` job to row 1;
rebaked. No new Gemini image needed.

The capture-visibility problem (small blob behind the HUD bar) was still
open — the debug preview's placement math needs another look, and normal
flight altitude (`sky_y = 20`) sits close to the HUD bar regardless — when
the descope landed, so it was not pursued further. The art fix (no artifact)
is real and committed; the "verify it's actually in frame at normal
altitude" follow-up did not happen.

## What now works (current state)

- **Pumps**: two visually distinct, bright, readable machines (verdigris
  hand pump / red-and-yellow engine pump), correct z-order, piston/flywheel
  animation, hose, lamp, level pips. Confirmed in day/dusk/night captures.
- **Camels**: unchanged from round 1, still excellent.
- **Island mansion + dock**, **politicians**, **helicopter**: functional,
  fixed, boot clean, behind `V3_PROPS` — but out of scope per the mid-round
  descope, so not polished further and not re-verified beyond what's above.
- **Wanted poster**: unchanged from round 1 (bake looks correct in
  isolation; still not visually verified live — needs swamp 4 completed).

## Captures (in `_screenshots/revamp-2026-09-11/props/`)

- `pump_big_day/dusk/night.png`, `pump_small_day/dusk/night.png` — the
  primary evidence for the pump fix, camera parked on each basin.
- `pumps_wide_day/dusk/night.png` — both pumps in basin context (Bog +
  Swamp), same wide framing the coordinator originally reviewed.
- `camels_day/dusk/night.png` — unchanged, still the best of the set.
- `island_day/dusk/night.png` — mansion with the textured/contoured fill
  (no more flat slab) and 3 spread-out politicians in front of the porch.
- `heli_day.png` — kept from round 1 (not re-verified this round; framing
  issue still open, see above).
- `--check` clean after every change (only the documented pre-existing
  `Parameter "t" is null` boot error).

## What's still old / needs another pass

- **Pump night visibility.** Even with the brighter regenerated art, the
  pumps are hard to see after dark — this is the shared night-darkness
  problem (critters+night track's item), not pump-specific; day and dusk
  read fine.
- **Helicopter capture framing.** Not resolved (see above) — descoped
  before it could be chased down. Whoever picks end-game visuals back up
  should re-check whether it's visible at normal flight altitude, not just
  fix the capture command.
- **Wanted poster** still not verified live (needs `GameManager.
  is_swamp_completed(4)` true; no debug hook exists for it).

## For other tracks

- The murk-tint Polygon2D in `scripts/world/skin.gd` (z_index 4, per-pool,
  tracks `water_polygons[i].polygon` every frame) sits above anything at
  z < 4 in every basin — any other track adding basin-anchored objects
  should build above z 4, not just above the water walls at z 0.
- The flat dark block to the right of the island in `island_day.png` is a
  pool's water-murk tint, not props' — flagging for the water track.
- `game_world.gd` edits stayed within the plan's switch-only rule throughout
  both rounds: one `const V3_PROPS`, the `_ready()` instantiation block, and
  early-return guards in `_build_island_house`, `_spawn_helicopter`,
  `_build_pump_prop` (all pre-existing from the resumed WIP, untouched).

## Commits

- `v3 props: bake remaining assets, fix pump z-order bug, verify all five
  props with captures` (round 1)
- `v3 props: readable pump art, island slab/politicians fix, helicopter
  rotor fix — descope island/politicians/heli per Wes` (round 2, this
  session)

## Gemini budget used

3 of 6 images this round: `prop-pump-small-v2`, `prop-pump-big-v2`,
`prop-politicians-v2`. 3 remain unused.
