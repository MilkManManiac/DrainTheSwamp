extends Node2D
# v3 pixel-art props (2026-09-11): pumps, camels, island mansion + politicians,
# government helicopter, wanted poster. Same rule as skin.gd / player_skin.gd:
# the old state machines, timers, Areas and signals in game_world.gd keep
# running; only the visual children change. Where the old builder's root node
# is needed by gameplay (camels, politicians, helicopter, wanted poster) the old
# ColorRect/Polygon2D children are hidden and a Sprite2D strip is added under
# the same root, so the old flips / bobs / tweens still drive it. Where nothing
# else reads the visuals (pumps, island house) the old builder is switched off
# with V3_PROPS in game_world.gd and rebuilt here.
#
# Art: assets/art/drainsville/prop_*.png, baked from assets/gen/prop-*.{jpg,png}
# via tools/bake/bake.py (1 art px = 1 world unit; sprites at SCALE 0.5).
#
# Debug (DTS_SHOT captures only): env DTS_PROPS="pumps,camels,heli" draws
# preview pumps on every basin, a preview camel pair near town and a parked
# helicopter without touching GameManager state.

const ART := "res://assets/art/drainsville/"
const SCALE := 0.5
const ISLAND_CX := 5660.0
const ISLAND_Y := 484.0
# frames per strip, written by the bake step (see docs/plans/revamp-tracks/props.md)
const FRAMES := {
	"prop_pump_small": 3, "prop_pump_big": 3,
	"prop_camel": 4, "prop_camel_loaded": 4,
	"prop_politicians_a": 7, "prop_politicians_b": 7,
	"prop_helicopter": 2,
}
const PUMP_BIG_LEVEL := 5           # level >= this swaps to the industrial pump
const CAMEL_WALK_FPS := 7.0
const HELI_ROTOR_FPS := 14.0
const POLI_IDLE_FPS := 1.5
const POLI_SPACING := 14.0          # old roots sit 8 apart; sprites are ~14 wide

var world: Node2D = null
var _pumps: Dictionary = {}          # swamp_index -> {sprite, t, level}
var _camel_t: float = 0.0
var _heli: Node2D = null
var _heli_sprite: Sprite2D = null
var _heli_t: float = 0.0
var _poli: Array = []                # [{sprite, a, b, phase}]
var _poli_t: float = 0.0
var _tex_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_deferred("_build")

func _tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path: String = ART + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[name] = t
	return t

