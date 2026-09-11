extends SceneTree
# Headless walkability test. Run with:
#   godot --headless --audio-driver Dummy --fixed-fps 60 -s tests/terrain_walkable.gd
# Exits 0 on pass, 1 on failure.
#
# Walks a body shaped exactly like the player (16x32 rectangle, offset -20,
# same gravity/speed/accel, default floor_max_angle) across the whole terrain
# with every pool drained (worst case: no water walls), first east then west,
# and reports every x where it stalls. Guards the 2026-09-11 bug: a vertical
# 2-unit step in the Swamp basin trapped Wes after he drained it.

const GRAVITY := 800.0
const SPEED := 120.0
const ACCEL := 1400.0
const STALL_FRAMES := 60
const STALL_DIST := 2.0

var pts: Array[Vector2] = []
var body: CharacterBody2D
var dir := 1.0
var frame := 0
var last_check_x := 0.0
var stalls: Array = []
var done := false

func _initialize() -> void:
	pts = _parse_terrain()
	if pts.size() < 10:
		printerr("FAIL: could not parse terrain_points from game_world.gd")
		quit(1)
		return
	var ground := StaticBody2D.new()
	for i in range(pts.size() - 1):
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = pts[i]
		seg.b = pts[i + 1]
		cs.shape = seg
		ground.add_child(cs)
	root.add_child(ground)

	body = CharacterBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 32)
	col.shape = rect
	col.position = Vector2(0, -20)
	body.add_child(col)
	root.add_child(body)
	_place(pts[0].x + 20.0)
	last_check_x = body.position.x

func _parse_terrain() -> Array[Vector2]:
	var src: String = FileAccess.get_file_as_string("res://scripts/game_world.gd")
	var a: int = src.find("var terrain_points")
	var b: int = src.find("\n]", a)
	var re := RegEx.new()
	re.compile("Vector2\\(\\s*(-?[\\d.]+)\\s*,\\s*(-?[\\d.]+)\\s*\\)")
	var out: Array[Vector2] = []
	for m in re.search_all(src.substr(a, b - a)):
		out.append(Vector2(m.get_string(1).to_float(), m.get_string(2).to_float()))
	return out

func _ground_y(x: float) -> float:
	for i in range(pts.size() - 1):
		if x >= pts[i].x and x <= pts[i + 1].x and pts[i + 1].x > pts[i].x:
			var t: float = (x - pts[i].x) / (pts[i + 1].x - pts[i].x)
			return lerpf(pts[i].y, pts[i + 1].y, t)
	return pts[-1].y

func _place(x: float) -> void:
	body.position = Vector2(x, _ground_y(x) - 2.0)
	body.velocity = Vector2.ZERO

func _physics_process(delta: float) -> bool:
	if done:
		return true
	if not body.is_on_floor():
		body.velocity.y += GRAVITY * delta
	body.velocity.x = move_toward(body.velocity.x, dir * SPEED, ACCEL * delta)
	body.move_and_slide()
	frame += 1

	var x: float = body.position.x
	if dir > 0.0 and x >= pts[-1].x - 20.0:
		dir = -1.0
		last_check_x = x
		frame = 0
		return false   # skip this frame's stall check (it would see zero movement)
	elif dir < 0.0 and x <= pts[0].x + 20.0:
		_finish()
		return true

	if frame % STALL_FRAMES == 0:
		if absf(x - last_check_x) < STALL_DIST:
			stalls.append("stuck walking %s at x=%.0f y=%.0f" % ["east" if dir > 0.0 else "west", x, body.position.y])
			_place(x + dir * 24.0)   # hop past it so one run finds every trap
		last_check_x = body.position.x
	if frame > 60 * 400:
		stalls.append("timeout")
		_finish()
	return false

func _finish() -> void:
	done = true
	if stalls.is_empty():
		print("terrain_walkable: ALL PASS (%d segments, both directions)" % (pts.size() - 1))
		quit(0)
	else:
		for s in stalls:
			printerr("FAIL: " + s)
		quit(1)
