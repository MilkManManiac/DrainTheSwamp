extends Node2D
# v3 pixel-art player skin (2026-09-10). Swaps the ColorRect figure for a
# Gemini-baked sprite strip without touching the walk/idle/scoop logic in
# player.gd: the old parts are hidden, the sprite lives under Visual so the
# existing bob / lean / flip / flash still drive it.
#
# Variant picked by env DTS_CHAR (a / b / c) for lookdev; default DEFAULT_CHAR.

const ART := "res://assets/art/drainsville/"
const DEFAULT_CHAR := "a"
const WALK_FPS := 10.0
const IDLE_FPS := 4.0
# frames per strip, written by bake_char.py
const FRAMES := {"a": [5, 7], "b": [4, 8], "c": [6, 7]}

var player: CharacterBody2D = null
var _idle: Texture2D = null
var _walk: Texture2D = null
var _idle_n: int = 1
var _walk_n: int = 1
var _sprite: Sprite2D = null
var _t: float = 0.0
var _was_walking: bool = false

func _ready() -> void:
	var which: String = OS.get_environment("DTS_CHAR")
	if which == "":
		which = DEFAULT_CHAR
	_idle = load(ART + "player_%s_idle.png" % which)
	_walk = load(ART + "player_%s_walk.png" % which)
	if _idle == null or _walk == null:
		return
	var cell_h: int = _idle.get_height()
	_idle_n = FRAMES[which][0]
	_walk_n = FRAMES[which][1]
	var vis: Node2D = player.get_node("Visual")
	for c in vis.get_children():
		if c is ColorRect and c.name != "Shadow":
			(c as CanvasItem).visible = false
	# Tool-in-hand ColorRects: the sheets already draw a bucket; hidden until
	# per-tool sprites exist (open item in the handoff doc).
	var tool: Node2D = vis.get_node_or_null("ToolSprite")
	if tool:
		tool.visible = false
	_sprite = Sprite2D.new()
	_sprite.texture = _idle
	_sprite.hframes = _idle_n
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.centered = true
	# Feet on the origin: cell is (cell_h/2) units tall at 0.5 scale.
	_sprite.position = Vector2(0.0, -cell_h * 0.25)
	_sprite.z_index = 0
	vis.add_child(_sprite)

func _process(dt: float) -> void:
	if _sprite == null:
		return
	var walking: bool = player.is_walking
	if walking != _was_walking:
		_was_walking = walking
		_t = 0.0
		_sprite.texture = _walk if walking else _idle
		_sprite.hframes = _walk_n if walking else _idle_n
	_t += dt
	var n: int = _walk_n if walking else _idle_n
	var fps: float = WALK_FPS if walking else IDLE_FPS
	_sprite.frame = int(_t * fps) % n
