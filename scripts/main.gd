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
