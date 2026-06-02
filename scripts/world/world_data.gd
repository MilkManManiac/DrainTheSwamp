class_name WorldData
extends RefCounted

# ── Authored world geometry ─────────────────────────────────────────────────────
# Single source of truth for terrain shape + pool placement, lifted verbatim from the
# original game_world.gd. x = world position, y = surface height (down = +y).
# The 3D terrain/water builders consume this; nothing here knows about 2D vs 3D.

const TERRAIN_POINTS: Array[Vector2] = [
	# Left forest edge — indices 0-5
	Vector2(-240, 118), Vector2(-220, 122), Vector2(-195, 128),
	Vector2(-160, 132), Vector2(-110, 134), Vector2(-60, 136),
	# Left shore (shop area) — indices 6-7
	Vector2(-40, 136), Vector2(80, 136),
	# Puddle — indices 8-14
	Vector2(112, 152), Vector2(135, 164), Vector2(142, 163), Vector2(155, 168),
	Vector2(165, 166), Vector2(175, 164), Vector2(200, 148),
	# Ridge 1 — indices 15-16
	Vector2(230, 142), Vector2(270, 155),
	# Pond — indices 17-25
	Vector2(305, 188), Vector2(328, 200), Vector2(348, 200), Vector2(370, 210),
	Vector2(395, 212), Vector2(420, 210), Vector2(440, 208), Vector2(455, 205), Vector2(480, 186),
	# Ridge 2 — indices 26-28
	Vector2(520, 178), Vector2(555, 180), Vector2(595, 192),
	# Marsh — indices 29-41
	Vector2(650, 228), Vector2(675, 244), Vector2(688, 244), Vector2(705, 252),
	Vector2(720, 250), Vector2(738, 256), Vector2(758, 258), Vector2(775, 254),
	Vector2(795, 257), Vector2(812, 252), Vector2(828, 250), Vector2(842, 248), Vector2(862, 232),
	# Ridge 3 — indices 42-44
	Vector2(895, 224), Vector2(925, 218), Vector2(960, 250),
	# Bog — indices 45-59
	Vector2(1020, 296), Vector2(1042, 308), Vector2(1060, 304), Vector2(1080, 314),
	Vector2(1100, 320), Vector2(1118, 318), Vector2(1138, 324), Vector2(1160, 326),
	Vector2(1182, 322), Vector2(1200, 324), Vector2(1218, 318), Vector2(1236, 314),
	Vector2(1254, 310), Vector2(1272, 306), Vector2(1300, 290),
	# Ridge 4 — indices 60-63
	Vector2(1320, 280), Vector2(1345, 276), Vector2(1370, 278), Vector2(1400, 294),
	# Swamp — indices 64-80
	Vector2(1450, 336), Vector2(1475, 350), Vector2(1498, 362), Vector2(1518, 372),
	Vector2(1536, 378), Vector2(1555, 384), Vector2(1555, 386), Vector2(1582, 390),
	Vector2(1608, 388), Vector2(1632, 384), Vector2(1658, 380), Vector2(1680, 374),
	Vector2(1700, 368), Vector2(1720, 362), Vector2(1740, 356), Vector2(1758, 350), Vector2(1780, 334),
	# Ridge 5 — indices 81-83
	Vector2(1820, 326), Vector2(1850, 318), Vector2(1885, 332),
	# Lake — indices 84-102
	Vector2(1940, 372), Vector2(1965, 390), Vector2(1988, 402), Vector2(2010, 398),
	Vector2(2035, 410), Vector2(2065, 416), Vector2(2100, 420), Vector2(2138, 424),
	Vector2(2175, 426), Vector2(2210, 422), Vector2(2245, 418), Vector2(2275, 412),
	Vector2(2305, 418), Vector2(2335, 414), Vector2(2365, 408), Vector2(2390, 402),
	Vector2(2410, 396), Vector2(2430, 390), Vector2(2455, 372),
	# Ridge 6 — indices 103-105
	Vector2(2495, 364), Vector2(2525, 358), Vector2(2560, 370),
	# Reservoir — indices 106-126
	Vector2(2610, 400), Vector2(2632, 416), Vector2(2652, 432), Vector2(2670, 444),
	Vector2(2688, 452), Vector2(2708, 460), Vector2(2715, 464), Vector2(2740, 466),
	Vector2(2770, 468), Vector2(2800, 466), Vector2(2830, 464), Vector2(2858, 460),
	Vector2(2885, 456), Vector2(2910, 452), Vector2(2935, 448), Vector2(2958, 444),
	Vector2(2978, 440), Vector2(2996, 434), Vector2(3012, 428), Vector2(3028, 420), Vector2(3048, 404),
	# Ridge 7 — indices 127-129
	Vector2(3088, 396), Vector2(3115, 388), Vector2(3148, 400),
	# Lagoon — indices 130-152
	Vector2(3200, 430), Vector2(3225, 446), Vector2(3248, 458), Vector2(3268, 466),
	Vector2(3288, 472), Vector2(3310, 468), Vector2(3332, 464), Vector2(3358, 470),
	Vector2(3385, 478), Vector2(3412, 482), Vector2(3440, 478), Vector2(3465, 474),
	Vector2(3488, 470), Vector2(3510, 476), Vector2(3535, 480), Vector2(3558, 476),
	Vector2(3580, 472), Vector2(3600, 466), Vector2(3618, 460), Vector2(3636, 454),
	Vector2(3652, 448), Vector2(3668, 442), Vector2(3688, 430),
	# Ridge 8 — indices 153-156
	Vector2(3725, 422), Vector2(3755, 414), Vector2(3780, 420), Vector2(3810, 432),
	# Bayou — indices 157-181
	Vector2(3865, 458), Vector2(3888, 472), Vector2(3910, 484), Vector2(3930, 494),
	Vector2(3950, 500), Vector2(3955, 494), Vector2(3978, 502), Vector2(4002, 508),
	Vector2(4028, 512), Vector2(4055, 516), Vector2(4082, 520), Vector2(4108, 522),
	Vector2(4135, 518), Vector2(4158, 522), Vector2(4180, 516), Vector2(4200, 510),
	Vector2(4220, 506), Vector2(4238, 500), Vector2(4258, 494), Vector2(4276, 488),
	Vector2(4295, 482), Vector2(4312, 478), Vector2(4328, 474), Vector2(4345, 470), Vector2(4365, 456),
	# Ridge 9 — indices 182-185
	Vector2(4400, 448), Vector2(4430, 440), Vector2(4458, 436), Vector2(4490, 450),
	# The Atlantic — indices 186-214
	Vector2(4550, 484), Vector2(4575, 496), Vector2(4600, 504), Vector2(4630, 508),
	Vector2(4660, 516), Vector2(4692, 534), Vector2(4722, 552), Vector2(4735, 572),
	Vector2(4762, 582), Vector2(4790, 590), Vector2(4820, 596), Vector2(4852, 600),
	Vector2(4885, 604), Vector2(4918, 600), Vector2(4950, 594), Vector2(4978, 582),
	Vector2(5005, 570), Vector2(5030, 578), Vector2(5058, 588), Vector2(5088, 594),
	Vector2(5120, 590), Vector2(5148, 584), Vector2(5178, 576), Vector2(5208, 566),
	Vector2(5238, 556), Vector2(5268, 544), Vector2(5298, 530), Vector2(5328, 516), Vector2(5360, 498),
	# Right shore — indices 215-216
	Vector2(5420, 490), Vector2(5500, 498),
	# Island — indices 217-222
	Vector2(5560, 510), Vector2(5600, 490), Vector2(5640, 484),
	Vector2(5680, 484), Vector2(5720, 490), Vector2(5760, 510),
]

