extends CanvasLayer
# On-screen touch controls (autoload). v3 pixel skin: wood plank buttons from
# assets/art/ui/touch_*.png (drawn by tools/bake/ui_kit.py), Silkscreen label
# on SCOOP. Input wiring is unchanged (Input.action_press/release).
#
# Visibility: the saved GameManager.touch_controls_enabled flag only makes the
# controls *eligible*. They show once this session has seen a real screen
# touch (first tap on a phone / tablet) or the menu toggle was used; a desktop
# never sees a touch, so it stays clean. The old code switched them on for
# any machine that merely reported a touchscreen (touch-capable laptops), and
# that flag is still in older saves, hence the session gate.

var enabled: bool = false
var _left_pressed: bool = false
var _right_pressed: bool = false
var _scoop_pressed: bool = false

var left_btn: TouchScreenButton
var right_btn: TouchScreenButton
var scoop_btn: TouchScreenButton

var _container: Control
var _touched: bool = false  # a real screen touch happened this session

func has_touched() -> bool:
	## True once this session has seen a real InputEventScreenTouch. Used by
	## menu_panel.gd to decide whether the "Touch Controls" row belongs on
	## screen at all (a desktop session never touches, so it never should).
	return _touched

const TEX := {
	"<": ["res://assets/art/ui/touch_left.png", "res://assets/art/ui/touch_left_p.png"],
	">": ["res://assets/art/ui/touch_right.png", "res://assets/art/ui/touch_right_p.png"],
	"SCOOP": ["res://assets/art/ui/touch_scoop.png", "res://assets/art/ui/touch_scoop_p.png"],
}

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS

	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_container)

	left_btn = _create_button("<")
	right_btn = _create_button(">")
	scoop_btn = _create_button("SCOOP")

	# Viewport is 640x360: arrows bottom-left above the tool card, SCOOP
	# bottom-right above the MENU card.
	left_btn.position = Vector2(8, 276)
	right_btn.position = Vector2(56, 276)
	scoop_btn.position = Vector2(576, 260)

	_container.add_child(left_btn)
	_container.add_child(right_btn)
	_container.add_child(scoop_btn)

	_deactivate()

func _input(event: InputEvent) -> void:
	if enabled or _touched:
		return
	if event is InputEventScreenTouch and event.pressed:
		_touched = true
		GameManager.touch_controls_enabled = true
		_activate()

func _create_button(text: String) -> TouchScreenButton:
	var btn := TouchScreenButton.new()
	btn.texture_normal = load(TEX[text][0])
	btn.texture_pressed = load(TEX[text][1])
	btn.passby_press = true

	if text == "SCOOP":
		var label := PixelUI.caption("SCOOP", Color(0.94, 0.88, 0.72), true)
		label.position = Vector2(0, 40)
		label.size = Vector2(56, 12)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_child(label)

	btn.pressed.connect(_on_button_pressed.bind(text))
	btn.released.connect(_on_button_released.bind(text))
	return btn

func _on_button_pressed(which: String) -> void:
	match which:
		"<":
			if not _left_pressed:
				_left_pressed = true
				Input.action_press("move_left")
		">":
			if not _right_pressed:
				_right_pressed = true
				Input.action_press("move_right")
		"SCOOP":
			if not _scoop_pressed:
				_scoop_pressed = true
				Input.action_press("scoop")

func _on_button_released(which: String) -> void:
	match which:
		"<":
			if _left_pressed:
				_left_pressed = false
				Input.action_release("move_left")
		">":
			if _right_pressed:
				_right_pressed = false
				Input.action_release("move_right")
		"SCOOP":
			if _scoop_pressed:
				_scoop_pressed = false
				Input.action_release("scoop")

func _process(_delta: float) -> void:
	if not enabled:
		return
	# Hide when UI panel is open or player not found (title screen)
	var player: Node = _get_player()
	var should_show: bool = player != null and not player.ui_panel_open
	if _container.visible != should_show:
		_container.visible = should_show
		if not should_show:
			_release_all()

func _get_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _release_all() -> void:
	if _left_pressed:
		_left_pressed = false
		Input.action_release("move_left")
	if _right_pressed:
		_right_pressed = false
		Input.action_release("move_right")
	if _scoop_pressed:
		_scoop_pressed = false
		Input.action_release("scoop")

func set_enabled(value: bool) -> void:
	if value:
		_activate()
	else:
		_deactivate()

func _activate() -> void:
	enabled = true
	_container.visible = true
	Input.emulate_mouse_from_touch = false

func _deactivate() -> void:
	enabled = false
	_container.visible = false
	_release_all()
	Input.emulate_mouse_from_touch = true
