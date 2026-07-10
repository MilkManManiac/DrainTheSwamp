> **SUPERSEDED (2026-07-09)** by `visual-overhaul-research.md`, `high-res-2d-overhaul.md`,
> and the shipped Phase 1 visual pass in `full-audit-2026-07.md`.

# Graphical Overhaul Plan

Full visual overhaul: shaders, particles, animations, weather, UI juice, and post-processing.
All changes are code-only (no external art assets needed).

---

## Phase 1: Shader Foundation

### 1a. Water Shader
- Custom `.gdshader` on water Polygon2Ds
- Sine-wave vertex distortion for ripple effect
- Specular highlight that shifts with time
- Edge foam (brighter alpha at shoreline)
- Per-pool color tinting preserved

### 1b. Post-Processing (CRT + Vignette + Color Grading)
- Full-screen ColorRect with shader on CanvasLayer (top z-index)
- Subtle horizontal scanlines (alpha ~0.06)
- Vignette darkening at screen edges
- Color grading: warm shift during day, cool blue at night (reads CanvasModulate tint)

### 1c. Water Edge Glow
- Additive-blend ColorRect around water body edges
- Subtle luminous teal glow, stronger at night
- Pulses slowly with sine wave

---

## Phase 2: Particle Systems

### 2a. Replace Hand-Coded Particles with CPUParticles2D
- **Dust puffs** — footstep-triggered, cloud-like, sandy brown
- **Water splash** — on scoop, blue droplets with gravity
- **Bubbles** — rising from water bodies, varied sizes
- **Fireflies** — warm glow with randomized drift paths

### 2b. New Ambient Particles
- **Pollen/spores** — slow-drifting dots across entire screen, very subtle
- **Mist wisps** — near water bodies, low opacity, slow horizontal drift
- **Leaves** — occasional leaf falling from treeline area

---

## Phase 3: Parallax & Depth

### 3a. Parallax Background
- Split sky/hills/treeline into ParallaxBackground + ParallaxLayers
- Sky: no movement (fixed)
- Distant hills: 0.1x scroll ratio
- Near hills: 0.3x scroll ratio
- Treeline: 0.6x scroll ratio
- Foreground terrain: 1.0x (normal)

### 3b. Biome Tinting
- Subtle palette shift based on which swamp area player is near
- Puddle area: bright, clean, warm
- Deep Swamp area: dark, mysterious, cool teal
- Smooth transition via CanvasModulate interpolation

---

## Phase 4: Weather System

### 4a. Rain
- CPUParticles2D rain streaks (angled, blue-white)
- Ground splash particles on impact
- Darkened sky tint during rain
- Increased vegetation sway

### 4b. Lightning
- Occasional white flash (full-screen ColorRect alpha pulse)
- Brief bright tint on CanvasModulate
- Random timing (every 15-45s during storms)

### 4c. Fog
- Multiple semi-transparent ColorRects drifting horizontally
- Layered at different speeds for depth
- Thicker near Deep Swamp, lighter near Puddle
- More prominent at night/dawn

---

## Phase 5: Vegetation Animation

### 5a. Wind Sway
- Cattails: sine-based rotation on stalks, faster during rain
- Ferns: gentle frond wave via Line2D point offsets
- Grass strips: vertex displacement on Line2D points
- Global wind direction variable (shifts slowly over time)

### 5b. Lily Pad Bobbing
- Slow vertical sine wave on lily pad positions
- Slight rotation drift

---

## Phase 6: Wildlife Animation

### 6a. Fish
- Occasional jump: tween arc out of water + splash particle
- Idle: slow drift with direction changes

### 6b. Frogs
- Idle: periodic blink (eye ColorRect flash)
- Hop: tween jump arc to new position, land splash

### 6c. Turtles & Tadpoles
- Slow patrol movement along water edge
- Turtles: head bob animation

### 6d. Dragonflies & Butterflies
- Wobbly flight paths (sine + noise offset)
- Direction changes at random intervals
- Dragonflies hover near water, butterflies near vegetation

---

## Phase 7: Screen Effects & Camera

### 7a. Screen Shake
- On scoop: tiny shake (1-2px, 0.1s)
- On big purchase: medium shake (3px, 0.15s)
- On swamp drained: heavy shake (5px, 0.3s)

