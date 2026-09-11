extends Node2D
# v3 pixel-art player skin (2026-09-10, tools/scoop/lantern 2026-09-11).
# Swaps the ColorRect figure for a Gemini-baked sprite strip without touching
# the walk/idle/scoop logic in player.gd: the old parts are hidden, the sprite
# lives under Visual so the existing bob / lean / flip / flash still drive it.
#
# Layers (all under Visual, inside _root which mirrors the left-facing sheet so
# player.facing_right == Visual.scale.x == 1 faces right):
#   _sprite  idle / walk / scoop strip (feet on the origin)
#   _tool    per-tool hand sprite, grip pinned to the hand anchor of the current
#            frame (HAND table, art px in frame space); follows the old
#            ToolSprite node's rotation/scale so the walk swing, scoop swing and
#            equip pop from player.gd still apply
#   lantern  Sprite2D + overbright flame pixel under player.lantern_node (which
#            player.gd still toggles with darkness and sways with the arm)
#
# Debug env (all inert when unset; used by tools/capture.py runs):
#   DTS_CHAR=a|b|c   sprite variant          DTS_TOOL=<tool_id>  force the hand sprite
#   DTS_WALK=<n>     freeze on walk frame n  DTS_SCOOP=1         fire a scoop every second after 2 s
#   DTS_LANTERN=1    (player.gd) lantern on regardless of the upgrade

const ART := "res://assets/art/drainsville/"
const DEFAULT_CHAR := "a"
const WALK_FPS := 8.0
const IDLE_FPS := 4.0
const SCOOP_FRAME_TIME := 0.1
# frames per strip [idle, walk], written by bake_char.py / paint_out_bucket.py
const FRAMES := {"a": [5, 4], "b": [4, 8], "c": [6, 7]}
# scoop strip: frame count and play order (bend, low, bend)
const SCOOP_FRAMES := {"a": 3}
const SCOOP_ORDER := [1, 2, 2, 1]
# Near-hand anchor per frame, art px from the frame's top-left (sheet faces left).
# The tool's grip point sits here. Only A has been measured; other variants fall
# back to a hand guess at the hip.
const HAND := {
	"a": {
		"idle": [Vector2(3, 26), Vector2(4, 26), Vector2(3, 26), Vector2(3, 26), Vector2(3, 26)],
		"walk": [Vector2(6, 26), Vector2(11, 27), Vector2(8, 27), Vector2(9, 26)],
		"scoop": [Vector2(3, 26), Vector2(3, 26), Vector2(3, 26)],
	},
}
# Tool sprites: texture (x2 baked) and the grip point in art px of that texture.
# Filled in from tools/bake/bake_tools.py output (see docs/plans/revamp-tracks/player.md).
const TOOLS := {
	"spoon": {"tex": "tool_spoon.png", "grip": Vector2(2, 1)},
	"cup": {"tex": "tool_cup.png", "grip": Vector2(3, 1)},
	"bucket": {"tex": "tool_bucket.png", "grip": Vector2(4, 0)},
	"shovel": {"tex": "tool_shovel.png", "grip": Vector2(2, 5)},
	"wheelbarrow": {"tex": "tool_wheelbarrow.png", "grip": Vector2(11, 3)},
	"barrel": {"tex": "tool_barrel.png", "grip": Vector2(4, 0)},
	"water_wagon": {"tex": "tool_water_wagon.png", "grip": Vector2(8, 1)},
	"hose": {"tex": "tool_hose.png", "grip": Vector2(2, 2)},
}
const LANTERN_TEX := "tool_lantern.png"
const LANTERN_GRIP := Vector2(4, 0)   # handle top, art px
const LANTERN_FLAME := Vector2(4, 6)  # glass centre, art px

