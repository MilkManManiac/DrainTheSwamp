extends Node2D
# v3 pixel-art title (2026-09-11). Gemini key-art plate split into a band sky
# and a keyed foreground (tools/bake/bake_title.py), baked wordmark, wooden
# 9-slice Silkscreen menu. Same buttons, same signals into SceneManager /
# SaveManager / GameManager as before; the newspaper intro is unchanged text.
#
# Art grid: the canvas is 640x360 logical px (2 screen px each at 720p);
# textures are baked x2 and drawn at scale 0.5, so 1 texel = 1 logical px.

const ART := "res://assets/art/title/"
const WORLD_ART := "res://assets/art/drainsville/"
const FONT := "res://assets/fonts/Silkscreen-Regular.ttf"
const SCALE := 0.5
const VP := Vector2(640.0, 360.0)
const HORIZON := 224.0          # art px; sky is keyed above this in key_fg
const NIGHT_CYCLE := 70.0       # seconds for dusk -> night -> dusk
const NIGHT_MAX := 0.92

# --- Visual nodes ---
var art: Node2D = null
var sky: Sprite2D = null
var sky_night: Sprite2D = null
var fg: Sprite2D = null
var moon: Sprite2D = null
var logo: Sprite2D = null
var stars: Array = []       # [{node, phase, rate}]
var bulbs: Array = []       # [{node, phase, color}]
var fireflies: Array = []   # [{node, base, px, py, rate}]
var _dot_tex: Texture2D = null
var _hdr_glow: bool = false

# --- Menu nodes ---
var btn_new_game: Button = null
var btn_continue: Button = null
var btn_quit: Button = null
var confirm_container: HBoxContainer = null
var menu_vbox: VBoxContainer = null
var footer: Control = null

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

# --- Debug (DTS_SHOT / DTS_TITLE_AUTO, inert when unset) ---
var _shot_path: String = ""

var elapsed: float = 0.0
var night: float = 0.0

func _ready() -> void:
	_setup_hdr_glow()
	_setup_debug_shot()
	_build_art()
	_build_logo()
	_build_menu()
	_build_footer()
	_build_newspaper()
	_build_post_process()
	_setup_debug_auto()

func _tex(name: String) -> Texture2D:
	return load(ART + name + ".png")

func _font() -> Font:
	return load(FONT)

# --- HDR-2D glow (same recipe as game_world._setup_hdr_glow) -------------
func _setup_hdr_glow() -> void:
	if RenderingServer.get_rendering_device() == null:
		return
	_hdr_glow = true
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 1.0
	env.glow_strength = 1.15
	env.glow_bloom = 0.0   # only the overbright dots bloom; the plate and the paper stay flat
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.set_glow_level(1, 0.8)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.4)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _emit(c: Color, boost: float) -> Color:
	if not _hdr_glow:
		return c
	return Color(c.r * boost, c.g * boost, c.b * boost, c.a)

# --- Key art -------------------------------------------------------------
func _build_art() -> void:
	art = Node2D.new()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)

	sky = _plate("key_sky", -20)
	sky_night = _plate("key_sky_night", -19)
	sky_night.modulate.a = 0.0

	_build_stars()

	moon = Sprite2D.new()
	moon.texture = load(WORLD_ART + "moon.png")
	moon.scale = Vector2(SCALE, SCALE)
	moon.position = Vector2(548.0, 52.0)
	moon.z_index = -17
	moon.modulate.a = 0.0
	art.add_child(moon)

	fg = _plate("key_fg", -10)
	_build_bulbs()
	_build_fireflies()

