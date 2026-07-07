extends Node2D

# Override these in subclass
var cave_id: String = ""
var cave_terrain_points: Array[Vector2] = []
var cave_ceiling_points: Array[Vector2] = []
var crystal_color: Color = Color(0.8, 0.6, 0.2)  # Override in subclass

# Theme colors — override in subclass _init()
var ground_color: Color = Color(0.3, 0.22, 0.12)
var ceiling_color: Color = Color(0.2, 0.15, 0.1)
var wall_color: Color = Color(0.18, 0.12, 0.08)
var rock_mid_color: Color = Color(0.26, 0.18, 0.10)
var rock_sub_color: Color = Color(0.20, 0.14, 0.08)
var rock_inner_ceil_color: Color = Color(0.24, 0.18, 0.12)
# Backdrop fog — the graded haze that fills the void behind everything.
# Leave as the (0,0,0,0) sentinel to auto-derive a biome-appropriate fog from the
# rock/crystal colors; override in a subclass for a hand-tuned biome identity.
var fog_color: Color = Color(0, 0, 0, 0)
# Signature set-piece — one memorable themed vignette per cave. Override in subclass _init.
# Supported: "crates", "mine_cart", "pump", "skeleton", "dead_tree", "pillars", "coral".
var signature: String = ""

# Cave pool definitions — set in subclass _init()
# Each entry: {"x_range": [start_x, end_x], "pool_index": int, "loot_data": {...}}
var cave_pool_defs: Array = []

# Internal state
var player_ref: CharacterBody2D = null
var drip_timer: float = 0.0
var wave_time: float = 0.0
var crystal_lights: Array[PointLight2D] = []
var crystal_phases: Array[float] = []
var light_shafts: Array[Dictionary] = []  # animated god-ray cones {node, base_a, phase, speed}
var dust_motes: Array[Dictionary] = []
var moisture_gleams: Array[Dictionary] = []  # Phase 9B: shimmer pixels on wet walls

# Cave pool runtime references
var cave_pool_refs: Array[Dictionary] = []  # [{water_poly, wall_body, glow_light, loot_ref, detect_area}]

const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const HUD_SCENE = preload("res://scenes/ui/hud.tscn")
const SHOP_SCENE = preload("res://scenes/ui/shop_panel.tscn")
const MENU_SCENE = preload("res://scenes/ui/menu_panel.tscn")
const WATER_SHADER = preload("res://shaders/water.gdshader")
const POST_PROCESS_SHADER = preload("res://shaders/post_process.gdshader")
const ROCK_SHADER = preload("res://shaders/cave_rock.gdshader")

# Post-processing
var cave_post_process_rect: ColorRect = null
var _hdr: bool = false  # Forward+/Mobile: overbright cave elements bloom via HDR glow
var rock_material: ShaderMaterial = null  # shared procedural rock-surface shader
var cave_post_time: float = 0.0

# Cave UI refs
var cave_hud = null
var cave_shop_panel = null
var cave_menu_panel = null

func _ready() -> void:
	_setup_cave()

func _setup_cave() -> void:
	# CanvasModulate — moody but readable. Lifted further so the back wall + parallax
	# layers read as lit rock instead of a flat dark void.
	var modulate := CanvasModulate.new()
	modulate.color = Color(0.66, 0.68, 0.75)
	add_child(modulate)

	_setup_cave_hdr()
	_build_rock_material()
	_build_fog_backdrop()
	_build_back_wall()
	_build_floor()
	_build_ceiling()
	_build_walls()
	_build_rock_layers()
	_build_stalactites()
	_build_stalagmites()
	_build_crystals()
	_build_midground_clutter()
	_build_signature()
	_build_moss_lichen()
	_build_cave_pools()
	_build_cracks()
	_build_roots_cobwebs()
	_build_dust_motes()
	_build_moisture_gleams()
	_build_light_shafts()
	_build_parallax_bg()
	_build_ambient_fill_lights()
	_build_foreground_silhouettes()
	_build_exit_zone()
	_build_exit_glow()
	_spawn_player()
	_setup_camera()
	_setup_loot_and_lore()
	_setup_cave_ui()
	_build_cave_post_processing()

	# Connect cave pool signals
	GameManager.cave_pool_level_changed.connect(_on_cave_pool_level_changed)
	GameManager.cave_pool_completed.connect(_on_cave_pool_completed)

	_setup_debug_shot()

# Dev: when launched with DTS_SHOT=<path>, save the rendered viewport every 2s (or
# DTS_SHOT_INTERVAL). DTS_ZOOM overrides camera zoom. Inert without DTS_SHOT.
func _setup_debug_shot() -> void:
	var sp: String = OS.get_environment("DTS_SHOT")
	if sp == "":
		return
	var zoomv: String = OS.get_environment("DTS_ZOOM")
	if zoomv != "":
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam:
			var z: float = zoomv.to_float()
			cam.zoom = Vector2(z, z)
	var iv: String = OS.get_environment("DTS_SHOT_INTERVAL")
	var wait: float = iv.to_float() if iv != "" else 2.0
	if wait <= 0.0:
		wait = 2.0
	var st := Timer.new()
	st.wait_time = wait
	st.autostart = true
	st.timeout.connect(func() -> void:
		var tex: ViewportTexture = get_viewport().get_texture()
		if tex:
			var img: Image = tex.get_image()
			if img:
				# HDR-2D viewports return LINEAR data — convert or captures look dark.
				if get_viewport().use_hdr_2d:
					img.linear_to_srgb()
				img.save_png(sp))
	add_child(st)

# --- HDR-2D glow (Forward+/Mobile) so crystals/water/shafts bloom ---
func _setup_cave_hdr() -> void:
	if RenderingServer.get_rendering_device() == null:
		return
	_hdr = true
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 1.15
	env.glow_strength = 1.2
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.set_glow_level(1, 0.8)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.85)
	env.set_glow_level(4, 0.45)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# Push a color overbright (>1.0) so it blooms; pass-through on GL compat.
# Shared procedural rock-surface material — gives every big polygon real relief,
# strata, and crack seams instead of a flat 2-stop gradient.
func _build_rock_material() -> void:
	rock_material = ShaderMaterial.new()
	rock_material.shader = ROCK_SHADER
	rock_material.set_shader_parameter("surf_scale", 2.4)
	rock_material.set_shader_parameter("relief_strength", 0.6)
	rock_material.set_shader_parameter("crack_strength", 0.42)
	rock_material.set_shader_parameter("crack_scale", 1.8)
	rock_material.set_shader_parameter("strata_strength", 0.12)
	rock_material.set_shader_parameter("mottle_strength", 0.10)
	rock_material.set_shader_parameter("emit_boost", 2.0 if _hdr else 1.0)

func _emit(c: Color, boost: float) -> Color:
	if not _hdr:
		return c
	return Color(c.r * boost, c.g * boost, c.b * boost, c.a)

# --- Radial soft-light gradient texture (shared helper) ---
func _make_radial_light_texture() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(0, 0, 0, 0))
	tex.gradient = grad
	return tex

