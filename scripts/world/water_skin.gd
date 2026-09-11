extends Node2D
# v3 pixel-art water (2026-09-11). Draws every basin as authored pixel water
# over game_world's water_polygons (which are switched off by reference, never
# re-tuned): banded flat tones, quantized highlight rows, a 2 px foam rim at
# the bank, a cracked-mud bed that fades in as the basin drains. Murk lifts with
# the heal grade; palette follows day / dusk / night. Built deferred so it lands
# on top of everything game_world creates in _ready().
#
# Debug (only when DTS_SHOT is set): DTS_FILL=0..1 forces the drawn fill level
# of every basin so a drained bed can be captured without touching the save.

const ART := "res://assets/art/drainsville/"
const SHADER := preload("res://shaders/pixel_water.gdshader")
const RIM := 2.0   # foam rim thickness, art px

# Palettes: [top, surf, mid, deep, hi]
# Murky was originally a yellow-olive that sat almost on top of the grass/mud
# hue (both ~equal R/G, low B) and vanished by day. Shifted blue-forward so it
# reads as swamp WATER (silty, but still water) against the green banks at any
# time of day; kept darker than CLEAR so heal still visibly brightens it.
const MURKY: Array = [
	Color(0.40, 0.46, 0.38), Color(0.20, 0.30, 0.28), Color(0.12, 0.20, 0.20), Color(0.06, 0.11, 0.13), Color(0.68, 0.70, 0.56)]
const CLEAR: Array = [
	Color(0.74, 0.90, 0.78), Color(0.18, 0.60, 0.58), Color(0.10, 0.42, 0.46), Color(0.05, 0.24, 0.30), Color(1.00, 0.92, 0.62)]
const NIGHT: Array = [
	Color(0.70, 0.80, 1.00), Color(0.24, 0.34, 0.66), Color(0.14, 0.21, 0.48), Color(0.08, 0.12, 0.30), Color(1.00, 1.00, 1.00)]
const DUSK_WARM := Color(1.0, 0.72, 0.42)

var world: Node2D = null
var _water: Array = []      # Polygon2D with the pixel shader, per basin
var _rim: Array = []        # Polygon2D foam rim under it
var _bed: Array = []        # Polygon2D cracked mud bed
var _fill_override: float = -1.0
var _built := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if OS.get_environment("DTS_SHOT") != "":
		var f: String = OS.get_environment("DTS_FILL")
		if f != "":
			_fill_override = clampf(f.to_float(), 0.0, 1.0)
	call_deferred("_build")

func _tex(name: String) -> Texture2D:
	return load(ART + name + ".png")

func _build() -> void:
	var n: int = world.water_polygons.size()
	var bed_tex: Texture2D = _tex("cracked_mud") if ResourceLoader.exists(ART + "cracked_mud.png") else _tex("ground_dirt")
	var pts: Array = world.terrain_points
	for i in range(n):
		# Old draw off by reference (nodes stay alive: other code indexes them).
		_hide(world.water_polygons, i)
		_hide(world.water_surface_lines, i)
		_hide(world.water_glow_lines, i)
		_hide(world.water_foam_lines, i)
		_hide(world.shimmer_lines, i)
		_hide(world.foam_lines, i)
		_hide(world.depth_polygons, i)
		# Cracked bed: the whole basin cut, under the water, fades in as it drains.
		var r: Array = world.SWAMP_RANGES[i]
		var bed := Polygon2D.new()
		var bv := PackedVector2Array()
		var top_y: float = minf(pts[r[0]].y, pts[r[1]].y)
		bv.append(Vector2(pts[r[0]].x, top_y - 2.0))
		for k in range(r[0], r[1] + 1):
			bv.append(pts[k])
		bv.append(Vector2(pts[r[1]].x, top_y - 2.0))
		bed.polygon = bv
		bed.texture = bed_tex
		bed.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		bed.texture_scale = Vector2(2.0, 2.0)   # baked x2: 1 art px = 1 world unit
		bed.texture_offset = Vector2(float(i) * 37.0, float(i) * 23.0)
		bed.z_index = -2
		bed.modulate.a = 0.0
		add_child(bed)
		_bed.append(bed)
		# Foam rim: the water polygon itself in the light colour; the shaded
		# water sits on top shrunk by RIM px on the bank sides only.
		var rim := Polygon2D.new()
		rim.z_index = 2
		add_child(rim)
		_rim.append(rim)
		var w := Polygon2D.new()
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		w.material = mat
		w.z_index = 3
		add_child(w)
		_water.append(w)
	_built = true