var player: CharacterBody2D = null
var _which: String = "a"
var _strips: Dictionary = {}     # name -> Texture2D
var _counts: Dictionary = {}     # name -> frame count
var _root: Node2D = null
var _sprite: Sprite2D = null
var _tool: Sprite2D = null
var _tool_id: String = ""
var _cell: Vector2 = Vector2.ZERO  # current strip cell in art px
var _t: float = 0.0
var _was_walking: bool = false
var _scoop_t: float = -1.0       # >= 0 while the scoop strip plays
var _lantern_flame: Sprite2D = null
var _dbg_walk: int = -1
var _dbg_scoop: bool = false
var _dbg_scoop_t: float = 0.0

func _ready() -> void:
	_which = OS.get_environment("DTS_CHAR")
	if _which == "":
		_which = DEFAULT_CHAR
	_load_strip("idle", FRAMES[_which][0])
	_load_strip("walk", FRAMES[_which][1])
	if SCOOP_FRAMES.has(_which):
		_load_strip("scoop", SCOOP_FRAMES[_which])
	if not _strips.has("idle") or not _strips.has("walk"):
		return
	var dw: String = OS.get_environment("DTS_WALK")
	if dw != "":
		_dbg_walk = dw.to_int()
	_dbg_scoop = OS.get_environment("DTS_SCOOP") != ""

	var vis: Node2D = player.get_node("Visual")
	for c in vis.get_children():
		if c is ColorRect and c.name != "Shadow":
			(c as CanvasItem).visible = false
	# Old ColorRect tool stays hidden; its rotation/scale still drive _tool.
	var old_tool: Node2D = vis.get_node_or_null("ToolSprite")
	if old_tool:
		old_tool.visible = false

	# The sheet faces left; Visual.scale.x = 1 means facing right in player.gd.
	_root = Node2D.new()
	_root.scale = Vector2(-1.0, 1.0)
	vis.add_child(_root)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.centered = true
	_sprite.z_index = 0
	_root.add_child(_sprite)
	_set_strip("idle")

	_tool = Sprite2D.new()
	_tool.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tool.centered = false
	_tool.z_index = 1
	_root.add_child(_tool)
	GameManager.tool_changed.connect(func(_d: Dictionary) -> void: _refresh_tool())
	_refresh_tool()

	if player.has_signal("scooped"):
		player.scooped.connect(_on_scooped)
	_build_lantern()

func _load_strip(strip: String, n: int) -> void:
	var tex: Texture2D = load(ART + "player_%s_%s.png" % [_which, strip]) as Texture2D
	if tex == null:
		return
	_strips[strip] = tex
	_counts[strip] = n

func _set_strip(strip: String) -> void:
	var tex: Texture2D = _strips[strip]
	var n: int = _counts[strip]
	_sprite.texture = tex
	_sprite.hframes = n
	_cell = Vector2(float(tex.get_width()) / float(n) * 0.5, tex.get_height() * 0.5)
	# Feet on the origin: the cell is _cell.y world units tall at 0.5 scale.
	_sprite.position = Vector2(0.0, -_cell.y * 0.5)
	_sprite.frame = 0

func _current_strip() -> String:
	if _sprite.texture == _strips.get("walk"):
		return "walk"
	if _sprite.texture == _strips.get("scoop"):
		return "scoop"
	return "idle"

func _tool_id_now() -> String:
	var forced: String = OS.get_environment("DTS_TOOL")
	if forced != "":
		return forced
	return GameManager.current_tool_id

func _refresh_tool() -> void:
	_tool_id = _tool_id_now()
	if not TOOLS.has(_tool_id):
		_tool.visible = false
		return
	var tex: Texture2D = load(ART + TOOLS[_tool_id]["tex"]) as Texture2D
	if tex == null:
		_tool.visible = false
		return
	_tool.texture = tex
	_tool.offset = -(TOOLS[_tool_id]["grip"] as Vector2) * 2.0
	_tool.visible = true

