# Signage track — report

Branch `v3/signage`, worktree `C:/Users/weshu/CodeProjects/dts-wt/signage`.

## Status: done, verified

Resumed the WIP commit left by the previous agent (`scripts/world/signage.gd`,
`game_world.gd` switch block already written). The module code was sound; the
only missing piece was the actual baked art — `assets/art/drainsville/` had no
billboard/post/stake/cave textures yet, so nothing had ever rendered.

## What changed this session

- Baked 6 textures into `assets/art/drainsville/` via `tools/bake/bake.py`
  (all `sprite`, `--key magenta --despill`), **0 new Gemini calls** — reused
  the 5 gen sources already in `assets/gen/` from the previous agent's run:
  - `billboard.png` (528x300) ← `assets/gen/sign-billboard.jpg`
  - `sign_post.png` (178x164) ← `assets/gen/sign-post.jpg`
  - `sign_stake.png` (84x92) ← `assets/gen/sign-stake.jpg`
  - `sign_stake_l.png` (152x140) ← `assets/gen/sign-post.jpg` (same source,
    baked larger — this is the long stake next to cave mouths; no separate
    gen source existed for it, and re-baking the post art at a second size
    reads fine since it never appears next to the smaller `sign_post` in the
    same shot)
  - `cave_mouth.png` (442x180) ← `assets/gen/cave-mouth-a.jpg`
  - `cave_sealed.png` (354x180) ← `assets/gen/cave-sealed.png`
- Corrected the `*_FACE` Rect2 constants in `signage.gd` (text-safe area
  inside each board, in baked-texture px) to match the actual baked
  dimensions — the previous agent's rects were written before any bake
  existed and didn't match. Verified each by cropping the face rect back out
  of the baked PNG and eyeballing it sits inside the wood grain with margin.
- No other logic changes; `_build_billboards`, `_build_basin_signs`,
  `_build_shop_sell`, `_build_cave_mouths`, the Label-adoption/pixel-snap
  system, and the `game_world.gd` `V3_SIGNAGE` switch block were all already
  correct from the previous session and needed no edits.

## Verified (captures in `_screenshots/revamp-2026-09-11/signage/`)

- `tools/capture.py --check` — clean except the known pre-existing baseline
  error (`Parameter "t" is null`), not chased.
- `town_day.png`, `pools_1300_day.png`, `pools_1300_dusk.png`,
  `town_night.png` — billboards render as wooden boards with the verbatim
  story text in Silkscreen (checked "INJURED AT WORK... SWAMPSWORTH & SONS",
  "SWAMP ACRES... FROM $2.5M" against the original strings in
  `BILLBOARD_TEXTS`, byte-for-byte), red/blue tint alternates by ridge.
- `pools_1300_day.png` — basin name posts read "MARSH [DONE]", "BOG [DONE]",
  in green once drained; `shop_sell2.png` shows an undrained "RESERVOIR
  100.0% / 5.0M / 5.0M gal" post in the normal cream/blue ink.
- `cave_close_2.png` — an open cave mouth (mossy roots, dark opening) with
  its name plank "The Mire" reading correctly beside it, at the actual pool
  bottom (`camx 1550`); confirms `_build_cave_mouths` + `_sync_caves`
  visibility swap (sealed mound ↔ open mouth) is wired to `ce["opening"]`.
- `shop_sell_zoom.png` — the hardware-store SELL stake renders (small wooden
  board on a post) but a camel prop (props track's node) is standing
  directly in front of it in this frame, occluding all but one letter. The
  sign itself is fine; this is a props/signage placement overlap worth the
  integrator's attention, not a signage bug — didn't touch the camel.
- Did not manage to force a live "+0.015 gal" scoop float-text capture
  (`capture.py` has no debug hook to trigger a scoop) or the east-tower SELL
  plank (needs `east_tower_built = true`, a mid-game state) — verified both
  by reading `player.gd::_spawn_floating_text` (font size 14, added under
  the player node which is under `world`, not a CanvasLayer) and
  `signage.gd::_on_node_added`'s adoption filter, which together confirm the
  label will be picked up, restyled to Silkscreen 8px with a 1px outline,
  and pixel-snapped every frame. High confidence, not screenshot-verified.
- Night (`town_night.png`, `cave_night_glow.png`) is legible but dim — that
  matches every other track's night captures right now; general night
  darkness is track 4 (critters+night)'s job, not signage's.

## What is still old / out of scope here

- Nothing left in signage's own scope. All five "done when" items (wooden
  billboards, name posts, float text, SELL label, cave mouths) are built and
  wired.
- Cave interior art, the HUD, critters, and general night lighting are other
  tracks.

## Notes for the integrator

- `game_world.gd` diff is switch-only as required: one `const V3_SIGNAGE`,
  one instantiation block next to `skin`, and `if V3_SIGNAGE: return` /
  `if not V3_SIGNAGE:` guards around the four old builders
  (`_build_swamp_labels`, the two inline "SELL" Label blocks in
  `_build_shop`/`_build_east_tower`, `_build_billboards`).
- Props track: the camel (or whatever prop patrols near the hardware store)
  can stand in front of the new SELL stake at world x≈24. Not fixed here —
  positions/AI are props' file.
- `sign_stake_l.png` reuses the `sign-post.jpg` Gemini source at a different
  bake size rather than spending a Gemini call; flagging in case another
  track wants a visually distinct long-stake asset later.
- Gemini budget used by this session: 0 (all baked from existing
  `assets/gen/*` sources).
