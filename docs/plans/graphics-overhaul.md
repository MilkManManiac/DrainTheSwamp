> **SUPERSEDED (2026-07-09)** by `visual-overhaul-research.md`, `high-res-2d-overhaul.md`,
> and the shipped Phase 1 visual pass in `full-audit-2026-07.md`.

# Graphics Overhaul — Master Plan

## Current State Summary

Everything is **100% procedural** — zero image assets. All visuals are built from ColorRect, Polygon2D, Line2D, and 2 shaders (water + post-processing). The game runs at 640x360 with nearest-neighbor filtering on GL Compatibility. game_world.gd alone is ~4,800 lines handling 30+ visual systems.

**What already works well:**
- Water shader (waves, specular, foam, caustics, turbidity) — solid foundation
- Day/night cycle (9-stage CanvasModulate) — creates good mood shifts
- Creature ecosystem (fish, frogs, turtles, dragonflies, fireflies, etc.) — gives the world life
- Atmospheric systems (fog, mist, aurora, pollen, leaves) — adds depth
- Per-pool shader params (choppiness, turbidity scale with pool size) — good world progression
- Post-processing (heat shimmer, saturation tied to drain progress) — subtle but effective

**What needs work:**
- Rectangular shapes everywhere (clouds, sun, creatures are all visible rectangles)
- Terrain lacks visual depth at the surface level
- Sky is 3 flat color bands
- No shadow/lighting system beyond CanvasModulate tint
- Very few particle effects (only rain uses CPUParticles2D)
- UI is purely functional with no visual flair
- No screen shake, juice, or impact feedback beyond floating text
- Player character is static-looking from a distance

---

## Phase 1: Terrain & Ground Overhaul

### 1A. Layered Terrain Shading
**File: `game_world.gd` — `_build_terrain()`**

Currently: 3 flat Polygon2D layers (ground, mid-soil, dark subsoil) + 2 Line2D grass strips.

**Add:**
- **Erosion lines**: Horizontal Line2D scratches on exposed basin walls (darker than ground), 1-2px wide, scattered on steep slopes. Creates a weathered rock look.
- **Striation layers**: 3-5 thin horizontal Polygon2D bands within pool basins, each slightly different earth tone. Makes deep pools look geological.
- **Wet edge darkening**: Where terrain meets water, darken ground color by 20% in a 4px band above waterline. Update dynamically as water level drops.
- **Root exposure**: On steeper slopes near water, add Line2D "root" tendrils (dark brown, 1px wide, branching patterns) growing out of the soil face.
- **Pebble scatter**: Tiny 1-2px ColorRects in varied earth tones scattered on flat ridge areas. Currently only rocks exist as larger decorations — add smaller scattered pebbles.

### 1B. Better Grass System
**File: `game_world.gd` — `_build_vegetation()`**

Currently: Line2D blades in small tufts, same color everywhere.

**Add:**
- **Grass color zones**: Grass near water = darker/lush green. Grass on dry ridges = lighter/yellow-green. Grass on shore = mix. Use pool proximity to blend colors.
- **Tall grass clusters**: On wider ridges, place 3-4 blade clusters (12-16px tall) that sway together in wind. Currently max blade height is ~12px.
- **Wind sway**: All grass blades get a subtle sine-wave rotation based on `wind_direction`. Currently only ferns sway. Match frequency with fern sway for consistency.
- **Seasonal tint**: Tie grass hue to drain_progress. Early game (undrained) = muddy yellow-green. Late game (mostly drained) = vibrant green. Uses the existing saturation progression system.

### 1C. Ground Texture Shader (New)
**File: `shaders/terrain.gdshader` (new)**

A subtle procedural noise shader applied to the terrain Polygon2D:
- Perlin-like grain pattern (static, not animated) in the ground color
- Adds visual texture without images
- Very subtle — just breaks up the flat color
- Apply as ShaderMaterial to `terrain_polygon`

```glsl
// Pseudocode for terrain shader
// Simple hash-based noise to create ground texture
// Mix 2-3 earth tones based on noise value
// Add horizontal striation based on world Y position
```

---

## Phase 2: Sky & Atmosphere Overhaul

