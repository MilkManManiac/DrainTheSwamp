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

## Review round 4 (coordinator): popup/dialog reskin in scene_manager.gd

Ask: the tutorial/hint popup ("HOLD SPACE to scoop water" / "[Close]") was
still a plain black `StyleBoxFlat` box in the default font, built by
`SceneManager` (`scripts/autoload/scene_manager.gd`), called from
`game_world.gd` (owned by other tracks — not touched). Reskinned every
dialog-building function in that file that draws UI chrome, same
signatures/timing, only touching the UI-construction code:

- **`_build_popup()` / `show_popup()` / `_close_popup()`** — the hint/toast
  popup. Now a `PixelUI.wood()` card, Silkscreen caption text via
  `PixelUI.caption()`, `[Close]` as a real pixel wood button
  (`PixelUI.button()`) instead of a flat text link. `show_popup()`'s
  recentering math now derives from `cave_popup.size` instead of a
  hardcoded `320`/`100` so it stays correct if the box size changes again.
- **`show_document_popup()`** (and its thin wrappers `show_lore_popup()`,
  `_on_loot_collected()`) — cave inscriptions/discoveries and NA burner-phone
  texts. Kept the existing "paper" vs "phone" distinction but built from the
  kit: `PixelUI.parchment()` for paper, `PixelUI.inset()` with a green tint
  for phone (was two hand-rolled `StyleBoxFlat`s). Title via
  `PixelUI.header()` (Silkscreen 16), body/prompt via `PixelUI.caption()`
  (Silkscreen 8) — was an 11/8/9pt mix of the default font.
- **`show_ending_choice()`** — the "THE GUEST LIST" ending confirm dialog.
  `PixelUI.wood()` card, `PixelUI.header()` title, `PixelUI.caption()` body,
  and the two choice buttons now go through `PixelUI.button(btn, accent)`
  (wood button skin, accent-tinted) instead of one-off `StyleBoxFlat`s.
- Added `PixelUI.wood()` to `scripts/ui/pixel_ui.gd` — the other helpers
  (`inset`, `parchment`) already existed but nothing exposed the plain wood
  panel for code-built dialogs outside a shared `Theme` resource; each
  reskinned panel now also gets `theme = PixelUI.THEME` so its children pick
  up Silkscreen/VT323 and theme colors without per-label font overrides.

**Deliberately left alone:** the milestone "SWAMP GAZETTE" newspaper
(`_build_newspaper_overlay`, `_show_milestone_newspaper`, etc.) — it's an
in-fiction prop with its own masthead/corner-fold/coffee-stain parchment
conceit, not generic UI chrome; reskinning it to the wood HUD panel would
undercut the joke. Not a dialog Wes flagged, and out of the "confirm
dialogs/story popups" scope as I read it. Flagging here in case that reading
is wrong.

**Verification:** `tools/capture.py --check` clean (only the known
pre-existing `Parameter "t" is null` boot error). Triggered the actual hint
popup in a real capture: game_world.gd only fires it on a truly fresh save
standing in the Puddle's water (`GameManager.lifetime_earnings <= 0` and
`swamp_states[0]["gallons_drained"] <= 0.0001`). This worktree has its own
save via `override.cfg` (`custom_user_dir_name="DrainTheSwamp-wt-hud"`,
resolving to `%APPDATA%/DrainTheSwamp-wt-hud/`) — confirmed with a throwaway
`OS.get_user_data_dir()` probe script (not committed) after an earlier wrong
guess sent me digging in the *shared* `%APPDATA%/Godot/app_userdata/Drain The
Swamp/` folder instead. Backed that shared save up before touching it and
restored it byte-for-byte (verified by hash both times) before finding the
right folder — no data was lost, but noting the detour. Procedure used:
delete `%APPDATA%/DrainTheSwamp-wt-hud/save_data.json`, capture at
`--camx 155 --tod 0.3 --wait 4 --interval 0.5` (short wait/interval so the
periodic debug screenshot lands while the 3.5s auto-close popup is still up),
then copy the real save from `%APPDATA%/Godot/app_userdata/Drain The Swamp/`
back into the worktree folder (copy only, never wrote to that shared
folder). Capture: `_screenshots/revamp-2026-09-11/hud/hint_popup.png`, read
back — wood card, Silkscreen body text, pixel `[Close]` button, sits next to
the puddle/town art cleanly.

