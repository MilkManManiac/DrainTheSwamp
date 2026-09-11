extends CharacterBody2D

const BASE_SPEED: float = 120.0
const GRAVITY: float = 800.0
const SCOOP_COOLDOWN: float = 0.3
# Horizontal accel/friction give movement a little weight (subtle ramp + skid)
const ACCEL: float = 1400.0
const FRICTION: float = 2000.0

signal shop_requested()
signal cave_entrance_requested(cave_id: String)
signal scooped()  # v3 skin plays its scoop strip off this (fired with the arm tween)

var near_water: bool = false
var near_swamp_index: int = -1
var near_shop: bool = false
var near_cave_entrance: bool = false
var near_cave_id: String = ""
var near_cave_pool: bool = false
var cave_pool_cave_id: String = ""
var cave_pool_index: int = -1
var ui_panel_open: bool = false
var scoop_cooldown_timer: float = 0.0
var facing_right: bool = true
var flash_tween: Tween = null
var tool_tween: Tween = null
var walk_time: float = 0.0
var is_walking: bool = false
var prev_walk_sin: float = 0.0
var auto_scoop_timer: float = 0.0

var idle_timer: float = 0.0
var idle_state: int = 0
var drip_timer: float = 0.0

var speed_line_timer: float = 0.0

# Dev fly mode
var fly_mode: bool = false
const FLY_SPEED: float = 400.0

# Lantern system
var lantern_light: PointLight2D = null
var lantern_node: Node2D = null
var lantern_glass: ColorRect = null
var lantern_flame: ColorRect = null
var lantern_active: bool = false
var lantern_flicker_time: float = 0.0

@onready var visual: Node2D = $Visual
@onready var tool_sprite: Node2D = $Visual/ToolSprite
@onready var boot_left: ColorRect = $Visual/BootLeft
@onready var boot_right: ColorRect = $Visual/BootRight
@onready var boot_sole_left: ColorRect = $Visual/BootSoleLeft
@onready var boot_sole_right: ColorRect = $Visual/BootSoleRight
@onready var boot_lace_left: ColorRect = $Visual/BootLaceLeft
@onready var boot_lace_right: ColorRect = $Visual/BootLaceRight
@onready var pants_left: ColorRect = $Visual/PantsLeft
@onready var pants_right: ColorRect = $Visual/PantsRight
@onready var arm_right: ColorRect = $Visual/ArmRight
@onready var hand_right: ColorRect = $Visual/HandRight
@onready var arm_left: ColorRect = $Visual/ArmLeft
@onready var hand_left: ColorRect = $Visual/HandLeft

# Tool visual elements (built dynamically)
var tool_visuals: Array[ColorRect] = []

var _hdr_glow: bool = false  # Forward+/Mobile: lantern emits overbright to bloom under HDR glow
var _shot_camx: float = NAN  # debug: env DTS_CAMX parks the player at a world X for screenshots
var _dbg_lantern: bool = false  # debug: env DTS_LANTERN=1 lights the lantern without the upgrade (captures)

func _ready() -> void:
	add_to_group("player")
	_hdr_glow = RenderingServer.get_rendering_device() != null
	var cx: String = OS.get_environment("DTS_CAMX")
	if cx != "":
		_shot_camx = cx.to_float()
	_dbg_lantern = OS.get_environment("DTS_LANTERN") != ""
	GameManager.tool_changed.connect(func(_d: Dictionary) -> void: _update_tool_visual())
	_update_tool_visual()
	_setup_lantern()
	var skin := preload("res://scripts/player/player_skin.gd").new()
	skin.player = self
	add_child(skin)

func _unhandled_input(event: InputEvent) -> void:
	# Dev cheats (F4/F5) only available in debug builds — never in Steam/app releases
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F4:
				GameManager.money += 100000.0
				GameManager.money_changed.emit(GameManager.money)
				_spawn_floating_text("+$100,000", Color(1.0, 0.85, 0.2))
			KEY_F5:
				fly_mode = not fly_mode
				if fly_mode:
					_spawn_floating_text("FLY MODE ON", Color(0.4, 1.0, 0.4))
				else:
					_spawn_floating_text("FLY MODE OFF", Color(1.0, 0.4, 0.4))

