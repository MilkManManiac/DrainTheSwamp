extends Node2D
# v3 pixel cave kit (2026-09-11). Instantiated by cave_base._setup_cave when
# V3_CAVES is on. Draws every cave out of baked pixel art in the same grid as
# the town (1 art px = 1 world unit = 2 screen px, sprites at scale 0.5,
# nearest filter): a Gemini backdrop plate per cave FAMILY behind a parallax
# layer, rock as texture-tiled polygons that follow the cave's own floor /
# ceiling contours, stalactites / stalagmites / boulders / crystals /
# mushrooms / roots as sprite strips with flip + scale-step variation, the
# signature set-piece as a sprite, and a banded flat-tone pixel water on the
# existing pool polygons. Gameplay nodes (collision, pools, loot, lore,
# lights, camera, exit, DTS_* hooks) stay in cave_base; nothing here is read
# by other code.

const ART := "res://assets/art/caves/"
const SCALE := 0.5
const WATER_SHADER := preload("res://shaders/cave_water_pixel.gdshader")

# cave_id -> family (which backdrop plate + rock tile); the per-cave palette
# from each cave's _init() is applied on top as a tint so no two match.
const FAMILY := {
	"muddy_hollow": "mud", "gator_den": "mud",
	"the_sinkhole": "stone", "collapsed_mine": "stone", "the_cistern": "stone",
	"the_mire": "grotto", "sunken_grotto": "grotto",
	"coral_cavern": "crystal", "the_underdark": "crystal",
	"mariana_trench": "deep",
}
const TILE := {"mud": "tile_earth", "grotto": "tile_earth", "stone": "tile_stone", "crystal": "tile_stone", "deep": "tile_stone"}
# Frames per baked strip (see docs/plans/revamp-tracks/caves.md for the bakes).
const FRAMES := {
	"stalactites": 5, "stalagmites": 5, "crystals": 5, "mushrooms": 4,
	"boulders": 5, "loot_props": 3, "signature": 7, "roots": 4,
}
const SIG_FRAME := {"crates": 0, "mine_cart": 1, "pump": 2, "skeleton": 3, "dead_tree": 4, "pillars": 5, "coral": 6}
const SCALE_STEPS := [0.75, 1.0, 1.25]

var cave: Node2D = null
var _rng := RandomNumberGenerator.new()
var _family: String = "stone"
var _left: float = 0.0
var _right: float = 0.0
var _tex_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if cave == null or cave.cave_terrain_points.size() < 2 or cave.cave_ceiling_points.size() < 2:
		return
	_rng.seed = hash(cave.cave_id)
	_family = FAMILY.get(cave.cave_id, "stone")
	_left = cave.cave_terrain_points[0].x
	_right = cave.cave_terrain_points[cave.cave_terrain_points.size() - 1].x
	_build_backdrop()
	_build_rock()
	_build_ceiling_props()
	_build_floor_props()
	_build_signature()
	_build_foreground()
	call_deferred("_late")

# --- helpers ---------------------------------------------------------------
func _tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path: String = ART + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[name] = t
	return t

# Colour with its brightest channel at 1 (hue only), for modulating grey art.
func _norm(c: Color) -> Color:
	var m: float = maxf(maxf(c.r, c.g), maxf(c.b, 0.01))
	return Color(c.r / m, c.g / m, c.b / m, 1.0)

func _floor_y(x: float) -> float:
	return cave._get_cave_terrain_y_at(x)

func _ceil_y(x: float) -> float:
	return cave._get_cave_ceiling_y_at(x)

func _in_pool(x: float, margin: float = 30.0) -> bool:
	for pd in cave.cave_pool_defs:
		if x >= pd["x_range"][0] - margin and x <= pd["x_range"][1] + margin:
			return true
	return false

# Frame `frame` of strip `name` anchored bottom-centre (or top-centre when
# hang=true) at (x, y). scale_mul picks a SCALE_STEPS entry; never free scale.
func _strip(name: String, frame: int, x: float, y: float, z: int, parent: Node = null, flip: bool = false, scale_mul: float = 1.0, hang: bool = false) -> Sprite2D:
	var t: Texture2D = _tex(name)
	if t == null:
		return null
	var s := Sprite2D.new()
	s.texture = t
	s.hframes = FRAMES.get(name, 1)
	s.frame = clampi(frame, 0, s.hframes - 1)
	s.flip_h = flip
	var sc: float = SCALE * scale_mul
	s.scale = Vector2(sc, sc)
	var cell_h: float = t.get_height() * sc
	# centred sprite: shift so the anchor lands on the contour
	s.position = Vector2(x, (y + cell_h * 0.5) if hang else (y - cell_h * 0.5))
	s.z_index = z
	(parent if parent else self).add_child(s)
	return s

