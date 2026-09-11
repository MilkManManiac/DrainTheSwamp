extends PanelContainer

@onready var tool_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ToolList
@onready var close_button: Button = $MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/TopBar/TitleLabel

var _dirty: bool = false
var _dirty_structural: bool = false
var _refresh_cooldown: float = 0.0
const REFRESH_INTERVAL: float = 0.3

# Closures registered during a build; run on the money tick to update
# affordability/labels IN PLACE. A full tree rebuild every 0.3s destroyed
# hover state and open tooltips mid-interaction, so rebuilds are reserved
# for structural changes (tab switch, purchases, prestige).
var _live_updaters: Array[Callable] = []

var current_tab: int = 0  # 0=Tools, 1=Stats, 2=Influence
var tab_buttons: Array[Button] = []
var confirming_sellout: bool = false

func _ready() -> void:
	close_button.pressed.connect(func() -> void: close())
	# Money changes constantly while selling — soft refresh only.
	GameManager.money_changed.connect(func(_m: float) -> void: _dirty = true)
	# Everything else changes row structure/costs — full rebuild.
	GameManager.tool_upgraded.connect(func(_t: String, _l: int) -> void: _mark_structural())
	GameManager.tool_changed.connect(func(_d: Dictionary) -> void: _mark_structural())
	GameManager.camel_changed.connect(func() -> void: _mark_structural())
	GameManager.upgrade_changed.connect(func() -> void: _mark_structural())
	GameManager.stat_upgraded.connect(func(_s: String, _l: int) -> void: _mark_structural())
	GameManager.prestige_changed.connect(func() -> void: _mark_structural())
	GameManager.pump_changed.connect(func(_i: int, _l: int) -> void: _mark_structural())
	visible = false

func _mark_structural() -> void:
	_dirty = true
	_dirty_structural = true
	_refresh_cooldown = REFRESH_INTERVAL

func _process(delta: float) -> void:
	if _dirty and visible:
		_refresh_cooldown -= delta
		if _refresh_cooldown <= 0.0:
			var structural: bool = _dirty_structural
			_dirty = false
			_dirty_structural = false
			_refresh_cooldown = REFRESH_INTERVAL
			if structural:
				_refresh()
			else:
				_soft_refresh()

func _soft_refresh() -> void:
	for fn in _live_updaters:
		fn.call()

func _register_updater(fn: Callable) -> void:
	_live_updaters.append(fn)
	fn.call()

# Standard affordability wiring: the button is always connected (GameManager
# buy functions self-guard on funds); this just keeps disabled/color live.
func _register_afford(btn: Button, cost: float, active_color: Color, extra_ok: bool = true, use_influence: bool = false) -> void:
	_register_updater(func() -> void:
		if not is_instance_valid(btn):
			return
		var funds: float = GameManager.influence if use_influence else GameManager.money
		var ok: bool = extra_ok and funds >= cost
		btn.disabled = not ok
		if ok:
			btn.add_theme_color_override("font_color", active_color)
		else:
			btn.remove_theme_color_override("font_color")
	)

func open() -> void:
	visible = true
	confirming_sellout = false
	_refresh_cooldown = 0.0
	_refresh()
	# Slide in from right
	var vp_w: float = get_viewport_rect().size.x
	position.x = vp_w
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "position:x", 0.0, 0.2)

func close() -> void:
	var vp_w: float = get_viewport_rect().size.x
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "position:x", vp_w, 0.15)
	tw.tween_callback(func() -> void: visible = false)

func _refresh() -> void:
	_live_updaters.clear()
	for child in tool_list.get_children():
		tool_list.remove_child(child)
		child.queue_free()

	# --- Tab Bar ---
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	tab_buttons.clear()

	var tab_names: Array[String] = ["Tools", "Stats", "Influence"]
	var tab_colors: Array[Color] = [
		Color(0.55, 0.48, 0.2),   # Gold for tools
		Color(0.3, 0.5, 0.8),     # Blue for stats
		Color(0.6, 0.3, 0.7),     # Purple for influence
	]
	for i in range(3):
		var tab_idx: int = i
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 20)

		# Active tab sits "pressed" into the wood; inactive tabs are raised.
		PixelUI.button(btn, tab_colors[i])
		if current_tab == i:
			var down: StyleBox = btn.get_theme_stylebox("pressed")
			btn.add_theme_stylebox_override("normal", down)
			btn.add_theme_stylebox_override("hover", down)
			btn.add_theme_color_override("font_color", tab_colors[i].lightened(0.45))
		else:
			btn.add_theme_color_override("font_color", PixelUI.CREAM_DIM)

		btn.pressed.connect(func() -> void:
			current_tab = tab_idx
			_refresh()
		)

		tab_bar.add_child(btn)
		tab_buttons.append(btn)

	tool_list.add_child(tab_bar)

	# --- Tab Content ---
	match current_tab:
		0:
			_build_tools_tab()
		1:
			_build_stats_tab()
		2:
			_build_prestige_tab()

