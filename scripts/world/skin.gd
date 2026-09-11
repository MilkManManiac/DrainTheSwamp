extends Node2D
# v3 pixel-art skin (2026-09-10). Authored sky / ground / sun / moon layered
# over the world without editing game_world's procedural draws: the old nodes
# are switched off by reference, never re-tuned. Built deferred so it lands on
# top of everything game_world creates in _ready().

const ART := "res://assets/art/drainsville/"
const SCALE := 0.5
const DAY_MID := Color(0.55, 0.73, 0.94)   # game_world.SKY_DAY[1]; ratio drives the sky tint

var world: Node2D = null
var _sky: Sprite2D = null
var _sky_night: Sprite2D = null
var _sky_dusk: Sprite2D = null
var _tree_fill: Polygon2D = null
var _cypress_fill: Polygon2D = null
var _cypress: Array = []
var _water_tints: Array = []
var _sky_fill: ColorRect = null
var _fill_day := Color(0.60, 0.83, 0.89)
var _fill_dusk := Color(0.96, 0.74, 0.60)
var _fill_night := Color(0.18, 0.30, 0.51)
var _sun: Sprite2D = null
var _moon: Sprite2D = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_deferred("_build")

func _tex(name: String) -> Texture2D:
	return load(ART + name + ".png")

func _build() -> void:
	_build_sky()
	_build_sun_moon()
	_build_treeline()
	_build_ground()
	_build_vegetation()

# --- sky ----------------------------------------------------------------
func _build_sky() -> void:
	if world.far_hills_layer:
		world.far_hills_layer.visible = false
	var nh: ParallaxLayer = world.near_hills_layer
	if nh:
		for c in nh.get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = false
	for c in world.clouds:
		if c:
			c.visible = false
	var sl: ParallaxLayer = world.sky_layer
	if sl == null:
		return
	# Flat fill under the painted band so treeline gaps never show the old gradient.
	_sky_fill = ColorRect.new()
	_sky_fill.color = Color.WHITE
	_sky_fill.position = Vector2(-400.0, -400.0)
	_sky_fill.size = Vector2(1500.0, 1200.0)
	_sky_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_fill.z_index = -12
	sl.add_child(_sky_fill)
	_sky = Sprite2D.new()
	_sky.texture = _tex("sky_day")
	_sky.centered = false
	_sky.scale = Vector2(SCALE, SCALE)
	_sky.position = Vector2(0.0, 0.0)
	_sky.z_index = -12
	sl.add_child(_sky)
	_sky_dusk = _sky_layer_sprite(sl, "sky_dusk")
	_sky_night = _sky_layer_sprite(sl, "sky_night")
	# The painted skies stop at world y 180; the fill below must be exactly their
	# bottom row or the edge reads as a straight seam across the screen at night.
	_fill_day = _bottom_row_color(_sky.texture, _fill_day)
	_fill_dusk = _bottom_row_color(_sky_dusk.texture, _fill_dusk)
	_fill_night = _bottom_row_color(_sky_night.texture, _fill_night)

func _bottom_row_color(tex: Texture2D, fallback: Color) -> Color:
	var img: Image = tex.get_image() if tex else null
	if img == null:
		return fallback
	if img.is_compressed():
		img.decompress()
	var h: int = img.get_height()
	var acc := Color(0, 0, 0, 0)
	var n: int = 0
	for y in range(h - 2, h):
		for x in range(0, img.get_width(), 4):
			acc += img.get_pixel(x, y)
			n += 1
	return Color(acc.r / n, acc.g / n, acc.b / n, 1.0) if n > 0 else fallback

