extends Node2D
# v3 signage (2026-09-11): every piece of text that lives in the world.
# Wooden pixel billboards on the ridges, a wooden name post per basin, SELL
# planks at the two sell points, pixel cave mouths with a name plank, and
# Silkscreen float text. game_world's old builders are gated off by
# V3_SIGNAGE; nothing here re-tunes them. Built deferred so it lands after
# everything game_world creates in _ready().
#
# Any Label added to the world tree by other code (scoop "+gal", camel sell,
# milestone, DRAINED! titles) is restyled on arrival to Silkscreen with a
# pixel outline and snapped to whole world units before each draw, so the
# old spawn sites and their tweens stay exactly as they were.

const ART := "res://assets/art/drainsville/"
const SCALE := 0.5
const FONT_PATH := "res://assets/fonts/Silkscreen-Regular.ttf"
const NUM_FONT_PATH := "res://assets/fonts/VT323-Regular.ttf"

const INK := Color(0.16, 0.12, 0.09)          # dark ink on pale board
const PLANK_INK := Color(0.93, 0.85, 0.62)    # cream paint on dark wood
const OUTLINE := Color(0.06, 0.05, 0.04, 0.95)
const DONE_GREEN := Color(0.45, 0.95, 0.5)

# Board face rects in texture px (unflipped), measured off the baked sprites
# (billboard.png 528x300, sign_post.png 178x164, sign_stake.png 84x92,
# sign_stake_l.png 152x140 — see assets/art/drainsville/).
const BILLBOARD_FACE := Rect2(20, 15, 488, 160)
const POST_FACE := Rect2(14, 10, 150, 70)
const STAKE_FACE := Rect2(6, 6, 72, 42)
const STAKE_L_FACE := Rect2(12, 10, 128, 70)

# Story content (verbatim from the old _build_billboards): one board per ridge,
# index = ridge between pool i and pool i+1. Odd ridges red (Swampsworth),
# even ridges blue (Lobbyton).
const BILLBOARD_TEXTS: Array[String] = [
	"VOTE SWAMPSWORTH\nLeadership You\nCan Trust\nPAID FOR BY FRIENDS OF SWAMPSWORTH",
	"LOBBYTON 2024\nA Fresh Voice\nFor Real Change\nPAID FOR BY LOBBYTON FOR CONGRESS",
	"INJURED AT WORK?\nCALL 555-SWAMP\nTHE LAW OFFICES OF\nSWAMPSWORTH & SONS",
	"SWAMP ACRES\nLUXURY CONDOS\nWaterfront Living\nFROM $2.5M",
	"PROTECT OUR\nWETLANDS\nPAID FOR BY CITIZENS\nAGAINST DRAINING",
	"RE-ELECT LOBBYTON\nShe Gets Results\n(ask her donors)\nPAID FOR BY LOBBYTON PAC",
	"GOODWELL\nFOR REFORM\nHonest Government Now\nPAID FOR BY GOODWELL 2024",
	"EAT AT\nSWAMP MIKE'S\nBBQ & BAIT SHOP\nEXIT 7  -  OPEN 24HRS",
	"SWAMPSWORTH\nGETS IT DONE*\n*it = fundraising\nPAID FOR BY SWAMPSWORTH PAC",
]
const RED_TINT := Color(0.96, 0.86, 0.82)
const BLUE_TINT := Color(0.82, 0.87, 0.98)

var world: Node2D = null
var _font: FontFile = null
var _num_font: FontFile = null
var _snap: Array = []        # adopted Labels, pixel-snapped before every draw
var _basin: Array = []       # per basin {name: Label, pct: Label, gal: Label}
var _caves: Array = []       # {ce: Dictionary, sealed: Sprite2D, mouth: Sprite2D, plank: Node2D}
var _tower_sell_built: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("signage")
	_font = _pixel_font(FONT_PATH)
	_num_font = _pixel_font(NUM_FONT_PATH)
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_snap_labels)
	call_deferred("_build")

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_snap_labels):
		RenderingServer.frame_pre_draw.disconnect(_snap_labels)

