extends "res://scripts/caves/cave_base.gd"

func _init() -> void:
	cave_id = "the_mire"
	signature = "dead_tree"
	crystal_color = Color(0.2, 0.5, 0.15)  # Dark green

	# Theme colors: dark green-brown
	ground_color = Color(0.22, 0.28, 0.14)
	ceiling_color = Color(0.16, 0.22, 0.10)
	wall_color = Color(0.14, 0.18, 0.08)
	rock_mid_color = Color(0.20, 0.24, 0.12)
	rock_sub_color = Color(0.16, 0.20, 0.10)
	rock_inner_ceil_color = Color(0.18, 0.24, 0.12)

	# ~2000px wide cave, 2 valleys for 2 pools
	# Valley 1: x=450-750, Valley 2: x=1200-1550
	cave_terrain_points = [
		Vector2(0, 220),
		Vector2(120, 214),
		Vector2(250, 208),
		Vector2(380, 216),
		Vector2(450, 234),    # slope into valley 1
		Vector2(540, 260),    # valley 1 floor
		Vector2(640, 268),    # valley 1 deepest
		Vector2(720, 258),    # valley 1 floor
		Vector2(800, 224),    # slope out
		Vector2(900, 206),    # ridge
		Vector2(1020, 200),   # ridge peak
		Vector2(1120, 208),
		Vector2(1200, 230),   # slope into valley 2
		Vector2(1300, 262),   # valley 2 floor
		Vector2(1400, 270),   # valley 2 deepest
		Vector2(1500, 260),   # valley 2 floor
		Vector2(1600, 226),   # slope out
		Vector2(1720, 210),
		Vector2(1850, 206),
		Vector2(2000, 212),
	]

	cave_ceiling_points = [
		Vector2(0, 90),
		Vector2(200, 84),
		Vector2(400, 76),
		Vector2(550, 64),    # lower over valley 1
		Vector2(750, 72),
		Vector2(950, 80),    # higher over ridge
		Vector2(1100, 76),
		Vector2(1300, 62),   # lower over valley 2
		Vector2(1550, 72),
		Vector2(1800, 80),
		Vector2(2000, 78),
	]

	# 2 pools
	cave_pool_defs = [
		{
			"x_range": [450.0, 800.0],
			"pool_index": 0,
			"loot_data": {
				"loot_id": "the_mire_pool_0",
				"reward_money": 6000000.0,
				"reward_text": "A shell company's slush fund, sealed in a waterproof case marked 'Swamp Friends LLC.'",
			},
		},
		{
			"x_range": [1200.0, 1600.0],
			"pool_index": 1,
			"loot_data": {
				"loot_id": "the_mire_pool_1",
				"reward_money": 9000000.0,
				"reward_text": "47 politicians' buried bribes — and an industrial dredge they used to bury them.",
				"reward_stat_levels": {"scoop_power": 3},
			},
		},
	]

func _setup_loot_and_lore() -> void:
	# Mire lore on ridge at x=1000
	var lore1 = preload("res://scripts/caves/lore_wall.gd").new()
	lore1.lore_id = "mire_depths"
	lore1.cave_id = cave_id
	lore1.lore_text = "INTERNAL MEMO — LOBBYING FIRM \"SWAMP FRIENDS LLC\"\n\nClient List (DO NOT SHARE):\n- SwampCo Industries (Senator Swampsworth, chair)\n- Definitely-Not-A-Shell-Company LLC (Congresswoman Lobbyton)\n- The Consultant (services: \"consulting\")\n- 47 other politicians from both parties\n\nALL CLIENTS HAVE ASSETS STORED IN THE SWAMP. DO NOT LET IT DRAIN."
	lore1.position = Vector2(1000, _get_cave_terrain_y_at(1000))
	add_child(lore1)

	if V3_CAVES:
		return  # v3 pixel kit (cave_skin.gd) draws the decoration now; old ColorRect/Line2D clutter below is quarantined

	# Tangled vines and hanging moss (mire theme)
	for i in range(12):
		var vx: float = randf_range(100, 1900)
		var vy: float = _get_cave_ceiling_y_at(vx)
		var vine := Line2D.new()
		vine.width = randf_range(1.0, 2.0)
		vine.default_color = Color(0.18, 0.35, 0.12, 0.6)
		var hang: float = randf_range(15, 40)
		vine.add_point(Vector2(vx, vy))
		vine.add_point(Vector2(vx + randf_range(-6, 6), vy + hang * 0.4))
		vine.add_point(Vector2(vx + randf_range(-8, 8), vy + hang * 0.7))
		vine.add_point(Vector2(vx + randf_range(-4, 4), vy + hang))
		vine.z_index = 5
		add_child(vine)

	# Glowing fungi on floor
	for i in range(8):
		var fx: float = randf_range(80, 1920)
		var fy: float = _get_cave_terrain_y_at(fx)
		var fungus := ColorRect.new()
		fungus.size = Vector2(randf_range(3, 6), randf_range(4, 8))
		fungus.position = Vector2(fx - fungus.size.x * 0.5, fy - fungus.size.y)
		fungus.color = Color(0.3, 0.6, 0.2, 0.5)
		fungus.z_index = 2
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		fungus.material = glow_mat
		add_child(fungus)