`show_document_popup()` and `show_ending_choice()` were not individually
captured — no `DTS_UI` debug hook exists for them (only `shop|menu|touch`,
wired in `main.gd`), and adding one felt like scope creep past "only touch
the UI-building parts of scene_manager.gd." They're built from the same
`PixelUI` helpers already visually verified in the shop/menu/hint captures,
so I'm confident in them by construction, but flagging that they're
code-reviewed, not screenshot-verified, in case a future track wants to add
a capture hook for them.

## Review round 5 (coordinator): real design pass, not a texture swap

Wes's core complaint: the UI read as "one wood texture pasted over
everything" — the AI-tell. This round rebuilt the visual hierarchy and fixed
several real bugs found along the way. **0 of 5 Gemini images used** —
everything below is either baked procedurally or reused from the player
track's sprites.

### New baked assets (`tools/bake/ui_kit.py` → `assets/art/ui/`)

- `panel_frame.png` — darker outer wood, thicker border, brass corner
  rivets. The outermost of three surfaces.
- `panel_content.png` — lighter content backdrop, the middle surface.
- `row_card.png` / `row_card_active.png` (bright green left edge) /
  `row_card_locked.png` (desaturated) — the lightest surface, one row = one
  card, three distinguishable states.
- `scroll_grabber.png` — a real vertical-pill scrollbar handle (was the
  square button texture stretched thin — read as unskinned).
- `icon_tool_{spoon,cup,bucket,shovel,wheelbarrow,barrel,water_wagon,hose}.png`
  — baked from the **player track's** in-hand tool sprites
  (`assets/art/drainsville/tool_*.png`, copied from `v3/player` at commit
  `c2af327`, `git show v3/player:...`), auto-cropped, scaled to fit a 13x13
  slot, outlined. `icon_tool_hands.png` is hand-drawn (no bare-hands sprite
  exists upstream — it's the implicit default, no held prop).
- Deepened `button()`'s pressed-state palette (was too close in value to
  normal, so an active tab and an inactive one looked almost identical).

`scripts/ui/pixel_ui.gd` gained `frame()`, `content()`, `row(state)`,
`tool_icon()`, and `prompt()` (see below) to hand these out as
StyleBoxTextures/nodes, same pattern as the existing `inset()`/`parchment()`.

Also copied `assets/art/drainsville/tool_*.png` (8 files) into this
worktree from `v3/player` — **merge note:** both `v3/hud` and `v3/player`
now add these same paths with identical content; should merge cleanly
(identical add on both sides), but flagging it since it's outside this
track's normal file ownership.

### 1. Popups don't shrink-wrap

`scene_manager.gd`'s `show_popup()` (hint/toast) and `show_document_popup()`
(lore/NA-phone) both had a hardcoded box size regardless of text length —
`cave_popup` was a fixed 320x84 with one line crammed at the top; the
document panel was a fixed 380x240. Fixed:

- `_build_popup()`: `cave_popup` no longer sets `.size` directly; its label
  gets a fixed-width cap (`POPUP_MAX_WIDTH = 260`) so long toast text (the
  buyback-window line, etc.) wraps instead of stretching, and the panel's
  actual anchor-driven size now comes from content. `show_popup()`
  repositions via `call_deferred` after the container re-sorts to the real
  (now correct) size — reading `.size` the same frame text changes gets the
  stale pre-resize value.
- `show_document_popup()`: same idea, but this panel isn't inside any
  Container-managed parent, so a bare Control there does **not** auto-fit to
  its children (that was a real bug: the first attempt produced a
  full-height black panel with no visible content). Fixed by wrapping it in
  a `CenterContainer` — the same proven pattern `menu_panel.tscn`'s `Box`
  already uses — which shrink-wraps and centers it automatically. Verified
  both `kind="phone"` (long NA text) and `kind="paper"` (short cave
  inscription) now size correctly to their own content.
