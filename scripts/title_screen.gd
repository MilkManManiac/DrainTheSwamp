extends Node2D

# --- Visual nodes ---
var stars: Array = []  # [{node, offset}]
var mist_wisps: Array = []  # [{node, speed, phase}]
var fireflies: Array = []  # [{node, base_pos, phase_x, phase_y}]
var water_poly: Polygon2D = null
var water_base_points: PackedVector2Array = PackedVector2Array()

# --- Menu nodes ---
var title_label: Label = null
var btn_new_game: Button = null
var btn_continue: Button = null
var btn_quit: Button = null
var confirm_container: HBoxContainer = null
var menu_vbox: VBoxContainer = null

# --- Newspaper nodes ---
var newspaper_overlay: ColorRect = null
var newspaper_panel: PanelContainer = null
var newspaper_prompt: Label = null
var newspaper_date_label: Label = null
var newspaper_headline: Label = null
var newspaper_subhead: Label = null
var newspaper_body: Label = null
var showing_newspaper: bool = false
var newspaper_ready_for_input: bool = false
var newspaper_index: int = 0
var newspaper_data: Array = []

# --- Post-process ---
var post_layer: CanvasLayer = null
var post_rect: ColorRect = null

var elapsed: float = 0.0

func _ready() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	_build_sky(vp_size)
	_build_stars(vp_size)
	_build_moon(vp_size)
	_build_terrain(vp_size)
	_build_water(vp_size)
	_build_mist(vp_size)
	_build_fireflies(vp_size)
	_build_title(vp_size)
	_build_menu(vp_size)
	_build_newspaper(vp_size)
	_build_post_process(vp_size)

# --- Sky ---
func _build_sky(vp_size: Vector2) -> void:
	var sky := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.04, 0.05, 0.12), Color(0.08, 0.10, 0.22)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	grad.gradient = g
	grad.width = int(vp_size.x)
	grad.height = int(vp_size.y)
	grad.fill_from = Vector2(0.5, 0.0)
	grad.fill_to = Vector2(0.5, 1.0)
	sky.texture = grad
	sky.size = vp_size
	add_child(sky)

# --- Stars ---
func _build_stars(vp_size: Vector2) -> void:
	for i in range(25):
		var star := ColorRect.new()
		var sz: float = randf_range(1.0, 3.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf() * vp_size.x, randf() * vp_size.y * 0.6)
		star.color = Color(0.9, 0.88, 0.8, randf_range(0.3, 0.8))
		add_child(star)
		stars.append({"node": star, "offset": randf() * TAU, "base_alpha": star.color.a})

# --- Moon ---
func _build_moon(vp_size: Vector2) -> void:
	var cx: float = vp_size.x * 0.78
	var cy: float = vp_size.y * 0.18
	var radius: float = 18.0

	# Glow behind moon
	var glow := Polygon2D.new()
	var glow_pts := PackedVector2Array()
	var glow_r: float = radius * 2.5
	for i in range(16):
		var angle: float = TAU * i / 16.0
		glow_pts.append(Vector2(cx + cos(angle) * glow_r, cy + sin(angle) * glow_r))
	glow.polygon = glow_pts
	glow.color = Color(0.8, 0.8, 0.6, 0.06)
	add_child(glow)

	# Moon (octagon)
	var moon := Polygon2D.new()
	var moon_pts := PackedVector2Array()
	for i in range(8):
		var angle: float = TAU * i / 8.0
		moon_pts.append(Vector2(cx + cos(angle) * radius, cy + sin(angle) * radius))
	moon.polygon = moon_pts
	moon.color = Color(0.92, 0.90, 0.82)
	add_child(moon)

