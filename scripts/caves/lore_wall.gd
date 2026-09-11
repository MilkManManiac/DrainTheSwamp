extends Node2D

@export var lore_id: String = ""
@export var cave_id: String = ""
@export var lore_text: String = ""

var player_in_range: bool = false
var hint_label: Label = null
var shimmer_time: float = 0.0
var marking_rect: ColorRect = null

func _ready() -> void:
	_build_visual()
	_build_interaction()

func _build_visual() -> void:
	# Wall marking background
	marking_rect = ColorRect.new()
	marking_rect.size = Vector2(16, 20)
	marking_rect.position = Vector2(-8, -22)
	marking_rect.color = Color(0.4, 0.35, 0.25, 0.6)
	marking_rect.z_index = 3
	add_child(marking_rect)

	# Carving lines
	for i in range(3):
		var line := ColorRect.new()
		line.size = Vector2(10, 1)
		line.position = Vector2(-5, -18 + i * 6)
		line.color = Color(0.55, 0.5, 0.35, 0.7)
		line.z_index = 3
		add_child(line)

	# Symbol
	var symbol := ColorRect.new()
	symbol.size = Vector2(6, 6)
	symbol.position = Vector2(-3, -16)
	symbol.color = Color(0.65, 0.55, 0.3, 0.5)
	symbol.z_index = 3
	add_child(symbol)

func _build_interaction() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var coll := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 30)
	coll.shape = shape
	coll.position = Vector2(0, -10)
	area.add_child(coll)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	hint_label = PixelUI.prompt("[SPACE]", Color(0.8, 0.75, 0.6, 0.9))
	hint_label.position = Vector2(-16, -36)
	hint_label.z_index = 8
	hint_label.visible = false
	add_child(hint_label)

var _auto_read_done: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_in_range = true
		hint_label.visible = true
		# P3 perk: NA photographs documents for you — walls read on approach
		if GameManager.has_auto_lore() and not _auto_read_done:
			_auto_read_done = true
			_read_lore()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_in_range = false
		hint_label.visible = false

func _process(delta: float) -> void:
	shimmer_time += delta
	# Subtle shimmer on marking
	if marking_rect:
		marking_rect.color.a = lerpf(0.5, 0.7, (sin(shimmer_time * 1.5) + 1.0) * 0.5)

	if player_in_range and Input.is_action_just_pressed("scoop"):
		_read_lore()

func _read_lore() -> void:
	GameManager.lore_read.emit(cave_id, lore_id)
	SceneManager.show_lore_popup(lore_text)
