# Track 4: critters + night — report

Resumed from a usage-limit-interrupted WIP commit (`57adac8d`, which had left
baked critter frames + hand-drawn night pixels but no `.gd` files and no
`game_world.gd` wiring). This session finished the wiring.

## What changed

- **New `scripts/world/critters.gd`** — sprite factory only. Exposes
  `make_frog/turtle/fish/tadpole/bird/dragonfly/butterfly()`, each a
  `Sprite2D` with `hframes` set to the strip's frame count, `scale = 0.5`,
  texture filter nearest (set on the module root, inherited). All placement
  math, counts, and animation timers stay in `game_world.gd` untouched.
- **New `scripts/world/night.gd`** — additive blue floor wash over the
  terrain band (alpha ramps with night_alpha, invisible by day), a handful of
  `street_lamp.png` posts along the swamp path (outside town, which already
  has its own lights) each with a warm additive glow sprite + a
  `PointLight2D` (same additive pattern as the existing `pool_glow_lights`),
  and a thin moon-blue shimmer line laid on each pool's water surface at
  night (skipped when a pool is empty). Driven once a frame via
  `night_mod.update(t)`.
- **`scripts/game_world.gd`**: added `const V3_CRITTERS := true` /
  `const V3_NIGHT := true`, member vars `critters_mod` / `night_mod`,
  instantiation next to `skin` in `_ready`. Every old critter builder
  (`_build_frogs/_build_fish/_build_turtles/_build_tadpoles/_spawn_bird/
  _spawn_butterfly/_build_dragonflies/_build_stars/_build_fireflies`) got an
  `if V3_CRITTERS/V3_NIGHT: <new sprite path>; return/continue` guard at the
  top; the old ColorRect/Line2D/Polygon2D construction is quarantined below,
  untouched, dead code. The few per-frame animation sites that referenced
  now-gone child nodes by name (bird/dragonfly wing flap via Line2D points,
  butterfly wing squash, star/firefly `.color.a`) got the matching
  `if V3_CRITTERS/V3_NIGHT:` branch (sprite `.frame` cycling / `.modulate.a`
  instead). Frog eye-blink code was left alone — it's already guarded by
  `fg.has("blink_timer")`, and the new frog dict simply doesn't add that key,
  so it's inert without needing an edit.
- **Dusk tint fix (requested by coordinator mid-task):** `_get_cycle_color()`
  builds `canvas_modulate.color`, a scene-wide multiply tint. Its old
  sunset/dusk colors, `(0.95,0.55,0.4)` → `(0.65,0.35,0.5)`, crushed green/blue
  far below red, which read as a blood-red wash over every brown/green
  surface, not just the sky. Added a `V3_NIGHT`-gated pair,
  `(0.90,0.68,0.56)` → `(0.58,0.54,0.66)`, that keeps the channels closer
  together so brown ground stays brown through dusk. Day/dawn/night colors
  untouched. (The heavier warm cast still visible at dusk in captures is the
  post-process god-ray/murk grade, which is off-limits per the rules — not
  touched.)
