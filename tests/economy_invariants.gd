extends SceneTree
# Headless economy invariants. Run with:
#   godot --headless --audio-driver Dummy -s tests/economy_invariants.gd
# Exits 0 on pass, 1 on failure. Guards against the 1.20/1.20 flat-treadmill
# class of bug that silently shipped once already (see full-audit-2026-07).

func _init() -> void:
	var failures: Array = []
	var gm: Node = load("res://scripts/autoload/game_manager.gd").new()
	# _ready never runs off-tree; init the per-pool state manually.
	gm._init_swamp_states()
	gm._init_cave_pool_states()

	# 1. Tool payback must LENGTHEN across every 10-level window (cost growth must
	#    outpace output growth including the x2 milestone), for every tool.
	for tool_id in gm.tool_definitions.keys():
		for l0 in range(0, 31, 5):
			var out_ratio: float = gm.get_tool_raw_output_at_level(tool_id, l0 + 10) \
				/ gm.get_tool_raw_output_at_level(tool_id, l0)
			gm.tools_owned[tool_id]["level"] = l0
			var cost_a: float = gm.get_tool_upgrade_cost(tool_id)
			gm.tools_owned[tool_id]["level"] = l0 + 10
			var cost_b: float = gm.get_tool_upgrade_cost(tool_id)
			gm.tools_owned[tool_id]["level"] = 0
			if cost_b / cost_a <= out_ratio:
				failures.append("%s: cost x%.2f <= output x%.2f over L%d..L%d (treadmill!)"
					% [tool_id, cost_b / cost_a, out_ratio, l0, l0 + 10])

	# 2. Milestone levels must actually spike output (x2 on top of base growth).
	var spike: float = gm.get_tool_raw_output_at_level("spoon", 10) \
		/ gm.get_tool_raw_output_at_level("spoon", 9)
	if spike < 2.0:
		failures.append("spoon L10 milestone spike is x%.2f, expected >= x2" % spike)

	# 3. First prestige must afford at least one prestige upgrade.
	gm.lifetime_earnings = 1_000_000.0  # ~mid-Bog lifetime earnings
	var pending: int = gm.get_pending_influence()
	var cheapest: int = 999999
	for key in gm.prestige_upgrades.keys():
		cheapest = mini(cheapest, gm.get_prestige_upgrade_cost(key))
	if pending < cheapest:
		failures.append("first prestige earns %d Influence but cheapest upgrade costs %d"
			% [pending, cheapest])

	# 4. Uncapped exponential stats must not be always-buy: cost growth >= value growth.
	for stat_id in gm.stat_definitions.keys():
		var d: Dictionary = gm.stat_definitions[stat_id]
		if d.get("scale", "linear") != "exponential":
			continue
		if d.has("max_level") or d.has("max_value"):
			continue
		if d["cost_exponent"] < d["growth_rate"]:
			failures.append("%s: cost_exponent %.2f < growth_rate %.2f (always-buy)"
				% [stat_id, d["cost_exponent"], d["growth_rate"]])

	# 5. Pumps: purchasable, survives save/load, offline catch-up grants money.
	gm.money = 1e12
	if not gm.buy_pump(0):
		failures.append("buy_pump(0) failed despite ample money")
	var sd: Dictionary = gm.get_save_data()
	sd["saved_at"] = Time.get_unix_time_from_system() - 3600.0  # left 1h ago
	var gm2: Node = load("res://scripts/autoload/game_manager.gd").new()
	gm2._init_swamp_states()
	gm2._init_cave_pool_states()
	gm2.load_save_data(sd)
	if gm2.get_pump_level(0) != 1:
		failures.append("pump level lost in save/load roundtrip")
	if gm2.offline_summary.is_empty():
		failures.append("no offline summary after 1h away with a pump")
	elif gm2.offline_summary["money"] <= 0.0:
		failures.append("offline pumps earned $0 over 1h")
	gm2.free()

	# 6. Arrangement perk ladder (prestige-count gates).
	var gm3: Node = load("res://scripts/autoload/game_manager.gd").new()
	gm3._init_swamp_states()
	gm3._init_cave_pool_states()
	if gm3.get_camel_max_count() != gm3.CAMEL_MAX_COUNT:
		failures.append("P0: camel cap should be base (%d), got %d" % [gm3.CAMEL_MAX_COUNT, gm3.get_camel_max_count()])
	if gm3.has_cave_sell_basin() or gm3.has_auto_lore():
		failures.append("P0: cave perks unlocked before P3")
	gm3.prestige_count = 2
	if gm3.get_camel_max_count() != gm3.CAMEL_MAX_COUNT * 3:
		failures.append("P2: camel caravan should triple cap, got %d" % gm3.get_camel_max_count())
	gm3.prestige_count = 3
	if not (gm3.has_cave_sell_basin() and gm3.has_auto_lore()):
		failures.append("P3: cave sell basin / auto-lore not unlocked")
	gm3.prestige_count = 4
	var base_mult: float = gm3.get_money_multiplier()
	gm3.sell_window_active = true
	if absf(gm3.get_money_multiplier() / base_mult - gm3.SELL_WINDOW_MULT) > 0.001:
		failures.append("P4: buyback window multiplier is x%.2f, expected x%.1f"
			% [gm3.get_money_multiplier() / base_mult, gm3.SELL_WINDOW_MULT])
	gm3.sell_window_active = false
	# Window must never tick on below P4
	gm3.prestige_count = 3
	gm3._tick_sell_window(10_000.0)
	if gm3.sell_window_active:
		failures.append("P3: buyback window ticked on below P4")
	gm3.free()

	gm.free()
	if failures.is_empty():
		print("economy_invariants: ALL PASS")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		quit(1)