# =============================================================================
# TOOLS TAB
# =============================================================================
func _build_tools_tab() -> void:
	# --- Camel Section (at top, hidden until unlocked) ---
	if GameManager.camel_unlocked:
		_build_camel_section()
		var tool_sep := HSeparator.new()
		tool_sep.add_theme_constant_override("separation", 8)
		tool_list.add_child(tool_sep)
	_build_pump_section()

	var sorted_tools: Array = GameManager.tool_definitions.keys()
	sorted_tools.sort_custom(func(a: Variant, b: Variant) -> bool: return GameManager.tool_definitions[a]["cost"] < GameManager.tool_definitions[b]["cost"])

	for tool_id in sorted_tools:
		var tid: String = tool_id
		var defn: Dictionary = GameManager.tool_definitions[tid]
		var owned_data: Dictionary = GameManager.tools_owned[tid]

		var row_panel := PanelContainer.new()
		var row_style: StyleBoxTexture = PixelUI.inset(Color(0.12, 0.12, 0.16, 0.6))
		if GameManager.current_tool_id == tid:
			row_style.border_width_left = 2
			row_style.border_color = Color(0.3, 0.9, 0.4, 0.5)
		row_panel.add_theme_stylebox_override("panel", row_style)

		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 8)

		var info_label := Label.new()
		info_label.add_theme_font_size_override("font_size", 8)
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.04, 0.75))
		info_label.add_theme_constant_override("shadow_offset_x", 1)
		info_label.add_theme_constant_override("shadow_offset_y", 1)

		if owned_data["owned"]:
			var output: float = GameManager.get_tool_output(tid)
			if defn["type"] == "semi_auto":
				info_label.text = "%s Lv%d (%.3f g/s)" % [defn["name"], owned_data["level"], output]
			elif output >= 10.0:
				info_label.text = "%s Lv%d (%.1f g)" % [defn["name"], owned_data["level"], output]
			elif output >= 1.0:
				info_label.text = "%s Lv%d (%.2f g)" % [defn["name"], owned_data["level"], output]
			else:
				info_label.text = "%s Lv%d (%.4f g)" % [defn["name"], owned_data["level"], output]
			if GameManager.current_tool_id == tid:
				info_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			else:
				info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		else:
			info_label.text = "%s [LOCKED]" % defn["name"]
			info_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))

		entry.add_child(info_label)

		if owned_data["owned"]:
			var equip_btn := Button.new()
			equip_btn.add_theme_font_size_override("font_size", 8)
			equip_btn.custom_minimum_size = Vector2(64, 0)
			if GameManager.current_tool_id == tid:
				equip_btn.text = "[ON]"
				equip_btn.disabled = true
			else:
				equip_btn.text = "Equip"
				equip_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
				var t: String = tid
				equip_btn.pressed.connect(func() -> void: GameManager.equip_tool(t))
			_style_button(equip_btn, Color(0.3, 0.28, 0.1))
			entry.add_child(equip_btn)

			var upgrade_btn := Button.new()
			upgrade_btn.add_theme_font_size_override("font_size", 8)
			var cost: float = GameManager.get_tool_upgrade_cost(tid)
			upgrade_btn.text = "Up %s" % Economy.format_money(cost)
			upgrade_btn.custom_minimum_size = Vector2(96, 0)
			var ut: String = tid
			upgrade_btn.pressed.connect(func() -> void: GameManager.upgrade_tool(ut))
			_register_afford(upgrade_btn, cost, Color(0.5, 0.85, 1.0))
			_style_button(upgrade_btn, Color(0.1, 0.18, 0.3))
			entry.add_child(upgrade_btn)
		else:
			var buy_btn := Button.new()
			buy_btn.add_theme_font_size_override("font_size", 8)
			buy_btn.text = "Buy %s" % Economy.format_money(defn["cost"])
			buy_btn.custom_minimum_size = Vector2(110, 0)
			var prev_owned := true
			var tool_index: int = sorted_tools.find(tid)
			if tool_index > 0:
				var prev_id: String = sorted_tools[tool_index - 1]
				if not GameManager.tools_owned[prev_id]["owned"]:
					prev_owned = false
			var t: String = tid
			buy_btn.pressed.connect(func() -> void: GameManager.buy_tool(t); GameManager.equip_tool(t))
			_register_afford(buy_btn, defn["cost"], Color(0.3, 1.0, 0.4), prev_owned)
			_style_button(buy_btn, Color(0.08, 0.22, 0.1))
			entry.add_child(buy_btn)

		row_panel.tooltip_text = _get_tool_tooltip(tid, defn, owned_data)
		row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		row_panel.add_child(entry)
		tool_list.add_child(row_panel)