func _hide(arr: Array, i: int) -> void:
	if i < arr.size() and arr[i] is CanvasItem:
		(arr[i] as CanvasItem).visible = false

# --- geometry -------------------------------------------------------------
func _fill(i: int) -> float:
	if _fill_override >= 0.0:
		return _fill_override
	return GameManager.get_swamp_fill_fraction(i)

# The polygon game_world traces for this basin, or a re-trace at a forced fill.
func _poly(i: int) -> PackedVector2Array:
	if _fill_override < 0.0:
		return world.water_polygons[i].polygon
	var fill: float = _fill_override
	if fill <= 0.001:
		return PackedVector2Array()
	var deepest_y: float = world._get_pool_deepest_y(i)
	var overflow_y: float = world._get_pool_overflow_y(i)
	var water_y: float = deepest_y - fill * (deepest_y - overflow_y)
	var left_x: float = world._find_water_left_x(i, water_y)
	var right_x: float = world._find_water_right_x(i, water_y)
	var out := PackedVector2Array()
	out.append(Vector2(left_x, water_y))
	var r: Array = world.SWAMP_RANGES[i]
	for k in range(r[0], r[1] + 1):
		var pt: Vector2 = world.terrain_points[k]
		if pt.y >= water_y and pt.x >= left_x and pt.x <= right_x:
			out.append(pt)
	out.append(Vector2(right_x, water_y))
	return out

# Shrink the water polygon by RIM on the bank sides, keep the top at the waterline.
# Small/narrow basins can collapse under a miter offset (Geometry2D returns
# empty, or a degenerate sliver) — fall back to the unshrunk polygon so the
# banded water always draws; losing the 2px rim inset there is a minor polish
# loss, not a basin reading as flat/invisible water.
func _inner(poly: PackedVector2Array, surface_y: float) -> PackedVector2Array:
	var res: Array = Geometry2D.offset_polygon(poly, -RIM, Geometry2D.JOIN_MITER)
	var best: PackedVector2Array = PackedVector2Array()
	if not res.is_empty():
		best = res[0]
		for p in res:
			if p.size() > best.size():
				best = p
	if best.size() < 3:
		best = poly
	var out := PackedVector2Array()
	for v in best:
		if v.y < surface_y + RIM + 0.6:
			out.append(Vector2(v.x, surface_y))
		else:
			out.append(v)
	return out