### 2A. Gradient Sky
**File: `game_world.gd` — `_build_sky()`**

Currently: 3 flat ColorRect bands.

**Replace with:**
- Single Polygon2D with a **GradientTexture2D** (vertical fill) that smoothly blends sky_top → sky_mid → sky_bottom.
- Make the gradient **time-dependent**: interpolate between 4 gradient presets (dawn warm, day blue, dusk orange, night dark blue) based on `cycle_progress`.
- Add a **horizon glow** Line2D (8px wide, additive blend) at the treeline level that intensifies at dawn/dusk.

### 2B. Volumetric Cloud Shapes
**File: `game_world.gd` — `_build_clouds()`**

Currently: Rectangular ColorRects with rectangular puffs — very obviously box-shaped.

**Replace with:**
- Each cloud = a **Polygon2D** with a hand-shaped organic outline (8-12 points forming a puffy silhouette).
- 3-4 cloud templates (small wisp, medium puff, large cumulus) randomly selected.
- Semi-transparent white with a brighter highlight rim on top.
- Inner shadow polygon (slightly offset, slightly darker) for depth.
- Cloud count scales: 6 base + more spawn/despawn at edges dynamically.
- During rain: clouds darken to grey, lower Y position, increase count.

### 2C. Sun & Moon Glow
**File: `game_world.gd` — `_build_sun()`, `_build_moon()`**

Currently: Square ColorRects layered to approximate a circle.

**Replace with:**
- **Sun**: Polygon2D octagon (8-sided, approximates circle at this resolution) with:
  - Outer glow: larger semi-transparent octagon with additive blend PointLight2D
  - Ray beams: 4-6 Line2D rays radiating outward, fade/rotate slowly
  - Lens flare: when sun is near horizon, a horizontal streak (narrow ColorRect, additive blend)
- **Moon**: Polygon2D octagon with:
  - Crater details: 2-3 tiny darker circles (small Polygon2D octagon)
  - Moonlight: PointLight2D with subtle blue-white glow, energy tied to moon altitude
  - Moon phase: track `current_day % 8` to show different amounts of shadow (simple crescent overlay)

### 2D. Shooting Stars
**File: `game_world.gd` — atmosphere section**

Currently: None (aurora exists but is rare).

**Add:**
- Random chance during night (every 15-30s, 20% chance)
- Line2D with 4-5 points, white-to-transparent gradient
- Animates rapidly across sky (0.4s lifetime) with slight curve
- Spawn at random position in upper sky

### 2E. Enhanced Aurora
Currently: 5 Line2D wavy lines, additive blend — good foundation.

**Improve:**
- Increase to 8-10 lines with more color variety
- Add subtle width variation (Line2D width_curve) for organic feel
- Brighten colors — currently max alpha is 0.3, increase to 0.5 for more impact
- Add pulsing: vary alpha per-line over time for rippling effect

---

## Phase 3: Water Visual Overhaul

### 3A. Enhanced Water Shader
**File: `shaders/water.gdshader`**

Currently: Good foundation with waves, specular, foam, caustics, turbidity.

**Add:**
- **Reflection approximation**: At UV.y near 0, sample a sky-color tint (passed as uniform) and blend it in. Creates a reflection illusion without actual reflections.
- **Ripple rings**: Where player scoops, emit expanding ring distortion (time-based radial wave from a uniform position). Ring expands, fades, resets.
- **Color banding**: Add subtle horizontal color bands (2-3 hues of the base water color) for depth layers rather than just darkening.
- **Animated foam**: Make foam pattern drift sideways slowly (adds to `UV.x` offset over time), currently static pattern.
- **Surface sparkle**: Random bright pixels that flash briefly (noise-based), simulating sun glinting. Only active during daytime (pass a `daytime` uniform).

### 3B. Waterfall/Drip Effects at Pool Edges
**File: `game_world.gd`**

**Add:**
- When a pool's fill fraction > 80%, add small "drip" Line2D animations at the entry/exit slopes — water seeping over the rim.
- 2-3 drip points per pool edge, small animated Line2D segments (2-4px) that cycle: extend down, drip, reset.
- Color matches pool water color.
- Disappear as water level drops below that edge.

### 3C. Water Splash Particles
**File: `game_world.gd`**