# --- Vertical per-vertex gradient for Polygon2D depth shading ---
func _vertical_gradient_colors(pts: PackedVector2Array, top_col: Color, bottom_col: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	if pts.size() == 0:
		return colors
	var min_y: float = pts[0].y
	var max_y: float = pts[0].y
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var span: float = maxf(max_y - min_y, 1.0)
	for p in pts:
		var t: float = clampf((p.y - min_y) / span, 0.0, 1.0)
		colors.append(top_col.lerp(bottom_col, t))
	return colors

# --- Ambient fill lights (lift the void, add depth) ---
func _build_ambient_fill_lights() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var span: float = right_x - left_x
	var num_fills: int = clampi(int(span / 240.0) + 2, 3, 6)
	var fog: Dictionary = _fog_palette()
	for i in range(num_fills):
		var t: float = (float(i) + 0.5) / float(num_fills)
		var fx: float = lerpf(left_x + 40, right_x - 40, t)
		var ceil_y: float = _get_cave_ceiling_y_at(fx)
		var floor_y: float = _get_cave_terrain_y_at(fx)
		var fill_light := PointLight2D.new()
		fill_light.position = Vector2(fx, lerpf(ceil_y, floor_y, 0.5))
		# Fill tinted toward the biome glow so the back wall reads as lit rock, not gray
		fill_light.color = (fog["fill"] as Color)
		fill_light.blend_mode = PointLight2D.BLEND_MODE_ADD
		fill_light.energy = 1.2
		fill_light.shadow_enabled = false
		fill_light.texture = _make_radial_light_texture()
		fill_light.texture_scale = randf_range(2.6, 3.4)
		fill_light.z_index = -2
		add_child(fill_light)

# --- Post-Processing overlay (mirror overworld) ---
func _build_cave_post_processing() -> void:
	var pp_layer := CanvasLayer.new()
	pp_layer.layer = 90
	add_child(pp_layer)
	cave_post_process_rect = ColorRect.new()
	cave_post_process_rect.anchor_right = 1.0
	cave_post_process_rect.anchor_bottom = 1.0
	cave_post_process_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = POST_PROCESS_SHADER
	mat.set_shader_parameter("vignette_strength", 0.14)
	# Was "bloom_strength" (not a real uniform) — fixed. Real HDR glow handles bloom on
	# desktop; fall back to the shader's single-pass bloom on GL Compatibility (web).
	mat.set_shader_parameter("bloom_threshold", 0.6)
	mat.set_shader_parameter("bloom_intensity", 0.0 if _hdr else 0.7)
	mat.set_shader_parameter("bloom_radius", 3.0)
	mat.set_shader_parameter("saturation", 1.22)
	mat.set_shader_parameter("chromatic_aberration", 0.4)
	mat.set_shader_parameter("film_grain_strength", 0.04)
	mat.set_shader_parameter("dither_levels", 14.0)
	mat.set_shader_parameter("dither_strength", 0.4)
	mat.set_shader_parameter("night_factor", 0.0)
	mat.set_shader_parameter("warmth", -0.01)
	mat.set_shader_parameter("time", 0.0)
	cave_post_process_rect.material = mat
	pp_layer.add_child(cave_post_process_rect)

# --- Floor ---
func _build_floor() -> void:
	if cave_terrain_points.size() < 2:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	var floor_points: PackedVector2Array = PackedVector2Array()
	for pt in cave_terrain_points:
		floor_points.append(pt)
	floor_points.append(Vector2(cave_terrain_points[cave_terrain_points.size() - 1].x, vp_size.y + 20))
	floor_points.append(Vector2(cave_terrain_points[0].x, vp_size.y + 20))

	var floor_poly := Polygon2D.new()
	floor_poly.polygon = floor_points
	floor_poly.color = ground_color
	# Vertical depth gradient: lighter near floor surface, darker deeper
	floor_poly.vertex_colors = _vertical_gradient_colors(floor_points, ground_color.lightened(0.18), ground_color.darkened(0.45))
	floor_poly.material = rock_material
	floor_poly.z_index = 1
	add_child(floor_poly)

	# Floor collision
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for i in range(cave_terrain_points.size() - 1):
		var seg := CollisionShape2D.new()
		var shape := SegmentShape2D.new()
		shape.a = cave_terrain_points[i]
		shape.b = cave_terrain_points[i + 1]
		seg.shape = shape
		body.add_child(seg)

# --- Ceiling ---
func _build_ceiling() -> void:
	if cave_ceiling_points.size() < 2:
		return

	var ceil_points: PackedVector2Array = PackedVector2Array()
	ceil_points.append(Vector2(cave_ceiling_points[0].x, -50))
	for pt in cave_ceiling_points:
		ceil_points.append(pt)
	ceil_points.append(Vector2(cave_ceiling_points[cave_ceiling_points.size() - 1].x, -50))

	var ceil_poly := Polygon2D.new()
	ceil_poly.polygon = ceil_points
	ceil_poly.color = ceiling_color
	# Gradient: darker up high, slightly lighter near the cave-facing contour
	ceil_poly.vertex_colors = _vertical_gradient_colors(ceil_points, ceiling_color.darkened(0.4), ceiling_color.lightened(0.12))
	ceil_poly.material = rock_material
	ceil_poly.z_index = 5
	add_child(ceil_poly)

	# Ceiling collision
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for i in range(cave_ceiling_points.size() - 1):
		var seg := CollisionShape2D.new()
		var shape := SegmentShape2D.new()
		shape.a = cave_ceiling_points[i]
		shape.b = cave_ceiling_points[i + 1]
		seg.shape = shape
		body.add_child(seg)

# --- Walls ---
func _build_walls() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return

	# Walls are 420px thick so any camera position (or overshoot) sees solid rock
	# beyond the cave mouth, never unpainted void.
	var left_x: float = cave_terrain_points[0].x
	var left_wall_pts: PackedVector2Array = PackedVector2Array([
		Vector2(left_x - 420, cave_ceiling_points[0].y - 240),
		Vector2(left_x, cave_ceiling_points[0].y),
		Vector2(left_x, cave_terrain_points[0].y),
		Vector2(left_x - 420, cave_terrain_points[0].y + 240),
	])
	var left_wall := Polygon2D.new()
	left_wall.polygon = left_wall_pts
	left_wall.color = wall_color
	left_wall.vertex_colors = _vertical_gradient_colors(left_wall_pts, wall_color.lightened(0.15), wall_color.darkened(0.35))
	left_wall.material = rock_material
	left_wall.z_index = 4
	add_child(left_wall)

	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var right_wall_pts: PackedVector2Array = PackedVector2Array([
		Vector2(right_x, cave_ceiling_points[cave_ceiling_points.size() - 1].y),
		Vector2(right_x + 420, cave_ceiling_points[cave_ceiling_points.size() - 1].y - 240),
		Vector2(right_x + 420, cave_terrain_points[cave_terrain_points.size() - 1].y + 240),
		Vector2(right_x, cave_terrain_points[cave_terrain_points.size() - 1].y),
	])
	var right_wall := Polygon2D.new()
	right_wall.polygon = right_wall_pts
	right_wall.color = wall_color
	right_wall.vertex_colors = _vertical_gradient_colors(right_wall_pts, wall_color.lightened(0.15), wall_color.darkened(0.35))
	right_wall.material = rock_material
	right_wall.z_index = 4
	add_child(right_wall)

	var wall_body := StaticBody2D.new()
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	add_child(wall_body)

	var left_seg := CollisionShape2D.new()
	var left_shape := SegmentShape2D.new()
	left_shape.a = Vector2(left_x, cave_ceiling_points[0].y)
	left_shape.b = Vector2(left_x, cave_terrain_points[0].y)
	left_seg.shape = left_shape
	wall_body.add_child(left_seg)

	var right_seg := CollisionShape2D.new()
	var right_shape := SegmentShape2D.new()
	right_shape.a = Vector2(right_x, cave_ceiling_points[cave_ceiling_points.size() - 1].y)
	right_shape.b = Vector2(right_x, cave_terrain_points[cave_terrain_points.size() - 1].y)
	right_seg.shape = right_shape
	wall_body.add_child(right_seg)

# --- Rock Layers ---
func _build_rock_layers() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return

	var vp_size: Vector2 = get_viewport_rect().size

	# Floor mid-layer: offset 5px below floor contour
	var mid_pts: PackedVector2Array = PackedVector2Array()
	for pt in cave_terrain_points:
		mid_pts.append(Vector2(pt.x, pt.y + 5))
	mid_pts.append(Vector2(cave_terrain_points[cave_terrain_points.size() - 1].x, vp_size.y + 20))
	mid_pts.append(Vector2(cave_terrain_points[0].x, vp_size.y + 20))
	var mid_poly := Polygon2D.new()
	mid_poly.polygon = mid_pts
	mid_poly.color = rock_mid_color
	mid_poly.vertex_colors = _vertical_gradient_colors(mid_pts, rock_mid_color.lightened(0.12), rock_mid_color.darkened(0.4))
	mid_poly.material = rock_material
	mid_poly.z_index = 0
	add_child(mid_poly)

	# Floor sub-layer: offset 14px below
	var sub_pts: PackedVector2Array = PackedVector2Array()
	for pt in cave_terrain_points:
		sub_pts.append(Vector2(pt.x, pt.y + 14))
	sub_pts.append(Vector2(cave_terrain_points[cave_terrain_points.size() - 1].x, vp_size.y + 20))
	sub_pts.append(Vector2(cave_terrain_points[0].x, vp_size.y + 20))
	var sub_poly := Polygon2D.new()
	sub_poly.polygon = sub_pts
	sub_poly.color = rock_sub_color
	sub_poly.vertex_colors = _vertical_gradient_colors(sub_pts, rock_sub_color.lightened(0.1), rock_sub_color.darkened(0.45))
	sub_poly.z_index = -1
	add_child(sub_poly)

	# Floor stone patches
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	for i in range(randi_range(8, 12)):
		var px: float = randf_range(left_x + 20, right_x - 20)
		var py: float = _get_cave_terrain_y_at(px)
		var patch := ColorRect.new()
		patch.size = Vector2(randf_range(8, 16), randf_range(2, 3))
		patch.position = Vector2(px - patch.size.x * 0.5, py + randf_range(2, 8))
		patch.color = ground_color.lightened(0.15)
		patch.color.a = 0.5
		patch.z_index = 0
		add_child(patch)

	# Ceiling inner-layer
	var ceil_inner_pts: PackedVector2Array = PackedVector2Array()
	ceil_inner_pts.append(Vector2(cave_ceiling_points[0].x, -50))
	for pt in cave_ceiling_points:
		ceil_inner_pts.append(Vector2(pt.x, pt.y + 4))
	ceil_inner_pts.append(Vector2(cave_ceiling_points[cave_ceiling_points.size() - 1].x, -50))
	var ceil_inner := Polygon2D.new()
	ceil_inner.polygon = ceil_inner_pts
	ceil_inner.color = rock_inner_ceil_color
	ceil_inner.vertex_colors = _vertical_gradient_colors(ceil_inner_pts, rock_inner_ceil_color.darkened(0.35), rock_inner_ceil_color.lightened(0.1))
	ceil_inner.material = rock_material
	ceil_inner.z_index = 4
	add_child(ceil_inner)

	# Dirt specks along floor
	for i in range(randi_range(30, 50)):
		var sx: float = randf_range(left_x + 10, right_x - 10)
		var sy: float = _get_cave_terrain_y_at(sx) + randf_range(-1, 2)
		var speck := ColorRect.new()
		speck.size = Vector2(randf_range(1, 2), randf_range(1, 2))
		speck.position = Vector2(sx, sy)
		speck.color = Color(
			randf_range(ground_color.r - 0.05, ground_color.r + 0.08),
			randf_range(ground_color.g - 0.04, ground_color.g + 0.06),
			randf_range(ground_color.b - 0.02, ground_color.b + 0.04),
			randf_range(0.3, 0.6)
		)
		speck.z_index = 1
		add_child(speck)

# --- Stalactites (Polygon2D triangles) ---
func _build_stalactites() -> void:
	for i in range(cave_ceiling_points.size()):
		if randf() < 0.5:
			var pt: Vector2 = cave_ceiling_points[i]
			var is_large: bool = randf() < 0.1
			var w: float = randf_range(6, 10) if is_large else randf_range(3, 8)
			var h: float = randf_range(20, 35) if is_large else randf_range(8, 24)
			var tri := Polygon2D.new()
			tri.polygon = PackedVector2Array([
				Vector2(-w * 0.5, 0),
				Vector2(w * 0.5, 0),
				Vector2(randf_range(-1, 1), h),
			])
			tri.position = pt
			tri.color = ceiling_color.lightened(randf_range(0.05, 0.15))
			tri.z_index = 4
			add_child(tri)

# --- Stalagmites (floor triangles) ---
func _build_stalagmites() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	for i in range(randi_range(10, 15)):
		var sx: float = randf_range(left_x + 40, right_x - 20)
		var sy: float = _get_cave_terrain_y_at(sx)
		var w: float = randf_range(3, 7)
		var h: float = randf_range(6, 18)
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([
			Vector2(-w * 0.5, 0),
			Vector2(w * 0.5, 0),
			Vector2(randf_range(-1, 1), -h),
		])
		tri.position = Vector2(sx, sy)
		tri.color = ground_color.lightened(randf_range(0.02, 0.12))
		tri.z_index = 2
		add_child(tri)

# --- Glowing Crystals ---
func _build_crystals() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var num_clusters: int = randi_range(8, 13)
	for i in range(num_clusters):
		var on_ceiling: bool = randf() < 0.3
		var cx: float = randf_range(left_x + 60, right_x - 40)
		var cy: float
		if on_ceiling:
			cy = _get_cave_ceiling_y_at(cx) + randf_range(2, 6)
		else:
			cy = _get_cave_terrain_y_at(cx)

		# 2-4 parallelogram crystals per cluster
		var num_crystals: int = randi_range(2, 4)
		for j in range(num_crystals):
			var cw: float = randf_range(3, 7)
			var ch: float = randf_range(9, 20)
			var skew: float = randf_range(-2, 2)
			var offset_x: float = randf_range(-6, 6)
			var crystal := Polygon2D.new()
			var tip_y: float = ch if on_ceiling else -ch
			crystal.polygon = PackedVector2Array([
				Vector2(offset_x, 0),
				Vector2(offset_x + cw, 0),
				Vector2(offset_x + cw + skew, tip_y),
				Vector2(offset_x + skew, tip_y),
			])
			crystal.position = Vector2(cx, cy)
			crystal.color = crystal_color.lightened(randf_range(-0.1, 0.2))
			# Faceted look: bright tip, dark base via vertex colors
			var base_col: Color = crystal_color.darkened(0.35)
			var tip_col: Color = crystal_color.lightened(0.5)
			crystal.vertex_colors = PackedColorArray([base_col, base_col, tip_col, tip_col])
			crystal.z_index = 3
			add_child(crystal)

			# Bright inner core (the bloom in step 1 makes this glow)
			var core := Polygon2D.new()
			var core_inset: float = cw * 0.28
			core.polygon = PackedVector2Array([
				Vector2(offset_x + core_inset, 0),
				Vector2(offset_x + cw - core_inset, 0),
				Vector2(offset_x + cw + skew - core_inset, tip_y * 0.92),
				Vector2(offset_x + skew + core_inset, tip_y * 0.92),
			])
			core.position = Vector2(cx, cy)
			core.color = _emit(crystal_color.lightened(0.65), 1.7)
			var hot: Color = _emit(crystal_color.lightened(0.85), 1.9)
			hot.a = 0.9
			var warm_base: Color = _emit(crystal_color.lightened(0.4), 1.5)
			core.vertex_colors = PackedColorArray([warm_base, warm_base, hot, hot])
			core.z_index = 3
			add_child(core)

		# PointLight2D per cluster
		var light := PointLight2D.new()
		light.position = Vector2(cx, cy + (6 if on_ceiling else -6))
		light.color = crystal_color
		light.blend_mode = PointLight2D.BLEND_MODE_ADD
		light.energy = randf_range(0.95, 1.55)
		light.shadow_enabled = false
		var gradient := GradientTexture2D.new()
		gradient.width = 128
		gradient.height = 128
		gradient.fill = GradientTexture2D.FILL_RADIAL
		gradient.fill_from = Vector2(0.5, 0.5)
		gradient.fill_to = Vector2(0.5, 0.0)
		var grad := Gradient.new()
		grad.set_offset(0, 0.0)
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_offset(1, 1.0)
		grad.set_color(1, Color(0, 0, 0, 0))
		gradient.gradient = grad
		light.texture = gradient
		light.texture_scale = randf_range(0.6, 1.0)
		add_child(light)
		crystal_lights.append(light)
		crystal_phases.append(randf() * TAU)

# --- Moss & Lichen ---
func _build_moss_lichen() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x

	# Wall moss patches
	for i in range(randi_range(6, 10)):
		var mx: float = randf_range(left_x + 10, right_x - 10)
		var on_ceil: bool = randf() < 0.4
		var my: float
		if on_ceil:
			my = _get_cave_ceiling_y_at(mx) + randf_range(1, 5)
		else:
			my = _get_cave_terrain_y_at(mx) - randf_range(1, 4)
		var moss := ColorRect.new()
		moss.size = Vector2(randf_range(4, 10), randf_range(3, 6))
		moss.position = Vector2(mx - moss.size.x * 0.5, my)
		moss.color = Color(0.15, 0.32, 0.12, 0.5)
		moss.z_index = 2
		add_child(moss)

	# Ceiling moss with tendrils
	for i in range(randi_range(4, 8)):
		var mx: float = randf_range(left_x + 30, right_x - 30)
		var my: float = _get_cave_ceiling_y_at(mx)
		var moss := ColorRect.new()
		moss.size = Vector2(randf_range(5, 10), randf_range(3, 5))
		moss.position = Vector2(mx, my)
		moss.color = Color(0.12, 0.28, 0.10, 0.45)
		moss.z_index = 5
		add_child(moss)
		# Hanging tendrils
		for t in range(randi_range(1, 2)):
			var tendril := Line2D.new()
			tendril.width = 1.0
			tendril.default_color = Color(0.14, 0.30, 0.12, 0.4)
			var tx: float = mx + randf_range(1, moss.size.x - 1)
			tendril.add_point(Vector2(tx, my + moss.size.y))
			tendril.add_point(Vector2(tx + randf_range(-2, 2), my + moss.size.y + randf_range(4, 10)))
			tendril.z_index = 5
			add_child(tendril)

# --- Cave Pools (barrier pools that block progression) ---
func _build_cave_pools() -> void:
	if cave_pool_defs.size() == 0:
		# No pool defs — build decorative puddles like before
		_build_decorative_puddles()
		return

	for pd in cave_pool_defs:
		var pool_index: int = pd["pool_index"]
		var x_start: float = pd["x_range"][0]
		var x_end: float = pd["x_range"][1]

		# Find the valley geometry in x_range
		var valley_min_y: float = -INF
		var valley_min_x: float = (x_start + x_end) * 0.5
		# Find the overflow_y: highest terrain at edges of x_range
		var left_edge_y: float = _get_cave_terrain_y_at(x_start)
		var right_edge_y: float = _get_cave_terrain_y_at(x_end)
		var overflow_y: float = minf(left_edge_y, right_edge_y)

		# Find valley floor (deepest point in range)
		for pt in cave_terrain_points:
			if pt.x >= x_start and pt.x <= x_end:
				if pt.y > valley_min_y:
					valley_min_y = pt.y
					valley_min_x = pt.x

		# Water surface Y = lerp between overflow_y (full) and valley_min_y (empty)
		var fill: float = GameManager.get_cave_pool_fill_fraction(cave_id, pool_index)
		var completed: bool = GameManager.is_cave_pool_completed(cave_id, pool_index)
		var water_y: float = lerpf(valley_min_y, overflow_y, fill) if not completed else valley_min_y

		# Build water polygon: terrain contour below water_y
		var water_poly := Polygon2D.new()
		water_poly.z_index = 2
		water_poly.color = Color(0.15, 0.30, 0.50, 0.78)
		# Stylized water shader (cave-tuned)
		var wmat := ShaderMaterial.new()
		wmat.shader = WATER_SHADER
		wmat.set_shader_parameter("wave_strength", 0.7)
		wmat.set_shader_parameter("specular_intensity", 0.2)
		wmat.set_shader_parameter("choppiness", 0.3)
		wmat.set_shader_parameter("turbidity", 0.5)
		wmat.set_shader_parameter("foam_density", 0.5)
		wmat.set_shader_parameter("daytime", 0.0)
		wmat.set_shader_parameter("sky_color", Vector3(0.20, 0.34, 0.46))
		wmat.set_shader_parameter("time", 0.0)
		wmat.set_shader_parameter("hdr_boost", 2.4 if _hdr else 1.0)
		water_poly.material = wmat
		_update_water_poly_shape(water_poly, x_start, x_end, water_y)
		water_poly.visible = not completed
		add_child(water_poly)

		# Water highlight line on surface
		var water_hl := ColorRect.new()
		water_hl.size = Vector2(x_end - x_start - 4, 1)
		water_hl.position = Vector2(x_start + 2, water_y)
		water_hl.color = _emit(Color(0.42, 0.62, 0.86, 0.5), 1.7)
		water_hl.z_index = 2
		water_hl.visible = not completed
		add_child(water_hl)

		# Wall body (blocks player at left water edge)
		var wall_body := StaticBody2D.new()
		wall_body.collision_layer = 1
		wall_body.collision_mask = 0
		var wall_x: float = _find_left_water_edge_x(x_start, x_end, water_y) if not completed else x_start
		var wall_h: float = overflow_y - _get_cave_ceiling_y_at(wall_x) + 20
		var wall_coll := CollisionShape2D.new()
		var wall_shape := RectangleShape2D.new()
		wall_shape.size = Vector2(8, wall_h)
		wall_coll.shape = wall_shape
		wall_coll.position = Vector2(wall_x, overflow_y - wall_h * 0.5)
		wall_body.add_child(wall_coll)
		wall_body.set_meta("disabled", completed)
		if completed:
			wall_coll.set_deferred("disabled", true)
		add_child(wall_body)

		# Glow light under water
		var glow_light := PointLight2D.new()
		glow_light.position = Vector2(valley_min_x, valley_min_y - 5)
		glow_light.color = crystal_color
		glow_light.blend_mode = PointLight2D.BLEND_MODE_ADD
		glow_light.energy = 0.8 * fill
		glow_light.shadow_enabled = false
		var glow_grad_tex := GradientTexture2D.new()
		glow_grad_tex.width = 128
		glow_grad_tex.height = 128
		glow_grad_tex.fill = GradientTexture2D.FILL_RADIAL
		glow_grad_tex.fill_from = Vector2(0.5, 0.5)
		glow_grad_tex.fill_to = Vector2(0.5, 0.0)
		var glow_grad := Gradient.new()
		glow_grad.set_offset(0, 0.0)
		glow_grad.set_color(0, Color(1, 1, 1, 1))
		glow_grad.set_offset(1, 1.0)
		glow_grad.set_color(1, Color(0, 0, 0, 0))
		glow_grad_tex.gradient = glow_grad
		glow_light.texture = glow_grad_tex
		glow_light.texture_scale = 0.7
		glow_light.visible = not completed
		add_child(glow_light)

		# Soft surface glow over the pool (cool, additive)
		var surface_glow := PointLight2D.new()
		surface_glow.position = Vector2(valley_min_x, water_y - 4)
		surface_glow.color = Color(0.45, 0.66, 0.82)
		surface_glow.blend_mode = PointLight2D.BLEND_MODE_ADD
		surface_glow.energy = 0.75
		surface_glow.shadow_enabled = false
		surface_glow.texture = _make_radial_light_texture()
		surface_glow.texture_scale = 1.1
		surface_glow.visible = not completed
		add_child(surface_glow)

		# Hidden loot node at valley floor — visible when pool completes
		var loot_ref: Node = null
		if pd.has("loot_data") and pd["loot_data"].size() > 0:
			var ld: Dictionary = pd["loot_data"]
			var loot_node = preload("res://scripts/caves/loot_node.gd").new()
			loot_node.loot_id = ld.get("loot_id", "pool_loot_%d" % pool_index)
			loot_node.cave_id = cave_id
			loot_node.reward_money = ld.get("reward_money", 0.0)
			if ld.has("reward_stat_levels"):
				loot_node.reward_stat_levels = ld["reward_stat_levels"]
			if ld.has("reward_upgrades"):
				loot_node.reward_upgrades = ld["reward_upgrades"]
			if ld.has("reward_tool_unlock"):
				loot_node.reward_tool_unlock = ld["reward_tool_unlock"]
			loot_node.reward_text = ld.get("reward_text", "Found hidden treasure!")
			loot_node.position = Vector2(valley_min_x, valley_min_y)
			loot_node.visible = completed
			add_child(loot_node)
			loot_ref = loot_node

		cave_pool_refs.append({
			"water_poly": water_poly,
			"water_hl": water_hl,
			"wall_body": wall_body,
			"wall_coll": wall_coll,
			"wall_shape": wall_shape,
			"glow_light": glow_light,
			"surface_glow": surface_glow,
			"loot_ref": loot_ref,
			"x_start": x_start,
			"x_end": x_end,
			"overflow_y": overflow_y,
			"valley_min_y": valley_min_y,
			"valley_min_x": valley_min_x,
		})

func _build_decorative_puddles() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	for i in range(randi_range(2, 4)):
		var px: float = randf_range(left_x + 50, right_x - 50)
		var py: float = _get_cave_terrain_y_at(px)
		var pw: float = randf_range(16, 30)
		var ph: float = randf_range(3, 5)
		var pool := ColorRect.new()
		pool.size = Vector2(pw, ph)
		pool.position = Vector2(px - pw * 0.5, py - ph)
		pool.color = Color(0.15, 0.25, 0.35, 0.5)
		pool.z_index = 1
		add_child(pool)
		var hl := ColorRect.new()
		hl.size = Vector2(pw - 2, 1)
		hl.position = Vector2(px - pw * 0.5 + 1, py - ph)
		hl.color = Color(0.3, 0.45, 0.55, 0.3)
		hl.z_index = 1
		add_child(hl)

func _update_water_poly_shape(poly: Polygon2D, x_start: float, x_end: float, water_y: float) -> void:
	# Build water polygon: top is water_y line, bottom traces terrain contour
	var pts: PackedVector2Array = PackedVector2Array()
	# Top-left
	pts.append(Vector2(x_start, water_y))
	# Bottom: trace terrain from left to right
	for pt in cave_terrain_points:
		if pt.x >= x_start and pt.x <= x_end:
			if pt.y > water_y:
				pts.append(Vector2(pt.x, pt.y))
			else:
				pts.append(Vector2(pt.x, water_y))
	# Top-right
	pts.append(Vector2(x_end, water_y))
	if pts.size() >= 3:
		poly.polygon = pts
	else:
		# Fallback: simple rectangle
		pts = PackedVector2Array([
			Vector2(x_start, water_y),
			Vector2(x_start, water_y + 10),
			Vector2(x_end, water_y + 10),
			Vector2(x_end, water_y),
		])
		poly.polygon = pts
	# UVs for the water shader (x normalized across span, y by depth below surface)
	var min_y: float = water_y
	var max_y: float = water_y
	for p in pts:
		max_y = maxf(max_y, p.y)
	var y_range: float = maxf(max_y - min_y, 1.0)
	var x_span: float = maxf(x_end - x_start, 1.0)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2(clampf((p.x - x_start) / x_span, 0.0, 1.0), clampf((p.y - min_y) / y_range, 0.0, 1.0)))
	poly.uv = uvs

