> **SUPERSEDED (2026-07-09).** This plan tuned systems that no longer exist in this form.
> The shipped economy is the Phase 2 curve rework in `full-audit-2026-07.md`
> (output 1.15 / cost 1.28 + x2 milestones), guarded by `tests/economy_invariants.gd`.

# Economy Rebalance v4

## Philosophy
Based on research from Cookie Clicker, Adventure Capitalist, Clicker Heroes, Antimatter Dimensions, and other successful idle games:
- **Cost must grow faster than output** — this creates natural progression walls
- **Diminishing returns should use asymptotic curves** — never trivialize a mechanic
- **Passive income should be 3-10x weaker than active play**
- **Industry standard cost exponents: 1.07 (gentle) → 1.15 (standard) → 1.25 (aggressive)**

---

## Changes

### 1. Tool Output vs Cost Gap
**Problem**: Both use 1.30x — no natural wall, every upgrade always "worth it"
**Fix**: Keep cost at 1.30x, reduce output growth to 1.15x

| | Old | New |
|---|---|---|
| Tool output growth | `base * 1.30^level` | `base * 1.15^level` |
| Tool cost growth | `base * 1.30^level` | `base * 1.30^level` (unchanged) |

Effect at level 20: Output is 16.4x (was 190x), cost is still 190x. Creates a wall that pushes players to next tool tier.

### 2. Splash Guard — Asymptotic Cap at 75%
**Problem**: 0.82^level → 98.5% reduction at L15, trivializes stamina
**Fix**: Use asymptotic formula capped at 75% reduction

| | Old | New |
|---|---|---|
| Formula | `pow(0.82, level)` | `1.0 - 0.75 * (1.0 - exp(-0.25 * level))` |
| L1 | 0.82 (18% off) | 0.83 (17% off) |
| L5 | 0.37 (63% off) | 0.46 (54% off) |
| L10 | 0.14 (86% off) | 0.31 (69% off) |
| L15 | 0.015 (98% off) | 0.27 (73% off) |
| L20 | 0.003 (99.7% off) | 0.25 (75% off) |

Stamina always matters. Max 75% reduction.

### 3. Rain Collector — Logarithmic Scaling After L5
**Problem**: $640/sec at L15, overtakes active play
**Fix**: Linear growth to L5, then sqrt scaling after

| | Old | New |
|---|---|---|
| Formula | `0.50 * 1.30^(level-1)` | L1-5: `0.50 * 1.30^(level-1)`, L6+: `L5_value * sqrt((level-4) / 1.0)` |
| L1 | $0.50/s | $0.50/s |
| L5 | $1.43/s | $1.43/s |
| L10 | $6.85/s | $3.49/s |
| L15 | $32.8/s | $4.73/s |
| L20 | $157/s | $5.72/s |

Active play stays dominant. Rain Collector is supplemental income.

### 4. Auto-Scooper — Minimum Interval 0.5s, Costs Stamina
**Problem**: Fires every 0.1s at high levels, combined with Splash Guard = AFK machine
**Fix**: Raise floor from 0.1s to 0.5s, reduce decay rate

| | Old | New |
|---|---|---|
| Formula | `max(2.5 * 0.88^level, 0.1)` | `max(2.5 * 0.92^level, 0.5)` |
| L1 | 2.30s | 2.30s |
| L5 | 1.35s | 1.70s |
| L10 | 0.74s | 1.08s |
| L15 | 0.40s | 0.69s |
| L20 | 0.22s | 0.50s (floor) |

Max rate: 2 scoops/sec (was 10/sec). Still useful, not broken.

### 5. Lucky Charm — Extend Cap, Slower Growth
**Problem**: Hits 80% cap at L15, levels beyond are waste
**Fix**: Slower growth (1.20x instead of 1.35x), cap at 60%

| | Old | New |
|---|---|---|
| Formula | `min(0.05 * 1.35^(level-1), 0.80)` | `min(0.05 * 1.20^(level-1), 0.60)` |
| L1 | 5% | 5% |
| L5 | 13.2% | 10.4% |
| L10 | 34.1% | 25.9% |
| L15 | 60% (cap approaching) | 51.6% |
| L20 | 80% (capped) | 60% (capped at ~L22) |

More levels feel meaningful, cap is lower but reached later.

