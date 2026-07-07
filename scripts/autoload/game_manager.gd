extends Node

# --- Signals ---
signal money_changed(new_amount: float)
signal water_level_changed(swamp_index: int, new_percent: float)
signal tool_changed(tool_data: Dictionary)
signal tool_upgraded(tool_id: String, new_level: int)
signal stat_upgraded(stat_id: String, new_level: int)
signal stamina_changed(current: float, maximum: float)
signal scoop_performed(swamp_index: int, gallons: float, money_earned: float)
signal water_sold(amount: float)
signal hose_state_changed(active: bool, time_remaining: float)
signal swamp_completed(swamp_index: int, reward: float)
signal water_carried_changed(current: float, capacity: float)
signal day_changed(day: int)
signal camel_changed()
signal upgrade_changed
signal cave_unlocked(cave_id: String)
signal cave_entered(cave_id: String)
signal cave_exited(cave_id: String)
signal loot_collected(cave_id: String, loot_id: String, reward_text: String)
signal lore_read(cave_id: String, lore_id: String)
signal cave_pool_level_changed(cave_id: String, pool_index: int, fill_fraction: float)
signal cave_pool_completed(cave_id: String, pool_index: int)
signal prestige_changed
signal prestige_performed
signal pump_changed(swamp_index: int, level: int)
signal cave_air_changed(current: float, maximum: float)
signal cave_air_depleted

# --- Prestige Scaling ---
# pending influence = floor(sqrt(lifetime_earnings / PRESTIGE_SCALE)).
# Selling-money to complete each early swamp (gallons*money_per_gallon + reward):
#   Puddle ~175, Pond ~3K, Marsh ~60K, Bog ~1.5M, Swamp ~30M.
# With SCALE = 250K: first prestige lands mid-Bog at ~2 Influence — enough to
# buy a first upgrade (at the old 1M scale the first payout was 1 while the
# cheapest upgrade cost 2, so the system was dead on arrival). Finishing the
# Swamp yields ~11.
const PRESTIGE_SCALE: float = 250_000.0

# --- Swamp Definitions ---
var swamp_definitions: Array = [
	{"name": "Puddle", "total_gallons": 5.0, "money_per_gallon": 25.0, "reward": 50.0},
	{"name": "Pond", "total_gallons": 50.0, "money_per_gallon": 50.0, "reward": 500.0},
	{"name": "Marsh", "total_gallons": 500.0, "money_per_gallon": 100.0, "reward": 10000.0},
	{"name": "Bog", "total_gallons": 5000.0, "money_per_gallon": 250.0, "reward": 250000.0},
	{"name": "Swamp", "total_gallons": 50000.0, "money_per_gallon": 500.0, "reward": 5000000.0},
	{"name": "Lake", "total_gallons": 500000.0, "money_per_gallon": 1000.0, "reward": 100000000.0},
	{"name": "Reservoir", "total_gallons": 5000000.0, "money_per_gallon": 2000.0, "reward": 2000000000.0},
	{"name": "Lagoon", "total_gallons": 50000000.0, "money_per_gallon": 4000.0, "reward": 40000000000.0},
	{"name": "Bayou", "total_gallons": 500000000.0, "money_per_gallon": 8000.0, "reward": 800000000000.0},
	{"name": "The Atlantic", "total_gallons": 10000000000.0, "money_per_gallon": 15000.0, "reward": 50000000000000.0},
]

var swamp_states: Array = []

# --- Tool Definitions ---
var tool_definitions: Dictionary = {
	"hands": {
		"name": "Hands",
		"base_output": 0.015,
		"cost": 0.0,
		"type": "manual",
		"order": 0
	},
	"spoon": {
		"name": "Spoon",
		"base_output": 0.02,
		"cost": 15.0,
		"type": "manual",
		"order": 1
	},
	"cup": {
		"name": "Cup",
		"base_output": 0.1,
		"cost": 200.0,
		"type": "manual",
		"order": 2
	},
	"bucket": {
		"name": "Bucket",
		"base_output": 0.5,
		"cost": 2000.0,
		"type": "manual",
		"order": 3
	},
	"shovel": {
		"name": "Shovel",
		"base_output": 2.5,
		"cost": 15000.0,
		"type": "manual",
		"order": 4
	},
	"wheelbarrow": {
		"name": "Wheelbarrow",
		"base_output": 12.0,
		"cost": 75000.0,
		"type": "manual",
		"order": 5
	},
	"barrel": {
		"name": "Barrel",
		"base_output": 50.0,
		"cost": 400000.0,
		"type": "manual",
		"order": 6
	},
	"water_wagon": {
		"name": "Water Wagon",
		"base_output": 250.0,
		"cost": 2500000.0,
		"type": "manual",
		"order": 7
	},
	"hose": {
		"name": "Garden Hose",
		"base_output": 2.0,
		"cost": 5000.0,
		"type": "semi_auto",
		"order": 8
	}
}

# Current save-format version. Bump when the save structure changes; SaveManager
# uses this to detect saves written by a NEWER build (Steam Cloud downgrade case).
# v19: pump_levels + saved_at (offline progress).
const SAVE_VERSION: int = 19

# --- Stat Definitions ---
var stat_definitions: Dictionary = {
	# --- Core Stats (cheap, QoL) ---
	"carrying_capacity": {
		"name": "Carrying Capacity",
		"base_value": 1.5,
		"growth_rate": 1.18,
		"scale": "exponential",
		"base_cost": 10.0,
		"cost_exponent": 1.22,
		"format": "gal"
	},
	"movement_speed": {
		"name": "Movement Speed",
		"base_value": 1.0,
		"growth_rate": 1.12,
		"scale": "exponential",
		"base_cost": 12.0,
		"cost_exponent": 1.12,
		"max_level": 8,
		"format": "multiplier"
	},
	"stamina": {
		"name": "Stamina",
		"base_value": 20.0,
		"growth_rate": 1.15,
		"scale": "exponential",
		"base_cost": 10.0,
		"cost_exponent": 1.17,
		"format": "value"
	},
	"stamina_regen": {
		"name": "Stamina Regen",
		"base_value": 3.0,
		"growth_rate": 1.15,
		"scale": "exponential",
		"base_cost": 12.0,
		"cost_exponent": 1.17,
		"format": "per_sec"
	},
	# --- Global Power Stats (slightly pricier, scales faster) ---
	"water_value": {
		"name": "Water Value",
		"base_value": 1.0,
		"growth_rate": 1.12,
		"scale": "exponential",
		"base_cost": 50.0,
		"cost_exponent": 1.45,
		"max_value": 50.0,
		"format": "multiplier"
	},
	"scoop_power": {
		"name": "Scoop Power",
		"base_value": 1.0,
		"growth_rate": 1.12,
		"scale": "exponential",
		"base_cost": 35.0,
		"cost_exponent": 1.40,
		"max_value": 40.0,
		"format": "multiplier"
	}
}

# --- Game State ---
var money: float = 0.0
var current_tool_id: String = "hands"

# --- Prestige State ---
var influence: float = 0.0           # prestige currency; persists through prestige
var lifetime_earnings: float = 0.0   # money earned from SELLING since last prestige
var prestige_count: int = 0
var prestige_upgrades: Dictionary = {"kickback": 0, "muscle": 0, "cap_hike": 0, "war_chest": 0}