func _physics_process(delta: float) -> void:
	# Fly mode: free movement, no gravity, no collision
	if fly_mode:
		var dir_x: float = Input.get_axis("move_left", "move_right")
		var dir_y: float = Input.get_axis("move_up", "move_down")
		var fly_speed: float = FLY_SPEED
		if Input.is_key_pressed(KEY_SHIFT):
			fly_speed *= 3.0
		position += Vector2(dir_x, dir_y) * fly_speed * delta
		velocity = Vector2.ZERO
		is_walking = false
		return

	# Debug screenshot: park the player at a fixed world X (gravity still settles Y).
	if not is_nan(_shot_camx):
		global_position.x = _shot_camx
		velocity.x = 0.0

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Movement
	var direction: float = Input.get_axis("move_left", "move_right")
	var speed: float = BASE_SPEED * GameManager.get_movement_speed_multiplier()
	var target_vx: float = direction * speed
	var rate: float = ACCEL if direction != 0.0 else FRICTION
	velocity.x = move_toward(velocity.x, target_vx, rate * delta)

	if direction != 0.0:
		facing_right = direction > 0.0
		visual.scale.x = 1.0 if facing_right else -1.0

	is_walking = direction != 0.0 and is_on_floor()

	move_and_slide()

	# Walk animation
	if is_walking:
		walk_time += delta * 8.0
		var walk_sin: float = sin(walk_time)

		# Body bob + squash/stretch
		var bob: float = walk_sin * 2.0
		visual.position.y = bob
		visual.scale.y = 1.0 + cos(walk_time * 2.0) * 0.03

		# Body lean into movement direction
		visual.rotation = direction * 0.03

		# Leg animation with forward/back stride
		var leg_y: float = walk_sin * 3.5
		var leg_x: float = walk_sin * 2.0
		boot_left.position.y = -8.0 + leg_y
		boot_left.position.x = -6.0 + leg_x
		boot_right.position.y = -8.0 - leg_y
		boot_right.position.x = 1.0 - leg_x
		boot_sole_left.position.y = -2.0 + leg_y
		boot_sole_left.position.x = -7.0 + leg_x
		boot_sole_right.position.y = -2.0 - leg_y
		boot_sole_right.position.x = 1.0 - leg_x
		boot_lace_left.position.y = -6.0 + leg_y
		boot_lace_left.position.x = -5.0 + leg_x
		boot_lace_right.position.y = -6.0 - leg_y
		boot_lace_right.position.x = 2.0 - leg_x
		pants_left.position.y = -14.0 + leg_y * 0.5
		pants_left.position.x = -6.0 + leg_x * 0.5
		pants_right.position.y = -14.0 - leg_y * 0.5
		pants_right.position.x = 1.0 - leg_x * 0.5

		# Both arms swing (opposite to their respective legs)
		var arm_left_offset: float = sin(walk_time) * 2.5
		var arm_right_offset: float = sin(walk_time + PI) * 2.5
		arm_left.position.y = -24.0 + arm_left_offset
		hand_left.position.y = -13.0 + arm_left_offset
		arm_right.position.y = -24.0 + arm_right_offset
		hand_right.position.y = -13.0 + arm_right_offset

		# Tool swings with the right arm
		tool_sprite.rotation = sin(walk_time + PI) * 0.2

		# Footstep dust: detect zero-crossings of walk_sin
		if prev_walk_sin > 0.0 and walk_sin <= 0.0:
			# Left foot lands
			_spawn_dust_puff(boot_left.position.x)
			AudioManager.play_footstep()
		elif prev_walk_sin < 0.0 and walk_sin >= 0.0:
			# Right foot lands
			_spawn_dust_puff(boot_right.position.x)
			AudioManager.play_footstep()
		prev_walk_sin = walk_sin
	else:
		walk_time = 0.0
		prev_walk_sin = 0.0
		var breath: float = sin(Time.get_ticks_msec() * 0.003) * 0.6
		visual.position.y = breath
		visual.scale.y = 1.0
		visual.rotation = 0.0
		boot_left.position = Vector2(-6.0, -8.0)
		boot_right.position = Vector2(1.0, -8.0)
		boot_sole_left.position = Vector2(-7.0, -2.0)
		boot_sole_right.position = Vector2(1.0, -2.0)
		boot_lace_left.position = Vector2(-5.0, -6.0)
		boot_lace_right.position = Vector2(2.0, -6.0)
		pants_left.position = Vector2(-6.0, -14.0)
		pants_right.position = Vector2(1.0, -14.0)
		arm_left.position.y = -24.0
		hand_left.position.y = -13.0
		arm_right.position.y = -24.0
		hand_right.position.y = -13.0
		tool_sprite.rotation = 0.0

		# Idle animations (Phase 12c)
		idle_timer += delta
		if idle_timer >= 10.0:
			idle_timer = 0.0
			idle_state = 0
		elif idle_timer >= 6.0 and idle_state < 2:
			idle_state = 2
			# Tap foot
			var tap_tw := create_tween()
			tap_tw.tween_property(boot_right, "position:y", -10.0, 0.1)
			tap_tw.tween_property(boot_right, "position:y", -8.0, 0.1)
			tap_tw.tween_property(boot_right, "position:y", -10.0, 0.1)
			tap_tw.tween_property(boot_right, "position:y", -8.0, 0.1)
		elif idle_timer >= 3.0 and idle_state < 1:
			idle_state = 1
			# Look around
			var look_tw := create_tween()
			look_tw.tween_property(visual, "position:x", 1.5, 0.3)
			look_tw.tween_interval(0.6)
			look_tw.tween_property(visual, "position:x", -1.5, 0.4)
			look_tw.tween_interval(0.6)
			look_tw.tween_property(visual, "position:x", 0.0, 0.3)

	if is_walking:
		idle_timer = 0.0
		idle_state = 0

	# Water drip trail (Phase 12a) — drip when carrying water
	var water_carried: float = GameManager.water_carried
	if water_carried > 0.0 and is_walking:
		drip_timer += delta
		var drip_interval: float = lerpf(0.6, 0.15, clampf(water_carried / GameManager.get_carrying_capacity(), 0.0, 1.0))
		if drip_timer >= drip_interval:
			drip_timer = 0.0
			var drip := ColorRect.new()
			drip.size = Vector2(1, 2)
			drip.color = Color(0.3, 0.55, 0.8, 0.6)
			drip.position = Vector2(randf_range(-3, 3), 0)
			drip.z_index = 2
			add_child(drip)
			var dtw := create_tween()
			dtw.tween_property(drip, "position:y", 4.0, 0.4)
			dtw.parallel().tween_property(drip, "modulate:a", 0.0, 0.5)
			dtw.tween_callback(drip.queue_free)
	else:
		drip_timer = 0.0

	# Speed lines (Phase 16b)
	var speed_mult: float = GameManager.get_movement_speed_multiplier()
	if speed_mult > 1.5 and is_walking:
		speed_line_timer += delta
		var line_interval: float = lerpf(0.15, 0.04, clampf((speed_mult - 1.5) / 3.0, 0.0, 1.0))
		if speed_line_timer >= line_interval:
			speed_line_timer = 0.0
			_spawn_speed_line()
	else:
		speed_line_timer = 0.0

	# Lantern update
	_update_lantern(delta)

	# Scoop cooldown
	if scoop_cooldown_timer > 0.0:
		scoop_cooldown_timer -= delta

	# Stamina regen
	GameManager.regen_stamina(delta)

	# Manual scoop (skip if UI panel is open). A fresh press goes through the full
	# handler (shop/cave entrance/water); HOLDING the key repeats water scooping only,
	# so carrying the button held past a shop or cave entrance never triggers them.
	if scoop_cooldown_timer <= 0.0 and not ui_panel_open:
		if Input.is_action_just_pressed("scoop"):
			_handle_scoop()
		elif Input.is_action_pressed("scoop"):
			_auto_scoop_water()

	# Auto-scoop: only near water/cave pool, only when standing still for 3s, only scoops (never shop/pump/cave)
	var auto_interval: float = GameManager.get_auto_scoop_interval()
	var can_auto_scoop: bool = (near_water and near_swamp_index >= 0) or (near_cave_pool and cave_pool_index >= 0)
	if can_auto_scoop and not is_walking:
		auto_scoop_timer += delta
		if auto_scoop_timer >= 3.0 + auto_interval:
			auto_scoop_timer -= auto_interval
			if scoop_cooldown_timer <= 0.0:
				_auto_scoop_water()
	else:
		auto_scoop_timer = 0.0