func _find_left_water_edge_x(x_start: float, x_end: float, water_y: float) -> float:
	# Find leftmost x where terrain dips below water_y (left shore of pool)
	for i in range(cave_terrain_points.size() - 1):
		var pt_a: Vector2 = cave_terrain_points[i]
		var pt_b: Vector2 = cave_terrain_points[i + 1]
		if pt_b.x < x_start:
			continue
		if pt_a.x > x_end:
			break
		# Terrain goes from above water to below water → left shore
		if pt_a.y <= water_y and pt_b.y >= water_y:
			var t: float = (water_y - pt_a.y) / (pt_b.y - pt_a.y + 0.001)
			return lerpf(pt_a.x, pt_b.x, t)
		# Already below water at this point
		if pt_a.y >= water_y and pt_a.x >= x_start:
			return pt_a.x
	return x_start

func _update_cave_pool_visual(pool_index: int) -> void:
	if pool_index < 0 or pool_index >= cave_pool_refs.size():
		return
	var refs: Dictionary = cave_pool_refs[pool_index]
	var fill: float = GameManager.get_cave_pool_fill_fraction(cave_id, pool_index)
	var completed: bool = GameManager.is_cave_pool_completed(cave_id, pool_index)

	if completed:
		# Hide water, disable wall, reveal loot
		if is_instance_valid(refs["water_poly"]):
			refs["water_poly"].visible = false
		if is_instance_valid(refs["water_hl"]):
			refs["water_hl"].visible = false
		if is_instance_valid(refs["wall_coll"]):
			refs["wall_coll"].set_deferred("disabled", true)
		if is_instance_valid(refs["glow_light"]):
			refs["glow_light"].visible = false
		if refs.has("surface_glow") and is_instance_valid(refs["surface_glow"]):
			refs["surface_glow"].visible = false
		if refs["loot_ref"] != null and is_instance_valid(refs["loot_ref"]):
			refs["loot_ref"].visible = true
		# Sparkle effect
		_spawn_pool_sparkle(refs["valley_min_x"], refs["valley_min_y"])
	else:
		# Update water level
		var water_y: float = lerpf(refs["valley_min_y"], refs["overflow_y"], fill)
		if is_instance_valid(refs["water_poly"]):
			_update_water_poly_shape(refs["water_poly"], refs["x_start"], refs["x_end"], water_y)
			refs["water_poly"].visible = true
		if is_instance_valid(refs["water_hl"]):
			refs["water_hl"].position.y = water_y
			refs["water_hl"].visible = true
		if is_instance_valid(refs["glow_light"]):
			refs["glow_light"].energy = 0.8 * fill
			refs["glow_light"].visible = true
		if refs.has("surface_glow") and is_instance_valid(refs["surface_glow"]):
			refs["surface_glow"].position.y = water_y - 4
			refs["surface_glow"].visible = true
		# Move wall to track left water edge
		if is_instance_valid(refs["wall_coll"]):
			var new_wall_x: float = _find_left_water_edge_x(refs["x_start"], refs["x_end"], water_y)
			var wall_h: float = refs["overflow_y"] - _get_cave_ceiling_y_at(new_wall_x) + 20
			refs["wall_coll"].position = Vector2(new_wall_x, refs["overflow_y"] - wall_h * 0.5)
			refs["wall_shape"].size = Vector2(8, wall_h)