### 7b. Camera Sway
- Subtle slow sine drift while walking (0.5px amplitude)
- Smooth follow with slight lag for organic feel

### 7c. Milestone Flash
- Drain complete / new tool: golden vignette pulse + particle burst
- Brief scale bounce on the game world (1.02x for 0.2s)

---

## Phase 8: Camel Animation

### 8a. Walk Cycle
- Leg stride (same pattern as player but 4 legs)
- Head bob synced to walk
- Saddle bag bounce (offset by half phase)

### 8b. Dust Trail
- CPUParticles2D behind camel while moving
- Sandy brown, small, short lifetime

---

## Phase 9: Tool-Specific Effects

### 9a. Per-Tool Scoop Particles
- **Hands**: small ripple
- **Spoon/Cup**: gentle splash
- **Bucket**: big splash with droplets
- **Shovel**: dirt chunk particles + splash
- **Wheelbarrow**: heavy splash + ground shake
- **Barrel/Wagon**: massive splash wave
- **Hose**: continuous spray mist particles

---

## Phase 10: UI Juice

### 10a. Panel Transitions
- Slide in from side (0.2s ease-out)
- Slide out on close (0.15s ease-in)

### 10b. Button Effects
- Hover: slight scale up (1.05x) + border brighten
- Press: scale down (0.95x) + color darken
- Purchase success: brief green flash

### 10c. Money Counter Animation
- Roll-up/roll-down number animation on money change
- Brief golden glow pulse on big earnings

### 10d. Visual Feedback Particles
- Money earned: small golden sparkle burst
- Inventory full: red pulse ring
- Level up: star burst particles around stat

---

## Phase 11: Lighting & Atmosphere

### 11a. Firefly Light Pools
- PointLight2D or additive ColorRect under each firefly
- Warm yellow, small radius, pulses with firefly glow

### 11b. Pump Station Glow
- Green indicator casts small light pool
- Pulses when pump is active

### 11c. Enhanced Day/Night
- Richer sunrise/sunset colors (orange/pink transitions)
- Star twinkle animation (alpha flicker)
- Moon glow halo
- Shooting stars more visible with brief trail

---

## Phase 12: Player Immersion

### 12a. Water Drip Trail
- When carrying water, small blue drip ColorRects fall from tool position
- Frequency based on how full inventory is
- Drips hit ground and fade out

### 12b. Footprints in Mud
- Near water edges, each footstep leaves a darkened mark on the ground
- Fades out over 3-4 seconds
- Only on dirt/mud areas (not on solid ground far from water)

### 12c. Idle Animations
- After 3s idle: player looks left/right (eye shift)
- After 6s: adjusts hat (hat nodes shift up then back)
- After 10s: taps foot (one boot bobs)
- Loop back to start

### 12d. Tool Equip Animation
- Old tool shrinks to 0 scale (0.1s)
- New tool grows from 0 to full scale (0.15s) with slight overshoot bounce

---

## Phase 13: Environment Storytelling

### 13a. Drain Visual Progression
- As swamp water_level drops below thresholds, reveal hidden objects:
  - 75%: mud patches at edges
  - 50%: exposed rocks, old boot
  - 25%: rusty sign, fish bones
  - 0%: treasure chest / ancient artifact (visual reward)
- Objects are pre-placed ColorRect groups, visibility toggled by water level

### 13b. Wet Ground Zones
- Dark, slightly glossy dirt band around each water body
- Width proportional to current water level
- Shrinks as swamp drains
- Subtle shimmer shader or alpha pulse

### 13c. Dynamic Shadows
- Player shadow stretches/rotates based on sun position in day/night cycle
- Short shadow at noon, long shadow at dawn/dusk
- Shadow disappears at night
- Pump station shadow follows same logic

---

## Phase 14: Extra Shaders

### 14a. Heat Shimmer
- Vertex distortion shader on a screen-wide ColorRect
- Active during daytime only, fades in/out with day cycle
- Disabled during rain
- Subtle — just enough to feel warm

### 14b. Water Reflections
- Flipped, distorted render of sky/cloud colors on water surface
- Shader reads sky gradient and mirrors it with wave distortion
- Low opacity (~0.15), blends with existing water color
- More visible on calmer (smaller) pools

---

## Phase 15: World Progression (Game Gets Prettier)