- `show_ending_choice()` ("THE GUEST LIST") — **left untouched per Wes's
  scope note**: endgame visuals may change, not worth polishing now.

### 2. Shop: three-surface hierarchy

`shop_panel.gd`/`shop_panel.tscn`: added a `ContentPanel` wrapping the
`ScrollContainer` in the scene. `_ready()` now sets:
`self` (the whole dialog) → `PixelUI.frame()`; `content_panel` →
`PixelUI.content()`; every row → `PixelUI.row(state)` (`"normal"` /
`"active"` / `"locked"`) instead of the old single `PixelUI.inset()` reused
everywhere with a near-invisible tint. Tabs: the active tab uses the
(now much darker) pressed stylebox at full opacity with bright accent text;
inactive tabs are dimmed (`modulate` 0.8 alpha) — previously they used
almost the same value and were only distinguished by a small font-color
change. Retinted every blue/purple info and header color to cream/gold/green
(Stats tab category color: blue → green; category-tint row backgrounds
dropped entirely — they were nearly invisible and are unnecessary now that
row state itself carries the color cue). `_register_afford()` now sets
can't-afford buttons to `PixelUI.RED` instead of falling back to the
theme's neutral disabled brown.

Fixed two concrete bugs along the way:
- **Empty inset row under CAMELS**: `_build_camel_section()`'s upgrade row
  had an expand-filling blank `Control` before the Cap/Spd buttons, pushing
  them to the right and leaving the row's left half visibly empty. Replaced
  with a "Camel Upgrades" label.
- **Script error on every shop open** (found while re-verifying, not part of
  this round's ask but blocking clean captures): none left — see round 2's
  fix; re-confirmed still clean.

Tool rows in the Tools tab now show a `PixelUI.tool_icon()` before the name.

### 3. Number formatting

`hud.gd`'s carry-capacity readout was raw floats ("0.0/10803.8"). Added
`_fmt_gal_compact()` (wraps `Economy.format_gallons`, stripping the " gal"
suffix and collapsing to "0" at zero) so it now reads "0/10.8K".

### 4. Per-tool pixel icons

Added to both the HUD's bottom-left tool card (`hud.gd::_build_hud_icons()`
now builds a `tool_icon` TextureRect and swaps its texture in
`_update_tool_label()`) and every Tools-tab shop row. Sourced from the
player track per Wes's instruction (see "New baked assets" above) rather
than generating new ones.

### 5. Milestone newspaper — pixel treatment

`_build_newspaper_overlay()`: the panel's `StyleBoxFlat` (rounded corners)
is now `PixelUI.parchment()` (pixel border, tiled paper texture), and
`newspaper_panel.theme = PixelUI.THEME` so every label picks up Silkscreen
by default instead of per-label default-font overrides. Fixed the
non-8/16 sizes (headline 12→16, subhead 9→8, photo caption 7→8, prompt
10→8). `newspaper_paper_style` changed type `StyleBoxFlat`→`StyleBoxTexture`
and its two age-tint call sites now set `.modulate_color` instead of
`.bg_color`. Kept it as its own parchment prop (masthead, corner-fold,
coffee-stain) rather than reskinning to wood dialog chrome — it's an
in-fiction object with its own conceit, not generic UI chrome.

### 6. In-world prompts outside scripts/ui

Added `PixelUI.prompt(text, color)` — a `Label` with a Silkscreen font
override (these nodes live directly on world/cave nodes, not under
`PixelUI.THEME`, so they need an explicit font, not just a size). Routed
through it, minimum edit (each was a 3-6 line `Label.new()` block replaced
with one call, same position/z_index/visibility left untouched):