func _spawn_pool_sparkle(sx: float, sy: float) -> void:
	for i in range(8):
		var spark := ColorRect.new()
		spark.size = Vector2(2, 2)
		spark.color = crystal_color.lightened(0.3)
		spark.position = Vector2(sx + randf_range(-20, 20), sy + randf_range(-10, 5))
		spark.z_index = 8
		add_child(spark)
		var tw := create_tween()
		tw.tween_property(spark, "position:y", spark.position.y - randf_range(15, 30), 0.6)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.6)
		tw.tween_callback(spark.queue_free)

func _on_cave_pool_level_changed(changed_cave_id: String, pool_index: int, _fill_fraction: float) -> void:
	if changed_cave_id != cave_id:
		return
	_update_cave_pool_visual(pool_index)

func _on_cave_pool_completed(completed_cave_id: String, pool_index: int) -> void:
	if completed_cave_id != cave_id:
		return
	_update_cave_pool_visual(pool_index)

# --- Cracks & Fissures ---
func _build_cracks() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	for i in range(randi_range(8, 15)):
		var on_floor: bool = randf() < 0.6
		var cx: float = randf_range(left_x + 20, right_x - 20)
		var cy: float
		if on_floor:
			cy = _get_cave_terrain_y_at(cx) + randf_range(-1, 3)
		else:
			cy = _get_cave_ceiling_y_at(cx) + randf_range(0, 4)
		var crack := Line2D.new()
		crack.width = 1.0
		crack.default_color = Color(0.08, 0.06, 0.04, 0.6)
		var num_points: int = randi_range(2, 4)
		var px: float = cx
		var py: float = cy
		for j in range(num_points):
			crack.add_point(Vector2(px, py))
			px += randf_range(-6, 6)
			py += randf_range(-3, 3)
		crack.z_index = 2
		add_child(crack)
		# Branch line
		if randf() < 0.4 and num_points >= 3:
			var branch := Line2D.new()
			branch.width = 1.0
			branch.default_color = Color(0.08, 0.06, 0.04, 0.4)
			var bp: Vector2 = crack.get_point_position(1)
			branch.add_point(bp)
			branch.add_point(bp + Vector2(randf_range(-4, 4), randf_range(-3, 3)))
			branch.z_index = 2
			add_child(branch)

# --- Roots & Cobwebs ---
func _build_roots_cobwebs() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x

	# Roots near entrance (left side)
	for i in range(randi_range(3, 6)):
		var rx: float = randf_range(left_x + 10, left_x + 100)
		var ry: float = _get_cave_ceiling_y_at(rx)
		var root := Line2D.new()
		root.width = randf_range(1.5, 2.0)
		root.default_color = Color(0.3, 0.2, 0.1, 0.6)
		var hang: float = randf_range(10, 25)
		root.add_point(Vector2(rx, ry))
		root.add_point(Vector2(rx + randf_range(-4, 4), ry + hang * 0.5))
		root.add_point(Vector2(rx + randf_range(-6, 6), ry + hang))
		root.z_index = 5
		add_child(root)

	# Cobwebs in corners
	var corners: Array[Vector2] = [
		Vector2(left_x + 5, cave_ceiling_points[0].y + 2),
		Vector2(right_x - 5, cave_ceiling_points[cave_ceiling_points.size() - 1].y + 2),
	]
	if randf() < 0.6:
		corners.append(Vector2(left_x + randf_range(200, 400), _get_cave_ceiling_y_at(left_x + 300) + 2))
	for corner in corners:
		if randf() < 0.6:
			for j in range(randi_range(3, 5)):
				var web := Line2D.new()
				web.width = 1.0
				web.default_color = Color(0.7, 0.7, 0.7, 0.15)
				web.add_point(corner)
				web.add_point(corner + Vector2(randf_range(-12, 12), randf_range(5, 18)))
				web.z_index = 5
				add_child(web)

# --- Dust Motes ---
func _build_dust_motes() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var top_y: float = cave_ceiling_points[0].y
	for pt in cave_ceiling_points:
		if pt.y < top_y:
			top_y = pt.y
	var bottom_y: float = cave_terrain_points[0].y
	for pt in cave_terrain_points:
		if pt.y > bottom_y:
			bottom_y = pt.y
	for i in range(randi_range(26, 36)):
		var mote := ColorRect.new()
		var glowing: bool = randf() < 0.5
		var mote_sz: float = (1.0 if randf() < 0.7 else 2.0) + (1.0 if glowing else 0.0)
		mote.size = Vector2(mote_sz, mote_sz)
		if glowing:
			# Bioluminescent spore — crystal-tinted, overbright so it blooms in the cave air.
			mote.color = _emit(Color(crystal_color.r, crystal_color.g, crystal_color.b, randf_range(0.5, 0.85)), 1.8)
		else:
			mote.color = Color(0.72, 0.66, 0.45, randf_range(0.16, 0.30))
		var mx: float = randf_range(left_x + 20, right_x - 20)
		var my: float = randf_range(top_y + 10, bottom_y - 10)
		mote.position = Vector2(mx, my)
		mote.z_index = 7
		add_child(mote)
		dust_motes.append({
			"node": mote,
			"base_x": mx,
			"base_y": my,
			"speed_x": randf_range(2, 6),
			"phase": randf() * TAU,
			"left_x": left_x + 20,
			"right_x": right_x - 20,
			"top_y": top_y + 10,
			"bottom_y": bottom_y - 10,
		})

# --- Moisture Gleam (Phase 9B) ---
func _build_moisture_gleams() -> void:
	# Shiny pixel flickers on wet cave walls near pools
	if cave_pool_defs.size() == 0:
		return
	for pool_def in cave_pool_defs:
		var px_start: float = pool_def["x_range"][0]
		var px_end: float = pool_def["x_range"][1]
		# Place gleam pixels on walls near each pool
		for _g in range(randi_range(4, 8)):
			var gx: float = randf_range(px_start - 20, px_end + 20)
			# Place on wall (near floor or ceiling)
			var gy: float
			if randf() > 0.5:
				gy = _get_cave_terrain_y_at(gx) - randf_range(2, 15)  # Above floor
			else:
				gy = _get_cave_ceiling_y_at(gx) + randf_range(2, 15)  # Below ceiling
			var gleam := ColorRect.new()
			gleam.size = Vector2(1, 1)
			gleam.color = _emit(Color(1.0, 1.0, 1.0, 0.0), 2.2)
			gleam.position = Vector2(gx, gy)
			gleam.z_index = 8
			add_child(gleam)
			moisture_gleams.append({
				"node": gleam,
				"phase": randf() * TAU,
				"flash_timer": randf_range(2.0, 8.0),
				"flash_interval": randf_range(3.0, 10.0),
			})

# --- Light Shafts from ceiling ---
func _build_light_shafts() -> void:
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	# Fewer shafts in later/deeper caves (by cave order)
	var cave_order: int = GameManager.CAVE_DEFINITIONS.get(cave_id, {}).get("order", 0)
	var num_shafts: int = clampi(3 - cave_order / 3, 1, 3)
	for i in range(num_shafts):
		var sx: float = randf_range(left_x + 80, right_x - 80)
		var ceil_y: float = _get_cave_ceiling_y_at(sx)
		var floor_y: float = _get_cave_terrain_y_at(sx)
		var beam_len: float = (floor_y - ceil_y) * randf_range(0.5, 0.8)
		# God-ray cone: soft translucent additive polygon, wide at the floor
		var top_w: float = randf_range(3, 6)
		var bot_w: float = randf_range(16, 28)
		var drift: float = randf_range(-6, 6)
		var cone := Polygon2D.new()
		cone.polygon = PackedVector2Array([
			Vector2(sx - top_w, ceil_y),
			Vector2(sx + top_w, ceil_y),
			Vector2(sx + drift + bot_w, ceil_y + beam_len),
			Vector2(sx + drift - bot_w, ceil_y + beam_len),
		])
		var ray_col: Color = _emit(Color(0.92, 0.87, 0.72, randf_range(0.06, 0.11)), 1.8)
		var ray_fade: Color = _emit(Color(0.92, 0.87, 0.72, 0.0), 1.8)
		cone.vertex_colors = PackedColorArray([ray_col, ray_col, ray_fade, ray_fade])
		cone.color = Color(1, 1, 1, 1)
		var cone_mat := CanvasItemMaterial.new()
		cone_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		cone.material = cone_mat
		cone.z_index = 6
		add_child(cone)
		light_shafts.append({"node": cone, "phase": randf_range(0.0, TAU), "speed": randf_range(0.4, 0.8)})
		# Light beam Line2D (bright core)
		var beam := Line2D.new()
		beam.width = randf_range(4, 8)
		beam.default_color = _emit(Color(0.9, 0.85, 0.7, randf_range(0.03, 0.06)), 2.2)
		beam.add_point(Vector2(sx, ceil_y))
		beam.add_point(Vector2(sx + randf_range(-3, 3), ceil_y + beam_len))
		beam.z_index = 6
		add_child(beam)
		# Light source at crack
		var shaft_light := PointLight2D.new()
		shaft_light.position = Vector2(sx, ceil_y + 5)
		shaft_light.color = Color(0.9, 0.85, 0.7)
		shaft_light.blend_mode = PointLight2D.BLEND_MODE_ADD
		shaft_light.energy = randf_range(0.3, 0.6)
		shaft_light.shadow_enabled = false
		var sl_tex := GradientTexture2D.new()
		sl_tex.width = 128
		sl_tex.height = 128
		sl_tex.fill = GradientTexture2D.FILL_RADIAL
		sl_tex.fill_from = Vector2(0.5, 0.5)
		sl_tex.fill_to = Vector2(0.5, 0.0)
		var sl_grad := Gradient.new()
		sl_grad.set_offset(0, 0.0)
		sl_grad.set_color(0, Color(1, 1, 1, 1))
		sl_grad.set_offset(1, 1.0)
		sl_grad.set_color(1, Color(0, 0, 0, 0))
		sl_tex.gradient = sl_grad
		shaft_light.texture = sl_tex
		shaft_light.texture_scale = 0.3
		add_child(shaft_light)

# --- Fog palette: derive a biome-appropriate haze from the rock/crystal colors ---
# Returns {top, mid, bottom, fill, accent}. Override `fog_color` in a subclass to
# pin the haze hue; otherwise it's mixed from ceiling/ground/crystal so each cave differs.
func _fog_palette() -> Dictionary:
	var base: Color = fog_color
	if base.a <= 0.0:
		# Auto: cool, desaturated blend of the ceiling rock pulled slightly toward crystal hue
		base = ceiling_color.lerp(crystal_color, 0.18)
		base = base.lerp(Color(0.16, 0.19, 0.27), 0.55)  # push toward a cool cavern blue-gray
	var top: Color = base.darkened(0.35)            # deep haze up high
	var mid: Color = base.lightened(0.55)           # lit band behind the player
	mid = mid.lerp(crystal_color, 0.16)
	var bottom: Color = base.darkened(0.30).lerp(ground_color.darkened(0.2), 0.4)
	var fill: Color = base.lightened(0.35).lerp(crystal_color, 0.22)
	var accent: Color = crystal_color.lightened(0.1)
	return {"top": top, "mid": mid, "bottom": bottom, "fill": fill, "accent": accent}

# --- Back wall: the textured rock face the player stands AGAINST. Fills the interior
# air column (ceiling contour -> floor contour) that was previously unpainted void.
# This is what makes the space behind the player read as solid rock, not open haze.
func _build_back_wall() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return
	# Top edge follows the ceiling contour (dropped slightly so a sliver of fog/parallax
	# shows above it for depth); bottom edge follows the floor contour (reversed).
	var pts := PackedVector2Array()
	for p in cave_ceiling_points:
		pts.append(Vector2(p.x, p.y + 18.0))
	for i in range(cave_terrain_points.size() - 1, -1, -1):
		pts.append(Vector2(cave_terrain_points[i].x, cave_terrain_points[i].y + 4.0))
	var wall := Polygon2D.new()
	wall.polygon = pts
	# Lit rock tone (pulled toward the biome fog so it reads as illuminated, not a
	# black slab) — the relief shader supplies the texture, lighting supplies the mood.
	var fog: Dictionary = _fog_palette()
	var wcol: Color = rock_mid_color.lightened(0.3).lerp(fog["mid"], 0.45)
	wall.color = wcol
	wall.vertex_colors = _vertical_gradient_colors(pts, wcol.darkened(0.22), wcol.lightened(0.2))
	wall.material = rock_material
	wall.z_index = -8
	add_child(wall)

