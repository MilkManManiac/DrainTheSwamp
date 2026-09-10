extends Node2D
# Drainsville — sprite-based town (v3 pixel-art direction, 2026-09-10).
# Replaces the procedural Polygon2D town. Same public surface as before so
# game_world.gd is untouched: build(), building(...), water_tower(...),
# update_glow(). Sprites live in assets/art/drainsville (baked from the CC0 /
# CC-BY packs listed in assets/art/LICENSES.md).
#
# Scale: the game's base viewport is 640x360 and the window is 2x that, so a
# sprite at world scale 0.5 renders 1 texture pixel : 1 screen pixel at 720p.
# All pack art is placed at SCALE so pixels stay square and crisp.

const ART := "res://assets/art/drainsville/"
const SCALE := 0.5
const FONT := "res://assets/fonts/Silkscreen-Regular.ttf"

var world: Node2D = null

# Lit-window rects per house texture (texture px, unflipped): x, y, w, h.
const WINDOWS := {
	"house_a": [Rect2(86, 54, 28, 28)],
	"house_c": [Rect2(60, 42, 20, 26), Rect2(180, 40, 20, 26), Rect2(104, 132, 44, 42)],
	"house_b": [Rect2(78, 108, 26, 22), Rect2(145, 106, 26, 22), Rect2(78, 190, 26, 40)],
	"shack_a": [Rect2(126, 105, 21, 30)],
}

var glow_rects: Array = []          # kept for API parity (unused by sprites)
var glow_point_lights: Array = []   # [{node: PointLight2D, energy: float}]
var _glow_last: float = -1.0
var _glow_sprites: Array = []       # [{node: CanvasItem, day: Color, night: Color}]

func _ready() -> void:
	# Pack art must never be bilinear-filtered (project default is linear).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func update_glow(glow_t: float) -> void:
	if absf(glow_t - _glow_last) <= 0.01:
		return
	_glow_last = glow_t
	for gl in glow_point_lights:
		(gl["node"] as PointLight2D).energy = (gl["energy"] as float) * glow_t
	for gs in _glow_sprites:
		(gs["node"] as CanvasItem).modulate = (gs["day"] as Color).lerp(gs["night"], glow_t)

func grnd(x: float, fallback: float) -> float:
	var y: float = world._get_terrain_y_at(x)
	return y if y > 0.0 else fallback

# --- sprite helpers -------------------------------------------------------

func _tex(name: String) -> Texture2D:
	return load(ART + name + ".png")