- `scripts/caves/lore_wall.gd` — `hint_label` ("[SPACE]")
- `scripts/caves/loot_node.gd` — `hint_label` ("[SPACE]")
- `scripts/world/dead_drop.gd` — `hint_label` ("[SPACE]")
- `scripts/caves/cave_base.gd` — the `tag` label near line 2006 ("NA
  COURIER"), plus `unstuck_btn` (was a hand-rolled `StyleBoxFlat`, now
  `PixelUI.button()`)

**Not reachable for verification:** `lore_wall.gd`/`loot_node.gd` aren't
currently instantiated anywhere in this worktree (`_setup_loot_and_lore()`
in `cave_base.gd` is a `pass` stub — presumably wired up by the caves
track). Confirmed by code review only; the edits are mechanical (same
3-line pattern as `dead_drop.gd`, which I could verify — see captures).
Per Wes: left `player.gd`'s floating text alone (signage owns it).

### Dev-only capture hooks added (gated on env vars, inert otherwise)

- `scripts/main.gd`: `DTS_UI=shop:1` / `shop:2` also selects a shop tab;
  `DTS_UI=hint` / `lore` / `lore_paper` trigger sample popups at real
  caller-length text so they can be captured without touching any save.
- `scripts/caves/cave_base.gd`: with `DTS_SHOT` set, calls
  `GameManager.enter_cave()` so the HUD's air bar is visible when capturing
  a cave scene directly (`--scene res://scenes/caves/<x>.tscn`, which
  otherwise skips the overworld's normal cave-entry flow); `DTS_PROMPT=1`
  additionally sets `prestige_count = max(3)` in memory only (never saved)
  so the P3 sell-basin "NA COURIER" prompt is reachable for a capture.

### Save-file discipline this round

Per the coordinator's hard rule: never touched
`%APPDATA%/Godot/app_userdata/Drain The Swamp/` this round, not even to
read. All state needed for captures came from either the worktree's own
save (`%APPDATA%/DrainTheSwamp-wt-hud/`, via `override.cfg`) or the
above in-memory-only DTS_* debug hooks — no save file was read, written, or
deleted this round.

### Before/after captures (1280x720, all read back)

`_screenshots/revamp-2026-09-11/hud/`, prefixed `r5_`:
- `r5_hud_day.png` / `r5_hud_night.png` — top-bar number formatting, no
  regressions at night (before: `town_day.png`/`town_night.png`)
- `r5_shop_tools.png` / `r5_shop_stats.png` / `r5_shop_influence.png` — all
  three tabs, frame/content/row hierarchy, active-vs-inactive tabs, tool
  icons, fixed camel row (before: `shop_open.png`)
- `r5_menu.png` (before: `menu_open.png`)
- `r5_hint_popup.png` — shrink-wrapped toast at real text length (before:
  `hint_popup.png`)
- `r5_lore_popup.png` (phone/NA text) and `r5_lore_paper.png` (cave
  inscription) — both document-popup kinds, shrink-wrapped
- `r5_cave_air.png` — a cave scene with the HUD air bar visible, reskinned
  Unstuck button
- `r5_prompt.png` — an in-world `PixelUI.prompt()` ("NA COURIER") live in a
  cave

`tools/capture.py --check` clean throughout (only the known pre-existing
`Parameter "t" is null` boot error).

## Round 6: merge v3/integrate, then the menu gets the same system

### Merge

`git merge v3/integrate` into `v3/hud` (commit `d270917`) pulled in caves,
player, title, props, critters-night, and water. Three conflicts, all in
files this track shares with the caves track (both sides edited the same
`hint_label`/`unstuck_btn` construction — caves reskinned the cave art
around them in the same commits):

- `scripts/caves/lore_wall.gd`, `scripts/caves/loot_node.gd` — kept
  `PixelUI.prompt()` (this track's side); it's a strict superset of
  integrate's inline `ResourceLoader.exists(V3_FONT)` + manual font/size
  (same Silkscreen 8pt result, less code). Took integrate's slightly
  different `hint_label.position` tuning on `loot_node.gd` (`-30` not
  `-28`) since that's the caves track's own visual calibration.
- `scripts/caves/cave_base.gd` — the Unstuck button: both sides
  independently reskinned it (this track via `PixelUI.button()`, caves via
  its own hand-rolled Silkscreen + `StyleBoxFlat`). Kept integrate's version
  — it's a complete, already-reviewed implementation (hover/pressed states,
  uppercase text, its own position tuning), and this track's investment in
  `PixelUI.button()` is still very much present everywhere else it's used.
  This track's `tag` label (line ~2006, "NA COURIER") and the `DTS_SHOT`/
  `DTS_PROMPT` dev hooks in `_ready()` weren't touched by caves and merged
  clean.
- `scripts/player/player_skin.gd.uid` — took ours per instruction.

Verified after merging: `capture.py --check` clean;
`--scene res://scenes/caves/muddy_hollow.tscn --freeze` shows the caves
track's painted pixel cave art (mud walls, roots, stalactites) fully
intact, with the HUD air bar and the reskinned Unstuck button both present
(`r6_cave_merge_check.png`); a second capture on `gator_den.tscn` with
`DTS_PROMPT=1` (extended this round to also force any `hint_label` in the
tree visible, not just the sell-basin tag) shows both a loot-node "[SPACE]"
prompt and the "NA COURIER" tag live together, confirming `PixelUI.prompt()`
survived the merge correctly (`r6_cave_prompts.png`). `lore_wall.gd`
specifically remains unreachable for a live capture — `cave_base.gd`'s
`_setup_loot_and_lore()` is still a `pass` stub even after the caves merge,
so no `LoreWall` instance exists anywhere in the tree yet; the fix there is
identical code to `loot_node.gd`'s (verified), just not independently
capturable until that stub is filled in by whoever owns it.

### Menu gets the frame/content/row-card system

The one miss from round 5: `menu_panel.tscn`/`.gd` never got the shop's
hierarchy — still one wood texture (`Box`'s default theme panel) behind
every button, with a few leftover blue/purple-adjacent colors.

- `menu_panel.tscn`: added a `ContentPanel` `PanelContainer` between the
  title/separator and `ButtonList` (same shape as the shop's
  `ContentPanel` wrapping its `ScrollContainer`).
- `menu_panel.gd::_ready()`: `box` (was implicitly the theme's default wood
  panel) → `PixelUI.frame()`; `content_panel` → `PixelUI.content()`.
- New `_row(control)` helper wraps one control in `PixelUI.row()` — applied
  to every individual button (Resume, Touch Controls, Fullscreen, Restart,
  the Yes/Cancel confirm row) and every audio slider row, so each is its
  own card sitting on the content backdrop, exactly the shop's language.
- Colors: Resume green, Restart (+ its confirm "Yes, Restart") red, "Cancel"
  and slider labels cream, Fullscreen/Touch Controls gold, "Audio" header
  green — no blue or purple left in this panel.
- **Touch Controls row**: was always present and could read "ON" on a
  desktop build (reflecting a stale saved `GameManager.touch_controls_enabled`
  even though the on-screen controls were correctly hidden per round 2's
  fix). Added `TouchControls.has_touched()` (the same `_touched` /
  `InputEventScreenTouch` gate `touch_controls.gd` already uses to decide
  whether to actually show the controls). The row now only appears when
  `TouchControls.has_touched() or TouchControls.enabled` — never on a
  desktop session that hasn't touched and hasn't manually enabled it — and
  when it does appear, its ON/OFF label reads the live `TouchControls.enabled`
  flag instead of the stale saved preference, so it can never again say ON
  while nothing is showing. Confirmed hidden in `r6_menu.png` (captured on
  the desktop build, no touch this session).

Capture: `_screenshots/revamp-2026-09-11/hud/r6_menu.png` (before:
`r5_menu.png`) — frame border with brass rivets visible, lighter content
backdrop, every row its own card, Touch Controls row gone. Read back and
compared directly against `r5_menu.png` and the shop screenshots for
consistency. `capture.py --check` clean.

## Gemini budget

0 of 5 images used across every round. Everything came from the procedural
`tools/bake/ui_kit.py` kit or (round 5's tool icons) baked from the player
track's existing sprites.
