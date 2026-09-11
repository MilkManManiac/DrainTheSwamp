extends Node2D
# The NA dead-drop mailbox at the west edge of town. The decorative shapes are
# drawn by town.gd's _dropbox(); this node adds the interaction on top.
# What's inside tracks the NA arc: locked teaser -> field box (post-reveal) ->
# dispensary (post-prestige).

var player_in_range: bool = false
var hint_label: Label = null

func _ready() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var coll := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 32)
	coll.shape = shape
	coll.position = Vector2(0, -14)
	area.add_child(coll)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	hint_label = PixelUI.prompt("[SPACE]", Color(0.8, 0.75, 0.6, 0.9))
	hint_label.position = Vector2(-16, -44)
	hint_label.z_index = 8
	hint_label.visible = false
	add_child(hint_label)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_in_range = true
		hint_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		player_in_range = false
		hint_label.visible = false

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("scoop"):
		SceneManager.show_document_popup(_current_text(), "THE DEAD DROP")

func _current_text() -> String:
	# Post-prestige: NA's rehire desk
	if GameManager.prestige_count >= 1:
		return "NORTHWIND ANALYTICS — DISPENSARY\n\nInside: your rehire paperwork, pre-signed. A fresh burner phone, same number. A commemorative pin shaped like a bucket.\n\nA note: \"Welcome back. The swamp missed you. So did the quarterly targets. — NA\""
	# Post-reveal (the lagoon texts have dropped the pretense)
	if GameManager.story_flags.get("na_text_lagoon", false):
		return "NORTHWIND ANALYTICS — FIELD BOX 7\n\nThe lock is gone. Inside: a receipt pad, a phrasebook open to the chapter on idioms, and an envelope labeled EXPENSES that is somehow already empty.\n\nA note: \"Turn in what you find. We pay better than the government. Everyone pays better than the government. — NA\""
	# Pre-reveal teaser
	return "A MAILBOX?\n\nA government mailbox with no route number. The lid is locked. The little red flag is up.\n\nSomeone oils the hinges. Nobody collects the mail.\n\nSomething tells you to keep draining."