func _light(pos: Vector2, col: Color, energy: float, radius: float, z: int = 0) -> PointLight2D:
	var pl := PointLight2D.new()
	pl.position = pos
	pl.color = col
	pl.blend_mode = PointLight2D.BLEND_MODE_ADD
	pl.energy = energy
	pl.shadow_enabled = false
	pl.texture = cave._make_radial_light_texture()
	pl.texture_scale = radius
	pl.z_index = z
	add_child(pl)
	return pl

# Rock-filled polygon: the tile repeats on the art grid (texture px = 2 x world
# units) and the tint multiplies it; vertex colours add a top-to-bottom shade.
func _rock_poly(pts: PackedVector2Array, tint: Color, z: int, shade_top: float = 1.0, shade_bottom: float = 1.0, parent: Node = null) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	var t: Texture2D = _tex(TILE.get(_family, "tile_stone"))
	if t:
		p.texture = t
		p.texture_scale = Vector2(2.0, 2.0)
	p.color = tint
	var vc := PackedColorArray()
	var min_y: float = pts[0].y
	var max_y: float = pts[0].y
	for q in pts:
		min_y = minf(min_y, q.y)
		max_y = maxf(max_y, q.y)
	for q in pts:
		var k: float = clampf((q.y - min_y) / maxf(max_y - min_y, 1.0), 0.0, 1.0)
		var f: float = lerpf(shade_top, shade_bottom, k)
		vc.append(Color(f, f, f, 1.0))
	p.vertex_colors = vc
	p.z_index = z
	(parent if parent else self).add_child(p)
	return p

# Crisp 2-px contour line (dark outline like the pack art) along a point list.
func _outline(pts: PackedVector2Array, col: Color, width: float, z: int) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = width
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_BEVEL
	l.z_index = z
	add_child(l)
	return l