func _plate(name: String, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.z_index = z
	art.add_child(s)
	return s

# 1x1 art px white dot; everything small and glowing is this, modulated.
func _dot() -> Texture2D:
	if _dot_tex == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex

func _dot_sprite(pos: Vector2, color: Color, z: int, size_px: int = 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _dot()
	s.centered = false
	s.scale = Vector2(SCALE * size_px, SCALE * size_px)
	s.position = pos.floor()
	s.modulate = color
	s.z_index = z
	art.add_child(s)
	return s

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	for i in range(34):
		var pos := Vector2(rng.randf_range(4.0, 636.0), rng.randf_range(4.0, 150.0))
		var big: bool = rng.randf() < 0.2
		var s := _dot_sprite(pos, Color(0.95, 0.93, 0.85, 0.0), -18, 2 if big else 1)
		stars.append({"node": s, "phase": rng.randf() * TAU, "rate": rng.randf_range(0.6, 1.6), "big": big})

# String-light bulbs: find the warm bright pixels the plate already has and put
# an overbright dot on each so the HDR glow blooms them (and they can flicker).
func _build_bulbs() -> void:
	var img: Image = fg.texture.get_image()
	if img == null:
		return
	var taken: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y: int = int(HORIZON) - 60
	while y < 360:
		var x: int = 0
		while x < 640:
			var c: Color = img.get_pixel(x * 2, y * 2)
			if c.a > 0.5 and c.r > 0.78 and c.g > 0.55 and c.b < 0.5 and (c.r - c.b) > 0.4:
				var key := Vector2i(x / 3, y / 3)
				if not taken.has(key):
					taken[key] = true
					var warm := Color(1.0, 0.82, 0.45)
					var s := _dot_sprite(Vector2(x, y), _emit(warm, 2.6), -9)
					bulbs.append({"node": s, "bx": float(x), "phase": rng.randf() * TAU, "color": warm, "rate": rng.randf_range(4.0, 9.0)})
			x += 1
		y += 1

func _build_fireflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(9):
		var base := Vector2(rng.randf_range(70.0, 430.0), rng.randf_range(262.0, 344.0))
		var s := _dot_sprite(base, _emit(Color(0.8, 1.0, 0.35), 2.2), -8)
		fireflies.append({"node": s, "base": base, "px": rng.randf() * TAU, "py": rng.randf() * TAU, "rate": rng.randf_range(1.2, 2.2)})

# --- Logo ----------------------------------------------------------------
func _build_logo() -> void:
	logo = Sprite2D.new()
	logo.texture = _tex("logo")
	logo.centered = false
	logo.scale = Vector2(SCALE, SCALE)
	logo.position = Vector2(131.0, 40.0)
	logo.z_index = 5
	art.add_child(logo)

# --- Menu ----------------------------------------------------------------
func _stylebox(name: String, top: int = 3, bottom: int = 3) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(name)
	sb.texture_margin_left = 4
	sb.texture_margin_right = 4
	sb.texture_margin_top = 4
	sb.texture_margin_bottom = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = top
	sb.content_margin_bottom = bottom
	return sb

func _build_menu() -> void:
	menu_vbox = VBoxContainer.new()
	menu_vbox.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.size = Vector2(140, 100)
	menu_vbox.position = Vector2(160, 150)
	menu_vbox.add_theme_constant_override("separation", 6)
	add_child(menu_vbox)

	btn_new_game = _create_menu_button("NEW GAME", Color(0.96, 0.88, 0.66))
	btn_new_game.pressed.connect(_on_new_game)
	menu_vbox.add_child(btn_new_game)

	btn_continue = _create_menu_button("CONTINUE", Color(0.65, 0.86, 0.45))
	btn_continue.pressed.connect(_on_continue)
	btn_continue.visible = FileAccess.file_exists("user://save_data.json")
	menu_vbox.add_child(btn_continue)

	# Test Endgame (dev tool — hidden in release/exported builds)
	if OS.is_debug_build():
		var btn_test_endgame := _create_menu_button("TEST ENDGAME", Color(0.95, 0.5, 0.4))
		btn_test_endgame.pressed.connect(_on_test_endgame)
		menu_vbox.add_child(btn_test_endgame)

	btn_quit = _create_menu_button("QUIT", Color(0.72, 0.68, 0.6))
	btn_quit.pressed.connect(_on_quit)
	menu_vbox.add_child(btn_quit)

	# Confirm container (hidden by default)
	confirm_container = HBoxContainer.new()
	confirm_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	confirm_container.visible = false
	confirm_container.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_container.add_theme_constant_override("separation", 6)

	var confirm_label := Label.new()
	confirm_label.text = "START FRESH? PROGRESS WILL BE LOST."
	_pixel_label(confirm_label, 8, Color(1.0, 0.72, 0.35))
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var btn_yes := _create_menu_button("YES", Color(1.0, 0.45, 0.35), 52)
	btn_yes.pressed.connect(_on_confirm_new_game)

	var btn_cancel := _create_menu_button("CANCEL", Color(0.72, 0.68, 0.6), 76)
	btn_cancel.pressed.connect(_on_cancel_new_game)

	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_vbox.add_theme_constant_override("separation", 6)
	confirm_vbox.add_child(confirm_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.add_child(btn_yes)
	btn_row.add_child(btn_cancel)
	confirm_vbox.add_child(btn_row)

	confirm_container.add_child(confirm_vbox)
	confirm_container.size = Vector2(VP.x, 50)
	confirm_container.position = Vector2(0, 170)
	add_child(confirm_container)

func _pixel_label(lbl: Label, size: int, color: Color) -> void:
	lbl.add_theme_font_override("font", _font())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)

func _create_menu_button(text: String, color: Color, min_w: int = 140) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", _font())
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(minf(color.r + 0.12, 1.0), minf(color.g + 0.12, 1.0), minf(color.b + 0.12, 1.0)))
	btn.add_theme_color_override("font_pressed_color", Color(color.r * 0.8, color.g * 0.8, color.b * 0.8))
	btn.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.03, 1.0))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)
	btn.add_theme_stylebox_override("normal", _stylebox("btn_normal"))
	btn.add_theme_stylebox_override("hover", _stylebox("btn_hover"))
	btn.add_theme_stylebox_override("pressed", _stylebox("btn_pressed", 4, 2))
	btn.add_theme_stylebox_override("disabled", _stylebox("btn_disabled"))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

