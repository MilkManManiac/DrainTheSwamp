# 2.5D Voxel Overhaul — "A Game About Digging A Hole" vibe

## Goal

Replace the flat 2D primitive look with a **chunky low-poly / voxel 3D world** rendered
through an angled orthographic camera, while keeping the existing side-on gameplay,
all 10 pools, the shop, caves, economy, day/night, and story endgame **fully intact**.

This is a **reskin of the rendering + scene layer only**. Game logic is untouched.

## What we keep vs. rebuild

| Layer | File(s) | Action |
|-------|---------|--------|
| Economy / progression / save | `game_manager.gd`, `save_manager.gd` | **Keep as-is** (pure data + signals) |
| Scene transitions, newspapers, popups | `scene_manager.gd` | **Keep** (CanvasLayer UI, dimension-agnostic) |
| HUD, shop, menu | `scripts/ui/*`, `scenes/ui/*` | **Keep** (Control nodes draw over the 3D viewport) |
| Touch controls | `touch_controls.gd` | **Keep** (input only) |
| Title screen | `title_screen.*` | Light reskin (optional, later phase) |
| **Overworld rendering** | `game_world.gd` (6,481 lines), `game_world.tscn` | **Rebuild in 3D** |
| **Player** | `player.gd`, `player.tscn` | **Rebuild as CharacterBody3D** |
| **Caves** | `cave_base.gd` + 10 cave scripts/scenes | **Rebuild in 3D** (Phase 5) |

The contract between logic and rendering is a small, known set of signals/calls:
`water_level_changed`, `scoop_performed`, `swamp_completed`, `cave_unlocked`,
`camel_changed`, `day_changed`; and on the player side `set_near_water()`,
`set_near_shop()`, `set_near_cave_entrance()`, `set_near_cave_pool()`,
`try_scoop()`, `shop_requested`, `cave_entrance_requested`. We preserve these
exactly so nothing downstream breaks.

## Rendering constraints (web PWA)

- **Renderer must stay GL Compatibility** (`project.godot` already set) so web export works.
- Available: `DirectionalLight3D` + shadows, `WorldEnvironment` fog, vertex colors,
  unshaded/baked materials, custom spatial shaders (with care).
- NOT available on web/compat: SSAO, SDFGI, real-time GI, screen-space glow/SSR.
- **Strategy:** bake the cozy mood into geometry + color. Fake AO by darkening
  vertex colors in crevices and at the base of walls; one warm key light with shadows;
  soft distance fog tinted by time-of-day; a deliberately limited, warm palette.
- 3D-on-web via WebGL2 is viable at this scale (low poly count, few lights). We must
  keep the on-screen mesh/light budget conservative and test web export early (Phase 0).

## Coordinate model

The current world is a 1D horizontal profile: `terrain_points: Array[Vector2]`
where `x` = world position (≈0..5760) and `y` = surface height (≈118..604, down = +y).
`SWAMP_RANGES` indexes into it to mark each pool's entry/exit.

In 3D we map:
- **X** (world) → 3D **X** (unchanged, scaled down ~1/16 so 1 voxel ≈ 1 unit).
- surface height `y` → 3D **+Y up** (negated: higher terrain = larger Y).
- a new **Z depth axis** (~6–10 voxels deep) the terrain is extruded along, giving the
  world thickness so the dig face and pool basins read as 3D volumes.
- Player movement stays constrained to a single Z plane (the "rail") — free X, gravity Y,
  Z locked. Camera looks down the world at a fixed 3/4 angle.

`terrain_points` stays the single source of truth for terrain shape, pool placement,
collision, and proximity zones — we just consume it to build meshes instead of polygons.

## Camera

- `Camera3D` with `projection = ORTHOGONAL`, fixed pitch (~25–35°) and slight yaw,
  size tuned so the visible slice ≈ current 640×360 framing.