# [entry_top_index, exit_top_index] into TERRAIN_POINTS — one per pool
const SWAMP_RANGES: Array = [
	[8, 14], [17, 25], [29, 41], [45, 59], [64, 80],
	[84, 102], [106, 126], [130, 152], [157, 181], [186, 214],
]
const SWAMP_COUNT: int = 10

# Per-pool water surface color (RGB; alpha applied by the water material)
const SWAMP_WATER_COLORS: Array[Color] = [
	Color(0.30, 0.55, 0.60),  # Puddle: crystal aqua
	Color(0.18, 0.42, 0.22),  # Pond: pastoral green
	Color(0.30, 0.28, 0.15),  # Marsh: murky olive
	Color(0.12, 0.10, 0.08),  # Bog: peaty black
	Color(0.10, 0.18, 0.12),  # Swamp: dark murky green
	Color(0.15, 0.30, 0.50),  # Lake: clear blue
	Color(0.12, 0.20, 0.35),  # Reservoir: slate
	Color(0.10, 0.35, 0.40),  # Lagoon: tropical teal
	Color(0.06, 0.08, 0.14),  # Bayou: near-black
	Color(0.04, 0.08, 0.22),  # Atlantic: abyssal blue
]

# ── 3D mapping constants (shared by all builders) ───────────────────────────────
const SCALE: float = 0.0625          # world px → 3D units (1/16)
const REF_Y: float = 130.0           # original-y mapping: left shore ≈ y0, later pools descend
const DEPTH: float = 44.0            # solid landmass depth along Z (extends toward camera AND back)
const FRONT_Z: float = 22.0          # front edge sits beyond the tilted camera so the dig-face
                                     # cross-section is never in frame — foreground is top-surface
                                     # ground. player rail z=0; land spans [FRONT_Z-DEPTH .. FRONT_Z]

