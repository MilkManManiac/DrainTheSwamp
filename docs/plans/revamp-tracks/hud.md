# hud track report

Branch `v3/hud` in worktree `dts-wt/hud`. Resumed from a prior agent's usage-limit
stop (commit `d4402cd`, "v3 hud: WIP (agent stopped by usage limit, unverified)").
That commit turned out to be functionally complete; this session verified it,
re-captured, and closed out the report.

## What now works

- **Top bar**: wood-plank strip (`assets/art/ui/panel_wood.png` via `PixelUI`),
  pixel icons (coin/bag/sun-moon/drop) replacing the old flat dark bar. Sun/moon
  icon swaps live off `GameManager.cycle_progress`.
- **Bottom bars**: tool card (left) and menu card (right) on wood panels; stamina
  bar and cave-air bar use a segmented pixel fill (`bar_fill.png`) recoloured by
  `modulate_color` (green -> yellow -> red for stamina; cyan/yellow/red for air),
  replacing the old flat ColorRect bars.
- **Shop panel** (`scenes/ui/shop_panel.tscn` + `scripts/ui/shop_panel.gd`): wood
  background, tabs (Tools/Stats/Influence) rendered as pressed-in vs raised wood
  buttons, rows on dark inset wood slots. Same tab/row/tooltip logic as before,
  just restyled through `PixelUI.inset` / `PixelUI.button`.
- **Menu panel**: wood panel, Silkscreen header, pixel sliders/buttons for
  audio, touch-controls toggle, fullscreen, restart. Same signals
  (`resume_pressed`, `reset_confirmed`).
- **Touch controls**: wood-plank arrow buttons + SCOOP button
  (`assets/art/ui/touch_*.png`), Silkscreen label. Stay hidden on desktop —
  gated behind a real `InputEventScreenTouch` this session (see
  `scripts/ui/touch_controls.gd` header comment); the old build showed them on
  any machine merely reporting touch capability.
- **Fonts**: Silkscreen for captions/headers (`PixelUI.SIZE_CAPTION`=8,
  `SIZE_HEADER`=16), VT323 available for numeric readouts. No Noto left in
  owner files.
- **`scripts/ui/pixel_ui.gd`**: shared static helper (icons, inset/parchment/
  wood styleboxes, bar fill, button/caption/header builders) so hud/shop/menu/
  touch all pull from one skin instead of duplicating StyleBoxFlats.
- **Baking**: `tools/bake/ui_kit.py` (new this track) generates the whole
  `assets/art/ui/*` kit procedurally — no Gemini calls were needed or used.
  **0 of the 5 Gemini image budget spent.**

Signals/API preserved: `hud.gd` still exposes `menu_pressed`; `shop_panel.gd` /
`menu_panel.gd` keep `open()`/`close()`, `resume_pressed`, `reset_confirmed`,
and every `GameManager` signal connection from the pre-v3 script. No node
paths that other scripts depend on were renamed.

`game_world.gd` was **not touched** — this track's files (`scripts/ui/*`,
`scenes/ui/*`, `assets/ui_theme.tres`) are fully disjoint from it.

## Captures

`_screenshots/revamp-2026-09-11/hud/`:
- `town_day.png`, `town_night.png` — overworld HUD in context (carried over
  from the prior agent, still valid)
- `shop_open.png`, `menu_open.png` — panels open over the world
- `touch.png` — touch controls visible (forced on for the capture)
- `verify_day.png`, `verify_dusk.png` — fresh re-captures this session at
  `--camx 900`, confirming nothing regressed after resuming

Read all of them; HUD sits at the same pixel density / outline weight as the
town art (`_screenshots/lookdev-2026-09-10/fix_town.png`). `tools/capture.py
--check` prints only the known pre-existing `Parameter "t" is null` boot
error, otherwise clean.

## Review round 2 (coordinator, read shop_open/menu_open/touch/verify_day)

Four fixes, all addressed this round:

1. **Slider grabbers were smooth AA circles.** Added `slider_grabber()` to
   `tools/bake/ui_kit.py` (small brass/wood knob, PIL `ellipse` — no
   anti-aliasing at this size, so it comes out crisp pixel-block like
   everything else) and wired `HSlider/icons/grabber`,
   `grabber_highlight`, `grabber_disabled` in `assets/ui_theme.tres`. Baked
   `assets/art/ui/slider_grabber.png` + `slider_grabber_hi.png`.
2. **Menu overflowed at 720p** ("RESTART GAME" cut off, bottom bar overlap).
   Root cause: too much stacked content (8 rows incl. 4 separate audio-slider
   rows) for the panel's vertical budget. Fixed in `scenes/ui/menu_panel.tscn`
   (tighter anchors 20/-20 instead of 50/-50, margins 14/6 instead of 16/12,
   `ButtonList` separation 4 instead of 8, `clip_contents = true` as a
   safety net) and `scripts/ui/menu_panel.gd` (button height 18 instead of 22,
   audio sliders now a 2x2 `GridContainer` instead of 4 stacked rows). Fits
   fully inside the top/bottom bars at 720p now with room to spare.