# =====================================================================================
# Midground clutter — real-scale, clustered objects placed at EYE LEVEL so the playable
# space reads as full and lived-in (not an empty floor + wall). Clusters > even scatter;
# density gradient leaves deliberate calm gaps; one glowing focal point per area.
# =====================================================================================
func _build_midground_clutter() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var span: float = right_x - left_x

	# 1) Rock columns/pillars that cross the empty midground — give vertical scale + depth.
	var n_col: int = clampi(int(span / 460.0) + 1, 1, 5)
	for i in range(n_col):
		var cx: float = lerpf(left_x + 70, right_x - 70, (float(i) + randf_range(0.25, 0.75)) / float(n_col))
		_make_rock_column(cx)

	# 2) Boulder clusters hugging the floor (fractal: anchor + shrinking children).
	var n_clust: int = clampi(int(span / 280.0) + 1, 2, 8)
	for i in range(n_clust):
		# Density gradient: skip ~1 in 4 anchors to keep calm negative space.
		if randf() < 0.25:
			continue
		var ax: float = randf_range(left_x + 40, right_x - 40)
		var children: int = randi_range(2, 4)
		for j in range(children):
			var bx: float = ax + randf_range(-46, 46)
			bx = clampf(bx, left_x + 16, right_x - 16)
			var by: float = _get_cave_terrain_y_at(bx)
			var r: float = randf_range(16.0, 46.0) * (1.0 - 0.18 * float(j))
			_make_boulder(Vector2(bx, by + r * 0.35), r)

	# 3) Rubble / scree scatter (smaller second pass for grain).
	for i in range(randi_range(6, 12)):
		var rx: float = randf_range(left_x + 24, right_x - 24)
		_make_rubble(Vector2(rx, _get_cave_terrain_y_at(rx)))

	# 4) Glowing mushroom clusters — cheap HDR focal points on rule-of-thirds-ish spots.
	var n_mush: int = clampi(int(span / 520.0) + 1, 1, 4)
	for i in range(n_mush):
		var mx: float = lerpf(left_x + 90, right_x - 90, (float(i) + 0.5) / float(n_mush) + randf_range(-0.12, 0.12))
		mx = clampf(mx, left_x + 40, right_x - 40)
		_make_mushroom_cluster(Vector2(mx, _get_cave_terrain_y_at(mx)))

	# 5) Hanging roots/vines from the ceiling — break the bare ceiling, add overlap depth.
	for i in range(randi_range(4, 8)):
		var vx: float = randf_range(left_x + 30, right_x - 30)
		_make_hanging_vine(vx, _get_cave_ceiling_y_at(vx))

# A rounded irregular rock blob (textured via the rock shader).
func _make_boulder(center: Vector2, radius: float, base: Color = Color(0, 0, 0, 0)) -> void:
	var col: Color = base if base.a > 0.0 else rock_mid_color.lightened(0.05)
	var pts := PackedVector2Array()
	var sides: int = 9
	for s in range(sides):
		var a: float = TAU * float(s) / float(sides)
		var rr: float = radius * randf_range(0.78, 1.12)
		pts.append(center + Vector2(cos(a) * rr, sin(a) * rr * 0.78))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = col
	poly.vertex_colors = _vertical_gradient_colors(pts, col.lightened(0.18), col.darkened(0.4))
	poly.material = rock_material
	poly.z_index = 2
	add_child(poly)

# Small scree rocks (no shader needed — they're tiny accents).
func _make_rubble(center: Vector2) -> void:
	for i in range(randi_range(2, 4)):
		var r: float = randf_range(3.0, 7.0)
		var p := center + Vector2(randf_range(-14, 14), randf_range(-2, 4))
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			p + Vector2(-r, r * 0.5), p + Vector2(-r * 0.4, -r), p + Vector2(r * 0.7, -r * 0.5), p + Vector2(r, r * 0.5),
		])
		var c: Color = rock_sub_color.lightened(randf_range(0.0, 0.18))
		poly.color = c
		poly.z_index = 2
		add_child(poly)

# A stalagmite/stalactite pair that may join into a full pillar crossing the midground.
func _make_rock_column(x: float) -> void:
	var ceil_y: float = _get_cave_ceiling_y_at(x)
	var floor_y: float = _get_cave_terrain_y_at(x)
	var gap: float = floor_y - ceil_y
	var join: bool = randf() < 0.35 and gap < 170.0
	var w: float = randf_range(10.0, 22.0)
	var col: Color = rock_mid_color.lightened(0.02)
	if join:
		# Full pillar, slightly waisted in the middle.
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(x - w, ceil_y), Vector2(x + w, ceil_y),
			Vector2(x + w * 0.55, (ceil_y + floor_y) * 0.5),
			Vector2(x + w, floor_y), Vector2(x - w, floor_y),
			Vector2(x - w * 0.55, (ceil_y + floor_y) * 0.5),
		])
		poly.color = col
		poly.vertex_colors = _vertical_gradient_colors(poly.polygon, col.lightened(0.16), col.darkened(0.34))
		poly.material = rock_material
		poly.z_index = 3
		add_child(poly)
	else:
		# Tall stalagmite from the floor.
		var sh: float = gap * randf_range(0.4, 0.72)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(x - w, floor_y + 6), Vector2(x - w * 0.3, floor_y - sh * 0.7),
			Vector2(x, floor_y - sh), Vector2(x + w * 0.3, floor_y - sh * 0.65), Vector2(x + w, floor_y + 6),
		])
		poly.color = col
		poly.vertex_colors = _vertical_gradient_colors(poly.polygon, col.darkened(0.3), col.lightened(0.14))
		poly.material = rock_material
		poly.z_index = 3
		add_child(poly)
		# A matching stalactite above it.
		var th: float = gap * randf_range(0.25, 0.5)
		var tw: float = w * 0.8
		var top := Polygon2D.new()
		top.polygon = PackedVector2Array([
			Vector2(x - tw, ceil_y - 6), Vector2(x + tw, ceil_y - 6),
			Vector2(x + tw * 0.3, ceil_y + th * 0.6), Vector2(x, ceil_y + th), Vector2(x - tw * 0.3, ceil_y + th * 0.6),
		])
		top.color = col
		top.vertex_colors = _vertical_gradient_colors(top.polygon, col.lightened(0.12), col.darkened(0.34))
		top.material = rock_material
		top.z_index = 3
		add_child(top)

# A cluster of glowing mushrooms — a bright HDR focal point in the play space.
func _make_mushroom_cluster(base: Vector2) -> void:
	var glow: Color = crystal_color.lerp(Color(0.5, 0.9, 0.6), 0.35)
	var n: int = randi_range(3, 6)
	for i in range(n):
		var off: float = randf_range(-26, 26)
		var bx: float = base.x + off
		var by: float = _get_cave_terrain_y_at(bx)
		var sh: float = randf_range(8.0, 20.0) * (1.0 - 0.06 * float(i))
		var capw: float = sh * randf_range(0.5, 0.8)
		# Stalk
		var stalk := Polygon2D.new()
		stalk.polygon = PackedVector2Array([
			Vector2(bx - 2, by), Vector2(bx + 2, by), Vector2(bx + 1.4, by - sh), Vector2(bx - 1.4, by - sh),
		])
		stalk.color = Color(0.82, 0.86, 0.8, 0.9)
		stalk.z_index = 3
		add_child(stalk)
		# Glowing cap (overbright so it blooms under HDR)
		var cap := Polygon2D.new()
		cap.polygon = PackedVector2Array([
			Vector2(bx - capw, by - sh), Vector2(bx + capw, by - sh),
			Vector2(bx + capw * 0.6, by - sh - capw * 0.9), Vector2(bx - capw * 0.6, by - sh - capw * 0.9),
		])
		cap.color = _emit(glow, 1.8)
		cap.z_index = 3
		add_child(cap)
	# One soft light for the whole cluster
	var ml := PointLight2D.new()
	ml.position = Vector2(base.x, _get_cave_terrain_y_at(base.x) - 14)
	ml.color = glow
	ml.blend_mode = PointLight2D.BLEND_MODE_ADD
	ml.energy = 0.8
	ml.shadow_enabled = false
	ml.texture = _make_radial_light_texture()
	ml.texture_scale = 0.9
	ml.z_index = 2
	add_child(ml)

# A drooping root/vine hanging from the ceiling (Line2D with a slight curve).
func _make_hanging_vine(x: float, ceil_y: float) -> void:
	var vine := Line2D.new()
	vine.width = randf_range(1.5, 3.0)
	var len: float = randf_range(18.0, 54.0)
	var sway: float = randf_range(-10, 10)
	vine.add_point(Vector2(x, ceil_y))
	vine.add_point(Vector2(x + sway * 0.4, ceil_y + len * 0.5))
	vine.add_point(Vector2(x + sway, ceil_y + len))
	var c: Color = ground_color.darkened(0.2)
	c = c.lerp(Color(0.25, 0.32, 0.18), 0.4)  # mossy green-brown
	vine.default_color = c
	vine.z_index = 3
	add_child(vine)
	# Occasional glowing tip pod
	if randf() < 0.4:
		var pod := Polygon2D.new()
		var tip := Vector2(x + sway, ceil_y + len)
		pod.polygon = PackedVector2Array([
			tip + Vector2(-2, 0), tip + Vector2(0, -3), tip + Vector2(2, 0), tip + Vector2(0, 4),
		])
		pod.color = _emit(crystal_color.lightened(0.2), 1.6)
		pod.z_index = 3
		add_child(pod)

# =====================================================================================
# Signature set-piece — one memorable, themed focal vignette per cave (environmental
# storytelling: object arrangement implies a history). Placed ~62% across, on the floor.
# =====================================================================================
func _build_signature() -> void:
	if signature == "" or cave_terrain_points.size() < 2:
		return
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var fx: float = lerpf(left_x, right_x, 0.62)
	var base := Vector2(fx, _get_cave_terrain_y_at(fx))
	match signature:
		"crates": _sig_crates(base)
		"mine_cart": _sig_mine_cart(base)
		"pump": _sig_pump(base)
		"skeleton": _sig_skeleton(base)
		"dead_tree": _sig_dead_tree(base)
		"pillars": _sig_pillars(base, left_x, right_x)
		"coral": _sig_coral(base)

# small filled-poly helper for set-pieces
func _add_poly(pts: PackedVector2Array, col: Color, z: int, grad_to: Color = Color(0, 0, 0, 0), use_rock: bool = false) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = col
	if grad_to.a > 0.0:
		p.vertex_colors = _vertical_gradient_colors(pts, col, grad_to)
	if use_rock:
		p.material = rock_material
	p.z_index = z
	add_child(p)
	return p

func _circle_pts(c: Vector2, r: float, sides: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in range(sides):
		var a: float = TAU * float(s) / float(sides)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r))
	return pts

func _add_point_glow(pos: Vector2, col: Color, energy: float, scale: float) -> void:
	var l := PointLight2D.new()
	l.position = pos
	l.color = col
	l.blend_mode = PointLight2D.BLEND_MODE_ADD
	l.energy = energy
	l.shadow_enabled = false
	l.texture = _make_radial_light_texture()
	l.texture_scale = scale
	l.z_index = 2
	add_child(l)

# Stacked, redacted government crates + a leaning "PROPERTY OF" sign — bureaucratic satire.
func _sig_crates(base: Vector2) -> void:
	var wood := Color(0.34, 0.24, 0.13)
	var boxes := [Vector2(-22, 0), Vector2(12, 0), Vector2(-6, -26), Vector2(20, -24)]
	for b in boxes:
		var c: Vector2 = base + b
		var w: float = randf_range(13, 17)
		var h: float = randf_range(15, 20)
		_add_poly(PackedVector2Array([
			c + Vector2(-w, 0), c + Vector2(w, 0), c + Vector2(w, -h), c + Vector2(-w, -h)
		]), wood.lightened(randf_range(0.0, 0.12)), 4, wood.darkened(0.25))
		# plank lines + a black redaction bar (stamped & classified)
		_add_poly(PackedVector2Array([
			c + Vector2(-w * 0.7, -h * 0.55), c + Vector2(w * 0.5, -h * 0.55),
			c + Vector2(w * 0.5, -h * 0.4), c + Vector2(-w * 0.7, -h * 0.4)
		]), Color(0.05, 0.05, 0.05, 0.9), 5)
	# leaning signpost
	var post := Line2D.new()
	post.width = 2.5
	post.default_color = Color(0.3, 0.22, 0.12)
	post.add_point(base + Vector2(34, 2))
	post.add_point(base + Vector2(40, -40))
	post.z_index = 4
	add_child(post)
	_add_poly(PackedVector2Array([
		base + Vector2(30, -34), base + Vector2(54, -38),
		base + Vector2(55, -50), base + Vector2(31, -46)
	]), Color(0.62, 0.58, 0.45), 5, Color(0.5, 0.46, 0.34))