- Follows the player on X (and clamps to world bounds) exactly like the current 2D camera.
- Screen shake (already used in `player.gd` via camera offset) ports to `Camera3D.h_offset`/
  position offset.

---

## Phases

### Phase 0 — Spike / de-risk (½ day)
Prove the risky parts before committing:
1. Switch a throwaway scene to a `Node3D` root with ortho `Camera3D`, one `DirectionalLight3D`
   with shadows, `WorldEnvironment` fog.
2. Build ONE extruded terrain chunk mesh from a slice of `terrain_points` (e.g. the Puddle).
3. **Export to web and confirm it runs** in-browser at acceptable FPS. This is the
   single biggest risk; validate it first.
4. Confirm GL Compatibility shadow quality is acceptable; if not, fall back to baked
   vertex-color fake shadows.

**Exit criteria:** a chunky 3D terrain slab renders in the browser with a sun + shadow + fog.

### Phase 1 — Terrain mesh from `terrain_points`
- New `scripts/world/terrain_builder.gd`: consumes `terrain_points` + `SWAMP_RANGES`,
  produces an extruded `ArrayMesh` (or `SurfaceTool`) with flat-shaded faces and
  per-vertex color (grass on top, dirt strata down the face, darker at the base for fake AO).
- Voxel/blocky aesthetic: quantize the surface profile into stepped blocks rather than a
  smooth ramp, so it reads as stacked cubes (the AGADH look). Keep step size tunable.
- Generate `StaticBody3D` + `CollisionShape3D` (trimesh or stacked box shapes) from the
  same profile so the player walks on it.
- Pool basins, ridges between pools, shop shore, and the island all come out of the
  existing point data automatically.

### Phase 2 — Water in 3D
- Each pool = a translucent water volume (a box/extruded mesh filling the basin up to the
  current fill line). Height driven by `GameManager.get_swamp_fill_fraction(i)` and updated
  on `water_level_changed` — same signal as today.
- Per-pool color/turbidity carried over from existing `SWAMP_WATER_COLORS` /
  `POOL_SHADER_PARAMS` tables (reuse the data, feed a 3D water spatial shader).
- Lightweight vertex-wave spatial shader + a scrolling normal/again-fake spec highlight,
  GL-compat friendly. Surface foam line at the waterline.
- As a pool drains, the water box shrinks → the 3D basin bed is revealed (replaces the
  2D "drained pool bed" system).

### Phase 3 — Player in 3D
- `player.gd` → `CharacterBody3D`, Z locked to the rail plane, gravity on Y, X from
  `move_left`/`move_right` (same input map). Movement speed still reads
  `GameManager.get_movement_speed_multiplier()`.
- Visual: a chunky voxel character (boxes for body/limbs/boots) replacing the ColorRect
  stack — keep the existing walk-bob / squash-stretch / scoop-arm animation logic, retargeted
  to 3D node transforms.
- Tools become small voxel meshes (the existing per-tool shapes in `_update_tool_visual`
  map almost 1:1 to little box assemblies).
- Splash/dust/drip particles → `GPUParticles3D`/`CPUParticles3D` (GL-compat: CPU particles).
- Lantern → `OmniLight3D` (replaces `PointLight2D`); reuse flicker logic.
- Keep all proximity/scoop/auto-scoop/hose input handling **unchanged** in structure.

### Phase 4 — Atmosphere & life (port the good systems)
Re-create the systems that actually add charm, as 3D equivalents, conservatively:
- Day/night: drive `DirectionalLight3D` color/angle + fog color from `cycle_progress`
  (reuse the existing SKY_DAWN/DAY/DUSK/NIGHT palettes and breakpoints).
- Sky: gradient via `WorldEnvironment` sky / or a large gradient backdrop quad.
- Parallax hills/treeline → layered low-poly silhouette meshes in the distance behind fog.
- Clouds, birds, fireflies, dragonflies, fish, frogs → small billboard or voxel sprites;
  port a **curated subset** (not all 30 systems at once — pick the high-impact ones first).