Currently: Player has a basic splash feedback in player.gd.

**Add to game_world:**
- When player scoops near water, spawn 4-6 CPUParticles2D burst droplets from the water surface
- Small blue-tinted circles, arc upward, gravity pulls down, lifetime 0.4s
- Scale with tool size (bigger tool = bigger splash)
- Same effect when camel drinks
- Ripple ring on water surface at scoop point (expanding Line2D circle, fades)

### 3D. Water Edge Vegetation
Currently: Lily pads + cattails near edges.

**Add:**
- **Reeds**: Thin Line2D clusters (3-5 per group, 8-12px tall) at water's edge, sway in wind. Darker green than grass. Place at entry/exit slopes of each pool.
- **Algae patches**: Small green-tinted Polygon2D blobs floating on water surface near shallow edges. Semi-transparent, bob with water.

---

## Phase 4: Lighting & Shadows

### 4A. Dynamic World Lighting
**File: `game_world.gd`**

Currently: Only CanvasModulate tint + shop lantern PointLight2D + player lantern.

**Add ambient lights:**
- **Pool glow lights**: One PointLight2D per pool, positioned at water center, colored to match pool water. Energy proportional to fill level. Creates colored reflection on nearby terrain.
- **Sunrise/sunset rim light**: During dawn/dusk, a wide PointLight2D positioned at the horizon (warm orange) that illuminates the left/right edge of screen. Follows camera.
- **Lightning flash**: Currently just a white ColorRect overlay. Replace with a brief PointLight2D flash (white, high energy, rapid decay) positioned at a random sky point. More realistic than full-screen white.

### 4B. Enhanced Shadows
Currently: Player has a simple dynamic shadow based on sun angle.

**Add:**
- **Shop shadow**: Static dark polygon projected from the shop building during daytime.
- **Treeline shadow**: A dark semi-transparent strip along the bottom of the treeline that extends/retracts based on sun angle.
- **Creature shadows**: Tiny 2-3px dark ellipse beneath each visible creature (frogs, turtles — flying creatures excluded). Only visible during day.

### 4C. Fog of Distance
**File: `game_world.gd`**

**Add:**
- As the camera scrolls right toward later pools, add a subtle depth-fog overlay.
- Implemented as a CanvasLayer with a ColorRect that has an alpha gradient (0 at camera center, slight tint at edges).
- Color matches time-of-day (blue at night, warm at day).
- Very subtle — 5-10% opacity max. Creates atmospheric perspective.

---

## Phase 5: Particle Effects & Juice

### 5A. CPUParticles2D Upgrades

Replace several manual ColorRect animations with CPUParticles2D for better visual quality:

| System | Current | Upgrade |
|--------|---------|---------|
| Fireflies | ColorRects moving on sine | CPUParticles2D with circular emission, glow, random lifetime |
| Pollen | ColorRects with manual drift | CPUParticles2D with very low velocity, high lifetime, turbulence |
| Leaves | ColorRects with manual physics | CPUParticles2D with rotation, gravity, wind influence |
| Bubbles | ColorRects rising | CPUParticles2D with negative gravity, wobble, pop at surface |
| Coin fly | Manual tween | CPUParticles2D burst at sell point, gold color, arc toward HUD |

Each conversion reduces per-frame manual update code and gets built-in interpolation/fading.

### 5B. Screen Shake
**File: `game_world.gd` or `player.gd`**

**Add a camera shake system:**
- `_shake_camera(intensity: float, duration: float)` — offsets Camera2D by random amounts, decays over duration
- Triggers:
  - Lightning strike: intensity 3, duration 0.2
  - Pool completion (drained to 0%): intensity 4, duration 0.5
  - Cave entrance opens: intensity 2, duration 0.3
  - Tool upgrade purchased: intensity 1, duration 0.1 (micro-shake)

### 5C. Purchase/Upgrade Visual Feedback
Currently: No visual feedback when buying upgrades besides stat numbers changing.

**Add:**
- **Upgrade sparkle**: When buying a tool/stat upgrade, spawn a burst of 8-12 small colored particles at the button position. Color matches the tab color (gold for tools, blue for stats, green for upgrades).
- **Money deduction animation**: When spending large amounts, the HUD money label does a brief red flash + scale bounce.
- **Tool equip flash**: When switching tools, the player's tool visual does a brief white flash (modulate to white for 0.05s, back to normal).