var tools_owned: Dictionary = {
	"hands": {"owned": true, "level": 0},
	"spoon": {"owned": false, "level": 0},
	"cup": {"owned": false, "level": 0},
	"bucket": {"owned": false, "level": 0},
	"shovel": {"owned": false, "level": 0},
	"wheelbarrow": {"owned": false, "level": 0},
	"barrel": {"owned": false, "level": 0},
	"water_wagon": {"owned": false, "level": 0},
	"hose": {"owned": false, "level": 0}
}

var stat_levels: Dictionary = {
	"carrying_capacity": 0,
	"movement_speed": 0,
	"stamina": 0,
	"stamina_regen": 0,
	"water_value": 0,
	"scoop_power": 0
}

var current_stamina: float = 10.0

# Carrying water inventory
var water_carried: float = 0.0
var last_scoop_swamp: int = 0
# Actual gallons drained on the most recent successful manual scoop (for honest feedback popups)
var last_scoop_gallons: float = 0.0

# Hose state
var hose_active: bool = false
var hose_timer: float = 0.0
var hose_swamp_index: int = -1
const HOSE_DURATION: float = 20.0

# Cave air ("swamp gas"): the risk/reward clock inside caves. Runs out -> you're
# ejected losing carried water. Each cave pool drained buys more time; collecting
# loot with >50% air left pays a x1.5 Daring Bonus.
const CAVE_AIR_BASE: float = 90.0
const CAVE_AIR_POOL_BONUS: float = 30.0
const CAVE_AIR_LANTERN_BONUS: float = 30.0
var cave_air: float = 0.0
var cave_air_max: float = 0.0

# Camel constants
const CAMEL_BASE_COST: float = 500.0
const CAMEL_COST_EXPONENT: float = 10.0   # 500 / 5K / 50K for camels 1/2/3
const CAMEL_MAX_COUNT: int = 3
const CAMEL_CAPACITY_UPGRADE_BASE: float = 50.0
const CAMEL_SPEED_UPGRADE_BASE: float = 200.0
const CAMEL_UPGRADE_EXPONENT: float = 1.25  # was 1.35 (> value growth = worsening deal)
const CAMEL_SPEED_MAX_LEVEL: int = 8

# Camel state
var camel_unlocked: bool = false  # Unlocked by finding camel in Gator Den cave
var camel_count: int = 0
var camel_capacity_level: int = 0
var camel_speed_level: int = 0
var camel_states: Array = []  # [{state, x, water_carried, source_swamp, state_timer}]

# Upgrade definitions
var upgrade_definitions: Dictionary = {
	"auto_scooper": {
		"name": "Auto-Scooper",
		"description": "Auto scoop near water",
		"cost": 150.0,
		"cost_exponent": 1.25,
		"max_level": -1,
		"order": 0
	},
	"lantern": {
		"name": "Lantern",
		"description": "Light in the dark, +30s cave air",
		"cost": 50.0,
		"cost_exponent": 1.30,
		"max_level": 1,
		"order": 1
	},
	"overflow_valve": {
		"name": "Overflow Valve",
		"description": "Bag full? Scoops auto-sell at 60%",
		"cost": 75000.0,
		"cost_exponent": 1.0,
		"max_level": 1,
		"order": 2
	}
}

# Upgrade state
var upgrades_owned: Dictionary = {
	"auto_scooper": 0,
	"lantern": 0,
	"overflow_valve": 0
}

# --- Pumps (the passive/idle tier) ---
# swamp_index -> pump level (absent = no pump). Pumps drain their pool slowly and
# bank money at wholesale rate; deliberately 5-10x below active play.
var pump_levels: Dictionary = {}
const PUMP_MAX_LEVEL: int = 10
const PUMP_WHOLESALE: float = 0.6            # pumps sell at 60% of manual value
const PUMP_BASE_DRAIN_SECONDS: float = 9000.0  # L1 drains its whole pool in ~2.5h
const PUMP_OFFLINE_CAP_HOURS: float = 8.0
const PUMP_OFFLINE_EFFICIENCY: float = 0.5
# Set by load_save_data when offline pump earnings were granted; consumed by the
# world scene to show a "while you were gone" summary. {seconds, gallons, money}
var offline_summary: Dictionary = {}
var _pump_accum: float = 0.0

# Device preference (not reset with game)
var touch_controls_enabled: bool = false