# Derailed mine cart spilling glowing ore + rail track + snapped support beam.
func _sig_mine_cart(base: Vector2) -> void:
	var iron := Color(0.22, 0.2, 0.22)
	# rail ties + rails
	for i in range(6):
		var tx: float = base.x - 50 + i * 18
		var ty: float = _get_cave_terrain_y_at(tx)
		_add_poly(PackedVector2Array([
			Vector2(tx - 2, ty), Vector2(tx + 2, ty), Vector2(tx + 2, ty + 4), Vector2(tx - 2, ty + 4)
		]), Color(0.28, 0.2, 0.12), 2)
	var rail1 := Line2D.new()
	rail1.width = 1.6
	rail1.default_color = Color(0.4, 0.36, 0.32)
	rail1.add_point(base + Vector2(-52, 1))
	rail1.add_point(base + Vector2(40, 1))
	rail1.z_index = 2
	add_child(rail1)
	# tilted cart body
	var c := base + Vector2(8, -10)
	_add_poly(PackedVector2Array([
		c + Vector2(-16, 8), c + Vector2(18, 4), c + Vector2(16, -10), c + Vector2(-14, -8)
	]), iron, 4, iron.darkened(0.4))
	_add_poly(_circle_pts(c + Vector2(-10, 10), 5, 8), Color(0.12, 0.11, 0.12), 5)
	_add_poly(_circle_pts(c + Vector2(10, 9), 5, 8), Color(0.12, 0.11, 0.12), 5)
	# spilled glowing ore
	for i in range(5):
		var op := base + Vector2(randf_range(-30, -8), randf_range(-2, 2))
		_add_poly(_circle_pts(op, randf_range(2.5, 4.5), 7), _emit(Color(0.95, 0.7, 0.3), 1.7), 6)
	_add_point_glow(base + Vector2(-18, -2), Color(0.95, 0.7, 0.3), 0.6, 0.5)
	# snapped support beam (tilted)
	_add_poly(PackedVector2Array([
		base + Vector2(34, 4), base + Vector2(40, 4), base + Vector2(58, -54), base + Vector2(52, -54)
	]), Color(0.26, 0.18, 0.1), 4, Color(0.16, 0.11, 0.06))

# Rusted drainage pump, half-sunk, with a snapped pipe still gushing — on-theme.
func _sig_pump(base: Vector2) -> void:
	var rust := Color(0.34, 0.26, 0.18)
	# machine housing
	var c := base + Vector2(0, -14)
	_add_poly(PackedVector2Array([
		c + Vector2(-22, 14), c + Vector2(22, 14), c + Vector2(20, -16), c + Vector2(-20, -16)
	]), rust, 4, rust.darkened(0.4))
	# rivets
	for rv in [Vector2(-16, -10), Vector2(14, -10), Vector2(-16, 8), Vector2(14, 8)]:
		_add_poly(_circle_pts(c + rv, 1.8, 6), rust.lightened(0.25), 5)
	# valve wheel
	var vc := c + Vector2(0, -6)
	_add_poly(_circle_pts(vc, 8, 12), Color(0.4, 0.3, 0.2), 5)
	_add_poly(_circle_pts(vc, 3.5, 8), rust.darkened(0.3), 6)
	for k in range(4):
		var a: float = TAU * float(k) / 4.0
		var spoke := Line2D.new()
		spoke.width = 1.4
		spoke.default_color = Color(0.45, 0.34, 0.22)
		spoke.add_point(vc)
		spoke.add_point(vc + Vector2(cos(a), sin(a)) * 8)
		spoke.z_index = 6
		add_child(spoke)
	# snapped pipe + gushing water
	var pipe := Line2D.new()
	pipe.width = 6.0
	pipe.default_color = Color(0.3, 0.24, 0.18)
	pipe.add_point(c + Vector2(20, -8))
	pipe.add_point(c + Vector2(40, -8))
	pipe.add_point(c + Vector2(46, -2))
	pipe.z_index = 4
	add_child(pipe)
	var gush := Line2D.new()
	gush.width = 3.0
	gush.default_color = _emit(Color(0.6, 0.8, 0.9, 0.7), 1.4)
	gush.add_point(c + Vector2(47, 0))
	gush.add_point(c + Vector2(52, 12))
	gush.add_point(c + Vector2(50, 22))
	gush.z_index = 4
	add_child(gush)
	_add_point_glow(c + Vector2(50, 16), Color(0.6, 0.8, 0.9), 0.4, 0.4)

# A skeleton clutching a coin pouch — who came down here and didn't leave.
func _sig_skeleton(base: Vector2) -> void:
	var bone := Color(0.78, 0.76, 0.66)
	var c := base + Vector2(0, -6)
	# ribcage arcs
	for i in range(4):
		var rib := Line2D.new()
		rib.width = 1.6
		rib.default_color = bone
		var ry: float = c.y - 4 - i * 3.5
		rib.add_point(Vector2(c.x - 10, ry))
		rib.add_point(Vector2(c.x, ry - 2))
		rib.add_point(Vector2(c.x + 10, ry))
		rib.z_index = 4
		add_child(rib)
	# spine + skull
	_add_poly(PackedVector2Array([
		c + Vector2(-1.5, -2), c + Vector2(1.5, -2), c + Vector2(1.5, -18), c + Vector2(-1.5, -18)
	]), bone.darkened(0.1), 4)
	_add_poly(_circle_pts(c + Vector2(0, -22), 6, 10), bone, 5)
	_add_poly(_circle_pts(c + Vector2(-2, -22), 1.4, 6), Color(0.1, 0.1, 0.1), 6)
	_add_poly(_circle_pts(c + Vector2(2, -22), 1.4, 6), Color(0.1, 0.1, 0.1), 6)
	# scattered bones
	for i in range(3):
		var bp := base + Vector2(randf_range(14, 30), randf_range(-2, 2))
		_add_poly(PackedVector2Array([bp, bp + Vector2(8, -2), bp + Vector2(9, 0), bp + Vector2(1, 2)]), bone.darkened(0.15), 4)
	# coin pouch, still glinting gold
	_add_poly(_circle_pts(c + Vector2(12, 4), 4, 8), Color(0.3, 0.22, 0.12), 4)
	for i in range(3):
		_add_poly(_circle_pts(c + Vector2(10 + i * 2, 2 - i), 1.6, 6), _emit(Color(1.0, 0.82, 0.3), 1.8), 6)
	_add_point_glow(c + Vector2(12, 2), Color(1.0, 0.82, 0.3), 0.5, 0.45)

# A gnarled dead tree with a will-o-wisp drifting at its roots — bog dread.
func _sig_dead_tree(base: Vector2) -> void:
	var bark := Color(0.16, 0.13, 0.1)
	var c := base
	# trunk, tapered
	_add_poly(PackedVector2Array([
		c + Vector2(-9, 2), c + Vector2(9, 2), c + Vector2(4, -64), c + Vector2(-4, -64)
	]), bark, 4, bark.lightened(0.1))
	# bare branches
	for b in [[Vector2(0, -50), Vector2(-26, -78)], [Vector2(0, -56), Vector2(24, -82)], [Vector2(0, -44), Vector2(18, -58)]]:
		var br := Line2D.new()
		br.width = 2.4
		br.default_color = bark.lightened(0.05)
		br.add_point(c + b[0])
		br.add_point(c + (b[0] + b[1]) * 0.5 + Vector2(randf_range(-4, 4), 0))
		br.add_point(c + b[1])
		br.z_index = 4
		add_child(br)
	# hanging moss
	for i in range(4):
		var mx: float = c.x + randf_range(-20, 20)
		var moss := Line2D.new()
		moss.width = 1.4
		moss.default_color = Color(0.3, 0.36, 0.2, 0.7)
		moss.add_point(Vector2(mx, c.y - 60 + randf_range(-6, 6)))
		moss.add_point(Vector2(mx + randf_range(-3, 3), c.y - 40 + randf_range(-4, 4)))
		moss.z_index = 4
		add_child(moss)
	# will-o-wisp
	_add_poly(_circle_pts(c + Vector2(18, -10), 3, 8), _emit(Color(0.6, 0.95, 0.7), 1.9), 6)
	_add_point_glow(c + Vector2(18, -10), Color(0.5, 0.95, 0.65), 0.8, 0.55)

# Towering ancient runed pillars at varied depth — eerie grandeur.
func _sig_pillars(base: Vector2, left_x: float, right_x: float) -> void:
	var stone := Color(0.2, 0.18, 0.24)
	var spots := [0.5, 0.62, 0.74]
	for idx in range(spots.size()):
		var px: float = lerpf(left_x, right_x, spots[idx])
		var ceil_y: float = _get_cave_ceiling_y_at(px)
		var floor_y: float = _get_cave_terrain_y_at(px)
		var w: float = 9.0 - idx * 1.5
		var sc: Color = stone.darkened(idx * 0.12)
		_add_poly(PackedVector2Array([
			Vector2(px - w, floor_y + 4), Vector2(px + w, floor_y + 4),
			Vector2(px + w * 0.8, ceil_y), Vector2(px - w * 0.8, ceil_y)
		]), sc, 3 - idx, sc.lightened(0.12), true)
		# glowing runes up the shaft
		for r in range(3):
			var ry: float = lerpf(floor_y, ceil_y, 0.25 + r * 0.22)
			_add_poly(_circle_pts(Vector2(px, ry), 2.0, 4), _emit(crystal_color.lightened(0.2), 1.6), 5)
		if idx == 1:
			_add_point_glow(Vector2(px, (ceil_y + floor_y) * 0.5), crystal_color, 0.5, 0.7)

# A fan-coral cluster with bioluminescent pods — undersea bloom.
func _sig_coral(base: Vector2) -> void:
	var hues := [Color(0.9, 0.3, 0.6), Color(0.3, 0.7, 0.9), Color(0.7, 0.4, 0.9)]
	for i in range(4):
		var cx: float = base.x + randf_range(-30, 30)
		var cy: float = _get_cave_terrain_y_at(cx)
		var hue: Color = hues[i % hues.size()]
		var h: float = randf_range(20, 40)
		# fan: several radiating ribs
		for k in range(5):
			var a: float = lerpf(-0.7, 0.7, float(k) / 4.0) - PI * 0.5
			var rib := Line2D.new()
			rib.width = 1.8
			rib.default_color = _emit(Color(hue.r, hue.g, hue.b, 0.85), 1.3)
			rib.add_point(Vector2(cx, cy))
			rib.add_point(Vector2(cx + cos(a) * h, cy + sin(a) * h))
			rib.z_index = 4
			add_child(rib)
		# glowing pod at the crown
		_add_poly(_circle_pts(Vector2(cx, cy - h), 3, 8), _emit(hue.lightened(0.3), 1.8), 6)
	_add_point_glow(base + Vector2(0, -24), Color(0.6, 0.5, 0.9), 0.7, 0.7)

# --- Fog backdrop: a full-bounds vertical gradient that fills the void behind
# everything (z=-20). Brighter through the mid band so the wall behind the player
# reads as lit rock haze instead of black. This is the single biggest "not a void" fix.
func _build_fog_backdrop() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return
	var fog: Dictionary = _fog_palette()
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	# Vertical band roughly centered on the cave interior, generously oversized so the
	# camera (clamped within the cave bounds) never sees an unpainted edge.
	var ceil_y: float = cave_ceiling_points[0].y
	var floor_y: float = cave_terrain_points[0].y
	for pt in cave_ceiling_points:
		ceil_y = minf(ceil_y, pt.y)
	for pt in cave_terrain_points:
		floor_y = maxf(floor_y, pt.y)
	var top_y: float = ceil_y - 280.0
	var bot_y: float = floor_y + 320.0
	var x0: float = left_x - 360.0
	var x1: float = right_x + 360.0

	# Three stacked gradient bands (top->mid, mid->bottom) give a lit core with dark
	# top and floor, reading as atmospheric depth.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.62, 1.0])
	grad.colors = PackedColorArray([
		fog["top"],
		(fog["mid"] as Color),
		(fog["mid"] as Color).lerp(fog["bottom"], 0.5),
		fog["bottom"],
	])
	var gtex := GradientTexture2D.new()
	gtex.width = 8
	gtex.height = 256
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.0, 0.0)
	gtex.fill_to = Vector2(0.0, 1.0)
	gtex.gradient = grad

	var bg := Sprite2D.new()
	bg.texture = gtex
	bg.centered = false
	bg.position = Vector2(x0, top_y)
	bg.scale = Vector2((x1 - x0) / 8.0, (bot_y - top_y) / 256.0)
	bg.z_index = -20
	add_child(bg)

	# A far focal light deep in the haze — a "distant chamber" glow that gives the
	# background a light source and somewhere for the eye to travel.
	var far_light := PointLight2D.new()
	far_light.position = Vector2(lerpf(left_x, right_x, randf_range(0.35, 0.65)), lerpf(ceil_y, floor_y, 0.4))
	far_light.color = (fog["fill"] as Color)
	far_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	far_light.energy = 0.55
	far_light.shadow_enabled = false
	far_light.texture = _make_radial_light_texture()
	far_light.texture_scale = 5.0
	far_light.z_index = -19
	add_child(far_light)

