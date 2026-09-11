extends CanvasLayer

# v3 pixel HUD: wood-plank strip on top (money / bag / day / water with pixel
# icons), tool card bottom-left, MENU card bottom-right. Skin only: the
# signals and GameManager wiring are the pre-v3 ones.
@onready var money_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/MoneyCell/MoneyLabel
@onready var carry_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/CarryCell/CarryLabel
@onready var water_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/WaterCell/WaterLabel
@onready var day_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/DayCell/DayLabel
@onready var phase_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/DayCell/PhaseLabel
@onready var day_icon: TextureRect = $MarginContainer/VBoxContainer/TopBar/HBox/DayCell/Icon
@onready var tool_label: Label = $MarginContainer/VBoxContainer/BottomBar/LeftCard/HBox/ToolLabel
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/BottomBar/LeftCard/HBox/StaminaBar
@onready var hose_label: Label = $MarginContainer/VBoxContainer/BottomBar/LeftCard/HBox/HoseLabel
@onready var menu_button: Button = $MarginContainer/VBoxContainer/BottomBar/RightCard/HBox/MenuButton

signal menu_pressed

# Phase 10c: Money counter animation
var displayed_money: float = 0.0
var money_tween: Tween = null

# Stamina fill: segmented pixel bar, recoloured by modulate (green -> red)
var stamina_fill_style: StyleBoxTexture = null

# Cave air (swamp gas) bar — only visible inside caves
var air_bar: ProgressBar = null
var air_fill_style: StyleBoxTexture = null
var _phase_is_night: bool = false

# Earn/drain rate readout (bottom bar): EMA over 1s samples of lifetime
# earnings + total gallons drained (both monotonic, so purchases don't spike it)
var rate_label: Label = null
var _rate_timer: float = 0.0
var _rate_last_money: float = -1.0
var _rate_last_drained: float = -1.0
var _money_rate: float = 0.0
var _gal_rate: float = 0.0

func _ready() -> void:
	_build_hud_icons()
	_setup_news_ticker()
	_setup_stamina_gradient()
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.water_level_changed.connect(_on_water_level_changed)
	GameManager.tool_changed.connect(func(_d: Dictionary) -> void: _update_tool_label())
	GameManager.tool_upgraded.connect(func(_t: String, _l: int) -> void: _update_tool_label())
	GameManager.stat_upgraded.connect(_on_stat_upgraded)
	GameManager.stamina_changed.connect(_on_stamina_changed)
	GameManager.hose_state_changed.connect(_on_hose_state_changed)
	GameManager.swamp_completed.connect(_on_swamp_completed)
	GameManager.water_carried_changed.connect(_on_water_carried_changed)
	GameManager.day_changed.connect(_on_day_changed)
	_setup_air_bar()
	GameManager.cave_air_changed.connect(_on_cave_air_changed)
	_setup_rate_label()

	menu_button.pressed.connect(func() -> void: menu_pressed.emit())

	# Initialize
	displayed_money = GameManager.money
	_on_money_changed(GameManager.money)
	_update_water_label()
	_update_tool_label()
	_on_stamina_changed(GameManager.current_stamina, GameManager.get_max_stamina())
	_on_water_carried_changed(GameManager.water_carried, GameManager.get_carrying_capacity())
	hose_label.visible = false
	_update_day_label()

func _process(_delta: float) -> void:
	_update_day_label()
	_update_rates(_delta)

func _setup_rate_label() -> void:
	rate_label = Label.new()
	rate_label.add_theme_font_size_override("font_size", PixelUI.SIZE_CAPTION)
	rate_label.add_theme_color_override("font_color", PixelUI.CREAM_DIM)
	rate_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate_label.tooltip_text = "Earning rate / draining rate (last minute)"
	rate_label.visible = false
	var hbox: HBoxContainer = stamina_bar.get_parent()
	hbox.add_child(rate_label)
	hbox.move_child(rate_label, air_bar.get_index() + 1)

func _update_rates(delta: float) -> void:
	_rate_timer += delta
	if _rate_timer < 1.0:
		return
	var lifetime: float = GameManager.lifetime_earnings
	var drained: float = 0.0
	for st in GameManager.swamp_states:
		drained += st["gallons_drained"]
	if _rate_last_money >= 0.0:
		var dm: float = maxf(lifetime - _rate_last_money, 0.0) / _rate_timer
		var dg: float = maxf(drained - _rate_last_drained, 0.0) / _rate_timer
		_money_rate = lerpf(_money_rate, dm, 0.3)
		_gal_rate = lerpf(_gal_rate, dg, 0.3)
		if _money_rate > 0.01 or _gal_rate > 0.0001:
			rate_label.visible = true
			rate_label.text = "%s/s  %s/s" % [Economy.format_money(_money_rate), Economy.format_gallons(_gal_rate)]
	_rate_last_money = lifetime
	_rate_last_drained = drained
	_rate_timer = 0.0

func _setup_air_bar() -> void:
	air_bar = ProgressBar.new()
	air_bar.custom_minimum_size = Vector2(84, 12)
	air_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	air_bar.show_percentage = false
	air_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air_bar.tooltip_text = "Swamp gas: air remaining before you're forced out"
	air_fill_style = PixelUI.bar_fill(Color(0.35, 0.8, 0.85))
	air_bar.add_theme_stylebox_override("fill", air_fill_style)
	var air_icon := PixelUI.icon("air")
	var hbox: HBoxContainer = stamina_bar.get_parent()
	hbox.add_child(air_icon)
	hbox.move_child(air_icon, stamina_bar.get_index() + 1)
	hbox.add_child(air_bar)
	hbox.move_child(air_bar, air_icon.get_index() + 1)
	air_icon.visible = GameManager.in_cave
	air_bar.visibility_changed.connect(func() -> void: air_icon.visible = air_bar.visible)
	air_bar.visible = GameManager.in_cave
	if GameManager.in_cave:
		_on_cave_air_changed(GameManager.cave_air, GameManager.cave_air_max)

