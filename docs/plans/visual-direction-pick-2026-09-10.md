# Visual direction pick — 2026-09-10

**Status: waiting on Wes to pick A, B, or C.** Do not run another grade/lighting pass on the procedural build.

## Why this exists
Fourth "complete visual overhaul" request. Every previous pass (R1–R4 Jun 3, high-res Jun 8, town/caves Jun 8, audit Phase 1 Jul 7) kept the same procedural primitives (Polygon2D boxes, Line2D, gradients) and only re-lit them. Diagnosis: the June 8 "stay 100% procedural" decision is the local minimum. The heal grade is a full-frame post-process and works on painted pixels just as well.

Decision this time: change what the pixels are made of, keep every system/shader/the heal/the writing. Reskin, not rewrite. Build on a quarantined branch without reading the old draw functions.

## The three candidates (same screen: town strip, real HUD overlaid)
Files in `_screenshots/lookdev-2026-09-10/`:
- `A_painted.png` — SDXL base (no LoRA), painterly, seed 555 of `A_painted_candidates.png`. Prompt/gen script: session scratchpad `gen/gen.py`.
- `B_pixel.png` — kitbash of free packs (licenses in `B_pack_licenses.md`; CC0 Gothicvania town/swamp, OGA-BY CraftPix swamp, CC-BY Admurin dock layers). Houses hue-shifted to wood; water tower built from a scaled barrel. Alt: `B_pixel_generated_alt.png` (pixel-art-xl LoRA, sparser).
- `C_ink.png` — SDXL base, ink-outline gouache storybook, seed 555 of `C_ink_candidates.png`.

All three are single flat plates with a PIL bloom/vignette/grain comp, NOT layered for parallax yet. Whichever wins must be cut into the 8-band layer stack (see `high-res-2d-overhaul.md` Pillar 3 / ArtGen `research/scene-composition-layering.md`) before it goes in-engine.

## After the pick
1. New branch `v3-<style>-art`. Do not open `game_world.gd` draw functions; work from the picked plate + this doc.
2. Rebuild the town strip in-engine as layered sprites with the existing post-process/glow/heal grade on top. One screen, screenshotted, before anything else.
3. Then pools, then caves, in the same language.
4. HUD needs a matching pass — the Silkscreen pixel HUD fights A and C.

Tooling: ComfyUI server per `ArtGen/comfy/README.md` (port 8188, our own venv, not the Desktop app). Packs live in the session scratchpad `packs/` — copy into `assets/` once a pixel direction is picked.

## 2026-09-10 later — B picked, first in-engine screen done
Wes: *"I mean B def looks the best."* Branch **`v3-pixel-art`** (off v2-2d-polish @ 97a6a9b).

Done: `scripts/world/town.gd` rewritten as sprites (same API; `game_world.gd` untouched). Pack art copied to `assets/art/` (+ `LICENSES.md`); recolored/assembled sprites baked to `assets/art/drainsville/` by a PIL script (houses hue-shifted to wood and lifted ×1.45 so they read in daylight; water tower = barrel ×3 on drawn legs; swamp trees keyed from their black bg). Sprites at world scale 0.5 = 1:1 screen px at 720p, nearest filter on the town node. Captures: `_screenshots/lookdev-2026-09-10/ingame_town_{day,night}.png`.

Known gaps, in order:
1. **Player is ~10 world units tall vs 90-unit houses** (the yellow eyes at the pawn door). Needs a real player sprite ~20 units and the interaction/scoop positions checked. Biggest remaining "pasted-in" tell.
2. **Ground/terrain** is still the procedural dirt slab (40% of frame). Next: tiled ground (Gothicvania swamp tileset / CraftPix) + camera framing lower so the dirt is ~25%.
3. **Signs** are unreadable at font size 5; plate not centered on text. Bake sign text into the sprite or use a larger plate.
4. Sky/sun/moon are still procedural (white disc). Replace with a pixel sky gradient + sun sprite; keep the heal grade.
5. Night: lamp point-lights work; string bulbs are white dots, want warm + bloom. House windows should glow (bake an emissive window overlay).
6. Then pools area and caves in the same language. Do NOT re-tune the old procedural draws anywhere.

## 2026-09-10 later still — Gemini imagegen joined the pipeline; whole overworld skinned