### 6. Lantern Radius — Cap at 400px
**Problem**: 1.40x growth → 20,000px at L25, absurd
**Fix**: Asymptotic cap at 400px

| | Old | New |
|---|---|---|
| Formula | `48.0 * 1.40^(level-1)` | `400.0 * (1.0 - exp(-0.15 * level))` |
| L1 | 48px | 56px |
| L5 | 161px | 159px |
| L10 | 539px | 318px |
| L15 | 1,806px | 370px |
| L20 | 6,050px | 390px |

Lantern is always useful but doesn't light up the entire world.

### 7. Hose — Buff Base Output
**Problem**: Same output as Bucket (0.5) but costs 4x more ($8K vs $2K)
**Fix**: Increase base output to 2.0 (4x Bucket), reduce cost to $5,000

| | Old | New |
|---|---|---|
| Base output | 0.5 | 2.0 |
| Cost | $8,000 | $5,000 |

Hose is now clearly better output than Bucket, justifying cost. Tradeoff: no scoop power multiplier (semi_auto type).

### 8. Camel Cost Exponent — Reduce from 1.8 to 1.5
**Problem**: 1.8x is steeper than almost any idle game
**Fix**: 1.5x is still aggressive but more accessible

| | Old | New |
|---|---|---|
| Cost exponent | 1.8 | 1.5 |
| 1st camel | $500 | $500 |

Note: Camel count is already capped at 1, so this only matters if cap is raised later.

### 9. Power Stats — Lower Cost Exponents
**Problem**: Cost 4-5x their value at high levels
**Fix**: Reduce cost exponents so investment feels worthwhile

| Stat | Old Cost Exp | New Cost Exp | Growth (unchanged) |
|---|---|---|---|
| Water Value | 1.30 | 1.22 | 1.30 |
| Scoop Power | 1.28 | 1.20 | 1.28 |
| Drain Mastery | 1.30 | 1.22 | 1.30 |

Power stats now outpace their costs slightly, making them rewarding long-term investments.

### 10. Core Stats — Minor Adjustments
Slight reduction to cost exponents so QoL upgrades stay accessible:

| Stat | Old Cost Exp | New Cost Exp |
|---|---|---|
| Carrying Capacity | 1.20 | 1.16 |
| Movement Speed | 1.14 | 1.12 |
| Stamina | 1.18 | 1.14 |
| Stamina Regen | 1.18 | 1.14 |

### 11. Elephant Upgrade Costs — Reduce Bases
**Problem**: $100K-150K per upgrade level is prohibitive
**Fix**: Lower base costs

| Upgrade | Old Base | New Base |
|---|---|---|
| Trunk Capacity | $100,000 | $50,000 |
| Trot Speed | $100,000 | $50,000 |
| Trunk Strength | $150,000 | $75,000 |

---

## Summary of All Number Changes

### game_manager.gd changes:
1. `get_tool_output()`: `pow(1.30, level)` → `pow(1.15, level)`
2. `get_splash_guard_multiplier()`: `pow(0.82, level)` → `1.0 - 0.75 * (1.0 - exp(-0.25 * level))`
3. `get_rain_collector_rate()`: `0.50 * pow(1.30, level-1)` → bifurcated formula with sqrt after L5
4. `get_auto_scooper_interval()`: `max(2.5 * pow(0.88, level), 0.1)` → `max(2.5 * pow(0.92, level), 0.5)`
5. `get_lucky_charm_chance()`: `min(0.05 * pow(1.35, level-1), 0.80)` → `min(0.05 * pow(1.20, level-1), 0.60)`
6. `get_lantern_radius()`: `48.0 * pow(1.40, level-1)` → `400.0 * (1.0 - exp(-0.15 * level))`
7. Hose: base_output 0.5 → 2.0, cost 8000 → 5000
8. Camel: CAMEL_COST_EXPONENT 1.8 → 1.5
9. Power stat cost exponents: water_value 1.30→1.22, scoop_power 1.28→1.20, drain_mastery 1.30→1.22
10. Core stat cost exponents: carrying_capacity 1.20→1.16, movement_speed 1.14→1.12, stamina 1.18→1.14, stamina_regen 1.18→1.14
11. Elephant upgrade bases: trunk_cap 100K→50K, trot_speed 100K→50K, trunk_str 150K→75K
12. Lantern cost exponent: 1.40 → 1.30 (to match slower radius growth)
