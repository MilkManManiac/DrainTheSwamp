extends CanvasLayer

@onready var money_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/MoneyLabel
@onready var carry_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/CarryLabel
@onready var water_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/WaterLabel
@onready var day_label: Label = $MarginContainer/VBoxContainer/TopBar/HBox/DayLabel
@onready var tool_label: Label = $MarginContainer/VBoxContainer/BottomBar/HBox/ToolLabel
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/BottomBar/HBox/StaminaBar
@onready var hose_label: Label = $MarginContainer/VBoxContainer/BottomBar/HBox/HoseLabel
@onready var menu_button: Button = $MarginContainer/VBoxContainer/BottomBar/HBox/MenuButton

signal menu_pressed

# Phase 10c: Money counter animation
var displayed_money: float = 0.0
var money_tween: Tween = null

# Phase 6A: Stamina gradient fill style
var stamina_fill_style: StyleBoxFlat = null

# Cave air (swamp gas) bar — only visible inside caves
var air_bar: ProgressBar = null
var air_fill_style: StyleBoxFlat = null

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
	rate_label.add_theme_font_size_override("font_size", 8)
	rate_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.55))
	rate_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	rate_label.add_theme_constant_override("shadow_offset_x", 1)
	rate_label.add_theme_constant_override("shadow_offset_y", 1)
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
	air_bar.custom_minimum_size = Vector2(90, 16)
	air_bar.show_percentage = false
	air_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air_bar.tooltip_text = "Swamp gas: air remaining before you're forced out"
	air_fill_style = StyleBoxFlat.new()
	air_fill_style.bg_color = Color(0.35, 0.8, 0.85)
	air_fill_style.corner_radius_top_left = 2
	air_fill_style.corner_radius_top_right = 2
	air_fill_style.corner_radius_bottom_left = 2
	air_fill_style.corner_radius_bottom_right = 2
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.14, 0.16, 0.85)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	air_bar.add_theme_stylebox_override("fill", air_fill_style)
	air_bar.add_theme_stylebox_override("background", bg)
	var hbox: HBoxContainer = stamina_bar.get_parent()
	hbox.add_child(air_bar)
	hbox.move_child(air_bar, stamina_bar.get_index() + 1)
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
		air_fill_style.bg_color = Color(0.95, 0.30, 0.25)
	elif ratio < 0.45:
		air_fill_style.bg_color = Color(0.95, 0.72, 0.25)
	else:
		air_fill_style.bg_color = Color(0.35, 0.8, 0.85)

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
	day_label.text = "Day %d - %s" % [GameManager.current_day, time_str]

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
		money_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55))
		var glow_tw := create_tween()
		glow_tw.tween_interval(0.15)
		glow_tw.tween_callback(func() -> void:
			money_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		)

func _on_water_level_changed(_swamp_index: int, _percent: float) -> void:
	_update_water_label()

func _update_water_label() -> void:
	var total_pct: float = GameManager.get_total_water_percent()
	water_label.text = "Water: %.1f%%" % total_pct

func _update_tool_label() -> void:
	var tool_data: Dictionary = GameManager.tool_definitions[GameManager.current_tool_id]
	if GameManager.current_tool_id == "hose":
		var output: float = GameManager.get_tool_output("hose")
		tool_label.text = "%s (%.3f g/s)" % [tool_data["name"], output]
	else:
		var output: float = GameManager.get_effective_scoop(GameManager.current_tool_id)
		if output >= 10.0:
			tool_label.text = "%s (%.1f g)" % [tool_data["name"], output]
		elif output >= 1.0:
			tool_label.text = "%s (%.2f g)" % [tool_data["name"], output]
		else:
			tool_label.text = "%s (%.4f g)" % [tool_data["name"], output]

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	_update_stamina_color(current / maxf(maximum, 0.01))

func _on_hose_state_changed(active: bool, time_remaining: float) -> void:
	hose_label.visible = active
	if active:
		hose_label.text = "HOSE: %.1fs" % time_remaining

func _on_stat_upgraded(_stat_id: String, _new_level: int) -> void:
	_update_tool_label()
	_on_water_carried_changed(GameManager.water_carried, GameManager.get_carrying_capacity())

func _on_water_carried_changed(current: float, capacity: float) -> void:
	if capacity >= 10.0:
		carry_label.text = "Bag: %.1f/%.1f" % [current, capacity]
	elif capacity >= 1.0:
		carry_label.text = "Bag: %.2f/%.2f" % [current, capacity]
	else:
		carry_label.text = "Bag: %.3f/%.3f" % [current, capacity]