# Bottom-center anchored strip under `parent`, frame cells FRAMES[name] wide.
func _strip(name: String, parent: Node, z: int = 0, offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	var t: Texture2D = _tex(name)
	if t == null:
		return null
	var n: int = FRAMES.get(name, 1)
	var s := Sprite2D.new()
	s.name = "V3_" + name
	s.texture = t
	s.hframes = n
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(SCALE, SCALE)
	s.centered = true
	s.position = Vector2(0.0, -t.get_height() * SCALE * 0.5) + offset
	s.z_index = z
	parent.add_child(s)
	return s

func _hide_old(root: Node) -> void:
	for c in root.get_children():
		if c is CanvasItem and not (c is Light2D) and not (c.name as String).begins_with("V3_"):
			(c as CanvasItem).visible = false

func _build() -> void:
	if world == null:
		return
	_build_pumps()
	_build_island()
	_skin_politicians()
	_skin_wanted_poster()
	_debug_previews()

# --- pumps ------------------------------------------------------------------
# Old builder is gated off (V3_PROPS); world.pump_props still maps index -> root
# for parity. Rebuilt on GameManager.pump_changed like before.
func _build_pumps() -> void:
	for idx in GameManager.pump_levels.keys():
		build_pump(idx, GameManager.get_pump_level(idx))
	GameManager.pump_changed.connect(func(idx: int, level: int) -> void: build_pump(idx, level))

func build_pump(swamp_index: int, level: int) -> void:
	if world.pump_props.has(swamp_index):
		var old: Node2D = world.pump_props[swamp_index]
		if is_instance_valid(old):
			old.queue_free()
		world.pump_props.erase(swamp_index)
	_pumps.erase(swamp_index)
	if level <= 0:
		return
	var geo: Dictionary = world._get_swamp_geometry(swamp_index)
	var rim: Vector2 = geo["entry_top"]
	var basin: Vector2 = geo["basin_left"]
	var root := Node2D.new()
	root.position = Vector2(rim.x + 6.0, rim.y)
	root.z_index = 5   # above water walls (z 0) and the per-pool murk tint (skin.gd, z 4)
	add_child(root)
	world.pump_props[swamp_index] = root
	var big: bool = level >= PUMP_BIG_LEVEL
	var name: String = "prop_pump_big" if big else "prop_pump_small"
	var spr: Sprite2D = _strip(name, root)
	if spr == null:
		return
	# The bake keeps the source's dark rust palette, which all but disappears
	# against the pit's near-black interior; lift it a little so the housing
	# reads at a glance without breaking the palette.
	spr.modulate = Color(1.35, 1.28, 1.18)
	var w: float = spr.texture.get_width() / float(spr.hframes) * SCALE
	var h: float = spr.texture.get_height() * SCALE
	# Intake hose: outlet on the basin side of the housing, arcing over the rim
	# and down into the water. 2 art px dark rubber with a 1 px highlight.
	var p0 := Vector2(w * 0.35, -h * 0.55)
	var p3 := Vector2(basin.x - root.position.x + 4.0, basin.y - root.position.y - 2.0)
	var p1 := Vector2(p0.x + 8.0, p0.y - 5.0)
	var p2 := Vector2(p3.x - 4.0, p3.y - 10.0)
	var pts := PackedVector2Array()
	for i in range(9):
		var t: float = float(i) / 8.0
		var q: Vector2 = p0.bezier_interpolate(p1, p2, p3, t)
		pts.append(Vector2(roundf(q.x), roundf(q.y)))
	var hose := Line2D.new()
	hose.name = "V3_hose"
	hose.points = pts
	hose.width = 2.0
	hose.default_color = Color(0.13, 0.12, 0.11)
	hose.joint_mode = Line2D.LINE_JOINT_BEVEL
	hose.z_index = -1
	root.add_child(hose)
	var hose_hi := Line2D.new()
	hose_hi.name = "V3_hose_hi"
	var hi_pts := PackedVector2Array()
	for q in pts:
		hi_pts.append(q + Vector2(0.0, -1.0))
	hose_hi.points = hi_pts
	hose_hi.width = 1.0
	hose_hi.default_color = Color(0.34, 0.33, 0.30)
	hose_hi.z_index = -1
	root.add_child(hose_hi)
	# Status lamp (1 art px, blinks) + level pips along the skid, as before.
	var lamp := ColorRect.new()
	lamp.name = "V3_lamp"
	lamp.position = Vector2(-w * 0.5 + 1.0, -h + 2.0)
	lamp.size = Vector2(1, 1)
	lamp.color = Color(0.45, 1.0, 0.55)
	if world.has_method("_emit"):
		lamp.color = world._emit(Color(0.3, 1.0, 0.45), 1.6)
	root.add_child(lamp)
	var tw := create_tween().set_loops()
	tw.tween_property(lamp, "modulate:a", 0.2, 0.7)
	tw.tween_property(lamp, "modulate:a", 1.0, 0.7)
	for i in range(mini(level, GameManager.PUMP_MAX_LEVEL)):
		var pip := ColorRect.new()
		pip.name = "V3_pip%d" % i
		pip.position = Vector2(-w * 0.5 + 1.0 + float(i) * 2.0, 1.0)
		pip.size = Vector2(1, 1)
		pip.color = Color(0.55, 0.85, 0.95)
		root.add_child(pip)
	_pumps[swamp_index] = {"sprite": spr, "t": randf() * 3.0, "level": level}

func _tick_pumps(dt: float) -> void:
	for idx in _pumps.keys():
		var pd: Dictionary = _pumps[idx]
		var spr: Sprite2D = pd["sprite"]
		if not is_instance_valid(spr):
			continue
		# Piston: 0-1-2-1 loop, faster with level.
		var fps: float = 3.0 + float(pd["level"]) * 0.4
		pd["t"] += dt * fps
		var seq: Array = [0, 1, 2, 1]
		spr.frame = seq[int(pd["t"]) % 4] % spr.hframes

# --- island: mansion + dock ----------------------------------------------------
func _build_island() -> void:
	var t: Texture2D = _tex("prop_mansion")
	if t:
		# The island's flat top is only 40 wide; fill dark earth under the wider
		# foundation down to the shore slopes so it never floats (fill, not art).
		var mw: float = t.get_width() * SCALE
		var fill := Polygon2D.new()
		fill.name = "V3_island_fill"
		var poly := PackedVector2Array()
		poly.append(Vector2(ISLAND_CX - mw * 0.5 + 6.0, ISLAND_Y + 1.0))
		poly.append(Vector2(ISLAND_CX + mw * 0.5 - 6.0, ISLAND_Y + 1.0))
		poly.append(Vector2(ISLAND_CX + mw * 0.5 - 6.0, ISLAND_Y + 40.0))
		poly.append(Vector2(ISLAND_CX - mw * 0.5 + 6.0, ISLAND_Y + 40.0))
		fill.polygon = poly
		fill.color = Color(0.20, 0.15, 0.10)
		fill.z_index = -3
		add_child(fill)
		var s := Sprite2D.new()
		s.name = "V3_mansion"
		s.texture = t
		s.centered = false
		s.scale = Vector2(SCALE, SCALE)
		s.position = Vector2(ISLAND_CX - t.get_width() * SCALE * 0.5, ISLAND_Y + 2.0 - t.get_height() * SCALE)
		s.z_index = -2
		add_child(s)
	# Dock: town boardwalk planks on pilings running down the west shore.
	var bw: Texture2D = _tex("boardwalk")
	var pil: Texture2D = _tex("piling")
	if bw == null:
		return
	var step: float = bw.get_width() * SCALE
	var x: float = ISLAND_CX - 40.0 - step * 3.0
	var i := 0
	var deck_y: float = ISLAND_Y + 1.0
	while x < ISLAND_CX - 40.0:
		var plank := Sprite2D.new()
		plank.name = "V3_plank%d" % i
		plank.texture = bw
		plank.centered = false
		plank.scale = Vector2(SCALE, SCALE)
		plank.position = Vector2(x, deck_y - 3.0)
		plank.z_index = -1
		add_child(plank)
		if pil and i % 2 == 0:
			var gy: float = world._get_terrain_y_at(x + 2.0)
			var post := Sprite2D.new()
			post.name = "V3_piling%d" % i
			post.texture = pil
			post.centered = false
			post.scale = Vector2(SCALE, SCALE)
			post.position = Vector2(x + 2.0 - pil.get_width() * SCALE * 0.5, deck_y)
			# stretch to the shore below, in whole art px
			var need: float = maxf(gy + 6.0 - deck_y, 4.0)
			post.scale.y = SCALE * maxf(1.0, roundf(need / (pil.get_height() * SCALE)))
			post.z_index = -2
			add_child(post)
		x += step
		i += 1

# --- politicians: old roots + Area kept, figures swapped ------------------------
func _skin_politicians() -> void:
	var a: Texture2D = _tex("prop_politicians_a")
	if a == null:
		return
	var b: Texture2D = _tex("prop_politicians_b")
	var nodes: Array = world.politician_nodes
	for i in range(nodes.size()):
		var pn: Node2D = nodes[i]
		if not is_instance_valid(pn):
			continue
		_hide_old(pn)
		var fi: int = i % FRAMES["prop_politicians_a"]
		var off := Vector2((float(i) - float(nodes.size() - 1) * 0.5) * (POLI_SPACING - 8.0), 0.0)
		var s: Sprite2D = _strip("prop_politicians_a", pn, -pn.z_index - 1, off)
		s.frame = fi
		if i % 2 == 1:
			s.flip_h = true
		_poli.append({"sprite": s, "a": a, "b": b, "frame": fi, "phase": randf() * 2.0})

func _tick_politicians(dt: float) -> void:
	if _poli.is_empty():
		return
	_poli_t += dt
	for pd in _poli:
		var s: Sprite2D = pd["sprite"]
		if not is_instance_valid(s):
			continue
		var beat: int = int((_poli_t + pd["phase"]) * POLI_IDLE_FPS) % 2
		if pd["b"] != null:
			s.texture = pd["b"] if beat == 1 else pd["a"]
			s.hframes = FRAMES["prop_politicians_b"] if beat == 1 else FRAMES["prop_politicians_a"]
			s.frame = pd["frame"] % s.hframes
		else:
			s.position.y = roundf(-s.texture.get_height() * SCALE * 0.5) - float(beat)

# --- camels: game_world rebuilds the roots on camel_changed; we notice new dicts
# each frame and skin them (hide the ColorRects, add the strip).
func _tick_camels(dt: float) -> void:
	_camel_t += dt
	var cap: float = GameManager.get_camel_capacity()
	for i in range(world.camels.size()):
		var cd: Dictionary = world.camels[i]
		var node: Node2D = cd["node"]
		if not is_instance_valid(node):
			continue
		if not cd.has("v3"):
			_hide_old(node)
			var s: Sprite2D = _strip("prop_camel", node)
			if s == null:
				return
			cd["v3"] = s
			cd["v3_phase"] = randf()
		var spr: Sprite2D = cd["v3"]
		var loaded: bool = false
		if i < GameManager.camel_states.size():
			var cs: Dictionary = GameManager.camel_states[i]
			loaded = cap > 0.0 and float(cs["water_carried"]) / cap > 0.05
			var walking: bool = cs["state"] == "to_player" or cs["state"] == "to_shop"
			var want: String = "prop_camel_loaded" if loaded and _tex("prop_camel_loaded") else "prop_camel"
			if spr.texture != _tex(want):
				spr.texture = _tex(want)
				spr.hframes = FRAMES[want]
				spr.position.y = -spr.texture.get_height() * SCALE * 0.5
			if walking:
				spr.frame = int((_camel_t + cd["v3_phase"]) * CAMEL_WALK_FPS) % spr.hframes
			else:
				spr.frame = 0

# --- helicopter: root + flight path stay in game_world; we add the strip --------
func _tick_helicopter(dt: float) -> void:
	var h: Node2D = world.helicopter_active
	if h == null or not is_instance_valid(h):
		_heli = null
		_heli_sprite = null
		return
	if h != _heli:
		_heli = h
		_hide_old(h)
		_heli_sprite = _strip("prop_helicopter", h)
		if _heli_sprite:
			_heli_sprite.position = Vector2.ZERO   # old body was centred on the root
	if _heli_sprite and is_instance_valid(_heli_sprite):
		_heli_t += dt
		_heli_sprite.frame = int(_heli_t * HELI_ROTOR_FPS) % _heli_sprite.hframes

# --- wanted poster on the Hardware wall ----------------------------------------
func _skin_wanted_poster() -> void:
	var wp: Node2D = world.wanted_poster
	if wp == null or not is_instance_valid(wp):
		return
	var t: Texture2D = _tex("prop_wanted")
	if t == null:
		return
	_hide_old(wp)
	wp.rotation_degrees = 0.0   # art grid: no odd-angle rotation on pixel art
	var s := Sprite2D.new()
	s.name = "V3_wanted"
	s.texture = t
	s.centered = true
	s.scale = Vector2(SCALE, SCALE)
	s.z_index = 0
	wp.add_child(s)

# --- debug previews for captures -------------------------------------------------
func _debug_previews() -> void:
	if OS.get_environment("DTS_SHOT") == "":
		return
	var want: String = OS.get_environment("DTS_PROPS")
	if want == "":
		return
	if "pumps" in want:
		for idx in range(world.SWAMP_COUNT):
			if not world.pump_props.has(idx):
				build_pump(idx, 2 if idx % 2 == 0 else 7)
	if "camels" in want:
		var cx: float = 1080.0
		var cxs: String = OS.get_environment("DTS_CAMX")
		if cxs != "":
			cx = cxs.to_float() + 60.0
		for k in range(2):
			var n := Node2D.new()
			var x: float = cx + float(k) * 70.0
			n.position = Vector2(x, world._get_terrain_y_at(x))
			n.z_index = 5
			n.scale.x = 1.0 if k == 0 else -1.0
			add_child(n)
			var s: Sprite2D = _strip("prop_camel_loaded" if k == 1 else "prop_camel", n)
			if s:
				s.frame = k
	if "island" in want:
		# The player camera clamps at limit_right 5600 (scenes/player/player.tscn),
		# which leaves the island off-screen; lift it for the capture only.
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam:
			cam.limit_right = 6000
	if "heli" in want and world.has_method("_spawn_helicopter") and world.helicopter_active == null:
		world._spawn_helicopter()
		if world.helicopter_active:
			var cxs2: String = OS.get_environment("DTS_CAMX")
			var hx: float = cxs2.to_float() if cxs2 != "" else 900.0
			world.helicopter_active.position = Vector2(hx + 120.0, world._get_terrain_y_at(hx) - 120.0)

func _process(dt: float) -> void:
	if world == null:
		return
	_tick_pumps(dt)
	_tick_camels(dt)
	_tick_helicopter(dt)
	_tick_politicians(dt)