- Shop building, camels, politicians, Jeff, wanted poster, cave entrances → voxel models
  placed using the existing X positions.
- Weather (rain/lightning) → CPU particles + light flash.

### Phase 5 — Caves in 3D
- `cave_base.gd` + 10 cave scenes rebuilt as 3D interiors (enclosed voxel rooms,
  crystal `OmniLight3D`s, cave pools using the Phase-2 water). Each cave keeps its
  `cave_pool_definitions`, loot, and lore hooks unchanged.
- Reuse the same player + water + particle tech from Phases 2–3.

### Phase 6 — Polish & feel
- Fake AO pass on all meshes (darken vertex colors where geometry meets/occludes).
- Screen shake, freeze-frames, completion bursts (port existing juice to 3D).
- Performance pass: mesh merging, LOD/culling for off-screen creatures, light budget.
- Title screen reskin (optional).
- Web export size/FPS pass.

---

## Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| 3D doesn't perform on web | **Phase 0 validates this first.** Keep poly/light budget low; merge static meshes. |
| GL-compat shadows look bad | Fall back to baked vertex-color fake shadows + a ground shadow-blob under entities. |
| Scope creep (30+ visual systems) | Port a curated subset in Phase 4; not everything must return. |
| `game_world.gd` is 6,481 lines | We don't edit it — we replace it with a new, smaller 3D `game_world.gd` and delete the old. Game logic untouched means low blast radius. |
| Save compatibility | Untouched — `GameManager` save format doesn't change. |

## Suggested first build step

Start with **Phase 0 spike** as a standalone scene (`scenes/_spike_3d.tscn`) so we can
prove web performance and lock the camera/lighting look before touching the real game.
Once the slice looks right and runs in-browser, proceed to Phase 1.

---

## Look-dev backlog (v2-3d-overhaul branch)

Running list of art/feel passes still to do. Done so far on this branch: RPG-map
ground-fill + back forest wall, winding N/S brown path, dense layered grass, faceted
de-bubbled trees, brown alpha-blended path edges, grass shadow-casting off (flicker fix).

### Next up — requested 2026-06-02
- [ ] **Tree variety** — some trees still read as copy-pasted. Add more per-instance
  variation (more size/shape/lean/hue jitter) and 1–2 additional canopy silhouettes so
  no two neighbours look identical. `_tree_mesh` / spawn loop in `scenery_builder.gd`.
- [ ] **Road rocks** — current stones look poor and there are too many. Improve the rock
  mesh (rounder/faceted, better color) and cut the spawn density. `build_path_detail`.
- [ ] **Brown dirt patches in base land** — scatter brown bare-earth patches through the
  green ground (not all green) so it reads more natural/realistic. `_ground_color` /
  patch logic in `terrain_builder.gd`.
- [ ] **More grass styles** — add a couple more grass blade/clump variants for variety in
  the dense cover. New `_*_mesh` builders + mix into `build_surface_props`.
- [ ] **Downed trees / stumps** — scatter fallen logs and tree stumps as ground detail.
  (Have `_log_mesh` + `_snag_mesh` — add a true stump mesh + a downed-trunk variant and
  sprinkle them along the land between pools.)

### Carried over
- [ ] **De-bubble cypress + bushes** — still use smooth `_sphere`; convert to faceted
  `_facet_blob` to match the new trees if we want consistency.
- [ ] **Perf / grass LOD** — grass is very dense over the long stretched world. If FPS
  drops, chunk grass into per-X-region MultiMeshInstances with `visibility_range` LOD.
- [ ] **POIs in extended land** — shop, cave mouths, decorative rowboat/shack in the
  longer land stretches.
- [ ] **Duckweed / moss skim on water**, bayou mist, hanging Spanish moss for vibe.
- [ ] **Higher-poly character** (currently intentional voxel box style — round if wanted).
