# High-Res 2D Overhaul — Plan & Research Synthesis (2026-06-08)

> **Direction decision (2026-06-08, user-confirmed):**
> 1. **Painterly-procedural HD** — keep the 100% procedural pipeline (the real-time reactive "heal" is the competitive moat hand-painted games can't match); push fidelity via higher resolution, HDR glow, depth-graded layers, and a disciplined color system. *Not* a hand-painted/AI-asset replacement of the procedural draws.
> 2. **Two-preset renderer** — desktop Steam build on **Forward+** (true HDR glow/bloom + full 2D lighting); web demo stays on **GL Compatibility** with a shader-faked-bloom fallback.
>
> Supersedes nothing; extends the completed procedural R1–R3 (`visual-overhaul-research.md`). Engine: Godot 4.6.

Synthesized from a 4-agent research fan-out (codebase audit, art-direction, asset-pipeline, Godot HD-2D tech). Sources at bottom.

---

## Why this direction (the load-bearing finding)

Ori and the Will of the Wisps hand-painted **~30,000 lightmaps across ~7,000 assets** to get reactive painterly lighting — the art director called it "not good for the artist soul." A solo/small team can't and shouldn't. **Our reactive, code-driven world (murky→golden as you drain) is something hand-painted games physically cannot do in real time.** So we keep everything procedural and spend effort on the levers that actually read as "premium" — none of which require authored art:

- Higher resolution + linear filtering + glow (kills the "low-res/flat" tell)
- Layered depth with **atmospheric perspective** (the #1 depth cue, currently missing)
- **Value-first color discipline** (grisaille→glaze) — the heal becomes a luxurious continuous grade
- Detail density + per-instance variation (kills the "uniform/procedural" tell)
- Constant ambient motion + a global post pass with grain (kills the "sterile/AI" tell)

## Signature look (north star)

**"A value-structured painterly bayou at golden hour that visibly heals — murky sickly-green murk → clear warm gold — rendered crisp at HD with overbright HDR glow and deep atmospheric layering."**

Builds on the existing R1–R3 art direction (limited palette, ramp lighting, dither, the heal-as-progress-bar) and raises its ceiling.

---

## Architecture: the four pillars

### Pillar 1 — Renderer & resolution foundation (enables everything)

**Two export presets** (Godot has no single-build runtime renderer switch — set per export preset):
- **Desktop:** `rendering_method = forward_plus`, enable Viewport **`use_hdr_2d`**, a `WorldEnvironment` with **glow** (4.6 default blend is now *screen*, blends before tonemapping → convincing bloom). This is the premium look.
- **Web:** `rendering_method.web = gl_compatibility`. Engine glow is unavailable here (#66455) → keep a shader-faked single-pass bloom (current `post_process.gdshader` path) as the documented fallback. GPUParticles2D don't render on web — web stays on CPUParticles2D.

**Resolution.** Keep **`canvas_items`** stretch (already correct for non-pixel-art HD; it re-renders 2D at native window resolution). Two changes + one spike:
- Switch default texture filter **Nearest → Linear** (matters for the sky GradientTexture2D, noise textures, god-rays). Per-CanvasItem override anything that must stay crisp.
- Support true fullscreen at 1080p/1440p/4K (canvas_items scales content automatically; window override is just the default size).
- **SPIKE (must verify in engine, do first):** Decide the logical **base resolution**. Option A — *keep 640×360 base* and rely on canvas_items rendering shaders/gradients at native window res (gradients are already per-fragment-smooth at the physical resolution; "blockiness" is mostly coarse geometry + thin lines + nearest filtering, all fixable without a coordinate refactor). Option B — *raise base to 1280×720 or 1920×1080* if gradient banding / geometry coarseness still reads after Option A; this requires scaling all authored world coordinates (the `terrain_points` array `game_world.gd:11-227`, creature px sizes, `Line2D.width` values ~3×) and re-tuning parallax `motion_scale`. **Recommended: try Option A first** — it captures most of the win at a fraction of the risk. Only escalate to B if 1080p-fullscreen-with-linear-filtering still looks coarse.

*Migration gotchas (from tech research):* disable any pixel-snap meant for the 640×360 era (jitter on smooth motion); line widths tuned to 640×360 go hairline at HD (scale ~3× if base changes); shaders hardcoding pixel sizes/blur radii must derive from `SCREEN_PIXEL_SIZE`; `canvas_items` edge-clear bug (#71799) — verify the web build has no garbage edges; VRAM-compressed "high quality" textures don't render on web (#95721) — web uses Lossless/Basis.

### Pillar 2 — Grisaille → glaze color system (the heal, done premium)

The single highest-value art technique, and a perfect match for a code-driven palette shift (it's literally how old masters handled value-vs-color):
- **Author value/structure in monochrome (grisaille underlayer):** all procedural geometry/noise defines *where it's light/dark, near/far, lit/shadowed* — independent of hue. Audit current draws to ensure tonal hierarchy reads in grayscale (clear darkest-dark + brightest-bright).
- **Drive color as a "glaze" keyed to one `swamp_health` (0→1):** a single grade/LUT-style lerp in `post_process.gdshader` moves the whole frame from the **murk palette** (desaturated yellow-green, muddy browns, compressed midtones, green-tinted fog) → **healed palette** (clear water, warm golden key, disciplined saturated greens, thin bright fog). Because value is locked underneath, the color shift never breaks readability.
- This consolidates the ~10 existing scattered `drain_progress` lerps (`game_world.gd:6064-6186`) under one coherent grade philosophy. Preserve every existing hook; unify their *targets* into the murk/healed palette pair.
- **Make the transition the feature:** continuous 0→1, watched in real time — the thing hand-painted games can't do.

### Pillar 3 — 8-layer depth + atmospheric perspective (the #1 "flat" fix)

Restructure the scene back-to-front into depth bands, each **lit and graded differently**:
1. Sky / far backdrop — hazed, desaturated, blue/teal-shifted
2. Atmospheric fog band — density/color/height driven by `swamp_health`
3. Far parallax silhouettes (treeline, distant cypress) — low-contrast, hazed, slow scroll
4. Midground water plane — the hero shader (reflections, caustics, ripples; scum→clarity by health)
5. Mid foliage (reeds/lilies) — sway shader; density & color by health
6. **Near foreground silhouettes — dark, rim-lit, sharp, fast parallax** (INSIDE/Limbo depth anchor; frames every shot)
7. Ambient particle systems — motes/fireflies/insects/pollen; type & density by health
8. Global post pass — grade + glow + vignette + **fine grain** (grain defeats the flat-digital tell)

**Atmospheric perspective** (highest-leverage single move, currently absent): distant layers get slight blur + desaturation + tint toward the haze color. The current over-saturated green distant layers are the biggest "flat" tell. Helper `_atmospheric_tint(base, depth, atmo)`, strength scaling with `swamp_health` (sicker = hazier).

### Pillar 4 — Lighting, detail density & "premium tells"

- **HDR glow (desktop):** make overbright pixels (sun, fireflies, glow-plants, waterline sparkle, god-rays) push >1.0 so WorldEnvironment glow blooms them correctly. This is the biggest single "premium" upgrade Forward+ unlocks.
- **Commit to one key light:** a low warm bayou sun + cool shadows; rim lights and cast shadows agree with it. Warm-light/cool-shadow temperature split throughout.
- **Detail density + per-instance variation:** 3–5× foliage; vary scale 0.7–1.4 / rotation ±12° / hue across 2–3 green stops + occasional dead-yellow; cluster via noise (dense patches + bare). Uniform foliage is a key amateur tell.
- **Soft edges + grain + constant ambient motion** everywhere — the trio that separates "premium" from "procedural/AI."

---

## Performance & must-fix

- **De-node-ify the dither:** the per-pixel ColorRect dither in `_build_terrain()` (~1,200–6,000 nodes, `game_world.gd:1078-1089`) is the #1 bottleneck and is *redundant* — `terrain.gdshader` already has `bayer4()`. Delete the ColorRect dither, rely on shader dither. **Do this before any res work.**
- **Particles:** desktop Forward+ may use GPUParticles2D; **web must stay CPUParticles2D** (don't render on GL-compat/web, #96030 — supply `COLOR=texture(TEXTURE,UV)` if the default-shader bug still bites 4.6).
- **2D lights:** cap shadow-casters; `SHADOW_FILTER_NONE` cheapest. 2D MSAA/FXAA unavailable on GL-compat — rely on linear filtering (+ mipmaps if anything zooms/downscales) for AA.
- **Post-FX:** one full-screen CanvasLayer+ColorRect with `hint_screen_texture` = one back-buffer copy (cheap). Keep web's faked-bloom blur at limited taps / half-res.

---

## Round plan (sequenced; each round → boot-verify → commit → relaunch → user judges → tune)

- **R0 — Foundation & spike. ✅ DONE 2026-06-08.** Two-preset renderer set (Forward+ desktop confirmed running on RTX 4060 Ti / Vulkan 1.4.325; `.web`+`.mobile` pinned gl_compat). Linear filtering on. Redundant per-pixel ColorRect dither deleted from `_build_terrain()`. **Resolution spike → Option A locked:** keep 640×360 base — canvas_items native-res rendering + linear is crisp enough, no coordinate rescale needed. (Still TODO when web build is next exported: verify edges/CPUParticles on the gl_compat web preset.)
- **R1 — HDR glow + lighting (desktop).** `use_hdr_2d` + WorldEnvironment glow; push hero elements overbright; one warm key light + cool shadows; web faked-bloom parity pass. *(Biggest single visible jump on desktop.)*
- **R2 — Grisaille→glaze color system.** Audit value hierarchy; unify the heal under one murk↔healed palette grade in post-process; re-point existing `drain_progress` lerps. *(The signature, made premium.)*
- **R3 — Depth + atmospheric perspective.** 8-layer restructure; `_atmospheric_tint` on distant layers; near foreground silhouette band; fog band tuning. *(The #1 "flat" fix.)*
- **R4 — Detail density + ambient life + grain.** 3–5× foliage with per-instance variation + noise clustering; constant ambient motion; fine grain; soft-edge audit. *(Kills the procedural/AI tells.)*
- **R5 — Cave consistency + tuning.** Bring the stack into caves; final grade/glow/perf tuning pass; profile node counts on min-spec + in-browser.

## Tooling & skills

- **`godot` skill** — headless boot-verify, export both presets, tests after each round.
- **`algorithmic-art`** (p5.js) — *if* we ever want copyright-clean noise/mask/tiling texture seeds for shaders (procedural-friendly; optional, not core to this procedural-HD direction).
- **`theme-factory`** — lock the murk/healed palette pair as a single source of truth for the grade.
- **`verify` / `code-review`** — per-round validation.
- Authored-asset tools (FLUX/SDXL/Material Maker/Krita) are **out of scope** for this direction but documented in `2d-steam-roadmap.md` tooling table if the hybrid option is ever revisited.

## Must-verify-in-engine checklist

1. Resolution spike: does Option A (keep 640×360 base) look HD-crisp at 1080p fullscreen + linear, or do we need Option B (base bump + coordinate rescale)?
2. HDR-2D + WorldEnvironment glow blooms overbright sprites on Forward+ desktop (4.6).
3. Web faked-bloom is visually acceptable vs desktop HDR glow.
4. Two-preset renderer override actually applies in *exported* builds (not just editor).
5. CPUParticles2D render on the web export.
6. `canvas_items` edge-clear bug (#71799) absent on web build.
7. 1080p post-FX + light cost on min-spec and in-browser.

## Key sources

- **Tech:** Godot multiple-resolutions, custom-post-processing, web-export, Light2D, renderers docs; HDR-2D PR #80215 (4.2, Forward+/Mobile only); 4.6 glow notes; GL-compat tracker #66458; web particles #96030; VRAM-web #95721.
- **Art direction:** Ori 30k-lightmaps (thegamer/wccftech); Hollow Knight / INSIDE / Journey atmosphere breakdowns (room8studio, medium); Gris + grisaille/glazing (watercoloracademy); Sea of Stars hybrid pipeline (megavisions); parallax/atmospheric-perspective theory.
- **Pipeline (out-of-scope reference):** Scenario/FLUX/LayerDiffuse/Material Maker 1.5; Steam AI disclosure (Jan 2026 rewrite); US Copyright Office Part 2.
- Full URLs in the agent transcripts / chat history for this session.
