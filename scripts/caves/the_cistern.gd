extends "res://scripts/caves/cave_base.gd"

func _init() -> void:
	cave_id = "the_cistern"
	signature = "pump"
	crystal_color = Color(0.45, 0.55, 0.7)  # Steel blue

	# Theme colors: slate grey
	ground_color = Color(0.30, 0.30, 0.32)
	ceiling_color = Color(0.22, 0.22, 0.25)
	wall_color = Color(0.18, 0.18, 0.22)
	rock_mid_color = Color(0.26, 0.26, 0.28)
	rock_sub_color = Color(0.22, 0.22, 0.25)
	rock_inner_ceil_color = Color(0.24, 0.24, 0.28)

	# ~2400px wide cave, 3 valleys for 3 pools
	# Valley 1: x=350-600, Valley 2: x=950-1250, Valley 3: x=1650-1950
	cave_terrain_points = [
		Vector2(0, 215),
		Vector2(120, 208),
		Vector2(250, 202),
		Vector2(340, 218),    # slope into valley 1
		Vector2(430, 250),    # valley 1 floor
		Vector2(500, 258),    # valley 1 deepest
		Vector2(580, 248),    # valley 1 floor
		Vector2(660, 216),    # slope out
		Vector2(760, 198),    # ridge 1
		Vector2(860, 194),    # ridge 1 peak
		Vector2(940, 210),    # slope into valley 2
		Vector2(1020, 248),   # valley 2 floor
		Vector2(1100, 256),   # valley 2 deepest
		Vector2(1180, 246),   # valley 2 floor
		Vector2(1260, 212),   # slope out
		Vector2(1360, 196),   # ridge 2
		Vector2(1470, 192),   # ridge 2 peak
		Vector2(1570, 198),
		Vector2(1650, 218),   # slope into valley 3
		Vector2(1740, 252),   # valley 3 floor
		Vector2(1830, 260),   # valley 3 deepest
		Vector2(1920, 250),   # valley 3 floor
		Vector2(2010, 216),   # slope out
		Vector2(2120, 200),
		Vector2(2260, 196),
		Vector2(2400, 202),
	]

	cave_ceiling_points = [
		Vector2(0, 88),
		Vector2(240, 82),
		Vector2(420, 72),
		Vector2(500, 62),    # lower over valley 1
		Vector2(660, 74),
		Vector2(860, 82),    # higher over ridge 1
		Vector2(1000, 74),
		Vector2(1100, 64),   # lower over valley 2
		Vector2(1260, 76),
		Vector2(1470, 82),   # higher over ridge 2
		Vector2(1650, 76),
		Vector2(1800, 62),   # lower over valley 3
		Vector2(2010, 74),
		Vector2(2200, 80),
		Vector2(2400, 78),
	]

	# 3 pools
	cave_pool_defs = [
		{
			"x_range": [340.0, 660.0],
			"pool_index": 0,
			"loot_data": {
				"loot_id": "the_cistern_pool_0",
				"reward_money": 1500000000.0,
				"reward_text": "Cayman wire transfers, printed and laminated — the 'swamp stuff' the bank begged them to relabel.",
			},
		},
		{
			"x_range": [940.0, 1260.0],
			"pool_index": 1,
			"loot_data": {
				"loot_id": "the_cistern_pool_1",
				"reward_money": 2000000000.0,
				"reward_text": "The Goodwell Clean Government Fund — 'donations' that flowed straight into a personal account.",
			},
		},
		{
			"x_range": [1650.0, 2010.0],
			"pool_index": 2,
			"loot_data": {
				"loot_id": "the_cistern_pool_2",
				"reward_money": 2500000000.0,
				"reward_text": "Senator Swampsworth's 'personal savings' — and a reinforced scoop forged to move it fast.",
				"reward_stat_levels": {"scoop_power": 4},
			},
		},
	]

func _setup_loot_and_lore() -> void:
	# Cistern lore on ridge 1 at x=800
	var lore1 = preload("res://scripts/caves/lore_wall.gd").new()
	lore1.lore_id = "cistern_builders"
	lore1.cave_id = cave_id
	lore1.lore_text = "OFFSHORE ACCOUNT RECORDS — CAYMAN ISLANDS BRANCH\n\nAccount: SW4MP-FUND-2024\nDeposits:\n- $2.4M from \"Anonymous Concerned Citizens PAC\"\n- $800K from \"Americans for Swamp Preservation\"\n- $3.1M from [NAME REDACTED BY COURT ORDER]\n\nWithdrawals:\n- $6.3M to \"Senator Swampsworth Personal Savings\"\n\nNote from bank: \"Please stop labeling transfers as 'swamp stuff'\"\n\nRecent addition: Account GW-REFORM-2024, \"Goodwell Clean Government Fund\" — Deposits: $400K from \"concerned citizens.\" Withdrawals: $400K to personal investment account."
	lore1.position = Vector2(800, _get_cave_terrain_y_at(800))
	add_child(lore1)

	if V3_CAVES:
		return  # v3 pixel kit (cave_skin.gd) draws the decoration now; old ColorRect/Line2D clutter below is quarantined

	# Concrete pillars (industrial cistern theme) — on ridges
	var pillar_positions: Array[float] = [140.0, 760.0, 860.0, 1360.0, 1470.0, 2120.0, 2260.0]
	for px in pillar_positions:
		var floor_y: float = _get_cave_terrain_y_at(px)
		var ceil_y: float = _get_cave_ceiling_y_at(px)
		var pillar := ColorRect.new()
		pillar.size = Vector2(6, floor_y - ceil_y - 4)
		pillar.position = Vector2(px - 3, ceil_y + 2)
		pillar.color = Color(0.42, 0.42, 0.44)
		pillar.z_index = 1
		add_child(pillar)
		var cap := ColorRect.new()
		cap.size = Vector2(10, 3)
		cap.position = Vector2(px - 5, ceil_y + 2)
		cap.color = Color(0.38, 0.38, 0.40)
		cap.z_index = 1
		add_child(cap)

	# Pipe fragments
	for i in range(5):
		var pipe_x: float = randf_range(100, 2300)
		var pipe_y: float = _get_cave_terrain_y_at(pipe_x)
		var pipe := ColorRect.new()
		pipe.size = Vector2(randf_range(12, 24), randf_range(3, 5))
		pipe.position = Vector2(pipe_x - pipe.size.x * 0.5, pipe_y - pipe.size.y)
		pipe.color = Color(0.5, 0.45, 0.35, 0.7)
		pipe.rotation = randf_range(-0.3, 0.3)
		pipe.z_index = 2
		add_child(pipe)