static func to_world_x(orig_x: float) -> float:
	return orig_x * SCALE

static func elev(orig_y: float) -> float:
	# higher terrain (smaller orig_y) → larger 3D y
	return (REF_Y - orig_y) * SCALE

# gentle winding of the walking path in Z, as a function of 3D world-x.
# (the player follows this; terrain path mesh + prop-clearing use it too)
static func path_z(world_x: float) -> float:
	return sin(world_x * 0.045) * 1.8 + sin(world_x * 0.013 + 1.0) * 1.0

static func path_tangent_yaw(world_x: float) -> float:
	# yaw to face along the path (derivative of path_z gives the local heading)
	var dz := 0.045 * 1.8 * cos(world_x * 0.045) + 0.013 * 1.0 * cos(world_x * 0.013 + 1.0)
	return atan2(dz, 1.0)

# ── Land extension ───────────────────────────────────────────────────────────────
# The raw TERRAIN_POINTS have short ridges between pools. We remap the X coords once so
# the LAND segments between pools stretch (proportional to the nearest pool's size →
# more land than water, a longer journey), while pool segments keep their exact shape
# and SWAMP_RANGES indices stay valid. Everything reads points() instead of the raw const.
static var _pts: Array[Vector2] = []

static func points() -> Array[Vector2]:
	if _pts.is_empty():
		_pts = _build_stretched()
	return _pts

static func _build_stretched() -> Array[Vector2]:
	var raw := TERRAIN_POINTS
	var pw: Array[float] = []
	var pc: Array[float] = []
	for r in SWAMP_RANGES:
		pw.append(raw[r[1]].x - raw[r[0]].x)
		pc.append((float(r[0]) + float(r[1])) * 0.5)
	var out: Array[Vector2] = []
	var shift := 0.0
	out.append(raw[0])
	for j in range(1, raw.size()):
		var dx := raw[j].x - raw[j - 1].x
		var is_pool_seg := false
		for r in SWAMP_RANGES:
			if j - 1 >= r[0] and j <= r[1]:
				is_pool_seg = true
				break
		var f := 1.0
		if not is_pool_seg:
			# stretch land by the nearest pool's size → land scales with the pools
			var best := 0
			var bestd := 1.0e9
			for pi in range(pc.size()):
				var d: float = absf((float(j) - 0.5) - pc[pi])
				if d < bestd:
					bestd = d
					best = pi
			f = clampf(1.0 + pw[best] / 150.0, 1.7, 4.0)
		shift += dx * (f - 1.0)
		out.append(Vector2(raw[j].x + shift, raw[j].y))
	return out

static func in_pool(orig_x: float) -> bool:
	var pts := points()
	for r in SWAMP_RANGES:
		if orig_x >= pts[r[0]].x and orig_x <= pts[r[1]].x:
			return true
	return false

# 1.0 on land away from pools → 0.0 inside pools (smooth ramp), so the rolling-hill
# undulation fades out at the water and the basins stay clean
static func _land_mask(orig_x: float) -> float:
	var pts := points()
	var min_d := 1e9
	for r in SWAMP_RANGES:
		var a: float = pts[r[0]].x
		var b: float = pts[r[1]].x
		if orig_x >= a and orig_x <= b:
			return 0.0
		min_d = minf(min_d, minf(absf(orig_x - a), absf(orig_x - b)))
	return clampf(min_d / 45.0, 0.0, 1.0)

# gentle rolling-hill undulation on the land sections (3D units), faded at pools
static func land_roll(orig_x: float) -> float:
	var roll: float = sin(orig_x * 0.0075) * 1.6 + sin(orig_x * 0.017 + 1.3) * 0.9 + sin(orig_x * 0.034) * 0.5
	return roll * _land_mask(orig_x)

static func surface_y_at(orig_x: float) -> float:
	# linear interp of 3D elevation at an original-x, plus rolling-hill undulation on land
	var pts := points()
	var base: float
	if orig_x <= pts[0].x:
		base = elev(pts[0].y)
	elif orig_x >= pts[pts.size() - 1].x:
		base = elev(pts[pts.size() - 1].y)
	else:
		base = elev(pts[pts.size() - 1].y)
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			if orig_x >= a.x and orig_x <= b.x:
				var t := (orig_x - a.x) / (b.x - a.x) if b.x != a.x else 0.0
				base = elev(lerpf(a.y, b.y, t))
				break
	return base + land_roll(orig_x)