# --- per frame --------------------------------------------------------------
func _process(_dt: float) -> void:
	if not _built:
		return
	var t: float = GameManager.cycle_progress
	# Day / dusk / night amounts on the same breakpoints game_world uses for
	# its shader daytime / night_factor ramps.
	var night: float = 0.0
	if t > 0.72 or t < 0.12:
		night = 1.0
	elif t >= 0.65:
		night = (t - 0.65) / 0.07
	elif t <= 0.2:
		night = 1.0 - (t - 0.12) / 0.08
	var dusk: float = 0.0
	if t >= 0.55 and t < 0.72:
		dusk = sin((t - 0.55) / 0.17 * PI)
	elif t >= 0.12 and t < 0.25:
		dusk = sin((t - 0.12) / 0.13 * PI) * 0.6
	# Heal grade: same total as game_world's drain_progress (+ DTS_DRAIN preview).
	var heal: float = _heal()
	# Sky reflection tint off the sky gradient's mid colour (as skin.gd does).
	var sky: Color = Color(0.55, 0.73, 0.94)
	if world.sky_gradient_res and world.sky_gradient_res.colors.size() >= 2:
		sky = world.sky_gradient_res.colors[1]
	var wave_time: float = world.wave_time
	for i in range(_water.size()):
		var w: Polygon2D = _water[i]
		var rim: Polygon2D = _rim[i]
		var bed: Polygon2D = _bed[i]
		var fill: float = _fill(i)
		bed.modulate = Color(0.82, 0.76, 0.70, clampf((1.0 - fill) * 1.6, 0.0, 0.9))
		var poly: PackedVector2Array = _poly(i)
		if poly.size() < 3:
			w.visible = false
			rim.visible = false
			continue
		w.visible = true
		rim.visible = true
		var surface_y: float = poly[0].y
		rim.polygon = poly
		w.polygon = _inner(poly, surface_y)
		# Palette: murky -> clear by heal, then a little of the basin's own hue
		# for identity, then dusk warmth on the lit rows, then the night set.
		var wc: Color = world.SWAMP_WATER_COLORS[i]
		var pal: Array = []
		for k in range(5):
			var c: Color = (MURKY[k] as Color).lerp(CLEAR[k], heal)
			if k >= 1 and k <= 3:
				c = c.lerp(Color(wc.r, wc.g, wc.b), 0.12)
			if k == 0 or k == 4:
				c = c.lerp(sky, 0.12 * (1.0 - night))
				c = c.lerp(DUSK_WARM, dusk * 0.45)
			elif k == 1:
				c = c.lerp(sky, 0.05 * (1.0 - night))
				c = c.lerp(DUSK_WARM, dusk * 0.12)
			c = c.lerp(NIGHT[k], night)
			pal.append(c)
		var mat: ShaderMaterial = w.material as ShaderMaterial
		mat.set_shader_parameter("time", wave_time)
		mat.set_shader_parameter("surface_y", surface_y)
		mat.set_shader_parameter("col_top", Vector3(pal[0].r, pal[0].g, pal[0].b))
		mat.set_shader_parameter("col_surf", Vector3(pal[1].r, pal[1].g, pal[1].b))
		mat.set_shader_parameter("col_mid", Vector3(pal[2].r, pal[2].g, pal[2].b))
		mat.set_shader_parameter("col_deep", Vector3(pal[3].r, pal[3].g, pal[3].b))
		mat.set_shader_parameter("col_hi", Vector3(pal[4].r, pal[4].g, pal[4].b))
		# Deeper basins get thicker bands so the deep tone still shows.
		var depth: float = world._get_pool_deepest_y(i) - surface_y
		mat.set_shader_parameter("band1", clampf(depth * 0.18, 3.0, 9.0))
		mat.set_shader_parameter("band2", clampf(depth * 0.45, 8.0, 26.0))
		mat.set_shader_parameter("hi_amount", 1.0)
		mat.set_shader_parameter("drift", 2.0 + float(i % 3))
		# Rim: foam colour, a touch brighter than the waterline row.
		var rc: Color = pal[0].lightened(0.22)
		rim.color = Color(rc.r, rc.g, rc.b, 1.0)

func _heal() -> float:
	var total_drained: float = 0.0
	var total_capacity: float = 0.0
	for si in range(world.SWAMP_COUNT):
		total_capacity += GameManager.swamp_definitions[si]["total_gallons"]
		total_drained += GameManager.swamp_states[si]["gallons_drained"]
	var heal: float = total_drained / maxf(total_capacity, 1.0)
	if OS.get_environment("DTS_SHOT") != "":
		var dr: String = OS.get_environment("DTS_DRAIN")
		if dr != "":
			heal = clampf(dr.to_float(), 0.0, 1.0)
	return heal
