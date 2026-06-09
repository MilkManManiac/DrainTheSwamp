# Dev Notes — what's worked well (Godot 4.6, Drain The Swamp)

Living record of the workflow and Godot techniques that have proven effective on this project. Updated 2026-06-08 after the visual-overhaul + town + cave sessions.

---

## Workflow that worked

### Screenshot-driven visual iteration (the big one)
The game is 100% procedural, so the only way to judge a change is to *see* it. We added an **env-gated screenshot hook** that saves the rendered viewport to a PNG, which the agent can then read back. This made tight visual iteration possible.

- `DTS_SHOT=<abs path>` — game saves `get_viewport().get_texture().get_image().save_png(path)` on a timer. Inert when unset (no effect on shipped builds).
- `DTS_SHOT_INTERVAL=<sec>` — capture cadence (default 2.0; use ~0.15–0.4 to study animation/motion across frames).
- `DTS_CAMX=<x>` — teleport/park the player at a world X (in `player.gd`) so any spot on the map can be framed.
- `DTS_ZOOM=<z>` — override camera zoom (>1 in, <1 out) to inspect detail or fit a whole area.
- `DTS_TOD=<0..1>` — force time-of-day to check day/dawn/dusk/night lighting; also **freezes day progression** so news popups don't fire during captures.
- `DTS_DRAIN=<0..1>` — force the heal/drain level to preview the murky→golden grade at both ends.
- `DTS_FREEZE=1` — hold the current scene (blocks `SceneManager.transition_to_return` + cave auto-exit) so scenes that would auto-transition stay put for screenshots.

These live in both `game_world.gd` (`_setup_debug_shot`, the `_process` overrides) and `cave_base.gd` (`_setup_debug_shot`). All are no-ops unless the env var is set.

**Hard-won rule:** keep gameplay-affecting debug behavior on a SEPARATE flag from the screenshot flag. We originally gated cave-exit/transition blocking on `DTS_SHOT`, then handed the user a `DTS_SHOT` build to *play* — which trapped them in caves. Split it: `DTS_SHOT` = capture only; `DTS_FREEZE` = the scene-hold guard. **Hand the user flag-free builds to play.**

### Verify-before-show loop
1. Make the edit.
2. **Headless boot** to catch parse/script errors fast: `godot --headless --audio-driver Dummy --path . res://scenes/main.tscn --quit-after 120` and grep stderr for `SCRIPT ERROR|Parse Error|nonexistent`. (Headless uses the dummy renderer — no `RenderingDevice` — so HDR/glow code paths skip; it validates logic, not rendering.)
3. **Windowed launch with `DTS_SHOT`** to capture and eyeball the actual rendered frame.
4. Multi-location captures (`DTS_CAMX`) to check the whole map, not just spawn.

### Other habits that paid off
- **Mute with `--audio-driver Dummy`** on every launch (no audio in the background while iterating).
- **Commit per round** with descriptive messages; small, revertible units.
- **Revert fast** with `git checkout HEAD -- <file>` when a change looks wrong, instead of guess-patching (did this for the failed post-grade glaze and the rejected fronds — cheaper than debugging a bad direction).
- **Run a cave/sub-scene directly** (`godot res://scenes/caves/<x>.tscn`) — works because each cave sets its data in `_init()`. Watch for autoloads + auto-transitions (cave exit) interfering.
- **Ask the user the load-bearing fork early** (renderer choice, art direction) before building down a path.

---

## Godot 4.6 techniques that worked

### HDR 2D glow (the premium look)
- **Forward+ desktop / GL-Compatibility web** two-preset renderer (`rendering_method` + `.web`/`.mobile` overrides). Forward+ is the only renderer with real HDR-2D glow; web can't have it (shader-faked bloom fallback there).
- Enable HDR-2D via the **project setting** `rendering/viewport/hdr_2d=true` (a runtime `get_viewport().use_hdr_2d = true` alone was NOT enough — set it at boot).
- Add a `WorldEnvironment` with `Environment` glow (`glow_enabled`, `glow_blend_mode = SCREEN`, `glow_hdr_threshold = 1.0` so only overbright pixels bloom — avoids the "everything glows" gotcha).
- Gate the WorldEnvironment on `RenderingServer.get_rendering_device() != null` (true on Forward+/Mobile, false on GL-compat/headless).
- **Push hero elements overbright (>1.0)** so they bloom: an `_emit(color, boost)` helper returns `color*boost` when HDR is on, pass-through otherwise. Used on sun/moon/lantern/god-rays/water sparkle/crystals/cave pools.

### Polygon2D gotchas
- **UVs are NOT passed to a canvas_item shader unless the Polygon2D has a `texture`** (godot#81627). This silently broke the foliage wind-sway (UV.y was 0 everywhere → whole blade floated). Fix: attach a shared **1×1 white `ImageTexture`** to any Polygon2D using a UV-reading shader. (See `[[godot-polygon2d-uv-needs-texture]]` memory.)
- **`vertex_colors` DO work without a texture** — use them for free per-vertex gradient shading (dark base → light tip on grass; light→shade on walls/roofs). This is the cheapest way to make flat procedural shapes look painterly.

### Lighting / procedural art
- **`PointLight2D.texture_scale` dominates how much a light illuminates.** Tiny values (0.2–0.3) barely light anything — the caves looked near-black until we bumped crystal lights to 0.6–1.0.
- Soft round glows: a `Sprite2D` with a radial white→transparent `GradientTexture2D`, additive blend, overbright modulate → blooms into a soft orb (used for sun/moon, lamp flames, string-light bulbs). Avoids hard-edged octagon/disc look.
- Full-screen post-FX: one top `CanvasLayer` + `ColorRect` with a `hint_screen_texture` shader. **Watch uniform names** — the caves had `bloom_strength` (a non-existent uniform; the shader uses `bloom_intensity/threshold/radius`), so cave bloom silently never worked until fixed.
- `CanvasModulate` sets the scene's ambient floor; lifting it from near-black made caves readable.

### Resolution / scaling
- `canvas_items` stretch + **Linear** default texture filter for HD non-pixel-art 2D. Keeping the 640×360 logical base was fine — canvas_items renders shaders at native window resolution, so a base bump wasn't needed.

### World/terrain editing
- The overworld `terrain_points` array is index-referenced by pool ranges — when widening the terrain, **keep the point count the same** (replace, don't insert) so pool indices don't shift.
- The player `Camera2D` has hard `limit_left/right` in `player.tscn` — extending the walkable world means moving the wall (in `game_world.gd`) AND the camera limit together.