# =============================================================================
# STATS TAB
# =============================================================================
func _build_stats_tab() -> void:
	# Order: core stats first, then power stats
	var stat_order: Array[String] = [
		"carrying_capacity", "movement_speed", "stamina", "stamina_regen",
		"water_value", "scoop_power"
	]

	# Core stats header
	var core_header := Label.new()
	core_header.text = "-- Core Stats --"
	core_header.add_theme_font_size_override("font_size", 8)
	core_header.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	core_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(core_header)

	for i in range(stat_order.size()):
		var stat_id: String = stat_order[i]

		# Power stats header
		if stat_id == "water_value":
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 6)
			tool_list.add_child(sep)
			var power_header := Label.new()
			power_header.text = "-- Power Stats --"
			power_header.add_theme_font_size_override("font_size", 8)
			power_header.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
			power_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tool_list.add_child(power_header)

		var defn: Dictionary = GameManager.stat_definitions[stat_id]
		var level: int = GameManager.stat_levels[stat_id]
		var value: float = GameManager.get_stat_value(stat_id)

		var row_panel := PanelContainer.new()
		var row_style: StyleBoxTexture = PixelUI.inset(Color(0.1, 0.12, 0.18, 0.6))
		row_panel.add_theme_stylebox_override("panel", row_style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Stat info
		var info_label := Label.new()
		info_label.add_theme_font_size_override("font_size", 8)
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.04, 0.75))
		info_label.add_theme_constant_override("shadow_offset_x", 1)
		info_label.add_theme_constant_override("shadow_offset_y", 1)

		var value_str: String = _format_stat_value(stat_id, defn, value)
		if level > 0:
			info_label.text = "%s Lv%d (%s)" % [defn["name"], level, value_str]
			info_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		else:
			info_label.text = "%s (%s)" % [defn["name"], value_str]
			info_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		row.add_child(info_label)

		# Upgrade button
		if GameManager.is_stat_maxed(stat_id):
			var max_label := Label.new()
			max_label.text = "[MAX]"
			max_label.add_theme_font_size_override("font_size", 8)
			max_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			row.add_child(max_label)
		else:
			var cost: float = GameManager.get_stat_upgrade_cost(stat_id)
			var up_btn := Button.new()
			up_btn.add_theme_font_size_override("font_size", 8)
			up_btn.text = "Up %s" % Economy.format_money(cost)
			up_btn.custom_minimum_size = Vector2(110, 0)
			var sid: String = stat_id
			up_btn.pressed.connect(func() -> void: GameManager.upgrade_stat(sid))
			_register_afford(up_btn, cost, Color(0.5, 0.85, 1.0))
			_style_button(up_btn, Color(0.1, 0.18, 0.3))
			row.add_child(up_btn)

		# Tooltip
		row_panel.tooltip_text = _get_stat_tooltip(stat_id, defn, level, value)
		row_panel.mouse_filter = Control.MOUSE_FILTER_PASS

		row_panel.add_child(row)
		tool_list.add_child(row_panel)

	# --- Upgrades Section (merged into Stats tab) ---
	var upg_sep := HSeparator.new()
	upg_sep.add_theme_constant_override("separation", 6)
	tool_list.add_child(upg_sep)
	var upg_header := Label.new()
	upg_header.text = "-- Upgrades --"
	upg_header.add_theme_font_size_override("font_size", 8)
	upg_header.add_theme_color_override("font_color", Color(0.3, 0.65, 0.35))
	upg_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(upg_header)

	var sorted_upgrades: Array = GameManager.upgrade_definitions.keys()
	sorted_upgrades.sort_custom(func(a: Variant, b: Variant) -> bool: return GameManager.upgrade_definitions[a]["order"] < GameManager.upgrade_definitions[b]["order"])

	for upgrade_id in sorted_upgrades:
		var uid: String = upgrade_id
		var udefn: Dictionary = GameManager.upgrade_definitions[uid]
		var ulevel: int = GameManager.upgrades_owned[uid]
		var is_maxed: bool = GameManager.is_upgrade_maxed(uid)

		var u_panel := PanelContainer.new()
		var u_style: StyleBoxTexture = PixelUI.inset(Color(0.1, 0.14, 0.1, 0.6))
		u_panel.add_theme_stylebox_override("panel", u_style)

		var u_row := HBoxContainer.new()
		u_row.add_theme_constant_override("separation", 8)

		var u_info := Label.new()
		u_info.add_theme_font_size_override("font_size", 8)
		u_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u_info.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.04, 0.75))
		u_info.add_theme_constant_override("shadow_offset_x", 1)
		u_info.add_theme_constant_override("shadow_offset_y", 1)

		if ulevel > 0:
			u_info.text = "%s Lv%d" % [udefn["name"], ulevel]
			u_info.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
		else:
			u_info.text = "%s" % udefn["name"]
			u_info.add_theme_color_override("font_color", Color(0.55, 0.6, 0.55))
		u_row.add_child(u_info)

		if is_maxed:
			var umax_label := Label.new()
			umax_label.text = "[MAX]"
			umax_label.add_theme_font_size_override("font_size", 8)
			umax_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			u_row.add_child(umax_label)
		else:
			var u_btn := Button.new()
			u_btn.add_theme_font_size_override("font_size", 8)
			var u_cost: float = GameManager.get_upgrade_cost(uid)
			if ulevel == 0:
				u_btn.text = "Buy %s" % Economy.format_money(u_cost)
			else:
				u_btn.text = "Up %s" % Economy.format_money(u_cost)
			u_btn.custom_minimum_size = Vector2(110, 0)
			var u: String = uid
			u_btn.pressed.connect(func() -> void: GameManager.buy_upgrade(u))
			_register_afford(u_btn, u_cost, Color(0.4, 1.0, 0.5))
			_style_button(u_btn, Color(0.08, 0.2, 0.08))
			u_row.add_child(u_btn)

		u_panel.tooltip_text = _get_upgrade_tooltip(uid, udefn, ulevel)
		u_panel.mouse_filter = Control.MOUSE_FILTER_PASS

		u_panel.add_child(u_row)
		tool_list.add_child(u_panel)

