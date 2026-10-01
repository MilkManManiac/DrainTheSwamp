# Drain The Swamp

A 2D incremental game made in Godot 4.6.3. You scoop water out of swamps, sell it, buy better tools, and slowly find out who is paying you.

This file is the handoff: where the project stands, what was mid-flight, and what is left. Last updated 2026-10-01.

## Run it

1. Install Godot **4.6.3 stable** (the version matters; 4.4 will not open the project cleanly).
2. Open `project.godot` in the editor and press Play. The first open takes a minute while it imports the art.
3. From a terminal, the first run after a fresh clone needs an import or you get a wall of "Failed loading resource" errors:
   `godot --headless --import`

Checks to run before you push anything:

```
python tools/capture.py --out x.png --check
godot --headless --audio-driver Dummy --fixed-fps 60 -s tests/terrain_walkable.gd
godot --headless --audio-driver Dummy --fixed-fps 60 -s tests/economy_invariants.gd
```

`--check` prints one known line, `ERROR: Parameter "t" is null.` That one is old and harmless so far (see the to-do list). Anything else is new.

**Pushing to `master` republishes the live game at squii.me** (`.github/workflows/deploy-web.yml`), unless the newest commit message contains `[skip ci]`. As of 2026-10-01 the live site is still the old pre-pixel-art build; the pixel-art build has not been published. Work on your own branch and open a pull request; Wes wants to see what a change does before it goes in.

## Where things stand

In September 2026 the whole game was reskinned from procedural shapes (coloured rectangles and polygons) to pixel art. The gameplay, save data, story text and economy were not touched; only what the pixels are made of.

- **Round 1 (2026-09-10):** sky, treeline, ground, the town of Drainsville, the player character. Notes: `docs/plans/visual-direction-pick-2026-09-10.md`.
- **Round 2 (2026-09-11):** eight tracks, all merged: water, signage, props (pumps, camels), critters and night lighting, HUD and shop and menu, all ten caves, title screen, player tools and scoop animation. Plan, rules and a blow-by-blow log: `docs/plans/pixel-art-revamp-2026-09-11.md`. One report per track: `docs/plans/revamp-tracks/`.
- **2026-09-12:** two fixes after a play: the walk animation froze on bumpy ground, and cave entrance mounds were drawn four times too big.

Each old draw routine is still in the code, switched off by a `V3_<TRACK>` constant in `scripts/world/game_world.gd` (or `scripts/caves/cave_base.gd`). The new art lives in its own modules: `scripts/world/{skin,town,water_skin,signage,props,critters,night}.gd`, `scripts/caves/cave_skin.gd`, `scripts/ui/pixel_ui.gd`, `scripts/player/player_skin.gd`.

## What we were in the middle of

**Signage round 4, unfinished, not merged.** It sits on branch `v3/signage` (commit `8309a59`). It fixes two real defects that are still in this build:

- basin name posts overlap the billboards (the MARSH post over the LOBBYTON board near x 900; the SWAMP post and lamp over the bottom of SWAMP ACRES)
- billboards glow orange at dusk as if lit from inside

But it added two of its own, which is why it was not merged:

- the Swamp "0.0% DRAINED" sign sits half behind the cave mound (camera x 1300 to 1500). The mounds were shrunk the next day, so this may already be gone; nobody has re-checked.
- the Lake "500.0K / 500.0K GAL" text overflows its panel (camera x 1900)

To finish: merge `master` into `v3/signage`, re-capture those camera positions at day, dusk and night, fix what is still wrong, then merge back.

**Wes playing the build.** The revamp was wrapped on purpose ("we are kinda focused on nothing right now") so that the next work comes from him playing it, not from more pixel-hunting. That play-through has only partly happened. His reactions outrank everything in the list below.

## Still to do

Graphics:

1. Finish signage round 4 (above).
2. End-game visuals are still the old procedural shapes: the island house, the politicians, the helicopter, the ending-choice dialog. Left alone deliberately because those scenes may change with the story. Do not reskin them without asking Wes.
3. Night: pumps are hard to see after dark. Lamp positions were a first pass and were never tuned next to the props.
4. Caves: each cave has a signature set-piece about 62% of the way across. None of them has been looked at in a capture. Cave water is a flat three-band shader, not authored pixel water.
5. Frog and turtle sprites were never individually confirmed on screen. Crickets are still the old coloured squares.
6. Credits: the art packs need a credit line in-game (CraftPix is OGA-BY, Admurin is CC-BY). Licences are in `assets/art/LICENSES.md`.
7. The `Parameter "t" is null` error on boot. It predates the revamp and nobody has traced it.

Housekeeping:

8. Old branches on GitHub (`v3/water`, `v3/hud`, and so on) are all merged and can be deleted, except `v3/signage`. `v2-2d-polish` and `v2-3d-overhaul` are shelved experiments.
9. Bigger plans that are parked, not dead: `docs/plans/2d-steam-roadmap.md`, `docs/plans/story-rework.md`, `docs/plans/full-audit-2026-07.md`.

## The art pipeline (and the imagegen part)

The rule: **art packs for anything repeated or animated, generated pictures for one-offs** (a backdrop, one building, one prop). Everything, from either source, goes through the bake step so it lands on the same pixel grid and palette as the town.

1. **Generate.** `python tools/gen.py "<prompt>" --out assets/gen --name <thing>` asks Gemini for one picture. **This only works on Wes's computer.** It drives a Chrome window signed in to his Google plan through a separate tool at `C:\Users\weshu\CodeProjects\imagegen\`, which is not in this repo and holds his login. It uses no API key and cannot spend money, and caps itself at 70 images a day. Gemini cannot make transparent images, so sprites are asked for on a flat magenta background and keyed out in the bake.
   - The prompt wording that keeps the look consistent is rule 6 in `docs/plans/pixel-art-revamp-2026-09-11.md`.
   - Known gap: `--hires` (Gemini's 2x download) crashes Chrome and is parked.
   - If you are not on Wes's machine, make the source picture any way you like, drop it in `assets/gen/`, and carry on from step 2. Every source picture used so far is already in `assets/gen/`.
2. **Bake.** `python tools/bake/bake.py sprite|sheet|plate|tile SRC DST --height H ...` removes the background, trims, scales to the art grid (1 art pixel = 1 world unit = 2 screen pixels at 720p), cuts to 32 colours and saves at 2x with hard edges. The other scripts in `tools/bake/` are one-purpose helpers (UI kit, props, title, scoop frames, night pixels, a seam probe).
3. **Capture and judge.** `python tools/capture.py --out shot.png --camx 900 --tod 0.3` launches the game, saves a frame and prints script errors. `--tod 0.3` is day, `0.62` dusk, `0.85` night. Hold the result next to the town: same pixel density, same outline weight, same saturation. If it does not sit next to the town, it is not done.

House rules for art, short version: no smooth fonts in the world (Silkscreen at size 8 or 16 only), no rectangles or polygons standing in as art, no identical sprites in a row, no emoji. Full list in the round 2 plan.