func _hand_anchor(strip: String, frame: int) -> Vector2:
	var a: Vector2 = Vector2(_cell.x * 0.3, _cell.y * 0.65)
	if HAND.has(_which) and HAND[_which].has(strip):
		var arr: Array = HAND[_which][strip]
		if frame < arr.size():
			a = arr[frame]
	# frame-space art px -> world (sprite is centred, feet on origin)
	return Vector2(a.x - _cell.x * 0.5, a.y - _cell.y)

func _on_scooped() -> void:
	if _dbg_walk >= 0:
		return
	_scoop_t = 0.0

func _process(dt: float) -> void:
	if _sprite == null:
		return
	if _dbg_scoop:
		_dbg_scoop_t += dt
		if _dbg_scoop_t >= 2.0:
			_dbg_scoop_t -= 1.0
			player._scoop_feedback()
	var walking: bool = player.is_walking or _dbg_walk >= 0
	if walking != _was_walking:
		_was_walking = walking
		_t = 0.0
		_scoop_t = -1.0
		_set_strip("walk" if walking else "idle")
	_t += dt
	var strip: String = _current_strip()
	var frame: int = 0
	if walking:
		frame = int(_t * WALK_FPS) % _counts["walk"]
		if _dbg_walk >= 0:
			frame = _dbg_walk % _counts["walk"]
	elif _scoop_t >= 0.0 and _strips.has("scoop"):
		_scoop_t += dt
		var step: int = int(_scoop_t / SCOOP_FRAME_TIME)
		if step >= SCOOP_ORDER.size():
			_scoop_t = -1.0
			_set_strip("idle")
			strip = "idle"
		else:
			if strip != "scoop":
				_set_strip("scoop")
				strip = "scoop"
			frame = clampi(SCOOP_ORDER[step], 0, _counts["scoop"] - 1)
	else:
		if strip != "idle":
			_set_strip("idle")
			strip = "idle"
		frame = int(_t * IDLE_FPS) % _counts["idle"]
	_sprite.frame = frame

	# Tool follows the hand; the hidden ToolSprite still carries the swing/pop tweens.
	if _tool.visible:
		_tool.position = _hand_anchor(strip, frame)
		var old_tool: Node2D = player.tool_sprite
		_tool.rotation = -old_tool.rotation
		_tool.scale = old_tool.scale * 0.5
	_update_lantern(dt)

# --- lantern -------------------------------------------------------------

func _build_lantern() -> void:
	var node: Node2D = player.lantern_node
	if node == null:
		return
	var tex: Texture2D = load(ART + LANTERN_TEX) as Texture2D
	if tex == null:
		return
	for c in node.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	var body := Sprite2D.new()
	body.texture = tex
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.centered = false
	body.scale = Vector2(0.5, 0.5)
	body.offset = -LANTERN_GRIP * 2.0
	body.position = Vector2(2.0, -4.0)  # handle top where the old wire hung
	node.add_child(body)
	# One overbright pixel behind the glass; HDR glow blooms it into the halo.
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_lantern_flame = Sprite2D.new()
	_lantern_flame.texture = ImageTexture.create_from_image(img)
	_lantern_flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lantern_flame.centered = true
	_lantern_flame.scale = Vector2(0.5, 1.0)
	_lantern_flame.position = body.position + (LANTERN_FLAME - LANTERN_GRIP)
	_lantern_flame.z_index = 1
	node.add_child(_lantern_flame)

func _update_lantern(_dt: float) -> void:
	if _lantern_flame == null or not player.lantern_active:
		return
	var t: float = player.lantern_flicker_time
	var flicker: float = 1.0 + sin(t * 12.0) * 0.08 + sin(t * 7.3) * 0.05
	var boost: float = 2.2 if player._hdr_glow else 1.0
	_lantern_flame.modulate = Color(boost, 0.9 * boost * flicker, 0.35 * boost * flicker)
	_lantern_flame.scale.y = 1.0 + sin(t * 12.0) * 0.25