# =============================================================================
# INFLUENCE (PRESTIGE) TAB
# =============================================================================
func _build_prestige_tab() -> void:
	# --- Balance header ---
	var bal := Label.new()
	bal.text = "Influence: %d" % int(GameManager.influence)
	bal.add_theme_font_size_override("font_size", 16)
	bal.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(bal)

	var sub := Label.new()
	sub.text = "Times Sold Out: %d" % GameManager.prestige_count
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(sub)

	# --- Sell Out panel ---
	var sellout_panel := PanelContainer.new()
	var sellout_style: StyleBoxTexture = PixelUI.inset(Color(0.14, 0.08, 0.16, 0.6))
	sellout_panel.add_theme_stylebox_override("panel", sellout_style)

	var sellout_col := VBoxContainer.new()
	sellout_col.add_theme_constant_override("separation", 6)

	var pending_lbl := Label.new()
	pending_lbl.add_theme_font_size_override("font_size", 8)
	pending_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	pending_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sellout_col.add_child(pending_lbl)

	# Progress toward the NEXT influence point (sqrt curve -> next threshold).
	# Live-updated: lifetime earnings tick up while the panel is open.
	var next_lbl := Label.new()
	next_lbl.add_theme_font_size_override("font_size", 8)
	next_lbl.add_theme_color_override("font_color", Color(0.62, 0.55, 0.78))
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sellout_col.add_child(next_lbl)

	_register_updater(func() -> void:
		if not is_instance_valid(pending_lbl):
			return
		var p: int = GameManager.get_pending_influence()
		pending_lbl.text = "Pending payout: +%d Influence" % p
		var next_thresh: float = GameManager.PRESTIGE_SCALE * pow(float(p + 1), 2.0)
		var prev_thresh: float = GameManager.PRESTIGE_SCALE * pow(float(p), 2.0)
		var frac: float = clampf((GameManager.lifetime_earnings - prev_thresh) / maxf(next_thresh - prev_thresh, 1.0), 0.0, 1.0)
		next_lbl.text = "Next +1 at %s lifetime (%d%%)" % [Economy.format_money(next_thresh), int(frac * 100.0)]
	)

	if not confirming_sellout:
		var sellout_btn := Button.new()
		sellout_btn.add_theme_font_size_override("font_size", 16)
		sellout_btn.text = "SELL OUT"
		sellout_btn.custom_minimum_size = Vector2(160, 30)
		sellout_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sellout_btn.pressed.connect(func() -> void:
			confirming_sellout = true
			_refresh()
		)
		_register_updater(func() -> void:
			if not is_instance_valid(sellout_btn):
				return
			var ok: bool = GameManager.can_prestige()
			sellout_btn.disabled = not ok
			if ok:
				sellout_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
			else:
				sellout_btn.remove_theme_color_override("font_color")
		)
		_style_button(sellout_btn, Color(0.3, 0.12, 0.3))
		sellout_col.add_child(sellout_btn)
	else:
		var warn := Label.new()
		warn.add_theme_font_size_override("font_size", 8)
		warn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		warn.text = "Resets money, tools, stats &\nswamp progress. You keep your Influence."
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sellout_col.add_child(warn)

		# The handler's blessing — selling out is NA's idea of career growth
		var na_line := Label.new()
		na_line.add_theme_font_size_override("font_size", 8)
		na_line.add_theme_color_override("font_color", Color(0.55, 0.85, 0.60))
		na_line.text = "\"The swamp refills. The arrangement continues.\" — NA"
		na_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sellout_col.add_child(na_line)

		var confirm_row := HBoxContainer.new()
		confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
		confirm_row.add_theme_constant_override("separation", 16)

		var yes_btn := Button.new()
		yes_btn.add_theme_font_size_override("font_size", 8)
		yes_btn.text = "Yes, Sell Out"
		yes_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		yes_btn.pressed.connect(func() -> void:
			confirming_sellout = false
			GameManager.prestige()
		)
		_style_button(yes_btn, Color(0.3, 0.12, 0.3))
		confirm_row.add_child(yes_btn)

		var no_btn := Button.new()
		no_btn.add_theme_font_size_override("font_size", 8)
		no_btn.text = "Cancel"
		no_btn.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		no_btn.pressed.connect(func() -> void:
			confirming_sellout = false
			_refresh()
		)
		_style_button(no_btn, Color(0.15, 0.18, 0.22))
		confirm_row.add_child(no_btn)
		sellout_col.add_child(confirm_row)

	sellout_panel.add_child(sellout_col)
	tool_list.add_child(sellout_panel)

	# --- Upgrades header ---
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	tool_list.add_child(sep)
	var hdr := Label.new()
	hdr.text = "-- Permanent Upgrades --"
	hdr.add_theme_font_size_override("font_size", 8)
	hdr.add_theme_color_override("font_color", Color(0.75, 0.55, 0.9))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(hdr)

	_build_prestige_upgrade_row("kickback", "Kickback", "x1.25 money per level")
	_build_prestige_upgrade_row("muscle", "Muscle", "x1.25 scoop output per level")
	_build_prestige_upgrade_row("cap_hike", "Cap Hike", "+25% stat caps per level")
	_build_prestige_upgrade_row("war_chest", "War Chest", "Start with seed money + tools")

	# --- The Arrangement: one perk per sell-out, no purchase needed ---
	var arr_sep := HSeparator.new()
	arr_sep.add_theme_constant_override("separation", 6)
	tool_list.add_child(arr_sep)
	var arr_hdr := Label.new()
	arr_hdr.text = "-- The Arrangement --"
	arr_hdr.add_theme_font_size_override("font_size", 8)
	arr_hdr.add_theme_color_override("font_color", Color(0.55, 0.85, 0.60))
	arr_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(arr_hdr)

	var perks: Array = [
		{"p": 1, "name": "Federal Infrastructure Grant", "desc": "Pumps at half price",
			"na": "\"We know a man on the appropriations committee. We know all the men on the appropriations committee.\" — NA"},
		{"p": 2, "name": "Camel Caravan", "desc": "Camel herd cap x3",
			"na": "\"A caravan says: this man is settled. Also, they carry water.\" — NA"},
		{"p": 3, "name": "NA Courier Service", "desc": "In-cave sell basin; documents auto-read",
			"na": "\"Our couriers were in the caves before you. Do not ask how. They are professionals.\" — NA"},
		{"p": 4, "name": "Buyback Windows", "desc": "Periodic 2x sell-price events",
			"na": "\"Sometimes a buyer needs water gone quickly and quietly, at twice the price. You will know the moment.\" — NA"},
	]
	for perk in perks:
		var unlocked: bool = GameManager.prestige_count >= perk["p"]
		var perk_panel := PanelContainer.new()
		var perk_style: StyleBoxTexture = PixelUI.inset(Color(0.08, 0.14, 0.10, 0.6) if unlocked else Color(0.10, 0.10, 0.12, 0.5))
		perk_panel.add_theme_stylebox_override("panel", perk_style)
		var perk_lbl := Label.new()
		perk_lbl.add_theme_font_size_override("font_size", 8)
		if unlocked:
			perk_lbl.text = "[P%d] %s — %s" % [perk["p"], perk["name"], perk["desc"]]
			perk_lbl.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
		else:
			perk_lbl.text = "[P%d] Sell out %d times to unlock" % [perk["p"], perk["p"]]
			perk_lbl.add_theme_color_override("font_color", Color(0.45, 0.48, 0.5))
		perk_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		perk_panel.tooltip_text = "%s\n%s\n\n%s" % [perk["name"], perk["desc"], perk["na"]] if unlocked else "Unlocks at %d sell-outs" % perk["p"]
		perk_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		perk_panel.add_child(perk_lbl)
		tool_list.add_child(perk_panel)