func _auto_scoop_water() -> void:
	# Auto-scoop only does water scooping — never triggers shop/pump/cave entrance
	# Cave pools
	if near_cave_pool and cave_pool_index >= 0:
		if GameManager.try_scoop_cave_pool(cave_pool_cave_id, cave_pool_index):
			scoop_cooldown_timer = SCOOP_COOLDOWN
			_scoop_feedback()
		return
	# Overworld water
	if not near_water or near_swamp_index < 0:
		return
	if GameManager.current_tool_id == "hose":
		GameManager.try_activate_hose(near_swamp_index)
		return
	if GameManager.try_scoop(near_swamp_index):
		scoop_cooldown_timer = SCOOP_COOLDOWN
		_scoop_feedback()

func _handle_scoop() -> void:
	if near_cave_entrance and near_cave_id != "":
		cave_entrance_requested.emit(near_cave_id)
		scoop_cooldown_timer = SCOOP_COOLDOWN
		return
	if near_cave_pool and cave_pool_index >= 0:
		if GameManager.try_scoop_cave_pool(cave_pool_cave_id, cave_pool_index):
			scoop_cooldown_timer = SCOOP_COOLDOWN
			_scoop_feedback()
		elif GameManager.is_inventory_full():
			_spawn_floating_text("FULL!", Color(1.0, 0.4, 0.3))
			AudioManager.play_error()
			scoop_cooldown_timer = SCOOP_COOLDOWN
		elif GameManager.current_stamina < GameManager.get_stamina_cost():
			_spawn_floating_text("No Stamina!", Color(1.0, 0.3, 0.3))
			_flash_red()
			AudioManager.play_error()
			scoop_cooldown_timer = SCOOP_COOLDOWN
		return
	if near_shop:
		shop_requested.emit()
		scoop_cooldown_timer = SCOOP_COOLDOWN
		return
	if GameManager.current_tool_id == "hose":
		if near_water and near_swamp_index >= 0:
			GameManager.try_activate_hose(near_swamp_index)
		return
	if not near_water or near_swamp_index < 0:
		return
	if GameManager.try_scoop(near_swamp_index):
		scoop_cooldown_timer = SCOOP_COOLDOWN
		_scoop_feedback()
	elif GameManager.is_inventory_full():
		_spawn_floating_text("FULL!", Color(1.0, 0.4, 0.3))
		scoop_cooldown_timer = SCOOP_COOLDOWN
	elif GameManager.current_stamina < GameManager.get_stamina_cost():
		_spawn_floating_text("No Stamina!", Color(1.0, 0.3, 0.3))
		_flash_red()
		scoop_cooldown_timer = SCOOP_COOLDOWN

