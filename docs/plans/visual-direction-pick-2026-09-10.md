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