Wes proposed the new `imagegen` skill (Gemini web, free) for assets. Split agreed and then used:
- **Gemini for single flattened pictures**: sky (day / dusk / night, three-way crossfade driven off the old sky gradient's mid colour), ground cross-section texture, one bayou shack (`shack_a`, west end of the town, style 3). Sources kept in `assets/gen/`, bakes in `assets/art/drainsville/`. Bake script lives in the session scratchpad (`bake/bake_gen.py`); the recipe is: crop, LANCZOS to 2-screen-px art grid, quantize, key magenta/white, `x2 NEAREST`.
- **Packs for anything that repeats**: CraftPix trees/willows/bushes/stones/tufts along the banks (`skin.gd::_build_vegetation`, seeded).

New module `scripts/world/skin.gd` (created next to `town` in `game_world._ready`, builds deferred): painted skies + fill, pixel sun/moon riding the old nodes' positions (their orbs hidden, lights kept), far pines in `treeline_layer` (two rows) + cypress silhouette band in `near_hills_layer`, textured ground polygon + depth shade + surface strip tiles, dark mud beds under every basin, murk overlay polygons that copy each `water_polygons[i].polygon` per frame (z 4, alpha 0.7), bank vegetation.

`game_world.gd` changes are switches only: `const V3_SKIN := true` skips `_build_clouds/_distant_hills/_treeline/_terrain_details/_vegetation/_tree_trunks/_mud_patches/_mushrooms/_ferns/_left_trees/_cypresses`. Camera offset in `player.tscn` -55 → -38 (ground sits lower in frame).

Town fixes: buildings/props now z ≤ -1 so the player (z 0) is in front (he was hidden behind z 3 sprites — the "ten-pixel eyes" was a z-order bug, not a size bug); baked sign textures (`sign_<name>.png`, Silkscreen 8px, `building()` prefers them); additive window-glow rects per house (`WINDOWS` table, texture px) lit by `update_glow`; warm string bulbs.

Captures: `_screenshots/lookdev-2026-09-10/v3b_*.png` (town day/dusk/night, pools x3, stacks).

**Still old / next:**
1. Billboards: pink `ColorRect` + smooth font (`_build_billboards`) — reskin to a wooden pixel board with Silkscreen; they are story content so keep the text system.
2. Water: shader sparkle/foam layers still read as noise; needs an authored pixel-water pass (animated tile strip) rather than more tint.
3. Island house / politicians / cave entrances / camels / pumps / east tower — procedural props still in place.
4. Caves scene untouched.
5. Player: current ColorRect figure reads fine at 2x; revisit only if Wes calls it.
6. Credits screen line for CraftPix (OGA-BY) and Admurin (CC-BY) — Admurin not used in-engine yet; CraftPix is.

## 2026-09-10 night — Wes's first reaction + two fixes

Wes: "Massive improvement overall." Two notes, both fixed:
1. **Console spam** `Lambda capture at index 0 was freed` every frame after dismissing the tutorial popup. Pre-existing bug in `scene_manager._wait_for_lore_dismiss`: a `process_frame` lambda captured the popup layer and was never disconnected after the layer was freed. Fixed by keeping the callable in `frame_ref` and disconnecting it in the dismiss callback before `queue_free`. Never showed in captures because `DTS_SHOT` suppresses the tutorial.
2. **Trees hovering downhill.** Pines and cypress band were viewport-anchored parallax rows (fixed screen y), so when the terrain drops east of town they floated as a shelf. `skin.gd::_build_treeline` now builds them in world space on a smoothed terrain line (`_smooth_y`, ±160 units, 9 taps): a `Polygon2D` forest mass under each row (`_band_fill`) down past any dip, sprite tiles rotated to the local slope (`_band_row`, bottom-left pivot). Cypress row sits 12 under the ground line at z -4, pines 36 / 14 above at z -5. The 0.6x parallax on the treeline is gone; sky still parallaxes. Captures: `fix_hill1/2.png`, `fix_town.png`.

## 2026-09-10 night — player character candidates

Three Gemini sprite sheets (idle row + walk row on magenta), baked by `bake/bake_char.py` in the session scratchpad into `assets/art/drainsville/player_{a,b,c}_{idle,walk}.png` (40 art px tall, x2 NEAREST, one 28-colour palette per character). Sources in `assets/gen/char-sheet-*.{png,jpg}`.
- A: bearded swamp guy, brown hat, red shirt, blue overalls (matches Wes's June 3D concept `Downloads/swamp_character.png`). 5 idle / 7 walk frames.
- B: young guy, green trucker cap, grey tee, overalls. 4 / 8.
- C: middle-aged woman, red bandana, olive shirt, waders. 6 / 7.

`scripts/player/player_skin.gd` (hooked with 3 lines at the end of `player._ready`): hides every ColorRect under Visual except Shadow, hides ToolSprite, adds a Sprite2D strip under Visual so the old bob / lean / flip / flash still apply; swaps idle/walk strip off `player.is_walking`. Env `DTS_CHAR=a|b|c` picks the variant for captures; `DEFAULT_CHAR` in the script is the shipped one. Frame counts live in `FRAMES`.

Captures: `char_a/b/c.png`, `char_zoom.png` (3-up), `char_stack.png`.

Open after the pick: per-tool sprite in the hand (sheets all draw a bucket; the ColorRect tools are hidden), scoop animation (still the old arm tween on a hidden node — add a 2-frame scoop strip), lantern still ColorRects.