# --- Footer: version + attribution (assets/art/LICENSES.md) ----------------
func _build_footer() -> void:
	footer = Control.new()
	footer.position = Vector2(0, VP.y - 12)
	footer.size = Vector2(VP.x, 12)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var left := Label.new()
	left.text = ("V" + version if version != "" else "DRAIN THE SWAMP") + " (C) 2026"
	_pixel_label(left, 8, Color(0.86, 0.8, 0.66, 0.85))
	left.position = Vector2(6, 0)
	footer.add_child(left)
	var right := Label.new()
	right.text = "ART: CRAFTPIX.NET (OGA-BY)  ADMURIN (CC-BY)  ANSIMUZ"
	_pixel_label(right, 8, Color(0.86, 0.8, 0.66, 0.85))
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.size = Vector2(VP.x - 12, 12)
	right.position = Vector2(6, 0)
	footer.add_child(right)

# --- Newspaper (story text unchanged) ----------------------------------------
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

func _build_newspaper() -> void:
	_init_newspaper_data()

	newspaper_overlay = ColorRect.new()
	newspaper_overlay.size = VP
	newspaper_overlay.color = Color(0, 0, 0, 0.0)
	newspaper_overlay.visible = false
	newspaper_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	newspaper_overlay.z_index = 10
	add_child(newspaper_overlay)

	newspaper_panel = PanelContainer.new()
	newspaper_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var panel_w: float = 460.0
	var panel_h: float = 236.0
	newspaper_panel.position = Vector2((VP.x - panel_w) * 0.5, (VP.y - panel_h) * 0.5)
	newspaper_panel.size = Vector2(panel_w, panel_h)
	newspaper_panel.modulate = Color(1, 1, 1, 0)
	var paper := _stylebox("panel_paper", 8, 8)
	paper.content_margin_left = 14
	paper.content_margin_right = 14
	newspaper_panel.add_theme_stylebox_override("panel", paper)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	newspaper_panel.add_child(vbox)

	var ink := Color(0.16, 0.12, 0.09)
	var ink_soft := Color(0.36, 0.30, 0.24)

	var masthead := Label.new()
	masthead.text = "THE SWAMP GAZETTE"
	_paper_label(masthead, 16, ink)
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(masthead)

	newspaper_date_label = Label.new()
	_paper_label(newspaper_date_label, 8, ink_soft)
	newspaper_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(newspaper_date_label)

	vbox.add_child(_paper_rule())

	newspaper_headline = Label.new()
	_paper_label(newspaper_headline, 8, ink)
	newspaper_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_headline.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(newspaper_headline)

	newspaper_subhead = Label.new()
	_paper_label(newspaper_subhead, 8, ink_soft)
	newspaper_subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_subhead.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(newspaper_subhead)

	vbox.add_child(_paper_rule())

	newspaper_body = Label.new()
	_paper_label(newspaper_body, 8, ink)
	newspaper_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	newspaper_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(newspaper_body)

	newspaper_prompt = Label.new()
	newspaper_prompt.text = "[PRESS ANY KEY]"
	_paper_label(newspaper_prompt, 8, Color(0.55, 0.32, 0.12))
	newspaper_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(newspaper_prompt)

	newspaper_overlay.add_child(newspaper_panel)

func _paper_label(lbl: Label, size: int, color: Color) -> void:
	lbl.add_theme_font_override("font", _font())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