### 5D. Scoop Impact Juice
Currently: Arm rotation + floating text.

**Add:**
- Brief 0.05s freeze-frame on heavy scoops (scoop amount > 0.5 gal)
- Tool impact particles: small brown/blue spray from scoop point (3-5 particles, short life)
- Water ripple at contact point
- Subtle camera nudge (1px down, bounce back) on scoop

---

## Phase 6: UI Visual Polish

### 6A. HUD Modernization
**File: `scripts/ui/hud.gd` + `scenes/hud.tscn`**

Currently: Plain labels in a margin container.

**Improve:**
- **Backdrop**: Semi-transparent dark panel behind HUD bars (currently transparent, text can be hard to read over bright scenes).
- **Icons**: Tiny 5x5 ColorRect pixel-art icons next to each label:
  - Money: yellow circle (coin)
  - Water: blue drop shape (3 small rects forming a droplet)
  - Bag: brown square
  - Stamina: green lightning bolt
  - Day: sun/moon symbol based on time
- **Stamina bar style**: Add a gradient fill (green → yellow → red as it depletes). Currently solid color.
- **Animated transitions**: When values change, labels briefly scale up 10% and settle back (tween, 0.15s).

### 6B. Shop Panel Polish
**File: `scripts/ui/shop_panel.gd`**

Currently: Functional with tabs and StyleBoxFlat, but visually plain.