func _scoop_feedback() -> void:
	# Flash the sprite
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	visual.modulate = Color(2.0, 2.0, 2.0)
	flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.15)

	# Scoop arm animation
	scooped.emit()
	var scoop_tween := create_tween()
	scoop_tween.tween_property(arm_right, "rotation", -0.5, 0.08)
	scoop_tween.tween_property(arm_right, "rotation", 0.0, 0.12)

	# Tool swings with the scoop
	if tool_tween and tool_tween.is_valid():
		tool_tween.kill()
	tool_tween = create_tween()
	tool_tween.tween_property(tool_sprite, "rotation", -0.7, 0.08)
	tool_tween.tween_property(tool_sprite, "rotation", 0.0, 0.12)

	# Show gallons actually collected (blue) — honest amount, not raw tool output
	var output: float = GameManager.last_scoop_gallons
	var gal_text: String
	if output >= 10.0:
		gal_text = "+%.1f gal" % output
	elif output >= 1.0:
		gal_text = "+%.2f gal" % output
	else:
		gal_text = "+%.4f gal" % output
	_spawn_floating_text(gal_text, Color(0.4, 0.8, 1.0))

	# Splash particles
	_spawn_splash()

func _flash_red() -> void:
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	visual.modulate = Color(2.0, 0.3, 0.3)
	flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.25)

## Splash droplet palette — matches scripts/world/water_skin.gd's CLEAR bands
## (surf/hi) so scoop splash reads as the same water as the basins, not a
## generic flat sky-blue. 2026-09-11 review: dots were several art px across
## (several TIMES the art grid) and pure flat blue; now 1-2 art px, water-teal,
## with a light highlight variant for sparkle.
const SPLASH_MAIN := Color(0.18, 0.60, 0.58, 1.0)
const SPLASH_DEEP := Color(0.10, 0.42, 0.46, 1.0)
const SPLASH_HI := Color(0.74, 0.90, 0.78, 1.0)