func _on_swamp_completed(swamp_index: int, _reward: float) -> void:
	_update_water_label()

# --- Phase 6A: HUD Icons & Stamina Gradient ---
func _build_hud_icons() -> void:
	# Money icon: yellow coin (circle approximation)
	var coin_icon := _make_icon_container()
	var coin_bg := ColorRect.new()
	coin_bg.custom_minimum_size = Vector2(5, 5)
	coin_bg.size = Vector2(5, 5)
	coin_bg.color = Color(1.0, 0.85, 0.2, 0.9)
	coin_icon.add_child(coin_bg)
	var coin_dot := ColorRect.new()
	coin_dot.custom_minimum_size = Vector2(1, 3)
	coin_dot.size = Vector2(1, 3)
	coin_dot.position = Vector2(2, 1)
	coin_dot.color = Color(0.8, 0.65, 0.1)
	coin_icon.add_child(coin_dot)
	var top_hbox: HBoxContainer = money_label.get_parent() as HBoxContainer
	top_hbox.add_child(coin_icon)
	top_hbox.move_child(coin_icon, 0)

	# Bag icon: brown square with flap
	var bag_icon := _make_icon_container()
	var bag_body := ColorRect.new()
	bag_body.custom_minimum_size = Vector2(5, 5)
	bag_body.size = Vector2(5, 5)
	bag_body.color = Color(0.55, 0.35, 0.15)
	bag_icon.add_child(bag_body)
	var bag_flap := ColorRect.new()
	bag_flap.custom_minimum_size = Vector2(5, 2)
	bag_flap.size = Vector2(5, 2)
	bag_flap.position = Vector2(0, 0)
	bag_flap.color = Color(0.65, 0.42, 0.18)
	bag_icon.add_child(bag_flap)
	top_hbox.add_child(bag_icon)
	var carry_idx: int = top_hbox.get_children().find(carry_label)
	if carry_idx >= 0:
		top_hbox.move_child(bag_icon, carry_idx)

	# Stamina icon: green lightning bolt (3 rects forming a zigzag)
	var bolt_icon := _make_icon_container()
	var b1 := ColorRect.new()
	b1.custom_minimum_size = Vector2(3, 2)
	b1.size = Vector2(3, 2)
	b1.position = Vector2(1, 0)
	b1.color = Color(0.3, 0.85, 0.2)
	bolt_icon.add_child(b1)
	var b2 := ColorRect.new()
	b2.custom_minimum_size = Vector2(3, 2)
	b2.size = Vector2(3, 2)
	b2.position = Vector2(0, 2)
	b2.color = Color(0.3, 0.85, 0.2)
	bolt_icon.add_child(b2)
	var b3 := ColorRect.new()
	b3.custom_minimum_size = Vector2(3, 2)
	b3.size = Vector2(3, 2)
	b3.position = Vector2(1, 4)
	b3.color = Color(0.3, 0.85, 0.2)
	bolt_icon.add_child(b3)
	var bot_hbox: HBoxContainer = tool_label.get_parent() as HBoxContainer
	bot_hbox.add_child(bolt_icon)
	var stam_idx: int = bot_hbox.get_children().find(stamina_bar)
	if stam_idx >= 0:
		bot_hbox.move_child(bolt_icon, stam_idx)

func _setup_news_ticker() -> void:
	# Throttled headline strip (one fading headline / ~45s) under the top bar.
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer
	var ticker: PanelContainer = preload("res://scripts/ui/news_ticker.gd").new()
	vbox.add_child(ticker)
	vbox.move_child(ticker, 1)

func _make_icon_container() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(8, 8)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _setup_stamina_gradient() -> void:
	# Clone the existing fill style so we can dynamically change color
	var existing: StyleBoxFlat = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if existing:
		stamina_fill_style = existing.duplicate() as StyleBoxFlat
		stamina_bar.add_theme_stylebox_override("fill", stamina_fill_style)

func _update_stamina_color(fraction: float) -> void:
	if not stamina_fill_style:
		return
	# Green → Yellow → Red gradient based on stamina fraction
	var color: Color
	if fraction > 0.5:
		# Green to Yellow (1.0 → 0.5)
		var f: float = (fraction - 0.5) / 0.5
		color = Color(0.2, 0.75, 0.3).lerp(Color(0.85, 0.8, 0.2), 1.0 - f)
	else:
		# Yellow to Red (0.5 → 0.0)
		var f: float = fraction / 0.5
		color = Color(0.85, 0.2, 0.15).lerp(Color(0.85, 0.8, 0.2), f)
	stamina_fill_style.bg_color = color
