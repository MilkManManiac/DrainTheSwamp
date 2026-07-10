extends Node2D
# Drainsville — the painterly procedural town, extracted verbatim from
# game_world.gd (Phase 4 god-file split). Build-once scenery: no signal
# subscriptions; the only per-frame coupling is update_glow(), which
# game_world calls with the day/night glow factor.
#
# `world` must be set (to the GameWorld node) before build()/building()/
# water_tower() are called — helpers use its terrain lookup, HDR _emit,
# and radial light texture.

var world: Node2D = null

# Glow elements (window glass / lamp flames / string bulbs) lerped between a
# day (unlit) and night (emissive) color by time-of-day — lit windows at noon
# made the whole town read as a night scene.
var glow_rects: Array = []          # [{node: ColorRect, day: Color, night: Color}]
var glow_point_lights: Array = []   # [{node: PointLight2D, energy: float}]
var _glow_last: float = -1.0

# Town lights: off in daylight, warm from dusk through dawn (glow_t 0..1).
func update_glow(glow_t: float) -> void:
	if absf(glow_t - _glow_last) <= 0.01:
		return
	_glow_last = glow_t
	for gr in glow_rects:
		(gr["node"] as ColorRect).color = (gr["day"] as Color).lerp(gr["night"], glow_t)
	for gl in glow_point_lights:
		(gl["node"] as PointLight2D).energy = (gl["energy"] as float) * glow_t

func build() -> void:
	# Drainsville — a weathered bayou hamlet on the home shore (painterly procedural).
	var gnd := 136.0
	# --- Background rooftops: a deeper town behind the main street (depth) ---
	var bg_roofs: Array = [
		Vector2(-430, 28), Vector2(-360, 34), Vector2(-285, 24),
		Vector2(-205, 32), Vector2(-130, 26), Vector2(-55, 30), Vector2(20, 28),
	]
	for r in bg_roofs:
		var bx: float = r.x
		var bh: float = r.y
		var bw: float = 28.0
		var rg: float = gnd - 26.0
		var bwall := Polygon2D.new()
		bwall.polygon = PackedVector2Array([Vector2(bx, rg - bh), Vector2(bx + bw, rg - bh), Vector2(bx + bw, rg), Vector2(bx, rg)])
		var bc := Color(0.16, 0.18, 0.19)
		bwall.vertex_colors = PackedColorArray([bc.lightened(0.05), bc.lightened(0.02), bc.darkened(0.12), bc.darkened(0.16)])
		bwall.z_index = -1
		add_child(bwall)
		var broof := Polygon2D.new()
		broof.polygon = PackedVector2Array([Vector2(bx - 3, rg - bh), Vector2(bx + bw * 0.5, rg - bh - 9), Vector2(bx + bw + 3, rg - bh)])
		broof.color = Color(0.12, 0.12, 0.14)
		broof.z_index = -1
		add_child(broof)
	# --- Boardwalk along the (now much wider) street ---
	for bxi in range(-485, 70, 9):
		var bgy: float = world._get_terrain_y_at(float(bxi))
		if bgy <= 0.0:
			bgy = gnd
		var plank := Polygon2D.new()
		var pcol := Color(0.34, 0.25, 0.16) if (bxi / 9) % 2 == 0 else Color(0.29, 0.21, 0.13)
		plank.polygon = PackedVector2Array([Vector2(bxi, bgy - 3), Vector2(bxi + 8.5, bgy - 3), Vector2(bxi + 8.5, bgy + 2), Vector2(bxi, bgy + 2)])
		plank.color = pcol
		plank.z_index = 1
		add_child(plank)
	# --- Main street buildings, spread out (Hardware is built in _build_shop at ~-22) ---
	# Weathered-but-sunlit paint: values high enough to read as daylight walls
	# (the old 0.35-0.40 walls rendered as night silhouettes at noon).
	var buildings: Array = [
		{"x": -130.0, "w": 44.0, "h": 36.0, "wall": Color(0.66, 0.58, 0.42), "roof": Color(0.38, 0.26, 0.20), "sign": "DINER", "sc": Color(1.0, 0.84, 0.5), "style": 1},
		{"x": -240.0, "w": 40.0, "h": 44.0, "wall": Color(0.60, 0.44, 0.40), "roof": Color(0.40, 0.32, 0.27), "sign": "PAWN", "sc": Color(1.0, 0.9, 0.45), "style": 2},
		{"x": -345.0, "w": 46.0, "h": 38.0, "wall": Color(0.56, 0.60, 0.44), "roof": Color(0.34, 0.38, 0.26), "sign": "OUTFITTER", "sc": Color(0.95, 0.88, 0.6), "style": 0},
		{"x": -448.0, "w": 40.0, "h": 33.0, "wall": Color(0.58, 0.55, 0.50), "roof": Color(0.32, 0.34, 0.36), "sign": "", "sc": Color(1, 1, 1), "style": 1},
	]
	for b in buildings:
		var gy: float = world._get_terrain_y_at(b["x"] + b["w"] * 0.5)
		if gy <= 0.0:
			gy = gnd
		building(b["x"], gy, b["w"], b["h"], b["wall"], b["roof"], b["sign"], b["sc"], b["style"])
	# --- Street props (in the wide gaps between shops) ---
	_lamp_post(-75.0, grnd(-75.0, gnd))
	_lamp_post(-185.0, grnd(-185.0, gnd))
	_lamp_post(-295.0, grnd(-295.0, gnd))
	_lamp_post(-400.0, grnd(-400.0, gnd))
	_barrels(-180.0, grnd(-180.0, gnd))
	_crates(-300.0, grnd(-300.0, gnd))
	_string_lights(-130.0, 28.0, gnd - 42.0)
	_string_lights(-345.0, -130.0, gnd - 44.0)
	_string_lights(-465.0, -345.0, gnd - 42.0)
	# Water tower — east landmark / future auto-sell point
	water_tower(55.0, grnd(55.0, gnd))
	# NA dead-drop — tucked at the quiet west edge by the trees
	_dropbox(-468.0, grnd(-468.0, gnd))