func _build_prestige_upgrade_row(key: String, display_name: String, effect: String) -> void:
	var level: int = GameManager.prestige_upgrades[key]
	var cost: int = GameManager.get_prestige_upgrade_cost(key)

	var row_panel := PanelContainer.new()
	var row_style: StyleBoxTexture = PixelUI.inset(Color(0.12, 0.09, 0.16, 0.6))
	row_panel.add_theme_stylebox_override("panel", row_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info_label := Label.new()
	info_label.add_theme_font_size_override("font_size", 8)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.04, 0.75))
	info_label.add_theme_constant_override("shadow_offset_x", 1)
	info_label.add_theme_constant_override("shadow_offset_y", 1)
	if level > 0:
		info_label.text = "%s Lv%d" % [display_name, level]
		info_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	else:
		info_label.text = display_name
		info_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	row.add_child(info_label)

	var buy_btn := Button.new()
	buy_btn.add_theme_font_size_override("font_size", 8)
	buy_btn.text = "Buy (%d Inf)" % cost
	buy_btn.custom_minimum_size = Vector2(110, 0)
	var k: String = key
	buy_btn.pressed.connect(func() -> void: GameManager.buy_prestige_upgrade(k))
	_register_afford(buy_btn, float(cost), Color(0.9, 0.7, 1.0), true, true)
	_style_button(buy_btn, Color(0.2, 0.1, 0.25))
	row.add_child(buy_btn)

	var tip: String = "%s\n%s\nLevel: %d\nCost: %d Influence" % [display_name, effect, level, cost]
	if key == "war_chest":
		tip += "\nNext start money: %s" % Economy.format_money(_war_chest_seed_at(level + 1))
		var starter_names: Array = ["Spoon", "Cup", "Bucket"]
		if level < starter_names.size():
			tip += "\nAlso starts owned: %s" % ", ".join(starter_names.slice(0, level + 1))
	# One handler line each — the upgrades are NA's payroll categories
	var na_notes: Dictionary = {
		"kickback": "\"Everyone takes a cut. Yours is simply honest about it.\" — NA",
		"muscle": "\"We sent protein powder and a man who teaches lifting. Do not ask where he teaches.\" — NA",
		"cap_hike": "\"Regulations are for people without friends.\" — NA",
		"war_chest": "\"Consider it an advance. Northwind always collects.\" — NA",
	}
	if na_notes.has(key):
		tip += "\n\n%s" % na_notes[key]
	row_panel.tooltip_text = tip
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	row_panel.add_child(row)
	tool_list.add_child(row_panel)

