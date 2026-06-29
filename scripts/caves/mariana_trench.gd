extends "res://scripts/caves/cave_base.gd"

func _init() -> void:
	cave_id = "mariana_trench"
	signature = "skeleton"
	crystal_color = Color(0.2, 0.4, 0.9)  # Bioluminescent blue

	# Theme colors: deep blue-black
	ground_color = Color(0.12, 0.15, 0.28)
	ceiling_color = Color(0.08, 0.12, 0.22)
	wall_color = Color(0.06, 0.10, 0.18)
	rock_mid_color = Color(0.10, 0.13, 0.24)
	rock_sub_color = Color(0.08, 0.11, 0.20)
	rock_inner_ceil_color = Color(0.10, 0.14, 0.24)

	# ~3200px wide cave, 3 valleys for 3 pools
	# Valley 1: x=500-850, Valley 2: x=1350-1750, Valley 3: x=2200-2650
	cave_terrain_points = [
		Vector2(0, 222),
		Vector2(140, 214),
		Vector2(290, 206),
		Vector2(420, 218),    # slope into valley 1
		Vector2(540, 258),    # valley 1 floor
		Vector2(670, 272),    # valley 1 deepest
		Vector2(790, 256),    # valley 1 floor
		Vector2(890, 220),    # slope out
		Vector2(1010, 202),   # ridge 1
		Vector2(1140, 194),   # ridge 1 peak
		Vector2(1260, 206),
		Vector2(1360, 224),   # slope into valley 2
		Vector2(1470, 260),   # valley 2 floor
		Vector2(1580, 274),   # valley 2 deepest
		Vector2(1690, 258),   # valley 2 floor
		Vector2(1790, 222),   # slope out
		Vector2(1910, 204),   # ridge 2
		Vector2(2050, 196),   # ridge 2 peak
		Vector2(2160, 212),
		Vector2(2260, 230),   # slope into valley 3
		Vector2(2380, 264),   # valley 3 floor
		Vector2(2490, 278),   # valley 3 deepest
		Vector2(2600, 262),   # valley 3 floor
		Vector2(2700, 226),   # slope out
		Vector2(2830, 208),
		Vector2(2980, 202),
		Vector2(3100, 208),
		Vector2(3200, 204),
	]

	cave_ceiling_points = [
		Vector2(0, 78),
		Vector2(320, 68),
		Vector2(500, 60),
		Vector2(670, 48),    # lower over valley 1
		Vector2(890, 62),
		Vector2(1140, 74),   # higher over ridge 1
		Vector2(1350, 64),
		Vector2(1580, 46),   # lower over valley 2
		Vector2(1790, 62),
		Vector2(2050, 74),   # higher over ridge 2
		Vector2(2250, 66),
		Vector2(2490, 44),   # lower over valley 3
		Vector2(2700, 62),
		Vector2(2950, 72),
		Vector2(3200, 70),
	]

	# 3 pools
	cave_pool_defs = [
		{
			"x_range": [420.0, 890.0],
			"pool_index": 0,
			"loot_data": {
				"loot_id": "mariana_trench_pool_0",
				"reward_money": 22500000000000.0,
				"reward_text": "The deepest account of all — every flight, every favor, converted to cold hard cash.",
			},
		},
		{
			"x_range": [1360.0, 1790.0],
			"pool_index": 1,
			"loot_data": {
				"loot_id": "mariana_trench_pool_1",
				"reward_money": 30000000000000.0,
				"reward_text": "Both parties' shared war chest, sunk so deep they were sure the Atlantic would keep it.",
			},
		},
		{
			"x_range": [2260.0, 2700.0],
			"pool_index": 2,
			"loot_data": {
				"loot_id": "mariana_trench_pool_2",
				"reward_money": 37500000000000.0,
				"reward_text": "The Guest List's true price, and an abyssal still that distills maximum value from the very last drop.",
				"reward_stat_levels": {"water_value": 5},
			},
		},
	]

func _setup_loot_and_lore() -> void:
	# Final lore on ridge 1 at x=1100
	var lore1 = preload("res://scripts/caves/lore_wall.gd").new()
	lore1.lore_id = "trench_truth"
	lore1.cave_id = cave_id
	lore1.lore_text = "THE GUEST LIST\n\n[A leather-bound book, waterlogged but legible]\n\nEvery name. Every date. Every flight.\nBoth parties. All of them.\n\nThe swamp wasn't hiding water.\nIt was hiding the truth.\n\nAnd you just drained it all."
	lore1.position = Vector2(1100, _get_cave_terrain_y_at(1100))
	add_child(lore1)

	# Bioluminescent organisms (deep sea theme)
	for i in range(20):
		var bx: float = randf_range(100, 3100)
		var by: float
		if randf() > 0.5:
			by = _get_cave_terrain_y_at(bx) - randf_range(1, 5)
		else:
			by = _get_cave_ceiling_y_at(bx) + randf_range(2, 10)
		var glow := ColorRect.new()
		glow.size = Vector2(randf_range(2, 6), randf_range(2, 4))
		glow.position = Vector2(bx - glow.size.x * 0.5, by)
		var hue: float = randf_range(0.55, 0.7)
		glow.color = Color.from_hsv(hue, 0.7, 0.8, 0.35)
		glow.z_index = 2
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = glow_mat
		add_child(glow)

	# Whale bone fragments
	for i in range(4):
		var wx: float = randf_range(400, 2800)
		var wy: float = _get_cave_terrain_y_at(wx)
		var bone := Line2D.new()
		bone.width = randf_range(2.0, 3.0)
		bone.default_color = Color(0.75, 0.72, 0.68, 0.5)
		var curve_h: float = randf_range(10, 20)
		bone.add_point(Vector2(wx - 4, wy))
		bone.add_point(Vector2(wx, wy - curve_h))
		bone.add_point(Vector2(wx + 4, wy - curve_h * 0.3))
		bone.z_index = 2
		add_child(bone)

	# Sunken ship debris
	for i in range(3):
		var sx: float = randf_range(600, 2600)
		var sy: float = _get_cave_terrain_y_at(sx)
		var plank := ColorRect.new()
		plank.size = Vector2(randf_range(14, 28), randf_range(3, 5))
		plank.position = Vector2(sx - plank.size.x * 0.5, sy - plank.size.y)
		plank.color = Color(0.3, 0.22, 0.14, 0.6)
		plank.rotation = randf_range(-0.5, 0.5)
		plank.z_index = 2
		add_child(plank)

	# Kelp strands from ceiling
	for i in range(10):
		var kx: float = randf_range(150, 3050)
		var ky: float = _get_cave_ceiling_y_at(kx)
		var kelp := Line2D.new()
		kelp.width = randf_range(1.5, 2.5)
		kelp.default_color = Color(0.15, 0.4, 0.2, 0.5)
		var hang: float = randf_range(20, 50)
		kelp.add_point(Vector2(kx, ky))
		kelp.add_point(Vector2(kx + randf_range(-4, 4), ky + hang * 0.3))
		kelp.add_point(Vector2(kx + randf_range(-6, 6), ky + hang * 0.6))
		kelp.add_point(Vector2(kx + randf_range(-3, 3), ky + hang))
		kelp.z_index = 5
		add_child(kelp)