# --- Terrain silhouette ---
func _build_terrain(vp_size: Vector2) -> void:
	var terrain := Polygon2D.new()
	var pts := PackedVector2Array()
	# Bottom-left (off-screen to avoid visible edge)
	pts.append(Vector2(-40, vp_size.y))
	# Irregular horizon across bottom ~30%, starting off-screen left
	var horizon_y: float = vp_size.y * 0.70
	var num_points: int = 22
	for i in range(num_points + 1):
		var t: float = float(i) / float(num_points)
		var x: float = -40.0 + t * (vp_size.x + 80.0)
		var y: float = horizon_y + sin(x * 0.02 + 1.5) * 12.0 + sin(x * 0.05) * 6.0 + sin(x * 0.01 + 0.7) * 8.0
		# Raise terrain on the left side so ground is visible
		var left_rise: float = lerpf(30.0, 0.0, clampf(t * 3.0, 0.0, 1.0))
		y -= left_rise
		# Some tree-like bumps
		if i == 1 or i == 4 or i == 9 or i == 16:
			y -= randf_range(10.0, 20.0)
		pts.append(Vector2(x, y))
	# Bottom-right (off-screen)
	pts.append(Vector2(vp_size.x + 40, vp_size.y))
	terrain.polygon = pts
	terrain.color = Color(0.08, 0.06, 0.04)
	add_child(terrain)

# --- Water strip ---
func _build_water(vp_size: Vector2) -> void:
	water_poly = Polygon2D.new()
	var pts := PackedVector2Array()
	var water_top: float = vp_size.y * 0.78
	var num_points: int = 24
	# Top edge (will be animated)
	for i in range(num_points + 1):
		var x: float = (float(i) / float(num_points)) * vp_size.x
		pts.append(Vector2(x, water_top))
	# Bottom edge
	pts.append(Vector2(vp_size.x, vp_size.y))
	pts.append(Vector2(0, vp_size.y))
	water_poly.polygon = pts
	water_poly.color = Color(0.06, 0.10, 0.08, 0.9)
	add_child(water_poly)
	# Save base points for animation
	water_base_points = pts.duplicate()

# --- Mist wisps ---
func _build_mist(vp_size: Vector2) -> void:
	for i in range(5):
		var wisp := ColorRect.new()
		var w: float = randf_range(40.0, 80.0)
		var h: float = randf_range(6.0, 12.0)
		wisp.size = Vector2(w, h)
		wisp.position = Vector2(randf() * vp_size.x, vp_size.y * randf_range(0.65, 0.80))
		wisp.color = Color(0.7, 0.65, 0.55, 0.08)
		add_child(wisp)
		mist_wisps.append({
			"node": wisp,
			"speed": randf_range(3.0, 8.0),
			"phase": randf() * TAU,
			"base_x": wisp.position.x,
			"vp_w": vp_size.x
		})

# --- Fireflies ---
func _build_fireflies(vp_size: Vector2) -> void:
	for i in range(6):
		var ff := ColorRect.new()
		ff.size = Vector2(2, 2)
		var base_pos := Vector2(
			randf_range(vp_size.x * 0.1, vp_size.x * 0.9),
			randf_range(vp_size.y * 0.68, vp_size.y * 0.80)
		)
		ff.position = base_pos
		ff.color = Color(0.9, 0.95, 0.3, 0.7)
		# ADD blend via CanvasItem material
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ff.material = mat
		add_child(ff)
		fireflies.append({
			"node": ff,
			"base_pos": base_pos,
			"phase_x": randf() * TAU,
			"phase_y": randf() * TAU
		})

# --- Title ---
func _build_title(vp_size: Vector2) -> void:
	title_label = Label.new()
	title_label.text = "DRAIN THE SWAMP"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 80)
	title_label.size = Vector2(vp_size.x, 40)
	add_child(title_label)

