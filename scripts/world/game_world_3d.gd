extends Node3D

# 3D voxel overworld — look-dev build. Polished environment (MSAA, sky-fill ambient,
# filmic tonemap, soft sun shadows, depth fog) + terrain + water. Player/camera-follow
# and signal wiring come next; for now a static diorama camera frames the first pools.

const CAPTURE_PATH := "res://_lookdev.png"
const PLAYER_3D := preload("res://scripts/player/player_3d.gd")

var water: WaterBuilder
var player: CharacterBody3D
var follow_cam: Camera3D
# camera Z (12) sits IN FRONT of the terrain front edge (FRONT_Z=14) so the dig-face
# cross-section is behind the camera and never rendered — foreground is pure top-surface ground
var cam_offset := Vector3(1.5, 13.0, 10.5)

func _ready() -> void:
	_build_environment()
	if not ("--nobg" in OS.get_cmdline_user_args()):
		SceneryBuilder.build_background(self)
	TerrainBuilder.build(self)
	SceneryBuilder.build_surface_props(self)
	SceneryBuilder.build_tree_walls(self)
	SceneryBuilder.build_digface_detail(self)
	water = WaterBuilder.new()
	water.build(self)
	SceneryBuilder.build_water_props(self)
	GameManager.water_level_changed.connect(func(i: int, _pct: float) -> void:
		water.update_fill(i, GameManager.get_swamp_fill_fraction(i)))

	if _wants_capture():
		if "--player" in OS.get_cmdline_user_args():
			_spawn_player()
			var hill := "--hill" in OS.get_cmdline_user_args()
			var cx := 520.0 if hill else 300.0   # 520 = flat ridge (between pools)
			player.position = Vector3(cx * WorldData.SCALE, WorldData.surface_y_at(cx) + 1.0, 0.0)
			var pcam := Camera3D.new()
			pcam.projection = Camera3D.PROJECTION_ORTHOGONAL
			add_child(pcam)
			if hill:
				pcam.size = 24.0
				var look := player.position + Vector3(0, 1.0, 0)
				pcam.position = look + cam_offset
				pcam.look_at(look, Vector3.UP)
			else:
				pcam.size = 4.0
				var look := player.position + Vector3(0, 0.3, 0)
				pcam.position = look + Vector3(2.6, 1.0, 4.5)
				pcam.look_at(look, Vector3.UP)
			pcam.make_current()
		else:
			_build_camera()
		_capture_and_quit()
	else:
		# crisp full-res 3D (don't use the 640x360 pixel-art viewport for 3D)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		_spawn_player()
		_build_follow_camera()

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PLAYER_3D)
	var sx := 40.0
	player.position = Vector3(sx * WorldData.SCALE, WorldData.surface_y_at(sx) + 1.0, 0.0)
	add_child(player)

func _build_follow_camera() -> void:
	follow_cam = Camera3D.new()
	follow_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	follow_cam.size = 24.0
	add_child(follow_cam)
	follow_cam.position = player.position + cam_offset
	follow_cam.look_at(player.position + Vector3(0, 1.0, 0), Vector3.UP)
	follow_cam.make_current()

func _process(delta: float) -> void:
	if follow_cam == null or player == null:
		return
	# track the player's x/y; hold z centred so the camera doesn't sway as the path winds
	var look := Vector3(player.global_position.x, player.global_position.y + 1.0, 0.0)
	var want := look + cam_offset
	# smooth the horizontal scroll, but track height TIGHTLY so climbing a hill never
	# lags the camera down and exposes the void below the terrain
	var p := follow_cam.global_position
	var k := clampf(delta * 6.0, 0.0, 1.0)
	p.x = lerpf(p.x, want.x, k)
	p.z = lerpf(p.z, want.z, k)
	p.y = lerpf(p.y, want.y, clampf(delta * 18.0, 0.0, 1.0))
	follow_cam.global_position = p
	follow_cam.look_at(look, Vector3.UP)

func _build_environment() -> void:
	# Forward+ renderer — gorgeous desktop/Steam path. MSAA for crisp edges.
	get_viewport().msaa_3d = Viewport.MSAA_4X

	# Warm key sun with SOFT shadows (angular size gives a real penumbra)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42, 44, 0)
	sun.light_color = Color(1.0, 0.91, 0.73)   # warm, hazy swamp sun
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.4          # soft-edged shadows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.3
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_normal_bias = 1.2
	add_child(sun)

	# Procedural gradient sky → ambient source (cool sky fill in shadows)
	var sky_mat := ProceduralSkyMaterial.new()
	# hazy, overcast-ish swamp sky (muted grey-green, not bright blue)
	sky_mat.sky_top_color = Color(0.40, 0.50, 0.55)
	sky_mat.sky_horizon_color = Color(0.62, 0.66, 0.58)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color(0.50, 0.54, 0.48)
	sky_mat.ground_horizon_color = Color(0.62, 0.66, 0.58)
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.08
	sky_mat.energy_multiplier = 0.5
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.30
	env.ambient_light_sky_contribution = 0.7

	# LINEAR keeps the stylized colours rich (FILMIC/ACES desaturate these LDR colours)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0

	# Bloom — only the brightest highlights (water sparkle) glow; don't wash the grass
	env.glow_enabled = not ("--noglow" in OS.get_cmdline_user_args())
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.15

	# SSAO — contact shadows in crevices, under trees/grass (depth + grounding)
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.6

	# SSIL — short-range colored indirect light bounce
	env.ssil_enabled = false

	# Volumetric fog off — it milks out this bright daytime scene
	env.volumetric_fog_enabled = false

	# Murky swamp haze — grounds the scene (no floating slab) + fades distance into murk
	env.fog_enabled = not ("--nofog" in OS.get_cmdline_user_args())
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.52, 0.58, 0.50)   # grey-green swamp murk
	env.fog_sky_affect = 0.4
	env.fog_density = 1.0
	env.fog_depth_begin = 26.0
	env.fog_depth_end = 115.0
	env.fog_depth_curve = 0.5

	# Subtle grade — a touch more contrast + saturation (AgX desaturates highlights)
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.97
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.98   # grimy, slightly desaturated

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "LookCam"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var wide := "--wide" in OS.get_cmdline_user_args()
	cam.size = 34.0 if wide else 24.0
	add_child(cam)
	var tx := 40.0 if wide else 18.0
	var ty: float = WorldData.surface_y_at(tx / WorldData.SCALE) - (3.0 if wide else 1.5)
	var target := Vector3(tx, ty, 0.0)
	cam.position = target + Vector3(3.0, 16.0, 26.0) if wide else target + Vector3(1.5, 13.0, 10.5)
	cam.look_at(target, Vector3.UP)
	cam.make_current()

# ── look-dev capture ────────────────────────────────────────────────────────────
func _wants_capture() -> bool:
	return "--capture" in OS.get_cmdline_user_args()

func _capture_and_quit() -> void:
	# render the capture at full resolution (the real game should NOT use the 640x360
	# pixel-art viewport for 3D — this shows the true crispness)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(CAPTURE_PATH)
	await get_tree().create_timer(0.05).timeout
	get_tree().quit()
