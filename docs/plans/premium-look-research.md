# Premium stylized look — research + implementation notes

Goal (user, 2026-06-02): make the 3D swamp look "4x better," people "shocked it's made by AI."
Three parallel research deep-dives (foliage/trees, materials/shaders, lighting/post) all
converged on one point: **poly count is NOT the lever — shading and lighting are.**

## The high-impact techniques (what actually sells "premium stylized")

1. **Inflated / spherical canopy normals** — keep the chunky faceted *silhouette* but override
   foliage-clump vertex normals toward radial-from-center (egg-shaped, squashed vertical) so
   each clump lights as one soft volume. This is the BotW/Europa trick. Implemented as the
   `soft` param on `_facet_blob` in scenery_builder.gd (0 = gem facet for rocks, ~0.7 = soft
   canopy). Used on trees, cypress, bushes.
2. **Leaf translucency / fake SSS (backlight)** — light bleeding through thin greenery. Custom
   `light()` backlight term, auto-masked to green (ALBEDO.g) so leaves/grass glow when backlit
   while trunks/rocks stay opaque. NOTE: `COLOR` is NOT available in `light()` — mask on ALBEDO.
3. **Painterly custom lighting** — half-Lambert WRAP (lifted cozy terminator) + soft AA bands
   (`smoothstep`+`fwidth`, not hard `step`) + saturation split (rich light / muted shade).
   Cool "never-black" shade comes from AMBIENT/GI, NOT folded into the key term (else cast
   shadows get fake fill and stop reading).
4. **Fresnel rim → EMISSION** — silhouette separation from the dark swamp + survives fog.
5. **AgX tonemap + re-saturate** (contrast ~1.16, saturation ~1.3). AgX preserves hue and rolls
   highlights off softly; Filmic/ACES desaturate stylized LDR colors (the old reason we used
   LINEAR — but LINEAR hard-clips highlights / looks digital). AgX+resaturate is the fix.
6. **SDFGI** — colored bounce light + crevice fill; drop flat `ambient_light_energy` to ~0.12 so
   it doesn't double-fill. **SSIL** on top for short-range contact bounce.
7. **Volumetric fog god-rays** — LOW density (0.005) + high `light_volumetric_fog_energy` (3.0)
   = shafts through the trees WITHOUT milking the frame. Heavy fog washed everything out — keep
   it subtle, keep the foreground crisp (`fog_depth_begin` ~48).
8. **Crisper shadows** — 8192 atlas (project setting) + `soft_shadow_filter_quality` 4, 2 splits,
   `shadow_blur` 1.5, tighter `directional_shadow_max_distance` 60 for the diorama.
9. **TAA** (MSAA 2x + `use_taa`) to clean soft-shadow/GI/volumetric dithering.

## Implementation (commit on v2-3d-overhaul)
- `shaders/stylized.gdshader` — NEW shared material (sway + painterly light() + backlight + rim).
  All props (`_spawn_mm`, cached by sway/roughness) + terrain now use it for a cohesive read.
  `shaders/foliage.gdshader` is now superseded (left in place, unused).
- `_facet_blob` gained the `soft` (spherical-normal) param; trees/cypress/bushes de-bubbled to
  soft volumes; rocks faceted (soft 0.12) with irregular 3-lobe silhouette.
- Modest poly bumps: canopy blob rings 3→4 + segs up; grass `_blade` segs 3→4; bush 4 clumps.
- `game_world_3d.gd::_build_environment` — full AgX/SDFGI/SSIL/volumetric/shadow/SSAO overhaul.
- `project.godot` — shadow atlas 8192, soft shadow + SSAO + SSIL quality.

## Tuning levers if the user wants changes
- Trees feel bubbly → lower the `soft` (0.7) on canopy `_facet_blob` calls toward 0.4–0.5 to
  bring facet edges back.
- Too hazy → `volumetric_fog_density` / `fog_depth_begin`. Too washed → `adjustment_saturation`
  / `adjustment_contrast`. God-rays weak/strong → `sun.light_volumetric_fog_energy`.
- Debug flags: `--nofog` (kills depth+volumetric+god-ray), `--nogi` (SDFGI off), `--noglow`.
- FULL research writeups (shader snippets, exact param tables) are in the session transcript.

## Still NOT done (poly/detail backlog continues)
- Procedural normal detail (bark/rock noise normals), triplanar terrain texturing, wet-surface
  sheen on mud/waterline, custom LUT color grade, DoF tilt-shift, vignette+grain — all researched,
  deferred. See the lighting/material research in the transcript for snippets.