# --- Menu ---
func _build_menu(vp_size: Vector2) -> void:
	menu_vbox = VBoxContainer.new()
	menu_vbox.theme = load("res://assets/ui_theme.tres")
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.size = Vector2(140, 100)
	menu_vbox.position = Vector2((vp_size.x - 140) * 0.5, 190)
	menu_vbox.add_theme_constant_override("separation", 8)
	add_child(menu_vbox)

	# New Game
	btn_new_game = _create_menu_button("New Game", Color(0.9, 0.8, 0.5))
	btn_new_game.pressed.connect(_on_new_game)
	menu_vbox.add_child(btn_new_game)

	# Continue (only if save exists)
	btn_continue = _create_menu_button("Continue", Color(0.3, 1.0, 0.4))
	btn_continue.pressed.connect(_on_continue)
	btn_continue.visible = FileAccess.file_exists("user://save_data.json")
	menu_vbox.add_child(btn_continue)

	# Test Endgame (dev tool — hidden in release/exported builds)
	if OS.is_debug_build():
		var btn_test_endgame := _create_menu_button("Test Endgame", Color(1.0, 0.3, 0.3))
		btn_test_endgame.pressed.connect(_on_test_endgame)
		menu_vbox.add_child(btn_test_endgame)

	# Quit
	btn_quit = _create_menu_button("Quit", Color(0.6, 0.6, 0.6))
	btn_quit.pressed.connect(_on_quit)
	menu_vbox.add_child(btn_quit)

	# Confirm container (hidden by default)
	confirm_container = HBoxContainer.new()
	confirm_container.visible = false
	confirm_container.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_container.add_theme_constant_override("separation", 6)

	var confirm_label := Label.new()
	confirm_label.text = "Start fresh? Progress will be lost."
	confirm_label.add_theme_font_size_override("font_size", 9)
	confirm_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))

	var btn_yes := _create_menu_button("Yes", Color(1.0, 0.4, 0.3))
	btn_yes.custom_minimum_size = Vector2(40, 20)
	btn_yes.pressed.connect(_on_confirm_new_game)

	var btn_cancel := _create_menu_button("Cancel", Color(0.6, 0.6, 0.6))
	btn_cancel.custom_minimum_size = Vector2(50, 20)
	btn_cancel.pressed.connect(_on_cancel_new_game)

	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_vbox.add_theme_constant_override("separation", 4)
	confirm_vbox.add_child(confirm_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.add_child(btn_yes)
	btn_row.add_child(btn_cancel)
	confirm_vbox.add_child(btn_row)

	confirm_container.add_child(confirm_vbox)
	confirm_container.size = Vector2(vp_size.x, 50)
	confirm_container.position = Vector2(0, 280)
	add_child(confirm_container)

func _create_menu_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 24)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(minf(color.r + 0.15, 1.0), minf(color.g + 0.15, 1.0), minf(color.b + 0.15, 1.0)))

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	style_normal.border_color = Color(0.4, 0.35, 0.25, 0.6)
	style_normal.border_width_top = 1
	style_normal.border_width_bottom = 1
	style_normal.border_width_left = 1
	style_normal.border_width_right = 1
	style_normal.corner_radius_top_left = 3
	style_normal.corner_radius_top_right = 3
	style_normal.corner_radius_bottom_left = 3
	style_normal.corner_radius_bottom_right = 3
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 4
	style_normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	style_hover.border_color = Color(0.7, 0.6, 0.4, 0.8)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = Color(0.12, 0.10, 0.06, 0.9)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	return btn

# --- Newspaper ---
func _init_newspaper_data() -> void:
	newspaper_data = [
		{
			"date": "Vol. XLII, No. 6 — Wednesday, March 13",
			"headline": "CONGRESS ANNOUNCES HISTORIC \"DRAIN THE SWAMP\" INITIATIVE",
			"subhead": "Bipartisan bill allocates $200M to swamp removal program",
			"body": "In a rare show of unity, both parties voted unanimously to fund a comprehensive swamp-draining program. \"This is what the American people voted for,\" said Senator Swampsworth (R), standing beside Congresswoman Lobbyton (D), who added, \"We are fully committed to transparency.\"\n\nThe program's budget includes $180M for \"administrative oversight,\" $19.5M for \"consulting fees,\" and $500 for \"field operations.\" Critics noted the field operations budget could only cover a single employee with no equipment."
		},
		{
			"date": "Vol. XLII, No. 7 — Thursday, March 14",
			"headline": "GOVERNMENT HIRES LOCAL MAN TO DRAIN ENTIRE SWAMP",
			"subhead": "\"Just use your hands,\" supervisor reportedly instructed",
			"body": "The sole employee of the new Swamp Draining Initiative reported for work yesterday to find no office, no tools, and a handwritten note reading \"good luck.\" When asked about equipment, a government liaison shrugged and said, \"Budget constraints.\"\n\nThe man was last seen kneeling at the edge of the swamp, scooping water with his bare hands. Neighbors describe the scene as \"either inspiring or deeply concerning.\" Several elected officials were seen celebrating at a nearby steakhouse."
		}
	]

