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

## Captures (read back)

`_screenshots/revamp-2026-09-11/critters-night/`:
- `pools_night_d0.png`, `pools_dusk_d0.png`, `pools_day_d0.png` — camx 1500
- `pools_day_fresh.png` — fresh save (drain 0, day 1 morning), water 100%
- `town_night.png` — camx 900

Night: floor reads as moonlit blue-brown instead of near-black; a lamp post
with warm bulb glow + light pool is visible along the path; stars/fireflies
render as real sprites now (were 2x2 ColorRects). Dusk: ground stays brown,
not red. Frog/turtle/fish/bird/dragonfly/butterfly/tadpole are all real
2-3-frame pixel strips (verified by reading `assets/art/drainsville/{frog,
turtle,catfish,bird,dragonfly,butterfly,tadpole}.png`), each frame distinct
(no duplicate-sprite AI-tell).

## What is still old / not verified

- Could not confirm frog/fish/turtle sprites in a live filled pool in a
  capture — the one fresh-save shot with 100% water had the "HOLD SPACE to
  scoop" hint dialog covering the basin, and the water surface (owned by the
  water track) reads as a flat dark green that may be occluding underwater
  critters via z-index; worth a joint check with the water track once both
  land on the same branch.
- Crickets were left on the old ColorRect path — not in the plan's species
  list ("frogs/fish/turtles/tadpoles/fireflies/dragonflies/birds/
  butterflies"), and already a minor chirp-flash effect, not a coloured
  square. Left alone to stay in budget.
- Lamp spacing (every 480 world units from x=1000) is a guess tuned to make
  one lamp land near the plan's example capture position (camx 1500); may
  want retuning once merged next to the props track's own placements.
- `override.cfg` in this worktree (per-track save isolation) — left in
  place, untouched, not committed (matches instruction).

## For other tracks

- The `V3_NIGHT` dusk-tint fix touches `_get_cycle_color()`, which is shared
  game_world.gd code, not something this track exclusively owns — flagged
  here in case another track's dusk captures shift when this merges.
- `night.gd`'s lamp posts reuse `assets/art/drainsville/street_lamp.png`
  (already in the pack, no new asset). If the props track also places lamps
  along the path, coordinate positions at merge time to avoid doubles.
