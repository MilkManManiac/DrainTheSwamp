# Visual Overhaul — Research Synthesis & Plan (2026-06-03)

Goal: make Drain The Swamp look *dramatically* better — "wow, this was made by AI?" — across overworld + caves. Based on 4 parallel research agents (water, atmosphere/background, foliage/ground, lighting/post-fx). Engine: Godot 4.6, **GL Compatibility**, 640×360 logical w/ `canvas_items` stretch, fully **procedural** (Polygon2D/ColorRect/Line2D/GradientTexture2D — NOT sprites).

## Signature look (the unifying art direction)
**"Limited-palette, ramp-lit, gently dithered painterly bayou at golden/blue hour — that visibly heals from murky-green to clear as you drain it."**
- Palette discipline + ordered (Bayer) dither = the "intentional/premium" fingerprint.
- Ramp lighting + dusk rim/shadows = form on flat polygons.
- The **atmosphere IS the progress bar**: one `drain_progress` (0→1) lerps sky, fog, god-rays, saturation, foliage tint/density from sickly-green murk → clear golden.
- Reference looks: Ori, Hollow Knight, Gris, Eastward, Sea of Stars, Dome Keeper (palette+dither), Rayman (vector canopies).

## Renderer decision
**Stay on `gl_compatibility` for now** (keeps the web demo working; everything below is achievable in canvas_item shaders). Forward+ would only add true **HDR 2D glow/bloom** (Forward+/Mobile only) — a real but optional upgrade for the Steam build later, requiring a gl_compat fallback preset. Revisit after the core overhaul lands. Skip per-pixel 2D normal maps (buggy in gl_compat); get fake relief from ramp lighting + LightOccluder2D + dither instead.

## Don'ts (verified constraints)
- **No GPUParticles2D** — renders nothing on GL Compatibility (no compute). Use CPUParticles2D, cap ~200–500.
- Don't hand-author a LUT (we're iterating blind) — do grade/dither/bloom in-shader instead.
- Water: `hint_depth_texture` is Forward+ only — fake depth via the known surface line + UV.y (we have better depth info than a depth buffer anyway).

---

## Universal foundation (lifts everything at once)
1. **post_process.gdshader upgrades**: wider single-pass threshold bloom (current is a 4-tap cross — too small); subtle ordered **Bayer dither + posterize** (`levels`~12-16) so gradients become an intentional stipple; keep vignette/CA/grain/night. Pipeline order: bloom add → posterize+dither → grade → CA → grain → vignette.
2. **Atmospheric-perspective parallax**: retint distant layers — lighten + desaturate + blue-shift toward sky color (helper `_atmospheric_tint(base, depth, atmo)`). Current distant layers are over-saturated green = the #1 "flat" tell.
3. **God-ray / light-shaft band**: additive `canvas_item` shader (procedural noise rays) on a ColorRect behind the treeline; `strength` driven by time-of-day (peak dawn/dusk) + drain murk.
4. **Foreground silhouette layer** (`motion_scale` > 1.0): big soft dark fronds/branches at screen edges that pass faster than the world — frames every shot (Hollow Knight/Ori trick).
5. **Animated fbm fog** (canvas_item): two bands — low ground-mist over water (rising swamp gas) + high atmospheric haze; color/density lerp with drain_progress.
6. **"Heal" master lerp**: wire sky ramps + fog + god-ray + saturation/warmth + ambient-particle counts to `drain_progress`.

