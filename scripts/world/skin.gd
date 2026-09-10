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
var _sky_fill: ColorRect = null
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

# --- sky ----------------------------------------------------------------
func _build_sky() -> void:
	for l in [world.far_hills_layer, world.near_hills_layer]:
		if l:
			l.visible = false
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

# --- treeline: pack pines tiled across the world in the 0.6 parallax layer ---
func _build_treeline() -> void:
	var tl: ParallaxLayer = world.treeline_layer
	if tl == null:
		return
	for c in tl.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	var tex: Texture2D = _tex("far_treeline")
	var w: float = tex.get_width() * SCALE
	var world_w: float = world.terrain_points[world.terrain_points.size() - 1].x + 400.0
	var x: float = -900.0
	while x < world_w:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(SCALE, SCALE)
		s.position = Vector2(x, 150.0 - tex.get_height() * SCALE)
		s.z_index = -5
		tl.add_child(s)
		x += w

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
			# Fill matches the bottom row of whichever sky is showing.
			var fill: Color = Color(0.60, 0.83, 0.89).lerp(Color(0.96, 0.74, 0.60), dusk_amt).lerp(Color(0.18, 0.30, 0.51), night_amt)
			_sky_fill.modulate = fill * tint
	if _sun and world.sun_node:
		_sun.global_position = world.sun_node.global_position.round()
		_sun.visible = world.sun_node.visible
	if _moon and world.moon:
		_moon.global_position = world.moon.global_position.round()
		_moon.visible = world.moon.visible