# A private copy of the font with every smoothing feature off, so glyphs land
# on the art grid like the baked sprites do.
func _pixel_font(path: String) -> FontFile:
	var f: FontFile = (load(path) as FontFile).duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f

func _tex(name: String) -> Texture2D:
	return load(ART + name + ".png")

# Bottom-center anchored sprite at world scale.
func _sprite(name: String, x: float, ground_y: float, z: int, flip: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.flip_h = flip
	s.position = Vector2(x - s.texture.get_width() * SCALE * 0.5, ground_y - s.texture.get_height() * SCALE).round()
	s.z_index = z
	add_child(s)
	return s

# Label sized to a face rect of a sprite (rect in texture px), centered text.
func _face_label(s: Sprite2D, face: Rect2, text: String, size: int, col: Color, font: FontFile = null) -> Label:
	var lbl := _label(text, size, col, font)
	lbl.position = (s.position + face.position * SCALE).round()
	lbl.size = (face.size * SCALE).round()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.clip_text = true
	lbl.z_index = s.z_index
	add_child(lbl)
	return lbl

func _label(text: String, size: int, col: Color, font: FontFile = null) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font if font else _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("line_spacing", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return lbl

func _outline(lbl: Label, px: int = 1) -> void:
	lbl.add_theme_color_override("font_outline_color", OUTLINE)
	lbl.add_theme_constant_override("outline_size", px)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)

func _build() -> void:
	_build_billboards()
	_build_basin_signs()
	_build_shop_sell()
	_build_cave_mouths()
	GameManager.water_level_changed.connect(_on_water_level_changed)
	GameManager.swamp_completed.connect(_on_swamp_completed)

# --- billboards: one wooden board per ridge, story text in Silkscreen -------
func _build_billboards() -> void:
	for ridge_i in range(world.SWAMP_COUNT - 1):
		if ridge_i >= BILLBOARD_TEXTS.size():
			break
		var ridge_start: int = world.SWAMP_RANGES[ridge_i][1]
		var ridge_end: int = world.SWAMP_RANGES[ridge_i + 1][0]
		if ridge_start >= world.terrain_points.size() or ridge_end >= world.terrain_points.size():
			continue
		var mid_x: float = (world.terrain_points[ridge_start].x + world.terrain_points[ridge_end].x) * 0.5
		var gy: float = world._get_terrain_y_at(mid_x)
		if gy < 0.0:
			continue
		var board := _sprite("billboard", mid_x, gy + 2.0, -1, ridge_i % 2 == 1)
		board.modulate = RED_TINT if (ridge_i % 2 == 0) else BLUE_TINT
		var face := BILLBOARD_FACE
		if board.flip_h:
			face.position.x = board.texture.get_width() - face.position.x - face.size.x
		_face_label(board, face, BILLBOARD_TEXTS[ridge_i], 8, INK)

# --- basin name posts: name + percent + gallons on a plank at the near rim ---
func _build_basin_signs() -> void:
	_basin.clear()
	for i in range(world.SWAMP_COUNT):
		var geo: Dictionary = world._get_swamp_geometry(i)
		var et: Vector2 = geo["entry_top"]
		var x: float = et.x - 34.0
		var gy: float = world._get_terrain_y_at(x)
		var post := _sprite("sign_post", x, gy + 2.0, -1)
		var face := POST_FACE
		var fw: float = face.size.x * SCALE
		var fx: float = post.position.x + face.position.x * SCALE
		var fy: float = post.position.y + face.position.y * SCALE
		var name_lbl := _label(GameManager.swamp_definitions[i]["name"], 8, PLANK_INK)
		name_lbl.position = Vector2(fx, fy + 1.0).round()
		name_lbl.size = Vector2(fw, 10.0)
		name_lbl.z_index = -1
		add_child(name_lbl)
		var pct_lbl := _label("", 8, Color(0.85, 0.80, 0.62), _num_font)
		pct_lbl.position = Vector2(fx, fy + 11.0).round()
		pct_lbl.size = Vector2(fw, 9.0)
		pct_lbl.z_index = -1
		add_child(pct_lbl)
		var gal_lbl := _label("", 8, Color(0.62, 0.78, 0.92), _num_font)
		gal_lbl.position = Vector2(fx, fy + 20.0).round()
		gal_lbl.size = Vector2(fw, 9.0)
		gal_lbl.z_index = -1
		add_child(gal_lbl)
		_basin.append({"name": name_lbl, "pct": pct_lbl, "gal": gal_lbl})
		_refresh_basin(i)
		if GameManager.swamp_states[i]["completed"]:
			_mark_basin_done(i)

func _refresh_basin(i: int) -> void:
	if i < 0 or i >= _basin.size():
		return
	var b: Dictionary = _basin[i]
	if GameManager.swamp_states[i]["completed"]:
		return
	var pct: float = GameManager.get_swamp_water_percent(i)
	(b["pct"] as Label).text = "%.1f%%" % pct
	var total_gal: float = GameManager.swamp_definitions[i]["total_gallons"]
	var drained: float = GameManager.swamp_states[i]["gallons_drained"]
	var remaining: float = maxf(total_gal - drained, 0.0)
	(b["gal"] as Label).text = "%s / %s gal" % [world._format_gallons(remaining), world._format_gallons(total_gal)]

func _mark_basin_done(i: int) -> void:
	if i < 0 or i >= _basin.size():
		return
	var b: Dictionary = _basin[i]
	(b["name"] as Label).text = GameManager.swamp_definitions[i]["name"] + " [DONE]"
	(b["name"] as Label).add_theme_color_override("font_color", DONE_GREEN)
	(b["pct"] as Label).text = "0.0%"
	(b["pct"] as Label).add_theme_color_override("font_color", DONE_GREEN)
	(b["gal"] as Label).text = "DRAINED"
	(b["gal"] as Label).add_theme_color_override("font_color", DONE_GREEN)

func _on_water_level_changed(swamp_index: int, _percent: float) -> void:
	_refresh_basin(swamp_index)

func _on_swamp_completed(swamp_index: int, _reward: float) -> void:
	_mark_basin_done(swamp_index)

# --- SELL planks ----------------------------------------------------------
func _sell_plank(x: float, ground_y: float) -> void:
	var stake := _sprite("sign_stake", x, ground_y + 1.0, -1)
	_face_label(stake, STAKE_FACE, "SELL", 8, Color(1.0, 0.88, 0.35))

func _build_shop_sell() -> void:
	# Hardware store: base_x -22, width 46 -> door at x 1; plank just right of it.
	var x: float = 24.0
	_sell_plank(x, world._grnd(x, 136.0))

func _build_tower_sell() -> void:
	_tower_sell_built = true
	var x: float = world.EAST_TOWER_X + 30.0
	_sell_plank(x, world._grnd(x, 136.0))

# --- cave mouths: ride the old entrance roots; the old ColorRects go fully
# transparent (their .visible flags still flip on unlock, we mirror them).
func _build_cave_mouths() -> void:
	_caves.clear()
	var k := 0
	for ce in world.cave_entrances:
		var root: Node2D = ce["root"]
		for key in ["crack", "opening", "edge_left", "edge_right", "lintel", "glow"]:
			var n: CanvasItem = ce[key]
			if is_instance_valid(n):
				n.modulate = Color(1, 1, 1, 0)
		var sealed := _child_sprite(root, "cave_sealed", 0.0, 1.0, k % 2 == 1)
		var mouth := _child_sprite(root, "cave_mouth", 0.0, 1.0, k % 2 == 0)
		# Warm light in the mouth once open (the old amber rect is invisible now).
		var glow := PointLight2D.new()
		if world.has_method("_make_light_texture"):
			glow.texture = world._make_light_texture()
		glow.texture_scale = 0.5
		glow.color = Color(1.0, 0.7, 0.35)
		glow.energy = 0.0
		glow.position = Vector2(0.0, -8.0)
		mouth.add_child(glow)
		# Name plank beside the mouth, shown with it.
		var cave_name: String = GameManager.CAVE_DEFINITIONS[ce["cave_id"]]["name"]
		var plank := Node2D.new()
		plank.position = Vector2(28.0 if k % 2 == 0 else -28.0, 0.0)
		root.add_child(plank)
		var stake := Sprite2D.new()
		stake.texture = _tex("sign_stake_l")
		stake.centered = false
		stake.scale = Vector2(SCALE, SCALE)
		stake.position = Vector2(-stake.texture.get_width() * SCALE * 0.5, 1.0 - stake.texture.get_height() * SCALE).round()
		plank.add_child(stake)
		var lbl := _label(cave_name, 8, PLANK_INK, _num_font)
		lbl.position = (stake.position + STAKE_L_FACE.position * SCALE).round()
		lbl.size = (STAKE_L_FACE.size * SCALE).round()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		plank.add_child(lbl)
		# The "Press SPACE" hint: center it over the mouth (restyled on arrival).
		var hint: Label = ce["hint"]
		if is_instance_valid(hint):
			hint.size = Vector2(140.0, 10.0)
			hint.position = Vector2(-70.0, -36.0)
		_caves.append({"ce": ce, "sealed": sealed, "mouth": mouth, "plank": plank, "glow": glow})
		k += 1
	_sync_caves()

func _child_sprite(parent: Node2D, name: String, x: float, ground_y: float, flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.flip_h = flip
	s.position = Vector2(x - s.texture.get_width() * SCALE * 0.5, ground_y - s.texture.get_height() * SCALE).round()
	parent.add_child(s)
	return s

func _sync_caves() -> void:
	for c in _caves:
		var ce: Dictionary = c["ce"]
		var open_vis: bool = is_instance_valid(ce["opening"]) and (ce["opening"] as CanvasItem).visible
		(c["mouth"] as Sprite2D).visible = open_vis
		(c["plank"] as Node2D).visible = open_vis
		(c["sealed"] as Sprite2D).visible = not open_vis
		if open_vis:
			var pulse: float = (sin(world.wave_time * 2.0 + ce["x"] * 0.1) + 1.0) * 0.5
			(c["glow"] as PointLight2D).energy = lerpf(0.35, 0.8, pulse)

# --- float text adoption ---------------------------------------------------
func _on_node_added(n: Node) -> void:
	if not (n is Label):
		return
	var lbl := n as Label
	if lbl.has_theme_font_override("font"):
		return   # ours, or town.gd's
	# Only world-space labels: anything under a CanvasLayer is HUD / popups.
	var p: Node = lbl.get_parent()
	var in_world := false
	while p:
		if p is CanvasLayer:
			return
		if p == world:
			in_world = true
		p = p.get_parent()
	if not in_world:
		return
	var fs: int = lbl.get_theme_font_size("font_size")
	if lbl.has_theme_font_size_override("font_size") and fs < 9:
		return   # tiny prop lettering (wanted poster, helicopter) is the props track's
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 16 if fs >= 16 else 8)
	_outline(lbl, 2 if fs >= 16 else 1)
	lbl.add_theme_constant_override("line_spacing", 0)
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_snap.append(lbl)

func _snap_labels() -> void:
	var i := _snap.size() - 1
	while i >= 0:
		var l: Label = _snap[i]
		if not is_instance_valid(l) or not l.is_inside_tree():
			_snap.remove_at(i)
		else:
			l.global_position = l.global_position.round()
		i -= 1

func _process(_dt: float) -> void:
	if not _tower_sell_built and world.east_tower_built:
		_build_tower_sell()
	_sync_caves()