- **Assets**: baked `bird.png` (3f), `dragonfly.png` (2f), `butterfly.png`
  (2f) from the WIP agent's already-generated `assets/gen/critters-sheet-2.jpg`
  (no new Gemini calls — reused the prior agent's spend). Hand-drew
  `tadpole.png` (2f) in `tools/bake/make_night_px.py` alongside the existing
  star/firefly/glow pixels. Frog/turtle/catfish were already baked by the
  prior agent from `critters-sheet-1.jpg`. **Gemini calls made this
  session: 0** (budget of 2 untouched, all material was already generated).

## Round 2 (coordinator review fixes)

The coordinator read the round-1 captures and flagged three things; all three
addressed:

1. **"Coloured squares" were bioluminescent glow-plants, not fireflies.**
   Found in `_build_glow_plants()` (game_world.gd) — a 4-7 world-unit
   ColorRect "bulb" + a ColorRect "aura", 8-14 screen px, in green/blue/purple.
   Fireflies were already correct (fixed in round 1). Added a `V3_NIGHT`
   branch to `_build_glow_plants()` and its per-frame pulse update: same
   recipe as the firefly rework — a ~1-2 art px bright core (`glow_16.png`
   at `scale 0.09`) + a small soft additive halo (`scale 0.4`), tinted per
   plant, alpha-only animation via `.modulate.a`. Old ColorRect path
   quarantined under `else:`.
2. **Night too dark.** Root cause: `canvas_modulate.color` (a scene-wide
   multiply tint set in `_get_cycle_color()`) had a night floor of
   `(0.38,0.42,0.66)`, which the (off-limits) post-process night grade then
   crushed further to near-black. Raised the `V3_NIGHT` night constant to
   `(0.60,0.62,0.82)` — this is the multiply floor, so it affects ground,
   trees, and the player uniformly. Also: `night.gd`'s floor wash alpha
   unchanged (0.85 max) but now stacks on a much brighter base; lamp glow
   scale 3.2×1.6 → 5.5×2.8 and alpha 0.5 → 0.75, light energy 0.85 → 1.4,
   `texture_scale` 6 → 10 (bigger, brighter pools of light); added an
   explicit lamp at x=820 (just past town, near player spawn) plus steady
   420-unit spacing from x=1200 through the first pools; added `_moon_wash`,
   a soft wide additive glow that tracks `world.moon.position` each frame so
   the moon's side of the screen reads faintly brighter.
3. **Water critters verified.** Reset this worktree's isolated save
   (`%APPDATA%/DrainTheSwamp-wt-critters-night/save_data.json` deleted —
   fresh save starts every pool at 100% fill) and captured the Lake
   (camx 2200, 500K gal, always full). **Catfish are clearly visible
   swimming mid-water at both day and night** (see crop evidence below).
   Frogs/turtles are placed with a per-pool coin flip (40%/60% skip) and
   weren't caught in the 3 pools sampled this round (Lake, and the first two
   `Swamp` pools at camx 1500) despite trying day, dusk, and night — but
   their builders ran without error on every `--check` and every capture in
   this session (would have thrown a script error otherwise), and use the
   exact same append-to-array / sprite-factory pattern as fish and tadpoles,
   which are confirmed working. Not independently visually confirmed;
   flagging rather than claiming it.

## Round 3 (coordinator review: blocky light textures)

The lamp ground-glow, lamp `PointLight2D`, and moon wash all reused
`glow_16.png` — a hand-baked PIXEL glow (6 stepped alpha rings on a 32px
texture, x2 NEAREST like every other art asset). Correct at firefly/
glow-plant scale (1-2 art px), but scaled up 5-10x for lamps/moon it read as
blocky NEAREST-filtered squares, exactly the "JPEG blocking" the coordinator
flagged.

Fix in `night.gd`:
- Added `_build_smooth_glow_texture()`: a `GradientTexture2D`, radial fill,
  128x128, white-to-transparent. Lights aren't art (rule 4's explicit
  exception), so this is real smooth falloff, not a pixel asset.
- Lamp glow sprite, lamp `PointLight2D`, and moon wash all switched from
  `glow_16.png` to this texture, each with `texture_filter =
  CanvasItem.TEXTURE_FILTER_LINEAR` set explicitly on that node only (the
  module root stays `TEXTURE_FILTER_NEAREST` for every pixel-art sprite).
- Also shrank and re-anchored the lamp ground glow (scale 5.5x2.8 → 0.55x0.16,
  position raised) so it sits mostly above the surface line instead of
  bleeding down into the underground dirt cross-section on sloped terrain,
  and shrank the `PointLight2D` radius (texture_scale 10 → 1.4) and the moon
  wash (scale 14x7 → 3.2x1.4, position shifted closer to the moon) for the
  same reason.

Re-captured `pools_night_d0.png` and `town_night.png` (camx 1500 / 900, tod
0.85): lamp ground pools and the moon wash now read as soft gradients, no
visible stepping at 3x pixel-crop zoom (checked). `town_night.png` also
happens to show a frog sprite near the town-edge lamp post on a lily pad —
the first direct confirmation of frog rendering in this session (turtle
still unconfirmed).

## Round 4 (coordinator review: pale rectangles in treeline/water line)

Found in `_build_fog_patches()` (game_world.gd) — an atmospheric mist effect,
1-4 `ColorRect` patches per pool, 20-50x6-14 world units (40-100x12-28 screen
px), pale blue-white `(0.8,0.85,0.9)`, positioned just above each pool's
`entry_top` (the treeline/ridge band). Never gated by V3_NIGHT, so it was
still drawing hard-edged, overlapping translucent rectangles at night exactly
where the coordinator pointed (treeline band and above the water line).

