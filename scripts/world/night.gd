extends Node2D
## v3 night: readable blue floor wash + warm lamp-glow pools + moonlit water
## edge, replacing the near-black overworld night (see
## _screenshots/*/v3b_pools_night.png for the old look). Stars/fireflies keep
## their existing data-driven animation in game_world.gd::_process; this
## module only supplies the ambient dressing around them plus per-frame
## intensity via update(t). Gate: game_world.gd::V3_NIGHT. See
## docs/plans/pixel-art-revamp-2026-09-11.md, track 4.

var world: Node2D = null  # game_world.gd instance, set by caller before add_child

const GLOW_TEX: Texture2D = preload("res://assets/art/drainsville/glow_16.png")
const LAMP_TEX: Texture2D = preload("res://assets/art/drainsville/street_lamp.png")

# glow_16.png is a hand-baked PIXEL glow (6 stepped alpha rings on a 32px
# texture, x2 NEAREST like every other art asset) -- correct for the tiny
# firefly/glow-plant cores, but scaled up to lamp/moon size it reads as
# blocky NEAREST-filtered squares, not a light. Lights aren't art (rule 4
# explicitly allows linear filtering there), so lamp/moon glow use a real
# radial gradient at a smooth resolution instead, with LINEAR filtering set
# on just those nodes (the module root stays NEAREST for everything else).
var smooth_glow: GradientTexture2D
var _vfalloff: GradientTexture2D

var _floor_wash: Sprite2D
var _lamps: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _moon_wash: Sprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_smooth_glow_texture()
	_build_vertical_falloff_texture()
	_build_floor_wash()
	_build_moon_wash()
	_build_lamps()
	_build_water_edges()

func _build_smooth_glow_texture() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	smooth_glow = GradientTexture2D.new()
	smooth_glow.gradient = g
	smooth_glow.width = 128
	smooth_glow.height = 128
	smooth_glow.fill = GradientTexture2D.FILL_RADIAL
	smooth_glow.fill_from = Vector2(0.5, 0.5)
	smooth_glow.fill_to = Vector2(1.0, 0.5)

## Vertical top-to-bottom falloff (transparent top, ramping to full over the
## first ~10% of the texture, flat for the rest) for the floor wash below --
## a flat ColorRect there had a hard, dead-straight top edge that read as a
## seam crossing the whole screen at night. width is 1 since the gradient
## doesn't vary horizontally; the sprite is stretched to full world width.
func _build_vertical_falloff_texture() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1)])
	g.offsets = PackedFloat32Array([0.0, 0.10, 1.0])
	_vfalloff = GradientTexture2D.new()
	_vfalloff.gradient = g
	_vfalloff.width = 8
	_vfalloff.height = 256
	_vfalloff.fill = GradientTexture2D.FILL_LINEAR
	_vfalloff.fill_from = Vector2(0.5, 0.0)
	_vfalloff.fill_to = Vector2(0.5, 1.0)

## A soft, moderate cool-white glow that tracks the moon, biasing the sky and
## upper ground slightly brighter on the moon's side of the screen. Kept
## small and shifted up so it doesn't wash out into the underground dirt
## cross-section on the deeper basins.
func _build_moon_wash() -> void:
	_moon_wash = Sprite2D.new()
	_moon_wash.texture = smooth_glow
	_moon_wash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_moon_wash.centered = true
	_moon_wash.scale = Vector2(3.2, 1.4)
	_moon_wash.modulate = Color(0.75, 0.82, 1.0, 0.0)
	_moon_wash.z_index = -2
	var mmat := CanvasItemMaterial.new()
	mmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_moon_wash.material = mmat
	add_child(_moon_wash)

func _last_x() -> float:
	return world.terrain_points[world.terrain_points.size() - 1].x

## A big, cheap, additive blue wash over the ground band so the night floor
## reads as moonlit dirt/water instead of pure black. Alpha ramps with t in
## update(); at day it is fully transparent (== no cost, no visual change).
## Uses the vertical falloff texture instead of a flat rect so the top edge
## fades in over ~50 world units instead of cutting hard across the screen.
func _build_floor_wash() -> void:
	var band_w: float = _last_x() + 500.0
	var band_h: float = 520.0
	_floor_wash = Sprite2D.new()
	_floor_wash.texture = _vfalloff
	_floor_wash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_floor_wash.centered = false
	_floor_wash.scale = Vector2(band_w / _vfalloff.width, band_h / _vfalloff.height)
	_floor_wash.position = Vector2(-250.0, 20.0)
	_floor_wash.modulate = Color(0.16, 0.26, 0.48, 0.0)
	_floor_wash.z_index = -2
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_floor_wash.material = mat
	add_child(_floor_wash)