func _build_newspaper(vp_size: Vector2) -> void:
	_init_newspaper_data()

	# Dark overlay
	newspaper_overlay = ColorRect.new()
	newspaper_overlay.size = vp_size
	newspaper_overlay.color = Color(0, 0, 0, 0.0)
	newspaper_overlay.visible = false
	newspaper_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(newspaper_overlay)

	# Paper panel
	newspaper_panel = PanelContainer.new()
	var panel_w: float = 400.0
	var panel_h: float = 280.0
	newspaper_panel.position = Vector2((vp_size.x - panel_w) * 0.5, (vp_size.y - panel_h) * 0.5)
	newspaper_panel.size = Vector2(panel_w, panel_h)
	newspaper_panel.modulate = Color(1, 1, 1, 0)

	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color(0.92, 0.88, 0.78)
	paper_style.border_color = Color(0.3, 0.25, 0.2)
	paper_style.border_width_top = 2
	paper_style.border_width_bottom = 2
	paper_style.border_width_left = 2
	paper_style.border_width_right = 2
	paper_style.corner_radius_top_left = 2
	paper_style.corner_radius_top_right = 2
	paper_style.corner_radius_bottom_left = 2
	paper_style.corner_radius_bottom_right = 2
	paper_style.content_margin_left = 16
	paper_style.content_margin_right = 16
	paper_style.content_margin_top = 12
	paper_style.content_margin_bottom = 12
	newspaper_panel.add_theme_stylebox_override("panel", paper_style)

	# Corner fold — small triangle in top-right corner
	var panel_x: float = newspaper_panel.position.x
	var panel_y: float = newspaper_panel.position.y
	var fold_size: float = 14.0
	var corner_fold := Polygon2D.new()
	corner_fold.polygon = PackedVector2Array([
		Vector2(panel_x + panel_w - fold_size, panel_y),
		Vector2(panel_x + panel_w, panel_y),
		Vector2(panel_x + panel_w, panel_y + fold_size),
	])
	corner_fold.color = Color(0.78, 0.74, 0.64)
	corner_fold.z_index = 1
	newspaper_overlay.add_child(corner_fold)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	newspaper_panel.add_child(vbox)

	# Masthead
	var masthead := Label.new()
	masthead.text = "THE SWAMP GAZETTE"
	masthead.add_theme_font_size_override("font_size", 16)
	masthead.add_theme_color_override("font_color", Color(0.15, 0.12, 0.10))
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(masthead)

	# Date (dynamic)
	newspaper_date_label = Label.new()
	newspaper_date_label.add_theme_font_size_override("font_size", 8)
	newspaper_date_label.add_theme_color_override("font_color", Color(0.4, 0.38, 0.35))
	newspaper_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(newspaper_date_label)

	var sep1 := HSeparator.new()
	sep1.add_theme_stylebox_override("separator", _newspaper_separator_style())
	vbox.add_child(sep1)

	# Headline (dynamic)
	newspaper_headline = Label.new()
	newspaper_headline.add_theme_font_size_override("font_size", 12)
	newspaper_headline.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
	newspaper_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_headline.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(newspaper_headline)

	# Subhead (dynamic)
	newspaper_subhead = Label.new()
	newspaper_subhead.add_theme_font_size_override("font_size", 9)
	newspaper_subhead.add_theme_color_override("font_color", Color(0.35, 0.32, 0.28))
	newspaper_subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_subhead.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(newspaper_subhead)

	var sep2 := HSeparator.new()
	sep2.add_theme_stylebox_override("separator", _newspaper_separator_style())
	vbox.add_child(sep2)

	# Body (dynamic)
	newspaper_body = Label.new()
	newspaper_body.add_theme_font_size_override("font_size", 8)
	newspaper_body.add_theme_color_override("font_color", Color(0.18, 0.15, 0.12))
	newspaper_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	newspaper_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(newspaper_body)

	# Prompt
	newspaper_prompt = Label.new()
	newspaper_prompt.text = "[Press any key to continue]"
	newspaper_prompt.add_theme_font_size_override("font_size", 10)
	newspaper_prompt.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	newspaper_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(newspaper_prompt)

	newspaper_overlay.add_child(newspaper_panel)