func _paper_rule() -> Control:
	var rule := ColorRect.new()
	rule.color = Color(0.36, 0.28, 0.2, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

# --- Post-process (the game's grade, softened for a painted plate) ---------
func _build_post_process() -> void:
	post_layer = CanvasLayer.new()
	post_layer.layer = 100
	add_child(post_layer)

	post_rect = ColorRect.new()
	post_rect.size = VP
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := load("res://shaders/post_process.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("vignette_strength", 0.28)
		mat.set_shader_parameter("film_grain_strength", 0.02)
		mat.set_shader_parameter("night_factor", 0.0)
		mat.set_shader_parameter("warmth", 0.0)
		mat.set_shader_parameter("chromatic_aberration", 0.0)
		mat.set_shader_parameter("bloom_strength", 0.0 if _hdr_glow else 0.1)
		mat.set_shader_parameter("scanline_strength", 0.0)
		mat.set_shader_parameter("heat_shimmer_strength", 0.0)
		post_rect.material = mat
	post_layer.add_child(post_rect)

# --- Debug hooks (capture.py) ----------------------------------------------
func _setup_debug_shot() -> void:
	_shot_path = OS.get_environment("DTS_SHOT")
	if _shot_path == "":
		return
	var iv: String = OS.get_environment("DTS_SHOT_INTERVAL")
	var wait: float = iv.to_float() if iv != "" else 2.0
	if wait <= 0.0:
		wait = 2.0
	var st := Timer.new()
	st.wait_time = wait
	st.autostart = true
	st.timeout.connect(_save_debug_shot)
	add_child(st)

func _save_debug_shot() -> void:
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img != null:
		if get_viewport().use_hdr_2d:
			# HDR-2D viewports hand back a float image in LINEAR colour; convert to
			# 8-bit first (linear_to_srgb only accepts RGB8/RGBA8) then to sRGB.
			img.convert(Image.FORMAT_RGBA8)
			img.linear_to_srgb()
		img.save_png(_shot_path)

# DTS_TITLE_AUTO=continue|newspaper|night: drive the screen for captures.
#   continue   press CONTINUE after 1.5 s (routes through SceneManager to main)
#   newspaper  show the intro paper without touching the save
#   night      jump the sky crossfade to full night
func _setup_debug_auto() -> void:
	var mode: String = OS.get_environment("DTS_TITLE_AUTO")
	if mode == "":
		return
	if mode == "night":
		elapsed = NIGHT_CYCLE * 0.5
		return
	var t := Timer.new()
	t.wait_time = 1.5
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(func() -> void:
		if mode == "continue":
			_on_continue()
		elif mode == "newspaper":
			_show_newspaper()
	)
	add_child(t)

# --- Process (animations) ------------------------------------------------------
func _process(delta: float) -> void:
	elapsed += delta

	# Slow dusk -> night -> dusk crossfade.
	night = NIGHT_MAX * (0.5 - 0.5 * cos(elapsed * TAU / NIGHT_CYCLE))
	sky_night.modulate.a = night
	var dim: float = 1.0 - 0.5 * night
	fg.modulate = Color(dim, dim * 0.98, minf(1.0, dim * 1.08))
	moon.modulate.a = clampf((night - 0.25) * 2.0, 0.0, 1.0)

	# Foreground drifts a few whole pixels against the fixed sky / stars / moon.
	var drift: float = floor(sin(elapsed * 0.11) * 5.0)
	fg.position.x = drift
	for f in fireflies:
		f["node"].position.x = floor(f["base"].x + drift + sin(elapsed * 0.5 * f["rate"] + f["px"]) * 10.0)
		f["node"].position.y = floor(f["base"].y + sin(elapsed * 0.7 * f["rate"] + f["py"]) * 5.0)
		var pulse: float = 0.5 + 0.5 * sin(elapsed * 2.0 * f["rate"] + f["px"])
		f["node"].modulate.a = 0.15 + 0.85 * pulse * pulse
	for b in bulbs:
		var n: Sprite2D = b["node"]
		n.position.x = floor(b["bx"] + drift)   # bulbs sit on the plate, so they drift with it
		var flick: float = 1.0 + 0.12 * sin(elapsed * b["rate"] + b["phase"]) * sin(elapsed * 1.7 + b["phase"])
		n.modulate = _emit(b["color"], 2.6 * flick)

	# Stars fade up with the night and twinkle.
	for s in stars:
		var tw: float = 0.55 + 0.45 * sin(elapsed * s["rate"] + s["phase"])
		s["node"].modulate.a = clampf(night * 1.3, 0.0, 1.0) * tw

	if showing_newspaper and newspaper_prompt:
		newspaper_prompt.modulate.a = 0.5 + 0.5 * sin(elapsed * 2.0)

	if post_rect and post_rect.material:
		var mat := post_rect.material as ShaderMaterial
		mat.set_shader_parameter("time", elapsed)
		mat.set_shader_parameter("night_factor", night * 0.35)

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
	confirm_container.visible = false
	newspaper_overlay.visible = true
	_set_newspaper_content(0)

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
		var tw := create_tween()
		tw.tween_property(newspaper_panel, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			_set_newspaper_content(newspaper_index)
		)
		tw.tween_property(newspaper_panel, "modulate:a", 1.0, 0.3)
		tw.tween_callback(func() -> void: newspaper_ready_for_input = true)
	else:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(newspaper_overlay, "color:a", 0.0, 0.4)
		tw.tween_property(newspaper_panel, "modulate:a", 0.0, 0.4)
		tw.set_parallel(false)
		tw.tween_callback(func() -> void:
			SceneManager.transition_to_scene("res://scenes/main.tscn")
		)
