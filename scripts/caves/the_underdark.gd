extends "res://scripts/caves/cave_base.gd"

func _init() -> void:
	cave_id = "the_underdark"
	crystal_color = Color(0.5, 0.15, 0.65)  # Deep purple

	# Theme colors: purple-black
	ground_color = Color(0.22, 0.16, 0.28)
	ceiling_color = Color(0.16, 0.12, 0.22)
	wall_color = Color(0.14, 0.10, 0.18)
	rock_mid_color = Color(0.20, 0.14, 0.24)
	rock_sub_color = Color(0.16, 0.12, 0.20)
	rock_inner_ceil_color = Color(0.18, 0.14, 0.24)

	# ~2800px wide cave, 3 valleys for 3 pools
	# Valley 1: x=450-780, Valley 2: x=1200-1580, Valley 3: x=1950-2350
	cave_terrain_points = [
		Vector2(0, 220),
		Vector2(130, 212),
		Vector2(270, 204),
		Vector2(400, 216),    # slope into valley 1
		Vector2(500, 254),    # valley 1 floor
		Vector2(620, 266),    # valley 1 deepest
		Vector2(730, 252),    # valley 1 floor
		Vector2(820, 218),    # slope out
		Vector2(940, 200),    # ridge 1
		Vector2(1060, 194),   # ridge 1 peak
		Vector2(1170, 212),   # slope into valley 2
		Vector2(1280, 256),   # valley 2 floor
		Vector2(1400, 268),   # valley 2 deepest
		Vector2(1510, 254),   # valley 2 floor
		Vector2(1610, 216),   # slope out
		Vector2(1720, 198),   # ridge 2
		Vector2(1840, 192),   # ridge 2 peak
		Vector2(1940, 214),   # slope into valley 3
		Vector2(2050, 258),   # valley 3 floor
		Vector2(2160, 270),   # valley 3 deepest
		Vector2(2280, 256),   # valley 3 floor
		Vector2(2380, 218),   # slope out
		Vector2(2500, 202),
		Vector2(2650, 198),
		Vector2(2800, 204),
	]

	cave_ceiling_points = [
		Vector2(0, 82),
		Vector2(280, 74),
		Vector2(470, 66),
		Vector2(620, 54),    # lower over valley 1
		Vector2(820, 68),
		Vector2(1060, 78),   # higher over ridge 1
		Vector2(1250, 68),
		Vector2(1400, 52),   # lower over valley 2
		Vector2(1610, 68),
		Vector2(1840, 78),   # higher over ridge 2
		Vector2(2020, 70),
		Vector2(2160, 52),   # lower over valley 3
		Vector2(2380, 68),
		Vector2(2600, 76),
		Vector2(2800, 74),
	]

	# 3 pools
	cave_pool_defs = [
		{
			"x_range": [400.0, 820.0],
			"pool_index": 0,
			"loot_data": {
				"loot_id": "the_underdark_pool_0",
				"reward_money": 600000000000.0,
				"reward_text": "The emergency meeting's emergency fund — drawn up the night they realized you'd reached the bayou.",
			},
		},
		{
			"x_range": [1170.0, 1610.0],
			"pool_index": 1,
			"loot_data": {
				"loot_id": "the_underdark_pool_1",
				"reward_money": 800000000000.0,
				"reward_text": "Mayor Kickback's namesake stash, hidden so deep even he forgot the permit he never issued.",
			},
		},
		{
			"x_range": [1940.0, 2380.0],
			"pool_index": 2,
			"loot_data": {
				"loot_id": "the_underdark_pool_2",
				"reward_money": 1000000000000.0,
				"reward_text": "An ancient warlord-grade scoop beside a hoard so vast it predates the swamp's first lie.",
				"reward_stat_levels": {"scoop_power": 5},
			},
		},
	]

func _setup_loot_and_lore() -> void:
	# Underdark lore on ridge 1 at x=1000
	var lore1 = preload("res://scripts/caves/lore_wall.gd").new()
	lore1.lore_id = "underdark_warning"
	lore1.cave_id = cave_id
	lore1.lore_text = "EMERGENCY MEETING MINUTES — LOCATION: [CLASSIFIED]\nATTENDEES: Everyone who matters\n\nSWAMPSWORTH: \"He's at the bayou. THE BAYOU.\"\nLOBBYTON: \"How? We took away his permit!\"\nMAYOR KICKBACK: \"He never had a permit!\"\nTHE CONSULTANT: \"My $500,000 report recommended patience.\"\nSWAMPSWORTH: \"YOUR REPORT WAS THREE PAGES OF 'MAYBE WAIT?'\"\nGOODWELL: \"Gentlemen, I believe I can help. For a modest consulting fee.\"\nALL: [unintelligible shouting]\n\nRESOLUTION: \"Pray he doesn't reach the Atlantic.\""
	lore1.position = Vector2(1000, _get_cave_terrain_y_at(1000))
	add_child(lore1)

	# Ancient stone pillars on ridges (crumbling, alien)
	var pillar_positions: Array[float] = [160.0, 940.0, 1060.0, 1720.0, 1840.0, 2500.0, 2650.0]
	for px in pillar_positions:
		var floor_y: float = _get_cave_terrain_y_at(px)
		var ceil_y: float = _get_cave_ceiling_y_at(px)
		var broken: bool = randf() < 0.3
		var pillar_h: float = floor_y - ceil_y - 4
		if broken:
			pillar_h *= randf_range(0.3, 0.6)
		var pillar := ColorRect.new()
		pillar.size = Vector2(5, pillar_h)
		pillar.position = Vector2(px - 2.5, floor_y - pillar_h if broken else ceil_y + 2)
		pillar.color = Color(0.28, 0.22, 0.32)
		pillar.z_index = 1
		add_child(pillar)

	# Bioluminescent patches (purple/violet)
	for i in range(12):
		var bx: float = randf_range(100, 2700)
		var by: float
		if randf() > 0.5:
			by = _get_cave_terrain_y_at(bx) - randf_range(1, 4)
		else:
			by = _get_cave_ceiling_y_at(bx) + randf_range(2, 8)
		var glow := ColorRect.new()
		glow.size = Vector2(randf_range(3, 8), randf_range(2, 5))
		glow.position = Vector2(bx - glow.size.x * 0.5, by)
		glow.color = Color(0.4, 0.15, 0.55, 0.3)
		glow.z_index = 2
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = glow_mat
		add_child(glow)

	# Rune markings on walls
	for i in range(6):
		var rx: float = randf_range(200, 2600)
		var on_floor: bool = randf() < 0.5
		var ry: float
		if on_floor:
			ry = _get_cave_terrain_y_at(rx) - randf_range(1, 3)
		else:
			ry = _get_cave_ceiling_y_at(rx) + randf_range(1, 4)
		var rune := ColorRect.new()
		rune.size = Vector2(randf_range(4, 8), randf_range(3, 6))
		rune.position = Vector2(rx - rune.size.x * 0.5, ry)
		rune.color = Color(0.5, 0.2, 0.7, 0.2)
		rune.z_index = 2
		var rune_mat := CanvasItemMaterial.new()
		rune_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		rune.material = rune_mat
		add_child(rune)