# --- Cave Definitions ---
const CAVE_DEFINITIONS: Dictionary = {
	"muddy_hollow": {"name": "Muddy Hollow", "swamp_index": 0, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/muddy_hollow.tscn", "order": 0},
	"gator_den": {"name": "Gator Den", "swamp_index": 1, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/gator_den.tscn", "order": 1},
	"the_sinkhole": {"name": "The Sinkhole", "swamp_index": 2, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/the_sinkhole.tscn", "order": 2},
	"collapsed_mine": {"name": "Collapsed Mine", "swamp_index": 3, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/collapsed_mine.tscn", "order": 3},
	"the_mire": {"name": "The Mire", "swamp_index": 4, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/the_mire.tscn", "order": 4},
	"sunken_grotto": {"name": "Sunken Grotto", "swamp_index": 5, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/sunken_grotto.tscn", "order": 5},
	"the_cistern": {"name": "The Cistern", "swamp_index": 6, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/the_cistern.tscn", "order": 6},
	"coral_cavern": {"name": "Coral Cavern", "swamp_index": 7, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/coral_cavern.tscn", "order": 7},
	"the_underdark": {"name": "The Underdark", "swamp_index": 8, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/the_underdark.tscn", "order": 8},
	"mariana_trench": {"name": "Mariana Trench", "swamp_index": 9, "drain_threshold": 0.5, "scene_path": "res://scenes/caves/mariana_trench.tscn", "order": 9},
}

# Cave state
var in_cave: bool = false
var current_cave: String = ""
var cave_data: Dictionary = {
	"muddy_hollow": {"unlocked": false, "entered": false, "loot_collected": {}},
	"gator_den": {"unlocked": false, "entered": false, "loot_collected": {}},
	"the_sinkhole": {"unlocked": false, "entered": false, "loot_collected": {}},
	"collapsed_mine": {"unlocked": false, "entered": false, "loot_collected": {}},
	"the_mire": {"unlocked": false, "entered": false, "loot_collected": {}},
	"sunken_grotto": {"unlocked": false, "entered": false, "loot_collected": {}},
	"the_cistern": {"unlocked": false, "entered": false, "loot_collected": {}},
	"coral_cavern": {"unlocked": false, "entered": false, "loot_collected": {}},
	"the_underdark": {"unlocked": false, "entered": false, "loot_collected": {}},
	"mariana_trench": {"unlocked": false, "entered": false, "loot_collected": {}},
}

# --- Cave Pool Definitions ---
# Each cave has pools that block progression; drain them to reveal loot
var cave_pool_definitions: Dictionary = {
	"muddy_hollow": [
		{"total_gallons": 2.0, "loot_id": "pool_treasure_1"},
	],
	"gator_den": [
		{"total_gallons": 15.0, "loot_id": "pool_treasure_1"},
	],
	"the_sinkhole": [
		{"total_gallons": 80.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 80.0, "loot_id": "pool_treasure_2"},
	],
	"collapsed_mine": [
		{"total_gallons": 500.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 500.0, "loot_id": "pool_treasure_2"},
	],
	"the_mire": [
		{"total_gallons": 3000.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 3000.0, "loot_id": "pool_treasure_2"},
	],
	"sunken_grotto": [
		{"total_gallons": 20000.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 20000.0, "loot_id": "pool_treasure_2"},
	],
	"the_cistern": [
		{"total_gallons": 150000.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 150000.0, "loot_id": "pool_treasure_2"},
		{"total_gallons": 150000.0, "loot_id": "pool_treasure_3"},
	],
	"coral_cavern": [
		{"total_gallons": 1000000.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 1000000.0, "loot_id": "pool_treasure_2"},
		{"total_gallons": 1000000.0, "loot_id": "pool_treasure_3"},
	],
	"the_underdark": [
		{"total_gallons": 8000000.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 8000000.0, "loot_id": "pool_treasure_2"},
		{"total_gallons": 8000000.0, "loot_id": "pool_treasure_3"},
	],
	"mariana_trench": [
		{"total_gallons": 50000000.0, "loot_id": "pool_treasure_1"},
		{"total_gallons": 50000000.0, "loot_id": "pool_treasure_2"},
		{"total_gallons": 50000000.0, "loot_id": "pool_treasure_3"},
	],
}

# Cave pool runtime state: {cave_id: [{gallons_drained, completed}]}
var cave_pool_states: Dictionary = {}

# Day tracking
var current_day: int = 1
var cycle_progress: float = 0.2

func _ready() -> void:
	_init_swamp_states()
	_init_cave_pool_states()

func _init_swamp_states() -> void:
	swamp_states.clear()
	for i in range(swamp_definitions.size()):
		swamp_states.append({"gallons_drained": 0.0, "completed": false})

# --- Computed Properties ---
func get_swamp_count() -> int:
	return swamp_definitions.size()

func get_swamp_water_percent(swamp_index: int) -> float:
	var total: float = swamp_definitions[swamp_index]["total_gallons"]
	var drained: float = swamp_states[swamp_index]["gallons_drained"]
	return clampf((total - drained) / total * 100.0, 0.0, 100.0)

func get_swamp_fill_fraction(swamp_index: int) -> float:
	var total: float = swamp_definitions[swamp_index]["total_gallons"]
	var drained: float = swamp_states[swamp_index]["gallons_drained"]
	return clampf((total - drained) / total, 0.0, 1.0)

func is_swamp_completed(swamp_index: int) -> bool:
	return swamp_states[swamp_index]["completed"]

func get_total_water_percent() -> float:
	var total_gal: float = 0.0
	var total_drained: float = 0.0
	for i in range(swamp_definitions.size()):
		total_gal += swamp_definitions[i]["total_gallons"]
		total_drained += swamp_states[i]["gallons_drained"]
	if total_gal == 0.0:
		return 0.0
	return clampf((total_gal - total_drained) / total_gal * 100.0, 0.0, 100.0)

# Raw tool curve (no global multipliers), the single source of truth for shop
# previews too. Gentle 1.15 growth with a x2 milestone every 10 levels: costs
# grow 1.28/level so payback time lengthens within a tier (soft wall) and the
# L10/L20 milestones give "push to the badge" goals. The old 1.20/1.20 pair
# meant constant payback forever — zero decisions (see full-audit-2026-07).
func get_tool_raw_output_at_level(tool_id: String, level: int) -> float:
	var base: float = tool_definitions[tool_id]["base_output"]
	return base * pow(1.15, level) * pow(2.0, level / 10)

func get_tool_output(tool_id: String) -> float:
	var level: int = tools_owned[tool_id]["level"]
	var raw: float = get_tool_raw_output_at_level(tool_id, level)
	# Apply scoop power multiplier for manual tools; semi-auto (hose) gets the
	# square root so automation benefits from stats without beating manual play
	# (fully excluded, the hose was strictly worse than a mid-tier shovel).
	if tool_definitions[tool_id]["type"] == "manual":
		raw *= get_stat_value("scoop_power")
	elif tool_definitions[tool_id]["type"] == "semi_auto":
		raw *= sqrt(get_stat_value("scoop_power"))
	# Prestige: Muscle boosts all scoop output globally (multiplicative, see Kickback)
	raw *= pow(1.25, prestige_upgrades["muscle"])
	return raw

func get_effective_scoop(tool_id: String) -> float:
	return get_tool_output(tool_id)

# Effective cap for a stat — Prestige Cap Hike raises water_value/scoop_power ceilings
func get_effective_stat_cap(stat_id: String, defn: Dictionary) -> float:
	var base_max: float = defn["max_value"]
	if stat_id == "water_value" or stat_id == "scoop_power":
		return base_max * (1.0 + 0.25 * prestige_upgrades["cap_hike"])
	return base_max

func get_stat_value(stat_id: String) -> float:
	var defn: Dictionary = stat_definitions[stat_id]
	var value: float
	if defn.get("scale", "linear") == "exponential":
		value = defn["base_value"] * pow(defn["growth_rate"], stat_levels[stat_id])
	else:
		value = defn["base_value"] + defn.get("per_level", 0.0) * stat_levels[stat_id]
	if defn.has("max_value"):
		value = minf(value, get_effective_stat_cap(stat_id, defn))
	return value

func get_stat_value_at_level(stat_id: String, level: int) -> float:
	var defn: Dictionary = stat_definitions[stat_id]
	var value: float
	if defn.get("scale", "linear") == "exponential":
		value = defn["base_value"] * pow(defn["growth_rate"], level)
	else:
		value = defn["base_value"] + defn.get("per_level", 0.0) * level
	if defn.has("max_value"):
		value = minf(value, get_effective_stat_cap(stat_id, defn))
	return value

func get_carrying_capacity() -> float:
	var base: float = get_stat_value("carrying_capacity")
	# Floor: always hold a few scoops of the current tool, so big tools never
	# force single-scoop sell trips. (Also the canonical capacity accessor —
	# previously called but undefined, which crashed on the first carry-walk.)
	var tid: String = current_tool_id
	if tool_definitions.has(tid) and tool_definitions[tid]["type"] == "manual":
		return maxf(base, get_tool_output(tid) * 4.0)
	return base

func get_money_multiplier() -> float:
	# Prestige: Kickback boosts all money earned globally. Multiplicative x1.25 per
	# level — additive +8% was noise against the x10-per-pool content scaling.
	return get_stat_value("water_value") * pow(1.25, prestige_upgrades["kickback"])

func get_stamina_cost() -> float:
	return 1.0

func get_max_stamina() -> float:
	return get_stat_value("stamina")

func get_stamina_regen_rate() -> float:
	return get_stat_value("stamina_regen")

func get_movement_speed_multiplier() -> float:
	return get_stat_value("movement_speed")

func get_tool_upgrade_cost(tool_id: String) -> float:
	var base_cost: float = tool_definitions[tool_id]["cost"]
	if base_cost == 0.0:
		base_cost = 10.0
	var level: int = tools_owned[tool_id]["level"]
	return base_cost * pow(1.28, level)

func get_stat_upgrade_cost(stat_id: String) -> float:
	var defn: Dictionary = stat_definitions[stat_id]
	var base_cost: float = defn["base_cost"]
	var exponent: float = defn.get("cost_exponent", 1.15)
	var level: int = stat_levels[stat_id]
	return base_cost * pow(exponent, level)

# --- Internal: drain swamp without earning money ---
func _drain_swamp(swamp_index: int, gallons: float) -> float:
	if gallons <= 0.0 or swamp_index < 0 or swamp_index >= swamp_definitions.size():
		return 0.0
	if swamp_states[swamp_index]["completed"]:
		return 0.0
	var total: float = swamp_definitions[swamp_index]["total_gallons"]
	var remaining: float = total - swamp_states[swamp_index]["gallons_drained"]
	var actual: float = minf(gallons, remaining)
	if actual <= 0.0:
		return 0.0
	swamp_states[swamp_index]["gallons_drained"] += actual
	water_level_changed.emit(swamp_index, get_swamp_water_percent(swamp_index))
	check_cave_unlocks(swamp_index)

	if swamp_states[swamp_index]["gallons_drained"] >= total and not swamp_states[swamp_index]["completed"]:
		swamp_states[swamp_index]["completed"] = true
		var reward: float = swamp_definitions[swamp_index]["reward"]
		if reward > 0.0:
			money += reward
			lifetime_earnings += reward
			money_changed.emit(money)
		swamp_completed.emit(swamp_index, reward)

	return actual

# --- Pumps ---
func get_pump_level(swamp_index: int) -> int:
	return pump_levels.get(swamp_index, 0)

func is_pump_available(swamp_index: int) -> bool:
	# Same progression rule as the pools themselves: first pool always, later
	# pools once the previous one is drained.
	if swamp_index <= 0:
		return true
	return is_swamp_completed(swamp_index - 1)

func get_pump_cost(swamp_index: int) -> float:
	# L1 costs ~10% of the pool's total water value; each level x1.5.
	var d: Dictionary = swamp_definitions[swamp_index]
	var base: float = d["total_gallons"] * d["money_per_gallon"] * 0.10
	if prestige_count >= 1:
		base *= 0.5  # "Federal Infrastructure Grant" — prestige perk
	return base * pow(1.5, get_pump_level(swamp_index))

func get_pump_rate(swamp_index: int) -> float:
	var level: int = get_pump_level(swamp_index)
	if level <= 0:
		return 0.0
	return swamp_definitions[swamp_index]["total_gallons"] / PUMP_BASE_DRAIN_SECONDS \
		* pow(1.25, level - 1)

func buy_pump(swamp_index: int) -> bool:
	if not is_pump_available(swamp_index):
		return false
	if get_pump_level(swamp_index) >= PUMP_MAX_LEVEL:
		return false
	if is_swamp_completed(swamp_index):
		return false
	var cost: float = get_pump_cost(swamp_index)
	if money < cost:
		return false
	money -= cost
	pump_levels[swamp_index] = get_pump_level(swamp_index) + 1
	money_changed.emit(money)
	pump_changed.emit(swamp_index, pump_levels[swamp_index])
	return true

# Run all pumps for `seconds` of game time (efficiency < 1 for offline catch-up).
# Returns {gallons, money}. _drain_swamp handles level signals + completion.
func _run_pumps(seconds: float, efficiency: float = 1.0) -> Dictionary:
	var total_g: float = 0.0
	var total_m: float = 0.0
	for idx in pump_levels.keys():
		if swamp_states[idx]["completed"]:
			continue
		var actual: float = _drain_swamp(idx, get_pump_rate(idx) * seconds * efficiency)
		if actual > 0.0:
			var earned: float = actual * swamp_definitions[idx]["money_per_gallon"] \
				* get_money_multiplier() * PUMP_WHOLESALE
			money += earned
			lifetime_earnings += earned
			total_g += actual
			total_m += earned
	if total_m > 0.0:
		money_changed.emit(money)
	return {"gallons": total_g, "money": total_m}

# --- Actions ---
# drain_water: used by hose and pump (earns money directly)
func drain_water(swamp_index: int, gallons: float) -> void:
	var actual: float = _drain_swamp(swamp_index, gallons)
	if actual > 0.0:
		var mpg: float = swamp_definitions[swamp_index]["money_per_gallon"] * get_money_multiplier()
		var earned: float = actual * mpg
		money += earned
		money_changed.emit(money)
		scoop_performed.emit(swamp_index, actual, earned)

# try_scoop: manual scooping fills player inventory (no instant money)
func try_scoop(swamp_index: int) -> bool:
	var stamina_cost: float = get_stamina_cost()
	if current_stamina < stamina_cost:
		return false
	if swamp_index < 0 or swamp_index >= swamp_definitions.size():
		return false
	if swamp_states[swamp_index]["completed"]:
		return false
	if tool_definitions[current_tool_id]["type"] == "semi_auto":
		return false

	var capacity: float = get_carrying_capacity()
	var remaining_space: float = capacity - water_carried
	if remaining_space <= 0.001:
		# Overflow Valve: a full bag vents incoming scoops as instant 60% sales
		# instead of hard-stopping play. Walking it to a sell point stays optimal.
		if upgrades_owned.get("overflow_valve", 0) > 0:
			var vent_amount: float = get_tool_output(current_tool_id)
			current_stamina -= stamina_cost
			stamina_changed.emit(current_stamina, get_max_stamina())
			var vented: float = _drain_swamp(swamp_index, vent_amount)
			if vented > 0.0:
				var earned: float = vented * swamp_definitions[swamp_index]["money_per_gallon"] \
					* get_money_multiplier() * 0.6
				money += earned
				lifetime_earnings += earned
				last_scoop_swamp = swamp_index
				last_scoop_gallons = vented
				money_changed.emit(money)
				scoop_performed.emit(swamp_index, vented, earned)
			return vented > 0.0
		return false

	var tool_output: float = get_tool_output(current_tool_id)
	var scoop_amount: float = minf(tool_output, remaining_space)

	current_stamina -= stamina_cost
	stamina_changed.emit(current_stamina, get_max_stamina())

	var actual: float = _drain_swamp(swamp_index, scoop_amount)
	if actual > 0.0:
		water_carried += actual
		last_scoop_swamp = swamp_index
		last_scoop_gallons = actual
		water_carried_changed.emit(water_carried, capacity)
		scoop_performed.emit(swamp_index, actual, 0.0)
	return actual > 0.0

# sell_water: convert carried water to money (at sell point)
func sell_water() -> float:
	if water_carried <= 0.0001:
		return 0.0
	var base_mpg: float = swamp_definitions[last_scoop_swamp]["money_per_gallon"]
	var mpg: float = base_mpg * get_money_multiplier()
	var earned: float = water_carried * mpg
	money += earned
	lifetime_earnings += earned
	water_carried = 0.0
	money_changed.emit(money)
	water_carried_changed.emit(0.0, get_carrying_capacity())
	if earned > 0.0:
		water_sold.emit(earned)
	return earned

func is_inventory_full() -> bool:
	var capacity: float = get_carrying_capacity()
	return water_carried >= capacity - 0.0001

func try_activate_hose(swamp_index: int) -> bool:
	if current_tool_id != "hose":
		return false
	if not tools_owned["hose"]["owned"]:
		return false
	if hose_active:
		return false
	if swamp_index < 0 or swamp_index >= swamp_definitions.size():
		return false
	if swamp_states[swamp_index]["completed"]:
		return false
	hose_active = true
	hose_timer = HOSE_DURATION
	hose_swamp_index = swamp_index
	hose_state_changed.emit(true, hose_timer)
	return true

func buy_tool(tool_id: String) -> bool:
	if tools_owned[tool_id]["owned"]:
		return false
	var cost: float = tool_definitions[tool_id]["cost"]
	if money < cost:
		return false
	money -= cost
	tools_owned[tool_id]["owned"] = true
	money_changed.emit(money)
	return true

func equip_tool(tool_id: String) -> void:
	if tools_owned[tool_id]["owned"]:
		current_tool_id = tool_id
		tool_changed.emit(tool_definitions[tool_id])

func upgrade_tool(tool_id: String) -> bool:
	if not tools_owned[tool_id]["owned"]:
		return false
	var cost: float = get_tool_upgrade_cost(tool_id)
	if money < cost:
		return false
	money -= cost
	tools_owned[tool_id]["level"] += 1
	money_changed.emit(money)
	tool_upgraded.emit(tool_id, tools_owned[tool_id]["level"])
	return true

func is_stat_maxed(stat_id: String) -> bool:
	var defn: Dictionary = stat_definitions[stat_id]
	var ml: int = defn.get("max_level", -1)
	if ml >= 0 and stat_levels[stat_id] >= ml:
		return true
	# Also maxed if at the (prestige-boosted) max_value cap
	if defn.has("max_value"):
		var cur: float = get_stat_value(stat_id)
		if cur >= get_effective_stat_cap(stat_id, defn) - 0.001:
			return true
	return false

func upgrade_stat(stat_id: String) -> bool:
	if is_stat_maxed(stat_id):
		return false
	var cost: float = get_stat_upgrade_cost(stat_id)
	if money < cost:
		return false
	money -= cost
	stat_levels[stat_id] += 1
	money_changed.emit(money)
	stat_upgraded.emit(stat_id, stat_levels[stat_id])
	if stat_id == "stamina":
		current_stamina = get_max_stamina()
		stamina_changed.emit(current_stamina, get_max_stamina())
	return true

# --- Camel computed ---
func get_camel_cost() -> float:
	return CAMEL_BASE_COST * pow(CAMEL_COST_EXPONENT, camel_count)

func get_camel_capacity() -> float:
	# Scales with the player's own capacity (25% of it) so camels never become
	# obsolete relics (a fixed 1 gal base was dead on arrival by mid-game).
	var base: float = maxf(get_stat_value("carrying_capacity") * 0.25, 1.0)
	return base * pow(1.25, camel_capacity_level)

func get_camel_speed() -> float:
	return 35.0 * pow(1.20, camel_speed_level)

func get_camel_capacity_upgrade_cost() -> float:
	return CAMEL_CAPACITY_UPGRADE_BASE * pow(CAMEL_UPGRADE_EXPONENT, camel_capacity_level)

func get_camel_speed_upgrade_cost() -> float:
	return CAMEL_SPEED_UPGRADE_BASE * pow(CAMEL_UPGRADE_EXPONENT, camel_speed_level)

# --- Upgrade computed ---
func get_upgrade_cost(upgrade_id: String) -> float:
	var defn: Dictionary = upgrade_definitions[upgrade_id]
	var level: int = upgrades_owned[upgrade_id]
	return defn["cost"] * pow(defn["cost_exponent"], level)

func get_auto_scoop_interval() -> float:
	var level: int = upgrades_owned["auto_scooper"]
	# Always active: base 2.5s, each upgrade level reduces by ~8%, min 0.5s
	return maxf(2.5 * pow(0.92, level), 0.5)

func get_lantern_radius() -> float:
	if upgrades_owned["lantern"] <= 0:
		return 0.0
	return 200.0

func get_lantern_energy() -> float:
	if upgrades_owned["lantern"] <= 0:
		return 0.0
	return 3.0

func get_darkness_factor() -> float:
	if in_cave:
		return 1.0
	var t: float = cycle_progress
	# Mirror _get_cycle_color breakpoints: full day 0.22-0.55, full night 0.75-1.0/0.0-0.1
	# Darkness = how far from noon brightness (1.0 = full night, 0.0 = full day)
	if t < 0.1:
		return 1.0
	elif t < 0.22:
		return lerpf(1.0, 0.0, (t - 0.1) / 0.12)
	elif t < 0.55:
		return 0.0
	elif t < 0.68:
		return lerpf(0.0, 1.0, (t - 0.55) / 0.13)
	else:
		return 1.0

func is_upgrade_maxed(upgrade_id: String) -> bool:
	var defn: Dictionary = upgrade_definitions[upgrade_id]
	if defn["max_level"] < 0:
		return false
	return upgrades_owned[upgrade_id] >= defn["max_level"]

# --- Upgrade actions ---
func buy_upgrade(upgrade_id: String) -> bool:
	if is_upgrade_maxed(upgrade_id):
		return false
	var cost: float = get_upgrade_cost(upgrade_id)
	if money < cost:
		return false
	money -= cost
	upgrades_owned[upgrade_id] += 1
	money_changed.emit(money)
	upgrade_changed.emit()
	return true

# --- Camel actions ---
func buy_camel() -> bool:
	if not camel_unlocked or camel_count >= CAMEL_MAX_COUNT:
		return false
	var cost: float = get_camel_cost()
	if money < cost:
		return false
	money -= cost
	camel_count += 1
	camel_states.append({"state": "to_player", "x": 30.0, "water_carried": 0.0, "source_swamp": 0, "state_timer": 0.0})
	money_changed.emit(money)
	camel_changed.emit()
	return true

func upgrade_camel_capacity() -> bool:
	if camel_count <= 0:
		return false
	var cost: float = get_camel_capacity_upgrade_cost()
	if money < cost:
		return false
	money -= cost
	camel_capacity_level += 1
	money_changed.emit(money)
	camel_changed.emit()
	return true

func upgrade_camel_speed() -> bool:
	if camel_count <= 0:
		return false
	if camel_speed_level >= CAMEL_SPEED_MAX_LEVEL:
		return false
	var cost: float = get_camel_speed_upgrade_cost()
	if money < cost:
		return false
	money -= cost
	camel_speed_level += 1
	money_changed.emit(money)
	camel_changed.emit()
	return true

func camel_take_water(index: int) -> void:
	if index < 0 or index >= camel_states.size():
		return
	var capacity: float = get_camel_capacity()
	var take_amount: float = minf(water_carried, capacity)
	if take_amount <= 0.0001:
		return
	camel_states[index]["water_carried"] = take_amount
	camel_states[index]["source_swamp"] = last_scoop_swamp
	water_carried -= take_amount
	water_carried_changed.emit(water_carried, get_carrying_capacity())

func camel_sell_water(index: int) -> float:
	if index < 0 or index >= camel_states.size():
		return 0.0
	var carried: float = camel_states[index]["water_carried"]
	if carried <= 0.0001:
		return 0.0
	var swamp_idx: int = camel_states[index]["source_swamp"]
	var base_mpg: float = swamp_definitions[swamp_idx]["money_per_gallon"]
	var mpg: float = base_mpg * get_money_multiplier()
	var earned: float = carried * mpg
	money += earned
	lifetime_earnings += earned
	camel_states[index]["water_carried"] = 0.0
	money_changed.emit(money)
	if earned > 0.0:
		water_sold.emit(earned)
	return earned

func _init_camel_states() -> void:
	camel_states.clear()
	for i in range(camel_count):
		camel_states.append({"state": "to_player", "x": 30.0, "water_carried": 0.0, "source_swamp": 0, "state_timer": 0.0})

# --- Cave Functions ---
func check_cave_unlocks(swamp_index: int = -1) -> void:
	for cave_id: String in CAVE_DEFINITIONS:
		var defn: Dictionary = CAVE_DEFINITIONS[cave_id]
		if cave_data[cave_id]["unlocked"]:
			continue
		var si: int = defn["swamp_index"]
		if swamp_index >= 0 and si != swamp_index:
			continue
		var fill: float = get_swamp_fill_fraction(si)
		if fill <= defn["drain_threshold"]:
			cave_data[cave_id]["unlocked"] = true
			cave_unlocked.emit(cave_id)

func is_cave_unlocked(cave_id: String) -> bool:
	return cave_data.get(cave_id, {}).get("unlocked", false)

func enter_cave(cave_id: String) -> void:
	in_cave = true
	current_cave = cave_id
	cave_data[cave_id]["entered"] = true
	cave_air_max = CAVE_AIR_BASE + (CAVE_AIR_LANTERN_BONUS if upgrades_owned["lantern"] > 0 else 0.0)
	cave_air = cave_air_max
	cave_air_changed.emit(cave_air, cave_air_max)
	cave_entered.emit(cave_id)

func exit_cave() -> void:
	var old_cave: String = current_cave
	in_cave = false
	current_cave = ""
	cave_exited.emit(old_cave)

func collect_loot(cave_id: String, loot_id: String, reward_text: String) -> void:
	if not cave_data.has(cave_id):
		return
	cave_data[cave_id]["loot_collected"][loot_id] = true
	loot_collected.emit(cave_id, loot_id, reward_text)

# All loot money flows through here so the Daring Bonus applies and loot counts
# toward lifetime earnings (it previously bypassed prestige entirely).
func grant_loot_money(amount: float) -> Dictionary:
	var daring: bool = in_cave and cave_air_max > 0.0 and cave_air > cave_air_max * 0.5
	var final: float = amount * (1.5 if daring else 1.0)
	money += final
	lifetime_earnings += final
	money_changed.emit(money)
	return {"amount": final, "daring": daring}

func is_loot_collected(cave_id: String, loot_id: String) -> bool:
	if not cave_data.has(cave_id):
		return false
	return cave_data[cave_id]["loot_collected"].get(loot_id, false)

# --- Cave Pool Functions ---
func _init_cave_pool_states() -> void:
	cave_pool_states.clear()
	for cave_id: String in cave_pool_definitions:
		var pools: Array = cave_pool_definitions[cave_id]
		var states: Array = []
		for i in range(pools.size()):
			states.append({"gallons_drained": 0.0, "completed": false})
		cave_pool_states[cave_id] = states

func get_cave_pool_fill_fraction(cave_id: String, pool_index: int) -> float:
	if not cave_pool_definitions.has(cave_id):
		return 0.0
	var pools: Array = cave_pool_definitions[cave_id]
	if pool_index < 0 or pool_index >= pools.size():
		return 0.0
	var total: float = pools[pool_index]["total_gallons"]
	var drained: float = cave_pool_states[cave_id][pool_index]["gallons_drained"]
	return clampf((total - drained) / total, 0.0, 1.0)

func is_cave_pool_completed(cave_id: String, pool_index: int) -> bool:
	if not cave_pool_states.has(cave_id):
		return false
	if pool_index < 0 or pool_index >= cave_pool_states[cave_id].size():
		return false
	return cave_pool_states[cave_id][pool_index]["completed"]

func _drain_cave_pool(cave_id: String, pool_index: int, gallons: float) -> float:
	if gallons <= 0.0:
		return 0.0
	if not cave_pool_definitions.has(cave_id):
		return 0.0
	var pools: Array = cave_pool_definitions[cave_id]
	if pool_index < 0 or pool_index >= pools.size():
		return 0.0
	if cave_pool_states[cave_id][pool_index]["completed"]:
		return 0.0
	var total: float = pools[pool_index]["total_gallons"]
	var remaining: float = total - cave_pool_states[cave_id][pool_index]["gallons_drained"]
	var actual: float = minf(gallons, remaining)
	if actual <= 0.0:
		return 0.0
	cave_pool_states[cave_id][pool_index]["gallons_drained"] += actual
	var fill: float = get_cave_pool_fill_fraction(cave_id, pool_index)
	cave_pool_level_changed.emit(cave_id, pool_index, fill)
	if cave_pool_states[cave_id][pool_index]["gallons_drained"] >= total:
		cave_pool_states[cave_id][pool_index]["completed"] = true
		# Draining a cave pool releases trapped air pockets — buys more gas time.
		if in_cave:
			cave_air += CAVE_AIR_POOL_BONUS
			cave_air_max = maxf(cave_air_max, cave_air)
			cave_air_changed.emit(cave_air, cave_air_max)
		cave_pool_completed.emit(cave_id, pool_index)
	return actual

func try_scoop_cave_pool(cave_id: String, pool_index: int) -> bool:
	var stamina_cost: float = get_stamina_cost()
	if current_stamina < stamina_cost:
		return false
	if not cave_pool_definitions.has(cave_id):
		return false
	var pools: Array = cave_pool_definitions[cave_id]
	if pool_index < 0 or pool_index >= pools.size():
		return false
	if cave_pool_states[cave_id][pool_index]["completed"]:
		return false
	if tool_definitions[current_tool_id]["type"] == "semi_auto":
		return false

	var capacity: float = get_carrying_capacity()
	var remaining_space: float = capacity - water_carried
	if remaining_space <= 0.001:
		return false

	var tool_output: float = get_tool_output(current_tool_id)
	var scoop_amount: float = minf(tool_output, remaining_space)

	current_stamina -= stamina_cost
	stamina_changed.emit(current_stamina, get_max_stamina())

	var actual: float = _drain_cave_pool(cave_id, pool_index, scoop_amount)
	if actual > 0.0:
		water_carried += actual
		# Use the associated overworld pool's money_per_gallon rate
		var swamp_index: int = CAVE_DEFINITIONS[cave_id]["swamp_index"]
		last_scoop_swamp = swamp_index
		last_scoop_gallons = actual
		water_carried_changed.emit(water_carried, capacity)
		scoop_performed.emit(swamp_index, actual, 0.0)
	return actual > 0.0

# --- Prestige ---
func get_pending_influence() -> int:
	return int(floor(sqrt(lifetime_earnings / PRESTIGE_SCALE)))

func can_prestige() -> bool:
	return get_pending_influence() >= 1

func get_war_chest_seed() -> float:
	var level: int = prestige_upgrades["war_chest"]
	if level == 0:
		return 0.0
	# $500 doubling per level ($50 bought less than one drained Puddle) — plus
	# starter tools granted in prestige() so a new run skips the worst grind.
	return 500.0 * pow(2.0, level - 1)

func get_prestige_upgrade_cost(key: String) -> int:
	var bases: Dictionary = {"kickback": 1, "muscle": 1, "cap_hike": 2, "war_chest": 1}
	var level: int = prestige_upgrades[key]
	return int(floor(bases[key] * pow(1.5, level)))

func buy_prestige_upgrade(key: String) -> bool:
	if not prestige_upgrades.has(key):
		return false
	var cost: int = get_prestige_upgrade_cost(key)
	if influence < cost:
		return false
	influence -= cost
	prestige_upgrades[key] += 1
	prestige_changed.emit()
	return true

func prestige() -> void:
	if not can_prestige():
		return
	influence += get_pending_influence()
	prestige_count += 1
	lifetime_earnings = 0.0
	# Partial reset: keep influence, prestige_upgrades, prestige_count, touch_controls.
	# Seed starting money from War Chest upgrade.
	_reset_progression(get_war_chest_seed())
	# War Chest also fronts starter tools: L1+ Spoon, L2+ Cup, L3+ Bucket.
	var wc: int = prestige_upgrades["war_chest"]
	var starter_tools: Array = ["spoon", "cup", "bucket"]
	for i in range(mini(wc, starter_tools.size())):
		tools_owned[starter_tools[i]]["owned"] = true
	prestige_changed.emit()
	prestige_performed.emit()

# Shared progression reset used by both reset_game() and prestige().
func _reset_progression(start_money: float) -> void:
	money = start_money
	current_tool_id = "hands"
	tools_owned = {
		"hands": {"owned": true, "level": 0},
		"spoon": {"owned": false, "level": 0},
		"cup": {"owned": false, "level": 0},
		"bucket": {"owned": false, "level": 0},
		"shovel": {"owned": false, "level": 0},
		"wheelbarrow": {"owned": false, "level": 0},
		"barrel": {"owned": false, "level": 0},
		"water_wagon": {"owned": false, "level": 0},
		"hose": {"owned": false, "level": 0}
	}
	stat_levels = {
		"carrying_capacity": 0,
		"movement_speed": 0,
		"stamina": 0,
		"stamina_regen": 0,
		"water_value": 0,
		"scoop_power": 0
	}
	current_stamina = get_max_stamina()
	water_carried = 0.0
	last_scoop_swamp = 0
	pump_levels.clear()
	hose_active = false
	hose_timer = 0.0
	hose_swamp_index = -1
	camel_unlocked = false
	camel_count = 0
	camel_capacity_level = 0
	camel_speed_level = 0
	camel_states.clear()
	upgrades_owned = {
		"auto_scooper": 0,
		"lantern": 0,
		"overflow_valve": 0
	}
	current_day = 1
	cycle_progress = 0.2
	in_cave = false
	current_cave = ""
	cave_data = {
		"muddy_hollow": {"unlocked": false, "entered": false, "loot_collected": {}},
		"gator_den": {"unlocked": false, "entered": false, "loot_collected": {}},
		"the_sinkhole": {"unlocked": false, "entered": false, "loot_collected": {}},
		"collapsed_mine": {"unlocked": false, "entered": false, "loot_collected": {}},
		"the_mire": {"unlocked": false, "entered": false, "loot_collected": {}},
		"sunken_grotto": {"unlocked": false, "entered": false, "loot_collected": {}},
		"the_cistern": {"unlocked": false, "entered": false, "loot_collected": {}},
		"coral_cavern": {"unlocked": false, "entered": false, "loot_collected": {}},
		"the_underdark": {"unlocked": false, "entered": false, "loot_collected": {}},
		"mariana_trench": {"unlocked": false, "entered": false, "loot_collected": {}},
	}
	_init_swamp_states()
	_init_cave_pool_states()

	# Emit all signals to update UI
	money_changed.emit(money)
	for i in range(swamp_definitions.size()):
		water_level_changed.emit(i, get_swamp_water_percent(i))
	stamina_changed.emit(current_stamina, get_max_stamina())
	tool_changed.emit(tool_definitions[current_tool_id])
	hose_state_changed.emit(false, 0.0)
	water_carried_changed.emit(0.0, get_carrying_capacity())
	camel_changed.emit()
	upgrade_changed.emit()
	day_changed.emit(current_day)

# Full restart: wipe everything including prestige progress.
func reset_game() -> void:
	influence = 0.0
	lifetime_earnings = 0.0
	prestige_count = 0
	prestige_upgrades = {"kickback": 0, "muscle": 0, "cap_hike": 0, "war_chest": 0}
	_reset_progression(0.0)
	prestige_changed.emit()

func regen_stamina(delta: float) -> void:
	var max_stam: float = get_max_stamina()
	if current_stamina < max_stam:
		var rate: float = get_stamina_regen_rate()
		current_stamina = minf(current_stamina + rate * delta, max_stam)
		stamina_changed.emit(current_stamina, max_stam)

func _process(delta: float) -> void:
	# Cave air drains while inside a cave; depletion ejects the player (handled
	# by the cave scene via cave_air_depleted).
	if in_cave and cave_air > 0.0:
		cave_air = maxf(cave_air - delta, 0.0)
		cave_air_changed.emit(cave_air, cave_air_max)
		if cave_air <= 0.0:
			cave_air_depleted.emit()

	# Pumps tick in 1s batches to keep water_level_changed signal traffic low
	# (each emission reshapes pool polygons in the world).
	if not pump_levels.is_empty():
		_pump_accum += delta
		if _pump_accum >= 1.0:
			_run_pumps(_pump_accum)
			_pump_accum = 0.0

	# Hose fills water_carried (like manual scooping, player must sell at shop)
	if hose_active:
		hose_timer -= delta
		if hose_timer <= 0.0:
			hose_active = false
			hose_timer = 0.0
			hose_swamp_index = -1
			hose_state_changed.emit(false, 0.0)
		else:
			if hose_swamp_index >= 0 and hose_swamp_index < swamp_definitions.size():
				if swamp_states[hose_swamp_index]["completed"]:
					hose_active = false
					hose_timer = 0.0
					hose_swamp_index = -1
					hose_state_changed.emit(false, 0.0)
				else:
					var capacity: float = get_carrying_capacity()
					var remaining_space: float = capacity - water_carried
					if remaining_space <= 0.001:
						hose_active = false
						hose_timer = 0.0
						hose_swamp_index = -1
						hose_state_changed.emit(false, 0.0)
					else:
						var gallons: float = minf(get_tool_output("hose") * delta, remaining_space)
						var actual: float = _drain_swamp(hose_swamp_index, gallons)
						if actual > 0.0:
							water_carried += actual
							last_scoop_swamp = hose_swamp_index
							water_carried_changed.emit(water_carried, capacity)
						hose_state_changed.emit(true, hose_timer)

func get_save_data() -> Dictionary:
	var swamp_save: Array = []
	for state in swamp_states:
		swamp_save.append({"gallons_drained": state["gallons_drained"], "completed": state["completed"]})
	var cave_pool_save: Dictionary = {}
	for cave_id: String in cave_pool_states:
		var pools: Array = []
		for state in cave_pool_states[cave_id]:
			pools.append({"gallons_drained": state["gallons_drained"], "completed": state["completed"]})
		cave_pool_save[cave_id] = pools

	var pump_save: Dictionary = {}
	for pk in pump_levels.keys():
		pump_save[str(pk)] = pump_levels[pk]

	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"pump_levels": pump_save,
		"money": money,
		"influence": influence,
		"lifetime_earnings": lifetime_earnings,
		"prestige_count": prestige_count,
		"prestige_upgrades": prestige_upgrades.duplicate(true),
		"current_tool_id": current_tool_id,
		"tools_owned": tools_owned.duplicate(true),
		"stat_levels": stat_levels.duplicate(true),
		"current_stamina": current_stamina,
		"water_carried": water_carried,
		"last_scoop_swamp": last_scoop_swamp,
		"swamp_states": swamp_save,
		"current_day": current_day,
		"camel_unlocked": camel_unlocked,
		"camel_count": camel_count,
		"camel_capacity_level": camel_capacity_level,
		"camel_speed_level": camel_speed_level,
		"upgrades_owned": upgrades_owned.duplicate(true),
		"cave_data": cave_data.duplicate(true),
		"cave_pool_states": cave_pool_save,
		"cycle_progress": cycle_progress,
		"touch_controls_enabled": touch_controls_enabled
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", 0.0)
	influence = data.get("influence", 0.0)
	lifetime_earnings = data.get("lifetime_earnings", 0.0)
	prestige_count = int(data.get("prestige_count", 0))
	if data.has("prestige_upgrades"):
		for key in data["prestige_upgrades"]:
			var k: String = key
			if prestige_upgrades.has(k):
				prestige_upgrades[k] = int(data["prestige_upgrades"][k])
	current_tool_id = data.get("current_tool_id", "hands")
	if data.has("tools_owned"):
		for key in data["tools_owned"]:
			var k: String = key
			if tools_owned.has(k):
				tools_owned[k] = data["tools_owned"][k]
	if data.has("stat_levels"):
		for key in data["stat_levels"]:
			var k: String = key
			if stat_levels.has(k):
				stat_levels[k] = data["stat_levels"][k]
	current_stamina = data.get("current_stamina", get_max_stamina())
	water_carried = data.get("water_carried", 0.0)
	last_scoop_swamp = int(data.get("last_scoop_swamp", 0))

	current_day = int(data.get("current_day", 1))
	cycle_progress = float(data.get("cycle_progress", 0.2))

	# Load swamp states
	if data.has("swamp_states"):
		var saved_swamps: Array = data["swamp_states"]
		for i in range(mini(saved_swamps.size(), swamp_states.size())):
			swamp_states[i]["gallons_drained"] = saved_swamps[i].get("gallons_drained", 0.0)
			swamp_states[i]["completed"] = saved_swamps[i].get("completed", false)
	elif data.has("gallons_drained"):
		var old_drained: float = data["gallons_drained"]
		swamp_states[0]["gallons_drained"] = minf(old_drained, swamp_definitions[0]["total_gallons"])
		if swamp_states[0]["gallons_drained"] >= swamp_definitions[0]["total_gallons"]:
			swamp_states[0]["completed"] = true

	# Camels
	camel_unlocked = data.get("camel_unlocked", false)
	camel_count = int(data.get("camel_count", 0))
	camel_capacity_level = int(data.get("camel_capacity_level", 0))
	camel_speed_level = int(data.get("camel_speed_level", 0))
	# Migration: old saves — unlock camel if they own one, Marsh done, or found cave loot
	if not camel_unlocked and (camel_count > 0 or is_swamp_completed(2) or is_loot_collected("gator_den", "gator_camel")):
		camel_unlocked = true
	_init_camel_states()

	# Upgrades
	if data.has("upgrades_owned"):
		for key in data["upgrades_owned"]:
			var k: String = key
			if upgrades_owned.has(k):
				upgrades_owned[k] = int(data["upgrades_owned"][k])

	# Cave data
	if data.has("cave_data"):
		for key in data["cave_data"]:
			var k: String = key
			if cave_data.has(k):
				var saved: Dictionary = data["cave_data"][k]
				cave_data[k]["unlocked"] = saved.get("unlocked", false)
				cave_data[k]["entered"] = saved.get("entered", false)
				if saved.has("loot_collected"):
					cave_data[k]["loot_collected"] = saved["loot_collected"].duplicate()

	# Cave pool states
	if data.has("cave_pool_states"):
		for key in data["cave_pool_states"]:
			var k: String = key
			if cave_pool_states.has(k):
				var saved_pools: Array = data["cave_pool_states"][k]
				for i in range(mini(saved_pools.size(), cave_pool_states[k].size())):
					cave_pool_states[k][i]["gallons_drained"] = saved_pools[i].get("gallons_drained", 0.0)
					cave_pool_states[k][i]["completed"] = saved_pools[i].get("completed", false)

	# Device preference
	touch_controls_enabled = data.get("touch_controls_enabled", false)

	# Pumps (JSON stringifies int keys — convert back)
	pump_levels.clear()
	var pump_save: Dictionary = data.get("pump_levels", {})
	for pk in pump_save.keys():
		var idx: int = int(pk)
		if idx >= 0 and idx < swamp_definitions.size():
			pump_levels[idx] = int(pump_save[pk])

	# Offline pump progress: capped hours at reduced efficiency, summarized for
	# the world scene to announce.
	var saved_at: float = float(data.get("saved_at", 0.0))
	if saved_at > 0.0 and not pump_levels.is_empty():
		var away: float = clampf(Time.get_unix_time_from_system() - saved_at,
			0.0, PUMP_OFFLINE_CAP_HOURS * 3600.0)
		if away > 60.0:
			var res: Dictionary = _run_pumps(away, PUMP_OFFLINE_EFFICIENCY)
			if res["money"] > 0.0:
				offline_summary = {"seconds": away, "gallons": res["gallons"], "money": res["money"]}

	# Version migration
	var save_version: int = int(data.get("version", 1))
	if save_version < 14:
		# Swamp sizes changed — clamp drained to new caps
		for i in range(swamp_states.size()):
			var cap: float = swamp_definitions[i]["total_gallons"]
			swamp_states[i]["gallons_drained"] = minf(swamp_states[i]["gallons_drained"], cap)
			swamp_states[i]["completed"] = swamp_states[i]["gallons_drained"] >= cap
		# Migrate the_abyss cave data to the_mire
		if cave_data.has("the_mire") and not cave_data["the_mire"]["unlocked"]:
			var old_abyss: Dictionary = data.get("cave_data", {}).get("the_abyss", {})
			if old_abyss.get("unlocked", false):
				cave_data["the_mire"]["unlocked"] = true
				cave_data["the_mire"]["entered"] = old_abyss.get("entered", false)
				if old_abyss.has("loot_collected"):
					cave_data["the_mire"]["loot_collected"] = old_abyss["loot_collected"].duplicate()

	# Emit signals
	money_changed.emit(money)
	for i in range(swamp_definitions.size()):
		water_level_changed.emit(i, get_swamp_water_percent(i))
	stamina_changed.emit(current_stamina, get_max_stamina())
	tool_changed.emit(tool_definitions[current_tool_id])
	water_carried_changed.emit(water_carried, get_carrying_capacity())
	camel_changed.emit()
	upgrade_changed.emit()