func _war_chest_seed_at(level: int) -> float:
	if level <= 0:
		return 0.0
	return 500.0 * pow(2.0, level - 1)

func _format_stat_value(stat_id: String, defn: Dictionary, value: float) -> String:
	var fmt: String = defn.get("format", "value")
	match fmt:
		"gal":
			if value >= 10.0:
				return "%.1f gal" % value
			elif value >= 1.0:
				return "%.2f gal" % value
			else:
				return "%.3f gal" % value
		"multiplier":
			return "%.2fx" % value
		"per_sec":
			return "%.2f/s" % value
		"percent":
			return "%.0f%%" % (value * 100.0)
		_:
			if value >= 10.0:
				return "%.1f" % value
			elif value >= 1.0:
				return "%.2f" % value
			else:
				return "%.3f" % value

func _get_stat_tooltip(stat_id: String, defn: Dictionary, level: int, value: float) -> String:
	var tip: String = "%s" % defn["name"]
	var value_str: String = _format_stat_value(stat_id, defn, value)
	tip += "\nCurrent: %s (Lv%d)" % [value_str, level]

	var next_value: float = GameManager.get_stat_value_at_level(stat_id, level + 1)
	var next_str: String = _format_stat_value(stat_id, defn, next_value)
	var growth: float = (defn.get("growth_rate", 1.15) - 1.0) * 100.0
	tip += "\nNext: %s (+%.0f%%)" % [next_str, growth]

	# Special stat notes
	match stat_id:
		"scoop_power":
			tip += "\nMultiplies all manual tool output"
		"water_value":
			tip += "\nMultiplies money earned per gallon"

	var cost: float = GameManager.get_stat_upgrade_cost(stat_id)
	tip += "\nCost: %s" % Economy.format_money(cost)
	return tip

# =============================================================================
# TOOLTIPS
# =============================================================================
func _get_upgrade_tooltip(uid: String, defn: Dictionary, level: int) -> String:
	var tip: String = "%s - %s" % [defn["name"], defn["description"]]
	match uid:
		"auto_scooper":
			var cur_interval: float = GameManager.get_auto_scoop_interval()
			tip += "\nScoop every %.2fs" % cur_interval
			var next_interval: float = maxf(2.5 * pow(0.92, level + 1), 0.5)
			tip += "\nNext: %.2fs (-8%%)" % next_interval
		"lantern":
			if level > 0:
				tip += "\nRadius: %.0fpx, Brightness: %.1f" % [GameManager.get_lantern_radius(), GameManager.get_lantern_energy()]
			else:
				tip += "\nAutomatic light during night\n200px radius"
	if not GameManager.is_upgrade_maxed(uid):
		tip += "\nCost: %s" % Economy.format_money(GameManager.get_upgrade_cost(uid))
	return tip

func _get_tool_tooltip(tid: String, defn: Dictionary, owned_data: Dictionary) -> String:
	var tip: String = "%s" % defn["name"]
	if defn["type"] == "semi_auto":
		tip += " (auto-drain)"
	else:
		tip += " (manual scoop)"

	if owned_data["owned"]:
		var level: int = owned_data["level"]
		var cur_output: float = GameManager.get_tool_output(tid)
		if defn["type"] == "semi_auto":
			tip += "\nOutput: %.4f gal/s" % cur_output
		else:
			tip += "\nOutput: %.4f gal/scoop" % cur_output

		var next_output: float = GameManager.get_tool_raw_output_at_level(tid, level + 1)
		var cur_cmp: float = GameManager.get_tool_raw_output_at_level(tid, level)
		if defn["type"] == "manual":
			next_output *= GameManager.get_stat_value("scoop_power")
			cur_cmp *= GameManager.get_stat_value("scoop_power")
		elif defn["type"] == "semi_auto":
			next_output *= sqrt(GameManager.get_stat_value("scoop_power"))
			cur_cmp *= sqrt(GameManager.get_stat_value("scoop_power"))
		var gain_pct: float = (next_output / maxf(cur_cmp, 0.000001) - 1.0) * 100.0
		if defn["type"] == "semi_auto":
			tip += "\nNext Lv%d: %.4f gal/s (+%.0f%%)" % [level + 1, next_output, gain_pct]
		else:
			tip += "\nNext Lv%d: %.4f gal (+%.0f%%)" % [level + 1, next_output, gain_pct]
		if (level + 1) % 10 == 0:
			tip += "\nMILESTONE: Lv%d doubles output!" % (level + 1)

		var cost: float = GameManager.get_tool_upgrade_cost(tid)
		tip += "\nUpgrade: %s" % Economy.format_money(cost)
	else:
		var base_out: float = defn["base_output"]
		if defn["type"] == "manual":
			base_out *= GameManager.get_stat_value("scoop_power")
		if defn["type"] == "semi_auto":
			tip += "\nBase output: %.4f gal/s" % base_out
		else:
			tip += "\nBase output: %.4f gal/scoop" % base_out
		tip += "\nCost: %s" % Economy.format_money(defn["cost"])
	return tip