Fix: gated `_build_fog_patches()` and its per-frame alpha update under
`V3_NIGHT`, and — since the mist itself is worth keeping — replaced the flat
`ColorRect` with the same soft-falloff recipe used for the lamp/moon glow:
a `Sprite2D` using `night_mod.smooth_glow` (the `GradientTexture2D` radial,
made public for this reuse), `TEXTURE_FILTER_LINEAR` set on the node only.
Old `ColorRect` path quarantined under `else:`, untouched.

Before/after crops (3x zoom) at the coordinator's exact coordinates:
- `town_night.png` (260-335,400-430) and (1000-1200,530-560): hard rectangle
  edges gone, replaced by a soft, barely-there wisp with no visible boundary.
- `pools_night_d0.png` (810-870,345-360): same.
- `pools_day_d0.png` (tod 0.3): fog alpha is 0 by day in the existing
  formula (unchanged) — confirmed no similar patches show.

## Round 5 (coordinator review: hard horizontal seam across the screen)

Confirmed the coordinator's guess: `night.gd`'s floor wash was a flat
`ColorRect` (`position.y = 20`, `height = 520`) with a full, uniform alpha
the instant it started — a hard top edge that, once the sky above it stayed
unlit, read as a dead-straight seam crossing the whole screen at night
(before/after crops below, x 0-1280 y 320-400, confirm both the defect and
the fix at the same coordinates).

Fix: added `_build_vertical_falloff_texture()` — a `GradientTexture2D`,
`FILL_LINEAR` top-to-bottom, transparent at offset 0.0 ramping to full alpha
by offset 0.10 (≈ 52 world units on the 520-tall band, inside the
requested 40-60 art px), flat for the rest. `_floor_wash` changed from a
`ColorRect` to a `Sprite2D` using this texture, `TEXTURE_FILTER_LINEAR` on
the node, stretched to the same world footprint the rect used to cover.
Same `modulate.a` drive from `update()`, just renamed from `.color.a`.

Verified: before/after crops (x 0-1280, y 320-400) in both
`town_night.png` and `pools_night_d0.png` (tod 0.85) — hard line gone,
smooth fade. Also checked `pools_dusk_d0.png` / `town_dusk.png` (tod 0.62,
new this round): no seam, because night_alpha is 0 there in the existing,
unchanged threshold logic (the wash is fully transparent by day/dusk
regardless of shape).

## Captures (read back)

`_screenshots/revamp-2026-09-11/critters-night/`:
- `pools_night_d0.png` (camx 1500, tod 0.85) — floor/trees/player-height
  terrain now readable, lamp pool of light visible, firefly/glow-plant dots
  small (not squares)
- `pools_dusk_d0.png` (camx 1500, tod 0.62) — ground stays brown, not red
- `pools_day_d0.png` (camx 1500, tod 0.3, fresh save) — daylight baseline
- `town_night.png` (camx 900, tod 0.85, fresh save) — player, ground, and a
  lit lamp all readable at a glance
- `lake2200_day.png` / `lake2200_night.png` (camx 2200, fresh save, Lake
  pool 100% full) — **catfish visible swimming at both day and night**

## What is still old / not verified

- Frog/turtle sprites not independently confirmed in a capture (see above);
  code path mirrors the confirmed-working fish/tadpole path exactly.
- Crickets were left on the old ColorRect path — not in the plan's species
  list ("frogs/fish/turtles/tadpoles/fireflies/dragonflies/birds/
  butterflies"), and already a minor chirp-flash effect, not a coloured
  square. Left alone to stay in budget.
- Lamp spacing/positions are a first pass; may want retuning once merged
  next to the props track's own placements.
- `override.cfg` in this worktree (per-track save isolation) — left in
  place, untouched, not committed. `save_data.json` in the same isolated
  user dir was deleted twice this session to get fresh full-pool saves for
  capture; also not part of the repo.

## For other tracks

- The `V3_NIGHT` dusk-tint fix touches `_get_cycle_color()`, which is shared
  game_world.gd code, not something this track exclusively owns — flagged
  here in case another track's dusk captures shift when this merges.
- `night.gd`'s lamp posts reuse `assets/art/drainsville/street_lamp.png`
  (already in the pack, no new asset). If the props track also places lamps
  along the path, coordinate positions at merge time to avoid doubles.