# --- Parallax background: real multi-plane depth (replaces the old flat triangles) ---
# Three silhouette planes scroll at decreasing speed for genuine parallax; far planes
# are hazed + desaturated (atmospheric perspective) so depth reads instantly.
func _build_parallax_bg() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return
	var fog: Dictionary = _fog_palette()
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var ceil_y: float = _get_cave_ceiling_y_at((left_x + right_x) * 0.5)
	var floor_y: float = _get_cave_terrain_y_at((left_x + right_x) * 0.5)
	var span: float = right_x - left_x

	# plane defs: [scroll_scale, z, color toward fog["top"], base_y frac, height, count]
	var planes := [
		{"scroll": 0.25, "z": -16, "tint": 0.78, "yf": 0.62, "h": 70.0, "rough": 0.55},  # far hills
		{"scroll": 0.45, "z": -13, "tint": 0.55, "yf": 0.74, "h": 95.0, "rough": 0.7},   # mid ridge
		{"scroll": 0.65, "z": -10, "tint": 0.32, "yf": 0.9, "h": 120.0, "rough": 0.85},  # near formations
	]
	for pdef in planes:
		var layer := Parallax2D.new()
		layer.scroll_scale = Vector2(pdef["scroll"], pdef["scroll"])
		layer.repeat_size = Vector2.ZERO
		add_child(layer)
		# Rolling silhouette ridge spanning the (parallax-stretched) width
		var base_y: float = lerpf(ceil_y, floor_y + 60.0, pdef["yf"])
		var col: Color = ground_color.lerp(fog["top"], pdef["tint"])
		col = col.lerp(Color(col.v, col.v, col.v), 0.25 * pdef["tint"])  # desaturate with distance
		var pts := PackedVector2Array()
		var x0: float = left_x - span * 0.6
		var x1: float = right_x + span * 0.6
		pts.append(Vector2(x0, floor_y + 340.0))
		var steps: int = 18
		for s in range(steps + 1):
			var fx: float = lerpf(x0, x1, float(s) / float(steps))
			var n: float = sin(fx * 0.013 + pdef["z"]) * 0.5 + sin(fx * 0.031 + pdef["scroll"] * 7.0) * 0.5
			var hy: float = base_y - (n * 0.5 + 0.5) * pdef["h"] * pdef["rough"]
			pts.append(Vector2(fx, hy))
		pts.append(Vector2(x1, floor_y + 340.0))
		var ridge := Polygon2D.new()
		ridge.polygon = pts
		ridge.color = col
		ridge.vertex_colors = _vertical_gradient_colors(pts, col.lightened(0.12), col.darkened(0.35))
		ridge.z_index = int(pdef["z"])
		layer.add_child(ridge)

	# Mineral veins glinting on the back wall (emissive accent, blooms under HDR)
	var vein_layer := Parallax2D.new()
	vein_layer.scroll_scale = Vector2(0.55, 0.55)
	vein_layer.repeat_size = Vector2.ZERO
	add_child(vein_layer)
	for i in range(randi_range(4, 7)):
		var vx: float = randf_range(left_x, right_x)
		var vy: float = lerpf(ceil_y, floor_y, randf_range(0.2, 0.7))
		var vein := Line2D.new()
		vein.width = randf_range(1.0, 2.0)
		vein.default_color = _emit(Color((fog["accent"] as Color).r, (fog["accent"] as Color).g, (fog["accent"] as Color).b, 0.4), 1.6)
		var vpx: float = vx
		var vpy: float = vy
		vein.add_point(Vector2(vpx, vpy))
		for j in range(randi_range(2, 4)):
			vpx += randf_range(-18, 18)
			vpy += randf_range(-14, 14)
			vein.add_point(Vector2(vpx, vpy))
		vein.z_index = -12
		vein_layer.add_child(vein)

# --- Foreground silhouettes: near-black framing rock that fast-parallaxes past the
# camera edges, adding the depth anchor INSIDE/Limbo use. ---
func _build_foreground_silhouettes() -> void:
	if cave_terrain_points.size() < 2 or cave_ceiling_points.size() < 2:
		return
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var fg_layer := Parallax2D.new()
	fg_layer.scroll_scale = Vector2(1.25, 1.25)
	fg_layer.repeat_size = Vector2.ZERO
	add_child(fg_layer)
	var fg_col := Color(0.04, 0.04, 0.06, 0.92)
	# Overhang jutting down from the top a couple places
	for i in range(randi_range(1, 2)):
		var ox: float = randf_range(left_x + 80, right_x - 80)
		var ceil_y: float = _get_cave_ceiling_y_at(ox)
		var ow: float = randf_range(50, 90)
		var oh: float = randf_range(20, 44)
		var over := Polygon2D.new()
		over.polygon = PackedVector2Array([
			Vector2(ox - ow * 0.5, ceil_y - 60),
			Vector2(ox + ow * 0.5, ceil_y - 60),
			Vector2(ox + ow * 0.3, ceil_y + oh),
			Vector2(ox, ceil_y + oh * 0.5),
			Vector2(ox - ow * 0.3, ceil_y + oh),
		])
		over.color = fg_col
		over.z_index = 11
		fg_layer.add_child(over)
	# Big out-of-focus stalagmite/boulder crossing the bottom edge (one, near an edge,
	# so it frames without dominating the play space).
	for i in range(1):
		var bx: float = (left_x + 70) if randf() < 0.5 else (right_x - 70)
		var floor_y: float = _get_cave_terrain_y_at(bx)
		var bw: float = randf_range(40, 64)
		var bh: float = randf_range(46, 78)
		var boulder := Polygon2D.new()
		boulder.polygon = PackedVector2Array([
			Vector2(bx - bw * 0.5, floor_y + 80),
			Vector2(bx - bw * 0.3, floor_y - bh * 0.5),
			Vector2(bx, floor_y - bh),
			Vector2(bx + bw * 0.35, floor_y - bh * 0.4),
			Vector2(bx + bw * 0.5, floor_y + 80),
		])
		boulder.color = fg_col
		boulder.z_index = 11
		fg_layer.add_child(boulder)

# --- Exit Zone ---
func _build_exit_zone() -> void:
	var left_x: float = cave_terrain_points[0].x
	var exit_area := Area2D.new()
	exit_area.position = Vector2(left_x + 10, (cave_ceiling_points[0].y + cave_terrain_points[0].y) * 0.5)
	exit_area.collision_layer = 0
	exit_area.collision_mask = 1
	var coll := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, cave_terrain_points[0].y - cave_ceiling_points[0].y)
	coll.shape = shape
	exit_area.add_child(coll)
	add_child(exit_area)
	exit_area.body_entered.connect(_on_exit_body_entered)

func _on_exit_body_entered(body: Node2D) -> void:
	if OS.get_environment("DTS_FREEZE") != "":
		return  # debug-only: stay in the cave for screenshots (never set in real builds)
	if body is CharacterBody2D:
		SceneManager.transition_to_return()

# --- Exit Glow (Enhanced) ---
func _build_exit_glow() -> void:
	var left_x: float = cave_terrain_points[0].x
	var mid_y: float = (cave_ceiling_points[0].y + cave_terrain_points[0].y) * 0.5
	var opening_h: float = cave_terrain_points[0].y - cave_ceiling_points[0].y

	# Dark rock cover over the exit void (everything left of the cave mouth) so it reads
	# as a solid wall with a lit doorway — NOT a flat bright fog panel. Covers from far
	# off-screen up to the opening, textured with the rock shader.
	var ceil0: float = cave_ceiling_points[0].y
	var floor0: float = cave_terrain_points[0].y
	var cover := Polygon2D.new()
	cover.polygon = PackedVector2Array([
		Vector2(left_x - 520, ceil0 - 320), Vector2(left_x + 6, ceil0 - 320),
		Vector2(left_x + 6, floor0 + 360), Vector2(left_x - 520, floor0 + 360),
	])
	var cov_col: Color = wall_color.darkened(0.12)
	cover.color = cov_col
	cover.vertex_colors = _vertical_gradient_colors(cover.polygon, cov_col.darkened(0.25), cov_col.lightened(0.08))
	cover.material = rock_material
	cover.z_index = -9
	add_child(cover)

	# Warm "daylight from the surface" gradient filling the opening itself.
	var door := Sprite2D.new()
	var dtex := GradientTexture2D.new()
	dtex.width = 64
	dtex.height = 8
	dtex.fill = GradientTexture2D.FILL_LINEAR
	dtex.fill_from = Vector2(0.0, 0.0)
	dtex.fill_to = Vector2(1.0, 0.0)
	var dgrad := Gradient.new()
	dgrad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	dgrad.colors = PackedColorArray([
		_emit(Color(0.95, 0.85, 0.62, 0.9), 1.6),
		Color(0.7, 0.62, 0.45, 0.5),
		Color(0.5, 0.45, 0.35, 0.0),
	])
	dtex.gradient = dgrad
	door.texture = dtex
	door.centered = false
	door.position = Vector2(left_x - 14, ceil0 - 4)
	door.scale = Vector2(70.0 / 64.0, (opening_h + 12) / 8.0)
	door.z_index = -7
	add_child(door)

	var glow := ColorRect.new()
	glow.size = Vector2(16, opening_h + 10)
	glow.position = Vector2(left_x - 4, cave_ceiling_points[0].y - 5)
	glow.color = Color(0.5, 0.45, 0.35, 0.25)
	glow.z_index = 3
	add_child(glow)

	# Light rays fanning from exit
	for i in range(randi_range(3, 5)):
		var ray := Line2D.new()
		ray.width = randf_range(1.5, 3.0)
		ray.default_color = Color(0.8, 0.7, 0.5, randf_range(0.05, 0.12))
		var start_y: float = mid_y + randf_range(-opening_h * 0.3, opening_h * 0.3)
		ray.add_point(Vector2(left_x, start_y))
		ray.add_point(Vector2(left_x + randf_range(30, 60), start_y + randf_range(-10, 10)))
		ray.z_index = 3
		add_child(ray)

	# PointLight2D for exit glow
	var exit_light := PointLight2D.new()
	exit_light.position = Vector2(left_x + 8, mid_y)
	exit_light.color = Color(0.8, 0.75, 0.6)
	exit_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	exit_light.energy = 2.0
	exit_light.shadow_enabled = false
	var gradient := GradientTexture2D.new()
	gradient.width = 128
	gradient.height = 128
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(0, 0, 0, 0))
	gradient.gradient = grad
	exit_light.texture = gradient
	exit_light.texture_scale = 0.8
	add_child(exit_light)

# --- Player ---
func _spawn_player() -> void:
	player_ref = PLAYER_SCENE.instantiate()
	var left_x: float = cave_terrain_points[0].x
	var floor_y: float = cave_terrain_points[0].y
	# Spawn deep enough that the entry wall sits at the screen edge instead of
	# mid-frame (at +24 the clamped camera showed a half-screen of black void).
	player_ref.position = Vector2(left_x + 90, floor_y - 20)
	add_child(player_ref)

# --- Camera ---
func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.enabled = true
	cam.zoom = Vector2(1, 1)
	var left_x: float = cave_terrain_points[0].x
	var right_x: float = cave_terrain_points[cave_terrain_points.size() - 1].x
	var top_y: float = cave_ceiling_points[0].y
	for pt in cave_ceiling_points:
		if pt.y < top_y:
			top_y = pt.y
	var bottom_y: float = cave_terrain_points[0].y
	for pt in cave_terrain_points:
		if pt.y > bottom_y:
			bottom_y = pt.y
	cam.limit_left = int(left_x - 20)
	cam.limit_right = int(right_x + 20)
	cam.limit_top = int(top_y - 40)
	cam.limit_bottom = int(bottom_y + 40)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	if player_ref:
		player_ref.add_child(cam)
		# The player scene ships its own Camera2D (overworld limits) which entered
		# the tree first and stays current — without this, THIS camera never
		# activates and the cave view is clamped by overworld limits (black void
		# past the entrance wall at spawn).
		cam.make_current()

# --- Virtual: override in subclass ---
func _setup_loot_and_lore() -> void:
	pass