## Water (hero surface) — water.gdshader rewrite
Order of impact: (1) add `world_pos` varying + **surface-only Gerstner** displacement (gate by `smoothstep(0.18,0,UV.y)` so the basin floor stays anchored — current shader displaces all verts and can tear the pool from its bank); (2) **Beer-Lambert depth tint** with murky bayou palette (olive→bottle-green-black, reflection-dominated NOT transparent-blue); (3) **screen-space refraction** via a `BackBufferCopy` node placed under the water + `hint_screen_texture` UV distortion (short-range, dies with turbidity); (4) warm **reflection rim** at the waterline (sky_color = warm canopy, not blue); (5) drifting **foam line**; (6) warm sparkle.
- **Receding waterline (core mechanic, highest ROI)**: wet/dark saturated mud band revealed as water drops (terrain-shader uniforms `high_water_y`/`cur_water_y`/`wet_fade` that darkens+saturates the freshly-exposed band, decaying as it "dries"); a **foam tide-line that lags then drops**; **drips** spawned on fast level drops.
- **Interactive ripples Tier 1** (recommended): GDScript array of {pos,t,amp} → shader uniform arrays; expanding decaying sin rings added to vertex displacement + surface glint; spawn on scoop. (Tier 2 = ping-pong SubViewport heightmap — works in gl_compat but defer.)

## Foliage / ground / terrain — lush bayou
1. **Wind-sway vertex shader** (`foliage_sway.gdshader`, canvas_item): pivot-anchored (base still, tip max via `1.0-UV.y`), world-X gust phase so one gust rolls across the whole field, per-instance `phase_jitter`. Biggest "alive" lever. (Convert Line2D grass to thin tapered Polygon2D quads so the vertex shader has geometry to bend.)
2. **Gradient/3-tone faceting**: use `Polygon2D.vertex_colors` (free per-vertex gradient, dark base→light tip) on grass/ferns/canopy; optional ramp shader for richer control + rim.
3. **Density + per-instance variation**: 3-5× foliage count, vary scale 0.7-1.4 / rotation ±12° / hue across 2-3 green stops + occasional dead-yellow; **cluster via noise** (dense patches + bare); split into back/front `z_index` depth bands (back darker/cooler/smaller).
4. **Ground** (terrain.gdshader): multi-octave FBM mottling + vertical depth-darkening + **contact AO** (dark soft band under grass line and under every prop base) + ordered dither at soil transitions + overhanging grass fringe to break the hard surface Line2D.
5. **Trees as hero assets (stay procedural, "up the pixels" via higher-vertex Polygon2D)**: tapered trunk + 2-3 forking branches + 4-8 overlapping clustered canopy blobs (vertex-color dark-bottom→light-top, back→front depth) + rim cluster; **cypress** (tall trunk + knees in water + hanging **Spanish moss** Line2D strands on the sway shader, high strength/low stiffness); bushes. Place cypress at pool edges.

## Cave consistency (already reworked once — extend with the new stack)
Bring dither + the new water shader + foliage techniques into caves too for consistency; tune the existing post-process overlay alongside the overworld one.

---

## Round plan (sequenced; each round → boot-verify → commit → relaunch → user judges → tune)
- **R1 — Atmosphere + Post-FX foundation**: post_process dither+bloom; parallax atmospheric retint; god-ray band; foreground silhouette layer; fbm fog; heal-lerp wiring. *(biggest overall lift)*
- **R2 — Water**: full water.gdshader rewrite + BackBufferCopy refraction + receding-waterline wet band/foam/drips + Tier-1 ripples.
- **R3 — Foliage + Ground + Trees**: sway shader; vertex-color faceting; density/variation; terrain FBM/depth/AO; cypress/moss/bush rebuild.
- **R4 — Cave consistency + asset-fidelity polish + tuning pass.**
- Later/optional: Forward+ HDR-glow Steam build w/ gl_compat web fallback; hand-authored day/night LUTs; Tier-2 ping-pong water; AI-generated texture seeds (concept-only — prompt output isn't copyrightable; disclose on Steam).

## Key sources
godotshaders.com (god-rays, 2D fog overlay, 2D water distortion/reflection, ripple, bayer-dithering, stylized grass, 2D wind sway); Godot docs (2D parallax, 2D lights & shadows, screen-reading shaders/BackBufferCopy, custom post-processing, HDR-2D PR #80215, HDR in 4.7); Art of Hollow Knight; aerial-perspective theory; Cyanilux rain breakdown. (Full URLs in the agent transcripts / chat history.)
