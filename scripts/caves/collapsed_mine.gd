extends "res://scripts/caves/cave_base.gd"

func _init() -> void:
	cave_id = "collapsed_mine"
	crystal_color = Color(0.8, 0.5, 0.2)  # Orange

	# Theme colors: rusty brown
	ground_color = Color(0.38, 0.25, 0.15)
	ceiling_color = Color(0.28, 0.18, 0.12)
	wall_color = Color(0.24, 0.15, 0.10)
	rock_mid_color = Color(0.34, 0.22, 0.13)
	rock_sub_color = Color(0.28, 0.18, 0.10)
	rock_inner_ceil_color = Color(0.30, 0.20, 0.14)

	# ~1800px wide cave, 2 valleys for 2 pools
	# Valley 1: x=400-650, Valley 2: x=1100-1400
	cave_terrain_points = [
		Vector2(0, 210),
		Vector2(120, 204),
		Vector2(250, 198),
		Vector2(350, 208),    # slope into valley 1
		Vector2(440, 238),    # valley 1 floor
		Vector2(530, 244),    # valley 1 deepest
		Vector2(620, 236),    # valley 1 floor
		Vector2(700, 206),    # slope out
		Vector2(800, 192),    # ridge between pools
		Vector2(920, 188),    # ridge peak
		Vector2(1020, 194),
		Vector2(1100, 210),   # slope into valley 2
		Vector2(1200, 242),   # valley 2 floor
		Vector2(1300, 248),   # valley 2 deepest
		Vector2(1380, 240),   # valley 2 floor
		Vector2(1460, 208),   # slope out
		Vector2(1580, 194),
		Vector2(1700, 198),
		Vector2(1800, 196),
	]

	cave_ceiling_points = [
		Vector2(0, 90),
		Vector2(180, 84),
		Vector2(360, 78),
		Vector2(500, 68),    # lower over valley 1
		Vector2(700, 76),
		Vector2(900, 82),    # higher over ridge
		Vector2(1100, 76),
		Vector2(1250, 66),   # lower over valley 2
		Vector2(1440, 74),
		Vector2(1620, 80),
		Vector2(1800, 78),
	]

	# 2 pools
	cave_pool_defs = [
		{
			"x_range": [350.0, 700.0],
			"pool_index": 0,
			"loot_data": {
				"loot_id": "collapsed_mine_pool_0",
				"reward_money": 300000.0,
				"reward_text": "A miner's lockbox stuffed with payroll the company swore was 'lost in the collapse.'",
			},
		},
		{
			"x_range": [1100.0, 1460.0],
			"pool_index": 1,
			"loot_data": {
				"loot_id": "collapsed_mine_pool_1",
				"reward_money": 450000.0,
				"reward_text": "A vein of pure embezzlement — and an old assayer's trick for squeezing more value from every scoop.",
				"reward_stat_levels": {"water_value": 2},
			},
		},
	]

func _setup_loot_and_lore() -> void:
	# Mine history lore at x=850 (on ridge between pools)
	var lore1 = preload("res://scripts/caves/lore_wall.gd").new()
	lore1.lore_id = "mine_history"
	lore1.cave_id = cave_id
	lore1.lore_text = "WIRETAP TRANSCRIPT — CLASSIFIED\n\nSWAMPSWORTH: \"He drained the bog. THE BOG.\"\nLOBBYTON: \"I thought you said he only had hands?\"\nSWAMPSWORTH: \"He bought a BUCKET. With his OWN money.\"\nLOBBYTON: \"...That wasn't supposed to be possible.\""
	lore1.position = Vector2(850, _get_cave_terrain_y_at(850))
	add_child(lore1)

	# Consultant report — crumpled paper near the back
	var report1 = preload("res://scripts/caves/lore_wall.gd").new()
	report1.lore_id = "consultant_report_21"
	report1.cave_id = cave_id
	report1.lore_text = "THE CONSULTANT — QUARTERLY REPORT #21\n\nidk maybe wait?\n\n-TC\n\nP.S. Invoice attached."
	report1.position = Vector2(1600, _get_cave_terrain_y_at(1600))
	add_child(report1)

	# Wooden beam supports (mine theme decorations) — only on non-pool terrain
	var beam_positions: Array[float] = [150.0, 780.0, 920.0, 1550.0, 1700.0]
	for bx in beam_positions:
		var floor_y: float = _get_cave_terrain_y_at(bx)
		var ceil_y: float = _get_cave_ceiling_y_at(bx)
		var beam := ColorRect.new()
		beam.size = Vector2(4, floor_y - ceil_y - 4)
		beam.position = Vector2(bx - 2, ceil_y + 2)
		beam.color = Color(0.4, 0.28, 0.14)
		beam.z_index = 1
		add_child(beam)
		var cross := ColorRect.new()
		cross.size = Vector2(20, 3)
		cross.position = Vector2(bx - 10, ceil_y + 2)
		cross.color = Color(0.35, 0.24, 0.12)
		cross.z_index = 1
		add_child(cross)

	# Metal debris
	for i in range(5):
		var dx: float = randf_range(100, 1700)
		var dy: float = _get_cave_terrain_y_at(dx)
		var debris := ColorRect.new()
		debris.size = Vector2(randf_range(3, 8), randf_range(2, 5))
		debris.position = Vector2(dx - debris.size.x * 0.5, dy - debris.size.y)
		debris.color = Color(0.45, 0.42, 0.4, 0.7)
		debris.rotation = randf_range(-0.4, 0.4)
		debris.z_index = 2
		add_child(debris)
