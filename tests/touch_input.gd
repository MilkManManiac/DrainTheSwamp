extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var touch = root.get_node("TouchControls")
	_check(not touch.enabled, "Desktop starts with touch controls off")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	_check(mouse.is_action_pressed("scoop_mouse"), "Desktop click still has a scoop binding")
	_check(not mouse.is_action_pressed("scoop"), "Emulated menu/arrow clicks cannot press touch scoop")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	_check(key.is_action_pressed("scoop"), "Space still scoops")

	var first_touch := InputEventScreenTouch.new()
	first_touch.pressed = true
	touch._input(first_touch)
	_check(touch.enabled and touch.has_touched(), "The first real touch enables touch controls")
	_check(Input.emulate_mouse_from_touch, "The first touch must not disable regular menu buttons")

	# Two held gameplay controls must stay independent when an emulated mouse
	# press/release from that same finger arrives through Godot's input map.
	touch._on_button_pressed(">")
	touch._on_button_pressed("SCOOP")
	Input.parse_input_event(mouse)
	var mouse_release: InputEventMouseButton = mouse.duplicate()
	mouse_release.pressed = false
	Input.parse_input_event(mouse_release)
	_check(Input.is_action_pressed("move_right") and Input.is_action_pressed("scoop"), "Mouse release cancels a held touch action")
	touch._on_button_released(">")
	_check(not Input.is_action_pressed("move_right") and Input.is_action_pressed("scoop"), "Releasing movement cancels scoop")
	touch.set_enabled(false)
	_check(not Input.is_action_pressed("scoop"), "Disabling touch must release held actions")
	_check(Input.emulate_mouse_from_touch, "Menus remain tappable with touch controls off")
	for failure in failures:
		push_error(failure)
	print("Touch input checks: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