**Improve:**
- **Panel background**: Replace flat dark color with a subtle wood-grain pattern (procedural noise shader on the PanelContainer's StyleBoxFlat, or a darker/lighter stripe pattern).
- **Button hover effects**: On mouse hover, buttons glow slightly (lighten bg by 15%, add 1px bright border). Currently: just bg lightens by 10%.
- **Affordance indicators**: Buttons you can afford get a subtle green glow/pulse on the border. Items you can't afford are slightly desaturated.
- **Category dividers**: Thin Line2D separators between groups (Tools, Stats, Upgrades sections) with ornamental dots.
- **Scroll indicator**: When content overflows, show a subtle animated arrow at bottom of scroll area.

### 6C. Floating Text Improvements
Currently: Text spawns, floats up, fades out — functional but basic.

**Improve:**
- **Pop-in scale**: Text spawns at 0.5x scale, quickly scales to 1.2x, settles to 1.0x (bouncy ease).
- **Color coding**: Green for money earned, blue for water scooped, red for stamina warnings, gold for upgrades/completions.
- **Combo counter**: If multiple scoops happen rapidly (< 0.5s apart), stack the text: "x2", "x3" etc with escalating size.
- **Critical hits**: If Lucky Charm triggers a bonus, make the text larger with a brief yellow star burst behind it.

---

## Phase 7: Creature & Entity Polish

### 7A. Better Creature Shapes
All creatures are ColorRect-based. At 640x360, these are tiny so rectangle shapes are mostly fine, but some improvements:

- **Fish**: Add a small Line2D dorsal fin (1-2px triangle on top). Current fish are just body + tail rectangles.
- **Frogs**: Add rear legs (2 small ColorRects angled behind body) that extend during hop animation.
- **Turtles**: Add a small Line2D tail (1px, 3px long). Add shell dome highlight (brighter green stripe).
- **Butterflies** (NEW): Daytime creature. 2 tiny ColorRect wings that flap (rotate 45 degrees back and forth). Random pastel colors. 4-6 per world, wander near flowers. Replace some of the pollen visual space.
- **Crickets** (NEW): Nighttime sound indicator. Tiny dark ColorRects (2x2px) on ridges. Every 3-5s they "chirp" — brief yellow pixel flash. Purely visual ambiance.

### 7B. Camel Visual Polish
**File: `game_world.gd` — `_build_camels()`**

Currently: Basic ColorRect body parts.

**Add:**
- **Saddle/harness**: Small colored band across the hump area (changes color with level? or fixed warm brown)
- **Water bag visual**: When camel is carrying water, show a small blue-tinted ColorRect hanging from the saddle.
- **Dust puffs**: Small tan particles at feet while walking (like player dust).
- **Idle animation**: Gentle head bob + ear twitch (currently just breathing bob).

### 7C. Bird Flock Behavior
Currently: Single birds spawn, fly across screen, despawn.

**Improve:**
- Spawn birds in flocks of 3-5 (V-formation or loose cluster)
- Leader bird slightly ahead, followers offset
- Occasional single bird still spawns for variety
- Flock silhouettes visible against sunset = iconic visual

---

## Phase 8: World Progression Visuals

### 8A. Environmental Storytelling
As pools drain, the world should visibly transform:

Currently: Growing vegetation spawns at drain thresholds — good start.

**Expand:**
- **Ground color shift**: Terrain around drained pools gradually shifts from dark muddy brown to lighter earth/grass tones. Implement by interpolating `terrain_polygon.color` based on nearest pool's drain progress.
- **Wildflower density**: Drained areas spawn more flowers over time. Track per-region flower count, spawn new ones each time fill drops 10%.
- **Bird increase**: Already implemented (bird_interval scales with drain_progress). Make it more dramatic — add bird songs (visual: musical note particles near perched birds).
- **Sky clarity**: Post-processing saturation already scales. Also slightly increase sky blue intensity as more pools drain. World literally becomes more vivid.

### 8B. Pool-Specific Visual Milestones
At certain drain thresholds, trigger special one-time visual events:

| Threshold | Event |
|-----------|-------|
| 75% fill | Water surface starts rippling faster (increase wave freq) |
| 50% fill | Pool bottom partially visible, rocks/debris start showing |
| 25% fill | Pool edges dry, cracked earth texture at exposed sides |
| 10% fill | Fish panic animations more frequent, water very choppy |
| 0% (drained) | Dramatic: camera shake, sparkle burst, pool bed fully revealed, dried mud crack pattern appears, completion jingle particles |

### 8C. Drained Pool Beds
Currently: When a pool is fully drained, the terrain polygon is just visible.

**Add:**
- **Mud crack pattern**: Overlay of Line2D segments in a crackle pattern on the exposed pool floor (dark lines on lighter mud color). Pre-generate random crack patterns.
- **Scattered debris**: Small ColorRects in dull colors scattered on the floor (old bottles, bones, coins — flavor items).
- **Dried seaweed**: Existing seaweed turns brown when pool < 5% fill (color lerp from green to brown based on fill).

---

## Phase 9: Cave Visual Enhancement

### 9A. Dynamic Cave Lighting
**File: `scripts/caves/cave_base.gd`**

Currently: Light shafts (Line2D + PointLight2D) added in Phase 2 of cave overhaul.

**Expand:**
- **Crystal glow**: Each cave has a `crystal_color`. Add 4-8 small PointLight2D nodes embedded in walls at random positions, using crystal_color with low energy (0.3-0.5). Creates colored ambient pockets.
- **Drip splash light**: When water drips hit the ground, brief 0.1s PointLight2D flash at impact point. Subtle blue glow.
- **Pool underwater glow**: Cave pools get a PointLight2D at center, pulsing slowly. Already partially implemented in cave_base.gd pool building.
- **Entrance light cone**: At cave exit (x=0), a wide PointLight2D warm light that fades over distance. Simulates outside light bleeding in.

### 9B. Cave Atmosphere
**Add:**
- **Dust motes**: CPUParticles2D with very slow drift, barely visible (alpha 0.1-0.2), illuminated by crystal lights. 30-50 particles, long lifetime.
- **Cobwebs**: In corners where ceiling meets walls, small Line2D fan patterns (3-4 lines radiating from a corner point). White-grey, very transparent.
- **Moisture gleam**: On cave walls near pools, occasional shiny pixel flicker (brief white flash, random position). Simulates wet rock catching light.

### 9C. Cave Pool Water
Use the same water shader as overworld but with different parameters:
- Lower wave_strength (calmer underground water)
- Higher turbidity (murkier)
- Crystal_color tint mixed into water color
- No foam (still underground water)

---

## Phase 10: Post-Processing & Polish

### 10A. Enhanced Post-Processing Shader
**File: `shaders/post_process.gdshader`**

Currently: Heat shimmer, saturation, warmth, scanlines, vignette.

**Add:**
- **Chromatic aberration**: Very subtle (0.5-1px) RGB channel offset at screen edges. Increases slightly during lightning.
- **Bloom approximation**: Bright pixels (>0.8 luminance) get a soft glow spread. Use a simple 3-tap gaussian blur of bright areas. This makes water specular, sun, and glowing plants pop.
- **Film grain**: Very subtle noise overlay (animated per-frame). Alpha 0.02-0.05. Adds texture to flat-colored areas. Can be toggled off.
- **Night blue shift**: During night, shift the entire color palette toward blue (beyond just the CanvasModulate darken). Apply a subtle blue overlay (uniform `night_factor`).

### 10B. Transition Effects
**File: `scripts/autoload/scene_manager.gd`**

Currently: Simple fade to black for scene transitions.

**Improve:**
- **Pixelation dissolve**: Instead of fade, pixelate the screen (increase pixel size from 1 to 16 over 0.3s, then un-pixelate the new scene). Perfect for the pixel-art aesthetic.
- **Iris wipe**: For entering caves — circular reveal/hide centered on the cave entrance. Old-school platformer feel.
- **Quick flash**: For completing a pool — brief white flash (0.05s) before celebration particles.

---

## Implementation Priority

### Tier 1: High Impact, Lower Effort
1. **Screen shake system** (5B) — instant game feel improvement
2. **Gradient sky** (2A) — replaces flat bands with smooth gradients
3. **Enhanced post-processing** (10A) — subtle bloom + chromatic aberration
4. **Water splash particles** (3C) — scoop feedback
5. **Scoop impact juice** (5D) — micro-freeze + particles
6. **HUD backdrop + icons** (6A) — readability improvement
7. **Drained pool beds** (8C) — mud cracks, completion reward visual

### Tier 2: Medium Impact, Medium Effort
8. **Volumetric cloud shapes** (2B) — organic Polygon2D clouds
9. **Sun/Moon glow** (2C) — PointLight2D + octagon shapes
10. **Pool glow lights** (4A) — ambient colored lighting per pool
11. **Better grass system** (1B) — wind sway, color zones
12. **Floating text improvements** (6C) — pop-in, combos
13. **Cave crystal lighting** (9A) — atmospheric caves
14. **Camel visual polish** (7B) — saddle, water bag, dust
15. **Waterfall drips** (3B) — pool edge detail

### Tier 3: Lower Impact, Higher Effort
16. **Ground texture shader** (1C) — procedural noise on terrain
17. **CPUParticles2D conversions** (5A) — replace manual particle code
18. **Terrain striation/roots** (1A) — geological detail
19. **Creature shape improvements** (7A) — fins, legs, tails
20. **Butterflies + crickets** (7A) — new ambient creatures
21. **Pool drain milestones** (8B) — threshold events
22. **Environmental storytelling** (8A) — ground color shifts
23. **Bird flocks** (7C) — V-formation behavior
24. **Water shader enhancements** (3A) — reflections, sparkle
25. **Shop panel polish** (6B) — wood grain, glow buttons
26. **Transition effects** (10B) — pixelation dissolve, iris wipe
27. **Cave atmosphere** (9B) — dust motes, cobwebs
28. **Shooting stars** (2D) — night sky detail
29. **Enhanced aurora** (2E) — more lines, pulsing
30. **Fog of distance** (4C) — atmospheric perspective

---

## Performance Notes

- Keep CPUParticles2D amounts conservative (max 50-100 per emitter)
- PointLight2D count: aim for < 20 active at once on screen
- Shader complexity: GL Compatibility limits — avoid complex branching, keep texture lookups minimal
- Polygon2D shapes: 8-12 vertices max for small shapes (clouds, sun/moon)
- Consider LOD: disable creature animations when off-screen (already partially done)
- Profile after each tier to ensure stable 60fps

## Scope

This plan covers **visual polish only** — no gameplay changes, no new mechanics, no economy adjustments. Every change is purely cosmetic, making the existing game look and feel more polished.

Total estimated: ~30 new or modified build methods, 1-2 new shaders, ~15 new animation systems.
