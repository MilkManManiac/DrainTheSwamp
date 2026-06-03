extends "res://scripts/caves/cave_base.gd"

func _init() -> void:
	cave_id = "coral_cavern"
	crystal_color = Color(0.85, 0.4, 0.5)  # Coral pink

	# Theme colors: pinkish stone
	ground_color = Color(0.35, 0.25, 0.28)
	ceiling_color = Color(0.28, 0.18, 0.22)
	wall_color = Color(0.22, 0.15, 0.18)
	rock_mid_color = Color(0.30, 0.22, 0.24)
	rock_sub_color = Color(0.26, 0.18, 0.20)
	rock_inner_ceil_color = Color(0.30, 0.20, 0.24)

	# ~2600px wide cave, 3 valleys for 3 pools
	# Valley 1: x=400-700, Valley 2: x=1100-1450, Valley 3: x=1850-2200
	cave_terrain_points = [
		Vector2(0, 218),
		Vector2(120, 210),
		Vector2(260, 204),
		Vector2(370, 218),    # slope into valley 1
		Vector2(460, 252),    # valley 1 floor
		Vector2(560, 262),    # valley 1 deepest
		Vector2(660, 250),    # valley 1 floor
		Vector2(750, 216),    # slope out
		Vector2(860, 198),    # ridge 1
		Vector2(980, 192),    # ridge 1 peak
		Vector2(1080, 210),   # slope into valley 2
		Vector2(1170, 250),   # valley 2 floor
		Vector2(1280, 260),   # valley 2 deepest
		Vector2(1380, 248),   # valley 2 floor
		Vector2(1470, 212),   # slope out
		Vector2(1580, 196),   # ridge 2
		Vector2(1700, 190),   # ridge 2 peak
		Vector2(1810, 200),
		Vector2(1880, 222),   # slope into valley 3
		Vector2(1970, 254),   # valley 3 floor
		Vector2(2060, 264),   # valley 3 deepest
		Vector2(2150, 252),   # valley 3 floor
		Vector2(2240, 218),   # slope out
		Vector2(2360, 202),
		Vector2(2480, 198),
		Vector2(2600, 204),
	]

	cave_ceiling_points = [
		Vector2(0, 84),
		Vector2(260, 76),
		Vector2(430, 68),
		Vector2(560, 58),    # lower over valley 1
		Vector2(750, 70),
		Vector2(980, 80),    # higher over ridge 1
		Vector2(1150, 72),
		Vector2(1280, 60),   # lower over valley 2
		Vector2(1470, 72),
		Vector2(1700, 80),   # higher over ridge 2
		Vector2(1880, 74),
		Vector2(2060, 58),   # lower over valley 3
		Vector2(2240, 72),
		Vector2(2440, 78),
		Vector2(2600, 76),
	]

	# 3 pools
	cave_pool_defs = [
		{
			"x_range": [370.0, 750.0],
			"pool_index": 0,
			"loot_data": {
				"loot_id": "coral_cavern_pool_0",
				"reward_money": 30000000000.0,
				"reward_text": "Blackmail payouts crusted in coral — the price of keeping a dozen senators 'cooperative.'",
			},
		},
		{
			"x_range": [1080.0, 1470.0],
			"pool_index": 1,
			"loot_data": {
				"loot_id": "coral_cavern_pool_1",
				"reward_money": 40000000000.0,
				"reward_text": "A very nervous Vice President's go-bag, still zipped, still full, never claimed.",
			},
		},
		{
			"x_range": [1880.0, 2240.0],
			"pool_index": 2,
			"loot_data": {
				"loot_id": "coral_cavern_pool_2",
				"reward_money": 50000000000.0,
				"reward_text": "The Consultant's secret retainer — paid by both sides — beside a refinery that purifies every haul.",
				"reward_stat_levels": {"water_value": 4},
			},
		},
	]

func _setup_loot_and_lore() -> void:
	# Coral lore on ridge 1 at x=900
	var lore1 = preload("res://scripts/caves/lore_wall.gd").new()
	lore1.lore_id = "coral_origins"
	lore1.cave_id = cave_id
	lore1.lore_text = "BLACKMAIL FILE — EYES ONLY\n\nThe following officials have been \"cooperative\" since receiving our documentation of their activities:\n- 12 Senators (6R, 6D — perfectly bipartisan!)\n- 34 Representatives\n- 3 Governors\n- 1 very nervous Vice President\n- \"The Consultant\" (who is somehow on BOTH sides of this)"
	lore1.position = Vector2(900, _get_cave_terrain_y_at(900))
	add_child(lore1)

	# Coral formations (organic branching shapes)
	for i in range(14):
		var cx: float = randf_range(100, 2500)
		var on_floor: bool = randf() < 0.7
		var cy: float
		if on_floor:
			cy = _get_cave_terrain_y_at(cx)
		else:
			cy = _get_cave_ceiling_y_at(cx)
		var coral := Line2D.new()
		coral.width = randf_range(2.0, 3.5)
		var hue: float = randf_range(0.0, 0.15)
		coral.default_color = Color.from_hsv(hue, 0.6, 0.8, 0.7)
		var branch_h: float = randf_range(8, 20)
		if on_floor:
			coral.add_point(Vector2(cx, cy))
			coral.add_point(Vector2(cx + randf_range(-3, 3), cy - branch_h * 0.5))
			coral.add_point(Vector2(cx + randf_range(-5, 5), cy - branch_h))
		else:
			coral.add_point(Vector2(cx, cy))
			coral.add_point(Vector2(cx + randf_range(-3, 3), cy + branch_h * 0.5))
			coral.add_point(Vector2(cx + randf_range(-5, 5), cy + branch_h))
		coral.z_index = 3
		add_child(coral)

	# Bioluminescent specks
	for i in range(10):
		var sx: float = randf_range(80, 2520)
		var sy: float
		if randf() > 0.5:
			sy = _get_cave_terrain_y_at(sx) - randf_range(2, 6)
		else:
			sy = _get_cave_ceiling_y_at(sx) + randf_range(2, 8)
		var speck := ColorRect.new()
		speck.size = Vector2(randf_range(2, 4), randf_range(2, 3))
		speck.position = Vector2(sx - speck.size.x * 0.5, sy)
		speck.color = Color(0.9, 0.5, 0.6, 0.35)
		speck.z_index = 2
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		speck.material = glow_mat
		add_child(speck)
