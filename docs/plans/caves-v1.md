> **SUPERSEDED (2026-07-09)** by `cave-overhaul-v3.md` (shipped) and the cave items in `full-audit-2026-07.md`.

# Cave System v1 — Implementation Plan

## Overview
Add explorable side-scrolling cave rooms that unlock as swamps are drained. Caves contain one-time loot (money + tool/upgrade unlocks) and provide the first layer of the conspiracy narrative.

## Caves (3 total)

### 1. Muddy Hollow
- **Unlock condition**: Puddle ~90% drained
- **Theme**: Short, dimly lit mud cave
- **Layout**: ~2 screens wide, flat ground, some stalagmites
- **Loot**:
  - Scrap metal pile → $100 money
  - Old toolbox → Unlocks Spoon upgrade (+1 level free) or early Cup unlock
  - Strange carving on wall → Lore item (flavor text popup)

### 2. Gator Den
- **Unlock condition**: Pond ~50% drained
- **Theme**: Wider cave, darker, animal bones scattered around
- **Layout**: ~3 screens wide, slight elevation changes, narrow squeeze section
- **Loot**:
  - Bone pile → $500 money
  - Military crate (half-buried) → Unlocks a pump upgrade or new upgrade type
  - Scratched markings on wall → Lore item ("These aren't natural...")

### 3. The Sinkhole
- **Unlock condition**: Marsh begins draining (or ~75% remaining)
- **Theme**: Partially flooded cave, player wades through shallow water sections
- **Layout**: ~4 screens wide, water sections that slow movement, a drop-down section
- **Loot**:
  - Waterlogged safe → $2000 money
  - Broken pump parts → Unlocks new semi-auto tool or significant pump upgrade
  - Government document → Lore item ("Project Wetland - Phase 1 Report")

## Core Mechanics

### Cave Entrances
- Appear as dark openings in the right-side wall of the game world
- Y position corresponds to water level milestone
- Visual: dark rectangle with rocky edges, maybe a slight glow/shimmer to draw attention
- Only visible/interactable when water level drops below the unlock threshold
- HUD notification when a new cave is revealed: "A cave entrance has appeared!"

### Entering a Cave
- Player walks to the entrance and presses interact key (same as scoop key or a dedicated key)
- Screen transitions (fade to black, load cave scene, fade in)
- Cave is a separate scene that gets loaded

### Inside the Cave
- Side-scrolling CharacterBody2D movement (same player controller)
- Darker ambient lighting (CanvasModulate or shader)
- Loot nodes: glowing interactive spots on the ground/walls
- Walk up to loot node + press interact → pickup animation + popup showing what you got
- Collected loot is marked as collected (saved to GameManager)

### Exiting
- Walk back to the left edge (entrance) and press interact, or just walk off-screen left
- Fade transition back to main game world

### Persistence
- Each loot node has a unique ID
- GameManager tracks which loot has been collected (Dictionary: loot_id → bool)
- Caves can be re-entered for exploration but collected loot nodes are gone/dimmed
- Cave unlock state saved in save data

## Technical Approach

### New Files Needed
- `scenes/caves/cave_base.tscn` — Base cave scene (shared structure)
- `scenes/caves/muddy_hollow.tscn` — Cave 1
- `scenes/caves/gator_den.tscn` — Cave 2
- `scenes/caves/the_sinkhole.tscn` — Cave 3
- `scripts/caves/cave_manager.gd` — Handles cave unlock state, loot tracking
- `scripts/caves/loot_node.gd` — Interactive loot pickup behavior
- `scripts/caves/cave_entrance.gd` — Entrance interaction + visual

### GameManager Additions
- `cave_states: Dictionary` — tracks unlock + loot collection per cave
- `loot_collected: Dictionary` — loot_id → bool
- Save/load support for cave data (bump save version to 10)
- New signals: `cave_unlocked(cave_id)`, `loot_collected(loot_id, loot_data)`

### Scene Transitions
- Simple fade-to-black transition (ColorRect alpha tween)
- Load cave scene, position player at entrance
- On exit, return to main world, position player at cave entrance

## Implementation Order
1. Cave state tracking in GameManager + save/load
2. Cave entrance visual + interaction in game world
3. Scene transition system (fade in/out)
4. Base cave scene with player movement
5. Loot node system (interact + collect + persist)
6. Build out Muddy Hollow (first cave)
7. Build Gator Den + The Sinkhole
8. HUD notifications for cave unlocks + loot pickups

## Bug Fix
- Verify and fix the top-left quadrant box overlay artifact (may still be present despite cloud drift fix)