# --- Cave UI (HUD + Shop + Menu) ---
func _setup_cave_ui() -> void:
	# HUD (CanvasLayer at layer 10 — same as overworld)
	cave_hud = HUD_SCENE.instantiate()
	add_child(cave_hud)
	cave_hud.menu_pressed.connect(_on_cave_menu_pressed)

	# UILayer for panels (CanvasLayer at layer 20)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)

	cave_shop_panel = SHOP_SCENE.instantiate()
	ui_layer.add_child(cave_shop_panel)

	cave_menu_panel = MENU_SCENE.instantiate()
	ui_layer.add_child(cave_menu_panel)
	cave_menu_panel.reset_confirmed.connect(_on_cave_reset_confirmed)

	# Close panels when visibility changes
	cave_shop_panel.visibility_changed.connect(_on_cave_panel_visibility_changed)
	cave_menu_panel.visibility_changed.connect(_on_cave_panel_visibility_changed)

	# Let player open shop via scoop near any position in cave
	if player_ref:
		player_ref.shop_requested.connect(_on_cave_shop_pressed)

	# Unstuck button (bottom-right area, above bottom bar)
	var unstuck_layer := CanvasLayer.new()
	unstuck_layer.layer = 15
	add_child(unstuck_layer)
	var unstuck_btn := Button.new()
	unstuck_btn.text = "Unstuck"
	unstuck_btn.add_theme_font_size_override("font_size", 10)
	unstuck_btn.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.13, 0.1, 0.7)
	btn_style.border_color = Color(0.4, 0.35, 0.25, 0.6)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(4)
	unstuck_btn.add_theme_stylebox_override("normal", btn_style)
	var hover_style := btn_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.22, 0.18, 0.12, 0.85)
	unstuck_btn.add_theme_stylebox_override("hover", hover_style)
	unstuck_btn.add_theme_stylebox_override("pressed", hover_style)
	var vp_size: Vector2 = get_viewport_rect().size
	unstuck_btn.position = Vector2(vp_size.x - 70, vp_size.y - 60)
	unstuck_btn.pressed.connect(_on_unstuck_pressed)
	unstuck_layer.add_child(unstuck_btn)

func _on_cave_shop_pressed() -> void:
	if cave_shop_panel.visible:
		_close_cave_panels()
		return
	_close_cave_panels()
	cave_shop_panel.open()
	if player_ref:
		player_ref.ui_panel_open = true

func _on_cave_menu_pressed() -> void:
	_close_cave_panels()
	cave_menu_panel.open()
	if player_ref:
		player_ref.ui_panel_open = true

func _on_cave_reset_confirmed() -> void:
	_close_cave_panels()
	GameManager.reset_game()
	SaveManager.save_game()
	SceneManager.transition_to_return()

func _close_cave_panels() -> void:
	if cave_shop_panel:
		cave_shop_panel.visible = false
	if player_ref:
		player_ref.ui_panel_open = false

func _on_cave_panel_visibility_changed() -> void:
	if cave_shop_panel and cave_menu_panel:
		if not cave_shop_panel.visible and not cave_menu_panel.visible:
			if player_ref:
				player_ref.ui_panel_open = false

func _on_unstuck_pressed() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var px: float = player_ref.position.x
	# Find closest pool to the player
	var closest_idx: int = -1
	var closest_dist: float = 999999.0
	for i in range(cave_pool_refs.size()):
		var refs: Dictionary = cave_pool_refs[i]
		var pool_cx: float = (refs["x_start"] + refs["x_end"]) * 0.5
		var dist: float = absf(px - pool_cx)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i
	if closest_idx >= 0:
		var refs: Dictionary = cave_pool_refs[closest_idx]
		var safe_x: float = refs["x_start"] - 30.0
		# Clamp to cave left boundary
		var left_bound: float = cave_terrain_points[0].x + 30.0
		safe_x = maxf(safe_x, left_bound)
		var safe_y: float = _get_cave_terrain_y_at(safe_x) - 16.0
		player_ref.position = Vector2(safe_x, safe_y)
		player_ref.velocity = Vector2.ZERO
	else:
		# No pools — just move to cave entrance area
		var left_x: float = cave_terrain_points[0].x + 30.0
		var floor_y: float = cave_terrain_points[0].y - 16.0
		player_ref.position = Vector2(left_x, floor_y)
		player_ref.velocity = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if cave_menu_panel and cave_menu_panel.visible:
			cave_menu_panel._close()
			if player_ref:
				player_ref.ui_panel_open = false
		elif cave_shop_panel and cave_shop_panel.visible:
			_close_cave_panels()
		else:
			if cave_menu_panel:
				cave_menu_panel.open()
				if player_ref:
					player_ref.ui_panel_open = true

# --- Ceiling Y helper ---
func _get_cave_ceiling_y_at(x: float) -> float:
	for i in range(cave_ceiling_points.size() - 1):
		if x >= cave_ceiling_points[i].x and x <= cave_ceiling_points[i + 1].x:
			var t: float = (x - cave_ceiling_points[i].x) / (cave_ceiling_points[i + 1].x - cave_ceiling_points[i].x + 0.001)
			return lerpf(cave_ceiling_points[i].y, cave_ceiling_points[i + 1].y, t)
	if x < cave_ceiling_points[0].x:
		return cave_ceiling_points[0].y
	return cave_ceiling_points[cave_ceiling_points.size() - 1].y

# --- Process: Drips, Crystal pulses, Dust motes ---
func _process(delta: float) -> void:
	wave_time += delta

	# Post-processing time uniform
	cave_post_time += delta
	if cave_post_process_rect and cave_post_process_rect.material:
		(cave_post_process_rect.material as ShaderMaterial).set_shader_parameter("time", cave_post_time)

	# Cave pool water shader time uniform
	for refs in cave_pool_refs:
		var wp = refs.get("water_poly")
		if is_instance_valid(wp) and wp.material:
			(wp.material as ShaderMaterial).set_shader_parameter("time", wave_time)

	# Ambient drips
	drip_timer += delta
	if drip_timer >= 1.5:
		drip_timer -= 1.5
		_spawn_drip()

	# God-ray shaft shimmer (drifting dust-in-sunbeam feel)
	for sh in light_shafts:
		var sn = sh["node"]
		if is_instance_valid(sn):
			sn.modulate.a = lerpf(0.5, 1.0, (sin(wave_time * sh["speed"] + sh["phase"]) + 1.0) * 0.5)

	# Crystal light pulse
	for i in range(crystal_lights.size()):
		if is_instance_valid(crystal_lights[i]):
			crystal_lights[i].energy = lerpf(0.7, 1.25, (sin(wave_time * 1.5 + crystal_phases[i]) + 1.0) * 0.5)

	# Dust mote drift
	for dm in dust_motes:
		if not is_instance_valid(dm["node"]):
			continue
		var n: ColorRect = dm["node"]
		var new_x: float = dm["base_x"] + wave_time * dm["speed_x"]
		# Wrap at cave edges
		var range_x: float = dm["right_x"] - dm["left_x"]
		new_x = dm["left_x"] + fmod(new_x - dm["left_x"], range_x)
		if new_x < dm["left_x"]:
			new_x += range_x
		var new_y: float = dm["base_y"] + sin(wave_time * 0.8 + dm["phase"]) * 4.0
		n.position = Vector2(new_x, new_y)

	# Phase 9B: Moisture gleam flickers
	for mg in moisture_gleams:
		if not is_instance_valid(mg["node"]):
			continue
		mg["flash_timer"] += delta
		if mg["flash_timer"] >= mg["flash_interval"]:
			mg["flash_timer"] = 0.0
			mg["flash_interval"] = randf_range(3.0, 10.0)
			# Brief white flash
			var gleam_node: ColorRect = mg["node"]
			gleam_node.color.a = 0.8
			var tw := create_tween()
			tw.tween_property(gleam_node, "color:a", 0.0, randf_range(0.2, 0.5))

	# Pulse cave pool glow lights
	for i in range(cave_pool_refs.size()):
		if i < cave_pool_refs.size():
			var refs: Dictionary = cave_pool_refs[i]
			if is_instance_valid(refs["glow_light"]) and refs["glow_light"].visible:
				var fill: float = GameManager.get_cave_pool_fill_fraction(cave_id, i)
				refs["glow_light"].energy = 0.8 * fill * (0.9 + sin(wave_time * 1.2 + float(i)) * 0.1)

	# Proximity-based cave pool detection (more reliable than Area2D)
	if player_ref and is_instance_valid(player_ref) and player_ref.has_method("set_near_cave_pool"):
		var px: float = player_ref.position.x
		var found_pool: int = -1
		for i in range(cave_pool_refs.size()):
			var refs: Dictionary = cave_pool_refs[i]
			if GameManager.is_cave_pool_completed(cave_id, i):
				continue
			# Player is near pool if within 50px left of pool start or inside pool range
			if px >= refs["x_start"] - 50.0 and px <= refs["x_end"] + 20.0:
				found_pool = i
				break
		if found_pool >= 0:
			if not player_ref.near_cave_pool or player_ref.cave_pool_index != found_pool:
				player_ref.set_near_cave_pool(true, cave_id, found_pool)
		else:
			if player_ref.near_cave_pool:
				player_ref.set_near_cave_pool(false, cave_id, player_ref.cave_pool_index)

func _spawn_drip() -> void:
	if cave_ceiling_points.size() == 0:
		return
	var idx: int = randi() % cave_ceiling_points.size()
	var pt: Vector2 = cave_ceiling_points[idx]

	# If this x is over an active pool, the drip lands on the water surface (ripple)
	var land_y: float = _get_cave_terrain_y_at(pt.x)
	var on_pool: bool = false
	for i in range(cave_pool_refs.size()):
		var refs: Dictionary = cave_pool_refs[i]
		if pt.x >= refs["x_start"] and pt.x <= refs["x_end"] and not GameManager.is_cave_pool_completed(cave_id, i):
			var wp = refs.get("water_poly")
			if is_instance_valid(wp) and wp.visible:
				var fill: float = GameManager.get_cave_pool_fill_fraction(cave_id, i)
				land_y = lerpf(refs["valley_min_y"], refs["overflow_y"], fill)
				on_pool = true
			break

	var drip := ColorRect.new()
	drip.size = Vector2(1, 3)
	drip.color = Color(0.3, 0.45, 0.6, 0.6)
	drip.position = pt
	drip.z_index = 6
	add_child(drip)

	var fall_time: float = (land_y - pt.y) / 120.0
	var tw := create_tween()
	tw.tween_property(drip, "position:y", land_y, fall_time)
	tw.tween_callback(func() -> void:
		if on_pool:
			_spawn_ripple(pt.x, land_y)
		else:
			for j in range(2):
				var splash := ColorRect.new()
				splash.size = Vector2(2, 1)
				splash.color = Color(0.3, 0.45, 0.6, 0.4)
				splash.position = Vector2(pt.x + randf_range(-3, 3), land_y)
				splash.z_index = 6
				add_child(splash)
				var stw := create_tween()
				stw.tween_property(splash, "position:y", land_y - randf_range(2, 6), 0.3)
				stw.parallel().tween_property(splash, "modulate:a", 0.0, 0.3)
				stw.tween_callback(splash.queue_free)
		drip.queue_free()
	)

func _spawn_ripple(rx: float, ry: float) -> void:
	# Expanding ring at a pool surface where a drip landed
	for ring_i in range(2):
		var ring := Line2D.new()
		ring.width = 1.0
		ring.default_color = Color(0.55, 0.75, 0.9, 0.5)
		var pts := PackedVector2Array()
		var segs: int = 14
		for s in range(segs + 1):
			var a: float = TAU * float(s) / float(segs)
			pts.append(Vector2(cos(a) * 2.0, sin(a) * 0.8))
		ring.points = pts
		ring.position = Vector2(rx, ry)
		ring.z_index = 3
		add_child(ring)
		var target_scale: float = randf_range(4.0, 7.0)
		var rtw := create_tween()
		rtw.tween_interval(ring_i * 0.12)
		rtw.tween_property(ring, "scale", Vector2(target_scale, target_scale), 0.7)
		rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.7)
		rtw.tween_callback(ring.queue_free)

func _get_cave_terrain_y_at(x: float) -> float:
	for i in range(cave_terrain_points.size() - 1):
		if x >= cave_terrain_points[i].x and x <= cave_terrain_points[i + 1].x:
			var t: float = (x - cave_terrain_points[i].x) / (cave_terrain_points[i + 1].x - cave_terrain_points[i].x + 0.001)
			return lerpf(cave_terrain_points[i].y, cave_terrain_points[i + 1].y, t)
	if x < cave_terrain_points[0].x:
		return cave_terrain_points[0].y
	return cave_terrain_points[cave_terrain_points.size() - 1].y