func _sky_layer_sprite(sl: ParallaxLayer, name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.z_index = -12
	s.modulate.a = 0.0
	sl.add_child(s)
	return s

# --- sun / moon: pixel discs ride on the old nodes' positions --------------
func _build_sun_moon() -> void:
	if world.sun_node:
		_hide_visuals(world.sun_node)
		_sun = Sprite2D.new()
		_sun.texture = _tex("sun")
		_sun.scale = Vector2(SCALE, SCALE)
		_sun.z_index = -10
		add_child(_sun)
	if world.moon:
		_hide_visuals(world.moon)
		_moon = Sprite2D.new()
		_moon.texture = _tex("moon")
		_moon.scale = Vector2(SCALE, SCALE)
		_moon.z_index = -10
		add_child(_moon)

func _hide_visuals(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem and not (c is Light2D):
			(c as CanvasItem).visible = false

# --- treeline: pines + cypress silhouettes ride a smoothed copy of the terrain
# in world space (not a viewport-anchored parallax band), so when the land
# drops they stay behind the ground instead of floating at screen height.
func _smooth_y(x: float) -> float:
	var acc: float = 0.0
	var n: int = 0
	var dx: float = -160.0
	while dx <= 160.0:
		acc += world._get_terrain_y_at(x + dx)
		n += 1
		dx += 40.0
	return acc / float(n)

func _band_fill(color: Color, lift: float, z: int, x0: float, x1: float) -> Polygon2D:
	var poly := PackedVector2Array()
	var x: float = x0
	while x < x1:
		poly.append(Vector2(x, _smooth_y(x) - lift))
		x += 32.0
	poly.append(Vector2(x1, _smooth_y(x1) - lift))
	poly.append(Vector2(x1, 2400.0))
	poly.append(Vector2(x0, 2400.0))
	var p := Polygon2D.new()
	p.polygon = poly
	p.color = color
	p.z_index = z
	add_child(p)
	return p

func _band_row(tex: Texture2D, x0: float, x1: float, lift: float, z: int, mod: Color, flip: bool, xoff: float) -> Array:
	var w: float = tex.get_width() * SCALE
	var out: Array = []
	var x: float = x0 + xoff
	while x < x1:
		var ya: float = _smooth_y(x) - lift
		var yb: float = _smooth_y(x + w) - lift
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(0.0, -float(tex.get_height()))   # pivot = bottom-left
		s.scale = Vector2(SCALE, SCALE)
		s.flip_h = flip
		s.position = Vector2(x, ya)
		s.rotation = atan2(yb - ya, w)
		s.modulate = mod
		s.z_index = z
		add_child(s)
		out.append(s)
		x += w
	return out

func _build_treeline() -> void:
	var tl: ParallaxLayer = world.treeline_layer
	if tl:
		for c in tl.get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = false
	var x0: float = world.terrain_points[0].x - 600.0
	var x1: float = world.terrain_points[world.terrain_points.size() - 1].x + 600.0
	var tex: Texture2D = _tex("far_treeline")
	var w: float = tex.get_width() * SCALE
	# Solid forest mass under the pines, down past any dip in the ground.
	_tree_fill = _band_fill(Color(0.36, 0.44, 0.42), 36.0, -5, x0, x1)
	_band_row(tex, x0, x1, 36.0, -5, Color.WHITE, false, 0.0)
	# Second, darker row a little lower: reads as forest depth, not a flat wall.
	_band_row(tex, x0, x1, 14.0, -5, Color(0.62, 0.68, 0.66), true, w * 0.37)
	# Cypress silhouettes just behind the ground line, in front of the pines.
	var ctex: Texture2D = _tex("cypress_band")
	_cypress_fill = _band_fill(Color(38.0 / 255.0, 56.0 / 255.0, 58.0 / 255.0), -12.0, -4, x0, x1)
	_cypress = _band_row(ctex, x0, x1, -12.0, -4, Color.WHITE, false, 0.0)

# --- ground: textured polygon under the terrain line + surface strip -------
func _build_ground() -> void:
	var pts: Array = world.terrain_points
	if world.terrain_polygon:
		world.terrain_polygon.visible = false
	for c in world.get_children():
		if c is Polygon2D and (c.color == world.GROUND_MID_COLOR or c.color == world.GROUND_DARK_COLOR):
			c.visible = false
		elif c is Line2D and c.z_index == 1 and (c.default_color == world.GRASS_COLOR or c.default_color == world.GRASS_LIGHT_COLOR):
			c.visible = false
	var max_y: float = 0.0
	for p in pts:
		max_y = maxf(max_y, p.y)
	var poly := Polygon2D.new()
	var v := PackedVector2Array()
	for p in pts:
		v.append(p)
	v.append(Vector2(pts[-1].x, max_y + 400.0))
	v.append(Vector2(pts[0].x, max_y + 400.0))
	poly.polygon = v
	poly.texture = _tex("ground_dirt")
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	poly.texture_scale = Vector2(2.0, 2.0)   # 1 texel = 0.5 world units
	poly.z_index = -3
	add_child(poly)
	# Depth shade: the cut fades to dark the deeper it goes.
	var shade := Polygon2D.new()
	var sv := PackedVector2Array()
	var sc := PackedColorArray()
	for p in pts:
		sv.append(Vector2(p.x, p.y + 20.0))
		sc.append(Color(0.05, 0.03, 0.02, 0.0))
	sv.append(Vector2(pts[-1].x, max_y + 400.0))
	sv.append(Vector2(pts[0].x, max_y + 400.0))
	sc.append(Color(0.05, 0.03, 0.02, 0.85))
	sc.append(Color(0.05, 0.03, 0.02, 0.85))
	shade.polygon = sv
	shade.vertex_colors = sc
	shade.z_index = -3
	add_child(shade)
	# Dark mud beds under every pool basin (the water shader refracts what is
	# behind it; bright root texture there read as a grey sheet).
	var bed_tex: Texture2D = _tex("ground_dirt")
	for r in world.SWAMP_RANGES:
		var bed := Polygon2D.new()
		var bv := PackedVector2Array()
		var top_y: float = minf(pts[r[0]].y, pts[r[1]].y)
		bv.append(Vector2(pts[r[0]].x, top_y - 2.0))
		for i in range(r[0], r[1] + 1):
			bv.append(pts[i])
		bv.append(Vector2(pts[r[1]].x, top_y - 2.0))
		bed.polygon = bv
		bed.texture = bed_tex
		bed.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
		bed.texture_scale = Vector2(2.0, 2.0)
		bed.color = Color(0.22, 0.20, 0.16)
		bed.z_index = -3
		add_child(bed)
	# Murk overlays that track each water polygon: the shader's sky reflection
	# and sparkle wash the pools out to grey; this puts the pool's colour back.
	for i in range(world.water_polygons.size()):
		var t := Polygon2D.new()
		var wc: Color = world.SWAMP_WATER_COLORS[i]
		t.color = Color(wc.r, wc.g, wc.b, 0.7)
		t.z_index = 4
		add_child(t)
		_water_tints.append(t)
	# Surface strip: 32-unit tiles following the terrain slope.
	var tiles: Array = []
	for i in range(10):
		tiles.append(_tex("ground_top_%d" % i))
	var x: float = pts[0].x
	var end_x: float = pts[-1].x
	var k := 0
	while x < end_x:
		var y0: float = world._get_terrain_y_at(x)
		var y1: float = world._get_terrain_y_at(x + 32.0)
		if y0 <= 0.0 or y1 <= 0.0:
			x += 32.0
			continue
		var s := Sprite2D.new()
		s.texture = tiles[(k * 7 + int(x / 32.0)) % 10]
		s.centered = false
		s.scale = Vector2(SCALE, SCALE)
		s.rotation = atan2(y1 - y0, 32.0)
		s.position = Vector2(x, y0 - 15.0)  # strip's dirt line is 30 texels down
		s.z_index = -3
		add_child(s)
		x += 32.0 * cos(s.rotation)
		k += 1

# --- vegetation: pack trees / willows / bushes / stones / tufts along the banks ---
func _build_vegetation() -> void:
	var pts: Array = world.terrain_points
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# Keep-out spans: town strip and every pool basin (plus a margin).
	var spans: Array = [[-600.0, 130.0]]
	for r in world.SWAMP_RANGES:
		spans.append([pts[r[0]].x - 24.0, pts[r[1]].x + 24.0])
	var x: float = -520.0
	var end_x: float = pts[-1].x - 40.0
	while x < end_x:
		var blocked := false
		for sp in spans:
			if x > sp[0] and x < sp[1]:
				blocked = true
				break
		if blocked:
			x += 18.0
			continue
		var gy: float = world._get_terrain_y_at(x)
		if gy > 0.0:
			var roll: float = rng.randf()
			var flip: bool = rng.randf() < 0.5
			if roll < 0.14:
				_veg("tree_%d" % rng.randi_range(1, 3), x, gy + 2.0, -4, flip)
			elif roll < 0.24:
				_veg("willow_%d" % rng.randi_range(1, 3), x, gy + 2.0, -4, flip)
			elif roll < 0.55:
				_veg("bush_%d" % rng.randi_range(4, 9), x, gy + 1.0, 1 if rng.randf() < 0.5 else -1, flip)
			elif roll < 0.72:
				_veg("stone_%d" % rng.randi_range(1, 5), x, gy + 1.0, -1, flip)
			else:
				_veg("tuft_%d" % rng.randi_range(1, 6), x, gy + 1.0, 1, flip)
		x += rng.randf_range(28.0, 70.0)
	# A willow leaning over each pool's near bank.
	for r in world.SWAMP_RANGES:
		var bx: float = pts[r[0]].x - 14.0
		var by: float = world._get_terrain_y_at(bx)
		if by > 0.0:
			_veg("willow_%d" % rng.randi_range(2, 3), bx, by + 2.0, -4, false)

func _veg(name: String, x: float, ground_y: float, z: int, flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.flip_h = flip
	s.position = Vector2(x - s.texture.get_width() * SCALE * 0.5, ground_y - s.texture.get_height() * SCALE)
	s.z_index = z
	add_child(s)
	return s

func _process(_dt: float) -> void:
	if _sky and world.sky_gradient_res:
		var cols: PackedColorArray = world.sky_gradient_res.colors
		if cols.size() >= 2:
			var m: Color = cols[1]
			# Three painted skies cross-faded off the old gradient's mid color:
			# warmth (r-b) picks dusk/dawn, luminance picks night.
			var lum: float = clampf(m.get_luminance() / DAY_MID.get_luminance(), 0.0, 1.0)
			var dusk_amt: float = clampf((m.r - m.b + 0.05) / 0.4, 0.0, 1.0)
			var night_amt: float = clampf((0.75 - lum) / 0.6, 0.0, 1.0)
			var tint: float = clampf(lum * 1.15, 0.25, 1.0)
			_sky.modulate = Color(tint, tint, tint)
			_sky_dusk.modulate = Color(tint, tint, tint, dusk_amt)
			_sky_night.modulate.a = night_amt
			# Fill composites the sampled bottom rows the same way the sprites stack:
			# day and dusk carry the tint, night is drawn untinted on top.
			var dd: Color = (_fill_day * tint).lerp(_fill_dusk * tint, dusk_amt)
			var fill: Color = dd.lerp(_fill_night, night_amt)
			fill.a = 1.0
			_sky_fill.modulate = fill
			if _tree_fill:
				_tree_fill.modulate = Color(tint, tint, tint).lerp(Color(0.12, 0.16, 0.22), night_amt)
			if _cypress_fill:
				var cm: Color = Color(tint, tint, tint).lerp(Color(0.10, 0.13, 0.20), night_amt)
				_cypress_fill.modulate = cm
				for c in _cypress:
					c.modulate = cm
	for i in range(_water_tints.size()):
		var wp: Polygon2D = world.water_polygons[i]
		_water_tints[i].polygon = wp.polygon
		_water_tints[i].visible = wp.visible and wp.polygon.size() >= 3
	if _sun and world.sun_node:
		_sun.global_position = world.sun_node.global_position.round()
		_sun.visible = world.sun_node.visible
	if _moon and world.moon:
		_moon.global_position = world.moon.global_position.round()
		_moon.visible = world.moon.visible
