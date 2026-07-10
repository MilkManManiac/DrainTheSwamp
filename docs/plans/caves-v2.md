> **SUPERSEDED (2026-07-09)** by `cave-overhaul-v3.md` (shipped) and the cave items in `full-audit-2026-07.md`.

# Cave System v2 — Design Plan

## Overview
5 explorable side-scrolling caves + 1 endgame government base. Each cave is tied to a specific swamp and unlocks when that swamp is ~50% drained. Caves reward the player with money, free upgrades, and conspiracy lore.

## Design Principles
- **Caves are a bonus, not a requirement** — rewards are shortcuts (free money, free upgrade levels), not exclusive items
- **Each cave has its own identity** — distinct theme, lighting, and lore beat
- **Simple mechanics** — circle of light, loot nodes, lore walls. No combat, no drowning, no complex puzzles
- **Lore escalation** — each cave ratchets up the conspiracy from "huh" to "oh shit"

---

## Cave Lineup

### 1. Muddy Hollow
- **Swamp**: Puddle (unlocks at ~50% drained)
- **Theme**: Short mud cave, tutorial-style introduction to cave exploration
- **Size**: ~2 screens wide, flat ground, some stalagmites
- **Lighting**: Dim but not scary. Player light radius feels adequate.
- **Loot**:
  - Scrap metal pile → ~$200 money
  - Old toolbox → Free tool upgrade (+1 level to current tool)
- **Lore**: Strange carved symbol on wall — too precise to be natural. Just a curiosity.
- **Vibe**: "Huh, that's odd"

### 2. Gator Den
- **Swamp**: Pond (unlocks at ~50% drained)
- **Theme**: Wider cave, darker, animal bones scattered around
- **Size**: ~3 screens wide, slight elevation changes
- **Lighting**: Noticeably darker than Muddy Hollow. Player light feels smaller relative to cave size.
- **Loot**:
  - Bone pile + scattered coins → ~$1,000 money
  - Better Flashlight → Increases player light radius in all caves
- **Lore**: Scratch marks that form patterns. A rusted military dog tag half-buried in mud.
- **Vibe**: "Wait, what? Something was kept down here."

### 3. The Sinkhole
- **Swamp**: Marsh (unlocks at ~50% drained)
- **Theme**: Partially flooded-looking cave (visual water on ground, doesn't affect gameplay)
- **Size**: ~3-4 screens wide, drop-down section
- **Lighting**: Darker still. Flashlight upgrade from Gator Den helps here.
- **Loot**:
  - Waterlogged safe → ~$5,000 money
  - Broken pump parts → Free stat upgrade (player's choice) or early tool unlock
- **Lore**: Government document — "Project Wetland — Phase 1 Report." Official letterhead. References to "containment" and "specimen transport."
- **Vibe**: "This is deliberate. The government did something here."

### 4. Collapsed Mine
- **Swamp**: Bog (unlocks at ~50% drained)
- **Theme**: Industrial cave — old mining equipment, support beams, generator room
- **Size**: ~3-4 screens wide, vertical shaft section
- **Lighting**: Very dark. Some areas have flickering overhead lights (atmosphere only).
- **Loot**:
  - Mining haul → ~$25,000 money
  - Generator parts → Major upgrade (tool tier unlock or big stat boost)
- **Lore**: Monitoring equipment. Containment cell designs on a clipboard. Logs referencing "the subjects" and "extraction schedules."
- **Vibe**: "They were hiding something. Something alive."

### 5. The Abyss
- **Swamp**: Deep Swamp (unlocks at ~50% drained)
- **Theme**: Deep alien cavern — glowing minerals, strange organic shapes, unearthly feel
- **Size**: ~4 screens wide, winding path downward
- **Lighting**: Pitch black except for player light and bioluminescent glow spots on walls/ceiling.
- **Loot**:
  - Alien mineral deposits → ~$100,000 money
  - Alien tech device → Large multiplier boost (Water Value or Scoop Power)
- **Lore**: Alien technology clearly not human-made. Biological samples in cracked containers. Communication logs between politicians and base personnel.
- **Vibe**: "This isn't human. And politicians knew about it."

### 6. The Base (Endgame)
- **Swamp**: Deep Swamp (unlocks at ~90% drained)
- **Theme**: Sterile government facility — gray walls, fluorescent lighting, multiple rooms
- **Size**: ~5+ screens, multi-room layout
- **Lighting**: Bright fluorescent (contrast to all previous dark caves). Feels wrong and clinical.
- **Loot**: Story payoff + endgame equipment
- **Lore**: Full facility. The whole conspiracy laid bare. Politicians are lizard people. The swamp was flooded intentionally to hide this place. Credits trigger after full exploration.
- **Vibe**: "The truth."

---

## Core Mechanics

### Circle of Light
- Player has a PointLight2D with a soft circular glow
- Cave environment uses a CanvasModulate to make everything dark
- Light radius starts small (~48px radius), upgradeable via Flashlight loot in Gator Den (~80px)
- Everything outside the light is pitch black
- Light has a soft falloff edge (not a hard circle)

### Loot Nodes
- Glowing interactive spots on the ground or walls
- Visual: subtle pulsing glow particle effect to draw attention
- Walk up + press interact key → pickup animation + popup showing reward
- Each loot node has a unique ID, tracked in GameManager
- Collected nodes are gone on revisit (or show as empty/dim container)
- One-time rewards only

### Lore Walls
- Carvings, documents, or markings on cave walls
- Visual: slightly different wall tile or overlay sprite with a subtle shimmer
- Walk up + press interact → text popup with lore content
- Can be re-read on revisit (not consumed)

### Cave Entrances (Main World)
- Appear as dark openings in the terrain wall of the game world
- Only visible when the associated swamp is drained past the threshold
- Visual: dark rectangle with rocky edges, subtle glow/shimmer
- HUD notification when a new cave is revealed: "A cave entrance has appeared!"
- Player walks to entrance + presses interact → fade to black → load cave scene

### Scene Transitions
- Fade to black (ColorRect alpha tween, ~0.5s)
- Load cave scene, position player at left edge (entrance)
- On exit: walk to left edge → fade to black → return to main world at cave entrance position

### Persistence
- GameManager tracks: cave unlock state, loot collection per cave
- `cave_data: Dictionary` — keyed by cave_id, stores {unlocked: bool, loot_collected: {loot_id: bool}}
- Saved in save data (bump save version)

---

## Implementation Order
1. Cave state tracking in GameManager + save/load
2. Circle of Light system (PointLight2D + CanvasModulate)
3. Scene transition system (fade in/out + scene swap)
4. Base cave scene template with player movement
5. Loot node system (interact + collect + persist + popup)
6. Lore wall system (interact + text popup)
7. Cave entrance in main world (visual + interaction + unlock trigger)
8. Build Muddy Hollow (first cave)
9. Build remaining caves one by one
10. HUD notifications for cave unlocks + loot pickups
11. The Base (endgame, last)

---

## Technical Notes
- Cave scenes are separate `.tscn` files, not part of the main world scene
- Player controller reused in caves (same CharacterBody2D script)
- Each cave is a hand-crafted tilemap scene (no procedural generation)
- Light radius upgrade stored as a GameManager stat (persistent across caves)
- Cave unlock checks happen whenever water_level changes in a swamp