## Lamp posts strung along the swamp path (outside town, which already has
## its own string lights via town.gd). Each is a sprite + an additive warm
## glow disc (ground "pool") + a warm PointLight2D, same additive-light
## pattern as the existing pool_glow_lights in game_world.gd.
func _build_lamps() -> void:
	var last_x: float = _last_x()
	# Explicit first lamp near the player's spawn/town edge, then steady
	# coverage through the first pools and beyond.
	var xs: Array[float] = [820.0]
	var x: float = 1200.0
	var spacing: float = 420.0
	while x < last_x - 250.0:
		xs.append(x)
		x += spacing
	for lx in xs:
		var ty: float = world._get_terrain_y_at(lx)
		var post := Sprite2D.new()
		post.texture = LAMP_TEX
		post.centered = false
		post.offset = Vector2(-LAMP_TEX.get_width() * 0.5, -LAMP_TEX.get_height())
		post.scale = Vector2(0.5, 0.5)
		post.position = Vector2(lx, ty)
		post.z_index = 2
		add_child(post)
		# Ground "pool" of light: small, flat, and anchored so it mostly sits
		# above the surface line (only a sliver below) -- it must not bleed
		# down into the underground dirt cross-section on sloped terrain.
		var glow := Sprite2D.new()
		glow.texture = smooth_glow
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.centered = true
		glow.modulate = Color(1.0, 0.78, 0.42, 0.0)
		glow.scale = Vector2(0.55, 0.16)
		glow.position = Vector2(lx, ty - 4.0)
		glow.z_index = 1
		var gmat := CanvasItemMaterial.new()
		gmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = gmat
		add_child(glow)
		var light := PointLight2D.new()
		light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		light.position = Vector2(lx, ty - LAMP_TEX.get_height() * 0.42)
		light.color = Color(1.0, 0.80, 0.45)
		light.energy = 0.0
		light.texture = smooth_glow
		light.texture_scale = 1.4
		light.blend_mode = PointLight2D.BLEND_MODE_ADD
		light.z_index = 3
		add_child(light)
		_lamps.append({"glow": glow, "light": light})

## A thin moon-blue shimmer laid on every pool's water surface at night.
func _build_water_edges() -> void:
	for i in range(world.SWAMP_COUNT):
		var edge := ColorRect.new()
		edge.color = Color(0.75, 0.85, 1.0, 0.0)
		edge.z_index = 4
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)
		_edges.append({"node": edge, "swamp": i})

## Called once per frame from game_world.gd::_process (V3_NIGHT guarded),
## t is the 0..1 time-of-day fraction already computed there.
func update(t: float) -> void:
	var night_alpha: float = 0.0
	if t > 0.62:
		night_alpha = clampf((t - 0.62) / 0.08, 0.0, 1.0)
	elif t < 0.15:
		night_alpha = 1.0
	elif t < 0.22:
		night_alpha = clampf(1.0 - (t - 0.15) / 0.07, 0.0, 1.0)

	_floor_wash.modulate.a = night_alpha * 0.85

	if world.moon:
		_moon_wash.position = Vector2(world.moon.position.x, world.moon.position.y + 30.0)
		_moon_wash.modulate.a = night_alpha * 0.30

	for lp in _lamps:
		var pulse: float = 0.9 + sin(world.wave_time * 1.3) * 0.1
		lp["glow"].modulate.a = night_alpha * 0.75 * pulse
		lp["light"].energy = night_alpha * 1.4 * pulse

	for ed in _edges:
		var swamp_i: int = ed["swamp"]
		var fill: float = GameManager.get_swamp_fill_fraction(swamp_i)
		var node: ColorRect = ed["node"]
		if fill < 0.02:
			node.visible = false
			continue
		node.visible = true
		var water_y: float = world._get_pool_water_y(swamp_i)
		var left_x: float = world._find_water_left_x(swamp_i, water_y)
		var right_x: float = world._find_water_right_x(swamp_i, water_y)
		var shimmer: float = 0.5 + sin(world.wave_time * 1.6 + float(swamp_i)) * 0.2
		node.position = Vector2(left_x, water_y - 0.5)
		node.size = Vector2(maxf(1.0, right_x - left_x), 1.0)
		node.color.a = night_alpha * shimmer * 0.5
