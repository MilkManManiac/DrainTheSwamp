extends Node2D

@export var loot_id: String = ""
@export var cave_id: String = ""
@export var reward_money: float = 0.0
@export var reward_tool_levels: Dictionary = {}  # {tool_id: levels_to_add}
@export var reward_upgrades: Dictionary = {}  # {upgrade_id: levels_to_add}
@export var reward_tool_unlock: String = ""  # tool_id to grant ownership for free
@export var reward_stat_levels: Dictionary = {}  # {stat_id: levels_to_add}
@export var reward_camel_unlock: bool = false
@export var reward_text: String = ""

var player_in_range: bool = false
var collected: bool = false
var glow_light: PointLight2D = null
var hint_label: Label = null
var wave_time: float = 0.0

func _ready() -> void:
	collected = GameManager.is_loot_collected(cave_id, loot_id)
	_build_visual()
	_build_interaction()

func _build_visual() -> void:
	# Loot pile/box visual
	var base := ColorRect.new()
	base.size = Vector2(12, 10)
	base.position = Vector2(-6, -10)
	base.color = Color(0.6, 0.45, 0.2) if not collected else Color(0.3, 0.25, 0.2)
	base.z_index = 3
	add_child(base)

	var lid := ColorRect.new()
	lid.size = Vector2(14, 3)
	lid.position = Vector2(-7, -13)
	lid.color = Color(0.5, 0.38, 0.15) if not collected else Color(0.25, 0.2, 0.15)
	lid.z_index = 3
	add_child(lid)

	# Glow
	if not collected:
		glow_light = PointLight2D.new()
		glow_light.color = Color(1.0, 0.9, 0.4)
		glow_light.blend_mode = PointLight2D.BLEND_MODE_ADD
		glow_light.energy = 1.5
		glow_light.shadow_enabled = false
		glow_light.position = Vector2(0, -6)
		var gradient := GradientTexture2D.new()
		gradient.width = 128
		gradient.height = 128
		gradient.fill = GradientTexture2D.FILL_RADIAL
		gradient.fill_from = Vector2(0.5, 0.5)
		gradient.fill_to = Vector2(0.5, 0.0)
		var grad := Gradient.new()
		grad.set_offset(0, 0.0)
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_offset(1, 1.0)
		grad.set_color(1, Color(0, 0, 0, 0))
		gradient.gradient = grad
		glow_light.texture = gradient
		glow_light.texture_scale = 0.4
		add_child(glow_light)

func _build_interaction() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var coll := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 40)
	coll.shape = shape
	coll.position = Vector2(0, -10)
	area.add_child(coll)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# Hint label
	hint_label = Label.new()
	hint_label.text = "[SPACE]"
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.8))
	hint_label.position = Vector2(-16, -28)
	hint_label.z_index = 8
	hint_label.visible = false
	add_child(hint_label)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_in_range = true
		if not collected:
			hint_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_in_range = false
		hint_label.visible = false

func _process(delta: float) -> void:
	wave_time += delta
	# Pulse glow
	if glow_light and not collected:
		glow_light.energy = lerpf(1.0, 2.0, (sin(wave_time * 2.5) + 1.0) * 0.5)

	# Check for interaction
	if player_in_range and not collected and Input.is_action_just_pressed("scoop"):
		_collect()

func _collect() -> void:
	collected = true
	hint_label.visible = false

	# Apply rewards (via GameManager so the Daring Bonus + lifetime earnings apply)
	if reward_money > 0.0:
		var grant: Dictionary = GameManager.grant_loot_money(reward_money)
		if grant["daring"]:
			SceneManager.show_popup("DARING BONUS x1.5 — grabbed with air to spare!\n+%s" % Economy.format_money(grant["amount"]), 3.5)
	# Grant tool ownership — or level up if already owned
	if reward_tool_unlock != "" and GameManager.tools_owned.has(reward_tool_unlock):
		if GameManager.tools_owned[reward_tool_unlock]["owned"]:
			# Already own it — grant a free level instead
			GameManager.tools_owned[reward_tool_unlock]["level"] += 1
			GameManager.tool_upgraded.emit(reward_tool_unlock, GameManager.tools_owned[reward_tool_unlock]["level"])
		else:
			GameManager.tools_owned[reward_tool_unlock]["owned"] = true
		GameManager.tool_changed.emit(GameManager.tool_definitions[GameManager.current_tool_id])
	# Grant extra tool levels
	for tool_id: String in reward_tool_levels:
		var levels: int = reward_tool_levels[tool_id]
		if GameManager.tools_owned.has(tool_id) and GameManager.tools_owned[tool_id]["owned"]:
			GameManager.tools_owned[tool_id]["level"] += levels
			GameManager.tool_upgraded.emit(tool_id, GameManager.tools_owned[tool_id]["level"])
	for upgrade_id: String in reward_upgrades:
		var levels: int = reward_upgrades[upgrade_id]
		if GameManager.upgrades_owned.has(upgrade_id):
			GameManager.upgrades_owned[upgrade_id] += levels
			GameManager.upgrade_changed.emit()
	# Grant stat levels (clamped to max_level if set)
	for stat_id: String in reward_stat_levels:
		var levels: int = reward_stat_levels[stat_id]
		if GameManager.stat_levels.has(stat_id):
			GameManager.stat_levels[stat_id] += levels
			var defn: Dictionary = GameManager.stat_definitions[stat_id]
			var ml: int = defn.get("max_level", -1)
			if ml >= 0 and GameManager.stat_levels[stat_id] > ml:
				GameManager.stat_levels[stat_id] = ml
			GameManager.stat_upgraded.emit(stat_id, GameManager.stat_levels[stat_id])

	# Unlock camel
	if reward_camel_unlock and not GameManager.camel_unlocked:
		GameManager.camel_unlocked = true
		GameManager.camel_count = 1
		GameManager.camel_changed.emit()

	# Mark collected in GameManager
	GameManager.collect_loot(cave_id, loot_id, reward_text)

	# Sparkle burst animation
	for i in range(8):
		var sparkle := ColorRect.new()
		sparkle.size = Vector2(2, 2)
		sparkle.color = Color(1.0, 0.9, 0.4, 0.9)
		sparkle.position = Vector2(randf_range(-4, 4), randf_range(-12, -4))
		sparkle.z_index = 9
		add_child(sparkle)
		var tw := create_tween()
		tw.tween_property(sparkle, "position", sparkle.position + Vector2(randf_range(-16, 16), randf_range(-20, -4)), 0.5)
		tw.parallel().tween_property(sparkle, "modulate:a", 0.0, 0.5)
		tw.tween_callback(sparkle.queue_free)

	# Dim glow
	if glow_light:
		var gtw := create_tween()
		gtw.tween_property(glow_light, "energy", 0.0, 0.3)
		gtw.tween_callback(func() -> void:
			glow_light.queue_free()
			glow_light = null
		)