### 15a. Desaturated-to-Vibrant
- Track total gallons drained as a "world health" score
- Early game: slight desaturation shader (saturation ~0.7)
- As you drain, saturation gradually rises to 1.0 then slightly beyond (1.05)
- Applied via the post-processing shader uniform

### 15b. Growing Vegetation on Drained Land
- When a swamp drops below water level thresholds, spawn new plants on exposed land
- Small flowers, grass tufts, saplings appear over time
- Tween them growing from size 0 to full — visible sprouting effect
- More swamps drained = lusher world

### 15c. Background Life Scaling
- Bird silhouettes crossing the sky — count increases with progress
- More butterflies and dragonflies spawn as world heals
- Clouds get slightly larger/fluffier at high progress
- Ecosystem visually recovering

---

## Phase 16: Player Readability & Juice

### 16a. 1px Character Outline
- Dark outline around the player's Visual node
- Shader on a duplicate behind the player, offset 1px in each direction
- Or: outline shader on the Visual node itself
- Always readable against any background color

### 16b. Speed Lines
- When move speed multiplier > 1.5x, spawn trailing motion streaks
- Horizontal lines behind player, fade quickly (0.15s)
- More lines and longer at higher speeds
- Subtle white/light color, low opacity

### 16c. Coin Fly Animation
- On earning money: golden dot particles fly from player toward HUD money counter
- On spending money: dots fly from HUD counter downward
- Bezier curve path for satisfying arc motion
- Connects the game world to the UI

---

## Phase 17: Atmosphere

### 17a. Pump Steam
- When selling water at pump, white steam particles rise from pipe
- CPUParticles2D: upward drift, expand, fade
- Brief mechanical chug visual (pump body jiggles 1px)

### 17b. Morning Mist
- Dawn-specific low fog layer (separate from weather fog)
- Appears during sunrise transition, burns off over 30s
- Thin horizontal wisps, warm golden tint from sunrise light

### 17c. Aurora Borealis
- Rare nighttime event (~10% chance per night cycle)
- Slow-moving colored curtains across top of sky
- Green/purple/blue gradient bands, undulating via sine offset
- Fades in/out gently over 20s

### 17d. Birds & Owls
- Daytime: bird silhouettes (2-3 ColorRect V-shapes) cross sky left to right
- Occasional flock (5-8 birds in loose formation)
- Nighttime: single owl silhouette perched in treeline, glowing yellow eye dots
- Owl occasionally blinks (eye alpha flash)

---

## Phase 18: Terrain Polish

### 18a. Dithered Transitions
- Checkerboard/dither pattern at boundaries between terrain types
- Grass-to-dirt: alternating green/brown pixels in a 2-3px band
- Dirt-to-mud: alternating dry/wet brown pixels near water
- Implemented via small repeating ColorRect pattern or shader

### 18b. Shoreline Ripples
- When player is near water (not scooping), concentric ring ripples expand from nearest water edge
- Small expanding circle outlines (Line2D or shader)
- Fade out over 1s, new ripple every 0.8s
- Only when standing still or walking slowly near edge

---

## Implementation Order (Recommended)
1. Phase 1 (shaders — water, post-processing, glow) — foundation everything else builds on
2. Phase 14 (extra shaders — heat shimmer, reflections) — while we're doing shaders
3. Phase 3 (parallax) — restructures scene tree, do early
4. Phase 2 (particles) — replaces existing effects
5. Phase 5 (vegetation) — quick win, big visual impact
6. Phase 11 (lighting) — enhances day/night which already exists
7. Phase 15 (world progression) — desaturation shader, growing vegetation
8. Phase 13 (environment storytelling) — drain progression, wet ground, shadows
9. Phase 4 (weather) — builds on particles + lighting
10. Phase 17 (atmosphere) — pump steam, mist, aurora, birds
11. Phase 6 (wildlife) — builds on existing creatures
12. Phase 8 (camel) — isolated system
13. Phase 16 (player readability) — outline, speed lines, coin fly
14. Phase 12 (player immersion) — drip trail, footprints, idle, tool swap
15. Phase 18 (terrain polish) — dithered transitions, shoreline ripples
16. Phase 7 (screen effects) — layer on top
17. Phase 9 (tool effects) — builds on particles
18. Phase 10 (UI juice) — independent, can do anytime
