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
# lower + further back = more side-on: shows the character's side + more of the back
# hills rising, instead of a near top-down map view (borders TBD per user)
var cam_offset := Vector3(1.5, 9.5, 14.5)
# orthographic zoom — smaller = tighter (crops the bottom/border out of frame)
const CAM_SIZE := 19.5
var cam_look := Vector3.ZERO

func _ready() -> void:
	_build_environment()
	if not ("--nobg" in OS.get_cmdline_user_args()):
		SceneryBuilder.build_background(self)
	TerrainBuilder.build(self)
	SceneryBuilder.build_surface_props(self)
	SceneryBuilder.build_tree_walls(self)
	SceneryBuilder.build_path_detail(self)
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
				pcam.size = CAM_SIZE
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
	follow_cam.size = CAM_SIZE
	add_child(follow_cam)
	cam_look = player.position + Vector3(0, 1.0, 0)
	follow_cam.position = cam_look + cam_offset
	follow_cam.look_at(cam_look, Vector3.UP)
	follow_cam.make_current()

func _process(delta: float) -> void:
	if follow_cam == null or player == null:
		return
	# SMOOTHED aim point — follow the winding z partially so the character stays framed
	# while the road still visibly sweeps. Smoothing both the aim and the position keeps
	# the camera steady (no jitter) even as the path/terrain change.
	var target_look := Vector3(player.global_position.x, player.global_position.y + 1.0, player.global_position.z * 0.6)
	cam_look = cam_look.lerp(target_look, clampf(delta * 7.0, 0.0, 1.0))
	var want := cam_look + cam_offset
	var p := follow_cam.global_position
	p.x = lerpf(p.x, want.x, clampf(delta * 6.0, 0.0, 1.0))
	p.z = lerpf(p.z, want.z, clampf(delta * 6.0, 0.0, 1.0))
	p.y = lerpf(p.y, want.y, clampf(delta * 9.0, 0.0, 1.0))
	follow_cam.global_position = p
	follow_cam.look_at(cam_look, Vector3.UP)

func _build_environment() -> void:
	# Forward+ renderer — gorgeous desktop/Steam path. MSAA + TAA: TAA cleans the soft-shadow
	# dithering, SDFGI and volumetric-fog noise so those premium effects read cleanly.
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().use_taa = true

	# Warm golden key sun with contact-hardening soft shadows
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42, 44, 0)
	sun.light_color = Color(1.0, 0.92, 0.76)   # warm, hazy swamp sun
	sun.light_energy = 1.25
	sun.light_indirect_energy = 1.5            # boost the SDFGI bounce warmth into the shade
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.4           # contact-hardening penumbra
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_split_1 = 0.12
	sun.directional_shadow_max_distance = 60.0   # tighter → crisper texels for the diorama
	sun.directional_shadow_fade_start = 0.85
	if not ("--nofog" in OS.get_cmdline_user_args()):
		sun.light_volumetric_fog_energy = 1.8    # makes the god-ray shafts glow (subtle)
	add_child(sun)

	# Procedural gradient sky → ambient source (cool sky fill in shadows)
	var sky_mat := ProceduralSkyMaterial.new()
	# hazy, overcast-ish swamp sky (muted grey-green, not bright blue)
	sky_mat.sky_top_color = Color(0.40, 0.50, 0.55)
	sky_mat.sky_horizon_color = Color(0.62, 0.66, 0.58)
	sky_mat.sky_curve = 0.18
	# green-tinted ground hemisphere → shaded foliage picks up GREEN ambient, not grey
	sky_mat.ground_bottom_color = Color(0.34, 0.46, 0.34)
	sky_mat.ground_horizon_color = Color(0.52, 0.60, 0.50)
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.08
	sky_mat.energy_multiplier = 0.6
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# SDFGI provides indirect fill, but a bit more sky ambient keeps shaded foliage from
	# reading as flat grey (the camera-facing side of foreground trees was going grey)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.22
	env.ambient_light_sky_contribution = 1.0

	# Global illumination — colored bounce light (warm sun → green foliage bounce into shade,
	# sky-blue fill in crevices). The single biggest "hand-crafted" depth win for a diorama.
	env.sdfgi_enabled = not ("--nogi" in OS.get_cmdline_user_args())
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.sdfgi_energy = 1.0
	env.sdfgi_normal_bias = 1.1
	env.sdfgi_probe_bias = 1.1
	# short-range colored contact bounce on top of SDFGI
	env.ssil_enabled = true
	env.ssil_radius = 2.5
	env.ssil_intensity = 1.2
	env.ssil_sharpness = 0.98

	# AgX tonemap — rolls highlights off softly (cozy, no harsh clip) and preserves hue far
	# better than Filmic/ACES; re-saturate to bring the stylized vertex colours back rich.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	# Soft dreamy glow (SOFTLIGHT blend = halo, not additive blow-out)
	env.glow_enabled = not ("--noglow" in OS.get_cmdline_user_args())
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.set("glow_levels/3", 0.7)
	env.set("glow_levels/4", 1.0)
	env.set("glow_levels/5", 0.6)

	# SSAO — grounding contact darkening (low light_affect so lit areas don't get grimy)
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.ssao_detail = 1.0
	env.ssao_light_affect = 0.1
	env.ssao_sharpness = 0.98

	# Murky swamp haze — grounds the scene + aerial perspective bleeds distance toward sky
	env.fog_enabled = not ("--nofog" in OS.get_cmdline_user_args())
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.60, 0.68, 0.60)   # grey-green swamp murk
	env.fog_sun_scatter = 0.15
	env.fog_aerial_perspective = 0.18               # gentle distance-to-sky bleed only
	env.fog_sky_affect = 0.25
	env.fog_density = 0.0                            # let volumetric carry the near haze
	env.fog_depth_begin = 62.0                       # keep the whole playfield crisp
	env.fog_depth_end = 165.0
	env.fog_depth_curve = 0.75

	# Volumetric fog — very SUBTLE haze + faint god-ray shafts. Low density so it never milks.
	env.volumetric_fog_enabled = not ("--nofog" in OS.get_cmdline_user_args())
	env.volumetric_fog_density = 0.0025
	env.volumetric_fog_albedo = Color(0.86, 0.92, 0.83)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 55.0
	env.volumetric_fog_gi_inject = 0.35
	env.volumetric_fog_ambient_inject = 0.04
	env.volumetric_fog_sky_affect = 0.15

	# Re-saturate after AgX + cozy punch (counter the soft/faded feel)
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.24
	env.adjustment_saturation = 1.38

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
	cam.position = target + Vector3(3.0, 16.0, 26.0) if wide else target + cam_offset
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
