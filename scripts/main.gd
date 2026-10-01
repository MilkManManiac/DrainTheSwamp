extends Node2D

@onready var hud = $HUD
@onready var shop_panel = $UILayer/ShopPanel
@onready var menu_panel = $UILayer/MenuPanel
@onready var player = $GameWorld/Player

func _ready() -> void:
	hud.menu_pressed.connect(_on_menu_pressed)
	player.shop_requested.connect(_on_shop_pressed)
	player.cave_entrance_requested.connect(_on_cave_entrance_requested)
	menu_panel.reset_confirmed.connect(_on_reset_confirmed)
	GameManager.cave_unlocked.connect(_on_cave_unlocked)
	GameManager.prestige_performed.connect(_on_prestige_performed)

	# Clear ui_panel_open when any panel closes itself via its own X button
	shop_panel.visibility_changed.connect(_on_panel_visibility_changed)
	menu_panel.visibility_changed.connect(_on_panel_visibility_changed)

	# Check if returning from cave
	if SceneManager.return_position != Vector2.ZERO:
		player.position = SceneManager.return_position
		player.velocity = Vector2.ZERO
		SceneManager.return_position = Vector2.ZERO
		GameManager.exit_cave()
		SceneManager.fade_in()

	# Dev-only capture hook (v3 hud track): DTS_UI=shop|menu|touch opens that
	# panel / shows the touch controls so tools/capture.py can photograph them.
	# Inert without the env var; nothing here is saved.
	var ui_dbg: String = OS.get_environment("DTS_UI")
	if ui_dbg != "":
		_debug_open_ui.call_deferred(ui_dbg)

func _debug_open_ui(which: String) -> void:
	# "shop:1" / "shop:2" also selects a tab (0=Tools default, 1=Stats,
	# 2=Influence) so tools/capture.py can shoot each one.
	var parts: PackedStringArray = which.split(":")
	match parts[0]:
		"shop":
			_on_shop_pressed()
			if parts.size() > 1:
				shop_panel.current_tab = parts[1].to_int()
				shop_panel._refresh()
		"menu":
			_on_menu_pressed()
			get_tree().paused = false  # keep the DTS_SHOT timer ticking
		"touch":
			TouchControls.set_enabled(true)
		"hint":
			# Sample toast text at real caller length (see game_world.gd's
			# buyback-window line) so the shrink-wrap capture reflects an
			# actual message, not a placeholder.
			SceneManager.show_popup("EMERGENCY BUYBACK WINDOW OPEN\nSomeone needs this water gone before an audit — 2x prices for 30s!", 0.0)
		"lore":
			SceneManager.show_document_popup(
				"The trucks that refill the water at night — we have photographed the drivers. For no reason. We photograph many things.\n\nAlso: the drop box at the west edge of town. It is ours. Check it when the flag is up.\n\n— a Friend",
				"MESSAGE RECEIVED", "phone")
		"lore_paper":
			SceneManager.show_document_popup(
				"HERE LIES WHAT THE WATER TOOK\n\nSix names, one date, no stone big enough.",
				"CAVE INSCRIPTION", "paper")

func _close_all_panels() -> void:
	shop_panel.visible = false
	player.ui_panel_open = false

func _on_shop_pressed() -> void:
	if shop_panel.visible:
		_close_all_panels()
		return
	_close_all_panels()
	shop_panel.open()
	player.ui_panel_open = true

func _on_menu_pressed() -> void:
	_close_all_panels()
	menu_panel.open()
	player.ui_panel_open = true

func _on_reset_confirmed() -> void:
	_close_all_panels()
	GameManager.reset_game()
	SaveManager.save_game()
	# Full restart: reload the scene so the whole world rebuilds from fresh state.
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_prestige_performed() -> void:
	_close_all_panels()
	SaveManager.save_game()
	# Reload the scene so the whole world rebuilds from the post-prestige state.
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_cave_entrance_requested(cave_id: String) -> void:
	if SceneManager.is_transitioning:
		return
	var defn: Dictionary = GameManager.CAVE_DEFINITIONS.get(cave_id, {})
	var scene_path: String = defn.get("scene_path", "")
	if scene_path == "":
		player.show_floating_text("Not yet...", Color(0.8, 0.6, 0.3))
		return
	SceneManager.return_position = player.position
	SceneManager.return_scene_path = "res://scenes/main.tscn"
	GameManager.enter_cave(cave_id)
	SaveManager.save_game()
	SceneManager.transition_to_scene(scene_path)

func _on_cave_unlocked(cave_id: String) -> void:
	var defn: Dictionary = GameManager.CAVE_DEFINITIONS.get(cave_id, {})
	var cave_name: String = defn.get("name", "Unknown")
	if is_instance_valid(player):
		player.show_floating_text("Cave found: %s!" % cave_name, Color(1.0, 0.85, 0.3))

func _on_panel_visibility_changed() -> void:
	if not shop_panel.visible and not menu_panel.visible:
		player.ui_panel_open = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if menu_panel.visible:
			menu_panel._close()
			player.ui_panel_open = false
		elif shop_panel.visible:
			_close_all_panels()
		else:
			menu_panel.open()
			player.ui_panel_open = true