# =============================================================================
# PUMP SECTION — the passive/idle tier: one purchasable pump per unlocked pool.
# =============================================================================
func _build_pump_section() -> void:
	# Rows for every pool that's reachable and not finished, plus owned pumps.
	var rows: Array = []
	for idx in range(GameManager.swamp_definitions.size()):
		var owned: int = GameManager.get_pump_level(idx)
		if GameManager.is_swamp_completed(idx):
			continue
		if owned > 0 or GameManager.is_pump_available(idx):
			rows.append(idx)
	if rows.is_empty():
		return

	var header := Label.new()
	header.text = "-- Pumps (earn while away) --"
	header.add_theme_font_size_override("font_size", 8)
	header.add_theme_color_override("font_color", Color(0.5, 0.8, 0.9))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(header)

	for idx in rows:
		var d: Dictionary = GameManager.swamp_definitions[idx]
		var level: int = GameManager.get_pump_level(idx)
		var cost: float = GameManager.get_pump_cost(idx)

		var row_panel := PanelContainer.new()
		var style: StyleBoxTexture = PixelUI.inset(Color(0.07, 0.12, 0.15, 0.6))
		row_panel.add_theme_stylebox_override("panel", style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var info := Label.new()
		info.add_theme_font_size_override("font_size", 8)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.04, 0.75))
		info.add_theme_constant_override("shadow_offset_x", 1)
		info.add_theme_constant_override("shadow_offset_y", 1)
		if level > 0:
			info.text = "%s Pump Lv%d (%s/s)" % [d["name"], level, Economy.format_gallons(GameManager.get_pump_rate(idx))]
			info.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
		else:
			info.text = "%s Pump" % d["name"]
			info.add_theme_color_override("font_color", Color(0.45, 0.6, 0.68))
		row.add_child(info)

		if level >= GameManager.PUMP_MAX_LEVEL:
			var max_label := Label.new()
			max_label.text = "[MAX]"
			max_label.add_theme_font_size_override("font_size", 8)
			max_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			row.add_child(max_label)
		else:
			var btn := Button.new()
			btn.add_theme_font_size_override("font_size", 8)
			if level == 0:
				btn.text = "Buy %s" % Economy.format_money(cost)
			else:
				btn.text = "Lv%d %s" % [level + 1, Economy.format_money(cost)]
			btn.custom_minimum_size = Vector2(130, 0)
			var pump_idx: int = idx
			btn.pressed.connect(func() -> void: GameManager.buy_pump(pump_idx))
			_register_afford(btn, cost, Color(0.55, 0.85, 0.95))
			_style_button(btn, Color(0.06, 0.14, 0.18))
			row.add_child(btn)

		var rate_next: float = d["total_gallons"] / GameManager.PUMP_BASE_DRAIN_SECONDS * pow(1.25, level)
		var wholesale: float = d["money_per_gallon"] * GameManager.get_money_multiplier() * GameManager.PUMP_WHOLESALE
		var tip: String = "%s Pump — drains this pool passively\n" % d["name"]
		tip += "Pays wholesale (%.0f%% of manual value), even while the game is closed (up to %d h at half rate).\n" % [GameManager.PUMP_WHOLESALE * 100.0, int(GameManager.PUMP_OFFLINE_CAP_HOURS)]
		if level > 0:
			tip += "Current: %s/s (%s/s)\n" % [Economy.format_gallons(GameManager.get_pump_rate(idx)), Economy.format_money(GameManager.get_pump_rate(idx) * wholesale)]
		tip += "Next Lv%d: %s/s (%s/s)\nCost: %s" % [level + 1, Economy.format_gallons(rate_next), Economy.format_money(rate_next * wholesale), Economy.format_money(cost)]
		row_panel.tooltip_text = tip
		row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		row_panel.add_child(row)
		tool_list.add_child(row_panel)