# --- backdrop plate ----------------------------------------------------------
func _build_backdrop() -> void:
	var fog: Dictionary = cave._fog_palette()
	# solid fill behind everything so any gap is dark rock, never void
	var fill := ColorRect.new()
	fill.color = (fog["top"] as Color).darkened(0.5)
	fill.position = Vector2(_left - 900.0, -400.0)
	fill.size = Vector2(_right - _left + 1800.0, 1200.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.z_index = -22
	add_child(fill)

	var t: Texture2D = _tex("bg_" + _family)
	if t == null:
		return
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(0.35, 1.0)   # x parallax only; y stays world-locked
	var w: float = t.get_width() * SCALE
	layer.repeat_size = Vector2(w * 2.0, 0.0)  # plate + mirrored plate = seamless period
	layer.repeat_times = 3
	layer.z_index = -20
	add_child(layer)
	# plate sits on the cave's vertical band: ceiling top .. floor bottom
	var top_y: float = 1e9
	var bot_y: float = -1e9
	for p in cave.cave_ceiling_points:
		top_y = minf(top_y, p.y)
	for p in cave.cave_terrain_points:
		bot_y = maxf(bot_y, p.y)
	var h: float = t.get_height() * SCALE
	var py: float = (top_y + bot_y) * 0.5 - h * 0.5 - 10.0
	var tint: Color = Color.WHITE.lerp(_norm(cave.rock_mid_color), 0.5) * 0.62
	tint.a = 1.0
	for i in range(2):
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.scale = Vector2(SCALE, SCALE)
		s.flip_h = (i == 1)
		s.position = Vector2(-w + i * w, py)
		s.modulate = tint
		layer.add_child(s)
	# a low haze band over the plate so it sits behind the play space
	var haze := Polygon2D.new()
	haze.polygon = PackedVector2Array([
		Vector2(_left - 900.0, top_y - 100.0), Vector2(_right + 900.0, top_y - 100.0),
		Vector2(_right + 900.0, bot_y + 200.0), Vector2(_left - 900.0, bot_y + 200.0)])
	var hz: Color = fog["mid"] as Color
	haze.color = Color(hz.r, hz.g, hz.b, 0.18)
	haze.z_index = -19
	add_child(haze)

# --- rock masses -------------------------------------------------------------
func _build_rock() -> void:
	var tp: Array[Vector2] = cave.cave_terrain_points
	var cp: Array[Vector2] = cave.cave_ceiling_points
	var bottom: float = 460.0
	var top: float = -140.0
	var g_tint: Color = _norm(cave.ground_color) * 0.9
	var c_tint: Color = _norm(cave.ceiling_color) * 0.62
	var w_tint: Color = _norm(cave.wall_color) * 0.7
	g_tint.a = 1.0
	c_tint.a = 1.0
	w_tint.a = 1.0

	# floor
	var fpts := PackedVector2Array()
	for p in tp:
		fpts.append(p)
	fpts.append(Vector2(_right, bottom))
	fpts.append(Vector2(_left, bottom))
	_rock_poly(fpts, g_tint, 1, 1.0, 0.35)
	# floor lip: dark outline + lighter 1px edge just under the contour
	var line := PackedVector2Array()
	var lip := PackedVector2Array()
	for p in tp:
		line.append(p)
		lip.append(Vector2(p.x, p.y + 2.0))
	_outline(line, Color(0.03, 0.02, 0.03, 0.95), 2.0, 1)
	_outline(lip, (cave.ground_color as Color).lightened(0.35), 1.0, 1)

	# ceiling
	var cpts := PackedVector2Array()
	cpts.append(Vector2(_left, top))
	for p in cp:
		cpts.append(p)
	cpts.append(Vector2(_right, top))
	_rock_poly(cpts, c_tint, 5, 0.55, 1.0)
	var cline := PackedVector2Array()
	for p in cp:
		cline.append(p)
	_outline(cline, Color(0.03, 0.02, 0.03, 0.95), 2.0, 5)

	# end walls (thick, so overshoot never shows void) + exit cover
	var lw := PackedVector2Array([
		Vector2(_left - 520.0, top), Vector2(_left, top),
		Vector2(_left, cp[0].y), Vector2(_left, tp[0].y),
		Vector2(_left, bottom), Vector2(_left - 520.0, bottom)])
	_rock_poly(lw, w_tint, 4, 0.8, 0.5)
	var rw := PackedVector2Array([
		Vector2(_right, top), Vector2(_right + 520.0, top),
		Vector2(_right + 520.0, bottom), Vector2(_right, bottom),
		Vector2(_right, tp[tp.size() - 1].y), Vector2(_right, cp[cp.size() - 1].y)])
	_rock_poly(rw, w_tint, 4, 0.8, 0.5)
	# the doorway: rock behind the mouth at the far-back z so the warm gradient
	# door (cave_base) still reads as daylight through an opening
	var cover := PackedVector2Array([
		Vector2(_left - 520.0, top), Vector2(_left + 6.0, top),
		Vector2(_left + 6.0, bottom), Vector2(_left - 520.0, bottom)])
	_rock_poly(cover, w_tint * 0.8, -9, 0.7, 0.4)
	# wall edge outline so the mouth is a hard pixel edge
	_outline(PackedVector2Array([Vector2(_right, cp[cp.size() - 1].y - 2.0), Vector2(_right, tp[tp.size() - 1].y + 2.0)]), Color(0.03, 0.02, 0.03, 0.95), 2.0, 5)

# --- ceiling: stalactites, roots -------------------------------------------
func _build_ceiling_props() -> void:
	var x: float = _left + 70.0 + _rng.randf_range(0.0, 40.0)
	var last_frame: int = -1
	while x < _right - 40.0:
		var frame: int = _rng.randi_range(0, FRAMES["stalactites"] - 1)
		if frame == last_frame:
			frame = (frame + 1) % FRAMES["stalactites"]
		last_frame = frame
		var sm: float = SCALE_STEPS[_rng.randi_range(0, 2)]
		_strip("stalactites", frame, x, _ceil_y(x) - 1.0, 6, null, _rng.randf() < 0.5, sm, true)
		# a second, smaller one close by about half the time (clusters, not a comb)
		if _rng.randf() < 0.5:
			var x2: float = x + _rng.randf_range(18.0, 34.0)
			_strip("stalactites", (frame + 2) % FRAMES["stalactites"], x2, _ceil_y(x2) - 1.0, 6, null, _rng.randf() < 0.5, 0.75, true)
		x += _rng.randf_range(90.0, 170.0)
	if _family == "mud" or _family == "grotto":
		var rx: float = _left + 120.0 + _rng.randf_range(0.0, 80.0)
		while rx < _right - 60.0:
			_strip("roots", _rng.randi_range(0, FRAMES["roots"] - 1), rx, _ceil_y(rx) - 1.0, 6, null, _rng.randf() < 0.5, SCALE_STEPS[_rng.randi_range(0, 1)], true)
			rx += _rng.randf_range(200.0, 340.0)

# --- floor: boulders, stalagmites, crystals, mushrooms -----------------------
func _build_floor_props() -> void:
	var span: float = _right - _left
	# boulder clusters behind the player (z -2), a few small ones in front (z 3)
	var n_clust: int = clampi(int(span / 300.0) + 1, 2, 8)
	for i in range(n_clust):
		var ax: float = _left + 60.0 + (float(i) + _rng.randf_range(0.2, 0.8)) * (span - 120.0) / float(n_clust)
		if _in_pool(ax, 40.0):
			continue
		var children: int = _rng.randi_range(1, 3)
		for j in range(children):
			var bx: float = clampf(ax + _rng.randf_range(-40.0, 40.0), _left + 30.0, _right - 30.0)
			if _in_pool(bx, 20.0):
				continue
			var front: bool = j > 0 and _rng.randf() < 0.3
			var s := _strip("boulders", _rng.randi_range(0, FRAMES["boulders"] - 1), bx, _floor_y(bx) + 1.0, 3 if front else -2, null, _rng.randf() < 0.5, 0.75 if front else SCALE_STEPS[_rng.randi_range(0, 2)])
			if s:
				var bt: Color = _norm(cave.rock_mid_color) * (0.75 if front else 0.9)
				bt.a = 1.0
				s.modulate = bt
	# stalagmites
	var x: float = _left + 140.0 + _rng.randf_range(0.0, 60.0)
	while x < _right - 40.0:
		if not _in_pool(x, 24.0):
			var sm: float = SCALE_STEPS[_rng.randi_range(0, 2)]
			var s := _strip("stalagmites", _rng.randi_range(0, FRAMES["stalagmites"] - 1), x, _floor_y(x) + 1.0, -1 if sm > 1.0 else 3, null, _rng.randf() < 0.5, sm)
			if s:
				var st: Color = _norm(cave.ground_color) * 0.85
				st.a = 1.0
				s.modulate = st
		x += _rng.randf_range(160.0, 300.0)
	# crystals: overbright so HDR glow blooms them; lights join the cave's pulse list
	var n_cry: int = clampi(int(span / 420.0) + 1, 2, 6)
	var cc: Color = _norm(cave.crystal_color)
	for i in range(n_cry):
		var cx: float = _left + 100.0 + (float(i) + _rng.randf_range(0.15, 0.85)) * (span - 200.0) / float(n_cry)
		var on_ceiling: bool = _rng.randf() < 0.3
		if not on_ceiling and _in_pool(cx, 16.0):
			on_ceiling = true
		var s: Sprite2D
		var ly: float
		if on_ceiling:
			ly = _ceil_y(cx)
			s = _strip("crystals", _rng.randi_range(0, FRAMES["crystals"] - 1), cx, ly - 1.0, 6, null, _rng.randf() < 0.5, SCALE_STEPS[_rng.randi_range(0, 1)], true)
			if s:
				s.flip_v = true
		else:
			ly = _floor_y(cx)
			s = _strip("crystals", _rng.randi_range(0, FRAMES["crystals"] - 1), cx, ly + 1.0, -1, null, _rng.randf() < 0.5, SCALE_STEPS[_rng.randi_range(0, 2)])
		if s == null:
			continue
		s.modulate = cave._emit(cc.lerp(Color.WHITE, 0.25), 2.4)
		var pl := _light(Vector2(cx, ly + (10.0 if on_ceiling else -10.0)), cave.crystal_color, 1.0, 0.7)
		cave.crystal_lights.append(pl)
		cave.crystal_phases.append(_rng.randf_range(0.0, TAU))
	# glowing mushrooms: one or two clusters as focal points
	var n_mush: int = clampi(int(span / 700.0) + 1, 1, 3)
	for i in range(n_mush):
		var mx: float = _left + 180.0 + (float(i) + _rng.randf_range(0.2, 0.8)) * (span - 360.0) / float(n_mush)
		if _in_pool(mx, 24.0):
			mx = cave.cave_pool_defs[0]["x_range"][0] - 60.0 if cave.cave_pool_defs.size() > 0 else mx
		var s := _strip("mushrooms", _rng.randi_range(0, FRAMES["mushrooms"] - 1), mx, _floor_y(mx) + 1.0, 3, null, _rng.randf() < 0.5, SCALE_STEPS[_rng.randi_range(0, 1)])
		if s:
			s.modulate = cave._emit(Color.WHITE.lerp(cc, 0.45), 1.9)
			_light(Vector2(mx, _floor_y(mx) - 8.0), cave.crystal_color.lerp(Color.WHITE, 0.3), 0.7, 0.45)

# --- signature set-piece (same spot the old builder used: 62% across) --------
func _build_signature() -> void:
	var sig: String = cave.signature
	if sig == "" or not SIG_FRAME.has(sig):
		return
	var fx: float = lerpf(_left, _right, 0.62)
	if _in_pool(fx, 30.0):
		fx = lerpf(_left, _right, 0.5)
	var s := _strip("signature", SIG_FRAME[sig], fx, _floor_y(fx) + 1.0, -1, null, false, 1.0)
	if s == null:
		return
	if sig == "coral":
		s.modulate = cave._emit(Color.WHITE, 1.4)
		_light(Vector2(fx, _floor_y(fx) - 12.0), cave.crystal_color, 0.8, 0.5)
	elif sig == "pillars":
		# a second broken pillar further along, flipped
		var px: float = lerpf(_left, _right, 0.36)
		if not _in_pool(px, 30.0):
			_strip("signature", SIG_FRAME[sig], px, _floor_y(px) + 1.0, -1, null, true, 0.75)
	else:
		# small warm light so the set-piece reads as the room's landmark
		_light(Vector2(fx, _floor_y(fx) - 14.0), Color(0.9, 0.75, 0.5), 0.45, 0.5)

# --- foreground: two near-black framing rocks on a fast parallax ------------
func _build_foreground() -> void:
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(1.25, 1.0)
	layer.z_index = 11
	add_child(layer)
	var dark := Color(0.08, 0.07, 0.1, 1.0)
	var bx: float = _left + 140.0 if _rng.randf() < 0.5 else _right - 140.0
	var b := _strip("boulders", _rng.randi_range(0, FRAMES["boulders"] - 1), bx, _floor_y(bx) + 40.0, 11, layer, _rng.randf() < 0.5, 2.0)
	if b:
		b.modulate = dark
	var ox: float = lerpf(_left, _right, _rng.randf_range(0.3, 0.7))
	var o := _strip("stalactites", _rng.randi_range(0, FRAMES["stalactites"] - 1), ox, _ceil_y(ox) - 50.0, 11, layer, _rng.randf() < 0.5, 2.5, true)
	if o:
		o.modulate = dark

# --- after cave_base has built pools / lights: water + ambient ---------------
func _late() -> void:
	if cave == null or not is_instance_valid(cave):
		return
	for c in cave.get_children():
		if c is CanvasModulate:
			(c as CanvasModulate).color = Color(0.78, 0.79, 0.86)
	var cc: Color = cave.crystal_color
	var base := Color(0.30, 0.55, 0.70)
	for refs in cave.cave_pool_refs:
		var wp = refs.get("water_poly")
		if wp == null or not is_instance_valid(wp):
			continue
		var m := ShaderMaterial.new()
		m.shader = WATER_SHADER
		var top: Color = base.lerp(cc, 0.35)
		m.set_shader_parameter("top_col", Color(top.r, top.g, top.b, 0.82))
		var mid: Color = top.darkened(0.35)
		m.set_shader_parameter("mid_col", Color(mid.r, mid.g, mid.b, 0.88))
		var deep: Color = top.darkened(0.65)
		m.set_shader_parameter("deep_col", Color(deep.r, deep.g, deep.b, 0.94))
		var sp: Color = top.lightened(0.55)
		m.set_shader_parameter("spark_col", Color(sp.r, sp.g, sp.b, 0.95))
		m.set_shader_parameter("hdr_boost", 1.8 if cave._hdr else 1.0)
		m.set_shader_parameter("span_px", float(refs["x_end"]) - float(refs["x_start"]))
		m.set_shader_parameter("time", 0.0)
		wp.material = m
		wp.color = Color.WHITE
		var hl = refs.get("water_hl")
		if hl and is_instance_valid(hl):
			hl.color = cave._emit(Color(sp.r, sp.g, sp.b, 0.9), 1.6)