func _spawn_splash() -> void:
	var tid: String = GameManager.current_tool_id
	var count: int = 4
	var spread_x: float = 8.0
	var spread_y: float = 10.0
	var dot_size: float = 1.0
	var life: float = 0.28
	var shake_amount: float = 0.0

	match tid:
		"hands":
			count = 3
			spread_x = 5.0
			spread_y = 6.0
			life = 0.22
		"spoon":
			count = 4
			spread_x = 6.0
			spread_y = 8.0
			life = 0.24
		"cup":
			count = 5
			spread_x = 7.0
			spread_y = 9.0
			life = 0.26
		"bucket":
			count = 8
			spread_x = 10.0
			spread_y = 13.0
			dot_size = 2.0
			life = 0.32
			shake_amount = 1.0
		"shovel":
			count = 10
			spread_x = 11.0
			spread_y = 14.0
			dot_size = 2.0
			life = 0.32
			shake_amount = 1.5
		"wheelbarrow":
			count = 14
			spread_x = 13.0
			spread_y = 16.0
			dot_size = 2.0
			life = 0.36
			shake_amount = 2.0
		"barrel":
			count = 18
			spread_x = 15.0
			spread_y = 18.0
			dot_size = 2.0
			life = 0.38
			shake_amount = 2.5
		"water_wagon":
			count = 24
			spread_x = 17.0
			spread_y = 20.0
			dot_size = 2.0
			life = 0.4
			shake_amount = 3.0
		"hose":
			count = 8
			spread_x = 12.0
			spread_y = 4.0
			life = 0.22

	# Screen shake via camera
	if shake_amount > 0.0:
		var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
		if cam:
			var shake_tw := create_tween()
			shake_tw.tween_property(cam, "offset", Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount)), 0.05)
			shake_tw.tween_property(cam, "offset", Vector2.ZERO, 0.1)

	for i in range(count):
		var dot := ColorRect.new()
		var sz: float = dot_size if randf() > 0.35 else maxf(1.0, dot_size - 1.0)
		dot.size = Vector2(sz, sz)
		dot.color = SPLASH_HI if randf() < 0.2 else (SPLASH_MAIN if randf() < 0.7 else SPLASH_DEEP)
		var start: Vector2 = Vector2(randf_range(-spread_x * 0.5, spread_x * 0.5), -4)
		dot.position = start
		dot.z_index = 8
		add_child(dot)

		# A few ms of stagger so a big splash (water_wagon: 24 dots) fans out
		# from the first frame instead of drawing as one solid bar of dots
		# all moving in lockstep.
		var delay: float = randf_range(0.0, 0.05)
		# Short ballistic arc: rise (ease out) then fall (ease in), fading the
		# whole way — a real arc + fade instead of one straight random hop.
		var side: float = randf_range(-spread_x, spread_x)
		var peak: Vector2 = start + Vector2(side * 0.4, -spread_y)
		var land: Vector2 = start + Vector2(side, randf_range(-1.0, 2.0))
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(dot, "position", peak, life * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(dot, "position", land, life * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(dot.queue_free)
		# Fade must finish by the time the position tween above frees the dot
		# (delay + life), so keep delay+duration <= life.
		var fade_tw := create_tween()
		fade_tw.tween_interval(delay + life * 0.15)
		fade_tw.tween_property(dot, "modulate:a", 0.0, life * 0.85)

	# Shovel-specific: dirt chunk particles
	if tid == "shovel":
		for i in range(4):
			var dirt := ColorRect.new()
			dirt.size = Vector2(2, 2)
			dirt.color = Color(0.45, 0.35, 0.2, 0.7)
			dirt.position = Vector2(randf_range(-8, 8), -2)
			dirt.z_index = 7
			add_child(dirt)
			var dtw := create_tween()
			dtw.tween_property(dirt, "position", dirt.position + Vector2(randf_range(-12, 12), randf_range(-10, 6)), 0.45)
			dtw.parallel().tween_property(dirt, "modulate:a", 0.0, 0.45)
			dtw.tween_callback(dirt.queue_free)

func _update_tool_visual() -> void:
	# Tool equip animation (Phase 12d): shrink old, grow new
	var had_tool: bool = tool_visuals.size() > 0
	for v in tool_visuals:
		if is_instance_valid(v):
			v.queue_free()
	tool_visuals.clear()

	# Animate tool sprite: shrink then grow
	tool_sprite.scale = Vector2(0.0, 0.0)
	var equip_tw := create_tween()
	equip_tw.set_ease(Tween.EASE_OUT)
	equip_tw.set_trans(Tween.TRANS_BACK)
	equip_tw.tween_property(tool_sprite, "scale", Vector2(1.0, 1.0), 0.15 if had_tool else 0.2)

	var tool_id: String = GameManager.current_tool_id
	match tool_id:
		"hands":
			# No tool visual — bare hands
			pass
		"spoon":
			var handle := ColorRect.new()
			handle.size = Vector2(2, 10)
			handle.position = Vector2(0, -4)
			handle.color = Color(0.7, 0.7, 0.7)
			tool_sprite.add_child(handle)
			tool_visuals.append(handle)
			var bowl := ColorRect.new()
			bowl.size = Vector2(4, 4)
			bowl.position = Vector2(-1, 6)
			bowl.color = Color(0.8, 0.8, 0.8)
			tool_sprite.add_child(bowl)
			tool_visuals.append(bowl)
		"cup":
			var body := ColorRect.new()
			body.size = Vector2(6, 8)
			body.position = Vector2(-2, 0)
			body.color = Color(0.85, 0.85, 0.9)
			tool_sprite.add_child(body)
			tool_visuals.append(body)
			var rim := ColorRect.new()
			rim.size = Vector2(8, 2)
			rim.position = Vector2(-3, -2)
			rim.color = Color(0.75, 0.75, 0.8)
			tool_sprite.add_child(rim)
			tool_visuals.append(rim)
		"bucket":
			var body := ColorRect.new()
			body.size = Vector2(8, 10)
			body.position = Vector2(-4, -2)
			body.color = Color(0.45, 0.45, 0.5)
			tool_sprite.add_child(body)
			tool_visuals.append(body)
			var handle := ColorRect.new()
			handle.size = Vector2(12, 2)
			handle.position = Vector2(-6, -6)
			handle.color = Color(0.55, 0.55, 0.6)
			tool_sprite.add_child(handle)
			tool_visuals.append(handle)
			var rim := ColorRect.new()
			rim.size = Vector2(10, 2)
			rim.position = Vector2(-5, -2)
			rim.color = Color(0.5, 0.5, 0.55)
			tool_sprite.add_child(rim)
			tool_visuals.append(rim)
		"shovel":
			var shaft := ColorRect.new()
			shaft.size = Vector2(2, 14)
			shaft.position = Vector2(0, -6)
			shaft.color = Color(0.55, 0.35, 0.15)
			tool_sprite.add_child(shaft)
			tool_visuals.append(shaft)
			var blade := ColorRect.new()
			blade.size = Vector2(8, 6)
			blade.position = Vector2(-3, 8)
			blade.color = Color(0.55, 0.55, 0.6)
			tool_sprite.add_child(blade)
			tool_visuals.append(blade)
			var edge := ColorRect.new()
			edge.size = Vector2(8, 2)
			edge.position = Vector2(-3, 14)
			edge.color = Color(0.7, 0.7, 0.75)
			tool_sprite.add_child(edge)
			tool_visuals.append(edge)
		"wheelbarrow":
			var tray := ColorRect.new()
			tray.size = Vector2(12, 8)
			tray.position = Vector2(-6, -2)
			tray.color = Color(0.45, 0.5, 0.45)
			tool_sprite.add_child(tray)
			tool_visuals.append(tray)
			var wheel := ColorRect.new()
			wheel.size = Vector2(4, 4)
			wheel.position = Vector2(-2, 6)
			wheel.color = Color(0.3, 0.3, 0.35)
			tool_sprite.add_child(wheel)
			tool_visuals.append(wheel)
			var leg := ColorRect.new()
			leg.size = Vector2(2, 6)
			leg.position = Vector2(4, 2)
			leg.color = Color(0.5, 0.35, 0.15)
			tool_sprite.add_child(leg)
			tool_visuals.append(leg)
		"barrel":
			var body := ColorRect.new()
			body.size = Vector2(10, 14)
			body.position = Vector2(-5, -4)
			body.color = Color(0.5, 0.3, 0.12)
			tool_sprite.add_child(body)
			tool_visuals.append(body)
			var band_top := ColorRect.new()
			band_top.size = Vector2(12, 2)
			band_top.position = Vector2(-6, -2)
			band_top.color = Color(0.45, 0.45, 0.5)
			tool_sprite.add_child(band_top)
			tool_visuals.append(band_top)
			var band_bot := ColorRect.new()
			band_bot.size = Vector2(12, 2)
			band_bot.position = Vector2(-6, 8)
			band_bot.color = Color(0.45, 0.45, 0.5)
			tool_sprite.add_child(band_bot)
			tool_visuals.append(band_bot)
		"water_wagon":
			var tank := ColorRect.new()
			tank.size = Vector2(16, 10)
			tank.position = Vector2(-8, -6)
			tank.color = Color(0.5, 0.3, 0.12)
			tool_sprite.add_child(tank)
			tool_visuals.append(tank)
			var band := ColorRect.new()
			band.size = Vector2(16, 2)
			band.position = Vector2(-8, -2)
			band.color = Color(0.45, 0.45, 0.5)
			tool_sprite.add_child(band)
			tool_visuals.append(band)
			var wheel_l := ColorRect.new()
			wheel_l.size = Vector2(4, 4)
			wheel_l.position = Vector2(-7, 4)
			wheel_l.color = Color(0.3, 0.3, 0.35)
			tool_sprite.add_child(wheel_l)
			tool_visuals.append(wheel_l)
			var wheel_r := ColorRect.new()
			wheel_r.size = Vector2(4, 4)
			wheel_r.position = Vector2(3, 4)
			wheel_r.color = Color(0.3, 0.3, 0.35)
			tool_sprite.add_child(wheel_r)
			tool_visuals.append(wheel_r)
		"hose":
			var nozzle := ColorRect.new()
			nozzle.size = Vector2(10, 4)
			nozzle.position = Vector2(-2, -2)
			nozzle.color = Color(0.2, 0.55, 0.2)
			tool_sprite.add_child(nozzle)
			tool_visuals.append(nozzle)
			var pipe := ColorRect.new()
			pipe.size = Vector2(4, 8)
			pipe.position = Vector2(-2, 2)
			pipe.color = Color(0.25, 0.5, 0.25)
			tool_sprite.add_child(pipe)
			tool_visuals.append(pipe)

func show_floating_text(text: String, color: Color = Color(0.3, 1.0, 0.4)) -> void:
	_spawn_floating_text(text, color)

func _spawn_floating_text(text: String, color: Color = Color(0.3, 1.0, 0.4)) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.position = Vector2(-28, -48)
	label.z_index = 10
	label.pivot_offset = Vector2(28, 8)
	label.scale = Vector2(0.5, 0.5)
	add_child(label)

	var tween := create_tween()
	# Pop-in scale: 0.5 → 1.2 → 1.0
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - 32, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func set_near_shop(value: bool) -> void:
	near_shop = value

func set_near_water(value: bool, swamp_index: int = -1) -> void:
	if value:
		near_water = true
		near_swamp_index = swamp_index
	else:
		if swamp_index == near_swamp_index:
			near_water = false
			near_swamp_index = -1

func set_near_cave_entrance(value: bool, cave_id: String = "") -> void:
	if value:
		near_cave_entrance = true
		near_cave_id = cave_id
	else:
		if cave_id == near_cave_id:
			near_cave_entrance = false
			near_cave_id = ""

func set_near_cave_pool(value: bool, cave_id: String = "", pool_index: int = -1) -> void:
	if value:
		near_cave_pool = true
		cave_pool_cave_id = cave_id
		cave_pool_index = pool_index
	else:
		if cave_id == cave_pool_cave_id and pool_index == cave_pool_index:
			near_cave_pool = false
			cave_pool_cave_id = ""
			cave_pool_index = -1

func _setup_lantern() -> void:
	# PointLight2D for warm glow
	lantern_light = PointLight2D.new()
	lantern_light.color = Color(1.0, 0.85, 0.5)
	lantern_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	lantern_light.shadow_enabled = false
	lantern_light.position = Vector2(0, -20)
	lantern_light.enabled = false

	# Create 256x256 radial gradient texture programmatically
	var gradient := GradientTexture2D.new()
	gradient.width = 256
	gradient.height = 256
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.4, Color(0.6, 0.6, 0.6, 0.6))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	gradient.gradient = grad
	lantern_light.texture = gradient
	add_child(lantern_light)

	# Lantern sprite node (child of Visual so it flips with facing)
	lantern_node = Node2D.new()
	lantern_node.z_index = 9
	lantern_node.position = Vector2(-10, -14)
	lantern_node.visible = false
	visual.add_child(lantern_node)

	# Handle wire
	var wire := ColorRect.new()
	wire.size = Vector2(1, 4)
	wire.position = Vector2(1, -4)
	wire.color = Color(0.6, 0.5, 0.3)
	lantern_node.add_child(wire)

	# Top cap
	var cap := ColorRect.new()
	cap.size = Vector2(4, 2)
	cap.position = Vector2(0, 0)
	cap.color = Color(0.45, 0.38, 0.2)
	lantern_node.add_child(cap)

	# Glass body
	lantern_glass = ColorRect.new()
	lantern_glass.size = Vector2(4, 5)
	lantern_glass.position = Vector2(0, 2)
	lantern_glass.color = Color(1.0, 0.85, 0.5, 0.7)
	lantern_node.add_child(lantern_glass)

	# Base
	var base := ColorRect.new()
	base.size = Vector2(6, 2)
	base.position = Vector2(-1, 7)
	base.color = Color(0.45, 0.38, 0.2)
	lantern_node.add_child(base)

	# Flame core
	lantern_flame = ColorRect.new()
	lantern_flame.size = Vector2(2, 3)
	lantern_flame.position = Vector2(1, 3)
	lantern_flame.color = Color(1.0, 0.95, 0.4)
	lantern_node.add_child(lantern_flame)

func _update_lantern(delta: float) -> void:
	var lantern_level: int = GameManager.upgrades_owned["lantern"]
	if _dbg_lantern:
		lantern_level = 1
	var darkness: float = GameManager.get_darkness_factor()
	var should_be_active: bool = lantern_level > 0 and darkness > 0.05

	if should_be_active != lantern_active:
		lantern_active = should_be_active
		lantern_node.visible = lantern_active
		lantern_light.enabled = lantern_active

	if not lantern_active:
		return

	lantern_flicker_time += delta

	# Flame flicker: three incommensurate sinusoids for natural feel
	var flicker: float = 1.0 + sin(lantern_flicker_time * 12.0) * 0.08 + sin(lantern_flicker_time * 7.3) * 0.05 + sin(lantern_flicker_time * 19.7) * 0.03

	# Scale energy by darkness factor (gentle at dusk, full at night)
	var base_energy: float = 3.0 if _dbg_lantern else GameManager.get_lantern_energy()
	lantern_light.energy = base_energy * darkness * flicker

	# Texture scale: radius to texture mapping
	var radius: float = 200.0 if _dbg_lantern else GameManager.get_lantern_radius()
	lantern_light.texture_scale = (radius * 2.0) / 256.0 * 0.88

	# Animate flame color and size (overbright on HDR so it blooms into a warm halo)
	var flame_brightness: float = 0.85 + flicker * 0.15
	var flame_boost: float = 1.7 if _hdr_glow else 1.0
	lantern_flame.color = Color(flame_boost, 0.95 * flame_brightness * flame_boost, 0.4 * flame_brightness * flame_boost)
	lantern_flame.size.y = 3.0 + sin(lantern_flicker_time * 12.0) * 0.5

	# Animate glass glow intensity
	var glass_alpha: float = 0.5 + darkness * 0.3 * flicker
	var glass_boost: float = 1.3 if _hdr_glow else 1.0
	lantern_glass.color = Color(glass_boost, 0.85 * glass_boost, 0.5 * glass_boost, glass_alpha)

	# Slight position wobble for organic feel
	lantern_light.position.x = sin(lantern_flicker_time * 3.1) * 0.5
	lantern_light.position.y = -20.0 + sin(lantern_flicker_time * 2.7) * 0.3

	# Walk animation integration: sway with arm
	if is_walking:
		var arm_offset: float = sin(walk_time) * 2.5
		lantern_node.position.y = -14.0 + arm_offset
		lantern_node.rotation = sin(walk_time) * 0.12
	else:
		lantern_node.position.y = -14.0
		lantern_node.rotation = 0.0

func _spawn_dust_puff(foot_x: float) -> void:
	var sizes: Array[Vector2] = [Vector2(6, 5), Vector2(5, 5), Vector2(7, 4)]
	for i in range(3):
		var puff := ColorRect.new()
		puff.size = sizes[i]
		var r_var: float = randf_range(-0.05, 0.05)
		puff.color = Color(0.72 + r_var, 0.64 + r_var, 0.50 + r_var, 0.65)
		puff.position = Vector2(foot_x + randf_range(-2, 2), -2 + randf_range(-1, 1))
		puff.z_index = 2
		add_child(puff)

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "size", puff.size + Vector2(4, 3), 0.5)
		tw.tween_property(puff, "position", puff.position + Vector2(randf_range(-4, 4), randf_range(-12, -5)), 0.6)
		tw.tween_property(puff, "modulate:a", 0.0, 0.6)
		tw.set_parallel(false)
		tw.tween_callback(puff.queue_free)

func _spawn_speed_line() -> void:
	var line := ColorRect.new()
	line.size = Vector2(randf_range(6, 14), 1)
	var dir_offset: float = -12.0 if facing_right else 12.0
	line.position = Vector2(dir_offset + randf_range(-4, 4), randf_range(-20, 4))
	line.color = Color(1.0, 1.0, 1.0, 0.25)
	line.z_index = 2
	add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.15)
	tw.tween_callback(line.queue_free)
