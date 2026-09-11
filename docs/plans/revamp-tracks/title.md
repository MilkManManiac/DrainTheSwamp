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

## Commit

`v3 title: verify resumed WIP — fresh captures (day/night/newspaper/continue), report`