func _newspaper_separator_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.25, 0.2, 0.5)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

# --- Post-process ---
func _build_post_process(vp_size: Vector2) -> void:
	post_layer = CanvasLayer.new()
	post_layer.layer = 100
	add_child(post_layer)

	post_rect = ColorRect.new()
	post_rect.size = vp_size
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := load("res://shaders/post_process.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("vignette_strength", 0.35)
		mat.set_shader_parameter("film_grain_strength", 0.03)
		mat.set_shader_parameter("night_factor", 0.8)
		mat.set_shader_parameter("warmth", -0.02)
		mat.set_shader_parameter("chromatic_aberration", 0.3)
		mat.set_shader_parameter("bloom_strength", 0.1)
		mat.set_shader_parameter("scanline_strength", 0.0)
		mat.set_shader_parameter("heat_shimmer_strength", 0.0)
		post_rect.material = mat
	post_layer.add_child(post_rect)

# --- Process (animations) ---
func _process(delta: float) -> void:
	elapsed += delta

	# Star twinkle
	for s in stars:
		var node: ColorRect = s["node"]
		var base_a: float = s["base_alpha"]
		var offset: float = s["offset"]
		node.color.a = base_a * (0.5 + 0.5 * sin(elapsed * 1.5 + offset))

	# Water wave animation
	if water_poly and water_base_points.size() > 0:
		var pts := water_base_points.duplicate()
		var num_top: int = pts.size() - 2  # Last 2 are bottom corners
		for i in range(num_top):
			pts[i].y += sin(elapsed * 1.2 + float(i) * 0.7) * 1.5
		water_poly.polygon = pts

	# Mist drift
	for m in mist_wisps:
		var node: ColorRect = m["node"]
		var base_x: float = m["base_x"]
		var speed: float = m["speed"]
		var phase: float = m["phase"]
		var vp_w: float = m["vp_w"]
		node.position.x = fmod(base_x + elapsed * speed, vp_w + node.size.x) - node.size.x
		node.color.a = 0.08 * (0.5 + 0.5 * sin(elapsed * 0.8 + phase))

	# Fireflies
	for f in fireflies:
		var node: ColorRect = f["node"]
		var base: Vector2 = f["base_pos"]
		var px: float = f["phase_x"]
		var py: float = f["phase_y"]
		node.position.x = base.x + sin(elapsed * 0.5 + px) * 12.0
		node.position.y = base.y + sin(elapsed * 0.7 + py) * 6.0
		node.color.a = 0.4 + 0.5 * sin(elapsed * 2.0 + px)

	# Title pulse
	if title_label and not showing_newspaper:
		title_label.modulate.a = 0.85 + 0.15 * sin(elapsed * 1.5)

	# Newspaper prompt pulse
	if showing_newspaper and newspaper_prompt:
		newspaper_prompt.modulate.a = 0.5 + 0.5 * sin(elapsed * 2.0)

	# Post-process time update
	if post_rect and post_rect.material:
		(post_rect.material as ShaderMaterial).set_shader_parameter("time", elapsed)

# --- Input ---
func _input(event: InputEvent) -> void:
	if not showing_newspaper or not newspaper_ready_for_input:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		_dismiss_newspaper()
		get_viewport().set_input_as_handled()

# --- Button callbacks ---
func _on_new_game() -> void:
	if FileAccess.file_exists("user://save_data.json"):
		# Show confirm
		menu_vbox.visible = false
		confirm_container.visible = true
	else:
		_start_new_game()

func _on_confirm_new_game() -> void:
	confirm_container.visible = false
	_start_new_game()

func _on_cancel_new_game() -> void:
	confirm_container.visible = false
	menu_vbox.visible = true

func _on_continue() -> void:
	# SaveManager already loaded the save in its _ready(), just transition
	SceneManager.transition_to_scene("res://scenes/main.tscn")

func _on_test_endgame() -> void:
	# Dev tool: set up game state with Atlantic nearly drained
	GameManager.reset_game()

	# Mark pools 0-8 as fully drained
	for i in range(9):
		var total: float = GameManager.swamp_definitions[i]["total_gallons"]
		GameManager.swamp_states[i]["gallons_drained"] = total
		GameManager.swamp_states[i]["completed"] = true

	# Atlantic (pool 9): drain all but 0.0001 gallons
	var atlantic_total: float = GameManager.swamp_definitions[9]["total_gallons"]
	GameManager.swamp_states[9]["gallons_drained"] = atlantic_total - 0.0001

	# Give player good tools so they can finish in one scoop
	GameManager.money = 999999999.0
	GameManager.current_tool_id = "hose"
	for tool_id in GameManager.tools_owned:
		GameManager.tools_owned[tool_id]["owned"] = true
		GameManager.tools_owned[tool_id]["level"] = 10
	GameManager.stat_levels["carrying_capacity"] = 20
	GameManager.stat_levels["movement_speed"] = 20
	GameManager.stat_levels["scoop_power"] = 20
	GameManager.stat_levels["water_value"] = 20
	GameManager.camel_unlocked = true
	GameManager.camel_count = 3

	# Unlock all caves
	for cave_id in GameManager.cave_data:
		GameManager.cave_data[cave_id]["unlocked"] = true

	SaveManager.save_game()
	SceneManager.transition_to_scene("res://scenes/main.tscn")

func _on_quit() -> void:
	get_tree().quit()

# --- New game flow ---
func _start_new_game() -> void:
	GameManager.reset_game()
	SaveManager.save_game()
	_show_newspaper()

func _set_newspaper_content(index: int) -> void:
	var data: Dictionary = newspaper_data[index]
	newspaper_date_label.text = data["date"]
	newspaper_headline.text = data["headline"]
	newspaper_subhead.text = data["subhead"]
	newspaper_body.text = data["body"]

func _show_newspaper() -> void:
	showing_newspaper = true
	newspaper_ready_for_input = false
	newspaper_index = 0
	menu_vbox.visible = false
	newspaper_overlay.visible = true
	_set_newspaper_content(0)

	# Fade in overlay and panel
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(newspaper_overlay, "color:a", 0.7, 0.5)
	tw.tween_property(newspaper_panel, "modulate:a", 1.0, 0.5)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: newspaper_ready_for_input = true)

func _dismiss_newspaper() -> void:
	newspaper_ready_for_input = false
	newspaper_index += 1
	if newspaper_index < newspaper_data.size():
		# Fade out panel, swap content, fade back in
		var tw := create_tween()
		tw.tween_property(newspaper_panel, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			_set_newspaper_content(newspaper_index)
		)
		tw.tween_property(newspaper_panel, "modulate:a", 1.0, 0.3)
		tw.tween_callback(func() -> void: newspaper_ready_for_input = true)
	else:
		# Last newspaper — transition to game
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(newspaper_overlay, "color:a", 0.0, 0.4)
		tw.tween_property(newspaper_panel, "modulate:a", 0.0, 0.4)
		tw.set_parallel(false)
		tw.tween_callback(func() -> void:
			SceneManager.transition_to_scene("res://scenes/main.tscn")
		)
