extends "res://scripts/caves/cave_base.gd"

func _init() -> void:
	cave_id = "sunken_grotto"
	signature = "pump"
	crystal_color = Color(0.2, 0.65, 0.6)  # Teal

	# Theme colors: teal-grey
	ground_color = Color(0.22, 0.30, 0.32)
	ceiling_color = Color(0.16, 0.24, 0.26)
	wall_color = Color(0.14, 0.20, 0.22)
	rock_mid_color = Color(0.20, 0.26, 0.28)
	rock_sub_color = Color(0.16, 0.22, 0.24)
	rock_inner_ceil_color = Color(0.18, 0.26, 0.28)

	# ~2200px wide cave, 2 valleys for 2 pools
	# Valley 1: x=500-800, Valley 2: x=1350-1700
	cave_terrain_points = [
		Vector2(0, 220),
		Vector2(120, 214),
		Vector2(250, 206),
		Vector2(380, 200),
		Vector2(460, 214),    # slope into valley 1
		Vector2(560, 248),    # valley 1 floor
		Vector2(660, 256),    # valley 1 deepest
		Vector2(760, 246),    # valley 1 floor
		Vector2(850, 212),    # slope out
		Vector2(960, 198),    # ridge
		Vector2(1080, 192),   # ridge peak
		Vector2(1200, 196),
		Vector2(1310, 210),   # slope into valley 2
		Vector2(1420, 250),   # valley 2 floor
		Vector2(1530, 260),   # valley 2 deepest
		Vector2(1640, 248),   # valley 2 floor
		Vector2(1740, 214),   # slope out
		Vector2(1860, 200),
		Vector2(1980, 196),
		Vector2(2100, 202),
		Vector2(2200, 198),
	]

	cave_ceiling_points = [
		Vector2(0, 86),
		Vector2(220, 78),
		Vector2(440, 74),
		Vector2(600, 62),    # lower over valley 1
		Vector2(800, 72),
		Vector2(1000, 80),   # higher over ridge
		Vector2(1200, 76),
		Vector2(1450, 60),   # lower over valley 2
		Vector2(1700, 72),
		Vector2(1950, 80),
		Vector2(2200, 78),
	]

	# 2 pools
	cave_pool_defs = [
		{
			"x_range": [460.0, 850.0],
			"pool_index": 0,
			"loot_data": {
				"loot_id": "sunken_grotto_pool_0",
				"reward_money": 120000000.0,
				"reward_text": "Operation Wet Blanket's black-budget cash, stashed where no auditor would ever wade.",
			},
		},
		{
			"x_range": [1310.0, 1740.0],
			"pool_index": 1,
			"loot_data": {
				"loot_id": "sunken_grotto_pool_1",
				"reward_money": 180000000.0,
				"reward_text": "A 'protected wetland' bribe fund — plus a filtration rig that wrings extra worth from every drop.",
				"reward_stat_levels": {"water_value": 3},
			},
		},
	]

func _setup_loot_and_lore() -> void:
	# Grotto lore on ridge at x=1100
	var lore1 = preload("res://scripts/caves/lore_wall.gd").new()
	lore1.lore_id = "grotto_secrets"
	lore1.cave_id = cave_id
	lore1.lore_text = "REDACTED GOVERNMENT FILE\n\nSubject: Operation Wet Blanket\nObjective: Slow down the drainer without attracting media attention\n\nProposed methods:\n- Release more water into swamp (REJECTED — too obvious)\n- Revoke his \"swamp access permit\" (NOTE: he doesn't have one)\n- Declare swamp a \"protected wetland\" (IN PROGRESS)\n- Bribe him (FAILED — \"he just bought another shovel with it\")"
	lore1.position = Vector2(1100, _get_cave_terrain_y_at(1100))
	add_child(lore1)

	if V3_CAVES:
		return  # v3 pixel kit (cave_skin.gd) draws the decoration now; old ColorRect/Line2D clutter below is quarantined

	# Dripping water features (grotto theme)
	for i in range(15):
		var dx: float = randf_range(80, 2120)
		var dy: float = _get_cave_ceiling_y_at(dx) + randf_range(1, 4)
		var drip_line := Line2D.new()
		drip_line.width = 1.0
		drip_line.default_color = Color(0.3, 0.55, 0.6, 0.4)
		drip_line.add_point(Vector2(dx, dy))
		drip_line.add_point(Vector2(dx + randf_range(-1, 1), dy + randf_range(4, 12)))
		drip_line.z_index = 5
		add_child(drip_line)

	# Flowstone formations on ridges
	for i in range(6):
		var fx: float = randf_range(880, 1280)
		var fy: float = _get_cave_terrain_y_at(fx)
		var flowstone := Polygon2D.new()
		var fw: float = randf_range(8, 16)
		var fh: float = randf_range(6, 14)
		flowstone.polygon = PackedVector2Array([
			Vector2(-fw * 0.5, 0),
			Vector2(fw * 0.5, 0),
			Vector2(fw * 0.3, -fh),
			Vector2(-fw * 0.3, -fh * 0.8),
		])
		flowstone.position = Vector2(fx, fy)
		flowstone.color = Color(0.28, 0.35, 0.36, 0.6)
		flowstone.z_index = 2
		add_child(flowstone)
