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

## Round 2 (2026-09-11, same day) — Wes's review fixes

Wes reviewed `pools_1300_day`, `cave_close_2`, `shop_sell_zoom`, `town_night`
and called five fixes before merge. All five addressed:

1. **Billboards far too big.** Rebaked `billboard.png` at `--height 100`
   (was `--height 150`) → 352x200 px (was 528x300), world footprint now
   ~176x100 units, in line with the old procedural billboard's 120x113
   footprint and well under "3x player height." Recomputed `BILLBOARD_FACE`
   to match (`Rect2(13, 10, 325, 107)`), re-verified by cropping the face
   rect back out of the new bake. **Caught a real bug doing this**: the
   first rebake silently didn't take effect in-game because `bake.py`
   overwrites the PNG but not its stale `.png.import` sibling, and
   `capture.py`'s `needs_import()` only checks *whether* an `.import` file
   exists, not whether it matches the source — so the game kept rendering
   the old 528x300 texture at the old scale until the import was forced
   (`rm billboard.png.import && godot --headless --import`). Left as a
   pitfall note for other tracks re-baking an asset a second time.
2. **Non-Silkscreen text on posts/planks, "DRA INED" gap.** The basin
   post's `%`/gallons labels and the cave name plank were on
   `VT323-Regular.ttf` (`_num_font`), not Silkscreen — that VT323 use is
   what Wes was seeing as "thin, blurry." Removed `_num_font` entirely;
   every Label in the file now goes through the single Silkscreen
   `_font` at size 8 or 16, integer positions (already `.round()`'d).
   The "DRA INED" mid-word gap was a VT323 rendering artifact at that size
   and is gone with the font switch.
3. **Basin post overlapping billboard legs.** `_build_billboards` now
   records each board's `{x, half_w}` span; `_build_basin_signs` runs the
   post's x through a new `_clear_of_billboards()` that nudges it away from
   any span it would overlap (half-widths + 8px margin). Tried moving the
   post to the opposite side of the entry rim first (into the pool) — reverted
   that after it turned out to sometimes land behind/inside that pool's cave
   mound (higher z_index, fully occludes a smaller sprite behind it); kept
   the original ridge-side offset and let the new clear-of-billboards nudge
   do the work instead.
4. **Illegible at night.** Added a tiny hand-pixelled gooseneck lamp
   (`_make_lamp_texture()`, a procedural 6x10 image nearest-doubled to
   12x20 — no new Gemini spend) atop every billboard and basin post.
   First attempt used a `PointLight2D` / additive light-cone, which turned
   out to barely register against `CanvasModulate`'s night tint (confirmed
   by direct pixel math, not just a hunch) — replaced with `_register_glow()`,
   which lerps each lit node's `modulate` from its day color up to
   `day_color * (1/night_tint)` as `_glow_t()` (a local copy of
   `game_world.gd`'s town-light curve, reading `GameManager.cycle_progress`)
   rises, i.e. it exactly cancels the night darkening rather than guessing at
   an additive amount. Billboards (board + text) go to full strength; basin
   posts keep the wood dim per Wes ("posts can stay dim") but boost the three
   text lines to 0.85 strength so they stay legible.
5. **Float text / SELL not shown.** First pass verified `+0.015 gal` with a
   temporary local test spawn that reproduced `player.gd::_spawn_floating_text`
   exactly and confirmed `_on_node_added`'s adoption path works — but that
   was testing the adoption path in isolation, not the real one. Re-captured
   the SELL stake at the hardware store from two angles; the sign itself
   renders correctly but a camel prop is parked directly in front of it in
   every capture (not a camera-timing issue — it doesn't move), so only one
   letter is visible. Camel placement is a props-track issue, not fixed here
   (see integrator notes).
6. **Float text was actually never adopted in real play** (caught from
   `v3/player`'s own `scoop_splash.png`: "+0.0000 gal" rendering ~60px tall
   in smooth Noto). Root cause: `player.gd::_spawn_floating_text` adds its
   Label under the *player* node, and depending on where the player is
   parented that walk-up in `_on_node_added` may never reach `world`, so the
   label is skipped and stays unstyled. Fixed by giving `player.gd` (not
   owned by this track) the minimum possible edit: the scoop-gallons call
   site now does `get_tree().get_first_node_in_group("signage")` and calls a
   new public `signage.spawn_gal_float(self, output)` when present, falling
   back to the old inline text if signage isn't loaded. `spawn_gal_float()`
   lives entirely in `signage.gd`: Silkscreen 8px with a 1px outline (same
   family as everything else in this file), text formatted through
   `Economy.format_gallons()` (money-style K/M/B suffixes) instead of
   player.gd's ad hoc `%.1f/%.2f/%.4f` picks, and it returns immediately
   without spawning anything when `absf(amount) < 0.00005` (displays as
   zero). Gallon math in player.gd is untouched — only the display call
   changed. Verified with a temporary debug spawn calling the *real*
   `spawn_gal_float()` directly (`float_text_v2.png`: "+0.0150 GAL" in
   pixel Silkscreen, correctly small next to the player; a paired
   zero-amount call produced nothing); debug code removed before commit.
7. **Basin labels colliding with the HUD bottom bar / MENU button** (Wes,
   from a 1080p `hud verify_day.png` at camx 900: the BOG post's "DRAINED"
   line ran under the MENU button). Basin post labels have a fixed world
   position but the camera follows the player, so at some framings the
   label group can land under the HUD's top or bottom bar. Added
   `_keep_basin_labels_clear_of_hud()`, run every `_process`: it reads the
   live `Viewport.canvas_transform` (world → the project's logical 640x360
   viewport, resolution-independent under `stretch/mode="canvas_items"`),
   and if the basin label group's screen-space top/bottom would land inside
   the top 33px or bottom 31px of that 360-tall space (Wes's "66px / 62px
   at 720p", halved), shifts all three lines together by exactly enough to
   clear it. Verified two ways: `hud_clear_900.png` / `hud_clear_1300.png`
   (normal framing, BOG/SWAMP posts sit well clear, matching the pre-fix
   captures — no regression) and `hud_clear_zoom.png` (`camx 4550 --zoom
   2.2`, deliberately pushing "THE ATLANTIC" post toward the bottom edge)
   showing it held clear of the bottom bar instead of sliding under it.

## What is still old / out of scope here

- Nothing left in signage's own scope. All five "done when" items (wooden
  billboards, name posts, float text, SELL label, cave mouths) are built and
  wired, and all seven of Wes's round-2 notes are addressed.
- Cave interior art, the HUD, critters, and general night lighting are other
  tracks. Cave name planks (`_build_cave_mouths`) were not in scope of
  Wes's night-legibility note (only "billboards and posts") and are still
  dim at night — flagging in case that's wanted later.
- Dusk (`--tod 0.62`) blows the billboard out white in a full-screen sun
  bloom when the sun sits directly behind it — pre-existing lighting/bloom
  behavior (present before this round too), not something this track
  controls.

## Notes for the integrator

- `game_world.gd` diff is switch-only as required: one `const V3_SIGNAGE`,
  one instantiation block next to `skin`, and `if V3_SIGNAGE: return` /
  `if not V3_SIGNAGE:` guards around the four old builders
  (`_build_swamp_labels`, the two inline "SELL" Label blocks in
  `_build_shop`/`_build_east_tower`, `_build_billboards`). Unchanged this
  round.
- **`scripts/player/player.gd` was touched** (not this track's file) — one
  call site only (`_on_scoop` / the gallons-float-text block), swapped for a
  `get_tree().get_first_node_in_group("signage")` lookup + call to the new
  `signage.spawn_gal_float()`, with the old inline-Label code kept as a
  fallback when signage isn't present. No gallon math changed. Flagging for
  the player track to review; happy to move the routing helper if they'd
  rather own the call site differently.
- Props track: the camel (or whatever prop parks near the hardware store)
  stands in front of the SELL stake at world x≈24, permanently in this save
  state (not just passing through). Not fixed here — positions/AI are
  props' file; worth a look from that track before ship.
- `sign_stake_l.png` reuses the `sign-post.jpg` Gemini source at a different
  bake size rather than spending a Gemini call; flagging in case another
  track wants a visually distinct long-stake asset later.
- Gemini budget used across both rounds: 0 (all baked from existing
  `assets/gen/*` sources).
- If any other track re-bakes an existing `assets/art/drainsville/*.png` a
  second time at a different size, delete its stale `.png.import` first (or
  run `godot --headless --import`) — see bug note in fix #1 above.
- `signage.gd` now exposes one public method other tracks can call:
  `spawn_gal_float(parent: Node2D, amount: float, local_pos := Vector2(-14, -48))`
  — pixel-styled floating gallons text, formatted, skips zero amounts.