# =============================================================================
# CAMEL SECTION
# =============================================================================
func _build_camel_section() -> void:
	var camel_header := Label.new()
	camel_header.text = "-- Camel --"
	camel_header.add_theme_font_size_override("font_size", 8)
	camel_header.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	camel_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_list.add_child(camel_header)

	var camel_buy_panel := PanelContainer.new()
	var camel_buy_style: StyleBoxTexture = PixelUI.inset(Color(0.16, 0.12, 0.06, 0.6))
	camel_buy_panel.add_theme_stylebox_override("panel", camel_buy_style)

	var camel_buy_row := HBoxContainer.new()
	camel_buy_row.add_theme_constant_override("separation", 8)

	var camel_info := Label.new()
	camel_info.add_theme_font_size_override("font_size", 8)
	camel_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camel_info.add_theme_color_override("font_shadow_color", Color(0.1, 0.06, 0.04, 0.75))
	camel_info.add_theme_constant_override("shadow_offset_x", 1)
	camel_info.add_theme_constant_override("shadow_offset_y", 1)
	if GameManager.camel_count > 0:
		camel_info.text = "Camels x%d (Cap: %.1fg, Spd: %.0f)" % [GameManager.camel_count, GameManager.get_camel_capacity(), GameManager.get_camel_speed()]
		camel_info.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	else:
		camel_info.text = "Camel (auto-sell carrier)"
		camel_info.add_theme_color_override("font_color", Color(0.6, 0.5, 0.35))
	camel_buy_row.add_child(camel_info)

	if GameManager.camel_count >= GameManager.get_camel_max_count():
		var max_label := Label.new()
		max_label.text = "[MAX]"
		max_label.add_theme_font_size_override("font_size", 8)
		max_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		camel_buy_row.add_child(max_label)
	else:
		var buy_camel_btn := Button.new()
		buy_camel_btn.add_theme_font_size_override("font_size", 8)
		var camel_cost: float = GameManager.get_camel_cost()
		buy_camel_btn.text = "Buy %s" % Economy.format_money(camel_cost)
		buy_camel_btn.custom_minimum_size = Vector2(110, 0)
		buy_camel_btn.pressed.connect(func() -> void: GameManager.buy_camel())
		_register_afford(buy_camel_btn, camel_cost, Color(0.85, 0.7, 0.3))
		_style_button(buy_camel_btn, Color(0.2, 0.15, 0.05))
		camel_buy_row.add_child(buy_camel_btn)

	var camel_tip: String = "Camel - Auto-sell carrier\n"
	if GameManager.camel_count == 0:
		camel_tip += "Walks to you, picks up water,\ncarries it to the shop and sells.\n"
		camel_tip += "Cost: %s" % Economy.format_money(GameManager.get_camel_cost())
	else:
		camel_tip += "Capacity: %.1f gal (25%% of yours) | Speed: %.0f px/s\n" % [GameManager.get_camel_capacity(), GameManager.get_camel_speed()]
		camel_tip += "Max %d camels." % GameManager.get_camel_max_count()
		if GameManager.prestige_count >= 2:
			camel_tip += " (Caravan: x3 herd cap)"
	camel_buy_panel.tooltip_text = camel_tip
	camel_buy_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	camel_buy_panel.add_child(camel_buy_row)
	tool_list.add_child(camel_buy_panel)

	# Camel upgrades (only if camel owned)
	if GameManager.camel_count > 0:
		var upgrade_panel := PanelContainer.new()
		var up_style: StyleBoxTexture = PixelUI.inset(Color(0.14, 0.1, 0.05, 0.6))
		upgrade_panel.add_theme_stylebox_override("panel", up_style)

		var up_row := HBoxContainer.new()
		up_row.add_theme_constant_override("separation", 8)

		var up_spacer := Control.new()
		up_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up_row.add_child(up_spacer)

		var cap_btn := Button.new()
		cap_btn.add_theme_font_size_override("font_size", 8)
		var cap_cost: float = GameManager.get_camel_capacity_upgrade_cost()
		cap_btn.text = "Cap Lv%d %s" % [GameManager.camel_capacity_level + 1, Economy.format_money(cap_cost)]
		cap_btn.custom_minimum_size = Vector2(130, 0)
		var cur_cap: float = GameManager.get_camel_capacity()
		var next_cap: float = cur_cap * 1.25
		cap_btn.tooltip_text = "Camel Capacity Lv%d\nCurrent: %.1f gal\nNext: %.1f gal (+25%%)\nCost: %s" % [GameManager.camel_capacity_level, cur_cap, next_cap, Economy.format_money(cap_cost)]
		cap_btn.pressed.connect(func() -> void: GameManager.upgrade_camel_capacity())
		_register_afford(cap_btn, cap_cost, Color(0.5, 0.85, 1.0))
		_style_button(cap_btn, Color(0.1, 0.15, 0.2))
		up_row.add_child(cap_btn)

		if GameManager.camel_speed_level >= GameManager.CAMEL_SPEED_MAX_LEVEL:
			var spd_max := Label.new()
			spd_max.text = "Spd [MAX]"
			spd_max.add_theme_font_size_override("font_size", 8)
			spd_max.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			up_row.add_child(spd_max)
		else:
			var spd_btn := Button.new()
			spd_btn.add_theme_font_size_override("font_size", 8)
			var spd_cost: float = GameManager.get_camel_speed_upgrade_cost()
			spd_btn.text = "Spd Lv%d %s" % [GameManager.camel_speed_level + 1, Economy.format_money(spd_cost)]
			spd_btn.custom_minimum_size = Vector2(130, 0)
			var cur_spd: float = GameManager.get_camel_speed()
			var next_spd: float = 35.0 * pow(1.20, GameManager.camel_speed_level + 1)
			spd_btn.tooltip_text = "Camel Speed Lv%d\nCurrent: %.0f px/s\nNext: %.0f px/s (+20%%)\nCost: %s" % [GameManager.camel_speed_level, cur_spd, next_spd, Economy.format_money(spd_cost)]
			spd_btn.pressed.connect(func() -> void: GameManager.upgrade_camel_speed())
			_register_afford(spd_btn, spd_cost, Color(0.5, 0.85, 1.0))
			_style_button(spd_btn, Color(0.1, 0.15, 0.2))
			up_row.add_child(spd_btn)

		upgrade_panel.add_child(up_row)
		tool_list.add_child(upgrade_panel)

func _style_button(btn: Button, bg_color: Color) -> void:
	# Wood pixel button from the theme; the old bg colour survives as a light tint.
	PixelUI.button(btn, bg_color)