# Bottom-center anchored sprite at world scale.
func _sprite(name: String, x: float, ground_y: float, z: int, flip: bool = false, scale_mul: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.centered = false
	var sc := SCALE * scale_mul
	s.scale = Vector2(sc, sc)
	s.flip_h = flip
	s.position = Vector2(x - s.texture.get_width() * sc * 0.5, ground_y - s.texture.get_height() * sc)
	s.z_index = z
	add_child(s)
	return s

func _lamp_light(x: float, y: float, energy: float, radius: float, col: Color) -> void:
	if world == null or not world.has_method("_make_light_texture"):
		return
	var pl := PointLight2D.new()
	pl.texture = world._make_light_texture()
	pl.texture_scale = radius / 64.0
	pl.color = col
	pl.energy = 0.0
	pl.position = Vector2(x, y)
	pl.z_index = 2
	add_child(pl)
	glow_point_lights.append({"node": pl, "energy": energy})

# --- build --------------------------------------------------------------

func build() -> void:
	var gnd := 136.0
	# Big swamp trees behind the street.
	_sprite("swamp_trees", -420.0, gnd - 2.0, -4)
	_sprite("swamp_trees_m", -60.0, gnd - 2.0, -4)
	_sprite("swamp_trees", 30.0, gnd - 2.0, -4, true)
	# Boardwalk: tiled planks following the terrain, pilings underneath.
	var bw_tex: Texture2D = _tex("boardwalk")
	var step: float = bw_tex.get_width() * SCALE
	var bxf: float = -485.0
	var i := 0
	while bxf < 70.0:
		var bgy: float = grnd(bxf + step * 0.5, gnd)
		var plank := Sprite2D.new()
		plank.texture = bw_tex
		plank.centered = false
		plank.scale = Vector2(SCALE, SCALE)
		plank.position = Vector2(bxf, bgy - 3.0)
		plank.z_index = -1
		add_child(plank)
		if i % 4 == 0:
			_sprite("piling", bxf + 2.0, bgy + 14.0, -2)
		bxf += step
		i += 1
	# Main street buildings (Hardware is placed by game_world at ~-22).
	var buildings: Array = [
		{"x": -130.0, "w": 44.0, "sign": "DINER", "style": 1},
		{"x": -240.0, "w": 40.0, "sign": "PAWN", "style": 2},
		{"x": -345.0, "w": 46.0, "sign": "OUTFITTER", "style": 0},
		{"x": -448.0, "w": 40.0, "sign": "", "style": 3},
	]
	for b in buildings:
		var gy: float = grnd(b["x"] + b["w"] * 0.5, gnd)
		building(b["x"], gy, b["w"], 36.0, Color.WHITE, Color.WHITE, b["sign"], Color.WHITE, b["style"])
	# Street props in the gaps.
	for lx in [-75.0, -185.0, -295.0, -400.0]:
		_lamp_post(lx, grnd(lx, gnd))
	_barrels(-180.0, grnd(-180.0, gnd))
	_crates(-300.0, grnd(-300.0, gnd))
	_string_lights(-130.0, 28.0, gnd - 52.0)
	_string_lights(-345.0, -130.0, gnd - 54.0)
	_string_lights(-465.0, -345.0, gnd - 52.0)
	# Grass tufts along the boardwalk edge.
	var gi := 1
	for gx in [-470.0, -420.0, -370.0, -320.0, -270.0, -210.0, -160.0, -100.0, -50.0, 0.0, 40.0]:
		_sprite("grass_%d" % gi, gx, grnd(gx, gnd) + 1.0, 1)
		gi = gi % 5 + 1
	# Willow at the west edge, foreground.
	_sprite("willow", -500.0, gnd + 8.0, 2)
	# Water tower — east landmark.
	water_tower(55.0, grnd(55.0, gnd))
	# NA dead-drop at the quiet west edge.
	_dropbox(-468.0, grnd(-468.0, gnd))

# style 0: house_a, 1: house_c, 2: house_b (mirrored). w/h/colors are ignored —
# the sprite defines the footprint; base_x + w/2 stays the building's center so
# every existing interaction point (shop door, sell spot) lands where it did.
func building(base_x: float, ground_y: float, w: float, _h: float, _wall_col: Color, _roof_col: Color, sign_text: String, _sign_col: Color, style: int) -> void:
	var cx := base_x + w * 0.5
	var name := "house_a"
	var flip := false
	match style:
		1: name = "house_c"
		2:
			name = "house_b"
			flip = true
		3:
			name = "shack_a"
	var s := _sprite(name, cx, ground_y + 1.0, -2, flip)
	var top_y: float = s.position.y
	_window_glow(s, WINDOWS.get(name, []), flip)
	# Warm window glow at night: a point light on the facade.
	_lamp_light(cx, ground_y - 28.0, 0.9, 70.0, Color(1.0, 0.78, 0.45))
	if sign_text != "":
		# Baked sign (text rendered into the plate at bake time so it stays crisp).
		var baked := "sign_" + sign_text.to_lower()
		if ResourceLoader.exists(ART + baked + ".png"):
			_sprite(baked, cx, ground_y - 60.0, -1)
		else:
			var plate := _sprite("sign_plate", cx, ground_y - 62.0, -1)
			var lbl := Label.new()
			lbl.text = sign_text
			lbl.add_theme_font_override("font", load(FONT))
			lbl.add_theme_font_size_override("font_size", 5)
			lbl.add_theme_color_override("font_color", Color(0.93, 0.82, 0.59))
			lbl.position = Vector2(plate.position.x + 2.0, plate.position.y - 1.0)
			lbl.size = Vector2(28.0, 7.0)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.z_index = -1
			add_child(lbl)

# Additive warm rects over the window panes; black by day (no-op), lit at night.
func _window_glow(s: Sprite2D, rects: Array, flip: bool) -> void:
	var tw: float = s.texture.get_width()
	for r in rects:
		var rx: float = (tw - r.position.x - r.size.x) if flip else r.position.x
		var g := ColorRect.new()
		g.position = s.position + Vector2(rx, r.position.y) * SCALE
		g.size = r.size * SCALE
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = m
		g.color = Color(1.0, 0.72, 0.32)
		g.z_index = -2
		add_child(g)
		_glow_sprites.append({"node": g, "day": Color(0, 0, 0, 1), "night": Color(0.85, 0.6, 0.25, 1)})

func water_tower(cx: float, ground_y: float) -> void:
	_sprite("water_tower", cx, ground_y + 1.0, -2)
	_lamp_light(cx, ground_y - 70.0, 0.5, 60.0, Color(1.0, 0.8, 0.5))

func _dropbox(cx: float, ground_y: float) -> void:
	_sprite("well", cx, ground_y + 1.0, -2)

func _lamp_post(x: float, ground_y: float) -> void:
	_sprite("street_lamp", x, ground_y + 1.0, -1)
	_lamp_light(x, ground_y - 46.0, 1.1, 56.0, Color(1.0, 0.75, 0.4))

func _barrels(x: float, ground_y: float) -> void:
	_sprite("barrel", x, ground_y + 1.0, -1)
	_sprite("barrel", x + 13.0, ground_y + 1.0, -1)

func _crates(x: float, ground_y: float) -> void:
	_sprite("crate_stack", x, ground_y + 1.0, -1)

# Sagging wire with warm bulbs; bulbs are unlit by day and glow at night.
func _string_lights(x0: float, x1: float, y: float) -> void:
	var wire := Line2D.new()
	wire.width = 1.0
	wire.default_color = Color(0.16, 0.12, 0.08)
	wire.z_index = -1
	var n := 16
	for k in range(n + 1):
		var t := float(k) / float(n)
		wire.add_point(Vector2(lerpf(x0, x1, t), y + 9.0 * sin(PI * t)))
	add_child(wire)
	for k in range(1, n, 2):
		var t := float(k) / float(n)
		var bulb := ColorRect.new()
		bulb.size = Vector2(1.5, 2.0)
		bulb.position = Vector2(lerpf(x0, x1, t) - 0.75, y + 9.0 * sin(PI * t))
		bulb.z_index = -1
		add_child(bulb)
		_glow_sprites.append({"node": bulb, "day": Color(0.55, 0.45, 0.3), "night": Color(1.0, 0.72, 0.32) * 1.8})
		bulb.color = Color.WHITE