func grnd(x: float, fallback: float) -> float:
	var y: float = world._get_terrain_y_at(x)
	return y if y > 0.0 else fallback

func building(base_x: float, ground_y: float, w: float, h: float, wall_col: Color, roof_col: Color, sign_text: String, sign_col: Color, style: int) -> void:
	var z := 3
	var cx := base_x + w * 0.5
	var top_y := ground_y - h
	# Contact shadow under the building
	var shadow := ColorRect.new()
	shadow.position = Vector2(base_x - 3, ground_y - 1)
	shadow.size = Vector2(w + 6, 4)
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	shadow.z_index = z - 1
	add_child(shadow)
	# Stone foundation + a couple cypress pilings
	var found := ColorRect.new()
	found.position = Vector2(base_x, ground_y - 6)
	found.size = Vector2(w, 7)
	found.color = Color(0.33, 0.30, 0.27)
	found.z_index = z
	add_child(found)
	for px in [base_x + 4.0, base_x + w - 6.0]:
		var pile := ColorRect.new()
		pile.position = Vector2(px, ground_y - 4)
		pile.size = Vector2(3, 6)
		pile.color = Color(0.22, 0.16, 0.11)
		pile.z_index = z - 1
		add_child(pile)
	# Wall with a soft light->shade + top->bottom gradient (painterly)
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([
		Vector2(base_x + 1, top_y), Vector2(base_x + w - 1, top_y),
		Vector2(base_x + w - 1, ground_y - 5), Vector2(base_x + 1, ground_y - 5)])
	wall.vertex_colors = PackedColorArray([
		wall_col.lightened(0.16), wall_col.darkened(0.05),
		wall_col.darkened(0.24), wall_col.darkened(0.04)])
	wall.z_index = z
	add_child(wall)
	# Plank seams
	for pi in range(1, int((h - 5) / 7.0)):
		var plank := ColorRect.new()
		plank.position = Vector2(base_x + 1, top_y + pi * 7)
		plank.size = Vector2(w - 2, 1)
		var pc: Color = wall_col.darkened(0.32)
		pc.a = 0.45
		plank.color = pc
		plank.z_index = z
		add_child(plank)
	# Corner trim boards
	for tx in [base_x + 1.0, base_x + w - 3.0]:
		var trim := ColorRect.new()
		trim.position = Vector2(tx, top_y)
		trim.size = Vector2(2, h - 5)
		trim.color = wall_col.darkened(0.3)
		trim.z_index = z
		add_child(trim)
	# Roof (style: 0 gable, 1 shed-slant, 2 flat parapet) with tin gradient + corrugation
	var roof := Polygon2D.new()
	var eave := 4.0
	if style == 2:
		# flat with parapet
		roof.polygon = PackedVector2Array([
			Vector2(base_x - eave, top_y - 5), Vector2(base_x + w + eave, top_y - 5),
			Vector2(base_x + w + eave, top_y + 1), Vector2(base_x - eave, top_y + 1)])
		roof.vertex_colors = PackedColorArray([roof_col.lightened(0.12), roof_col.darkened(0.05), roof_col.darkened(0.2), roof_col.darkened(0.12)])
	elif style == 1:
		# shed slant (high on the left)
		roof.polygon = PackedVector2Array([
			Vector2(base_x - eave, top_y - 11), Vector2(base_x + w + eave, top_y - 1),
			Vector2(base_x + w + eave, top_y + 3), Vector2(base_x - eave, top_y - 7)])
		roof.vertex_colors = PackedColorArray([roof_col.lightened(0.16), roof_col.darkened(0.04), roof_col.darkened(0.18), roof_col.darkened(0.02)])
	else:
		# gable
		roof.polygon = PackedVector2Array([
			Vector2(base_x - eave, top_y + 2), Vector2(cx, top_y - 14), Vector2(base_x + w + eave, top_y + 2)])
		roof.vertex_colors = PackedColorArray([roof_col.darkened(0.16), roof_col.lightened(0.18), roof_col.darkened(0.2)])
	roof.z_index = z + 2
	add_child(roof)
	# Eave shadow on the wall
	var eaveshadow := ColorRect.new()
	eaveshadow.position = Vector2(base_x + 1, top_y)
	eaveshadow.size = Vector2(w - 2, 2)
	eaveshadow.color = Color(0.0, 0.0, 0.0, 0.22)
	eaveshadow.z_index = z + 1
	add_child(eaveshadow)
	# Door: frame + inset panel + knob + stoop
	var dw := 13.0
	var dh := 18.0
	var dx := cx - dw * 0.5
	var dframe := ColorRect.new()
	dframe.position = Vector2(dx - 1, ground_y - 5 - dh)
	dframe.size = Vector2(dw + 2, dh)
	dframe.color = wall_col.darkened(0.45)
	dframe.z_index = z + 1
	add_child(dframe)
	var door := ColorRect.new()
	door.position = Vector2(dx, ground_y - 5 - dh + 1)
	door.size = Vector2(dw, dh - 1)
	door.color = Color(0.30, 0.21, 0.13)
	door.z_index = z + 1
	add_child(door)
	for pyi in range(2):
		var panel := ColorRect.new()
		panel.position = Vector2(dx + 2, ground_y - 5 - dh + 3 + pyi * 8)
		panel.size = Vector2(dw - 4, 6)
		panel.color = Color(0.24, 0.16, 0.10)
		panel.z_index = z + 1
		add_child(panel)
	var knob := ColorRect.new()
	knob.position = Vector2(dx + dw - 3, ground_y - 5 - dh * 0.5)
	knob.size = Vector2(2, 2)
	knob.color = Color(0.85, 0.7, 0.3)
	knob.z_index = z + 2
	add_child(knob)
	var stoop := ColorRect.new()
	stoop.position = Vector2(dx - 2, ground_y - 6)
	stoop.size = Vector2(dw + 4, 2)
	stoop.color = Color(0.30, 0.27, 0.24)
	stoop.z_index = z + 1
	add_child(stoop)
	# Window: framed warm glow (blooms at night) + mullion + shutters + light pool
	var wx := base_x + w - 14.0
	var wy := top_y + 8.0
	var wframe := ColorRect.new()
	wframe.position = Vector2(wx - 1, wy - 1)
	wframe.size = Vector2(11, 11)
	wframe.color = wall_col.darkened(0.4)
	wframe.z_index = z + 1
	add_child(wframe)
	var glass := ColorRect.new()
	glass.position = Vector2(wx, wy)
	glass.size = Vector2(9, 9)
	var glass_day := Color(0.34, 0.42, 0.50, 0.95)  # cool reflective glass by day
	glass.color = glass_day
	glass.z_index = z + 1
	add_child(glass)
	glow_rects.append({"node": glass, "day": glass_day, "night": world._emit(Color(1.0, 0.82, 0.46, 0.95), 1.5)})
	var mh := ColorRect.new()
	mh.position = Vector2(wx, wy + 4)
	mh.size = Vector2(9, 1)
	mh.color = wall_col.darkened(0.4)
	mh.z_index = z + 2
	add_child(mh)
	var mv := ColorRect.new()
	mv.position = Vector2(wx + 4, wy)
	mv.size = Vector2(1, 9)
	mv.color = wall_col.darkened(0.4)
	mv.z_index = z + 2
	add_child(mv)
	for sxoff in [-3.0, 9.0]:
		var shutter := ColorRect.new()
		shutter.position = Vector2(wx + sxoff, wy - 1)
		shutter.size = Vector2(3, 11)
		shutter.color = roof_col.darkened(0.1)
		shutter.z_index = z + 1
		add_child(shutter)
	var winlight := PointLight2D.new()
	winlight.position = Vector2(wx + 4, wy + 4)
	winlight.color = Color(1.0, 0.8, 0.5)
	winlight.energy = 0.0
	winlight.blend_mode = PointLight2D.BLEND_MODE_ADD
	winlight.texture = world._make_light_texture()
	winlight.texture_scale = 0.5
	add_child(winlight)
	glow_point_lights.append({"node": winlight, "energy": 0.5})
	# Moss patch at the base + a climbing vine (weathering)
	var moss := Polygon2D.new()
	moss.polygon = PackedVector2Array([
		Vector2(base_x + 2, ground_y - 5), Vector2(base_x + 10, ground_y - 5),
		Vector2(base_x + 8, ground_y - 11), Vector2(base_x + 3, ground_y - 9)])
	moss.color = Color(0.22, 0.36, 0.16, 0.7)
	moss.z_index = z + 1
	add_child(moss)
	var vine := Line2D.new()
	vine.width = 1.4
	vine.default_color = Color(0.20, 0.38, 0.16, 0.7)
	vine.add_point(Vector2(base_x + 3, ground_y - 5))
	vine.add_point(Vector2(base_x + 5, top_y + h * 0.4))
	vine.add_point(Vector2(base_x + 2, top_y + h * 0.15))
	vine.z_index = z + 1
	add_child(vine)
	# Hanging bracket sign
	if sign_text != "":
		var sbw := minf(w - 6.0, float(sign_text.length()) * 5.0 + 12.0)
		var sby := top_y - 3.0
		var bracket := Line2D.new()
		bracket.width = 1.0
		bracket.default_color = Color(0.12, 0.10, 0.08)
		bracket.add_point(Vector2(cx - sbw * 0.5, sby - 4))
		bracket.add_point(Vector2(cx + sbw * 0.5, sby - 4))
		bracket.z_index = z + 3
		add_child(bracket)
		var board := Polygon2D.new()
		board.polygon = PackedVector2Array([
			Vector2(cx - sbw * 0.5, sby), Vector2(cx + sbw * 0.5, sby),
			Vector2(cx + sbw * 0.5, sby + 11), Vector2(cx - sbw * 0.5, sby + 11)])
		board.vertex_colors = PackedColorArray([Color(0.24, 0.18, 0.11), Color(0.20, 0.15, 0.09), Color(0.14, 0.10, 0.06), Color(0.18, 0.13, 0.08)])
		board.z_index = z + 3
		add_child(board)
		var lbl := Label.new()
		lbl.text = sign_text
		lbl.add_theme_font_size_override("font_size", 6)
		lbl.add_theme_color_override("font_color", sign_col)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.position = Vector2(cx - sbw * 0.5, sby + 1)
		lbl.size = Vector2(sbw, 9)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.z_index = z + 4
		add_child(lbl)

