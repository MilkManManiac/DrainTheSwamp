extends PanelContainer

signal resume_pressed
signal reset_confirmed

var confirming_reset: bool = false

@onready var button_list: VBoxContainer = $CenterContainer/Box/MarginContainer/VBoxContainer/ButtonList
@onready var close_button: Button = $CenterContainer/Box/MarginContainer/VBoxContainer/TopBar/CloseButton

func _ready() -> void:
	close_button.pressed.connect(func() -> void: _close())
	visible = false
	_build_buttons()

func open() -> void:
	visible = true
	confirming_reset = false
	_build_buttons()
	get_tree().paused = true

func _close() -> void:
	visible = false
	confirming_reset = false
	get_tree().paused = false
	resume_pressed.emit()

func _build_buttons() -> void:
	for child in button_list.get_children():
		child.queue_free()

	var resume_btn := Button.new()
	resume_btn.add_theme_font_size_override("font_size", 16)
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(160, 18)
	resume_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	resume_btn.pressed.connect(func() -> void: _close())
	_style_button(resume_btn, Color(0.08, 0.22, 0.1))
	button_list.add_child(resume_btn)

	var touch_btn := Button.new()
	touch_btn.add_theme_font_size_override("font_size", 16)
	var touch_on: bool = GameManager.touch_controls_enabled
	touch_btn.text = "Touch Controls: " + ("ON" if touch_on else "OFF")
	touch_btn.custom_minimum_size = Vector2(160, 18)
	touch_btn.add_theme_color_override("font_color", PixelUI.GOLD)
	touch_btn.pressed.connect(func() -> void:
		GameManager.touch_controls_enabled = not GameManager.touch_controls_enabled
		TouchControls.set_enabled(GameManager.touch_controls_enabled)
		_build_buttons()
	)
	_style_button(touch_btn, Color(0.1, 0.15, 0.22))
	button_list.add_child(touch_btn)

	if not confirming_reset:
		_build_settings_section()

	var sep := HSeparator.new()
	button_list.add_child(sep)

	if not confirming_reset:
		var reset_btn := Button.new()
		reset_btn.add_theme_font_size_override("font_size", 16)
		reset_btn.text = "Restart Game"
		reset_btn.custom_minimum_size = Vector2(160, 18)
		reset_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		reset_btn.pressed.connect(func() -> void: confirming_reset = true; _build_buttons())
		_style_button(reset_btn, Color(0.25, 0.1, 0.08))
		button_list.add_child(reset_btn)
	else:
		var warn_label := Label.new()
		warn_label.add_theme_font_size_override("font_size", 8)
		warn_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		warn_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.04, 0.75))
		warn_label.add_theme_constant_override("shadow_offset_x", 1)
		warn_label.add_theme_constant_override("shadow_offset_y", 1)
		warn_label.text = "All progress will be lost!"
		warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_list.add_child(warn_label)

		var confirm_row := HBoxContainer.new()
		confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
		confirm_row.add_theme_constant_override("separation", 16)

		var yes_btn := Button.new()
		yes_btn.add_theme_font_size_override("font_size", 8)
		yes_btn.text = "Yes, Restart"
		yes_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		yes_btn.pressed.connect(func() -> void: reset_confirmed.emit(); _close())
		_style_button(yes_btn, Color(0.3, 0.08, 0.06))
		confirm_row.add_child(yes_btn)

		var no_btn := Button.new()
		no_btn.add_theme_font_size_override("font_size", 8)
		no_btn.text = "Cancel"
		no_btn.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		no_btn.pressed.connect(func() -> void: confirming_reset = false; _build_buttons())
		_style_button(no_btn, Color(0.15, 0.18, 0.22))
		confirm_row.add_child(no_btn)

		button_list.add_child(confirm_row)

func _build_settings_section() -> void:
	var sep := HSeparator.new()
	button_list.add_child(sep)

	var audio_header := Label.new()
	audio_header.text = "Audio"
	audio_header.add_theme_font_size_override("font_size", 8)
	audio_header.add_theme_color_override("font_color", PixelUI.GREEN)
	audio_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_list.add_child(audio_header)

	# 2x2 grid (not 4 stacked rows) so the panel fits between the HUD bars
	# at 720p without scrolling.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	button_list.add_child(grid)
	_add_volume_slider(grid, "Master", "master")
	_add_volume_slider(grid, "SFX", "sfx")
	_add_volume_slider(grid, "Music", "music")
	_add_volume_slider(grid, "Ambient", "ambient")

	var fs_btn := Button.new()
	fs_btn.add_theme_font_size_override("font_size", 16)
	fs_btn.text = "Fullscreen: " + ("ON" if AudioManager.is_fullscreen() else "OFF")
	fs_btn.custom_minimum_size = Vector2(160, 18)
	fs_btn.add_theme_color_override("font_color", PixelUI.GOLD)
	fs_btn.pressed.connect(func() -> void:
		AudioManager.set_fullscreen(not AudioManager.is_fullscreen())
		_build_buttons()
	)
	_style_button(fs_btn, Color(0.1, 0.15, 0.22))
	button_list.add_child(fs_btn)

func _add_volume_slider(grid: GridContainer, label_text: String, channel: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(78, 0)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	lbl.custom_minimum_size = Vector2(46, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioManager.get_volume(channel)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(56, 0)
	var ch: String = channel
	slider.value_changed.connect(func(v: float) -> void: AudioManager.set_volume(ch, v))
	row.add_child(slider)

	grid.add_child(row)

func _style_button(btn: Button, bg_color: Color) -> void:
	# Wood pixel button from the theme; the old bg colour survives as a light tint.
	PixelUI.button(btn, bg_color)
