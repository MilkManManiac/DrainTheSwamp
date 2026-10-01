# Track 7: title

Status: **done** (resumed from a prior agent's usage-limit stop; verified this session, nothing new generated).

## What changed

`scripts/title_screen.gd` was already fully rewritten by the previous (stopped) agent to build the
title procedurally from baked pixel-art plates instead of the old vector/ColorRect draw:

- Gemini key-art plate (Drainsville at dusk — town buildings, water tower, string lights, tree
  silhouettes) split by `tools/bake/bake_title.py` into a static `key_sky` / `key_sky_night`
  band-sky pair and a keyed `key_fg` foreground layer, baked to the game's pixel grid
  (`tools/bake/bake.py`, x2 NEAREST, quantized palette).
- Slow dusk -> night -> dusk crossfade (`NIGHT_CYCLE = 70s`) via alpha-blending `key_sky_night`
  over `key_sky`, a moon fade-in, 34 seeded twinkling stars, ~dozen warm string-light bulbs
  auto-detected from the plate's own warm pixels, and 9 drifting fireflies — all through the
  same HDR-2D glow recipe `game_world._setup_hdr_glow` uses, so bloom matches the overworld.
  Whole-pixel horizontal drift on the foreground layer against the fixed sky/stars/moon.
- Baked pixel wordmark (`assets/art/title/logo.png`) replacing the old Label-based title text.
- Wooden 9-slice Silkscreen menu (`btn_normal/hover/pressed/disabled.png`) — same button texts,
  same colors-per-action, same layout math as before, only the styleboxes are new.
  `panel_paper.png` gives the newspaper intro panel a matching baked-paper texture instead of a
  flat ColorRect.
- Same post-process shader pass (`shaders/post_process.gdshader`) as the game world, tuned softer
  (vignette 0.28, grain 0.02, no scanlines/CA/shimmer) so the plate reads as painted, not overlaid.
- `DTS_SHOT` / `DTS_SHOT_INTERVAL` capture hook added directly to `title_screen.gd` (mirrors the
  game world's), plus a `DTS_TITLE_AUTO=continue|newspaper|night` debug driver for scripted
  captures without touching save data.
- All gameplay wiring untouched: `NEW GAME` / `CONTINUE` / `QUIT` / dev-only `TEST ENDGAME`,
  the existing-save confirm dialog, and the two-page newspaper intro all fire the exact same
  signals into `SceneManager` / `SaveManager` / `GameManager` as before. Newspaper story text
  is byte-for-byte the original copy.

`scenes/title_screen.tscn` is untouched (single Node2D + script attach — it was already this
thin, nothing to reskin at the scene-tree level).

## Assets generated / baked

- Gemini plates already in `assets/gen/`: `title-key-a.jpg`, `title-key-b.jpg` (from the prior
  agent's run — key art was the only Gemini call this track needed).
- Baked outputs via `tools/bake/bake_title.py` + `tools/bake/bake.py`, committed under
  `assets/art/title/`: `key_sky.png`, `key_sky_night.png`, `key_fg.png`, `logo.png`,
  `btn_normal/hover/pressed/disabled.png`, `panel_paper.png`.
- **This session's Gemini budget (1 image) was not used** — the existing key art already reads
  as finished and matches the town lookdev reference, so nothing new was generated.

## Verification this session

- `python tools/capture.py --out ... --scene res://scenes/title_screen.tscn --check` ->
  `[capture] headless boot clean` (no script errors, no parse errors).
  (Note: `--check` against the *default* scene, `res://scenes/main.tscn`, prints
  `ERROR: Parameter "t" is null.` — that is pre-existing/unrelated to this track, reproduces
  with no title-track code involved; not touched, out of scope.)
- Fresh windowed captures taken and read back this session (previous agent's captures were
  unverified; these are new, in `_screenshots/revamp-2026-09-11/title/`):
  - `v_menu_day.png` — default boot state (dusk sky, mid-crossfade), menu + key art.
  - `v_menu_night.png` (`DTS_TITLE_AUTO=night`) — forced full-night crossfade: moon up, stars
    lit, bulbs flickering, foreground dimmed/cooled correctly.
  - `v_newspaper.png` (`DTS_TITLE_AUTO=newspaper`) — intro paper renders on the baked panel
    texture, masthead/rule/body all Silkscreen, unchanged copy.
  - `v_continue.png` (`DTS_TITLE_AUTO=continue`) — CONTINUE correctly loads the existing save
    and transitions into `scenes/main.tscn` (game world shown mid-playthrough, Day 11, drained
    puddle, correct HUD) — confirms `SceneManager`/`SaveManager`/`GameManager` wiring survived
    the reskin.
  - Prior agent's captures (`title_a.png`, `title_b.png`, `title_newspaper.png`,
    `title_route_continue.png`) also read back clean and match; kept alongside.
- Compared against `_screenshots/lookdev-2026-09-10/fix_town.png`: same pixel density, same
  dark outline weight, same saturated dusk palette. Sits next to the town without clashing.
- Buttons verified functionally (not just visually): NEW GAME -> newspaper -> main.tscn,
  CONTINUE -> main.tscn with save loaded, QUIT calls `get_tree().quit()` (unchanged), TEST
  ENDGAME unchanged (debug-build only).

## Still old / out of scope

- Nothing in this track's own files (`scripts/title_screen.gd`, `scenes/title_screen.tscn`) is
  left on the old draw path.
- The `main.tscn` headless-check error noted above is outside this track's owned files; flagging
  for whichever track/owner covers `game_world.gd` boot.
- `assets/gen/char-a-walk2.jpg.import` / `char-a-walk3.jpg.import` showed up in the prior
  agent's commit (import-only, no source .jpg change) — belongs to the player track, not
  touched further here.

## Notes for other tracks / merge

- Disjoint files only (`scripts/title_screen.gd`, `scenes/title_screen.tscn`,
  `assets/art/title/*`, `tools/bake/bake_title.py`); no edits to `game_world.gd` or any shared
  file. Should merge cleanly per the plan's stated order (hud, title, caves, player).
- `.import` churn (~175 files) is from running the local Godot import pass in this worktree;
  not re-touched or reverted, per instructions.

## Round 2: coordinator review fixes (2026-09-11)

Coordinator read `v_menu_day.png` and `v_newspaper.png` and flagged three issues. All three
fixed and re-verified with fresh captures:

1. **"TEST ENDGAME" on the shipping title screen.** Checked the pre-revamp `title_screen.gd`
   (`git show 1335ea3:scripts/title_screen.gd`) — it already gated the button behind
   `if OS.is_debug_build():`, and the rewritten version has the *identical* gate
   (`scripts/title_screen.gd:244`). No code change needed; it only appears in our captures
   because every capture runs the debug console executable, where `is_debug_build()` is always
   true (same as it always was). It will not appear in a release export template.
2. **Newspaper panel artifacts + logo peeking.**
   - Root cause of the band/stray-corner-lines, found by isolating it (hid every child of
     `newspaper_panel`, including all text, and the artifact was still there): `panel_paper.png`
     (the 12x12 source for the panel's `StyleBoxTexture`) had a deliberate but too-subtle
     directional bevel — a lighter row near the top, a darker row near the bottom-right, on an
     otherwise-flat fill — and stretching that over a ~460x236 box did not read as a bevel, it
     read as a three-band artifact plus corner seams where the top/right and bottom/left 9-slice
     edges met. Rebuilt `assets/art/title/panel_paper.png` as one flat parchment tone with only
     the outer 1px border differing (no internal gradient at all) — now nothing survives the
     stretch to band. Forced a reimport (`godot --headless --import`) so Godot picked up the new
     PNG bytes.
   - Logo: `logo.visible = false` added in `_show_newspaper()` (`scripts/title_screen.gd`) — the
     wordmark sits above the panel's top edge by design (title screen), so it's now hidden
     outright while the paper is up rather than partially clipped.
3. **`[PRESS ANY KEY]` contrast.** Two changes: the label's font color moved from a
   mid-brown/orange (`Color(0.55, 0.32, 0.12)`) to a dark ink (`Color(0.22, 0.15, 0.08)`), and
   the blink's alpha range was tightened from `0.5 + 0.5*sin(...)` (0 -> 1, fully transparent at
   its dimmest — that's what made the old color look "cream on cream" at the bottom of the
   cycle) to `0.65 + 0.35*sin(...)` (0.30 -> 1.0), so it still blinks gently but never washes out
   to invisible.

Re-captured and read back after the fixes:
- `v_menu_day.png` — unaffected by the panel fix (menu buttons use a separate stylebox), TEST
  ENDGAME confirmed still present only because this is a debug-build capture (see point 1).
- `v_newspaper.png` — one clean flat parchment sheet, no band, no corner seams, logo fully
  hidden, "[PRESS ANY KEY]" reads as dark ink at every point in the blink (checked with several
  capture timings against the sine cycle to confirm it never approaches invisible).
- `tools/capture.py --check` against `scenes/title_screen.tscn` re-run after the fixes: still
  `[capture] headless boot clean`.

## Commit

`v3 title: verify resumed WIP — fresh captures (day/night/newspaper/continue), report`
`v3 title: fix newspaper panel banding/corner seams, hide logo under paper, dark-ink press-any-key`
