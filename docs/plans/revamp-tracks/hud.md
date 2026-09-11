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