func water_tower(cx: float, ground_y: float) -> void:
	var tank_top: float = ground_y - 88.0
	var tank_bot: float = ground_y - 60.0
	var tw: float = 30.0
	# Legs (splayed) + a cross-brace
	for s in [-1.0, 1.0]:
		var leg := Line2D.new()
		leg.width = 2.0
		leg.default_color = Color(0.28, 0.22, 0.16)
		leg.add_point(Vector2(cx + s * tw * 0.42, tank_bot))
		leg.add_point(Vector2(cx + s * tw * 0.7, ground_y - 2))
		leg.z_index = 2
		add_child(leg)
	var brace := Line2D.new()
	brace.width = 1.0
	brace.default_color = Color(0.26, 0.20, 0.14)
	brace.add_point(Vector2(cx - tw * 0.55, ground_y - 28))
	brace.add_point(Vector2(cx + tw * 0.55, ground_y - 16))
	brace.z_index = 2
	add_child(brace)
	var brace2 := Line2D.new()
	brace2.width = 1.0
	brace2.default_color = Color(0.26, 0.20, 0.14)
	brace2.add_point(Vector2(cx + tw * 0.55, ground_y - 28))
	brace2.add_point(Vector2(cx - tw * 0.55, ground_y - 16))
	brace2.z_index = 2
	add_child(brace2)
	# Tank body
	var tank := Polygon2D.new()
	tank.polygon = PackedVector2Array([
		Vector2(cx - tw * 0.5, tank_top + 4),
		Vector2(cx - tw * 0.5, tank_bot),
		Vector2(cx + tw * 0.5, tank_bot),
		Vector2(cx + tw * 0.5, tank_top + 4),
	])
	tank.color = Color(0.42, 0.44, 0.43)
	tank.z_index = 3
	add_child(tank)
	# Conical roof
	var cone := Polygon2D.new()
	cone.polygon = PackedVector2Array([
		Vector2(cx - tw * 0.56, tank_top + 4),
		Vector2(cx, tank_top - 9),
		Vector2(cx + tw * 0.56, tank_top + 4),
	])
	cone.color = Color(0.30, 0.22, 0.16)
	cone.z_index = 4
	add_child(cone)
	# Rivet band
	var band := ColorRect.new()
	band.position = Vector2(cx - tw * 0.5, (tank_top + tank_bot) * 0.5 + 4.0)
	band.size = Vector2(tw, 2)
	band.color = Color(0.30, 0.33, 0.31)
	band.z_index = 4
	add_child(band)
	# Label
	var lbl := Label.new()
	lbl.text = "WATER"
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", Color(0.86, 0.91, 0.96))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = Vector2(cx - 15, (tank_top + tank_bot) * 0.5 - 9.0)
	lbl.size = Vector2(30, 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 5
	add_child(lbl)
	# Down-pipe / spout (where you offload your haul)
	var pipe := Line2D.new()
	pipe.width = 2.0
	pipe.default_color = Color(0.32, 0.34, 0.32)
	pipe.add_point(Vector2(cx + tw * 0.4, tank_bot))
	pipe.add_point(Vector2(cx + tw * 0.4, ground_y - 9))
	pipe.add_point(Vector2(cx + tw * 0.4 + 7, ground_y - 9))
	pipe.z_index = 3
	add_child(pipe)

func _dropbox(cx: float, ground_y: float) -> void:
	# A weathered, understated mailbox on a post (the secret NA dead-drop).
	# Interaction (SPACE to read; contents track the NA arc) lives in dead_drop.gd.
	var drop := preload("res://scripts/world/dead_drop.gd").new()
	drop.position = Vector2(cx, ground_y)
	drop.z_index = 6
	add_child(drop)
	var post := ColorRect.new()
	post.position = Vector2(cx - 1, ground_y - 15)
	post.size = Vector2(2, 15)
	post.color = Color(0.26, 0.20, 0.14)
	post.z_index = 4
	add_child(post)
	var box := ColorRect.new()
	box.position = Vector2(cx - 6, ground_y - 23)
	box.size = Vector2(12, 8)
	box.color = Color(0.30, 0.34, 0.33)
	box.z_index = 5
	add_child(box)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([
		Vector2(cx - 6, ground_y - 23),
		Vector2(cx - 4, ground_y - 26),
		Vector2(cx + 4, ground_y - 26),
		Vector2(cx + 6, ground_y - 23),
	])
	lid.color = Color(0.25, 0.29, 0.28)
	lid.z_index = 5
	add_child(lid)
	var slot := ColorRect.new()
	slot.position = Vector2(cx - 3, ground_y - 21)
	slot.size = Vector2(6, 1)
	slot.color = Color(0.04, 0.04, 0.04)
	slot.z_index = 6
	add_child(slot)
	var flag := ColorRect.new()
	flag.position = Vector2(cx + 6, ground_y - 23)
	flag.size = Vector2(3, 3)
	flag.color = Color(0.62, 0.22, 0.16)
	flag.z_index = 6
	add_child(flag)

# --- Town props ---
func _lamp_post(x: float, ground_y: float) -> void:
	var post := ColorRect.new()
	post.position = Vector2(x - 1, ground_y - 30)
	post.size = Vector2(2, 30)
	post.color = Color(0.15, 0.12, 0.09)
	post.z_index = 4
	add_child(post)
	var arm := ColorRect.new()
	arm.position = Vector2(x, ground_y - 30)
	arm.size = Vector2(7, 2)
	arm.color = Color(0.15, 0.12, 0.09)
	arm.z_index = 4
	add_child(arm)
	var housing := Polygon2D.new()
	housing.polygon = PackedVector2Array([
		Vector2(x + 3, ground_y - 30), Vector2(x + 10, ground_y - 30),
		Vector2(x + 9, ground_y - 22), Vector2(x + 4, ground_y - 22)])
	housing.color = Color(0.11, 0.09, 0.07)
	housing.z_index = 4
	add_child(housing)
	var flame := ColorRect.new()
	flame.position = Vector2(x + 4.7, ground_y - 28.5)
	flame.size = Vector2(3.5, 5)
	var flame_day := Color(0.30, 0.26, 0.21, 0.9)  # unlit mantle by day
	flame.color = flame_day
	flame.z_index = 4
	add_child(flame)
	glow_rects.append({"node": flame, "day": flame_day, "night": world._emit(Color(1.0, 0.78, 0.4, 0.95), 2.1)})
	var light := PointLight2D.new()
	light.position = Vector2(x + 6.5, ground_y - 26)
	light.color = Color(1.0, 0.82, 0.5)
	light.energy = 0.0
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	light.texture = world._make_light_texture()
	light.texture_scale = 0.9
	add_child(light)
	glow_point_lights.append({"node": light, "energy": 0.7})

func _barrels(x: float, ground_y: float) -> void:
	for i in range(3):
		var bx: float = x + i * 8.0
		var by: float = ground_y - 11.0
		var bw: float = 7.0
		var barrel := Polygon2D.new()
		barrel.polygon = PackedVector2Array([
			Vector2(bx + 0.8, by), Vector2(bx + bw - 0.8, by),
			Vector2(bx + bw, by + 5), Vector2(bx + bw - 0.8, by + 11),
			Vector2(bx + 0.8, by + 11), Vector2(bx, by + 5)])
		var wc := Color(0.42, 0.30, 0.18)
		barrel.vertex_colors = PackedColorArray([
			wc.lightened(0.12), wc.darkened(0.04), wc.darkened(0.2),
			wc.darkened(0.24), wc.darkened(0.12), wc.lightened(0.04)])
		barrel.z_index = 4
		add_child(barrel)
		for byo in [3.0, 8.0]:
			var band := ColorRect.new()
			band.position = Vector2(bx, by + byo)
			band.size = Vector2(bw, 1)
			band.color = Color(0.20, 0.16, 0.10)
			band.z_index = 5
			add_child(band)

func _crates(x: float, ground_y: float) -> void:
	var sizes: Array = [Vector2(10, 10), Vector2(8, 8), Vector2(9, 9)]
	var offsets: Array = [Vector2(0, 0), Vector2(11, 2), Vector2(4, -10)]
	for i in range(3):
		var s: Vector2 = sizes[i]
		var o: Vector2 = offsets[i]
		var cx0: float = x + o.x
		var cy0: float = ground_y - s.y + o.y
		var crate := Polygon2D.new()
		crate.polygon = PackedVector2Array([
			Vector2(cx0, cy0), Vector2(cx0 + s.x, cy0),
			Vector2(cx0 + s.x, cy0 + s.y), Vector2(cx0, cy0 + s.y)])
		var wc := Color(0.40, 0.29, 0.17)
		crate.vertex_colors = PackedColorArray([
			wc.lightened(0.13), wc.darkened(0.03), wc.darkened(0.2), wc.darkened(0.08)])
		crate.z_index = 4
		add_child(crate)
		var d1 := Line2D.new()
		d1.width = 1.0
		d1.default_color = Color(0.24, 0.17, 0.10)
		d1.add_point(Vector2(cx0, cy0))
		d1.add_point(Vector2(cx0 + s.x, cy0 + s.y))
		d1.z_index = 5
		add_child(d1)

func _string_lights(x0: float, x1: float, y: float) -> void:
	# Drooping wire with HDR-blooming bulbs strung along the street (cozy at night).
	var n: int = maxi(int((x1 - x0) / 12.0), 2)
	var wire := Line2D.new()
	wire.width = 1.0
	wire.default_color = Color(0.10, 0.09, 0.08, 0.8)
	var bulbs: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var px: float = lerpf(x0, x1, t)
		var py: float = y + sin(t * PI) * 10.0
		wire.add_point(Vector2(px, py))
		bulbs.append(Vector2(px, py + 2.0))
	wire.z_index = 7
	add_child(wire)
	var warm: Array = [Color(1.0, 0.8, 0.45), Color(1.0, 0.6, 0.4), Color(0.7, 0.9, 1.0), Color(1.0, 0.9, 0.6)]
	for i in range(bulbs.size()):
		var b: Vector2 = bulbs[i]
		var bulb := ColorRect.new()
		bulb.position = Vector2(b.x - 1, b.y)
		bulb.size = Vector2(2, 3)
		var wcol: Color = warm[i % warm.size()]
		var bulb_day := Color(wcol.r * 0.42, wcol.g * 0.42, wcol.b * 0.42, 0.9)  # unlit glass
		bulb.color = bulb_day
		bulb.z_index = 7
		add_child(bulb)
		glow_rects.append({"node": bulb, "day": bulb_day, "night": world._emit(wcol, 2.0)})