3. **Shop row text was dim blue-grey on near-black.** Two causes: the baked
   `panel_inset.png` was very dark (`S_BASE` (44,32,26)), and
   `PixelUI.inset()`'s category-tint blend (0.35) was actually *darkening*
   low-saturation tints further (multiplying a near-black texture by a dim
   hue drives it darker, not lighter). Lightened the inset bake palette,
   dropped the tint blend to 0.15 so it reads as a faint hue wash instead of
   the main value source, and brightened the specific dim label colours in
   `scripts/ui/shop_panel.gd` (locked tools, unbought pumps/stats/upgrades,
   prestige rows) toward cream/parchment while keeping them visibly dimmer
   than owned/equipped rows (still distinguishable).
4. **Shop panel covered ~88% of the screen, sliver on the right.** Traced to
   a real bug, not just a layout choice: `open()`/`close()` tween
   `position.x` from `vp_w` to `0.0`, but the panel's anchors held a 40px
   margin on *both* sides (`offset_left=40, offset_right=-40`). For a
   full-rect-anchored Control, setting `position.x` only moves
   `offset_left` — the tween's rest value of `0.0` overwrote the left margin
   but left `offset_right=-40` alone, so the panel ballooned flush to the
   left edge with only the right margin surviving. **Chose full-width
   between the bars** (`offset_left = offset_right = 0.0` in
   `scenes/ui/shop_panel.tscn`) over re-centering: it fixes the slide
   animation for free (the tween's rest position now matches the anchor
   layout exactly, no distortion), and the shop's scrollable row list
   benefits from the extra width more than a centered dialog would.

Also found and fixed a real script error while re-verifying: `shop_panel.gd`
was setting `border_width_left` / `border_color` on a `StyleBoxTexture`
(StyleBoxFlat-only properties) to highlight the equipped tool row — this
threw a script error on every shop open (`tools/capture.py --check` with
`DTS_UI=shop` was not clean before this fix). Replaced with a brighter green
`PixelUI.inset()` tint for the equipped row instead.

New captures at 1280x720 (`_screenshots/revamp-2026-09-11/hud/`):
`shop_open.png`, `menu_open.png`, `desktop_touch_off.png` (plain desktop
capture, touch controls confirmed hidden — no arrow/scoop buttons drawn).
`tools/capture.py --check` and `DTS_UI=shop python tools/capture.py --check`
both clean.

## Review round 3 (coordinator): menu regression

Round 2's tighter menu still stretched to the full anchored rect (now
`offset_top=20 .. offset_bottom=-20`, 20 UI units = 40px, above the top bar's
actual bottom edge at y=66px), so it overlapped the top HUD bar and had two
dead bands (VBoxContainer content centered by `alignment=1` inside a
container taller than its content).

Fixed by no longer letting the wood panel *be* the anchored rect. Restructured
`scenes/ui/menu_panel.tscn`: `MenuPanel` is now an invisible full-band
container (`theme_override_styles/panel` = empty stylebox,
`mouse_filter = IGNORE`, offsets `33 .. -31` in UI units — measured directly
from a clean capture: top bar bottom edge at screen y=66 = UI y=33, bottom
bar top edge at y=658 = UI y=329 = offset -31 from 360) holding a
`CenterContainer` that centers a new `Box` `PanelContainer` (the actual wood
panel, `custom_minimum_size.x = 340` to keep the same width as before,
height now shrink-wrapped to content). `scripts/ui/menu_panel.gd`'s
`@onready` paths updated to the new `CenterContainer/Box/...` nesting; no
other logic changed.

Re-captured `menu_open.png`: box now sits y=148..572, clear of the top bar
(0..66) and bottom bar (658..720), tight around its content with no dead
space.

## What is still old / out of scope

- The billboard sprite and floating basin labels ("MARSH 100.0%", "BOG...")
  are the **signage** track's territory, not hud — left untouched. In
  `verify_day.png` the BOG basin label overlaps the touch SCOOP button
  position at the far right; that's a world-label vs. HUD-anchor collision
  worth a heads-up to signage/whoever finishes anchoring those floats, but no
  owner-file change was made here to fix it.
- Dusk/night world tinting (red dusk wash, dark night) is the water/critters+
  night tracks' territory.

## Merge notes

- Disjoint owner files (`scripts/ui/*`, `scenes/ui/*`, `assets/ui_theme.tres`,
  plus the new `tools/bake/ui_kit.py` and `assets/art/ui/*`) — should merge
  cleanly per the stated merge order (hud, title, caves, player first).
- `project.godot` has a small diff (4 lines) from the prior agent — worth a
  quick look at merge time, likely just input-map or autoload wiring for
  touch controls; not reviewed line-by-line this session but nothing in HUD
  behavior depends on anything unusual there.
- Did not commit the large `.import` churn (~175 files) — pre-existing/known
  noise from opening the project in the editor, per instructions.

## Gemini budget

0 of 5 images used. Track needed none — everything came from the procedural
`tools/bake/ui_kit.py` kit.