func _on_cave_air_changed(current: float, maximum: float) -> void:
	if not GameManager.in_cave or maximum <= 0.0:
		air_bar.visible = false
		return
	air_bar.visible = true
	air_bar.max_value = maximum
	air_bar.value = current
	var ratio: float = current / maximum
	if ratio < 0.2:
		air_fill_style.modulate_color = Color(0.95, 0.30, 0.25)
	elif ratio < 0.45:
		air_fill_style.modulate_color = Color(0.95, 0.72, 0.25)
	else:
		air_fill_style.modulate_color = Color(0.35, 0.8, 0.85)

func _update_day_label() -> void:
	var t: float = GameManager.cycle_progress
	var time_str: String
	if t < 0.15:
		time_str = "Night"
	elif t < 0.25:
		time_str = "Dawn"
	elif t < 0.45:
		time_str = "Morning"
	elif t < 0.55:
		time_str = "Midday"
	elif t < 0.65:
		time_str = "Afternoon"
	elif t < 0.75:
		time_str = "Dusk"
	else:
		time_str = "Night"
	day_label.text = "DAY %d" % GameManager.current_day
	phase_label.text = time_str.to_upper()
	var night: bool = t < 0.2 or t >= 0.7
	if night != _phase_is_night or day_icon.texture == null:
		_phase_is_night = night
		day_icon.texture = PixelUI.ICONS["moon"] if night else PixelUI.ICONS["sun"]

func _on_day_changed(_day: int) -> void:
	_update_day_label()

func _on_money_changed(amount: float) -> void:
	var delta_money: float = amount - displayed_money
	# Smooth roll-up animation (Phase 10c)
	if money_tween and money_tween.is_valid():
		money_tween.kill()
	money_tween = create_tween()
	money_tween.tween_method(func(val: float) -> void:
		displayed_money = val
		money_label.text = Economy.format_money(val)
	, displayed_money, amount, 0.3)
	# Golden pulse on big earnings (restore to the label's base gold, not green)
	if delta_money > 10.0:
		money_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
		var glow_tw := create_tween()
		glow_tw.tween_interval(0.15)
		glow_tw.tween_callback(func() -> void:
			money_label.add_theme_color_override("font_color", PixelUI.GOLD)
		)

func _on_water_level_changed(_swamp_index: int, _percent: float) -> void:
	_update_water_label()

func _update_water_label() -> void:
	var total_pct: float = GameManager.get_total_water_percent()
	water_label.text = "%.1f%%" % total_pct

func _update_tool_label() -> void:
	var tool_data: Dictionary = GameManager.tool_definitions[GameManager.current_tool_id]
	if GameManager.current_tool_id == "hose":
		var output: float = GameManager.get_tool_output("hose")
		tool_label.text = "%s %.3f g/s" % [str(tool_data["name"]).to_upper(), output]
	else:
		var output: float = GameManager.get_effective_scoop(GameManager.current_tool_id)
		var tname: String = str(tool_data["name"]).to_upper()
		if output >= 10.0:
			tool_label.text = "%s %.1f g" % [tname, output]
		elif output >= 1.0:
			tool_label.text = "%s %.2f g" % [tname, output]
		else:
			tool_label.text = "%s %.4f g" % [tname, output]

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	_update_stamina_color(current / maxf(maximum, 0.01))

func _on_hose_state_changed(active: bool, time_remaining: float) -> void:
	hose_label.visible = active
	if active:
		hose_label.text = "HOSE %.1fs" % time_remaining

func _on_stat_upgraded(_stat_id: String, _new_level: int) -> void:
	_update_tool_label()
	_on_water_carried_changed(GameManager.water_carried, GameManager.get_carrying_capacity())

func _on_water_carried_changed(current: float, capacity: float) -> void:
	if capacity >= 10.0:
		carry_label.text = "%.1f/%.1f" % [current, capacity]
	elif capacity >= 1.0:
		carry_label.text = "%.2f/%.2f" % [current, capacity]
	else:
		carry_label.text = "%.3f/%.3f" % [current, capacity]

func _on_swamp_completed(swamp_index: int, _reward: float) -> void:
	_update_water_label()

func _build_hud_icons() -> void:
	# Icons are pixel textures placed in hud.tscn (assets/art/ui/icon_*.png);
	# nothing to build. Kept so the _ready order reads the same as before.
	pass

func _setup_news_ticker() -> void:
	# Throttled headline strip (one fading headline / ~45s) under the top bar.
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer
	var ticker: PanelContainer = preload("res://scripts/ui/news_ticker.gd").new()
	vbox.add_child(ticker)
	vbox.move_child(ticker, 1)

func _setup_stamina_gradient() -> void:
	stamina_fill_style = PixelUI.bar_fill(Color(0.2, 0.75, 0.3))
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill_style)

func _update_stamina_color(fraction: float) -> void:
	if not stamina_fill_style:
		return
	# Green -> Yellow -> Red by stamina fraction (modulates the pixel segments)
	var color: Color
	if fraction > 0.5:
		var f: float = (fraction - 0.5) / 0.5
		color = Color(0.2, 0.75, 0.3).lerp(Color(0.85, 0.8, 0.2), 1.0 - f)
	else:
		var f: float = fraction / 0.5
		color = Color(0.85, 0.2, 0.15).lerp(Color(0.85, 0.8, 0.2), f)
	stamina_fill_style.modulate_color = color
