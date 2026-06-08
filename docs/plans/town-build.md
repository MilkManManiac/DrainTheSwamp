# Build Plan — Drainsville: the home-base town (2026-06-08)

Replace the single generic shop on the left with a small, tightly-clustered bayou town: **4 themed storefronts + the hidden NA dead-drop**. Visual + light-mechanics feature. Status: plan (awaiting approval before build).

## Goal
- Give the home base character and make upgrades discoverable by theme.
- House the **NA dead-drop** diegetically (ties into [[story-rework]]).
- Do it **without adding meaningful walk friction** — buildings clustered within ~one screen, near the spawn/sell area.

## Store → upgrade mapping (locked: 4 stores + dropbox)
| Store | Sells | Categories |
|---|---|---|
| **Swamp Mike's Bait & Hardware** | scoop tools (spoon→water wagon), Garden Hose, Auto-Scooper | tools + automation |
| **The Diner** | Stamina, Stamina Regen | energy/food |
| **The Outfitter** | Carrying Capacity, Movement Speed, Lantern, Camel | loadout/transport |
| **The Pawn Shop** | Water Value, Scoop Power | power multipliers (pricey/shady) |
| **📫 NA dead-drop** | special gear + bonus cash + intel turn-in | secret channel (story-gated) |

## Current state to refactor (verified)
- `game_world.gd:_build_shop()` (~4981–5205): builds one shop building + a shop `Area2D`. **Entering the area auto-sells water** (`_on_shop_body_entered` → `GameManager.sell_water()` + coin fly) and flags `player_in_shop_area`. Also hosts the **wanted poster** (pool-4 gated) and shop lantern.
- `shop_panel.gd`: one slide-in `PanelContainer` with **Tools/Stats tabs**, rebuilt in `_refresh()`; opened via `open()`. `current_tab` 0=Tools/1=Stats.
- Player has `set_near_shop(bool)`; opening is proximity + input.

## Mechanics design
1. **Per-store triggers.** Each building gets its own `Area2D` + a `store_id`. Entering sets a "near store X" state + prompt; the open input opens the panel **for that store**.
2. **Parameterize `shop_panel`.** Replace the fixed Tools/Stats tabs with a per-store **allow-list** of items + a store title/color. `open(store_id)` filters `_refresh()` to that store's categories. Keep the slide-in UI, vendor flavor in the title bar.
3. **Selling — a WATER TOWER (decided).** A tall **water tower** is the auto-sell landmark: walk near it and your haul auto-sells (reuses the current proximity auto-sell + coin-fly). Diegetic ("dump your water here"), and a strong vertical silhouette anchoring the town. Its own `Area2D`, decoupled from the browse-a-store flow.
4. **NA dead-drop.** Build the **visual + a basic interactable** now (a beat-up mailbox/crate in an alley). Full behavior (special upgrades, intel turn-in, phone tie-in) is **story-gated** — stub it with a "nothing here yet" until the [[story-rework]] systems land. Flag this dependency; don't block the town on it.
5. **Migrate existing attachments:** move the **wanted poster** (pool-4 gated) and shop lantern onto an appropriate building (Hardware). Preserve save-compat (no GameManager data changes needed — this is presentation + UI routing).

## Art approach (procedural, matches current painterly-HD)
- Build procedurally in a new `_build_town()` (supersedes `_build_shop()`), consistent with the all-procedural world.
- Each storefront: tapered wood facade, pitched/awning roof, a hanging **sign** (distinct silhouette + label per store), a glowing window. Vary height/color/roofline so the row reads as a real street, not clones.
- **Night:** window/sign lights emit overbright so they **bloom under HDR** (reuse the `_emit()` + glow pipeline). Warm pools of PointLight2D light. This makes the town a cozy beacon at night.
- Ground the row on a slightly raised dry "boardwalk" so it sits above the waterline.
- Keep silhouettes bold and readable at the game's zoom; signs legible.

## Layout
```
 [Pawn] [Diner] [Hardware] [Outfitter]    📫        ...→ Puddle (first pool)
   🏚️     🍖       🔨          🎒      (alley)
 ===================================================  boardwalk / dry ground
 ^ spawn / town          tight cluster, ~1 screen wide
```
Place between the left boundary and the Puddle entry. Player spawns in/at town.

## Build sequence
1. **Layout + facades** — `_build_town()`: 4 procedural storefronts + signs + boardwalk, placed/clustered. (Visual; screenshot-verify the street reads well.)
2. **Panel refactor** — parameterize `shop_panel` by `store_id` (allow-list + title); add per-store `Area2D` triggers + prompts; route open() per store.
3. **Sell relocation** — single town cashier/sell trigger; migrate wanted poster + lantern.
4. **NA dropbox** — visual + stub interactable (story-gated behavior deferred).
5. **Night/polish** — sign/window glow (HDR), light pools, per-store color/roof variation, vendor names on signs.

## Risks / watch-items
- **Walk friction** — keep buildings adjacent (a few steps apart); verify the browse-multiple-stores flow isn't tedious (screenshot + walk-test).
- **Sell ambiguity** — resolve the single sell point (above) before wiring.
- **Save-compat** — keep all GameManager upgrade data identical; this is routing/visual only.
- **Panel refactor regressions** — ensure every existing upgrade still appears in exactly one store (no orphans: tools, hose, auto_scooper, carrying_capacity, movement_speed, stamina, stamina_regen, water_value, scoop_power, lantern, camel = all mapped above ✓).
- **Scope** — ~5 structures + a UI refactor; bigger than a visual tweak. Phased above so each step is verifiable.

## Decisions (resolved 2026-06-08)
- **Sell point = water tower** (auto-sell on proximity). ✔
- **NA dropbox built now, stubbed** (visual + basic interactable; full behavior deferred to story rework). ✔
- Town name: working "Drainsville" (swappable).
