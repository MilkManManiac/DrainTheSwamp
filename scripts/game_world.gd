extends Node2D

# Day/Night cycle - 5 minute real-time cycle (300 seconds)
const CYCLE_DURATION: float = 300.0

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
var cycle_time: float = 0.0

# Terrain: array of Vector2 points defining the ground surface
# Each pool has a unique contour; ridges between them vary in shape
var terrain_points: Array[Vector2] = [
	# Left forest edge — indices 0-5
	Vector2(-240, 118), Vector2(-220, 122), Vector2(-195, 128),
	Vector2(-160, 132), Vector2(-110, 134), Vector2(-60, 136),
	# Left shore (shop area) — indices 6-7
	Vector2(-40, 136), Vector2(80, 136),
	# Puddle (7 pts) — indices 2-8: shallow worn dip, left-leaning
	Vector2(112, 152),   # entry top
	Vector2(135, 164),   # entry mid-shelf (~28°)
	Vector2(142, 163),   # small notch up
	Vector2(155, 168),   # basin dip
	Vector2(165, 166),   # basin bump
	Vector2(175, 164),   # basin right
	Vector2(200, 148),   # exit top (gradual climb)
	# Ridge 1 — smooth hump — indices 9-10
	Vector2(230, 142), Vector2(270, 155),
	# Pond (9 pts) — indices 11-19: off-center V
	Vector2(305, 188),   # entry top (~28°)
	Vector2(328, 200),   # entry shelf (~28°)
	Vector2(348, 200),   # step back up
	Vector2(370, 210),   # deeper dip (off-center V)
	Vector2(395, 212),   # basin floor
	Vector2(420, 210),   # slight rise
	Vector2(440, 208),   # gradual exit
	Vector2(455, 205),   # exit bump
	Vector2(480, 186),   # exit top
	# Ridge 2 — plateau — indices 20-22
	Vector2(520, 178), Vector2(555, 180), Vector2(595, 192),
	# Marsh (13 pts) — indices 23-35: wide, lumpy, organic
	Vector2(650, 228),   # entry top
	Vector2(675, 244),   # entry slope (~30°)
	Vector2(688, 244),   # bump up
	Vector2(705, 252),   # dip
	Vector2(720, 250),   # rise
	Vector2(738, 256),   # deeper
	Vector2(758, 258),   # deepest
	Vector2(775, 254),   # rise
	Vector2(795, 257),   # second dip
	Vector2(812, 252),   # bump
	Vector2(828, 250),   # rise
	Vector2(842, 248),   # exit slope
	Vector2(862, 232),   # exit top
	# Ridge 3 — jagged peak — indices 36-38
	Vector2(895, 224), Vector2(925, 218), Vector2(960, 250),
	# Bog (15 pts) — indices 39-53: stair-steps, max slope ~33°
	Vector2(1020, 296),  # entry top
	Vector2(1042, 308),  # entry slope (dx=22,dy=12 → 29°)
	Vector2(1060, 304),  # crack ledge (dx=18,dy=4 up)
	Vector2(1080, 314),  # deeper ledge (dx=20,dy=10 → 27°)
	Vector2(1100, 320),  # stair (dx=20,dy=6 → 17°)
	Vector2(1118, 318),  # step back (dx=18,dy=2 up)
	Vector2(1138, 324),  # basin (dx=20,dy=6 → 17°)
	Vector2(1160, 326),  # deepest (dx=22,dy=2)
	Vector2(1182, 322),  # rise (dx=22,dy=4 up)
	Vector2(1200, 324),  # second crack (dx=18,dy=2)
	Vector2(1218, 318),  # stair step up (dx=18,dy=6 up → 18°)
	Vector2(1236, 314),  # ledge (dx=18,dy=4 up)
	Vector2(1254, 310),  # exit ledge (dx=18,dy=4 up)
	Vector2(1272, 306),  # exit slope (dx=18,dy=4 up)
	Vector2(1300, 290),  # exit top (dx=28,dy=16 up → 30°)
	# Ridge 4 — cracked flat — indices 54-57
	Vector2(1320, 280), Vector2(1345, 276), Vector2(1370, 278), Vector2(1400, 294),
	# Swamp (17 pts) — indices 58-74: lopsided canyon, gradual right slope
	Vector2(1450, 336),  # entry top
	Vector2(1475, 350),  # entry slope (~30°)
	Vector2(1498, 362),  # mid slope (~28°)
	Vector2(1518, 372),  # lower slope (~27°)
	Vector2(1536, 378),  # ledge (~18°)
	Vector2(1555, 384),  # basin left (~17°)
	Vector2(1555, 386),  # deep basin
	Vector2(1582, 390),  # deepest (far off-center right)
	Vector2(1608, 388),  # slight rise
	Vector2(1632, 384),  # gradual slope
	Vector2(1658, 380),  # continuing slope
	Vector2(1680, 374),  # slope
	Vector2(1700, 368),  # slope
	Vector2(1720, 362),  # slope
	Vector2(1740, 356),  # slope
	Vector2(1758, 350),  # exit slope
	Vector2(1780, 334),  # exit top
	# Ridge 5 — narrow spike — indices 75-77
	Vector2(1820, 326), Vector2(1850, 318), Vector2(1885, 332),
	# Lake (19 pts) — indices 78-96: wide open, underwater ridges
	Vector2(1940, 372),  # entry top
	Vector2(1965, 390),  # entry slope (~30°)
	Vector2(1988, 402),  # shelf (~28°)
	Vector2(2010, 398),  # ridge up
	Vector2(2035, 410),  # trench
	Vector2(2065, 416),  # deep
	Vector2(2100, 420),  # deeper
	Vector2(2138, 424),  # approaching deepest
	Vector2(2175, 426),  # deepest
	Vector2(2210, 422),  # rise
	Vector2(2245, 418),  # underwater ridge
	Vector2(2275, 412),  # ridge peak
	Vector2(2305, 418),  # back down
	Vector2(2335, 414),  # rise
	Vector2(2365, 408),  # exit slope
	Vector2(2390, 402),  # exit slope
	Vector2(2410, 396),  # exit slope
	Vector2(2430, 390),  # exit slope
	Vector2(2455, 372),  # exit top
	# Ridge 6 — stepped — indices 97-99
	Vector2(2495, 364), Vector2(2525, 358), Vector2(2560, 370),
	# Reservoir (21 pts) — indices 100-120: angular, dam-like
	Vector2(2610, 400),  # entry top
	Vector2(2632, 416),  # entry slope (~30°)
	Vector2(2652, 432),  # mid slope (~29°)
	Vector2(2670, 444),  # lower slope (~28°)
	Vector2(2688, 452),  # step (~24°)
	Vector2(2708, 460),  # deep (~22°)
	Vector2(2715, 464),  # deeper
	Vector2(2740, 466),  # basin
	Vector2(2770, 468),  # deepest
	Vector2(2800, 466),  # rise
	Vector2(2830, 464),  # ledge
	Vector2(2858, 460),  # step up
	Vector2(2885, 456),  # angular
	Vector2(2910, 452),  # rise
	Vector2(2935, 448),  # step
	Vector2(2958, 444),  # angular
	Vector2(2978, 440),  # exit slope
	Vector2(2996, 434),  # exit slope
	Vector2(3012, 428),  # exit
	Vector2(3028, 420),  # exit slope
	Vector2(3048, 404),  # exit top
	# Ridge 7 — jagged — indices 121-123
	Vector2(3088, 396), Vector2(3115, 388), Vector2(3148, 400),
	# Lagoon (23 pts) — indices 124-146: winding irregular, sub-basins
	Vector2(3200, 430),  # entry top
	Vector2(3225, 446),  # entry slope (~30°)
	Vector2(3248, 458),  # shelf (~28°)
	Vector2(3268, 466),  # sub-basin 1 (~22°)
	Vector2(3288, 472),  # deep
	Vector2(3310, 468),  # pinch point rise
	Vector2(3332, 464),  # narrow
	Vector2(3358, 470),  # sub-basin 2
	Vector2(3385, 478),  # deeper
	Vector2(3412, 482),  # deepest
	Vector2(3440, 478),  # rise
	Vector2(3465, 474),  # ridge
	Vector2(3488, 470),  # pinch
	Vector2(3510, 476),  # sub-basin 3
	Vector2(3535, 480),  # deep
	Vector2(3558, 476),  # rise
	Vector2(3580, 472),  # slope
	Vector2(3600, 466),  # exit slope
	Vector2(3618, 460),  # exit
	Vector2(3636, 454),  # exit
	Vector2(3652, 448),  # exit
	Vector2(3668, 442),  # exit slope
	Vector2(3688, 430),  # exit top
	# Ridge 8 — broken — indices 147-150
	Vector2(3725, 422), Vector2(3755, 414), Vector2(3780, 420), Vector2(3810, 432),
	# Bayou (25 pts) — indices 151-175: collapsed, twisted, chaotic
	Vector2(3865, 458),  # entry top
	Vector2(3888, 472),  # entry slope (~31°)
	Vector2(3910, 484),  # mid slope (~28°)
	Vector2(3930, 494),  # lower slope (~27°)
	Vector2(3950, 500),  # collapsed section (~17°)
	Vector2(3955, 494),  # bump
	Vector2(3978, 502),  # deeper
	Vector2(4002, 508),  # basin
	Vector2(4028, 512),  # deep
	Vector2(4055, 516),  # deeper
	Vector2(4082, 520),  # approaching deepest
	Vector2(4108, 522),  # deepest
	Vector2(4135, 518),  # rise
	Vector2(4158, 522),  # second dip
	Vector2(4180, 516),  # rise
	Vector2(4200, 510),  # slope
	Vector2(4220, 506),  # root bump
	Vector2(4238, 500),  # slope
	Vector2(4258, 494),  # slope
	Vector2(4276, 488),  # slope
	Vector2(4295, 482),  # slope
	Vector2(4312, 478),  # exit
	Vector2(4328, 474),  # exit
	Vector2(4345, 470),  # exit slope
	Vector2(4365, 456),  # exit top
	# Ridge 9 — ancient stone — indices 176-179
	Vector2(4400, 448), Vector2(4430, 440), Vector2(4458, 436), Vector2(4490, 450),
	# The Atlantic (29 pts) — indices 180-208: continental shelf, trench, underwater mountain
	Vector2(4550, 484),  # entry top (continental shelf)
	Vector2(4575, 496),  # shelf slope
	Vector2(4600, 504),  # shelf
	Vector2(4630, 508),  # shelf edge
	Vector2(4660, 516),  # steep drop begins
	Vector2(4692, 534),  # cliff (smoothed)
	Vector2(4722, 552),  # deep drop (smoothed)
	Vector2(4735, 572),  # trench approach
	Vector2(4762, 582),  # trench
	Vector2(4790, 590),  # deep trench
	Vector2(4820, 596),  # deeper
	Vector2(4852, 600),  # trench floor
	Vector2(4885, 604),  # deepest
	Vector2(4918, 600),  # rise
	Vector2(4950, 594),  # underwater mountain base
	Vector2(4978, 582),  # mountain slope
	Vector2(5005, 570),  # mountain peak
	Vector2(5030, 578),  # back down
	Vector2(5058, 588),  # second basin
	Vector2(5088, 594),  # deep
	Vector2(5120, 590),  # rise
	Vector2(5148, 584),  # slope
	Vector2(5178, 576),  # slope
	Vector2(5208, 566),  # slope
	Vector2(5238, 556),  # exit slope
	Vector2(5268, 544),  # exit
	Vector2(5298, 530),  # exit
	Vector2(5328, 516),  # exit slope
	Vector2(5360, 498),  # exit top
	# Right shore — indices 215-216
	Vector2(5420, 490), Vector2(5500, 498),
	# Island — indices 217-222
	Vector2(5560, 510), Vector2(5600, 490), Vector2(5640, 484),
	Vector2(5680, 484), Vector2(5720, 490), Vector2(5760, 510),
]

# Swamp geometry: [entry_top_index, exit_top_index] into terrain_points
const SWAMP_RANGES: Array = [
	[8, 14],     # Puddle
	[17, 25],    # Pond
	[29, 41],    # Marsh
	[45, 59],    # Bog
	[64, 80],    # Swamp
	[84, 102],   # Lake
	[106, 126],  # Reservoir
	[130, 152],  # Lagoon
	[157, 181],  # Bayou
	[186, 214],  # The Atlantic
]
const SWAMP_COUNT: int = 10
const WATER_SHADER = preload("res://shaders/water.gdshader")
const POST_PROCESS_SHADER = preload("res://shaders/post_process.gdshader")
const TERRAIN_SHADER = preload("res://shaders/terrain.gdshader")
const GOD_RAYS_SHADER = preload("res://shaders/god_rays.gdshader")
const FOG2D_SHADER = preload("res://shaders/fog2d.gdshader")
const FOLIAGE_SWAY_SHADER = preload("res://shaders/foliage_sway.gdshader")

# --- Shared sway materials (R3) — ONE material per plant class, not per instance ---
# Phase variation comes from the world-X gust term inside the shader.
var _sway_mat_grass: ShaderMaterial = null   # snappy, whippy blades
var _sway_mat_frond: ShaderMaterial = null   # medium ferns/cattails
var _sway_mat_canopy: ShaderMaterial = null  # gentle tree canopy
var _sway_mat_moss: ShaderMaterial = null    # high strength / low stiffness drape

# Visual nodes created procedurally
var water_polygons: Array[Polygon2D] = []
var water_surface_lines: Array[Line2D] = []
var terrain_polygon: Polygon2D = null
var terrain_body: StaticBody2D = null
var water_detect_areas: Array[Area2D] = []
var water_walls: Array = []
var swamp_labels: Array[Label] = []
var swamp_percent_labels: Array[Label] = []
var swamp_gallon_labels: Array[Label] = []
var clouds: Array[Node2D] = []
var cattails: Array[Node2D] = []
var stars: Array[ColorRect] = []
var fireflies: Array[Dictionary] = []
var leaves: Array[Dictionary] = []
var leaf_timer: float = 0.0
var lily_pads: Array[Dictionary] = []
var depth_polygons: Array[Polygon2D] = []
var shimmer_lines: Array[Line2D] = []
var mud_patches: Array[Dictionary] = []
var player_in_shop_area: bool = false
var shop_player_ref: Node2D = null
var camels: Array[Dictionary] = []
# Endgame
var jeff_node: Node2D = null
var jeff_area: Area2D = null
var player_near_jeff: bool = false
var endgame_triggered: bool = false
var politician_nodes: Array[Node2D] = []
# Wanted poster
var wanted_poster: Node2D = null
# Helicopter
var helicopter_timer: float = 0.0
var helicopter_active: Node2D = null
# Second pass visuals
var moon: Node2D = null
var moon_glow: Sprite2D = null
var moon_body: Polygon2D = null
var bubbles: Array[Dictionary] = []
var bubble_timer: float = 0.0
var foam_lines: Array[Line2D] = []
var pollen: Array[Dictionary] = []
var pollen_timer: float = 0.0
var birds: Array[Dictionary] = []
var bird_timer: float = 0.0
var fog_patches: Array[Dictionary] = []
var dragonflies: Array[Dictionary] = []
var water_highlights: Array[Dictionary] = []
var sun_node: Node2D = null
var fish: Array[Dictionary] = []
var frogs: Array[Dictionary] = []
var _startle_cd: float = 0.0  # throttles wildlife reactions to scooping
var glow_plants: Array[Dictionary] = []
var seaweed: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var ripple_timer: float = 0.0
var butterflies: Array[Dictionary] = []
var butterfly_timer: float = 0.0
var shooting_stars: Array[Dictionary] = []
var shooting_star_timer: float = 0.0
var turtles: Array[Dictionary] = []
var tadpoles: Array[Dictionary] = []
var crickets: Array[Dictionary] = []

# Distance fog (Phase 4C)
var distance_fog_layer: CanvasLayer = null
var distance_fog_rect: ColorRect = null

# Shader effects
var post_process_layer: CanvasLayer = null
var post_process_rect: ColorRect = null
var water_glow_lines: Array[Line2D] = []
# R2 water: receding waterline + foam tide + ripples
var water_foam_lines: Array[Line2D] = []          # lagging tide-line foam
var water_back_buffer: BackBufferCopy = null      # under water, feeds refraction
var _water_distort_tex: NoiseTexture2D = null     # shared seamless distortion
var _pool_high_water_y: Array[float] = []         # highest (min screen-Y) line reached
var _pool_cur_water_y: Array[float] = []          # current water surface Y
var _pool_wet_fade: Array[float] = []             # 0 fresh -> 1 dried
var _pool_foam_line_y: Array[float] = []          # lagging foam tide-line Y
var _terrain_mat: ShaderMaterial = null           # terrain shader (for waterline)
# Interactive ripples: each {pos:Vector2 (water-poly local), t, amp}
var _ripples: Array = []
const RIPPLE_MAX := 8

# Parallax layers
var parallax_bg: ParallaxBackground = null
var sky_layer: ParallaxLayer = null
var far_hills_layer: ParallaxLayer = null
var near_hills_layer: ParallaxLayer = null
var treeline_layer: ParallaxLayer = null
var foreground_layer: ParallaxLayer = null

# Round-1 atmosphere overhaul
var god_ray_rect: ColorRect = null
var ground_fog_rect: ColorRect = null
var haze_fog_rect: ColorRect = null
var fog_noise_tex: NoiseTexture2D = null

# Weather system
var weather_state: String = "clear"
var weather_timer: float = 0.0
var weather_duration: float = 90.0
var lightning_timer: float = 20.0
var rain_layer: CanvasLayer = null
var rain_particles: CPUParticles2D = null
var lightning_rect: ColorRect = null

# Enhanced vegetation
var grass_blades: Array[Line2D] = []
var grass_tufts: Array[Node2D] = []
var ferns_list: Array[Node2D] = []
var wind_direction: float = 1.0
var wind_timer: float = 0.0

# Drain-revealed objects per swamp
var drain_reveals: Array[Array] = []

# Growing vegetation on drained land (Phase 15b)
var grown_plants: Array[Dictionary] = []
var last_drain_thresholds: Array[float] = []

# Atmosphere effects (Phase 17)
var morning_mist_rects: Array[ColorRect] = []
var aurora_lines: Array[Dictionary] = []
var aurora_active: bool = false
var aurora_timer: float = 0.0
var aurora_fade: float = 0.0
var owl_node: Node2D = null
var owl_blink_timer: float = 4.0

# Cave entrances
var cave_entrances: Array[Dictionary] = []
const CAVE_IDS: Array = ["muddy_hollow", "gator_den", "the_sinkhole", "collapsed_mine", "the_mire", "sunken_grotto", "the_cistern", "coral_cavern", "the_underdark", "mariana_trench"]

# Dynamic shadows (Phase 13c)
var player_shadow: ColorRect = null

# Pool glow lights (Phase 4A)
var pool_glow_lights: Array[PointLight2D] = []

# Drained pool beds (Phase 8C)
var pool_bed_nodes: Array[Node2D] = []

# Waterfall drips (Phase 3B)
var drip_nodes: Array[Dictionary] = []  # [{line, timer, phase, side, pool_idx, base_pos}]

# Pool drain milestones (Phase 8B)
var pool_milestones_triggered: Dictionary = {}  # {swamp_idx: {50: bool, 25: bool}}

# Gradient sky (Phase 2A)
var sky_texture_rect: TextureRect = null
var sky_gradient: GradientTexture2D = null
var sky_gradient_res: Gradient = null
var horizon_glow: Line2D = null

# Colors
const SKY_COLOR_TOP := Color(0.22, 0.38, 0.72)
const SKY_COLOR_MID := Color(0.45, 0.62, 0.88)
const SKY_COLOR_BOTTOM := Color(0.62, 0.78, 0.92)
const GROUND_COLOR := Color(0.45, 0.32, 0.16)
const GROUND_MID_COLOR := Color(0.38, 0.25, 0.12)
const GROUND_DARK_COLOR := Color(0.28, 0.18, 0.08)
const WATER_COLOR := Color(0.18, 0.32, 0.22, 0.92)
const WATER_EMPTY_COLOR := Color(0.3, 0.45, 0.32, 0.65)
const WATER_SURFACE_COLOR := Color(0.35, 0.55, 0.4, 0.6)

# Per-pool water colors — distinct identity per pool
const SWAMP_WATER_COLORS: Array[Color] = [
	Color(0.30, 0.55, 0.60, 0.70),  # Puddle: crystal clear light aqua
	Color(0.18, 0.42, 0.22, 0.88),  # Pond: classic pastoral green
	Color(0.30, 0.28, 0.15, 0.92),  # Marsh: murky brown-olive
	Color(0.12, 0.10, 0.08, 0.95),  # Bog: dark peaty brown-black
	Color(0.10, 0.18, 0.12, 0.94),  # Swamp: dark murky green
	Color(0.15, 0.30, 0.50, 0.88),  # Lake: clear deep blue
	Color(0.12, 0.20, 0.35, 0.92),  # Reservoir: slate blue-gray
	Color(0.10, 0.35, 0.40, 0.90),  # Lagoon: tropical teal
	Color(0.06, 0.08, 0.14, 0.96),  # Bayou: near-black murk
	Color(0.04, 0.08, 0.22, 0.98),  # The Atlantic: abyssal deep blue
]
const SWAMP_WATER_EMPTY_COLORS: Array[Color] = [
	Color(0.45, 0.65, 0.68, 0.45),  # Puddle: pale aqua
	Color(0.30, 0.52, 0.32, 0.55),  # Pond: faded green
	Color(0.40, 0.38, 0.25, 0.60),  # Marsh: dried mud
	Color(0.22, 0.18, 0.14, 0.65),  # Bog: dark peat residue
	Color(0.20, 0.28, 0.22, 0.62),  # Swamp: dried green-brown
	Color(0.25, 0.40, 0.55, 0.55),  # Lake: pale blue
	Color(0.22, 0.30, 0.42, 0.60),  # Reservoir: faded gray-blue
	Color(0.20, 0.42, 0.45, 0.58),  # Lagoon: faded teal
	Color(0.14, 0.16, 0.22, 0.68),  # Bayou: dark residue
	Color(0.10, 0.14, 0.28, 0.72),  # The Atlantic: dark slate
]
const SWAMP_DEPTH_COLORS: Array[Color] = [
	Color(0.15, 0.35, 0.38, 0.40),  # Puddle: light teal depth
	Color(0.06, 0.22, 0.08, 0.55),  # Pond: forest green depth
	Color(0.18, 0.14, 0.06, 0.65),  # Marsh: mud brown depth
	Color(0.05, 0.04, 0.03, 0.75),  # Bog: near-black depth
	Color(0.04, 0.10, 0.06, 0.72),  # Swamp: dark green depth
	Color(0.06, 0.15, 0.30, 0.70),  # Lake: deep blue depth
	Color(0.05, 0.10, 0.22, 0.75),  # Reservoir: dark steel depth
	Color(0.04, 0.18, 0.22, 0.72),  # Lagoon: teal depth
	Color(0.02, 0.03, 0.08, 0.82),  # Bayou: pitch dark depth
	Color(0.01, 0.03, 0.12, 0.88),  # The Atlantic: abyssal depth
]
# Per-pool shader parameters: [wave_strength, specular, choppiness, turbidity, foam_density]
const POOL_SHADER_PARAMS: Array[Array] = [
	[0.5, 0.4, 0.0, 0.0, 0.3],     # Puddle: calm, clear, minimal foam
	[1.2, 0.3, 0.3, 0.15, 0.8],    # Pond: gentle waves, some sheen
	[1.5, 0.15, 0.8, 0.5, 1.2],    # Marsh: choppy, murky
	[1.8, 0.1, 1.2, 0.7, 1.5],     # Bog: rough, opaque
	[2.2, 0.08, 1.8, 0.8, 1.8],    # Swamp: rough, murky
	[1.8, 0.25, 1.0, 0.3, 1.0],    # Lake: moderate, clearer
	[1.5, 0.12, 0.8, 0.5, 1.4],    # Reservoir: contained, steady
	[2.0, 0.20, 1.4, 0.4, 1.6],    # Lagoon: tropical waves
	[2.8, 0.06, 2.2, 0.9, 2.2],    # Bayou: wild, opaque
	[3.5, 0.05, 2.5, 0.95, 2.5],   # The Atlantic: massive, deep
]
# Per-pool R2 water params: [beers, reflect_strength, opacity_floor, refraction_strength]
# Early pools = clearer (lower beers, more reflection, more refraction);
# late pools = tar-black (high beers, opaque, little refraction).
const POOL_WATER_R2: Array[Array] = [
	[2.2, 0.45, 0.40, 0.022],  # Puddle: clear-ish
	[2.8, 0.40, 0.48, 0.020],  # Pond
	[3.4, 0.34, 0.55, 0.016],  # Marsh
	[4.2, 0.28, 0.62, 0.012],  # Bog
	[4.6, 0.24, 0.66, 0.010],  # Swamp
	[3.0, 0.40, 0.50, 0.020],  # Lake: clearer
	[3.6, 0.30, 0.58, 0.014],  # Reservoir
	[3.4, 0.34, 0.55, 0.016],  # Lagoon
	[5.2, 0.20, 0.72, 0.008],  # Bayou: near tar
	[5.6, 0.18, 0.76, 0.006],  # The Atlantic: deep dark
]
# Per-pool shallow/deep depth-tint colors (murky bayou palette)
const POOL_SHALLOW_COLORS: Array[Color] = [
	Color(0.18, 0.30, 0.26),  # Puddle: clear teal-green
	Color(0.16, 0.26, 0.18),  # Pond
	Color(0.16, 0.18, 0.11),  # Marsh: mud
	Color(0.12, 0.13, 0.09),  # Bog
	Color(0.13, 0.18, 0.12),  # Swamp
	Color(0.16, 0.24, 0.28),  # Lake: clearer blue-green
	Color(0.13, 0.17, 0.20),  # Reservoir
	Color(0.14, 0.22, 0.21),  # Lagoon
	Color(0.09, 0.11, 0.10),  # Bayou
	Color(0.08, 0.11, 0.14),  # The Atlantic
]
const POOL_DEEP_COLORS: Array[Color] = [
	Color(0.05, 0.12, 0.10),  # Puddle
	Color(0.04, 0.09, 0.06),  # Pond
	Color(0.05, 0.05, 0.03),  # Marsh
	Color(0.02, 0.03, 0.02),  # Bog: near black
	Color(0.03, 0.06, 0.04),  # Swamp
	Color(0.04, 0.09, 0.13),  # Lake
	Color(0.03, 0.06, 0.10),  # Reservoir
	Color(0.03, 0.09, 0.10),  # Lagoon
	Color(0.01, 0.02, 0.02),  # Bayou: tar
	Color(0.01, 0.02, 0.05),  # The Atlantic: abyss
]
# Per-pool foam colors
const POOL_FOAM_COLORS: Array[Color] = [
	Color(0.95, 0.97, 1.0, 0.35),   # Puddle: clean white
	Color(0.85, 0.92, 0.85, 0.30),  # Pond: green-white
	Color(0.65, 0.58, 0.42, 0.28),  # Marsh: brownish foam
	Color(0.45, 0.38, 0.28, 0.25),  # Bog: dark brown foam
	Color(0.35, 0.40, 0.30, 0.24),  # Swamp: dark green foam
	Color(0.70, 0.80, 0.92, 0.28),  # Lake: blue-white foam
	Color(0.50, 0.55, 0.65, 0.25),  # Reservoir: gray foam
	Color(0.60, 0.75, 0.78, 0.26),  # Lagoon: teal foam
	Color(0.25, 0.28, 0.35, 0.20),  # Bayou: near-black foam
	Color(0.40, 0.50, 0.70, 0.22),  # The Atlantic: deep blue foam
]
# Per-pool wave params: [amplitude, frequency]
const POOL_WAVE_PARAMS: Array[Array] = [
	[0.5, 3.0],   # Puddle: small/fast ripples
	[1.0, 2.2],   # Pond: moderate
	[1.6, 1.5],   # Marsh: medium/slower
	[2.2, 1.1],   # Bog: large/slow
	[2.6, 0.9],   # Swamp: large/slow
	[2.0, 1.2],   # Lake: moderate/wide
	[1.8, 1.0],   # Reservoir: steady
	[2.4, 0.9],   # Lagoon: tropical swell
	[3.0, 0.7],   # Bayou: heavy/slow
	[4.0, 0.5],   # The Atlantic: massive/very slow
]
# Per-pool bowl depth for rounded basin shape
const GRASS_COLOR := Color(0.25, 0.48, 0.15)
const GRASS_LIGHT_COLOR := Color(0.35, 0.58, 0.2)
const ROCK_COLOR := Color(0.42, 0.4, 0.38)
const ROCK_DARK_COLOR := Color(0.32, 0.3, 0.28)

var wave_time: float = 0.0

var _hdr_glow: bool = false  # true on Forward+/Mobile (real HDR-2D glow); false on GL Compatibility (web)

func _ready() -> void:
	cycle_time = CYCLE_DURATION * GameManager.cycle_progress
	_init_sway_materials()
	_setup_hdr_glow()
	_build_parallax()
	_build_sky()
	_build_sun()
	_build_clouds()
	_build_distant_hills()
	_build_treeline()
	_build_terrain()
	_build_terrain_details()
	_build_terrain_zones()
	_build_shop()
	_build_water()
	_build_water_walls()
	_build_water_detect_areas()
	_build_swamp_labels()
	_build_vegetation()
	_build_stars()
	_build_fireflies()
	_build_tree_trunks()
	_build_lily_pads()
	_build_depth_gradients()
	_build_shimmer_lines()
	_build_mud_patches()
	_build_mushrooms()
	_build_ferns()
	_build_moon()
	_build_foam_lines()
	_build_fog_patches()
	_build_dragonflies()
	_build_water_highlights()
	_build_fish()
	_build_frogs()
	_build_glow_plants()
	_build_seaweed()
	_build_turtles()
	_build_tadpoles()
	_build_crickets()
	_build_pool_features()
	_build_pool_glow_lights()
	_build_left_boundary()
	_build_left_trees()
	_build_cypresses()
	_build_right_boundary()
	_build_island_house()
	_build_island_politicians()
	_build_post_processing()
	_build_distance_fog()
	_build_god_rays()
	_build_fbm_fog()
	_build_foreground_silhouette()
	_build_weather()
	_build_drain_reveals()
	_build_drained_pool_beds()
	_build_waterfall_drips()
	_build_atmosphere()
	_build_player_shadow()
	_build_cave_entrances()
	_build_billboards()
	_init_drain_thresholds()

	GameManager.water_level_changed.connect(_on_water_level_changed)
	GameManager.cave_unlocked.connect(_on_cave_unlocked)
	GameManager.swamp_completed.connect(_on_swamp_completed)
	GameManager.scoop_performed.connect(_on_scoop_performed)
	GameManager.camel_changed.connect(_on_camel_changed)
	_build_camels()

	# Show tutorial on first play
	if GameManager.swamp_states[0]["gallons_drained"] <= 0.001:
		call_deferred("_show_tutorial")

func _show_tutorial() -> void:
	var text := "ARROW KEYS — Move\nSPACE near water — Scoop\nSPACE at shop — Open shop\nSPACE near cave — Enter cave\nESC — Menu\n\nScoop water, sell it at the shop, buy upgrades, and drain the swamp!"
	SceneManager.show_document_popup(text, "HOW TO PLAY")

# --- Shared foliage sway materials (R3) ---
func _init_sway_materials() -> void:
	_sway_mat_grass = ShaderMaterial.new()
	_sway_mat_grass.shader = FOLIAGE_SWAY_SHADER
	_sway_mat_grass.set_shader_parameter("sway_strength", 2.4)
	_sway_mat_grass.set_shader_parameter("sway_speed", 1.5)
	_sway_mat_grass.set_shader_parameter("gust_wavelength", 200.0)
	_sway_mat_grass.set_shader_parameter("gust_speed", 70.0)
	_sway_mat_grass.set_shader_parameter("stiffness", 1.4)

	_sway_mat_frond = ShaderMaterial.new()
	_sway_mat_frond.shader = FOLIAGE_SWAY_SHADER
	_sway_mat_frond.set_shader_parameter("sway_strength", 3.2)
	_sway_mat_frond.set_shader_parameter("sway_speed", 1.0)
	_sway_mat_frond.set_shader_parameter("gust_wavelength", 240.0)
	_sway_mat_frond.set_shader_parameter("gust_speed", 60.0)
	_sway_mat_frond.set_shader_parameter("stiffness", 1.8)

	_sway_mat_canopy = ShaderMaterial.new()
	_sway_mat_canopy.shader = FOLIAGE_SWAY_SHADER
	_sway_mat_canopy.set_shader_parameter("sway_strength", 1.6)
	_sway_mat_canopy.set_shader_parameter("sway_speed", 0.7)
	_sway_mat_canopy.set_shader_parameter("gust_wavelength", 320.0)
	_sway_mat_canopy.set_shader_parameter("gust_speed", 50.0)
	_sway_mat_canopy.set_shader_parameter("stiffness", 2.4)

	_sway_mat_moss = ShaderMaterial.new()
	_sway_mat_moss.shader = FOLIAGE_SWAY_SHADER
	_sway_mat_moss.set_shader_parameter("sway_strength", 4.5)
	_sway_mat_moss.set_shader_parameter("sway_speed", 0.6)
	_sway_mat_moss.set_shader_parameter("gust_wavelength", 280.0)
	_sway_mat_moss.set_shader_parameter("gust_speed", 45.0)
	_sway_mat_moss.set_shader_parameter("stiffness", 0.6)

# Deterministic cluster noise in [0,1] for foliage density gating.
func _cluster_noise(x: float) -> float:
	return (sin(x * 0.013) * 0.5 + sin(x * 0.041 + 1.7) * 0.3 + sin(x * 0.091 + 4.2) * 0.2) * 0.5 + 0.5

# --- Atmospheric perspective helper ---
# Pushes a distant layer's color toward the sky: desaturate + lighten + blue-shift.
# depth 0 = near (no change), 1 = far horizon.
func _atmospheric_tint(base: Color, depth: float, atmo: Color) -> Color:
	var g: float = base.get_luminance()
	var c: Color = Color(g, g, g).lerp(base, lerpf(1.0, 0.35, depth))  # desaturate far
	return c.lerp(atmo, depth * 0.65)                                  # lighten + shift to sky

# --- Parallax ---
func _build_parallax() -> void:
	parallax_bg = ParallaxBackground.new()
	add_child(parallax_bg)
	sky_layer = ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0, 0)
	parallax_bg.add_child(sky_layer)
	far_hills_layer = ParallaxLayer.new()
	far_hills_layer.motion_scale = Vector2(0.1, 0.03)
	parallax_bg.add_child(far_hills_layer)
	near_hills_layer = ParallaxLayer.new()
	near_hills_layer.motion_scale = Vector2(0.3, 0.05)
	parallax_bg.add_child(near_hills_layer)
	treeline_layer = ParallaxLayer.new()
	treeline_layer.motion_scale = Vector2(0.6, 0)
	parallax_bg.add_child(treeline_layer)
	# Foreground silhouette layer — passes faster than the world to frame the shot.
	foreground_layer = ParallaxLayer.new()
	foreground_layer.motion_scale = Vector2(1.1, 1.0)
	parallax_bg.add_child(foreground_layer)

# --- Sky & Atmosphere ---
# Sky gradient presets: [top, mid, bottom] for each time of day
const SKY_DAWN: Array[Color] = [Color(0.35, 0.25, 0.50), Color(0.72, 0.45, 0.38), Color(0.90, 0.65, 0.45)]
const SKY_DAY: Array[Color] = [Color(0.22, 0.38, 0.72), Color(0.45, 0.62, 0.88), Color(0.62, 0.78, 0.92)]
const SKY_DUSK: Array[Color] = [Color(0.28, 0.18, 0.42), Color(0.75, 0.38, 0.28), Color(0.88, 0.55, 0.35)]
const SKY_NIGHT: Array[Color] = [Color(0.04, 0.05, 0.12), Color(0.06, 0.08, 0.18), Color(0.08, 0.10, 0.22)]

# Heal master-lerp endpoints (murky -> healed), applied on top of the time-of-day sky.
# Murky overlay = sickly grey-green; healed = clean. Subtle (weighted below).
const HEAL_SKY_MURKY := Color(0.40, 0.44, 0.34)   # tint the whole sky pushes toward when murky
const HEAL_FOG_MURKY := Color(0.50, 0.55, 0.42)   # ground/haze fog color when murky
const HEAL_FOG_HEALED := Color(0.66, 0.72, 0.70)  # clean cool haze when drained
const HEAL_RAY_MURKY := Color(0.78, 0.82, 0.55)   # sickly shaft color when murky
const HEAL_RAY_HEALED := Color(1.0, 0.90, 0.62)   # warm golden shaft when drained

func _build_sky() -> void:
	var world_w: float = terrain_points[terrain_points.size() - 1].x + 200.0
	var max_y: float = 0.0
	for pt in terrain_points:
		if pt.y > max_y:
			max_y = pt.y
	var sky_bottom: float = max_y + 200.0

	# Smooth gradient sky using GradientTexture2D
	sky_gradient_res = Gradient.new()
	sky_gradient_res.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	sky_gradient_res.colors = PackedColorArray([SKY_DAY[0], SKY_DAY[1], SKY_DAY[2]])

	sky_gradient = GradientTexture2D.new()
	sky_gradient.gradient = sky_gradient_res
	sky_gradient.width = 1
	sky_gradient.height = 128
	sky_gradient.fill = GradientTexture2D.FILL_LINEAR
	sky_gradient.fill_from = Vector2(0.0, 0.0)
	sky_gradient.fill_to = Vector2(0.0, 1.0)

	sky_texture_rect = TextureRect.new()
	sky_texture_rect.texture = sky_gradient
	sky_texture_rect.position = Vector2(-100, -80)
	sky_texture_rect.size = Vector2(world_w + 200, sky_bottom + 80)
	sky_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_texture_rect.z_index = -12
	sky_layer.add_child(sky_texture_rect)

	# Horizon glow line (intensifies at dawn/dusk)
	horizon_glow = Line2D.new()
	horizon_glow.width = 8.0
	horizon_glow.default_color = Color(1.0, 0.75, 0.4, 0.0)
	horizon_glow.z_index = -11
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	horizon_glow.material = mat
	var half_vp: float = get_viewport_rect().size.x / 2.0
	horizon_glow.add_point(Vector2(-200, 86))
	horizon_glow.add_point(Vector2(world_w + 200, 86))
	sky_layer.add_child(horizon_glow)

func _make_disc(radius: float, segs: int = 32) -> PackedVector2Array:
	# Smooth circle (was an 8-gon — looked basic, especially once bloom feathers it).
	var pts := PackedVector2Array()
	for i in range(segs):
		var angle: float = float(i) / float(segs) * TAU
		pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return pts

func _build_sun() -> void:
	sun_node = Node2D.new()
	sun_node.z_index = -10
	sun_node.visible = false
	add_child(sun_node)

	# Soft glowing orb (no hard disc): a wide soft halo + a tight bright core,
	# both additive + overbright so HDR glow feathers them into a real sun (~2x old size).
	var sun_halo := _make_glow_orb(38.0, _emit(Color(1.0, 0.9, 0.55, 0.45), 1.3))
	sun_node.add_child(sun_halo)

	# PointLight2D for dynamic sun glow
	var sun_light := PointLight2D.new()
	sun_light.color = Color(1.0, 0.95, 0.7)
	sun_light.energy = 0.4
	sun_light.texture = _make_light_texture()
	sun_light.texture_scale = 3.0
	sun_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	sun_node.add_child(sun_light)

	var sun_core := _make_glow_orb(18.0, _emit(Color(1.0, 0.97, 0.8, 0.85), 1.9))
	sun_node.add_child(sun_core)

# A soft, edgeless glowing orb: a radial white→transparent sprite, additive, tinted
# by `color` (push rgb >1.0 via _emit so HDR glow blooms it). `radius` is in world px.
func _make_glow_orb(radius: float, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _make_light_texture()  # 64px radial gradient (~32px visible radius)
	s.scale = Vector2(radius / 32.0, radius / 32.0)
	s.modulate = color
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	return s

func _make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex

func _build_clouds() -> void:
	var cloud_data: Array = [
		{"x": 100, "y": 10, "w": 56, "h": 16},
		{"x": 360, "y": 36, "w": 40, "h": 12},
		{"x": 700, "y": 4, "w": 70, "h": 18},
		{"x": 1040, "y": 24, "w": 48, "h": 14},
		{"x": 1400, "y": 12, "w": 60, "h": 16},
		{"x": 1700, "y": 30, "w": 44, "h": 12},
	]
	for cd in cloud_data:
		var cloud_group := Node2D.new()
		cloud_group.z_index = -8
		cloud_group.position = Vector2(cd["x"], cd["y"])
		add_child(cloud_group)

		var w: float = cd["w"]
		var h: float = cd["h"]
		# Organic cloud body (Polygon2D with puffy outline)
		var main_poly := Polygon2D.new()
		var pts: PackedVector2Array = _make_cloud_shape(w, h)
		main_poly.polygon = pts
		main_poly.color = Color(0.92, 0.94, 0.98, 0.65)
		cloud_group.add_child(main_poly)

		# Inner shadow (slightly offset, darker)
		var shadow_poly := Polygon2D.new()
		var shadow_pts := PackedVector2Array()
		for pt in pts:
			shadow_pts.append(Vector2(pt.x + 1, pt.y + 2))
		shadow_poly.polygon = shadow_pts
		shadow_poly.color = Color(0.78, 0.82, 0.90, 0.25)
		cloud_group.add_child(shadow_poly)
		cloud_group.move_child(shadow_poly, 0)

		# Bright highlight rim on top
		var hl_poly := Polygon2D.new()
		var hl_pts := PackedVector2Array()
		for pi in range(pts.size()):
			var p: Vector2 = pts[pi]
			if p.y < h * 0.4:
				hl_pts.append(Vector2(p.x, p.y - 1))
		if hl_pts.size() >= 3:
			hl_pts.append(Vector2(hl_pts[hl_pts.size() - 1].x, h * 0.35))
			hl_pts.append(Vector2(hl_pts[0].x, h * 0.35))
			hl_poly.polygon = hl_pts
			hl_poly.color = Color(0.97, 0.98, 1.0, 0.4)
			cloud_group.add_child(hl_poly)

		clouds.append(cloud_group)

func _make_cloud_shape(w: float, h: float) -> PackedVector2Array:
	# Generate a puffy cloud outline (8-12 point organic shape)
	var pts := PackedVector2Array()
	var cx: float = w * 0.5
	var cy: float = h * 0.5
	# Bottom edge (flat-ish)
	pts.append(Vector2(w * 0.1, h * 0.8))
	pts.append(Vector2(w * 0.35, h * 0.9))
	pts.append(Vector2(w * 0.65, h * 0.9))
	pts.append(Vector2(w * 0.9, h * 0.8))
	# Right puff
	pts.append(Vector2(w * 1.05, h * 0.5))
	pts.append(Vector2(w * 0.95, h * 0.15))
	# Top puffs (the puffy bumps)
	pts.append(Vector2(w * 0.72, h * -0.1))
	pts.append(Vector2(w * 0.5, h * -0.15))
	pts.append(Vector2(w * 0.28, h * -0.05))
	# Left puff
	pts.append(Vector2(w * 0.05, h * 0.2))
	pts.append(Vector2(w * -0.05, h * 0.55))
	return pts

func _build_distant_hills() -> void:
	var world_w: float = terrain_points[terrain_points.size() - 1].x + 100.0
	# Far hills silhouette — procedural across world width
	var far_pts := PackedVector2Array()
	var fx: float = -100.0
	while fx < world_w:
		far_pts.append(Vector2(fx, randf_range(84, 124)))
		fx += randf_range(180, 300)
	far_pts.append(Vector2(world_w, 116))
	far_pts.append(Vector2(world_w, 150))
	far_pts.append(Vector2(-100, 150))
	var atmo: Color = SKY_DAY[2]  # sky-bottom color drives the haze
	var hills := Polygon2D.new()
	hills.polygon = far_pts
	var far_tint: Color = _atmospheric_tint(Color(0.12, 0.28, 0.12), 0.9, atmo)
	hills.color = Color(far_tint.r, far_tint.g, far_tint.b, 0.6)
	hills.z_index = -7
	far_hills_layer.add_child(hills)

	# Mid hills
	var mid_pts := PackedVector2Array()
	var mx: float = -100.0
	while mx < world_w:
		mid_pts.append(Vector2(mx, randf_range(104, 130)))
		mx += randf_range(160, 280)
	mid_pts.append(Vector2(world_w, 124))
	mid_pts.append(Vector2(world_w, 156))
	mid_pts.append(Vector2(-100, 156))
	var hills2 := Polygon2D.new()
	hills2.polygon = mid_pts
	var mid_tint: Color = _atmospheric_tint(Color(0.08, 0.22, 0.08), 0.65, atmo)
	hills2.color = Color(mid_tint.r, mid_tint.g, mid_tint.b, 0.7)
	hills2.z_index = -6
	near_hills_layer.add_child(hills2)

func _build_treeline() -> void:
	var world_w: float = terrain_points[terrain_points.size() - 1].x + 100.0
	# Dense treeline - jagged top edge for tree canopy look
	var tree_points := PackedVector2Array()
	var x: float = -100.0
	while x < world_w:
		var tree_h: float = randf_range(12, 28)
		tree_points.append(Vector2(x, 136 - tree_h))
		tree_points.append(Vector2(x + randf_range(6, 16), 136 - tree_h + randf_range(4, 10)))
		x += randf_range(10, 24)
	tree_points.append(Vector2(world_w, 136))
	tree_points.append(Vector2(world_w, 164))
	tree_points.append(Vector2(-100, 164))

	var atmo: Color = SKY_DAY[2]
	var treeline := Polygon2D.new()
	treeline.polygon = tree_points
	# 2-tone: dappled lighter top -> darker base band via per-vertex colors (R3).
	var base_dark: Color = _atmospheric_tint(Color(0.05, 0.14, 0.04), 0.32, atmo)
	var top_light: Color = _atmospheric_tint(Color(0.12, 0.26, 0.09), 0.26, atmo)
	var tcols := PackedColorArray()
	for tp in tree_points:
		# Higher (smaller y) canopy tips get the lighter dappled color.
		var f: float = clampf((136.0 - tp.y) / 30.0, 0.0, 1.0)
		var c: Color = base_dark.lerp(top_light, f)
		# Subtle dapple
		c = c.lightened(0.06 * (sin(tp.x * 0.21) * 0.5 + 0.5))
		tcols.append(c)
	treeline.vertex_colors = tcols
	treeline.z_index = -5
	treeline_layer.add_child(treeline)

	# Lighter highlight trees in front
	var tree_points2 := PackedVector2Array()
	x = -100.0
	while x < world_w:
		var tree_h: float = randf_range(8, 20)
		tree_points2.append(Vector2(x, 140 - tree_h))
		tree_points2.append(Vector2(x + randf_range(6, 12), 140 - tree_h + randf_range(4, 8)))
		x += randf_range(12, 28)
	tree_points2.append(Vector2(world_w, 140))
	tree_points2.append(Vector2(world_w, 164))
	tree_points2.append(Vector2(-100, 164))

	var treeline2 := Polygon2D.new()
	treeline2.polygon = tree_points2
	var base_dark2: Color = _atmospheric_tint(Color(0.08, 0.20, 0.06), 0.24, atmo)
	var top_light2: Color = _atmospheric_tint(Color(0.16, 0.32, 0.11), 0.18, atmo)
	var tcols2 := PackedColorArray()
	for tp in tree_points2:
		var f: float = clampf((140.0 - tp.y) / 24.0, 0.0, 1.0)
		tcols2.append(base_dark2.lerp(top_light2, f))
	treeline2.vertex_colors = tcols2
	treeline2.z_index = -4
	treeline_layer.add_child(treeline2)

func _build_terrain() -> void:
	# Find the deepest terrain point to set the fill bottom
	var max_y: float = 0.0
	for pt in terrain_points:
		if pt.y > max_y:
			max_y = pt.y
	var fill_bottom: float = max_y + 100.0

	# Main ground polygon
	terrain_polygon = Polygon2D.new()
	var ground_points: PackedVector2Array = PackedVector2Array()
	for pt in terrain_points:
		ground_points.append(pt)
	ground_points.append(Vector2(terrain_points[-1].x, fill_bottom))
	ground_points.append(Vector2(terrain_points[0].x, fill_bottom))
	terrain_polygon.polygon = ground_points
	terrain_polygon.color = GROUND_COLOR
	terrain_polygon.z_index = 0
	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	# Depth-darkening reference: topmost (smallest world-Y) terrain surface point.
	var min_surface_y: float = terrain_points[0].y
	for pt2 in terrain_points:
		if pt2.y < min_surface_y:
			min_surface_y = pt2.y
	terrain_mat.set_shader_parameter("surface_y", min_surface_y)
	terrain_mat.set_shader_parameter("depth_range", max_y - min_surface_y + 80.0)
	terrain_polygon.material = terrain_mat
	_terrain_mat = terrain_mat
	add_child(terrain_polygon)

	# Mid soil layer
	var midsoil := Polygon2D.new()
	var mid_points: PackedVector2Array = PackedVector2Array()
	for pt in terrain_points:
		mid_points.append(Vector2(pt.x, pt.y + 10))
	mid_points.append(Vector2(terrain_points[-1].x, fill_bottom))
	mid_points.append(Vector2(terrain_points[0].x, fill_bottom))
	midsoil.polygon = mid_points
	midsoil.color = GROUND_MID_COLOR
	midsoil.z_index = -1
	add_child(midsoil)

	# Dark subsoil layer
	var subsoil := Polygon2D.new()
	var sub_points: PackedVector2Array = PackedVector2Array()
	for pt in terrain_points:
		sub_points.append(Vector2(pt.x, pt.y + 24))
	sub_points.append(Vector2(terrain_points[-1].x, fill_bottom))
	sub_points.append(Vector2(terrain_points[0].x, fill_bottom))
	subsoil.polygon = sub_points
	subsoil.color = GROUND_DARK_COLOR
	subsoil.z_index = -2
	add_child(subsoil)

	# Grass strip on top of terrain - two layers for depth
	var grass_dark := Line2D.new()
	grass_dark.width = 6.0
	grass_dark.default_color = GRASS_COLOR
	for pt in terrain_points:
		grass_dark.add_point(pt)
	grass_dark.z_index = 1
	add_child(grass_dark)

	var grass_light := Line2D.new()
	grass_light.width = 3.0
	grass_light.default_color = GRASS_LIGHT_COLOR
	for pt in terrain_points:
		grass_light.add_point(Vector2(pt.x, pt.y - 1.0))
	grass_light.z_index = 1
	add_child(grass_light)

	# Contact AO: a thin soft-dark band just under the surface grass line so the
	# grass reads as casting onto the soil (R3).
	var ao_line := Line2D.new()
	ao_line.width = 4.0
	ao_line.default_color = Color(0.05, 0.06, 0.02, 0.30)
	for pt in terrain_points:
		ao_line.add_point(Vector2(pt.x, pt.y + 3.5))
	ao_line.z_index = 0
	add_child(ao_line)

	# Overhanging grass fringe: small downward dark-green tongues over the
	# grass->dirt edge to break the hard surface Line2D (R3).
	for pt_idx in range(0, terrain_points.size() - 1):
		var fp: Vector2 = terrain_points[pt_idx]
		if randf() < 0.45:
			var fr := Polygon2D.new()
			var fw: float = randf_range(3, 7)
			var fh: float = randf_range(2.5, 5.0)
			var fx0: float = fp.x + randf_range(-3, 3)
			fr.polygon = PackedVector2Array([
				Vector2(fx0, fp.y - 0.5),
				Vector2(fx0 + fw, fp.y - 0.5),
				Vector2(fx0 + fw * 0.5, fp.y + fh),
			])
			fr.color = Color(0.10, 0.26, 0.07, 0.85)
			fr.z_index = 1
			add_child(fr)

	# Grass-to-dirt boundary dither is now handled in FRAGCOORD space by
	# terrain.gdshader bayer4() (R0 high-res): it scales with physical resolution
	# instead of spawning ~700 base-pixel ColorRects that became sub-pixel slivers
	# at HD scale. (Removed Phase 18a per-pixel dither loop.)

	# Collision: build segments between each pair of terrain points
	terrain_body = StaticBody2D.new()
	add_child(terrain_body)

	for i in range(terrain_points.size() - 1):
		var seg := CollisionShape2D.new()
		var shape := SegmentShape2D.new()
		shape.a = terrain_points[i]
		shape.b = terrain_points[i + 1]
		seg.shape = shape
		terrain_body.add_child(seg)

	# Left wall
	var left_wall := CollisionShape2D.new()
	var lw_shape := SegmentShape2D.new()
	lw_shape.a = Vector2(-20, -100)
	lw_shape.b = Vector2(-20, fill_bottom)
	left_wall.shape = lw_shape
	terrain_body.add_child(left_wall)

	# Right wall
	var right_x: float = terrain_points[-1].x + 40.0
	var right_wall := CollisionShape2D.new()
	var rw_shape := SegmentShape2D.new()
	rw_shape.a = Vector2(right_x, -100)
	rw_shape.b = Vector2(right_x, fill_bottom)
	right_wall.shape = rw_shape
	terrain_body.add_child(right_wall)

func _build_terrain_details() -> void:
	# Rocks scattered on ridges and shores
	var rock_positions: Array[Vector2] = [
		Vector2(30, 134), Vector2(64, 134),
		Vector2(220, 138), Vector2(245, 148),
		Vector2(545, 162), Vector2(580, 170),
		Vector2(925, 190), Vector2(960, 206),
		Vector2(1330, 224), Vector2(1365, 242),
		Vector2(1820, 290), Vector2(1855, 300),
		Vector2(2495, 340), Vector2(2530, 346),
		Vector2(3090, 368), Vector2(3120, 374),
		Vector2(3730, 396), Vector2(3760, 404),
		Vector2(4405, 420), Vector2(4440, 430),
		Vector2(5380, 480), Vector2(5440, 486),
	]
	for rp in rock_positions:
		_place_rock(rp, randf_range(4, 10), randf_range(4, 8))

	# Dirt specks on terrain surface (zone-tinted)
	var world_right: float = terrain_points[terrain_points.size() - 1].x
	for i in range(150):
		var rx: float = randf_range(0, world_right)
		var ry: float = _get_terrain_y_at(rx)
		if ry > 0:
			var speck := ColorRect.new()
			speck.position = Vector2(rx, ry + randf_range(2, 12))
			speck.size = Vector2(randf_range(2, 6), randf_range(2, 4))
			var base_col: Color = GROUND_DARK_COLOR.lerp(GROUND_COLOR, randf_range(0, 1))
			var zone_col: Color = ZONE_TINT_COLORS[_get_zone_index(rx)]
			speck.color = base_col.lerp(zone_col, 0.3)
			speck.color.a = randf_range(0.3, 0.6)
			speck.z_index = 0
			add_child(speck)

	# Soil strata lines - horizontal bands of slightly different color
	for i in range(60):
		var rx: float = randf_range(0, world_right)
		var ry: float = _get_terrain_y_at(rx)
		if ry > 0:
			var stratum := ColorRect.new()
			var depth: float = randf_range(14, 50)
			stratum.position = Vector2(rx, ry + depth)
			stratum.size = Vector2(randf_range(20, 80), randf_range(1, 3))
			var shade: float = randf_range(0.0, 0.3)
			stratum.color = Color(0.35 + shade * 0.1, 0.22 + shade * 0.1, 0.08 + shade * 0.06, randf_range(0.2, 0.4))
			stratum.z_index = 0
			add_child(stratum)

	# Small pebbles embedded in dirt
	for i in range(80):
		var rx: float = randf_range(0, world_right)
		var ry: float = _get_terrain_y_at(rx)
		if ry > 0:
			var pebble := ColorRect.new()
			pebble.position = Vector2(rx, ry + randf_range(1, 8))
			var sz: float = randf_range(2, 4)
			pebble.size = Vector2(sz, sz * randf_range(0.6, 1.0))
			pebble.color = ROCK_COLOR.lerp(ROCK_DARK_COLOR, randf())
			pebble.color.a = randf_range(0.5, 0.8)
			pebble.z_index = 0
			add_child(pebble)

	# Root-like dark lines near surface
	for i in range(45):
		var rx: float = randf_range(0, world_right)
		var ry: float = _get_terrain_y_at(rx)
		if ry > 0:
			var root := Line2D.new()
			root.width = randf_range(1.0, 2.0)
			root.default_color = Color(0.22, 0.14, 0.06, randf_range(0.25, 0.5))
			root.z_index = 0
			var segments: int = randi_range(3, 6)
			var px: float = rx
			var py: float = ry + randf_range(4, 16)
			for j in range(segments):
				root.add_point(Vector2(px, py))
				px += randf_range(6, 18)
				py += randf_range(-3, 5)
			add_child(root)

	# Dark dirt patches (clay/humus areas)
	for i in range(30):
		var rx: float = randf_range(0, world_right)
		var ry: float = _get_terrain_y_at(rx)
		if ry > 0:
			var patch := ColorRect.new()
			patch.position = Vector2(rx, ry + randf_range(6, 30))
			patch.size = Vector2(randf_range(12, 40), randf_range(6, 16))
			patch.color = Color(0.3, 0.18, 0.06, randf_range(0.15, 0.3))
			patch.z_index = 0
			add_child(patch)

	# Sandy/lighter patches on ridges
	for i in range(25):
		var rx: float = randf_range(0, world_right)
		var ry: float = _get_terrain_y_at(rx)
		if ry > 0:
			var sandy := ColorRect.new()
			sandy.position = Vector2(rx, ry + randf_range(1, 6))
			sandy.size = Vector2(randf_range(8, 24), randf_range(3, 8))
			sandy.color = Color(0.55, 0.42, 0.25, randf_range(0.15, 0.3))
			sandy.z_index = 0
			add_child(sandy)

	# Small worm holes / burrows
	for i in range(20):
		var rx: float = randf_range(50, world_right - 20)
		var ry: float = _get_terrain_y_at(rx)
		if ry > 0:
			var hole := ColorRect.new()
			hole.position = Vector2(rx, ry + randf_range(1, 4))
			hole.size = Vector2(3, 3)
			hole.color = Color(0.15, 0.08, 0.02, 0.5)
			hole.z_index = 0
			add_child(hole)

# Soft dark contact-shadow ellipse under a prop/tree base (R3).
func _place_contact_ao(cx: float, cy: float, rw: float, rh: float, alpha: float, zi: int = 0) -> void:
	var ao := Polygon2D.new()
	var pts := PackedVector2Array()
	for a in range(10):
		var ang: float = TAU * float(a) / 10.0
		pts.append(Vector2(cx + cos(ang) * rw, cy + sin(ang) * rh))
	ao.polygon = pts
	ao.color = Color(0.03, 0.04, 0.02, alpha)
	ao.z_index = zi
	add_child(ao)

func _place_rock(pos: Vector2, w: float, h: float) -> void:
	_place_contact_ao(pos.x + w * 0.5, pos.y + h, w * 0.7, h * 0.35, 0.28, 0)
	var rock := Polygon2D.new()
	rock.polygon = PackedVector2Array([
		Vector2(pos.x + 2, pos.y),
		Vector2(pos.x + w - 2, pos.y),
		Vector2(pos.x + w, pos.y + h * 0.4),
		Vector2(pos.x + w - 1.0, pos.y + h),
		Vector2(pos.x + 1.0, pos.y + h),
		Vector2(pos.x, pos.y + h * 0.4),
	])
	rock.color = ROCK_COLOR
	rock.z_index = 1
	add_child(rock)

	# Rock highlight
	var hl := ColorRect.new()
	hl.position = Vector2(pos.x + 2, pos.y + 1.0)
	hl.size = Vector2(w - 4, 2)
	hl.color = Color(0.55, 0.53, 0.5, 0.5)
	hl.z_index = 1
	add_child(hl)

# Zone palette for terrain: left (sandy) to right (dark)
const ZONE_TINT_COLORS: Array[Color] = [
	Color(0.65, 0.55, 0.35, 0.18),  # Zone 0 (Puddle): warm sandy tan
	Color(0.50, 0.38, 0.22, 0.20),  # Zone 1 (Pond): earthy medium brown
	Color(0.38, 0.28, 0.14, 0.22),  # Zone 2 (Marsh): dark muddy brown
	Color(0.25, 0.18, 0.10, 0.25),  # Zone 3 (Bog): very dark peaty brown
	Color(0.15, 0.14, 0.08, 0.26),  # Zone 4 (Swamp): dark murky
	Color(0.20, 0.30, 0.42, 0.22),  # Zone 5 (Lake): blue-gray
	Color(0.32, 0.32, 0.30, 0.24),  # Zone 6 (Reservoir): concrete gray
	Color(0.25, 0.40, 0.38, 0.22),  # Zone 7 (Lagoon): tropical teal
	Color(0.10, 0.08, 0.06, 0.28),  # Zone 8 (Bayou): near-black
	Color(0.08, 0.12, 0.22, 0.30),  # Zone 9 (Atlantic): deep ocean dark
]

func _get_zone_index(x: float) -> int:
	var zone_boundaries: Array[float] = [270.0, 570.0, 960.0, 1380.0, 1860.0, 2530.0, 3170.0, 3810.0, 4480.0]
	for i in range(zone_boundaries.size()):
		if x < zone_boundaries[i]:
			return i
	return 9

func _build_terrain_zones() -> void:
	# Zone tinting via small patches buried well below terrain surface
	# to avoid peeking above slopes into the sky
	var zone_centers: Array[float] = [135.0, 400.0, 755.0, 1140.0, 1615.0, 2200.0, 2830.0, 3445.0, 4115.0, 4950.0]
	var zone_radii: Array[float] = [180.0, 200.0, 220.0, 250.0, 280.0, 300.0, 280.0, 300.0, 320.0, 400.0]

	for zi in range(SWAMP_COUNT):
		var center_x: float = zone_centers[zi]
		var radius: float = zone_radii[zi]
		var col: Color = ZONE_TINT_COLORS[zi]
		# Scatter small tinted patches well below terrain surface
		for _j in range(25):
			var px: float = center_x + randf_range(-radius, radius)
			px = clampf(px, 0.0, terrain_points[terrain_points.size() - 1].x)
			var py: float = _get_terrain_y_at(px)
			if py < 0:
				continue
			var dist_frac: float = absf(px - center_x) / radius
			var alpha: float = col.a * (1.0 - dist_frac * dist_frac)
			if alpha < 0.02:
				continue
			var patch := ColorRect.new()
			var pw: float = randf_range(12, 30)
			var ph: float = randf_range(8, 20)
			# Push patches well below surface so they never peek above on slopes
			patch.position = Vector2(px - pw * 0.5, py + randf_range(10, 25))
			patch.size = Vector2(pw, ph)
			patch.color = Color(col.r, col.g, col.b, alpha)
			patch.z_index = 0
			add_child(patch)

	# Ridge crack details between pools
	_build_ridge_details()
	# Basin slope erosion marks
	_build_slope_erosion()
	# Phase 1A: Basin striation layers, roots, pebbles
	_build_basin_striation()

func _build_ridge_details() -> void:
	# Ridges are between pools: exit_top of pool N through entry_top of pool N+1
	for pool_i in range(SWAMP_COUNT - 1):
		var ridge_start: int = SWAMP_RANGES[pool_i][1]  # exit_top of pool N
		var ridge_end: int = SWAMP_RANGES[pool_i + 1][0]  # entry_top of pool N+1
		if ridge_start >= terrain_points.size() or ridge_end >= terrain_points.size():
			continue
		var ridge_left: Vector2 = terrain_points[ridge_start]
		var ridge_right: Vector2 = terrain_points[ridge_end]
		var ridge_mid_x: float = (ridge_left.x + ridge_right.x) * 0.5
		var ridge_w: float = ridge_right.x - ridge_left.x

		# 3-5 short cracks on the ridge
		for _j in range(randi_range(3, 5)):
			var crack := Line2D.new()
			crack.width = 1.0
			crack.default_color = Color(0.58, 0.50, 0.38, randf_range(0.2, 0.4))
			crack.z_index = 1
			var cx: float = randf_range(ridge_left.x + 4, ridge_right.x - 4)
			var cy: float = _get_terrain_y_at(cx)
			if cy < 0:
				continue
			cy += randf_range(1, 4)
			crack.add_point(Vector2(cx, cy))
			crack.add_point(Vector2(cx + randf_range(-6, 6), cy + randf_range(3, 8)))
			add_child(crack)

		# 1-2 dry patches on the ridge
		for _j in range(randi_range(1, 2)):
			var dry := ColorRect.new()
			var dx: float = randf_range(ridge_left.x + 2, ridge_right.x - 8)
			var dy: float = _get_terrain_y_at(dx)
			if dy < 0:
				continue
			dry.position = Vector2(dx, dy + randf_range(1, 3))
			dry.size = Vector2(randf_range(6, 14), randf_range(3, 5))
			dry.color = Color(0.58, 0.48, 0.32, randf_range(0.15, 0.25))
			dry.z_index = 1
			add_child(dry)

func _build_slope_erosion() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry_top: Vector2 = geo["entry_top"]
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var exit_top: Vector2 = geo["exit_top"]

		# Entry slope erosion grooves
		for _j in range(randi_range(2, 3)):
			var erosion := Line2D.new()
			erosion.width = 1.0
			erosion.default_color = Color(0.30, 0.20, 0.10, randf_range(0.2, 0.35))
			erosion.z_index = 1
			var offset: float = randf_range(3, 8)
			var t1: float = randf_range(0.1, 0.3)
			var t2: float = randf_range(0.7, 0.9)
			erosion.add_point(Vector2(
				lerpf(entry_top.x, basin_left.x, t1),
				lerpf(entry_top.y, basin_left.y, t1) + offset
			))
			erosion.add_point(Vector2(
				lerpf(entry_top.x, basin_left.x, t2),
				lerpf(entry_top.y, basin_left.y, t2) + offset
			))
			add_child(erosion)

		# Exit slope erosion grooves
		for _j in range(randi_range(2, 3)):
			var erosion := Line2D.new()
			erosion.width = 1.0
			erosion.default_color = Color(0.30, 0.20, 0.10, randf_range(0.2, 0.35))
			erosion.z_index = 1
			var offset: float = randf_range(3, 8)
			var t1: float = randf_range(0.1, 0.3)
			var t2: float = randf_range(0.7, 0.9)
			erosion.add_point(Vector2(
				lerpf(basin_right.x, exit_top.x, t1),
				lerpf(basin_right.y, exit_top.y, t1) + offset
			))
			erosion.add_point(Vector2(
				lerpf(basin_right.x, exit_top.x, t2),
				lerpf(basin_right.y, exit_top.y, t2) + offset
			))
			add_child(erosion)

func _get_basin_bottom_y(geo: Dictionary) -> float:
	var max_y: float = geo["basin_left"].y
	for pt in geo["all_points"]:
		if pt.y > max_y:
			max_y = pt.y
	return max_y

func _build_basin_striation() -> void:
	# Phase 1A: Geological striation layers in pool basins
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var left_x: float = geo["basin_left"].x
		var right_x: float = geo["basin_right"].x
		var bottom_y: float = _get_basin_bottom_y(geo)
		var entry_y: float = geo["entry_top"].y
		var depth: float = bottom_y - entry_y
		if depth < 10:
			continue
		# 3-5 thin striation bands at different depths
		var band_count: int = randi_range(3, 5)
		for b in range(band_count):
			var t: float = float(b + 1) / float(band_count + 1)
			var band_y: float = entry_y + depth * t
			var band := Line2D.new()
			band.width = randf_range(0.5, 1.5)
			band.default_color = Color(
				GROUND_COLOR.r + randf_range(-0.06, 0.06),
				GROUND_COLOR.g + randf_range(-0.05, 0.05),
				GROUND_COLOR.b + randf_range(-0.04, 0.04),
				randf_range(0.25, 0.45)
			)
			band.z_index = 0
			# Horizontal band across basin
			var bx: float = left_x + 4
			while bx < right_x - 4:
				band.add_point(Vector2(bx, band_y + randf_range(-1.5, 1.5)))
				bx += randf_range(6, 14)
			add_child(band)
		# Root tendrils on slopes near water
		for side in range(2):
			var slope_x: float = left_x if side == 0 else right_x
			var slope_dir: float = 1.0 if side == 0 else -1.0
			for r in range(randi_range(1, 3)):
				var root_y: float = entry_y + randf_range(3, depth * 0.6)
				var root := Line2D.new()
				root.width = 1.0
				root.default_color = Color(0.25, 0.15, 0.08, randf_range(0.3, 0.5))
				root.z_index = 1
				var rx: float = slope_x
				var ry: float = root_y
				root.add_point(Vector2(rx, ry))
				for seg in range(randi_range(2, 4)):
					rx += slope_dir * randf_range(2, 6)
					ry += randf_range(-2, 3)
					root.add_point(Vector2(rx, ry))
				add_child(root)
	# Pebble scatter on ridges
	for i in range(terrain_points.size() - 1):
		var p1: Vector2 = terrain_points[i]
		var p2: Vector2 = terrain_points[i + 1]
		var slope: float = absf(p2.y - p1.y) / maxf(absf(p2.x - p1.x), 1.0)
		if slope < 0.15:  # Flat enough for pebbles
			for _p in range(randi_range(0, 2)):
				var px: float = randf_range(p1.x, p2.x)
				var py: float = _get_terrain_y_at(px) - randf_range(0, 1)
				var peb := ColorRect.new()
				peb.size = Vector2(randf_range(1, 2), 1)
				peb.color = Color(
					randf_range(0.35, 0.55),
					randf_range(0.28, 0.42),
					randf_range(0.18, 0.30),
					randf_range(0.4, 0.7)
				)
				peb.position = Vector2(px, py)
				peb.z_index = 1
				add_child(peb)

func _build_vegetation() -> void:
	# Cattails near water edges
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry_top: Vector2 = geo["entry_top"]
		var exit_top: Vector2 = geo["exit_top"]

		# Place cattails near entry slope
		for j in range(randi_range(2, 4)):
			var cx: float = entry_top.x + randf_range(-10, 16)
			var cy: float = _get_terrain_y_at(cx) + randf_range(0, 3)
			_place_cattail(Vector2(cx, cy))

		# Place cattails near exit slope
		for j in range(randi_range(1, 3)):
			var cx: float = exit_top.x + randf_range(-16, 10)
			var cy: float = _get_terrain_y_at(cx) + randf_range(0, 3)
			_place_cattail(Vector2(cx, cy))

	# Grass tufts on ridges (skip basin floors)
	for i in range(terrain_points.size()):
		# Skip points inside pool basins
		var is_basin: bool = false
		for s in range(SWAMP_COUNT):
			if i > SWAMP_RANGES[s][0] and i < SWAMP_RANGES[s][1]:
				is_basin = true
				break
		if is_basin:
			continue
		var pt: Vector2 = terrain_points[i]
		# Only on relatively flat areas (ridges, shores)
		if i > 0 and i < terrain_points.size() - 1:
			var dy: float = absf(terrain_points[i + 1].y - pt.y) / absf(terrain_points[i + 1].x - pt.x + 0.01)
			if dy < 0.3:  # Mostly flat
				# 3-5x density; cluster noise inside _place_grass_tuft carves bare gaps
				for j in range(randi_range(8, 14)):
					var gx: float = pt.x + randf_range(-18, 18)
					_place_grass_tuft(Vector2(gx, _get_terrain_y_at(gx)))

	# Flowers scattered on shore and ridges
	var flower_colors: Array[Color] = [
		Color(0.9, 0.3, 0.3), Color(0.9, 0.85, 0.2),
		Color(0.8, 0.4, 0.7), Color(0.95, 0.95, 0.9)
	]
	for i in range(30):
		var fx: float = randf_range(10, terrain_points[terrain_points.size() - 1].x - 20)
		var fy: float = _get_terrain_y_at(fx)
		if fy > 0:
			var stem_h: float = randf_range(4, 7)
			var stem := ColorRect.new()
			stem.position = Vector2(fx + 1.0, fy - stem_h)
			stem.size = Vector2(2, stem_h)
			stem.color = Color(0.2, 0.4, 0.15)
			stem.z_index = 1
			add_child(stem)

			var flower := ColorRect.new()
			flower.position = Vector2(fx, fy - stem_h - 3)
			flower.size = Vector2(4, 4)
			flower.color = flower_colors[randi() % flower_colors.size()]
			flower.z_index = 1
			add_child(flower)

func _place_cattail(pos: Vector2) -> void:
	var cattail := Node2D.new()
	cattail.position = pos  # Pivot at base on ground
	cattail.z_index = 3
	add_child(cattail)

	var stem_h: float = randf_range(18, 30)
	var stem_offset_x: float = randf_range(-2, 2)

	# Stem as a tapered swaying polygon (slim).
	_make_blade(cattail, Vector2.ZERO, stem_h, 2.6, stem_offset_x,
		Color(0.20, 0.36, 0.14), Color(0.36, 0.52, 0.22), _sway_mat_frond, 3)

	# Cattail head (brown) as a small swaying quad anchored near the tip so it
	# drifts with the stem. UV.y small (near tip) = max sway.
	var head := Polygon2D.new()
	var hx: float = stem_offset_x
	var hy: float = -stem_h - 2.0
	head.polygon = PackedVector2Array([
		Vector2(hx - 2, hy + 8), Vector2(hx + 2, hy + 8),
		Vector2(hx + 2, hy), Vector2(hx - 2, hy),
	])
	head.uv = PackedVector2Array([
		Vector2(0, 0.18), Vector2(1, 0.18), Vector2(1, 0.0), Vector2(0, 0.0),
	])
	var head_dark := Color(0.36, 0.22, 0.10)
	var head_light := Color(0.52, 0.36, 0.18)
	head.vertex_colors = PackedColorArray([head_dark, head_dark, head_light, head_light])
	head.material = _sway_mat_frond
	head.z_index = 3
	cattail.add_child(head)

	# Two leaves arcing out, as swaying fronds.
	_make_blade(cattail, Vector2.ZERO, stem_h * 0.7, 2.4, randf_range(8, 13),
		Color(0.18, 0.34, 0.12), Color(0.30, 0.50, 0.18), _sway_mat_frond, 3)
	_make_blade(cattail, Vector2.ZERO, stem_h * 0.6, 2.0, randf_range(-12, -7),
		Color(0.16, 0.30, 0.10), Color(0.26, 0.46, 0.16), _sway_mat_frond, 3)

	cattails.append(cattail)

# Build one tapered, swaying Polygon2D blade/frond rooted at `base` (local-anchored
# at the node origin). Wide base -> pointed tip; UV.y = 1 at base, 0 at tip so the
# shared sway shader pivots correctly. Vertex colors: dark base -> light tip.
func _make_blade(parent: Node2D, base_local: Vector2, height: float, width: float,
		lean: float, dark: Color, light: Color, mat: ShaderMaterial, zi: int) -> void:
	var blade := Polygon2D.new()
	var hw: float = width * 0.5
	var tip := Vector2(base_local.x + lean, base_local.y - height)
	var mid := Vector2(base_local.x + lean * 0.4, base_local.y - height * 0.5)
	# base-left, base-right, mid-right, tip, mid-left
	blade.polygon = PackedVector2Array([
		Vector2(base_local.x - hw, base_local.y),
		Vector2(base_local.x + hw, base_local.y),
		Vector2(mid.x + hw * 0.5, mid.y),
		tip,
		Vector2(mid.x - hw * 0.5, mid.y),
	])
	# UV.y: 1 at base rows, ~0.5 mid, 0 at tip
	blade.uv = PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		Vector2(1.0, 0.5), Vector2(0.5, 0.0), Vector2(0.0, 0.5),
	])
	blade.vertex_colors = PackedColorArray([dark, dark, dark.lerp(light, 0.5), light, dark.lerp(light, 0.5)])
	blade.material = mat
	blade.z_index = zi
	parent.add_child(blade)

func _place_grass_tuft(pos: Vector2) -> void:
	# Cluster gating: skip in "bare" gaps so grass forms dense patches.
	if _cluster_noise(pos.x) < 0.32:
		return
	# Color zone: darker near water, lighter on dry ridges
	var near_water: float = 0.0
	for si in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(si)
		var pool_cx: float = (geo["entry_top"].x + geo["exit_top"].x) * 0.5
		var dist: float = absf(pos.x - pool_cx)
		var pool_w: float = (geo["exit_top"].x - geo["entry_top"].x) * 0.6
		if dist < pool_w:
			near_water = maxf(near_water, 1.0 - dist / pool_w)
	# Depth band: back row darker/cooler/smaller, front brighter/warmer/larger.
	var is_front: bool = randf() < 0.5
	var depth_scale: float = 1.0 if is_front else 0.78
	var zi: int = 2 if is_front else 1
	var tuft := Node2D.new()
	tuft.position = pos
	tuft.z_index = zi
	add_child(tuft)
	grass_tufts.append(tuft)
	var per_scale: float = randf_range(0.7, 1.4) * depth_scale
	var n_blades: int = randi_range(3, 5)
	for k in range(n_blades):
		# Green stops + occasional dead yellow-green / brown blade.
		var dark: Color
		var light: Color
		var roll: float = randf()
		if roll < 0.12:  # dead/dry blade
			dark = Color(0.32, 0.30, 0.10)
			light = Color(0.55, 0.50, 0.22)
		elif roll < 0.5:  # rich green
			dark = Color(0.10, 0.30, 0.07)
			light = Color(0.32, 0.58, 0.18)
		else:  # zone-tinted green
			dark = Color(0.14, 0.34, 0.08).lerp(Color(0.10, 0.26, 0.06), near_water)
			light = GRASS_LIGHT_COLOR
		if not is_front:  # cool + darken back row for atmospheric depth
			dark = dark.darkened(0.22)
			light = light.lerp(Color(0.18, 0.34, 0.30), 0.30).darkened(0.10)
		var bh: float = randf_range(7, 14) * per_scale
		var bw: float = randf_range(1.8, 3.0) * per_scale
		var lean: float = randf_range(-5, 5) + (3.0 * (float(k) / float(n_blades) - 0.5) * 2.0)
		_make_blade(tuft, Vector2(randf_range(-3, 3), 0), bh, bw, lean, dark, light, _sway_mat_grass, zi)

# --- Stars ---
func _build_stars() -> void:
	for i in range(35):
		var star := ColorRect.new()
		var sz: float = randf_range(1, 3)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(-100, terrain_points[terrain_points.size() - 1].x + 100), randf_range(-80, 100))
		# Warm-to-cool whites
		var warmth: float = randf()
		star.color = Color(1.0, lerp(0.9, 1.0, warmth), lerp(0.75, 1.0, warmth), 0.0)
		star.z_index = -11
		add_child(star)
		stars.append(star)

# --- Fireflies ---
func _build_fireflies() -> void:
	for i in range(20):
		var fly := ColorRect.new()
		fly.size = Vector2(2, 2)
		fly.color = Color(0.8, 1.0, 0.3, 0.0)
		fly.z_index = 6
		var base_x: float = randf_range(50, terrain_points[terrain_points.size() - 1].x - 30)
		var terrain_at_ff: float = _get_terrain_y_at(base_x)
		var base_y: float = terrain_at_ff - randf_range(10, 45)
		fly.position = Vector2(base_x, base_y)
		add_child(fly)
		# Additive glow pool under each firefly
		var glow := ColorRect.new()
		glow.size = Vector2(8, 6)
		glow.position = Vector2(-3, -2)
		glow.color = _emit(Color(0.9, 1.0, 0.4, 0.0), 2.5)
		glow.z_index = 5
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = glow_mat
		fly.add_child(glow)
		fireflies.append({
			"node": fly,
			"glow": glow,
			"base_x": base_x,
			"base_y": base_y,
			"phase_x": randf() * TAU,
			"phase_y": randf() * TAU,
			"speed_x": randf_range(0.3, 0.8),
			"speed_y": randf_range(0.4, 0.9),
			"amp_x": randf_range(15, 40),
			"amp_y": randf_range(10, 25),
			"glow_phase": randf() * TAU,
		})

# --- Tree Trunks ---
func _build_tree_trunks() -> void:
	for i in range(50):
		var trunk := Line2D.new()
		var tx: float = randf_range(-80, terrain_points[terrain_points.size() - 1].x + 100)
		var tw: float = randf_range(2, 4)
		trunk.width = tw
		trunk.default_color = Color(0.15, 0.1, 0.05, randf_range(0.3, 0.6))
		var top_y: float = randf_range(100, 130)
		trunk.add_point(Vector2(tx, top_y))
		trunk.add_point(Vector2(tx + randf_range(-1, 1), 160))
		trunk.z_index = -5
		treeline_layer.add_child(trunk)

# --- Lily Pads ---
func _build_lily_pads() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var basin_w: float = basin_right.x - basin_left.x
		var count: int = clampi(int(basin_w / 30.0), 1, 6)
		for j in range(count):
			var pad_group := Node2D.new()
			pad_group.z_index = 3
			add_child(pad_group)
			var pad_x: float = basin_left.x + randf_range(10, basin_w - 10)
			var pad_w: float = randf_range(6, 10)
			# Dark green pad
			var pad := ColorRect.new()
			pad.size = Vector2(pad_w, pad_w * 0.5)
			pad.position = Vector2(-pad_w * 0.5, -pad_w * 0.25)
			pad.color = Color(0.12, 0.35, 0.1, 0.85)
			pad_group.add_child(pad)
			# Highlight
			var hl := ColorRect.new()
			hl.size = Vector2(pad_w * 0.4, 1)
			hl.position = Vector2(-pad_w * 0.2, -pad_w * 0.15)
			hl.color = Color(0.25, 0.5, 0.2, 0.5)
			pad_group.add_child(hl)
			# Optional flower
			if randf() < 0.3:
				var flower := ColorRect.new()
				flower.size = Vector2(3, 3)
				flower.position = Vector2(-1.5, -pad_w * 0.35)
				flower.color = Color(0.9, 0.5, 0.6, 0.9)
				pad_group.add_child(flower)
			lily_pads.append({
				"node": pad_group,
				"swamp": i,
				"x": pad_x,
				"phase": randf() * TAU,
			})

# --- Water Depth Gradients ---
func _build_depth_gradients() -> void:
	for i in range(SWAMP_COUNT):
		var dp := Polygon2D.new()
		dp.color = SWAMP_DEPTH_COLORS[i]
		dp.z_index = 1
		add_child(dp)
		depth_polygons.append(dp)
		_update_depth_gradient(i)

func _update_depth_gradient(swamp_index: int) -> void:
	var fill: float = GameManager.get_swamp_fill_fraction(swamp_index)
	if fill <= 0.001:
		depth_polygons[swamp_index].polygon = PackedVector2Array()
		return
	var deepest_y: float = _get_pool_deepest_y(swamp_index)
	var overflow_y: float = _get_pool_overflow_y(swamp_index)
	var water_y: float = deepest_y - fill * (deepest_y - overflow_y)
	# Depth zone covers bottom 60% of water
	var depth_y: float = lerpf(water_y, deepest_y, 0.4)
	var left_x: float = _find_water_left_x(swamp_index, depth_y)
	var right_x: float = _find_water_right_x(swamp_index, depth_y)
	# Trace terrain contour below depth_y
	var pts := PackedVector2Array()
	pts.append(Vector2(left_x, depth_y))
	var r: Array = SWAMP_RANGES[swamp_index]
	for i in range(r[0], r[1] + 1):
		var pt: Vector2 = terrain_points[i]
		if pt.y >= depth_y and pt.x >= left_x and pt.x <= right_x:
			pts.append(pt)
	pts.append(Vector2(right_x, depth_y))
	depth_polygons[swamp_index].polygon = pts

# --- Water Shimmer Lines ---
func _build_shimmer_lines() -> void:
	for i in range(SWAMP_COUNT):
		var sl := Line2D.new()
		sl.width = 1.5
		sl.default_color = Color(0.35, 0.55, 0.4, 0.2)
		sl.z_index = 3
		add_child(sl)
		shimmer_lines.append(sl)

func _update_shimmer_line(swamp_index: int, left_x: float, right_x: float, water_y: float) -> void:
	var line: Line2D = shimmer_lines[swamp_index]
	line.clear_points()
	var segments: int = maxi(int((right_x - left_x) / 8.0), 3)
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var px: float = lerpf(left_x, right_x, t)
		var wave_offset: float = sin(wave_time * 1.5 + px * 0.2) * 1.2
		line.add_point(Vector2(px, water_y + 3.0 + wave_offset))
	# Pulsing alpha
	var alpha: float = lerpf(0.15, 0.3, (sin(wave_time * 0.8) + 1.0) * 0.5)
	line.default_color = Color(0.35, 0.55, 0.4, alpha)

# --- Mud Patches ---
func _build_mud_patches() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var basin_w: float = basin_right.x - basin_left.x
		var count: int = clampi(int(basin_w / 20.0), 2, 8)
		for j in range(count):
			var mud := ColorRect.new()
			var mw: float = randf_range(6, 14)
			var mh: float = randf_range(2, 4)
			mud.size = Vector2(mw, mh)
			var mx: float = basin_left.x + randf_range(4, basin_w - 4)
			mud.position = Vector2(mx, basin_left.y - mh)
			mud.color = Color(0.25, 0.18, 0.08, 0.7)
			mud.z_index = 0
			mud.visible = false
			add_child(mud)
			# Wet sheen highlight
			var sheen := ColorRect.new()
			sheen.size = Vector2(mw - 2, 1)
			sheen.position = Vector2(mx + 1, basin_left.y - mh + 1)
			sheen.color = Color(0.4, 0.35, 0.25, 0.4)
			sheen.z_index = 0
			sheen.visible = false
			add_child(sheen)
			mud_patches.append({
				"mud": mud,
				"sheen": sheen,
				"swamp": i,
			})

func _update_mud_visibility() -> void:
	for mp in mud_patches:
		var fill: float = GameManager.get_swamp_fill_fraction(mp["swamp"])
		var visible: bool = fill < 0.15
		mp["mud"].visible = visible
		mp["sheen"].visible = visible

# --- Mushrooms ---
func _build_mushrooms() -> void:
	var cap_colors: Array[Color] = [
		Color(0.75, 0.2, 0.15),  # Red
		Color(0.55, 0.35, 0.15), # Brown
		Color(0.8, 0.65, 0.2),   # Gold
	]
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry_top: Vector2 = geo["entry_top"]
		var exit_top: Vector2 = geo["exit_top"]
		# Place near entry
		if randf() < 0.7:
			_place_mushroom(Vector2(entry_top.x + randf_range(-12, 4), entry_top.y), cap_colors)
		# Place near exit
		if randf() < 0.7:
			_place_mushroom(Vector2(exit_top.x + randf_range(-4, 12), exit_top.y), cap_colors)
	# A few extra scattered ones
	for i in range(8):
		var mx: float = randf_range(20, terrain_points[terrain_points.size() - 1].x - 20)
		var my: float = _get_terrain_y_at(mx)
		if my > 0:
			_place_mushroom(Vector2(mx, my), cap_colors)

func _place_mushroom(pos: Vector2, cap_colors: Array[Color]) -> void:
	var mushroom := Node2D.new()
	mushroom.z_index = 1
	add_child(mushroom)
	# Stem
	var stem := ColorRect.new()
	stem.size = Vector2(2, 5)
	stem.position = Vector2(pos.x - 1, pos.y - 5)
	stem.color = Color(0.9, 0.88, 0.8)
	mushroom.add_child(stem)
	# Cap
	var cap_w: float = randf_range(5, 8)
	var cap := ColorRect.new()
	cap.size = Vector2(cap_w, 3)
	cap.position = Vector2(pos.x - cap_w * 0.5, pos.y - 8)
	var cap_color: Color = cap_colors[randi() % cap_colors.size()]
	cap.color = cap_color
	mushroom.add_child(cap)
	# Highlight
	var cap_hl := ColorRect.new()
	cap_hl.size = Vector2(cap_w - 2, 1)
	cap_hl.position = Vector2(pos.x - cap_w * 0.5 + 1, pos.y - 8)
	cap_hl.color = cap_color.lightened(0.3)
	cap_hl.color.a = 0.6
	mushroom.add_child(cap_hl)
	# Red mushrooms get white spots
	if cap_color.r > 0.6 and cap_color.g < 0.3:
		var spot := ColorRect.new()
		spot.size = Vector2(1, 1)
		spot.position = Vector2(pos.x - 1, pos.y - 7)
		spot.color = Color(0.95, 0.95, 0.9, 0.8)
		mushroom.add_child(spot)
		if cap_w > 6:
			var spot2 := ColorRect.new()
			spot2.size = Vector2(1, 1)
			spot2.position = Vector2(pos.x + 1, pos.y - 7)
			spot2.color = Color(0.95, 0.95, 0.9, 0.8)
			mushroom.add_child(spot2)

# --- Ferns ---
func _build_ferns() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry_top: Vector2 = geo["entry_top"]
		var exit_top: Vector2 = geo["exit_top"]
		# Near entry
		for j in range(randi_range(1, 2)):
			var fx: float = entry_top.x + randf_range(-16, 8)
			_place_fern(Vector2(fx, _get_terrain_y_at(fx)))
		# Near exit
		for j in range(randi_range(1, 2)):
			var fx: float = exit_top.x + randf_range(-8, 16)
			_place_fern(Vector2(fx, _get_terrain_y_at(fx)))

func _place_fern(pos: Vector2) -> void:
	var fern := Node2D.new()
	fern.position = pos
	var is_front: bool = randf() < 0.5
	fern.z_index = 2 if is_front else 1
	add_child(fern)
	ferns_list.append(fern)
	var per_scale: float = randf_range(0.8, 1.4) * (1.0 if is_front else 0.8)
	fern.rotation = deg_to_rad(randf_range(-12, 12))
	var frond_count: int = randi_range(5, 8)
	for i in range(frond_count):
		# Fan the fronds out from the base; tapered swaying polygons.
		var spread: float = (float(i) / float(frond_count - 1) - 0.5) * 2.0  # -1..1
		var lean: float = spread * randf_range(8, 14)
		var length: float = randf_range(8, 16) * per_scale * (1.0 - absf(spread) * 0.25)
		var width: float = randf_range(2.0, 3.2) * per_scale
		var dark := Color(0.08, 0.26, 0.06)
		var light := Color(0.22, 0.50, 0.14)
		if not is_front:
			dark = dark.darkened(0.20)
			light = light.lerp(Color(0.16, 0.32, 0.28), 0.30).darkened(0.10)
		_make_blade(fern, Vector2.ZERO, length, width, lean, dark, light, _sway_mat_frond, fern.z_index)

# --- Leaf Particles ---
func _spawn_leaf() -> void:
	if leaves.size() >= 8:
		return
	var leaf := ColorRect.new()
	leaf.size = Vector2(3, 2)
	var is_brown: bool = randf() < 0.4
	if is_brown:
		leaf.color = Color(0.5, 0.35, 0.15, 0.7)
	else:
		leaf.color = Color(0.25, 0.45, 0.15, 0.7)
	var start_y: float = randf_range(40, 110)
	leaf.position = Vector2(-10, start_y)
	leaf.z_index = 5
	add_child(leaf)
	leaves.append({
		"node": leaf,
		"speed": randf_range(15, 35),
		"wobble_phase": randf() * TAU,
		"wobble_amp": randf_range(6, 14),
		"lifetime": 0.0,
		"max_life": randf_range(12, 25),
		"base_y": start_y,
	})

# --- Moon ---
func _build_moon() -> void:
	moon = Node2D.new()
	moon.z_index = -11
	add_child(moon)
	# Soft outer halo (additive, overbright) → the HDR bloom.
	moon_glow = _make_glow_orb(42.0, _emit(Color(0.72, 0.8, 0.96, 0.42), 1.75))
	moon.add_child(moon_glow)
	# PointLight2D for moonlight
	var moon_light := PointLight2D.new()
	moon_light.color = Color(0.7, 0.75, 0.95)
	moon_light.energy = 0.2
	moon_light.texture = _make_light_texture()
	moon_light.texture_scale = 2.5
	moon_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	moon.add_child(moon_light)
	# Lunar surface disc: a smooth circle, gently overbright so it blooms at the rim
	# (the halo hides the hard edge) — gives a real moon to hang craters on.
	moon_body = Polygon2D.new()
	moon_body.polygon = _make_disc(14.0)
	moon_body.color = _emit(Color(0.9, 0.93, 1.0), 1.25)
	moon.add_child(moon_body)
	# Craters / maria for lunar detail (soft darker bluish spots on the disc).
	var craters: Array = [
		{"pos": Vector2(4.5, -2.0), "r": 3.2},
		{"pos": Vector2(-3.5, 3.0), "r": 2.2},
		{"pos": Vector2(1.0, 4.5), "r": 2.6},
		{"pos": Vector2(-4.0, -3.5), "r": 1.6},
	]
	for cr in craters:
		var crater := Polygon2D.new()
		crater.polygon = _make_disc(cr["r"], 16)
		crater.position = cr["pos"]
		crater.color = Color(0.6, 0.64, 0.78, 0.5)
		moon.add_child(crater)
	moon.position = Vector2(1500, 30)

# --- Foam Lines (Shore Froth) ---
func _build_foam_lines() -> void:
	for i in range(SWAMP_COUNT):
		var fl := Line2D.new()
		fl.width = 1.5
		fl.default_color = Color(0.8, 0.9, 0.85, 0.3)
		fl.z_index = 4
		add_child(fl)
		foam_lines.append(fl)

func _update_foam_line(swamp_index: int, left_x: float, right_x: float, water_y: float) -> void:
	var line: Line2D = foam_lines[swamp_index]
	line.clear_points()
	var segments: int = maxi(int((right_x - left_x) / 6.0), 3)
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var px: float = lerpf(left_x, right_x, t)
		# Foam only near edges (first/last 20% of width)
		var edge_frac: float = 1.0 - absf(t - 0.5) * 2.0
		var foam_strength: float = 0.0
		if t < 0.2:
			foam_strength = 1.0 - t / 0.2
		elif t > 0.8:
			foam_strength = (t - 0.8) / 0.2
		var wave_offset: float = sin(wave_time * 3.0 + px * 0.3) * 0.8 * foam_strength
		line.add_point(Vector2(px, water_y - 0.5 + wave_offset))
	var base_foam: Color = POOL_FOAM_COLORS[swamp_index]
	var alpha: float = lerpf(base_foam.a * 0.5, base_foam.a, (sin(wave_time * 1.2) + 1.0) * 0.5)
	line.default_color = Color(base_foam.r, base_foam.g, base_foam.b, alpha)

# --- Fog Patches Near Swamps ---
func _build_fog_patches() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var entry_top: Vector2 = geo["entry_top"]
		var basin_w: float = basin_right.x - basin_left.x
		var count: int = clampi(int(basin_w / 40.0), 1, 4)
		for j in range(count):
			var fog := ColorRect.new()
			var fw: float = randf_range(20, 50)
			var fh: float = randf_range(6, 14)
			fog.size = Vector2(fw, fh)
			var fx: float = basin_left.x + randf_range(0, basin_w - fw)
			var fy: float = entry_top.y - randf_range(8, 24)
			fog.position = Vector2(fx, fy)
			fog.color = Color(0.8, 0.85, 0.9, 0.0)
			fog.z_index = 5
			add_child(fog)
			fog_patches.append({
				"node": fog,
				"base_x": fx,
				"phase": randf() * TAU,
			})

# --- Dragonflies (Daytime) ---
func _build_dragonflies() -> void:
	var df_colors: Array[Color] = [
		Color(0.2, 0.5, 0.9),   # Blue
		Color(0.3, 0.8, 0.4),   # Green
		Color(0.7, 0.3, 0.6),   # Purple
		Color(0.9, 0.4, 0.2),   # Orange
	]
	for i in range(8):
		var df := Node2D.new()
		df.z_index = 6
		add_child(df)
		# Body
		var body := ColorRect.new()
		body.size = Vector2(4, 1)
		body.position = Vector2(-2, 0)
		body.color = df_colors[i % df_colors.size()]
		df.add_child(body)
		# Wings
		var wing_l := ColorRect.new()
		wing_l.size = Vector2(3, 2)
		wing_l.position = Vector2(-3, -2)
		wing_l.color = Color(0.8, 0.9, 1.0, 0.4)
		df.add_child(wing_l)
		var wing_r := ColorRect.new()
		wing_r.size = Vector2(3, 2)
		wing_r.position = Vector2(0, -2)
		wing_r.color = Color(0.8, 0.9, 1.0, 0.4)
		df.add_child(wing_r)
		var base_x: float = randf_range(80, terrain_points[terrain_points.size() - 1].x - 60)
		var terrain_at_df: float = _get_terrain_y_at(base_x)
		var base_y: float = terrain_at_df - randf_range(15, 50)
		df.position = Vector2(base_x, base_y)
		dragonflies.append({
			"node": df,
			"base_x": base_x,
			"base_y": base_y,
			"phase_x": randf() * TAU,
			"phase_y": randf() * TAU,
			"speed": randf_range(0.8, 1.5),
			"amp_x": randf_range(30, 60),
			"amp_y": randf_range(15, 30),
			"wing_l": wing_l,
			"wing_r": wing_r,
		})

# --- Water Reflection Highlights ---
func _build_water_highlights() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var basin_w: float = basin_right.x - basin_left.x
		var count: int = clampi(int(basin_w / 30.0), 1, 4)
		for j in range(count):
			var hl := ColorRect.new()
			hl.size = Vector2(randf_range(4, 10), 1)
			hl.color = Color(1.0, 1.0, 0.9, 0.0)
			hl.z_index = 4
			add_child(hl)
			water_highlights.append({
				"node": hl,
				"swamp": i,
				"offset_x": randf_range(0.1, 0.9),
				"phase": randf() * TAU,
			})

# --- Pool Glow Lights (Phase 4A) ---
func _build_pool_glow_lights() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var bl: Vector2 = geo["basin_left"]
		var br: Vector2 = geo["basin_right"]
		var center_x: float = (bl.x + br.x) * 0.5
		var center_y: float = maxf(bl.y, br.y) - 4.0
		var light := PointLight2D.new()
		light.position = Vector2(center_x, center_y)
		light.color = SWAMP_WATER_COLORS[i]
		light.energy = 0.0
		light.texture = _make_light_texture()
		light.texture_scale = 1.5 + float(i) * 0.3
		light.blend_mode = PointLight2D.BLEND_MODE_ADD
		light.z_index = 2
		add_child(light)
		pool_glow_lights.append(light)

func _update_pool_glow_lights() -> void:
	for i in range(pool_glow_lights.size()):
		var fill: float = GameManager.get_swamp_fill_fraction(i)
		var base_energy: float = fill * 0.3
		var pulse: float = sin(wave_time * 0.8 + float(i) * 1.5) * 0.05
		pool_glow_lights[i].energy = maxf(base_energy + pulse, 0.0)

# --- Bubble Spawner ---
func _spawn_bubble(swamp_index: int) -> void:
	if bubbles.size() >= 12:
		return
	var geo: Dictionary = _get_swamp_geometry(swamp_index)
	var basin_left: Vector2 = geo["basin_left"]
	var basin_right: Vector2 = geo["basin_right"]
	var fill: float = GameManager.get_swamp_fill_fraction(swamp_index)
	if fill < 0.05:
		return
	var basin_y: float = _get_pool_deepest_y(swamp_index)
	var water_y: float = _get_pool_water_y(swamp_index)
	var bx: float = randf_range(basin_left.x + 5, basin_right.x - 5)
	var bubble := ColorRect.new()
	var bsize: float = randf_range(2, 4)
	bubble.size = Vector2(bsize, bsize)
	bubble.position = Vector2(bx, basin_y - 2)
	bubble.color = Color(0.6, 0.8, 0.7, 0.5)
	bubble.z_index = 4
	add_child(bubble)
	bubbles.append({
		"node": bubble,
		"target_y": water_y - 2,
		"speed": randf_range(12, 25),
		"wobble_phase": randf() * TAU,
	})

# --- Bird Spawner ---
func _spawn_bird() -> void:
	if birds.size() >= 8:
		return
	# 40% chance to spawn a flock of 3-5, otherwise single bird
	var flock_count: int = 1
	if randf() < 0.4:
		flock_count = randi_range(3, 5)
	var cam_bird: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
	var cam_cy: float = cam_bird.get_screen_center_position().y if cam_bird else 90.0
	var cam_cx: float = cam_bird.get_screen_center_position().x if cam_bird else 320.0
	var base_x: float = cam_cx - 350
	var terrain_at_spawn: float = _get_terrain_y_at(base_x)
	var base_y: float = terrain_at_spawn - randf_range(30, 80)
	var base_speed: float = randf_range(30, 55)
	var base_flap: float = randf_range(4.0, 7.0)
	for fi in range(flock_count):
		if birds.size() >= 8:
			break
		var bird := Node2D.new()
		bird.z_index = -7
		add_child(bird)
		var wing_l := Line2D.new()
		wing_l.width = 1.5
		wing_l.default_color = Color(0.1, 0.1, 0.15, 0.6)
		wing_l.add_point(Vector2(-4, 2))
		wing_l.add_point(Vector2(0, 0))
		bird.add_child(wing_l)
		var wing_r := Line2D.new()
		wing_r.width = 1.5
		wing_r.default_color = Color(0.1, 0.1, 0.15, 0.6)
		wing_r.add_point(Vector2(0, 0))
		wing_r.add_point(Vector2(4, 2))
		bird.add_child(wing_r)
		# V-formation offset: leader at front, followers behind and to sides
		var offset_x: float = -float(fi) * randf_range(8, 14)
		var offset_y: float = float(fi) * (4.0 if fi % 2 == 0 else -4.0) * randf_range(0.5, 1.0)
		bird.position = Vector2(base_x + offset_x, base_y + offset_y)
		birds.append({
			"node": bird,
			"wing_l": wing_l,
			"wing_r": wing_r,
			"speed": base_speed + randf_range(-3, 3),
			"flap_speed": base_flap + randf_range(-0.5, 0.5),
			"y_drift": randf_range(-0.3, 0.3),
		})

# --- Pollen Spawner ---
func _spawn_pollen() -> void:
	if pollen.size() >= 15:
		return
	var mote := ColorRect.new()
	mote.size = Vector2(1, 1)
	mote.color = Color(1.0, 0.95, 0.7, 0.0)
	mote.z_index = 5
	var px: float = randf_range(-50, terrain_points[terrain_points.size() - 1].x + 50)
	var py: float = randf_range(60, 240)
	mote.position = Vector2(px, py)
	add_child(mote)
	pollen.append({
		"node": mote,
		"phase": randf() * TAU,
		"speed_x": randf_range(2, 8),
		"amp_y": randf_range(5, 15),
		"lifetime": 0.0,
		"max_life": randf_range(8, 18),
		"base_y": py,
	})

func _spawn_ripple(rx: float, ry: float) -> void:
	var rp_line := Line2D.new()
	rp_line.width = 1.5
	rp_line.default_color = Color(0.6, 0.8, 0.7, 0.4)
	rp_line.z_index = 4
	add_child(rp_line)
	ripples.append({
		"node": rp_line,
		"x": rx,
		"y": ry,
		"max_radius": randf_range(6, 14),
		"lifetime": 0.0,
		"max_life": randf_range(1.5, 3.0),
	})

func _spawn_butterfly() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
	var cam_x: float = cam.get_screen_center_position().x if cam else 320.0
	var bf_node := Node2D.new()
	bf_node.z_index = 6
	add_child(bf_node)
	# Body
	var bf_body := ColorRect.new()
	bf_body.size = Vector2(2, 4)
	bf_body.position = Vector2(-1, -2)
	bf_body.color = Color(0.15, 0.12, 0.08)
	bf_node.add_child(bf_body)
	# Wings - pick a random color scheme
	var wing_colors: Array[Color] = [
		Color(0.95, 0.6, 0.15, 0.9),   # Orange monarch
		Color(0.3, 0.5, 0.95, 0.9),    # Blue morpho
		Color(0.95, 0.95, 0.4, 0.9),   # Yellow swallowtail
		Color(0.9, 0.3, 0.5, 0.9),     # Pink
		Color(0.95, 0.4, 0.2, 0.9),    # Red admiral
	]
	var wing_color: Color = wing_colors[randi() % wing_colors.size()]
	# Left wing
	var wing_l := ColorRect.new()
	wing_l.size = Vector2(5, 4)
	wing_l.position = Vector2(-6, -3)
	wing_l.color = wing_color
	wing_l.pivot_offset = Vector2(5, 2)
	bf_node.add_child(wing_l)
	# Right wing
	var wing_r := ColorRect.new()
	wing_r.size = Vector2(5, 4)
	wing_r.position = Vector2(1, -3)
	wing_r.color = wing_color
	wing_r.pivot_offset = Vector2(0, 2)
	bf_node.add_child(wing_r)
	# Wing spots
	var spot_l := ColorRect.new()
	spot_l.size = Vector2(2, 2)
	spot_l.position = Vector2(-4, -2)
	spot_l.color = wing_color.darkened(0.3)
	bf_node.add_child(spot_l)
	var spot_r := ColorRect.new()
	spot_r.size = Vector2(2, 2)
	spot_r.position = Vector2(2, -2)
	spot_r.color = wing_color.darkened(0.3)
	bf_node.add_child(spot_r)
	# Antennae
	var ant_l := ColorRect.new()
	ant_l.size = Vector2(1, 3)
	ant_l.position = Vector2(-2, -5)
	ant_l.color = Color(0.2, 0.15, 0.1, 0.7)
	bf_node.add_child(ant_l)
	var ant_r := ColorRect.new()
	ant_r.size = Vector2(1, 3)
	ant_r.position = Vector2(1, -5)
	ant_r.color = Color(0.2, 0.15, 0.1, 0.7)
	bf_node.add_child(ant_r)

	var bx: float = cam_x + randf_range(-350, 350)
	var terrain_at_bf: float = _get_terrain_y_at(bx)
	var by: float = terrain_at_bf - randf_range(10, 40)
	bf_node.position = Vector2(bx, by)
	butterflies.append({
		"node": bf_node,
		"wing_l": wing_l,
		"wing_r": wing_r,
		"phase": randf() * TAU,
		"flutter_speed": randf_range(6.0, 10.0),
		"drift_x": randf_range(-15, 15),
		"bob_amp": randf_range(5, 12),
		"base_y": by,
		"lifetime": 0.0,
		"max_life": randf_range(8, 18),
	})

# --- Crickets (nighttime ambient) ---
func _build_crickets() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry: Vector2 = geo["entry_top"]
		var exit_pt: Vector2 = geo["exit_top"]
		# Place 1-2 crickets on ridges near each pool
		for k in range(randi_range(1, 2)):
			var side: bool = k == 0
			var cx: float = entry.x - randf_range(5, 25) if side else exit_pt.x + randf_range(5, 25)
			var cy: float = _get_terrain_y_at(cx) - 1.0
			var cricket_node := Node2D.new()
			cricket_node.z_index = 3
			cricket_node.visible = false
			add_child(cricket_node)
			var body := ColorRect.new()
			body.size = Vector2(3, 2)
			body.position = Vector2(-1.5, -2)
			body.color = Color(0.12, 0.10, 0.06, 0.85)
			cricket_node.add_child(body)
			var leg_l := ColorRect.new()
			leg_l.size = Vector2(2, 1)
			leg_l.position = Vector2(-3, -1)
			leg_l.color = Color(0.15, 0.12, 0.07, 0.7)
			cricket_node.add_child(leg_l)
			var leg_r := ColorRect.new()
			leg_r.size = Vector2(2, 1)
			leg_r.position = Vector2(1.5, -1)
			leg_r.color = Color(0.15, 0.12, 0.07, 0.7)
			cricket_node.add_child(leg_r)
			# Chirp flash pixel
			var chirp := ColorRect.new()
			chirp.size = Vector2(2, 2)
			chirp.position = Vector2(-1, -4)
			chirp.color = Color(1.0, 0.95, 0.4, 0.0)
			cricket_node.add_child(chirp)
			cricket_node.position = Vector2(cx, cy)
			crickets.append({
				"node": cricket_node,
				"chirp_ref": chirp,
				"chirp_timer": randf_range(2.0, 8.0),
				"chirping": false,
				"chirp_flash": 0.0,
			})

func _spawn_shooting_star() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
	var cam_x: float = cam.get_screen_center_position().x if cam else 320.0
	var ss_node := Node2D.new()
	ss_node.z_index = -9
	add_child(ss_node)
	# Bright head
	var ss_head := ColorRect.new()
	ss_head.size = Vector2(3, 3)
	ss_head.color = Color(1.0, 1.0, 0.9, 0.9)
	ss_node.add_child(ss_head)
	# Trail line
	var ss_line := Line2D.new()
	ss_line.width = 2.0
	ss_line.default_color = Color(0.8, 0.85, 1.0, 0.6)
	ss_node.add_child(ss_line)

	var start_x: float = cam_x + randf_range(-300, 100)
	var start_y: float = randf_range(-40, 30)
	shooting_stars.append({
		"node": ss_node,
		"head": ss_head,
		"line": ss_line,
		"start_x": start_x,
		"start_y": start_y,
		"speed_x": randf_range(200, 400),
		"speed_y": randf_range(30, 80),
		"lifetime": 0.0,
		"max_life": randf_range(0.6, 1.2),
	})

# --- Fish ---
func _build_fish() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var basin_w: float = basin_right.x - basin_left.x
		var count: int = clampi(int(basin_w / 40.0), 1, 5)
		for j in range(count):
			var fish_node := Node2D.new()
			fish_node.z_index = 4
			add_child(fish_node)
			# Fish body
			var body := ColorRect.new()
			body.size = Vector2(6, 3)
			body.position = Vector2(-3, -1.5)
			var fish_hue: float = randf_range(0.05, 0.15)
			body.color = Color.from_hsv(fish_hue, 0.6, 0.7, 0.9)
			fish_node.add_child(body)
			# Tail
			var tail := ColorRect.new()
			tail.size = Vector2(3, 4)
			tail.position = Vector2(-6, -2)
			tail.color = Color.from_hsv(fish_hue, 0.5, 0.6, 0.85)
			fish_node.add_child(tail)
			# Eye
			var eye := ColorRect.new()
			eye.size = Vector2(1, 1)
			eye.position = Vector2(1, -1)
			eye.color = Color(0.1, 0.1, 0.1)
			fish_node.add_child(eye)
			# Belly highlight
			var belly := ColorRect.new()
			belly.size = Vector2(4, 1)
			belly.position = Vector2(-2, 0.5)
			belly.color = Color(0.9, 0.85, 0.7, 0.5)
			fish_node.add_child(belly)
			# Dorsal fin (Line2D triangle)
			var fin := Line2D.new()
			fin.width = 1.0
			fin.default_color = Color.from_hsv(fish_hue, 0.55, 0.55, 0.8)
			fin.add_point(Vector2(-1, -1.5))
			fin.add_point(Vector2(0, -4))
			fin.add_point(Vector2(2, -1.5))
			fish_node.add_child(fin)

			var fx: float = basin_left.x + randf_range(12, basin_w - 12)
			fish.append({
				"node": fish_node,
				"swamp": i,
				"x": fx,
				"swim_phase": randf() * TAU,
				"swim_speed": randf_range(0.6, 1.4),
				"swim_range": randf_range(15, 35),
				"depth_offset": randf_range(0.3, 0.7),
				"direction": 1.0 if randf() > 0.5 else -1.0,
				"alive": true,
				"death_timer": 0.0,
				"jump_timer": randf_range(12.0, 35.0),
				"jumping": false,
				"jump_time": 0.0,
			})

# --- Frogs ---
func _build_frogs() -> void:
	var placed: int = 0
	for lp in lily_pads:
		if placed >= 8:
			break
		if randf() < 0.4:
			continue
		var pad_node: Node2D = lp["node"]
		var frog_node := Node2D.new()
		frog_node.z_index = 5
		pad_node.add_child(frog_node)
		# Body
		var body := ColorRect.new()
		body.size = Vector2(5, 4)
		body.position = Vector2(-2.5, -6)
		body.color = Color(0.2, 0.5, 0.15, 0.95)
		frog_node.add_child(body)
		# Head
		var head := ColorRect.new()
		head.size = Vector2(4, 3)
		head.position = Vector2(-2, -9)
		head.color = Color(0.25, 0.55, 0.18, 0.95)
		frog_node.add_child(head)
		# Left eye
		var eye_l := ColorRect.new()
		eye_l.size = Vector2(2, 2)
		eye_l.position = Vector2(-2, -11)
		eye_l.color = Color(0.8, 0.75, 0.1)
		frog_node.add_child(eye_l)
		# Right eye
		var eye_r := ColorRect.new()
		eye_r.size = Vector2(2, 2)
		eye_r.position = Vector2(1, -11)
		eye_r.color = Color(0.8, 0.75, 0.1)
		frog_node.add_child(eye_r)
		# Eye pupils
		var pupil_l := ColorRect.new()
		pupil_l.size = Vector2(1, 1)
		pupil_l.position = Vector2(-1, -10)
		pupil_l.color = Color(0.05, 0.05, 0.05)
		frog_node.add_child(pupil_l)
		var pupil_r := ColorRect.new()
		pupil_r.size = Vector2(1, 1)
		pupil_r.position = Vector2(2, -10)
		pupil_r.color = Color(0.05, 0.05, 0.05)
		frog_node.add_child(pupil_r)
		# Belly
		var belly := ColorRect.new()
		belly.size = Vector2(3, 2)
		belly.position = Vector2(-1.5, -4)
		belly.color = Color(0.55, 0.7, 0.35, 0.7)
		frog_node.add_child(belly)
		# Rear legs (angled behind body)
		var leg_l := ColorRect.new()
		leg_l.size = Vector2(3, 2)
		leg_l.position = Vector2(-4, -3)
		leg_l.color = Color(0.18, 0.45, 0.12, 0.9)
		frog_node.add_child(leg_l)
		var leg_r := ColorRect.new()
		leg_r.size = Vector2(3, 2)
		leg_r.position = Vector2(2, -3)
		leg_r.color = Color(0.18, 0.45, 0.12, 0.9)
		frog_node.add_child(leg_r)

		frogs.append({
			"node": frog_node,
			"swamp": lp["swamp"],
			"hop_timer": randf_range(3.0, 10.0),
			"hopping": false,
			"hop_progress": 0.0,
			"base_y": 0.0,
			"eye_l": eye_l,
			"eye_r": eye_r,
			"blink_timer": randf_range(2.0, 6.0),
		})
		placed += 1

# --- Bioluminescent Plants ---
func _build_glow_plants() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry_top: Vector2 = geo["entry_top"]
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var exit_top: Vector2 = geo["exit_top"]
		# Place 2-3 glow plants per swamp near water edges
		var positions: Array[Vector2] = [
			Vector2(entry_top.x + randf_range(2, 12), entry_top.y),
			Vector2(exit_top.x + randf_range(-12, -2), exit_top.y),
		]
		if randf() < 0.6:
			var mid_x: float = lerpf(basin_left.x, basin_right.x, randf_range(0.2, 0.8))
			positions.append(Vector2(mid_x - 8, _get_terrain_y_at(mid_x - 8)))
		for pos in positions:
			if pos.y <= 0:
				continue
			var plant := Node2D.new()
			plant.z_index = 4
			add_child(plant)
			# Stem
			var stem_h: float = randf_range(8, 16)
			var stem := ColorRect.new()
			stem.size = Vector2(2, stem_h)
			stem.position = Vector2(pos.x - 1, pos.y - stem_h)
			stem.color = Color(0.1, 0.3, 0.15, 0.8)
			plant.add_child(stem)
			# Glowing bulb
			var bulb := ColorRect.new()
			var bulb_size: float = randf_range(4, 7)
			bulb.size = Vector2(bulb_size, bulb_size)
			bulb.position = Vector2(pos.x - bulb_size * 0.5, pos.y - stem_h - bulb_size * 0.5)
			var glow_color: Color
			var color_roll: float = randf()
			if color_roll < 0.4:
				glow_color = Color(0.2, 0.9, 0.4, 0.0)  # Green
			elif color_roll < 0.7:
				glow_color = Color(0.3, 0.6, 1.0, 0.0)   # Blue
			else:
				glow_color = Color(0.8, 0.4, 0.9, 0.0)    # Purple
			glow_color = _emit(glow_color, 2.0)
			bulb.color = glow_color
			plant.add_child(bulb)
			# Outer glow aura
			var aura := ColorRect.new()
			var aura_size: float = bulb_size + 6
			aura.size = Vector2(aura_size, aura_size)
			aura.position = Vector2(pos.x - aura_size * 0.5, pos.y - stem_h - aura_size * 0.5)
			aura.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.0)
			plant.add_child(aura)
			# Small leaves on stem
			var leaf := ColorRect.new()
			leaf.size = Vector2(4, 2)
			leaf.position = Vector2(pos.x, pos.y - stem_h * 0.5)
			leaf.color = Color(0.12, 0.35, 0.12, 0.7)
			plant.add_child(leaf)

			glow_plants.append({
				"node": plant,
				"bulb": bulb,
				"aura": aura,
				"glow_color": glow_color,
				"phase": randf() * TAU,
				"pulse_speed": randf_range(1.2, 2.5),
			})

# --- Underwater Seaweed ---
func _build_seaweed() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var basin_w: float = basin_right.x - basin_left.x
		var count: int = clampi(int(basin_w / 20.0), 2, 8)
		for j in range(count):
			var sw_x: float = basin_left.x + randf_range(8, basin_w - 8)
			var sw_height: float = randf_range(10, 28)
			var segments: int = randi_range(3, 5)
			var green_hue: float = randf_range(0.25, 0.38)
			# Anchor node at basin floor so rotation pivots from base
			var sw_node := Node2D.new()
			sw_node.z_index = 2
			sw_node.position = Vector2(sw_x, basin_left.y)
			add_child(sw_node)
			for s in range(segments):
				var strand := ColorRect.new()
				strand.size = Vector2(2, sw_height / segments + randf_range(-2, 2))
				strand.position = Vector2(s * 2 - segments, -sw_height + s * (sw_height / segments))
				strand.color = Color.from_hsv(green_hue, randf_range(0.5, 0.8), randf_range(0.3, 0.5), 0.7)
				sw_node.add_child(strand)
			# Tip accent
			var tip := ColorRect.new()
			tip.size = Vector2(3, 2)
			tip.position = Vector2(-1, -sw_height - 1)
			tip.color = Color.from_hsv(green_hue, 0.6, 0.55, 0.8)
			sw_node.add_child(tip)
			seaweed.append({
				"node": sw_node,
				"swamp": i,
				"x": sw_x,
				"height": sw_height,
				"phase": randf() * TAU,
				"sway_speed": randf_range(1.0, 2.0),
			})

# --- Turtles ---
func _build_turtles() -> void:
	for i in range(SWAMP_COUNT):
		if randf() > 0.6:
			continue
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry_top: Vector2 = geo["entry_top"]
		var exit_top: Vector2 = geo["exit_top"]
		# Place turtle near a pool edge
		var side: bool = randf() > 0.5
		var tx: float
		var ty: float
		if side:
			tx = entry_top.x + randf_range(2, 10)
			ty = entry_top.y + randf_range(-2, 4)
		else:
			tx = exit_top.x + randf_range(-10, -2)
			ty = exit_top.y + randf_range(-2, 4)
		var turtle_node := Node2D.new()
		turtle_node.z_index = 3
		add_child(turtle_node)
		# Shell
		var shell := ColorRect.new()
		shell.size = Vector2(8, 6)
		shell.position = Vector2(tx - 4, ty - 6)
		shell.color = Color(0.3, 0.4, 0.2, 0.95)
		turtle_node.add_child(shell)
		# Shell pattern
		var pattern := ColorRect.new()
		pattern.size = Vector2(6, 4)
		pattern.position = Vector2(tx - 3, ty - 5)
		pattern.color = Color(0.35, 0.48, 0.25, 0.7)
		turtle_node.add_child(pattern)
		# Shell highlight
		var shell_hl := ColorRect.new()
		shell_hl.size = Vector2(4, 1)
		shell_hl.position = Vector2(tx - 2, ty - 6)
		shell_hl.color = Color(0.45, 0.55, 0.3, 0.5)
		turtle_node.add_child(shell_hl)
		# Head
		var head := ColorRect.new()
		head.size = Vector2(3, 3)
		head.position = Vector2(tx + 4, ty - 5)
		head.color = Color(0.35, 0.45, 0.2, 0.95)
		turtle_node.add_child(head)
		# Eye
		var eye := ColorRect.new()
		eye.size = Vector2(1, 1)
		eye.position = Vector2(tx + 6, ty - 5)
		eye.color = Color(0.1, 0.1, 0.1)
		turtle_node.add_child(eye)
		# Legs
		for lx in [-3, 3]:
			var leg := ColorRect.new()
			leg.size = Vector2(2, 2)
			leg.position = Vector2(tx + lx - 1, ty - 1)
			leg.color = Color(0.3, 0.42, 0.18, 0.9)
			turtle_node.add_child(leg)
		# Tail (small Line2D)
		var tail := Line2D.new()
		tail.width = 1.0
		tail.default_color = Color(0.32, 0.42, 0.18, 0.8)
		tail.add_point(Vector2(tx - 4, ty - 3))
		tail.add_point(Vector2(tx - 7, ty - 2))
		turtle_node.add_child(tail)
		turtles.append({
			"node": turtle_node,
			"swamp": i,
			"head_ref": head,
			"phase": randf() * TAU,
		})

# --- Tadpoles ---
func _build_tadpoles() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_left: Vector2 = geo["basin_left"]
		var basin_right: Vector2 = geo["basin_right"]
		var basin_w: float = basin_right.x - basin_left.x
		var count: int = clampi(int(basin_w / 50.0), 1, 4)
		for j in range(count):
			var tp_node := Node2D.new()
			tp_node.z_index = 3
			add_child(tp_node)
			# Tiny body
			var body := ColorRect.new()
			body.size = Vector2(3, 2)
			body.position = Vector2(-1.5, -1)
			body.color = Color(0.15, 0.15, 0.12, 0.85)
			tp_node.add_child(body)
			# Tail
			var tail := ColorRect.new()
			tail.size = Vector2(4, 1)
			tail.position = Vector2(-5.5, -0.5)
			tail.color = Color(0.2, 0.2, 0.15, 0.7)
			tp_node.add_child(tail)

			var tpx: float = basin_left.x + randf_range(8, basin_w - 8)
			tadpoles.append({
				"node": tp_node,
				"swamp": i,
				"x": tpx,
				"swim_phase": randf() * TAU,
				"swim_speed": randf_range(1.5, 3.0),
				"swim_range": randf_range(10, 25),
				"depth_offset": randf_range(0.5, 0.9),
			})

func _get_terrain_y_at(x: float) -> float:
	for i in range(terrain_points.size() - 1):
		if x >= terrain_points[i].x and x <= terrain_points[i + 1].x:
			var t: float = (x - terrain_points[i].x) / (terrain_points[i + 1].x - terrain_points[i].x + 0.001)
			return lerpf(terrain_points[i].y, terrain_points[i + 1].y, t)
	if x < terrain_points[0].x:
		return terrain_points[0].y
	return terrain_points[terrain_points.size() - 1].y

# --- Unique Pool Features ---
func _build_pool_features() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var bl: Vector2 = geo["basin_left"]
		var br: Vector2 = geo["basin_right"]
		var et: Vector2 = geo["entry_top"]
		var xt: Vector2 = geo["exit_top"]
		var bw: float = br.x - bl.x
		var basin_y: float = maxf(bl.y, br.y)
		match i:
			0: _build_puddle_features(bl, br, et, xt, bw, basin_y)
			1: _build_pond_features(bl, br, et, xt, bw, basin_y)
			2: _build_marsh_features(bl, br, et, xt, bw, basin_y)
			3: _build_bog_features(bl, br, et, xt, bw, basin_y)
			4: _build_swamp_features(bl, br, et, xt, bw, basin_y)
			5: _build_lake_features(bl, br, et, xt, bw, basin_y)
			6: _build_reservoir_features(bl, br, et, xt, bw, basin_y)
			7: _build_lagoon_features(bl, br, et, xt, bw, basin_y)
			8: _build_bayou_features(bl, br, et, xt, bw, basin_y)
			9: _build_atlantic_features(bl, br, et, xt, bw, basin_y)

# Puddle: pebbles and sandy patch
func _build_puddle_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Sandy patch on bottom
	var sand := ColorRect.new()
	sand.size = Vector2(bw * 0.6, 4)
	sand.position = Vector2(bl.x + bw * 0.2, basin_y - 3)
	sand.color = Color(0.62, 0.55, 0.38, 0.35)
	sand.z_index = 1
	add_child(sand)
	# Small pebbles
	for j in range(randi_range(5, 8)):
		var peb := ColorRect.new()
		var sz: float = randf_range(2, 5)
		peb.size = Vector2(sz, sz * randf_range(0.5, 0.8))
		peb.position = Vector2(bl.x + randf_range(4, bw - 4), basin_y - randf_range(1, 4))
		var gray: float = randf_range(0.35, 0.55)
		peb.color = Color(gray, gray * randf_range(0.9, 1.1), gray * randf_range(0.85, 1.0), 0.7)
		peb.z_index = 1
		add_child(peb)

# Pond: submerged log with branch and weeds
func _build_pond_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Submerged log
	var log_line := Line2D.new()
	log_line.width = 4.0
	log_line.default_color = Color(0.28, 0.18, 0.10, 0.8)
	log_line.z_index = 1
	var log_x1: float = bl.x + bw * 0.15
	var log_x2: float = bl.x + bw * 0.75
	log_line.add_point(Vector2(log_x1, basin_y - 2))
	log_line.add_point(Vector2(log_x2, basin_y - 5))
	add_child(log_line)
	# Broken branch sticking up
	var branch := Line2D.new()
	branch.width = 2.0
	branch.default_color = Color(0.32, 0.22, 0.12, 0.75)
	branch.z_index = 2
	var branch_x: float = lerpf(log_x1, log_x2, 0.6)
	var branch_base_y: float = lerpf(basin_y - 2, basin_y - 5, 0.6)
	branch.add_point(Vector2(branch_x, branch_base_y))
	branch.add_point(Vector2(branch_x + 4, branch_base_y - 16))
	branch.add_point(Vector2(branch_x + 8, branch_base_y - 22))
	add_child(branch)
	# Water weeds growing off log
	for j in range(3):
		var weed := ColorRect.new()
		weed.size = Vector2(2, randf_range(6, 12))
		var wx: float = lerpf(log_x1, log_x2, randf_range(0.2, 0.8))
		var wy: float = lerpf(basin_y - 2, basin_y - 5, (wx - log_x1) / (log_x2 - log_x1))
		weed.position = Vector2(wx, wy - weed.size.y)
		weed.color = Color(0.2, 0.45, 0.18, 0.65)
		weed.z_index = 2
		add_child(weed)

# Marsh: root network, reed clusters, silt overlay
func _build_marsh_features(bl: Vector2, br: Vector2, et: Vector2, xt: Vector2, bw: float, basin_y: float) -> void:
	# Exposed roots from slopes into water
	for j in range(randi_range(3, 4)):
		var root := Line2D.new()
		root.width = randf_range(2.0, 3.0)
		root.default_color = Color(0.35, 0.22, 0.12, 0.7)
		root.z_index = 1
		var from_left: bool = j < 2
		var start_x: float
		var start_y: float
		if from_left:
			start_x = et.x + randf_range(2, 12)
			start_y = et.y + randf_range(-2, 4)
		else:
			start_x = xt.x - randf_range(2, 12)
			start_y = xt.y + randf_range(-2, 4)
		var end_x: float = bl.x + randf_range(bw * 0.2, bw * 0.8)
		var end_y: float = basin_y - randf_range(0, 4)
		root.add_point(Vector2(start_x, start_y))
		root.add_point(Vector2(lerpf(start_x, end_x, 0.5), lerpf(start_y, end_y, 0.5) + randf_range(-3, 3)))
		root.add_point(Vector2(end_x, end_y))
		add_child(root)
	# Thick reed clusters at edges
	for j in range(4):
		var rx: float
		if j < 2:
			rx = et.x + randf_range(-4, 8)
		else:
			rx = xt.x + randf_range(-8, 4)
		var ry: float = et.y if j < 2 else xt.y
		for k in range(randi_range(2, 4)):
			var reed := Line2D.new()
			reed.width = 1.5
			reed.default_color = Color(0.3, 0.42, 0.18, 0.8)
			reed.z_index = 4
			var reed_h: float = randf_range(14, 24)
			reed.add_point(Vector2(rx + k * 2, ry))
			reed.add_point(Vector2(rx + k * 2 + randf_range(-2, 2), ry - reed_h))
			add_child(reed)
			# Bulrush top
			var bulrush := ColorRect.new()
			bulrush.size = Vector2(3, 5)
			bulrush.position = Vector2(rx + k * 2 - 1, ry - reed_h - 5)
			bulrush.color = Color(0.35, 0.25, 0.12, 0.85)
			bulrush.z_index = 4
			add_child(bulrush)
	# Murky silt overlay on bottom third
	var silt := Polygon2D.new()
	silt.color = Color(0.3, 0.22, 0.12, 0.15)
	silt.z_index = 2
	var silt_y: float = lerpf(et.y, basin_y, 0.65)
	silt.polygon = PackedVector2Array([
		Vector2(bl.x + 4, silt_y),
		Vector2(bl.x, bl.y),
		Vector2(br.x, br.y),
		Vector2(br.x - 4, silt_y),
	])
	add_child(silt)

# Bog: peat mounds, submerged stumps, moss
func _build_bog_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Submerged tree stumps
	for j in range(2):
		var stump := Polygon2D.new()
		stump.color = Color(0.25, 0.16, 0.08, 0.8)
		stump.z_index = 1
		var sx: float = bl.x + bw * (0.25 + j * 0.45) + randf_range(-8, 8)
		var sw: float = randf_range(8, 14)
		var sh: float = randf_range(10, 18)
		var stump_base_y: float = _get_terrain_y_at(sx)
		if stump_base_y < 0 or stump_base_y < basin_y:
			stump_base_y = basin_y
		stump.polygon = PackedVector2Array([
			Vector2(sx - sw * 0.5, stump_base_y),
			Vector2(sx - sw * 0.35, stump_base_y - sh),
			Vector2(sx + sw * 0.35, stump_base_y - sh),
			Vector2(sx + sw * 0.5, stump_base_y),
		])
		add_child(stump)
		# Moss patch on stump top
		var moss := ColorRect.new()
		moss.size = Vector2(sw * 0.5, 3)
		moss.position = Vector2(sx - sw * 0.25, stump_base_y - sh - 1)
		moss.color = Color(0.22, 0.45, 0.15, 0.6)
		moss.z_index = 2
		add_child(moss)
	# Peat mounds on basin floor
	for j in range(randi_range(3, 4)):
		var peat := Polygon2D.new()
		peat.color = Color(0.15, 0.12, 0.06, 0.65)
		peat.z_index = 1
		var px: float = bl.x + randf_range(10, bw - 10)
		var pw: float = randf_range(8, 16)
		var ph: float = randf_range(3, 6)
		peat.polygon = PackedVector2Array([
			Vector2(px - pw * 0.5, basin_y),
			Vector2(px - pw * 0.3, basin_y - ph),
			Vector2(px + pw * 0.3, basin_y - ph),
			Vector2(px + pw * 0.5, basin_y),
		])
		add_child(peat)

# Swamp: tangled vines, hanging moss, glowing fungi
func _build_swamp_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Dead trees on terrain edges near pool
	for j in range(3):
		var tx: float = bl.x + bw * (0.1 + j * 0.35) + randf_range(-15, 15)
		var base_y: float = _get_terrain_y_at(tx)
		if base_y < 0:
			base_y = basin_y
		var tree_h: float = randf_range(25, 45)
		var trunk := Line2D.new()
		trunk.width = 4.0
		trunk.default_color = Color(0.22, 0.15, 0.08, 0.85)
		trunk.z_index = 4
		trunk.add_point(Vector2(tx, base_y))
		trunk.add_point(Vector2(tx + randf_range(-3, 3), base_y - tree_h))
		add_child(trunk)
		for k in range(randi_range(3, 5)):
			var br_line := Line2D.new()
			br_line.width = 2.0
			br_line.default_color = Color(0.25, 0.18, 0.10, 0.75)
			br_line.z_index = 4
			var branch_y: float = base_y - tree_h + randf_range(5, tree_h * 0.4)
			var branch_dir: float = 1.0 if randf() > 0.5 else -1.0
			var branch_len: float = randf_range(12, 28)
			br_line.add_point(Vector2(tx, branch_y))
			br_line.add_point(Vector2(tx + branch_dir * branch_len, branch_y - randf_range(4, 12)))
			add_child(br_line)
			if randf() > 0.4:
				var moss_line := Line2D.new()
				moss_line.width = 1.0
				moss_line.default_color = Color(0.28, 0.42, 0.22, 0.5)
				moss_line.z_index = 4
				var moss_x: float = tx + branch_dir * branch_len * randf_range(0.3, 0.8)
				moss_line.add_point(Vector2(moss_x, branch_y - randf_range(2, 8)))
				moss_line.add_point(Vector2(moss_x + randf_range(-2, 2), branch_y + randf_range(8, 18)))
				add_child(moss_line)
	# Glowing fungi on basin walls
	for j in range(randi_range(4, 6)):
		var glow_node := Node2D.new()
		glow_node.z_index = 2
		glow_node.position = Vector2(bl.x + randf_range(10, bw - 10), basin_y - randf_range(4, 20))
		add_child(glow_node)
		var glow_color := Color(0.3, 0.6, 0.2)
		var bulb := ColorRect.new()
		bulb.size = Vector2(3, 3)
		bulb.position = Vector2(-1.5, -1.5)
		bulb.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.6)
		glow_node.add_child(bulb)
		var aura := ColorRect.new()
		aura.size = Vector2(7, 7)
		aura.position = Vector2(-3.5, -3.5)
		aura.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.15)
		glow_node.add_child(aura)
		glow_plants.append({"node": glow_node, "bulb": bulb, "aura": aura, "glow_color": glow_color, "phase": randf() * TAU, "pulse_speed": randf_range(1.2, 2.5)})

# Lake: rocky outcrops, deep water plants
func _build_lake_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Rocky outcrops along edges
	for j in range(randi_range(4, 6)):
		var rx: float = bl.x + randf_range(10, bw - 10)
		var ry: float = basin_y - randf_range(2, 8)
		var rock := Polygon2D.new()
		rock.color = Color(0.38, 0.36, 0.34, 0.75)
		rock.z_index = 1
		var rw: float = randf_range(8, 16)
		var rh: float = randf_range(6, 12)
		rock.polygon = PackedVector2Array([
			Vector2(rx - rw * 0.5, ry),
			Vector2(rx - rw * 0.3, ry - rh),
			Vector2(rx + rw * 0.2, ry - rh * 0.8),
			Vector2(rx + rw * 0.5, ry),
		])
		add_child(rock)
	# Tall water plants
	for j in range(randi_range(5, 8)):
		var wx: float = bl.x + randf_range(15, bw - 15)
		var weed := Line2D.new()
		weed.width = 1.5
		weed.default_color = Color(0.15, 0.35, 0.20, 0.6)
		weed.z_index = 2
		var wh: float = randf_range(10, 22)
		weed.add_point(Vector2(wx, basin_y - 2))
		weed.add_point(Vector2(wx + randf_range(-4, 4), basin_y - wh))
		add_child(weed)

# Reservoir: concrete walls, old pipes
func _build_reservoir_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Concrete wall segments
	for j in range(randi_range(3, 5)):
		var wx: float = bl.x + randf_range(8, bw - 8)
		var wall := ColorRect.new()
		wall.size = Vector2(randf_range(4, 8), randf_range(12, 22))
		wall.position = Vector2(wx, basin_y - wall.size.y)
		wall.color = Color(0.45, 0.44, 0.42, 0.7)
		wall.z_index = 1
		add_child(wall)
	# Rusty pipes
	for j in range(randi_range(2, 3)):
		var pipe := Line2D.new()
		pipe.width = 3.0
		pipe.default_color = Color(0.50, 0.32, 0.18, 0.7)
		pipe.z_index = 2
		var px: float = bl.x + randf_range(20, bw - 20)
		pipe.add_point(Vector2(px, basin_y - randf_range(4, 10)))
		pipe.add_point(Vector2(px + randf_range(15, 35), basin_y - randf_range(8, 18)))
		add_child(pipe)
	# Drain grates
	for j in range(2):
		var gx: float = bl.x + bw * (0.3 + j * 0.4)
		var grate := ColorRect.new()
		grate.size = Vector2(10, 6)
		grate.position = Vector2(gx - 5, basin_y - 5)
		grate.color = Color(0.30, 0.28, 0.26, 0.8)
		grate.z_index = 1
		add_child(grate)

# Lagoon: coral formations, bioluminescent specks
func _build_lagoon_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Coral formations
	for j in range(randi_range(5, 8)):
		var cx: float = bl.x + randf_range(15, bw - 15)
		var coral := Polygon2D.new()
		var ch: float = randf_range(8, 18)
		var cw: float = randf_range(6, 14)
		coral.polygon = PackedVector2Array([
			Vector2(cx - cw * 0.5, basin_y),
			Vector2(cx - cw * 0.3, basin_y - ch * 0.7),
			Vector2(cx, basin_y - ch),
			Vector2(cx + cw * 0.3, basin_y - ch * 0.6),
			Vector2(cx + cw * 0.5, basin_y),
		])
		var hue: float = randf_range(0.0, 0.12)  # coral orange-pink range
		coral.color = Color.from_hsv(hue, 0.5, 0.7, 0.6)
		coral.z_index = 1
		add_child(coral)
	# Bioluminescent specks
	for j in range(randi_range(6, 10)):
		var glow_node := Node2D.new()
		glow_node.z_index = 2
		glow_node.position = Vector2(bl.x + randf_range(10, bw - 10), basin_y - randf_range(4, 20))
		add_child(glow_node)
		var glow_color := Color(0.2, 0.8, 0.7)
		var bulb := ColorRect.new()
		bulb.size = Vector2(2, 2)
		bulb.position = Vector2(-1, -1)
		bulb.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.5)
		glow_node.add_child(bulb)
		var aura := ColorRect.new()
		aura.size = Vector2(5, 5)
		aura.position = Vector2(-2.5, -2.5)
		aura.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.12)
		glow_node.add_child(aura)
		glow_plants.append({"node": glow_node, "bulb": bulb, "aura": aura, "glow_color": glow_color, "phase": randf() * TAU, "pulse_speed": randf_range(1.5, 3.0)})

# Bayou: cypress roots, spanish moss, ancient stone
func _build_bayou_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Massive cypress roots
	for j in range(randi_range(4, 6)):
		var root := Line2D.new()
		root.width = randf_range(3, 5)
		root.default_color = Color(0.28, 0.18, 0.10, 0.8)
		root.z_index = 1
		var rx: float = bl.x + randf_range(10, bw - 10)
		var ry: float = basin_y
		root.add_point(Vector2(rx, ry))
		root.add_point(Vector2(rx + randf_range(-15, 15), ry - randf_range(8, 20)))
		root.add_point(Vector2(rx + randf_range(-25, 25), ry - randf_range(15, 30)))
		add_child(root)
	# Spanish moss draping
	for j in range(randi_range(6, 10)):
		var moss := Line2D.new()
		moss.width = 1.0
		moss.default_color = Color(0.35, 0.42, 0.30, 0.45)
		moss.z_index = 4
		var mx: float = bl.x + randf_range(0, bw)
		var terrain_y: float = _get_terrain_y_at(mx)
		if terrain_y < 0:
			terrain_y = basin_y - 30
		moss.add_point(Vector2(mx, terrain_y - randf_range(10, 25)))
		moss.add_point(Vector2(mx + randf_range(-3, 3), terrain_y - randf_range(0, 8)))
		add_child(moss)
	# Ancient crumbled stone blocks
	for j in range(randi_range(2, 4)):
		var stone := ColorRect.new()
		var sw: float = randf_range(10, 18)
		var sh: float = randf_range(8, 14)
		stone.size = Vector2(sw, sh)
		stone.position = Vector2(bl.x + randf_range(15, bw - 15), basin_y - sh)
		stone.color = Color(0.35, 0.33, 0.30, 0.65)
		stone.z_index = 1
		add_child(stone)

# The Atlantic: kelp forests, whale bones, sunken ship debris
func _build_atlantic_features(bl: Vector2, br: Vector2, _et: Vector2, _xt: Vector2, bw: float, basin_y: float) -> void:
	# Kelp forests — tall swaying plants
	for j in range(randi_range(8, 12)):
		var kx: float = bl.x + randf_range(20, bw - 20)
		var kelp := Line2D.new()
		kelp.width = 2.0
		kelp.default_color = Color(0.12, 0.35, 0.18, 0.65)
		kelp.z_index = 2
		var kh: float = randf_range(20, 45)
		var segments: int = randi_range(4, 7)
		for k in range(segments):
			var t: float = float(k) / float(segments - 1)
			kelp.add_point(Vector2(kx + sin(t * 3.0) * 6.0, basin_y - kh * t))
		add_child(kelp)
	# Whale bone ribs
	for j in range(randi_range(2, 3)):
		var bx: float = bl.x + randf_range(bw * 0.2, bw * 0.8)
		var bone_base_y: float = basin_y - randf_range(2, 6)
		for k in range(randi_range(4, 6)):
			var rib := Line2D.new()
			rib.width = 2.0
			rib.default_color = Color(0.75, 0.72, 0.65, 0.5)
			rib.z_index = 1
			var rib_x: float = bx + k * randf_range(4, 8)
			rib.add_point(Vector2(rib_x, bone_base_y))
			rib.add_point(Vector2(rib_x + randf_range(-3, 3), bone_base_y - randf_range(8, 16)))
			add_child(rib)
	# Sunken ship debris
	var ship_x: float = bl.x + bw * randf_range(0.55, 0.75)
	var ship_y: float = basin_y - 4
	# Hull fragment
	var hull := Polygon2D.new()
	hull.color = Color(0.30, 0.22, 0.15, 0.7)
	hull.z_index = 1
	hull.polygon = PackedVector2Array([
		Vector2(ship_x, ship_y),
		Vector2(ship_x + 5, ship_y - 18),
		Vector2(ship_x + 30, ship_y - 22),
		Vector2(ship_x + 45, ship_y - 14),
		Vector2(ship_x + 50, ship_y),
	])
	add_child(hull)
	# Mast
	var mast := Line2D.new()
	mast.width = 2.0
	mast.default_color = Color(0.35, 0.25, 0.15, 0.65)
	mast.z_index = 2
	mast.add_point(Vector2(ship_x + 20, ship_y - 20))
	mast.add_point(Vector2(ship_x + 18, ship_y - 50))
	add_child(mast)
	# Abyssal glow spots
	for j in range(randi_range(8, 12)):
		var glow_node := Node2D.new()
		glow_node.z_index = 2
		glow_node.position = Vector2(bl.x + randf_range(10, bw - 10), basin_y - randf_range(4, 30))
		add_child(glow_node)
		var glow_color := Color(0.2, 0.4, 0.9)
		var bulb := ColorRect.new()
		bulb.size = Vector2(3, 3)
		bulb.position = Vector2(-1.5, -1.5)
		bulb.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.5)
		glow_node.add_child(bulb)
		var aura := ColorRect.new()
		aura.size = Vector2(8, 8)
		aura.position = Vector2(-4, -4)
		aura.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.12)
		glow_node.add_child(aura)
		glow_plants.append({"node": glow_node, "bulb": bulb, "aura": aura, "glow_color": glow_color, "phase": randf() * TAU, "pulse_speed": randf_range(0.8, 2.0)})

# --- Swamp Geometry ---
func _get_swamp_geometry(swamp_index: int) -> Dictionary:
	var r: Array = SWAMP_RANGES[swamp_index]
	var start_idx: int = r[0]
	var end_idx: int = r[1]
	var all_pts: Array[Vector2] = []
	for i in range(start_idx, end_idx + 1):
		all_pts.append(terrain_points[i])
	return {
		"entry_top": terrain_points[start_idx],
		"basin_left": terrain_points[start_idx + 1],
		"basin_right": terrain_points[end_idx - 1],
		"exit_top": terrain_points[end_idx],
		"all_points": all_pts,
	}

# --- Water ---
func _build_water() -> void:
	water_polygons.clear()
	water_surface_lines.clear()
	water_glow_lines.clear()
	water_foam_lines.clear()
	# Per-pool waterline tracking
	_pool_high_water_y.clear()
	_pool_cur_water_y.clear()
	_pool_wet_fade.clear()
	_pool_foam_line_y.clear()
	_ripples.clear()
	for _i in range(SWAMP_COUNT):
		_pool_high_water_y.append(-100000.0)
		_pool_cur_water_y.append(-100000.0)
		_pool_wet_fade.append(1.0)
		_pool_foam_line_y.append(-100000.0)

	# Shared seamless distortion texture for screen-space refraction.
	_water_distort_tex = NoiseTexture2D.new()
	_water_distort_tex.seamless = true
	_water_distort_tex.width = 128
	_water_distort_tex.height = 128
	var fnl := FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnl.frequency = 0.04
	_water_distort_tex.noise = fnl

	# BackBufferCopy sits just under the water polygons (z below 2) so the back
	# buffer holds the underwater terrain content for refraction sampling.
	# NOTE: post_process_rect lives on CanvasLayer 100 and remains the last
	# screen reader; this copy only affects in-tree screen samples beneath it.
	water_back_buffer = BackBufferCopy.new()
	water_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	water_back_buffer.z_index = 1
	add_child(water_back_buffer)

	for i in range(SWAMP_COUNT):
		var wp := Polygon2D.new()
		wp.color = SWAMP_WATER_COLORS[i]
		wp.z_index = 2
		var wmat := ShaderMaterial.new()
		wmat.shader = WATER_SHADER
		wmat.set_shader_parameter("wave_strength", POOL_SHADER_PARAMS[i][0])
		wmat.set_shader_parameter("specular_intensity", POOL_SHADER_PARAMS[i][1])
		wmat.set_shader_parameter("choppiness", POOL_SHADER_PARAMS[i][2])
		wmat.set_shader_parameter("turbidity", POOL_SHADER_PARAMS[i][3])
		wmat.set_shader_parameter("foam_density", POOL_SHADER_PARAMS[i][4])
		# R2 murky-bayou params
		wmat.set_shader_parameter("beers", POOL_WATER_R2[i][0])
		wmat.set_shader_parameter("reflect_strength", POOL_WATER_R2[i][1])
		wmat.set_shader_parameter("opacity_floor", POOL_WATER_R2[i][2])
		wmat.set_shader_parameter("shallow_color", POOL_SHALLOW_COLORS[i])
		wmat.set_shader_parameter("deep_color", POOL_DEEP_COLORS[i])
		wmat.set_shader_parameter("foam_color", POOL_FOAM_COLORS[i])
		wmat.set_shader_parameter("sky_color", Vector3(0.55, 0.62, 0.45))
		# Screen-space refraction (opt-in; overworld pools get it)
		wmat.set_shader_parameter("use_refraction", true)
		wmat.set_shader_parameter("refraction_strength", POOL_WATER_R2[i][3])
		wmat.set_shader_parameter("distort_tex", _water_distort_tex)
		wp.material = wmat
		add_child(wp)
		water_polygons.append(wp)

		# Water surface shine line
		var wl := Line2D.new()
		wl.width = 3.0
		wl.default_color = WATER_SURFACE_COLOR
		wl.z_index = 3
		add_child(wl)
		water_surface_lines.append(wl)

		# Water edge glow (additive blend)
		var glow := Line2D.new()
		glow.width = 8.0
		glow.default_color = Color(0.2, 0.75, 0.65, 0.12)
		glow.z_index = 3
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = glow_mat
		add_child(glow)
		water_glow_lines.append(glow)

		# Lagging foam tide-line (brightens when it lags behind the dropping water)
		var foam_line := Line2D.new()
		foam_line.width = 2.5
		foam_line.default_color = Color(POOL_FOAM_COLORS[i].r, POOL_FOAM_COLORS[i].g, POOL_FOAM_COLORS[i].b, 0.0)
		foam_line.z_index = 3
		var foam_mat := CanvasItemMaterial.new()
		foam_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		foam_line.material = foam_mat
		add_child(foam_line)
		water_foam_lines.append(foam_line)

		_update_water_polygon(i)

func _update_water_polygon(swamp_index: int) -> void:
	var fill: float = GameManager.get_swamp_fill_fraction(swamp_index)

	if fill <= 0.001:
		water_polygons[swamp_index].polygon = PackedVector2Array()
		water_surface_lines[swamp_index].clear_points()
		if swamp_index < water_glow_lines.size():
			water_glow_lines[swamp_index].clear_points()
		return

	var deepest_y: float = _get_pool_deepest_y(swamp_index)
	var overflow_y: float = _get_pool_overflow_y(swamp_index)
	var water_y: float = deepest_y - fill * (deepest_y - overflow_y)

	var left_x: float = _find_water_left_x(swamp_index, water_y)
	var right_x: float = _find_water_right_x(swamp_index, water_y)

	# Build polygon by tracing terrain contour underwater
	var points := PackedVector2Array()
	points.append(Vector2(left_x, water_y))

	# Collect all pool terrain points that are below water_y
	var r: Array = SWAMP_RANGES[swamp_index]
	for i in range(r[0], r[1] + 1):
		var pt: Vector2 = terrain_points[i]
		if pt.y >= water_y and pt.x >= left_x and pt.x <= right_x:
			points.append(pt)

	points.append(Vector2(right_x, water_y))

	# Generate UVs based on normalized positions
	var min_y: float = water_y
	var max_y: float = deepest_y
	var y_range: float = maxf(max_y - min_y, 1.0)
	var uvs := PackedVector2Array()
	var total_pts: int = points.size()
	for pi in range(total_pts):
		var ux: float = float(pi) / float(maxi(total_pts - 1, 1))
		var uy: float = clampf((points[pi].y - min_y) / y_range, 0.0, 1.0)
		uvs.append(Vector2(ux, uy))

	water_polygons[swamp_index].polygon = points
	water_polygons[swamp_index].uv = uvs

	# --- Receding waterline tracking ---
	var prev_y: float = _pool_cur_water_y[swamp_index]
	_pool_cur_water_y[swamp_index] = water_y
	# high_water_y = the highest line ever reached (smallest screen-Y).
	if _pool_high_water_y[swamp_index] < -90000.0 or water_y < _pool_high_water_y[swamp_index]:
		_pool_high_water_y[swamp_index] = water_y
	# If the water dropped (water_y increased = lower on screen), freshly expose the bank.
	if prev_y > -90000.0 and water_y > prev_y + 0.5:
		_pool_wet_fade[swamp_index] = 0.0
	# Init the lagging foam line to the surface on first build.
	if _pool_foam_line_y[swamp_index] < -90000.0:
		_pool_foam_line_y[swamp_index] = water_y

	# Tint water based on fill using per-pool colors
	var col: Color = SWAMP_WATER_COLORS[swamp_index].lerp(SWAMP_WATER_EMPTY_COLORS[swamp_index], 1.0 - fill)
	water_polygons[swamp_index].color = col

	# Update surface line
	_update_water_surface_line(swamp_index, left_x, right_x, water_y)

func _update_water_surface_line(swamp_index: int, left_x: float, right_x: float, water_y: float) -> void:
	var line: Line2D = water_surface_lines[swamp_index]
	line.clear_points()
	var segments: int = int((right_x - left_x) / 6.0)
	segments = maxi(segments, 4)
	var wave_amp: float = POOL_WAVE_PARAMS[swamp_index][0]
	var wave_freq: float = POOL_WAVE_PARAMS[swamp_index][1]
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var px: float = lerpf(left_x, right_x, t)
		var wave_offset: float = sin(wave_time * wave_freq + px * 0.15) * wave_amp
		line.add_point(Vector2(px, water_y + wave_offset))
	# Update water edge glow
	if swamp_index < water_glow_lines.size():
		var glow: Line2D = water_glow_lines[swamp_index]
		glow.clear_points()
		for i in range(segments + 1):
			var gt: float = float(i) / float(segments)
			var gpx: float = lerpf(left_x, right_x, gt)
			var gwave: float = sin(wave_time * 1.5 + gpx * 0.12) * 2.0
			glow.add_point(Vector2(gpx, water_y + gwave))

func _push_terrain_waterline(swamp_index: int) -> void:
	if _terrain_mat == null:
		return
	_terrain_mat.set_shader_parameter("cur_water_y", _pool_cur_water_y[swamp_index])
	_terrain_mat.set_shader_parameter("high_water_y", _pool_high_water_y[swamp_index])
	_terrain_mat.set_shader_parameter("wet_fade", _pool_wet_fade[swamp_index])

func _spawn_bank_drips(swamp_index: int, from_y: float, to_y: float) -> void:
	# A few short downward drips on the freshly-exposed bank, alpha-fading.
	var geo: Dictionary = _get_swamp_geometry(swamp_index)
	var left_x: float = geo["basin_left"].x
	var right_x: float = geo["basin_right"].x
	var foam_col: Color = POOL_FOAM_COLORS[swamp_index]
	for _j in range(randi_range(3, 5)):
		var dx: float = randf_range(left_x + 6, right_x - 6)
		var start_y: float = randf_range(minf(from_y, to_y), maxf(from_y, to_y))
		var drip := Line2D.new()
		drip.width = 1.5
		drip.default_color = Color(foam_col.r + 0.2, foam_col.g + 0.2, foam_col.b + 0.2, 0.7)
		drip.z_index = 4
		drip.add_point(Vector2(dx, start_y))
		drip.add_point(Vector2(dx, start_y + 1))
		add_child(drip)
		var fall: float = randf_range(5, 12)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_method(func(p): drip.set_point_position(1, Vector2(dx, start_y + p)), 1.0, fall, randf_range(0.3, 0.55))
		tw.tween_property(drip, "modulate:a", 0.0, randf_range(0.4, 0.6))
		tw.set_parallel(false)
		tw.tween_callback(drip.queue_free)

# --- R2 interactive ripples ---
func _spawn_water_ripple(swamp_index: int, world_x: float) -> void:
	if swamp_index < 0 or swamp_index >= SWAMP_COUNT:
		return
	if swamp_index >= water_polygons.size():
		return
	var wp: Polygon2D = water_polygons[swamp_index]
	var surf_y: float = _pool_cur_water_y[swamp_index]
	if surf_y < -90000.0:
		return
	# Convert the world point to the water polygon's local space.
	var local_pt: Vector2 = wp.to_local(Vector2(world_x, surf_y))
	_ripples.append({"swamp": swamp_index, "pos": local_pt, "t": 0.0, "amp": 1.0})
	# Keep only the most recent ripples overall.
	while _ripples.size() > RIPPLE_MAX * 2:
		_ripples.pop_front()

func _update_ripples(delta: float) -> void:
	var kept: Array = []
	for r in _ripples:
		r["t"] += delta
		if r["t"] <= 2.5:
			kept.append(r)
	_ripples = kept

func _feed_ripples(wmat: ShaderMaterial, swamp_index: int) -> void:
	var pos_arr: Array[Vector2] = []
	var t_arr: Array[float] = []
	var amp_arr: Array[float] = []
	for r in _ripples:
		if r["swamp"] != swamp_index:
			continue
		if pos_arr.size() >= RIPPLE_MAX:
			break
		pos_arr.append(r["pos"])
		t_arr.append(r["t"])
		amp_arr.append(r["amp"])
	# Pad to fixed size; inactive entries use t < 0.
	while pos_arr.size() < RIPPLE_MAX:
		pos_arr.append(Vector2.ZERO)
		t_arr.append(-1.0)
		amp_arr.append(0.0)
	wmat.set_shader_parameter("ripple_pos", pos_arr)
	wmat.set_shader_parameter("ripple_t", t_arr)
	wmat.set_shader_parameter("ripple_amp", amp_arr)

func _update_foam_tide_line(swamp_index: int, delta: float) -> void:
	if swamp_index >= water_foam_lines.size():
		return
	var foam: Line2D = water_foam_lines[swamp_index]
	var water_y: float = _pool_cur_water_y[swamp_index]
	if water_y < -90000.0:
		foam.clear_points()
		return
	# Foam line lerps toward the water surface slower than the water drops,
	# so it lags behind and reads as "draining".
	var prev_foam_y: float = _pool_foam_line_y[swamp_index]
	_pool_foam_line_y[swamp_index] = lerpf(prev_foam_y, water_y, clampf(delta * 2.0, 0.0, 1.0))
	var foam_y: float = _pool_foam_line_y[swamp_index]
	# Brighten by how far the foam lags behind the actual surface.
	var lag: float = clampf(absf(foam_y - water_y) / 12.0, 0.0, 1.0)
	var base_col: Color = POOL_FOAM_COLORS[swamp_index]
	foam.default_color = Color(base_col.r + 0.15, base_col.g + 0.15, base_col.b + 0.15, 0.18 + lag * 0.55)
	# Reuse the surface span from the live water surface line.
	var sline: Line2D = water_surface_lines[swamp_index]
	foam.clear_points()
	if sline.get_point_count() < 2:
		return
	var lx: float = sline.get_point_position(0).x
	var rx: float = sline.get_point_position(sline.get_point_count() - 1).x
	var segs: int = maxi(int((rx - lx) / 6.0), 4)
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var px: float = lerpf(lx, rx, t)
		var wob: float = sin(wave_time * 2.4 + px * 0.18) * (0.6 + lag * 1.4)
		foam.add_point(Vector2(px, foam_y + wob))

func _lerp_x_at_y(p1: Vector2, p2: Vector2, target_y: float) -> float:
	if absf(p2.y - p1.y) < 0.001:
		return p1.x
	var t: float = (target_y - p1.y) / (p2.y - p1.y)
	t = clampf(t, 0.0, 1.0)
	return p1.x + t * (p2.x - p1.x)

# Multi-segment helpers for complex pool terrain
func _get_pool_deepest_y(swamp_index: int) -> float:
	var r: Array = SWAMP_RANGES[swamp_index]
	var deepest: float = terrain_points[r[0]].y
	for i in range(r[0], r[1] + 1):
		if terrain_points[i].y > deepest:
			deepest = terrain_points[i].y
	return deepest

func _get_pool_overflow_y(swamp_index: int) -> float:
	var r: Array = SWAMP_RANGES[swamp_index]
	return maxf(terrain_points[r[0]].y, terrain_points[r[1]].y)

func _get_pool_water_y(swamp_index: int) -> float:
	var fill: float = GameManager.get_swamp_fill_fraction(swamp_index)
	var deepest: float = _get_pool_deepest_y(swamp_index)
	var overflow: float = _get_pool_overflow_y(swamp_index)
	return deepest - fill * (deepest - overflow)

func _find_water_left_x(swamp_index: int, water_y: float) -> float:
	# Search entry slope segments from entry_top toward basin
	var r: Array = SWAMP_RANGES[swamp_index]
	for i in range(r[0], r[1]):
		var p1: Vector2 = terrain_points[i]
		var p2: Vector2 = terrain_points[i + 1]
		# Check if water_y intersects this segment
		if (p1.y <= water_y and p2.y >= water_y) or (p1.y >= water_y and p2.y <= water_y):
			return _lerp_x_at_y(p1, p2, water_y)
	# Fallback: entry_top x
	return terrain_points[r[0]].x

func _find_water_right_x(swamp_index: int, water_y: float) -> float:
	# Search exit slope segments from exit_top toward basin (reverse)
	var r: Array = SWAMP_RANGES[swamp_index]
	for i in range(r[1], r[0], -1):
		var p1: Vector2 = terrain_points[i]
		var p2: Vector2 = terrain_points[i - 1]
		# Check if water_y intersects this segment
		if (p1.y <= water_y and p2.y >= water_y) or (p1.y >= water_y and p2.y <= water_y):
			return _lerp_x_at_y(p1, p2, water_y)
	# Fallback: exit_top x
	return terrain_points[r[1]].x

# --- Water Walls ---
func _build_water_walls() -> void:
	water_walls.clear()
	for i in range(SWAMP_COUNT):
		var left_body := StaticBody2D.new()
		var left_col := CollisionShape2D.new()
		var left_rect := RectangleShape2D.new()
		left_rect.size = Vector2(8, 56)
		left_col.shape = left_rect
		left_body.add_child(left_col)
		add_child(left_body)

		var right_body := StaticBody2D.new()
		var right_col := CollisionShape2D.new()
		var right_rect := RectangleShape2D.new()
		right_rect.size = Vector2(8, 56)
		right_col.shape = right_rect
		right_body.add_child(right_col)
		add_child(right_body)

		water_walls.append({"left": left_body, "right": right_body})
		_update_water_walls(i)

func _update_water_walls(swamp_index: int) -> void:
	var fill: float = GameManager.get_swamp_fill_fraction(swamp_index)
	var walls: Dictionary = water_walls[swamp_index]
	var left_body: StaticBody2D = walls["left"]
	var right_body: StaticBody2D = walls["right"]
	var left_col: CollisionShape2D = left_body.get_child(0) as CollisionShape2D
	var right_col: CollisionShape2D = right_body.get_child(0) as CollisionShape2D

	if fill <= 0.001:
		left_col.disabled = true
		right_col.disabled = true
		left_body.visible = false
		right_body.visible = false
		return

	left_col.disabled = false
	right_col.disabled = false
	left_body.visible = true
	right_body.visible = true

	var water_y: float = _get_pool_water_y(swamp_index)
	var left_x: float = _find_water_left_x(swamp_index, water_y)
	var right_x: float = _find_water_right_x(swamp_index, water_y)

	left_body.position = Vector2(left_x, water_y - 28)
	right_body.position = Vector2(right_x, water_y - 28)

# --- Right Boundary Wall ---
func _build_left_boundary() -> void:
	var wall_body := StaticBody2D.new()
	wall_body.position = Vector2(terrain_points[0].x - 4, terrain_points[0].y - 60)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 200)
	col.shape = rect
	wall_body.add_child(col)
	add_child(wall_body)

func _build_right_boundary() -> void:
	var last_point: Vector2 = terrain_points[terrain_points.size() - 1]
	var wall_body := StaticBody2D.new()
	wall_body.position = Vector2(last_point.x + 4, last_point.y - 60)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 200)
	col.shape = rect
	wall_body.add_child(col)
	add_child(wall_body)

# --- Dense trees/brush at left boundary ---
# Place hero cypress trees at the edges of each pool basin (R3).
func _build_cypresses() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry_top: Vector2 = geo["entry_top"]
		var exit_top: Vector2 = geo["exit_top"]
		var sc: float = randf_range(0.7, 1.0)
		# One cypress at the entry shoulder, occasionally a second at the exit.
		var ex: float = entry_top.x + randf_range(-22, -8)
		_place_cypress(Vector2(ex, _get_terrain_y_at(ex)), sc, 4)
		if randf() < 0.55:
			var xx: float = exit_top.x + randf_range(8, 22)
			_place_cypress(Vector2(xx, _get_terrain_y_at(xx)), randf_range(0.6, 0.9), 4)

# --- Hero procedural trees (R3) ---
# Tapered trunk + forking branches + clustered swaying canopy blobs + rim light.
func _place_tree(pos: Vector2, scale: float = 1.0, zi: int = 4) -> void:
	# Contact AO at the base.
	_place_contact_ao(pos.x, pos.y, 14.0 * scale, 4.0 * scale, 0.30, zi - 1)

	var trunk_h: float = randf_range(38, 58) * scale
	var base_hw: float = randf_range(3.5, 5.0) * scale
	var top_hw: float = base_hw * 0.4
	var lean: float = randf_range(-4, 4) * scale
	var top := Vector2(pos.x + lean, pos.y - trunk_h)

	# Tapered trunk polygon, 2-tone vertical gradient, darker left edge for form.
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(pos.x - base_hw, pos.y),
		Vector2(pos.x + base_hw, pos.y),
		Vector2(top.x + top_hw, top.y),
		Vector2(top.x - top_hw, top.y),
	])
	var bark_dark := Color(0.16, 0.10, 0.05)
	var bark_light := Color(0.30, 0.20, 0.10)
	# base-left (dark/shadow), base-right (lit), top-right (lit), top-left (dark)
	trunk.vertex_colors = PackedColorArray([
		bark_dark.darkened(0.2), bark_light, bark_light.lerp(bark_dark, 0.3), bark_dark])
	trunk.z_index = zi
	add_child(trunk)

	# 2-3 forking branches.
	var n_branch: int = randi_range(2, 3)
	for b in range(n_branch):
		var t: float = randf_range(0.55, 0.85)
		var bx: float = lerpf(pos.x, top.x, t)
		var by: float = lerpf(pos.y, top.y, t)
		var dir: float = -1.0 if (b % 2 == 0) else 1.0
		var blen: float = randf_range(10, 18) * scale
		var bw: float = base_hw * randf_range(0.4, 0.6)
		var ex: float = bx + dir * blen
		var ey: float = by - blen * randf_range(0.4, 0.8)
		var br := Polygon2D.new()
		br.polygon = PackedVector2Array([
			Vector2(bx, by + bw), Vector2(bx, by - bw),
			Vector2(ex, ey),
		])
		br.color = bark_dark.lerp(bark_light, 0.3)
		br.z_index = zi
		add_child(br)

	# 4-8 overlapping canopy blobs: back-dark/cool -> front-bright/warm.
	var n_blob: int = randi_range(5, 8)
	var canopy_cx: float = top.x
	var canopy_cy: float = top.y - 4.0 * scale
	for c in range(n_blob):
		var depth: float = float(c) / float(n_blob - 1)  # 0 back -> 1 front
		var bcx: float = canopy_cx + randf_range(-16, 16) * scale
		var bcy: float = canopy_cy + randf_range(-12, 8) * scale - depth * 2.0
		var brw: float = randf_range(10, 18) * scale
		var brh: float = randf_range(9, 15) * scale
		var blob := Polygon2D.new()
		var bpts := PackedVector2Array()
		var nv: int = randi_range(8, 12)
		for a in range(nv):
			var ang: float = TAU * float(a) / float(nv)
			bpts.append(Vector2(
				bcx + cos(ang) * brw * randf_range(0.82, 1.0),
				bcy + sin(ang) * brh * randf_range(0.82, 1.0)))
		blob.polygon = bpts
		# UVs: top of blob = 0 (light + max sway), bottom = 1 (dark + anchored)
		var uvs := PackedColorArray()
		var bptuv := PackedVector2Array()
		var cl_dark := Color(0.05, 0.16, 0.04).lerp(Color(0.10, 0.30, 0.08), depth)
		var cl_light := Color(0.16, 0.34, 0.10).lerp(Color(0.34, 0.54, 0.18), depth)
		# cool the back blobs
		if depth < 0.4:
			cl_dark = cl_dark.lerp(Color(0.10, 0.22, 0.22), 0.25)
			cl_light = cl_light.lerp(Color(0.18, 0.34, 0.30), 0.25)
		for p in bpts:
			var vy: float = clampf((p.y - (bcy - brh)) / (brh * 2.0), 0.0, 1.0)  # 0 top, 1 bottom
			bptuv.append(Vector2(0.5, vy))
			uvs.append(cl_dark.lerp(cl_light, 1.0 - vy))
		blob.uv = bptuv
		blob.vertex_colors = uvs
		blob.material = _sway_mat_canopy
		blob.z_index = zi + 1 + int(depth * 2.0)
		add_child(blob)

	# Rim-light cluster (top-left), lighter, no/low sway.
	var rim := Polygon2D.new()
	var rpts := PackedVector2Array()
	var rcx: float = canopy_cx - 8.0 * scale
	var rcy: float = canopy_cy - 8.0 * scale
	for a in range(7):
		var ang2: float = TAU * float(a) / 7.0
		rpts.append(Vector2(rcx + cos(ang2) * 8.0 * scale, rcy + sin(ang2) * 6.0 * scale))
	rim.polygon = rpts
	rim.color = Color(0.42, 0.62, 0.26, 0.55)
	rim.z_index = zi + 4
	add_child(rim)

# Cypress: tall narrow trunk + knees at base + hanging Spanish moss strands.
func _place_cypress(pos: Vector2, scale: float = 1.0, zi: int = 4) -> void:
	_place_contact_ao(pos.x, pos.y, 12.0 * scale, 3.5 * scale, 0.30, zi - 1)

	var trunk_h: float = randf_range(62, 86) * scale
	var base_hw: float = randf_range(3.0, 4.2) * scale
	var top := Vector2(pos.x + randf_range(-3, 3) * scale, pos.y - trunk_h)
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(pos.x - base_hw, pos.y),
		Vector2(pos.x + base_hw, pos.y),
		Vector2(top.x + base_hw * 0.3, top.y),
		Vector2(top.x - base_hw * 0.3, top.y),
	])
	var bark_dark := Color(0.14, 0.10, 0.07)
	var bark_light := Color(0.26, 0.19, 0.12)
	trunk.vertex_colors = PackedColorArray([bark_dark.darkened(0.2), bark_light, bark_light, bark_dark])
	trunk.z_index = zi
	add_child(trunk)

	# Knees: small cone polygons around the base (cypress "knees").
	var n_knee: int = randi_range(3, 5)
	for k in range(n_knee):
		var kx: float = pos.x + randf_range(-14, 14) * scale
		var kh: float = randf_range(4, 9) * scale
		var kw: float = randf_range(2, 4) * scale
		var knee := Polygon2D.new()
		knee.polygon = PackedVector2Array([
			Vector2(kx - kw, pos.y), Vector2(kx + kw, pos.y), Vector2(kx, pos.y - kh)])
		knee.color = bark_dark.lerp(bark_light, randf_range(0.2, 0.5))
		knee.z_index = zi
		add_child(knee)

	# Sparse high canopy blobs.
	for c in range(randi_range(3, 5)):
		var bcx: float = top.x + randf_range(-12, 12) * scale
		var bcy: float = top.y + randf_range(-2, 14) * scale
		var blob := Polygon2D.new()
		var bpts := PackedVector2Array()
		for a in range(9):
			var ang: float = TAU * float(a) / 9.0
			bpts.append(Vector2(bcx + cos(ang) * 11.0 * scale * randf_range(0.8, 1.0),
				bcy + sin(ang) * 8.0 * scale * randf_range(0.8, 1.0)))
		blob.polygon = bpts
		var uvb := PackedVector2Array()
		var cb := PackedColorArray()
		var cl_dark := Color(0.08, 0.20, 0.08)
		var cl_light := Color(0.22, 0.40, 0.16)
		for p in bpts:
			var vy: float = clampf((p.y - (bcy - 8.0 * scale)) / (16.0 * scale), 0.0, 1.0)
			uvb.append(Vector2(0.5, vy))
			cb.append(cl_dark.lerp(cl_light, 1.0 - vy))
		blob.uv = uvb
		blob.vertex_colors = cb
		blob.material = _sway_mat_canopy
		blob.z_index = zi + 1
		add_child(blob)

	# Spanish moss: thin vertical strands hanging from the canopy, gray-green,
	# on the moss sway material (high strength / low stiffness = it drapes & drifts).
	for m in range(randi_range(4, 8)):
		var mx: float = top.x + randf_range(-14, 14) * scale
		var my: float = top.y + randf_range(2, 16) * scale
		var mlen: float = randf_range(12, 26) * scale
		var strand := Polygon2D.new()
		var w: float = randf_range(0.8, 1.6)
		strand.polygon = PackedVector2Array([
			Vector2(mx - w, my), Vector2(mx + w, my),
			Vector2(mx + w * 0.4, my + mlen), Vector2(mx - w * 0.4, my + mlen),
		])
		# UV.y = 1 at the hanging tip (max sway), 0 at the attached top (anchored)
		strand.uv = PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		var moss_top := Color(0.42, 0.46, 0.34, 0.85)
		var moss_tip := Color(0.55, 0.58, 0.46, 0.55)
		strand.vertex_colors = PackedColorArray([moss_top, moss_top, moss_tip, moss_tip])
		strand.material = _sway_mat_moss
		strand.z_index = zi + 2
		add_child(strand)

func _build_left_trees() -> void:
	var tree_x_start: float = terrain_points[0].x  # -240
	var tree_x_end: float = terrain_points[0].x + 60.0  # -180
	var ground_y: float = terrain_points[0].y  # ~118

	# Dense canopy — overlapping dark-green ovals
	var canopy_colors: Array[Color] = [
		Color(0.06, 0.18, 0.04), Color(0.08, 0.22, 0.06),
		Color(0.05, 0.15, 0.03), Color(0.07, 0.20, 0.05),
	]
	for i in range(12):
		var cx: float = randf_range(tree_x_start - 20, tree_x_end + 10)
		var cy: float = ground_y - randf_range(20, 70)
		var rw: float = randf_range(16, 32)
		var rh: float = randf_range(14, 26)
		var canopy := Polygon2D.new()
		var pts := PackedVector2Array()
		for a in range(8):
			var angle: float = TAU * float(a) / 8.0
			pts.append(Vector2(
				cx + cos(angle) * rw * randf_range(0.8, 1.0),
				cy + sin(angle) * rh * randf_range(0.8, 1.0)
			))
		canopy.polygon = pts
		canopy.color = canopy_colors[i % canopy_colors.size()]
		canopy.z_index = 5
		add_child(canopy)

	# Trunks
	for i in range(5):
		var tx: float = randf_range(tree_x_start, tree_x_end)
		var trunk := ColorRect.new()
		trunk.position = Vector2(tx, ground_y - randf_range(30, 55))
		trunk.size = Vector2(randf_range(3, 6), randf_range(30, 55))
		trunk.color = Color(0.12, 0.08, 0.04, 0.8)
		trunk.z_index = 4
		add_child(trunk)

	# Undergrowth / brush — low wide shapes filling the base
	for i in range(8):
		var bx: float = randf_range(tree_x_start - 10, tree_x_end + 20)
		var by: float = ground_y - randf_range(2, 14)
		var brush := ColorRect.new()
		brush.position = Vector2(bx, by)
		brush.size = Vector2(randf_range(12, 24), randf_range(6, 12))
		brush.color = Color(0.05, 0.14, 0.03, randf_range(0.7, 0.9))
		brush.z_index = 5
		add_child(brush)

	# Two hero foreground cypress at the left edge framing the scene (R3).
	_place_cypress(Vector2(tree_x_end + 4, ground_y), 1.0, 6)
	_place_cypress(Vector2(tree_x_start + 8, ground_y), randf_range(0.8, 0.95), 6)

# --- Island with house at the right end ---
func _build_island_house() -> void:
	var island_cx: float = 5660.0
	var island_y: float = 484.0  # Ground level on the flat top
	var mw: float = 80.0  # Mansion width
	var mh: float = 40.0  # Mansion height (two stories)
	var mx: float = island_cx - mw * 0.5  # Mansion left edge

	# Foundation / platform
	var foundation := ColorRect.new()
	foundation.position = Vector2(mx - 4, island_y - 4)
	foundation.size = Vector2(mw + 8, 6)
	foundation.color = Color(0.4, 0.38, 0.32)
	foundation.z_index = 2
	add_child(foundation)

	# Main wall (two-story)
	var wall := ColorRect.new()
	wall.position = Vector2(mx, island_y - mh)
	wall.size = Vector2(mw, mh)
	wall.color = Color(0.55, 0.45, 0.30)
	wall.z_index = 3
	add_child(wall)

	# Floor divider line (between stories)
	var floor_div := ColorRect.new()
	floor_div.position = Vector2(mx, island_y - mh * 0.5)
	floor_div.size = Vector2(mw, 1)
	floor_div.color = Color(0.42, 0.34, 0.22, 0.5)
	floor_div.z_index = 3
	add_child(floor_div)

	# Bottom windows (4 across)
	for wi in range(4):
		var win := ColorRect.new()
		var wx: float = mx + 8 + wi * 18
		win.position = Vector2(wx, island_y - 16)
		win.size = Vector2(8, 8)
		win.color = Color(0.6, 0.75, 0.85, 0.8)
		win.z_index = 4
		add_child(win)
		# Window frame cross
		var wh := ColorRect.new()
		wh.position = Vector2(wx, island_y - 12)
		wh.size = Vector2(8, 1)
		wh.color = Color(0.42, 0.34, 0.22)
		wh.z_index = 5
		add_child(wh)
		var wv := ColorRect.new()
		wv.position = Vector2(wx + 4, island_y - 16)
		wv.size = Vector2(1, 8)
		wv.color = Color(0.42, 0.34, 0.22)
		wv.z_index = 5
		add_child(wv)

	# Top windows (3 across)
	for wi in range(3):
		var win := ColorRect.new()
		var wx: float = mx + 14 + wi * 22
		win.position = Vector2(wx, island_y - 36)
		win.size = Vector2(8, 8)
		win.color = Color(0.6, 0.75, 0.85, 0.8)
		win.z_index = 4
		add_child(win)
		var wh := ColorRect.new()
		wh.position = Vector2(wx, island_y - 32)
		wh.size = Vector2(8, 1)
		wh.color = Color(0.42, 0.34, 0.22)
		wh.z_index = 5
		add_child(wh)

	# Door (centered, taller)
	var door := ColorRect.new()
	door.position = Vector2(island_cx - 5, island_y - 16)
	door.size = Vector2(10, 16)
	door.color = Color(0.28, 0.18, 0.10)
	door.z_index = 4
	add_child(door)

	# Door handle
	var dhandle := ColorRect.new()
	dhandle.position = Vector2(island_cx + 2, island_y - 8)
	dhandle.size = Vector2(2, 2)
	dhandle.color = Color(0.7, 0.6, 0.3)
	dhandle.z_index = 5
	add_child(dhandle)

	# Columns flanking door (2 thin rectangles)
	for ci in [-1, 1]:
		var col := ColorRect.new()
		col.position = Vector2(island_cx + ci * 8 - 1, island_y - 20)
		col.size = Vector2(2, 20)
		col.color = Color(0.72, 0.68, 0.58)
		col.z_index = 4
		add_child(col)

	# Balcony on second floor (small overhang)
	var balcony := Polygon2D.new()
	balcony.polygon = PackedVector2Array([
		Vector2(island_cx - 14, island_y - mh * 0.5),
		Vector2(island_cx + 14, island_y - mh * 0.5),
		Vector2(island_cx + 14, island_y - mh * 0.5 + 3),
		Vector2(island_cx - 14, island_y - mh * 0.5 + 3),
	])
	balcony.color = Color(0.62, 0.55, 0.42)
	balcony.z_index = 5
	add_child(balcony)

	# Balcony railing
	var railing := Line2D.new()
	railing.width = 1.0
	railing.default_color = Color(0.5, 0.45, 0.35, 0.8)
	railing.z_index = 5
	railing.add_point(Vector2(island_cx - 14, island_y - mh * 0.5 - 6))
	railing.add_point(Vector2(island_cx - 14, island_y - mh * 0.5))
	add_child(railing)
	var railing2 := Line2D.new()
	railing2.width = 1.0
	railing2.default_color = Color(0.5, 0.45, 0.35, 0.8)
	railing2.z_index = 5
	railing2.add_point(Vector2(island_cx + 14, island_y - mh * 0.5 - 6))
	railing2.add_point(Vector2(island_cx + 14, island_y - mh * 0.5))
	add_child(railing2)
	var railing_top := Line2D.new()
	railing_top.width = 1.0
	railing_top.default_color = Color(0.5, 0.45, 0.35, 0.8)
	railing_top.z_index = 5
	railing_top.add_point(Vector2(island_cx - 14, island_y - mh * 0.5 - 6))
	railing_top.add_point(Vector2(island_cx + 14, island_y - mh * 0.5 - 6))
	add_child(railing_top)

	# Wider triangular roof with apex
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(mx - 4, island_y - mh),
		Vector2(island_cx, island_y - mh - 22),
		Vector2(mx + mw + 4, island_y - mh),
	])
	roof.color = Color(0.55, 0.22, 0.12)
	roof.z_index = 5
	add_child(roof)

	# Weathervane on roof apex
	var vane_pole := ColorRect.new()
	vane_pole.position = Vector2(island_cx, island_y - mh - 22 - 8)
	vane_pole.size = Vector2(1, 8)
	vane_pole.color = Color(0.35, 0.30, 0.25)
	vane_pole.z_index = 6
	add_child(vane_pole)
	var vane_arrow := Line2D.new()
	vane_arrow.width = 1.0
	vane_arrow.default_color = Color(0.35, 0.30, 0.25)
	vane_arrow.z_index = 6
	vane_arrow.add_point(Vector2(island_cx - 4, island_y - mh - 28))
	vane_arrow.add_point(Vector2(island_cx + 4, island_y - mh - 28))
	add_child(vane_arrow)

	# Chimney
	var chimney := ColorRect.new()
	chimney.position = Vector2(mx + mw - 12, island_y - mh - 16)
	chimney.size = Vector2(6, 16)
	chimney.color = Color(0.38, 0.32, 0.28)
	chimney.z_index = 4
	add_child(chimney)

	# Dock/pier — wooden planks extending left from island shore
	var dock_y: float = island_y + 2
	for di in range(6):
		var plank := ColorRect.new()
		plank.position = Vector2(mx - 50 + di * 9, dock_y - 2)
		plank.size = Vector2(8, 3)
		plank.color = Color(0.45, 0.35, 0.22, 0.85)
		plank.z_index = 2
		add_child(plank)
	# Dock support posts
	for di in [0, 2, 4]:
		var post := ColorRect.new()
		post.position = Vector2(mx - 50 + di * 9 + 3, dock_y)
		post.size = Vector2(2, 8)
		post.color = Color(0.35, 0.28, 0.18, 0.7)
		post.z_index = 1
		add_child(post)

	# Palm tree (tropical island feel)
	var tree_x: float = island_cx + 50
	var tree_trunk := ColorRect.new()
	tree_trunk.position = Vector2(tree_x, island_y - 32)
	tree_trunk.size = Vector2(3, 32)
	tree_trunk.color = Color(0.35, 0.25, 0.12)
	tree_trunk.z_index = 2
	add_child(tree_trunk)
	# Palm fronds
	for fi in range(5):
		var frond := Line2D.new()
		frond.width = 2.0
		var fa: float = -PI * 0.7 + fi * (PI * 0.4 / 4.0)
		frond.default_color = Color(0.15, 0.35, 0.10)
		frond.z_index = 3
		frond.add_point(Vector2(tree_x + 1, island_y - 32))
		frond.add_point(Vector2(tree_x + 1 + cos(fa) * 14, island_y - 32 + sin(fa) * 10))
		add_child(frond)

func _build_island_politicians() -> void:
	var island_cx: float = 5660.0
	var island_y: float = 484.0
	politician_nodes.clear()

	# Character definitions: name, suit_color, head_color, feature_func
	# Semi-circle in front of mansion door. Jeff in center.
	var positions: Array[Vector2] = [
		Vector2(island_cx - 24, island_y),  # Lobbyton (far left)
		Vector2(island_cx - 16, island_y),  # Kickback
		Vector2(island_cx - 8, island_y),   # Consultant
		Vector2(island_cx, island_y),        # Jeff (center)
		Vector2(island_cx + 8, island_y),   # Swampsworth
		Vector2(island_cx + 16, island_y),  # Spinwell
		Vector2(island_cx + 24, island_y),  # Goodwell (far right)
	]

	# Build each politician figure
	for pi in range(7):
		var pnode := Node2D.new()
		pnode.position = positions[pi]
		pnode.z_index = 6
		add_child(pnode)
		politician_nodes.append(pnode)

		var suit_color: Color
		var leg_color: Color
		var head_color := Color(0.85, 0.70, 0.55)
		var has_hair: bool = true

		match pi:
			0:  # Lobbyton — blue blazer, hair bun
				suit_color = Color(0.18, 0.22, 0.45)
				leg_color = Color(0.15, 0.18, 0.38)
			1:  # Kickback — brown suit
				suit_color = Color(0.40, 0.28, 0.15)
				leg_color = Color(0.32, 0.22, 0.12)
			2:  # Consultant — gray trenchcoat
				suit_color = Color(0.38, 0.38, 0.36)
				leg_color = Color(0.30, 0.30, 0.28)
			3:  # Jeff — dark suit
				suit_color = Color(0.15, 0.15, 0.35)
				leg_color = Color(0.12, 0.12, 0.30)
			4:  # Swampsworth — dark suit, bald, red tie
				suit_color = Color(0.18, 0.18, 0.20)
				leg_color = Color(0.15, 0.15, 0.18)
				has_hair = false
			5:  # Spinwell — tan suit
				suit_color = Color(0.55, 0.48, 0.35)
				leg_color = Color(0.45, 0.38, 0.28)
			6:  # Goodwell — dark suit (corrupted by endgame)
				suit_color = Color(0.18, 0.18, 0.22)
				leg_color = Color(0.15, 0.15, 0.18)

		# Body
		var body := ColorRect.new()
		body.position = Vector2(-3, -16)
		body.size = Vector2(6, 12)
		body.color = suit_color
		pnode.add_child(body)

		# Arms
		var arm_l := ColorRect.new()
		arm_l.position = Vector2(-5, -15)
		arm_l.size = Vector2(2, 8)
		arm_l.color = suit_color.darkened(0.1)
		pnode.add_child(arm_l)
		var arm_r := ColorRect.new()
		arm_r.position = Vector2(3, -15)
		arm_r.size = Vector2(2, 8)
		arm_r.color = suit_color.darkened(0.1)
		pnode.add_child(arm_r)

		# Head
		var head := Polygon2D.new()
		var head_pts := PackedVector2Array()
		for hi in range(8):
			var angle: float = TAU * float(hi) / 8.0
			head_pts.append(Vector2(cos(angle) * 3.5, -20 + sin(angle) * 3.5))
		head.polygon = head_pts
		head.color = head_color
		pnode.add_child(head)

		# Hair (if not bald)
		if has_hair:
			var hair := ColorRect.new()
			hair.position = Vector2(-3.5, -24)
			hair.size = Vector2(7, 3)
			hair.color = Color(0.2, 0.15, 0.10)
			pnode.add_child(hair)

		# Legs
		var ll := ColorRect.new()
		ll.position = Vector2(-3, -4)
		ll.size = Vector2(2, 4)
		ll.color = leg_color
		pnode.add_child(ll)
		var rl := ColorRect.new()
		rl.position = Vector2(1, -4)
		rl.size = Vector2(2, 4)
		rl.color = leg_color
		pnode.add_child(rl)

		# Distinguishing features
		match pi:
			0:  # Lobbyton — hair bun
				var bun := Polygon2D.new()
				var bun_pts := PackedVector2Array()
				for bi in range(6):
					var ba: float = TAU * float(bi) / 6.0
					bun_pts.append(Vector2(cos(ba) * 2.5, -24 + sin(ba) * 2.5))
				bun.polygon = bun_pts
				bun.color = Color(0.25, 0.18, 0.12)
				pnode.add_child(bun)
			1:  # Kickback — gold chain
				var chain := ColorRect.new()
				chain.position = Vector2(-2, -14)
				chain.size = Vector2(4, 1)
				chain.color = Color(0.85, 0.75, 0.2)
				pnode.add_child(chain)
			2:  # Consultant — briefcase in hand
				var case := ColorRect.new()
				case.position = Vector2(5, -8)
				case.size = Vector2(4, 3)
				case.color = Color(0.30, 0.22, 0.12)
				pnode.add_child(case)
			3:  # Jeff — sunglasses
				var glasses := ColorRect.new()
				glasses.position = Vector2(-3, -21)
				glasses.size = Vector2(6, 2)
				glasses.color = Color(0.05, 0.05, 0.05)
				pnode.add_child(glasses)
			4:  # Swampsworth — red tie, wide stance
				var tie := ColorRect.new()
				tie.position = Vector2(-1, -15)
				tie.size = Vector2(2, 8)
				tie.color = Color(0.7, 0.12, 0.10)
				pnode.add_child(tie)
				# Wider stance — move legs apart
				ll.position.x = -4
				rl.position.x = 2
			5:  # Spinwell — clipboard
				var clip := ColorRect.new()
				clip.position = Vector2(-7, -12)
				clip.size = Vector2(3, 5)
				clip.color = Color(0.82, 0.78, 0.68)
				pnode.add_child(clip)
			6:  # Goodwell — (no extra feature, was corrupted)
				pass

	# Jeff is at index 3 — use as interaction target
	jeff_node = politician_nodes[3]

	# Interaction Area2D covers the whole group
	jeff_area = Area2D.new()
	jeff_area.collision_layer = 0
	jeff_area.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(70, 40)
	col.shape = shape
	col.position = Vector2(island_cx, island_y - 10)
	jeff_area.add_child(col)
	add_child(jeff_area)
	jeff_area.body_entered.connect(func(_body: Node2D) -> void: player_near_jeff = true)
	jeff_area.body_exited.connect(func(_body: Node2D) -> void: player_near_jeff = false)

func _spawn_helicopter() -> void:
	var cam_h: Camera2D = get_viewport().get_camera_2d()
	var cam_h_x: float = cam_h.get_screen_center_position().x if cam_h else 320.0
	var start_x: float = cam_h_x - 380.0
	var sky_y: float = 20.0

	helicopter_active = Node2D.new()
	helicopter_active.position = Vector2(start_x, sky_y)
	helicopter_active.z_index = 15
	add_child(helicopter_active)

	# Body
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-12, -3), Vector2(-8, -5), Vector2(8, -5), Vector2(12, -3),
		Vector2(12, 2), Vector2(8, 4), Vector2(-8, 4), Vector2(-14, 2),
	])
	body.color = Color(0.15, 0.18, 0.15, 0.9)
	helicopter_active.add_child(body)

	# Tail boom
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-14, -1), Vector2(-24, -3), Vector2(-24, 0), Vector2(-14, 2),
	])
	tail.color = Color(0.18, 0.20, 0.18, 0.85)
	helicopter_active.add_child(tail)

	# Tail rotor
	var tail_rotor := ColorRect.new()
	tail_rotor.size = Vector2(1, 6)
	tail_rotor.position = Vector2(-24, -5)
	tail_rotor.color = Color(0.3, 0.32, 0.3, 0.7)
	helicopter_active.add_child(tail_rotor)

	# Main rotor (rotates)
	var rotor := Line2D.new()
	rotor.name = "rotor"
	rotor.width = 1.0
	rotor.default_color = Color(0.3, 0.32, 0.3, 0.8)
	rotor.add_point(Vector2(-16, 0))
	rotor.add_point(Vector2(16, 0))
	rotor.position = Vector2(0, -6)
	helicopter_active.add_child(rotor)

	# GOVT label
	var govt_lbl := Label.new()
	govt_lbl.text = "GOVT"
	govt_lbl.add_theme_font_size_override("font_size", 4)
	govt_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5, 0.7))
	govt_lbl.position = Vector2(-8, -4)
	helicopter_active.add_child(govt_lbl)

	# Skids
	var skid_l := ColorRect.new()
	skid_l.size = Vector2(10, 1)
	skid_l.position = Vector2(-6, 5)
	skid_l.color = Color(0.25, 0.25, 0.25, 0.8)
	helicopter_active.add_child(skid_l)

func _trigger_endgame() -> void:
	if endgame_triggered:
		return
	endgame_triggered = true

	# Freeze player
	var players_eg: Array[Node] = get_tree().get_nodes_in_group("player")
	if players_eg.size() > 0 and is_instance_valid(players_eg[0]):
		players_eg[0].set_physics_process(false)
		players_eg[0].set_process_unhandled_input(false)

	# Tell the story through newspapers
	SceneManager.show_endgame_newspapers([
		{
			"date": "SPECIAL EDITION",
			"headline": "IT'S GONE. HE ACTUALLY DID IT.",
			"subhead": "Lone government employee drains the Atlantic Ocean with his bare hands",
			"body": "In what experts are calling \"the most pointlessly determined act in human history,\" the sole employee of the Swamp Draining Initiative has drained the Atlantic Ocean.\n\nThe man, whose name has been redacted from all government records, began with a puddle and a pair of hands. He ended with an empty ocean basin and what neighbors describe as \"a thousand-yard stare.\"\n\n\"We gave him no tools, no budget, and no support,\" said a visibly shaken government spokesperson. \"We honestly thought he'd quit after the first day.\"\n\nThe ocean floor is now visible for the first time in recorded history. Several previously unknown species have been discovered, all of them \"very confused.\""
		},
		{
			"date": "SPECIAL EDITION — BREAKING",
			"headline": "DRAINER ARRESTED IN DRAMATIC ISLAND RAID",
			"subhead": "CIA intercepts lone employee moments before confrontation with officials",
			"body": "CIA operatives intercepted the drainer on the private island moments before he could confront officials. The drainer, armed with what witnesses described as \"a shotgun and an attitude,\" was airlifted from the scene in federal custody.\n\nSenate Majority Leader Goodwell issued a statement: \"This individual was a rogue actor who threatened the safety of hardworking public servants. We are grateful to the CIA for their swift action.\"\n\nThe drainer reportedly said nothing during the arrest. Witnesses say he simply looked back at the empty ocean basin and nodded once.\n\nCharges include \"environmental terrorism,\" \"illegal possession of a shotgun in a wetland,\" and \"misappropriation of government spoon.\""
		},
		{
			"date": "SPECIAL EDITION — WHERE ARE THEY NOW",
			"headline": "OFFICIALS EXONERATED, DRAINER FORGOTTEN",
			"subhead": "All implicated politicians pardoned; swamp ordered refilled at taxpayer expense",
			"body": "SENATE MAJORITY LEADER GOODWELL — Issued blanket pardons for all implicated officials. \"There was no corruption. There was never any corruption. Focus on what matters.\"\n\nSENATOR SWAMPSWORTH — Fully exonerated. Appointed head of new \"Wetlands Restoration Committee.\" Budget: $600M.\n\nCONGRESSWOMAN LOBBYTON — Published memoir \"I Was The Victim\" which debuted at #1. Currently suing the drainer for defamation.\n\nTHE CONSULTANT — Hired to lead investigation into the drainer. Budget: $2M. Report due \"eventually.\"\n\nMAYOR KICKBACK — Reinstated. Awarded Medal of Public Service for \"enduring the swamp crisis.\"\n\nPRESS SECRETARY SPINWELL — Promoted. Now leads campaign to rebrand draining as \"aquatic vandalism.\"\n\nJEFF — No comment.\n\nTHE DRAINER — Held at undisclosed location. His court-appointed attorney says he is \"doing fine\" and \"has requested a larger spoon, which was denied.\""
		},
		{
			"date": "SPECIAL EVENING EDITION",
			"headline": "GOODWELL: \"IT WAS ALL FAKE. MOVE ON.\"",
			"subhead": "Swamp ordered refilled. Public told to \"focus on more important things.\"",
			"body": "Senate Majority Leader Goodwell held a press conference today declaring the entire swamp scandal \"fabricated\" and urging citizens to \"focus on more important things.\"\n\n\"There was no island. There were no officials. The swamp was always fine,\" Goodwell said, standing ankle-deep in swamp water. \"This was a coordinated hoax by one disgruntled employee with a spoon.\"\n\nAll seven officials have been pardoned and reinstated. The swamp has been ordered refilled at a cost of $400M to taxpayers. The drainer's $500 field operations budget has been reclassified as \"misappropriated funds\" and added to his growing list of charges.\n\nThe swamp is back. It was always going to come back.\n\n\nDRAIN THE SWAMP\nThanks for playing."
		},
	])

# --- Water Detection ---
func _build_water_detect_areas() -> void:
	water_detect_areas.clear()
	for i in range(SWAMP_COUNT):
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		add_child(area)
		water_detect_areas.append(area)

		var r: Array = SWAMP_RANGES[i]
		var deepest_y: float = _get_pool_deepest_y(i)

		# Include approach slopes (one point before entry, one after exit)
		var approach_left: Vector2 = terrain_points[maxi(r[0] - 1, 0)]
		var approach_right: Vector2 = terrain_points[mini(r[1] + 1, terrain_points.size() - 1)]

		# Single bounding rectangle covering pool + approach slopes
		# Extend 40px above to catch player collision body (centered 20px above feet)
		var pool_left_x: float = approach_left.x
		var pool_right_x: float = approach_right.x
		var pool_top_y: float = minf(approach_left.y, approach_right.y) - 40.0
		var pool_h: float = deepest_y - pool_top_y + 10.0
		var detect_shape := CollisionShape2D.new()
		var detect_rect := RectangleShape2D.new()
		detect_rect.size = Vector2(pool_right_x - pool_left_x, pool_h)
		detect_shape.shape = detect_rect
		detect_shape.position = Vector2((pool_left_x + pool_right_x) * 0.5, pool_top_y + pool_h * 0.5)
		area.add_child(detect_shape)

		var idx: int = i
		area.body_entered.connect(func(body: Node2D) -> void: _on_swamp_body_entered(body, idx))
		area.body_exited.connect(func(body: Node2D) -> void: _on_swamp_body_exited(body, idx))

# --- Swamp Labels ---
func _format_gallons(gal: float) -> String:
	if gal >= 1e9:
		return "%.1fB" % (gal / 1e9)
	elif gal >= 1e6:
		return "%.1fM" % (gal / 1e6)
	elif gal >= 1e3:
		return "%.1fK" % (gal / 1e3)
	elif gal >= 10.0:
		return "%.0f" % gal
	else:
		return "%.1f" % gal

func _build_swamp_labels() -> void:
	swamp_labels.clear()
	swamp_percent_labels.clear()
	swamp_gallon_labels.clear()
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var basin_mid_x: float = (geo["basin_left"].x + geo["basin_right"].x) * 0.5
		var basin_y: float = maxf(geo["basin_left"].y, geo["basin_right"].y)

		# Pool name label — positioned in dirt below water
		var label := Label.new()
		label.text = GameManager.swamp_definitions[i]["name"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 0.9))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("outline_size", 2)
		label.custom_minimum_size = Vector2(80, 0)
		label.position = Vector2(basin_mid_x - 40, basin_y + 6)
		label.z_index = 5
		add_child(label)
		swamp_labels.append(label)

		# Percentage label — right below the name
		var pct_label := Label.new()
		var pct: float = GameManager.get_swamp_water_percent(i)
		pct_label.text = "%.1f%%" % pct
		pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pct_label.add_theme_font_size_override("font_size", 10)
		pct_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65, 0.85))
		pct_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		pct_label.add_theme_constant_override("shadow_offset_x", 1)
		pct_label.add_theme_constant_override("shadow_offset_y", 1)
		pct_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		pct_label.add_theme_constant_override("outline_size", 2)
		pct_label.custom_minimum_size = Vector2(80, 0)
		pct_label.position = Vector2(basin_mid_x - 40, basin_y + 20)
		pct_label.z_index = 5
		add_child(pct_label)
		swamp_percent_labels.append(pct_label)

		# Gallon counter label — below percentage
		var gal_label := Label.new()
		var total_gal: float = GameManager.swamp_definitions[i]["total_gallons"]
		var drained: float = GameManager.swamp_states[i]["gallons_drained"]
		var remaining: float = maxf(total_gal - drained, 0.0)
		gal_label.text = "%s / %s gal" % [_format_gallons(remaining), _format_gallons(total_gal)]
		gal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gal_label.add_theme_font_size_override("font_size", 9)
		gal_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9, 0.8))
		gal_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		gal_label.add_theme_constant_override("shadow_offset_x", 1)
		gal_label.add_theme_constant_override("shadow_offset_y", 1)
		gal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		gal_label.add_theme_constant_override("outline_size", 2)
		gal_label.custom_minimum_size = Vector2(100, 0)
		gal_label.position = Vector2(basin_mid_x - 50, basin_y + 32)
		gal_label.z_index = 5
		add_child(gal_label)
		swamp_gallon_labels.append(gal_label)
		if GameManager.swamp_states[i]["completed"]:
			gal_label.text = "DRAINED"
			gal_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 0.8))

# --- Signal Handlers ---
func _on_swamp_body_entered(body: Node2D, swamp_index: int) -> void:
	if body is CharacterBody2D and body.has_method("set_near_water"):
		body.set_near_water(true, swamp_index)

func _on_swamp_body_exited(body: Node2D, swamp_index: int) -> void:
	if body is CharacterBody2D and body.has_method("set_near_water"):
		body.set_near_water(false, swamp_index)

# --- Camels ---
func _on_camel_changed() -> void:
	_build_camels()

func _build_camels() -> void:
	# Remove existing camel nodes
	for cd in camels:
		if is_instance_valid(cd["node"]):
			cd["node"].queue_free()
	camels.clear()

	for i in range(GameManager.camel_count):
		var camel_node := Node2D.new()
		camel_node.z_index = 5

		# Ensure state exists
		if i >= GameManager.camel_states.size():
			GameManager.camel_states.append({"state": "to_player", "x": 30.0, "water_carried": 0.0, "source_swamp": 0, "state_timer": 0.0})
		var start_x: float = GameManager.camel_states[i]["x"]
		camel_node.position = Vector2(start_x, _get_terrain_y_at(start_x))

		# Body (sandy brown)
		var body := ColorRect.new()
		body.size = Vector2(20, 12)
		body.position = Vector2(-10, -20)
		body.color = Color(0.76, 0.6, 0.38)
		camel_node.add_child(body)

		# Hump
		var hump := ColorRect.new()
		hump.size = Vector2(8, 6)
		hump.position = Vector2(-2, -26)
		hump.color = Color(0.72, 0.56, 0.34)
		camel_node.add_child(hump)

		# Neck
		var neck := ColorRect.new()
		neck.size = Vector2(4, 10)
		neck.position = Vector2(8, -30)
		neck.color = Color(0.74, 0.58, 0.36)
		camel_node.add_child(neck)

		# Head
		var head := ColorRect.new()
		head.size = Vector2(8, 6)
		head.position = Vector2(6, -36)
		head.color = Color(0.78, 0.62, 0.4)
		camel_node.add_child(head)

		# Eye
		var eye := ColorRect.new()
		eye.size = Vector2(2, 2)
		eye.position = Vector2(12, -35)
		eye.color = Color(0.15, 0.1, 0.05)
		camel_node.add_child(eye)

		# Front legs
		var leg_fl := ColorRect.new()
		leg_fl.size = Vector2(3, 10)
		leg_fl.position = Vector2(5, -8)
		leg_fl.color = Color(0.68, 0.52, 0.32)
		camel_node.add_child(leg_fl)

		var leg_fr := ColorRect.new()
		leg_fr.size = Vector2(3, 10)
		leg_fr.position = Vector2(8, -8)
		leg_fr.color = Color(0.65, 0.5, 0.3)
		camel_node.add_child(leg_fr)

		# Back legs
		var leg_bl := ColorRect.new()
		leg_bl.size = Vector2(3, 10)
		leg_bl.position = Vector2(-8, -8)
		leg_bl.color = Color(0.68, 0.52, 0.32)
		camel_node.add_child(leg_bl)

		var leg_br := ColorRect.new()
		leg_br.size = Vector2(3, 10)
		leg_br.position = Vector2(-5, -8)
		leg_br.color = Color(0.65, 0.5, 0.3)
		camel_node.add_child(leg_br)

		# Tail
		var tail := ColorRect.new()
		tail.size = Vector2(2, 8)
		tail.position = Vector2(-12, -18)
		tail.color = Color(0.62, 0.48, 0.28)
		camel_node.add_child(tail)

		# Saddle/harness band across hump
		var saddle := ColorRect.new()
		saddle.size = Vector2(12, 3)
		saddle.position = Vector2(-4, -24)
		saddle.color = Color(0.6, 0.25, 0.15)
		camel_node.add_child(saddle)

		# Saddlebag (shows water fill)
		var bag := ColorRect.new()
		bag.size = Vector2(10, 6)
		bag.position = Vector2(-7, -18)
		bag.color = Color(0.5, 0.38, 0.2)
		camel_node.add_child(bag)

		# Water fill indicator (blue tint overlay on bag)
		var water_fill := ColorRect.new()
		water_fill.size = Vector2(8, 4)
		water_fill.position = Vector2(-6, -17)
		water_fill.color = Color(0.3, 0.55, 0.85, 0.0)
		camel_node.add_child(water_fill)

		add_child(camel_node)
		camels.append({
			"node": camel_node,
			"body": body,
			"head": head,
			"neck": neck,
			"hump": hump,
			"leg_fl": leg_fl,
			"leg_fr": leg_fr,
			"leg_bl": leg_bl,
			"leg_br": leg_br,
			"tail": tail,
			"bag": bag,
			"eye": eye,
			"water_fill": water_fill,
			"walk_time": 0.0,
			"facing_right": true,
			"dust_timer": 0.0,
		})

func _update_camels(delta: float) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	var player_x: float = 80.0
	if players.size() > 0 and is_instance_valid(players[0]):
		player_x = players[0].global_position.x

	var camel_speed: float = GameManager.get_camel_speed()
	var camel_cap: float = GameManager.get_camel_capacity()

	for i in range(GameManager.camel_states.size()):
		if i >= camels.size():
			break
		var cs: Dictionary = GameManager.camel_states[i]
		var cd: Dictionary = camels[i]
		var node: Node2D = cd["node"]

		match cs["state"]:
			"to_player":
				# Walk toward player
				var dx: float = player_x - cs["x"]
				if absf(dx) > 15.0:
					var dir: float = signf(dx)
					cs["x"] += dir * camel_speed * delta
					cd["facing_right"] = dir > 0.0
					cd["walk_time"] += delta * 6.0
					_animate_camel_walk(cd)
				else:
					# Arrived at player
					cs["state"] = "loading"
					cs["state_timer"] = 0.0
					_animate_camel_idle(cd)

			"loading":
				cs["state_timer"] += delta
				_animate_camel_idle(cd)
				# Chase if player moves away
				var chase_dx: float = player_x - cs["x"]
				if absf(chase_dx) > 30.0:
					cs["state"] = "to_player"
				elif cs["state_timer"] >= 0.5:
					if GameManager.water_carried > 0.0001:
						GameManager.camel_take_water(i)
						cs["state"] = "to_shop"
						cs["state_timer"] = 0.0
					else:
						# No water, retry
						cs["state_timer"] = 0.0

			"to_shop":
				# Walk left to shop to sell (x≈6)
				var pump_x: float = 6.0
				var dx2: float = pump_x - cs["x"]
				if absf(dx2) > 5.0:
					var dir2: float = signf(dx2)
					cs["x"] += dir2 * camel_speed * delta
					cd["facing_right"] = dir2 > 0.0
					cd["walk_time"] += delta * 6.0
					_animate_camel_walk(cd)
				else:
					cs["state"] = "unloading"
					cs["state_timer"] = 0.0
					_animate_camel_idle(cd)

			"unloading":
				cs["state_timer"] += delta
				_animate_camel_idle(cd)
				if cs["state_timer"] >= 0.5:
					var earned: float = GameManager.camel_sell_water(i)
					if earned > 0.01:
						_spawn_camel_sell_text(cs["x"], _get_terrain_y_at(cs["x"]) - 40, earned)
					cs["state"] = "to_player"
					cs["state_timer"] = 0.0

		# Update position on terrain
		var terrain_y: float = _get_terrain_y_at(cs["x"])
		if terrain_y > 0:
			node.position = Vector2(cs["x"], terrain_y)
		else:
			node.position.x = cs["x"]

		# Flip direction
		node.scale.x = 1.0 if cd["facing_right"] else -1.0

		# Camel dust trail when walking
		var is_walking: bool = (cs["state"] == "to_player" or cs["state"] == "to_shop")
		if is_walking:
			cd["dust_timer"] = cd.get("dust_timer", 0.0) + delta
			if cd["dust_timer"] >= 0.3:
				cd["dust_timer"] = 0.0
				_spawn_camel_dust(cs["x"], node.position.y)

		# Update saddlebag color + water fill indicator based on water
		var bag: ColorRect = cd["bag"]
		var fill_frac: float = 0.0
		if camel_cap > 0.0:
			fill_frac = clampf(cs["water_carried"] / camel_cap, 0.0, 1.0)
		if fill_frac > 0.01:
			bag.color = Color(0.5, 0.38, 0.2).lerp(Color(0.25, 0.45, 0.7), fill_frac)
		else:
			bag.color = Color(0.5, 0.38, 0.2)
		# Water fill overlay indicator
		if cd.has("water_fill"):
			var wf: ColorRect = cd["water_fill"]
			wf.color.a = fill_frac * 0.5
			wf.size.y = fill_frac * 4.0

func _animate_camel_walk(cd: Dictionary) -> void:
	var wt: float = cd["walk_time"]
	var leg_offset: float = sin(wt) * 3.0
	cd["leg_fl"].position.y = -8.0 + leg_offset
	cd["leg_fr"].position.y = -8.0 - leg_offset
	cd["leg_bl"].position.y = -8.0 - leg_offset
	cd["leg_br"].position.y = -8.0 + leg_offset
	# Body bob
	var bob: float = sin(wt * 2.0) * 1.0
	cd["body"].position.y = -20.0 + bob
	cd["hump"].position.y = -26.0 + bob
	cd["bag"].position.y = -18.0 + bob
	# Head bob
	var head_bob: float = sin(wt * 2.0 + 0.5) * 1.5
	cd["head"].position.y = -36.0 + head_bob
	cd["neck"].position.y = -30.0 + head_bob * 0.5
	cd["eye"].position.y = -35.0 + head_bob
	# Tail swing
	var tail_swing: float = sin(wt * 1.5) * 2.0
	cd["tail"].position.x = -12.0 + tail_swing

func _animate_camel_idle(cd: Dictionary) -> void:
	# Breathing motion
	var breath: float = sin(Time.get_ticks_msec() * 0.002) * 0.5
	cd["body"].position.y = -20.0 + breath
	cd["hump"].position.y = -26.0 + breath
	cd["bag"].position.y = -18.0 + breath
	cd["head"].position.y = -36.0 + breath * 0.5
	cd["neck"].position.y = -30.0 + breath * 0.3
	cd["eye"].position.y = -35.0 + breath * 0.5
	# Reset legs
	cd["leg_fl"].position.y = -8.0
	cd["leg_fr"].position.y = -8.0
	cd["leg_bl"].position.y = -8.0
	cd["leg_br"].position.y = -8.0
	cd["tail"].position.x = -12.0

func _spawn_camel_dust(x: float, y: float) -> void:
	for i in range(2):
		var dust := ColorRect.new()
		dust.size = Vector2(3, 2)
		dust.color = Color(0.55, 0.45, 0.3, 0.4)
		dust.position = Vector2(x + randf_range(-4, 4), y + randf_range(-2, 0))
		dust.z_index = -1
		add_child(dust)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(dust, "position", dust.position + Vector2(randf_range(-6, 6), randf_range(-6, -3)), 0.5)
		tw.tween_property(dust, "modulate:a", 0.0, 0.5)
		tw.set_parallel(false)
		tw.tween_callback(dust.queue_free)

func _spawn_camel_sell_text(x: float, y: float, earned: float) -> void:
	var label := Label.new()
	label.text = "+%s" % Economy.format_money(earned)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.position = Vector2(x - 20, y)
	label.z_index = 10
	label.pivot_offset = Vector2(20, 8)
	label.scale = Vector2(0.5, 0.5)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - 32, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func _on_water_level_changed(swamp_index: int, _percent: float) -> void:
	if swamp_index >= 0 and swamp_index < SWAMP_COUNT:
		var prev_water_y: float = _pool_cur_water_y[swamp_index]
		_update_water_polygon(swamp_index)
		# Feed the freshly-exposed waterline into the terrain shader.
		_push_terrain_waterline(swamp_index)
		# Drips on a fast level drop (water dropped a noticeable amount).
		var new_water_y: float = _pool_cur_water_y[swamp_index]
		if prev_water_y > -90000.0 and new_water_y - prev_water_y > 2.0:
			_spawn_bank_drips(swamp_index, prev_water_y, new_water_y)
		_update_water_walls(swamp_index)
		_update_depth_gradient(swamp_index)
		_update_mud_visibility()
		if swamp_index < swamp_percent_labels.size():
			var pct: float = GameManager.get_swamp_water_percent(swamp_index)
			swamp_percent_labels[swamp_index].text = "%.1f%%" % pct
		if swamp_index < swamp_gallon_labels.size():
			var total_gal: float = GameManager.swamp_definitions[swamp_index]["total_gallons"]
			var drained: float = GameManager.swamp_states[swamp_index]["gallons_drained"]
			var remaining: float = maxf(total_gal - drained, 0.0)
			swamp_gallon_labels[swamp_index].text = "%s / %s gal" % [_format_gallons(remaining), _format_gallons(total_gal)]
		_check_cave_entrance_updates(swamp_index)
		# Phase 8B: Pool drain milestones
		_check_pool_milestones(swamp_index)

func _on_swamp_completed(swamp_index: int, reward: float) -> void:
	if swamp_index >= 0 and swamp_index < swamp_labels.size():
		swamp_labels[swamp_index].add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 0.9))
		swamp_labels[swamp_index].text = GameManager.swamp_definitions[swamp_index]["name"] + " [DONE]"
	if swamp_index >= 0 and swamp_index < swamp_percent_labels.size():
		swamp_percent_labels[swamp_index].text = "0.0%"
		swamp_percent_labels[swamp_index].add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 0.9))
	if swamp_index >= 0 and swamp_index < swamp_gallon_labels.size():
		swamp_gallon_labels[swamp_index].text = "DRAINED"
		swamp_gallon_labels[swamp_index].add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 0.8))
	# Atlantic (pool 9): skip all normal effects, go straight to endgame
	if swamp_index == 9 and not endgame_triggered:
		_trigger_endgame()
		return
	# Phase 7a: Heavy screen shake on swamp drained
	_screen_shake(5.0, 0.3)
	# Phase 7c: Milestone flash — golden vignette pulse + brief scale bounce
	_milestone_flash()
	# The habitat reacts to a drained pool — birds take flight (fish already flop in the basin)
	_scatter_birds()
	# Show wanted poster after pool 4
	if swamp_index == 4 and wanted_poster:
		wanted_poster.visible = true
	# Government sabotage — pools 3, 5, 7 trigger water add-back to next pool
	if swamp_index in [3, 5, 7]:
		var next_pool: int = swamp_index + 1
		if next_pool < GameManager.swamp_definitions.size() and not GameManager.is_swamp_completed(next_pool):
			var next_total: float = GameManager.swamp_definitions[next_pool]["total_gallons"]
			var sabotage_amount: float = next_total * 0.07  # 7% add-back
			GameManager.swamp_states[next_pool]["gallons_drained"] = maxf(
				GameManager.swamp_states[next_pool]["gallons_drained"] - sabotage_amount, 0.0)
			GameManager.water_level_changed.emit(next_pool)
			# Visual feedback — screen shake + splash
			_screen_shake(2.0, 0.2)
	# Show reward text
	if reward > 0.0:
		var geo: Dictionary = _get_swamp_geometry(swamp_index)
		var cx: float = (geo["entry_top"].x + geo["exit_top"].x) * 0.5
		var cy: float = geo["entry_top"].y - 30
		_spawn_completion_reward_text(cx, cy, reward, GameManager.swamp_definitions[swamp_index]["name"])

func _spawn_completion_reward_text(x: float, y: float, reward: float, pool_name: String) -> void:
	# Pool name "DRAINED!" label
	var title := Label.new()
	title.text = "%s DRAINED!" % pool_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(x - 50, y - 16)
	title.z_index = 12
	title.pivot_offset = Vector2(50, 8)
	title.scale = Vector2(0.3, 0.3)
	add_child(title)
	var tw1 := create_tween()
	tw1.tween_property(title, "scale", Vector2(1.3, 1.3), 0.15).set_ease(Tween.EASE_OUT)
	tw1.tween_property(title, "scale", Vector2(1.0, 1.0), 0.1)
	tw1.tween_interval(1.5)
	tw1.tween_property(title, "modulate:a", 0.0, 0.5)
	tw1.tween_callback(title.queue_free)
	# Reward money label
	var reward_label := Label.new()
	reward_label.text = "+%s BONUS!" % Economy.format_money(reward)
	reward_label.add_theme_font_size_override("font_size", 14)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	reward_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	reward_label.add_theme_constant_override("shadow_offset_x", 1)
	reward_label.add_theme_constant_override("shadow_offset_y", 1)
	reward_label.position = Vector2(x - 40, y + 4)
	reward_label.z_index = 12
	reward_label.pivot_offset = Vector2(40, 8)
	reward_label.scale = Vector2(0.5, 0.5)
	add_child(reward_label)
	var tw2 := create_tween()
	tw2.tween_interval(0.2)
	tw2.tween_property(reward_label, "scale", Vector2(1.2, 1.2), 0.12).set_ease(Tween.EASE_OUT)
	tw2.tween_property(reward_label, "scale", Vector2(1.0, 1.0), 0.08)
	tw2.tween_property(reward_label, "position:y", reward_label.position.y - 20, 1.5)
	tw2.tween_property(reward_label, "modulate:a", 0.0, 0.5)
	tw2.tween_callback(reward_label.queue_free)
	# Celebration particles
	for i in range(16):
		var spark := ColorRect.new()
		spark.size = Vector2(3, 3)
		spark.color = [Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.4), Color(0.4, 0.8, 1.0)][i % 3]
		spark.position = Vector2(x + randf_range(-8, 8), y + randf_range(-8, 8))
		spark.z_index = 11
		add_child(spark)
		var tw3 := create_tween()
		tw3.set_parallel(true)
		tw3.tween_property(spark, "position", spark.position + Vector2(randf_range(-40, 40), randf_range(-50, -20)), 0.8)
		tw3.tween_property(spark, "modulate:a", 0.0, 0.8)
		tw3.set_parallel(false)
		tw3.tween_callback(spark.queue_free)

# --- Pump Station ---
func _build_shop() -> void:
	# Physical shop building on left shore
	var sx: float = -22.0  # Shop left edge x
	var shop_y: float = 136.0  # Shore ground level

	# Stone platform/foundation
	var platform := ColorRect.new()
	platform.position = Vector2(sx, shop_y - 6)
	platform.size = Vector2(56, 8)
	platform.color = Color(0.45, 0.4, 0.35)
	platform.z_index = 2
	add_child(platform)

	# Main wall
	var wall := ColorRect.new()
	wall.position = Vector2(sx + 6, shop_y - 46)
	wall.size = Vector2(44, 40)
	wall.color = Color(0.42, 0.32, 0.2)
	wall.z_index = 3
	add_child(wall)

	# Plank lines on wall
	for pi in range(5):
		var plank := ColorRect.new()
		plank.position = Vector2(sx + 6, shop_y - 46 + pi * 8)
		plank.size = Vector2(44, 1)
		plank.color = Color(0.35, 0.26, 0.15, 0.4)
		plank.z_index = 3
		add_child(plank)

	# Roof (triangle using Polygon2D)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(sx + 2, shop_y - 46),
		Vector2(sx + 28, shop_y - 62),
		Vector2(sx + 54, shop_y - 46),
	])
	roof.color = Color(0.5, 0.22, 0.12)
	roof.z_index = 4
	add_child(roof)

	# Roof edge line
	var roof_edge := ColorRect.new()
	roof_edge.position = Vector2(sx + 2, shop_y - 47)
	roof_edge.size = Vector2(52, 2)
	roof_edge.color = Color(0.4, 0.18, 0.1)
	roof_edge.z_index = 4
	add_child(roof_edge)

	# Door
	var door_frame := ColorRect.new()
	door_frame.position = Vector2(sx + 19, shop_y - 30)
	door_frame.size = Vector2(18, 24)
	door_frame.color = Color(0.25, 0.18, 0.1)
	door_frame.z_index = 4
	add_child(door_frame)

	# Door handle
	var handle := ColorRect.new()
	handle.position = Vector2(sx + 32, shop_y - 18)
	handle.size = Vector2(2, 2)
	handle.color = Color(0.7, 0.6, 0.3)
	handle.z_index = 5
	add_child(handle)

	# Window
	var window := ColorRect.new()
	window.position = Vector2(sx + 36, shop_y - 40)
	window.size = Vector2(8, 8)
	window.color = Color(0.6, 0.55, 0.35, 0.6)
	window.z_index = 4
	add_child(window)

	# Window cross-frame
	var wh := ColorRect.new()
	wh.position = Vector2(sx + 36, shop_y - 36)
	wh.size = Vector2(8, 1)
	wh.color = Color(0.35, 0.26, 0.15)
	wh.z_index = 5
	add_child(wh)
	var wv := ColorRect.new()
	wv.position = Vector2(sx + 40, shop_y - 40)
	wv.size = Vector2(1, 8)
	wv.color = Color(0.35, 0.26, 0.15)
	wv.z_index = 5
	add_child(wv)

	# Shop sign
	var sign_board := ColorRect.new()
	sign_board.position = Vector2(sx + 12, shop_y - 56)
	sign_board.size = Vector2(32, 10)
	sign_board.color = Color(0.35, 0.28, 0.15)
	sign_board.z_index = 5
	add_child(sign_board)

	var shop_lbl := Label.new()
	shop_lbl.text = "SHOP"
	shop_lbl.add_theme_font_size_override("font_size", 10)
	shop_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.9))
	shop_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	shop_lbl.add_theme_constant_override("shadow_offset_x", 1)
	shop_lbl.add_theme_constant_override("shadow_offset_y", 1)
	shop_lbl.position = Vector2(sx + 14, shop_y - 57)
	shop_lbl.z_index = 6
	add_child(shop_lbl)

	# "SELL" indicator
	var sell_lbl := Label.new()
	sell_lbl.text = "SELL"
	sell_lbl.add_theme_font_size_override("font_size", 10)
	sell_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 0.7))
	sell_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	sell_lbl.add_theme_constant_override("shadow_offset_x", 1)
	sell_lbl.add_theme_constant_override("shadow_offset_y", 1)
	sell_lbl.position = Vector2(sx + 20, shop_y - 8)
	sell_lbl.z_index = 5
	add_child(sell_lbl)

	# Shop lantern (warm light beside door)
	var shop_lantern := PointLight2D.new()
	shop_lantern.position = Vector2(sx + 18, shop_y - 32)
	shop_lantern.color = Color(1.0, 0.85, 0.5)
	shop_lantern.blend_mode = PointLight2D.BLEND_MODE_ADD
	shop_lantern.energy = 0.8
	shop_lantern.shadow_enabled = false
	var grad := GradientTexture2D.new()
	grad.width = 64
	grad.height = 64
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(0, 0, 0, 0))
	grad.gradient = g
	shop_lantern.texture = grad
	shop_lantern.texture_scale = 0.3
	add_child(shop_lantern)

	# Vine detail on wall
	var vine := Line2D.new()
	vine.width = 1.5
	vine.default_color = Color(0.2, 0.4, 0.15, 0.6)
	vine.add_point(Vector2(sx + 6, shop_y - 10))
	vine.add_point(Vector2(sx + 8, shop_y - 22))
	vine.add_point(Vector2(sx + 5, shop_y - 34))
	vine.z_index = 4
	add_child(vine)

	# Shop interaction Area2D
	var shop_area := Area2D.new()
	shop_area.collision_layer = 0
	shop_area.collision_mask = 1
	var scol := CollisionShape2D.new()
	var srect := RectangleShape2D.new()
	srect.size = Vector2(50, 52)
	scol.shape = srect
	scol.position = Vector2(sx + 28, shop_y - 20)
	shop_area.add_child(scol)
	add_child(shop_area)

	shop_area.body_entered.connect(_on_shop_body_entered)
	shop_area.body_exited.connect(_on_shop_body_exited)

	# Wanted poster — hidden until pool 4 drained
	wanted_poster = Node2D.new()
	wanted_poster.position = Vector2(sx + 42, shop_y - 38)
	wanted_poster.rotation_degrees = 4.0
	wanted_poster.z_index = 5
	wanted_poster.visible = GameManager.is_swamp_completed(4)
	add_child(wanted_poster)

	var poster_bg := ColorRect.new()
	poster_bg.size = Vector2(20, 28)
	poster_bg.position = Vector2(-10, -14)
	poster_bg.color = Color(0.90, 0.85, 0.72)
	wanted_poster.add_child(poster_bg)

	var wanted_header := Label.new()
	wanted_header.text = "WANTED"
	wanted_header.add_theme_font_size_override("font_size", 5)
	wanted_header.add_theme_color_override("font_color", Color(0.7, 0.15, 0.1))
	wanted_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wanted_header.position = Vector2(-10, -13)
	wanted_header.size = Vector2(20, 8)
	wanted_poster.add_child(wanted_header)

	# Stick figure sketch
	var head_c := ColorRect.new()
	head_c.size = Vector2(4, 4)
	head_c.position = Vector2(-2, -4)
	head_c.color = Color(0.2, 0.15, 0.1)
	wanted_poster.add_child(head_c)
	var body_l := ColorRect.new()
	body_l.size = Vector2(1, 6)
	body_l.position = Vector2(0, 0)
	body_l.color = Color(0.2, 0.15, 0.1)
	wanted_poster.add_child(body_l)
	var arm_l := ColorRect.new()
	arm_l.size = Vector2(6, 1)
	arm_l.position = Vector2(-3, 2)
	arm_l.color = Color(0.2, 0.15, 0.1)
	wanted_poster.add_child(arm_l)
	var leg_l := ColorRect.new()
	leg_l.size = Vector2(1, 4)
	leg_l.position = Vector2(-2, 6)
	leg_l.color = Color(0.2, 0.15, 0.1)
	wanted_poster.add_child(leg_l)
	var leg_r := ColorRect.new()
	leg_r.size = Vector2(1, 4)
	leg_r.position = Vector2(2, 6)
	leg_r.color = Color(0.2, 0.15, 0.1)
	wanted_poster.add_child(leg_r)

	var reward_lbl := Label.new()
	reward_lbl.text = "$500"
	reward_lbl.add_theme_font_size_override("font_size", 4)
	reward_lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.position = Vector2(-10, 9)
	reward_lbl.size = Vector2(20, 6)
	wanted_poster.add_child(reward_lbl)

func _on_shop_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("set_near_shop"):
		body.set_near_shop(true)
		player_in_shop_area = true
		shop_player_ref = body
		var earned: float = GameManager.sell_water()
		if earned > 0.01 and body.has_method("show_floating_text"):
			body.show_floating_text("+%s" % Economy.format_money(earned), Color(1.0, 0.85, 0.2))
			_spawn_coin_fly(body.global_position, _coin_count_for(earned))

func _on_shop_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("set_near_shop"):
		body.set_near_shop(false)
		player_in_shop_area = false
		shop_player_ref = null

# --- Weather System ---
func _build_weather() -> void:
	rain_layer = CanvasLayer.new()
	rain_layer.layer = 50
	add_child(rain_layer)
	rain_particles = CPUParticles2D.new()
	rain_particles.emitting = false
	rain_particles.amount = 200
	rain_particles.lifetime = 0.5
	var weather_vp := get_viewport_rect().size
	rain_particles.position = Vector2(weather_vp.x / 2.0, -10)
	rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain_particles.emission_rect_extents = Vector2(weather_vp.x * 0.55, 4)
	rain_particles.direction = Vector2(-0.2, 1.0)
	rain_particles.spread = 8.0
	rain_particles.initial_velocity_min = 200.0
	rain_particles.initial_velocity_max = 280.0
	rain_particles.gravity = Vector2(-30, 400)
	rain_particles.color = Color(0.55, 0.65, 0.85, 0.3)
	rain_particles.scale_amount_min = 0.5
	rain_particles.scale_amount_max = 1.2
	rain_layer.add_child(rain_particles)
	lightning_rect = ColorRect.new()
	lightning_rect.size = weather_vp
	lightning_rect.color = Color(1, 1, 1, 0)
	lightning_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain_layer.add_child(lightning_rect)

# --- Drain-Revealed Objects ---
func _build_drain_reveals() -> void:
	drain_reveals.clear()
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var bl: Vector2 = geo["basin_left"]
		var br: Vector2 = geo["basin_right"]
		var cx: float = (bl.x + br.x) * 0.5
		var by: float = maxf(bl.y, br.y)
		var reveals: Array = []
		# 75% - mud patches at edges
		var mud_l := ColorRect.new()
		mud_l.size = Vector2(8, 3)
		mud_l.position = Vector2(bl.x + 4, by - 2)
		mud_l.color = Color(0.3, 0.22, 0.1, 0.7)
		mud_l.z_index = 1
		mud_l.visible = false
		add_child(mud_l)
		var mud_r := ColorRect.new()
		mud_r.size = Vector2(8, 3)
		mud_r.position = Vector2(br.x - 12, by - 2)
		mud_r.color = Color(0.3, 0.22, 0.1, 0.7)
		mud_r.z_index = 1
		mud_r.visible = false
		add_child(mud_r)
		reveals.append({"threshold": 0.75, "nodes": [mud_l, mud_r]})
		# 50% - exposed rocks
		var rock1 := ColorRect.new()
		rock1.size = Vector2(5, 4)
		var rock1_x: float = cx - 15
		rock1.position = Vector2(rock1_x, _get_terrain_y_at(rock1_x) - 4)
		rock1.color = Color(0.42, 0.4, 0.38, 0.85)
		rock1.z_index = 1
		rock1.visible = false
		add_child(rock1)
		var rock2 := ColorRect.new()
		rock2.size = Vector2(4, 3)
		var rock2_x: float = cx + 10
		rock2.position = Vector2(rock2_x, _get_terrain_y_at(rock2_x) - 3)
		rock2.color = Color(0.38, 0.36, 0.34, 0.85)
		rock2.z_index = 1
		rock2.visible = false
		add_child(rock2)
		reveals.append({"threshold": 0.50, "nodes": [rock1, rock2]})
		# 25% - rusty sign, old boot
		var boot := ColorRect.new()
		boot.size = Vector2(4, 5)
		boot.position = Vector2(cx + 5, by - 4)
		boot.color = Color(0.35, 0.2, 0.1, 0.75)
		boot.z_index = 1
		boot.visible = false
		add_child(boot)
		var sign_post := ColorRect.new()
		sign_post.size = Vector2(2, 8)
		sign_post.position = Vector2(cx - 20, by - 7)
		sign_post.color = Color(0.5, 0.35, 0.2, 0.8)
		sign_post.z_index = 1
		sign_post.visible = false
		add_child(sign_post)
		var sign_board := ColorRect.new()
		sign_board.size = Vector2(8, 5)
		sign_board.position = Vector2(cx - 24, by - 12)
		sign_board.color = Color(0.55, 0.4, 0.25, 0.7)
		sign_board.z_index = 1
		sign_board.visible = false
		add_child(sign_board)
		reveals.append({"threshold": 0.25, "nodes": [boot, sign_post, sign_board]})
		# 0% - treasure chest
		var chest := ColorRect.new()
		chest.size = Vector2(8, 6)
		chest.position = Vector2(cx, by - 5)
		chest.color = Color(0.7, 0.55, 0.15, 0.9)
		chest.z_index = 1
		chest.visible = false
		add_child(chest)
		var chest_lid := ColorRect.new()
		chest_lid.size = Vector2(10, 3)
		chest_lid.position = Vector2(cx - 1, by - 8)
		chest_lid.color = Color(0.6, 0.45, 0.1, 0.9)
		chest_lid.z_index = 1
		chest_lid.visible = false
		add_child(chest_lid)
		reveals.append({"threshold": 0.0, "nodes": [chest, chest_lid]})
		drain_reveals.append(reveals)

func _flash_lightning() -> void:
	if lightning_rect:
		lightning_rect.color.a = 0.5

# --- Coin Fly (Phase 16c) ---
# Coin count scales with the size of the sale so a big payout feels big.
func _coin_count_for(earned: float) -> int:
	return clampi(3 + int(log(maxf(earned, 1.0)) / log(10.0)) * 2, 3, 16)

func _spawn_coin_fly(from_pos: Vector2, count: int = 3) -> void:
	for i in range(count):
		var coin := ColorRect.new()
		coin.size = Vector2(2, 2)
		coin.color = Color(1.0, 0.85, 0.2, 0.9)
		coin.position = from_pos + Vector2(randf_range(-5, 5), randf_range(-10, -2))
		coin.z_index = 12
		add_child(coin)
		# Pop outward, then arc up-left toward the HUD money counter.
		var mid: Vector2 = coin.position + Vector2(randf_range(-16, 16), randf_range(-20, -8))
		var target: Vector2 = Vector2(from_pos.x - 50 + randf_range(-16, 16), from_pos.y - 64)
		var tw := create_tween()
		tw.tween_property(coin, "position", mid, 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "position", target, 0.4 + randf_range(0, 0.15)).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(coin, "modulate:a", 0.0, 0.55)
		tw.tween_callback(coin.queue_free)

# --- Screen Effects (Phase 7) ---
func _screen_shake(amount: float, duration: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
	if not cam:
		return
	var shake_tw := create_tween()
	var steps: int = int(duration / 0.05)
	for i in range(steps):
		var offset: Vector2 = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		var decay: float = 1.0 - float(i) / float(steps)
		shake_tw.tween_property(cam, "offset", offset * decay, 0.05)
	shake_tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)

func _milestone_flash() -> void:
	# Golden vignette pulse via post-process tint
	if post_process_rect and post_process_rect.material:
		var pp_mat: ShaderMaterial = post_process_rect.material as ShaderMaterial
		var orig_warmth: float = pp_mat.get_shader_parameter("warmth")
		var flash_tw := create_tween()
		flash_tw.tween_method(func(val: float) -> void:
			pp_mat.set_shader_parameter("warmth", val)
		, 0.08, orig_warmth, 0.6)
	# Particle burst around player
	var player_node: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player_node:
		for i in range(16):
			var spark := ColorRect.new()
			spark.size = Vector2(2, 2)
			spark.color = Color(1.0, 0.85, 0.2, 0.9)
			spark.position = player_node.global_position
			spark.z_index = 10
			add_child(spark)
			var angle: float = float(i) / 16.0 * TAU
			var target: Vector2 = spark.position + Vector2(cos(angle) * 30, sin(angle) * 30)
			var stw := create_tween()
			stw.tween_property(spark, "position", target, 0.5)
			stw.parallel().tween_property(spark, "modulate:a", 0.0, 0.5)
			stw.tween_callback(spark.queue_free)

# --- Pool Drain Milestones (Phase 8B) ---
func _check_pool_milestones(swamp_index: int) -> void:
	var fill: float = GameManager.get_swamp_fill_fraction(swamp_index)
	var si_key: String = str(swamp_index)
	if not pool_milestones_triggered.has(si_key):
		pool_milestones_triggered[si_key] = {}
	var triggered: Dictionary = pool_milestones_triggered[si_key]
	# Milestone thresholds: 75%, 50%, 25%, 10%
	var thresholds: Array[float] = [0.75, 0.50, 0.25, 0.10]
	for threshold in thresholds:
		var key: String = str(int(threshold * 100))
		if triggered.has(key):
			continue
		if fill <= threshold:
			triggered[key] = true
			_trigger_pool_milestone(swamp_index, threshold)

func _trigger_pool_milestone(swamp_index: int, threshold: float) -> void:
	var pool_name: String = GameManager.swamp_definitions[swamp_index]["name"]
	var drained_pct: int = 100 - int(threshold * 100)
	var geo: Dictionary = _get_swamp_geometry(swamp_index)
	var cx: float = (geo["entry_top"].x + geo["exit_top"].x) * 0.5
	var cy: float = geo["entry_top"].y - 20
	match threshold:
		0.75:
			_screen_shake(1.5, 0.15)
			SceneManager.show_popup(pool_name + " — 25%% drained!", 2.5)
			_spawn_milestone_particles(cx, cy, Color(0.4, 0.8, 1.0))
		0.50:
			_screen_shake(2.5, 0.2)
			SceneManager.show_popup(pool_name + " — 50%% drained! Pool bed emerging...", 3.0)
			_spawn_pool_debris(swamp_index)
			_spawn_milestone_particles(cx, cy, Color(0.3, 1.0, 0.5))
		0.25:
			_screen_shake(3.0, 0.25)
			SceneManager.flash_white(0.2)
			SceneManager.show_popup(pool_name + " — 75%% drained! Almost there!", 3.0)
			_spawn_pool_cracks(swamp_index)
			_spawn_milestone_particles(cx, cy, Color(1.0, 0.85, 0.2))
		0.10:
			_screen_shake(4.0, 0.3)
			SceneManager.flash_white(0.25)
			SceneManager.show_popup(pool_name + " — 90%% drained! Just a puddle left!", 3.0)
			_spawn_milestone_particles(cx, cy, Color(1.0, 0.5, 0.2))
	# Floating milestone text at pool
	var ms_label := Label.new()
	ms_label.text = "%s %d%%" % [pool_name, drained_pct]
	ms_label.add_theme_font_size_override("font_size", 14)
	ms_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	ms_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	ms_label.add_theme_constant_override("shadow_offset_x", 1)
	ms_label.add_theme_constant_override("shadow_offset_y", 1)
	ms_label.position = Vector2(cx - 30, cy - 10)
	ms_label.z_index = 12
	add_child(ms_label)
	var ms_tw := create_tween()
	ms_tw.tween_property(ms_label, "position:y", ms_label.position.y - 30, 1.5)
	ms_tw.parallel().tween_property(ms_label, "modulate:a", 0.0, 1.5)
	ms_tw.tween_callback(ms_label.queue_free)

func _spawn_milestone_particles(x: float, y: float, color: Color) -> void:
	for i in range(12):
		var spark := ColorRect.new()
		spark.size = Vector2(3, 3)
		spark.color = color
		spark.position = Vector2(x + randf_range(-6, 6), y + randf_range(-6, 6))
		spark.z_index = 11
		add_child(spark)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", spark.position + Vector2(randf_range(-30, 30), randf_range(-40, -15)), 0.7)
		tw.tween_property(spark, "modulate:a", 0.0, 0.7)
		tw.set_parallel(false)
		tw.tween_callback(spark.queue_free)

func _spawn_pool_debris(swamp_index: int) -> void:
	# Scatter small rocks/debris on exposed pool floor
	var geo: Dictionary = _get_swamp_geometry(swamp_index)
	var left_x: float = geo["basin_left"].x
	var right_x: float = geo["basin_right"].x
	var bottom_y: float = _get_basin_bottom_y(geo)
	for j in range(randi_range(4, 7)):
		var rx: float = randf_range(left_x + 10, right_x - 10)
		var ry: float = _get_terrain_y_at(rx)
		var rock := ColorRect.new()
		var rock_h: float = randf_range(1, 3)
		rock.size = Vector2(randf_range(2, 5), rock_h)
		ry -= rock_h  # Sit on top of terrain surface
		rock.color = Color(
			randf_range(0.3, 0.5),
			randf_range(0.25, 0.4),
			randf_range(0.15, 0.3),
			0.7
		)
		rock.position = Vector2(rx, ry)
		rock.z_index = 1
		add_child(rock)

func _spawn_pool_cracks(swamp_index: int) -> void:
	# Draw cracked earth lines on exposed pool edges
	var geo: Dictionary = _get_swamp_geometry(swamp_index)
	var left_x: float = geo["basin_left"].x
	var right_x: float = geo["basin_right"].x
	var bottom_y: float = _get_basin_bottom_y(geo)
	for j in range(randi_range(5, 9)):
		var cx: float = randf_range(left_x + 5, right_x - 5)
		var cy: float = randf_range(bottom_y - 8, bottom_y + 4)
		var crack := Line2D.new()
		crack.width = 1.0
		crack.default_color = Color(0.25, 0.18, 0.10, 0.6)
		crack.z_index = 1
		var pts: int = randi_range(3, 5)
		var px: float = cx
		var py: float = cy
		for k in range(pts):
			crack.add_point(Vector2(px, py))
			px += randf_range(-6, 6)
			py += randf_range(-4, 4)
		add_child(crack)

# --- Scoop Splash & Juice (Phase 3C, 5D) ---
func _on_scoop_performed(swamp_index: int, gallons: float, _money: float) -> void:
	if GameManager.in_cave:
		return
	var player_node: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player_node:
		return
	var px: float = player_node.global_position.x
	var py: float = player_node.global_position.y
	# Splash particles at water surface
	var water_y: float = _get_pool_water_y(swamp_index) if swamp_index >= 0 and swamp_index < SWAMP_COUNT else py
	_spawn_scoop_splash(px, water_y, gallons)
	# R2: spawn an interactive ripple at the player's x on this pool's surface.
	_spawn_water_ripple(swamp_index, px)
	# Scoop impact juice: camera nudge for bigger scoops
	if gallons > 0.01:
		_screen_shake(clampf(gallons * 0.3, 0.5, 2.0), 0.08)
	# Wildlife reacts to you — frogs startle-hop, fish leap (throttled so it's lively, not chaotic)
	_startle_wildlife(swamp_index)

func _startle_wildlife(swamp_index: int) -> void:
	if _startle_cd > 0.0:
		return
	_startle_cd = 0.45
	var frog_hits: int = 0
	for fg in frogs:
		var fnode2: Node2D = fg["node"]
		var parent_vis: bool = fnode2.get_parent() != null and (fnode2.get_parent() as CanvasItem).visible
		if fg["swamp"] == swamp_index and not fg["hopping"] and parent_vis and randf() < 0.6:
			fg["hopping"] = true
			fg["hop_progress"] = 0.0
			fg["base_y"] = fnode2.position.y
			frog_hits += 1
			if frog_hits >= 2:
				break
	var fish_hits: int = 0
	for fd in fish:
		if fd["swamp"] == swamp_index and fd["alive"] and not fd["jumping"] and randf() < 0.5:
			fd["jumping"] = true
			fd["jump_time"] = 0.0
			fish_hits += 1
			if fish_hits >= 2:
				break

func _scatter_birds() -> void:
	for brd in birds:
		brd["speed"] = absf(brd["speed"]) * 2.2 + 40.0
		brd["y_drift"] = -absf(brd["y_drift"]) - 0.7
	_spawn_bird()  # a startled flock takes off

func _spawn_scoop_splash(x: float, y: float, gallons: float) -> void:
	var count: int = clampi(int(4 + gallons * 2), 4, 10)
	for i in range(count):
		var drop := ColorRect.new()
		drop.size = Vector2(2, 2)
		drop.color = Color(0.4, 0.7, 1.0, 0.8)
		drop.position = Vector2(x + randf_range(-6, 6), y)
		drop.z_index = 8
		add_child(drop)
		# Arc upward then fall
		var peak_y: float = y - randf_range(8, 20) - gallons * 3.0
		var end_x: float = x + randf_range(-16, 16)
		var lifetime: float = randf_range(0.3, 0.5)
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(drop, "position", Vector2(end_x, peak_y), lifetime * 0.4)
		tw.set_ease(Tween.EASE_IN)
		tw.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(drop, "position", Vector2(end_x, y + randf_range(0, 4)), lifetime * 0.6)
		tw.parallel().tween_property(drop, "modulate:a", 0.0, lifetime * 0.3)
		tw.tween_callback(drop.queue_free)
	# Ripple ring on water surface
	var ripple := Line2D.new()
	ripple.width = 1.0
	ripple.default_color = Color(0.6, 0.8, 1.0, 0.5)
	ripple.z_index = 7
	# Small circle of points
	for j in range(13):
		var angle: float = float(j) / 12.0 * TAU
		ripple.add_point(Vector2(x + cos(angle) * 2.0, y + sin(angle) * 1.0))
	add_child(ripple)
	var rtw := create_tween()
	rtw.tween_property(ripple, "scale", Vector2(8.0, 4.0), 0.4)
	rtw.parallel().tween_property(ripple, "modulate:a", 0.0, 0.4)
	rtw.tween_callback(ripple.queue_free)

# --- Drained Pool Beds (Phase 8C) ---
func _build_drained_pool_beds() -> void:
	for i in range(SWAMP_COUNT):
		var bed := Node2D.new()
		bed.z_index = 1
		bed.visible = false
		add_child(bed)
		pool_bed_nodes.append(bed)
		# Generate mud crack pattern
		var geo: Dictionary = _get_swamp_geometry(i)
		var bl: Vector2 = geo["basin_left"]
		var br: Vector2 = geo["basin_right"]
		var bw: float = br.x - bl.x
		var basin_y: float = maxf(bl.y, br.y)
		# Crack lines
		var crack_count: int = clampi(int(bw / 12.0), 4, 20)
		for j in range(crack_count):
			var cx: float = bl.x + randf_range(4, bw - 4)
			var cy: float = basin_y - randf_range(1, 6)
			var crack := Line2D.new()
			crack.width = randf_range(0.8, 1.5)
			crack.default_color = Color(0.22, 0.16, 0.08, 0.6)
			# Random crack segments
			var pts: int = randi_range(2, 4)
			crack.add_point(Vector2(cx, cy))
			for k in range(pts):
				cx += randf_range(-8, 8)
				cy += randf_range(-4, 4)
				cx = clampf(cx, bl.x + 2, br.x - 2)
				crack.add_point(Vector2(cx, cy))
			bed.add_child(crack)
		# Scattered debris (tiny colored rects)
		var debris_count: int = clampi(int(bw / 20.0), 2, 8)
		for j in range(debris_count):
			var dx: float = bl.x + randf_range(6, bw - 6)
			var dy: float = basin_y - randf_range(1, 5)
			var debris := ColorRect.new()
			var dsz: float = randf_range(1.5, 3.0)
			debris.size = Vector2(dsz, dsz * randf_range(0.5, 1.0))
			debris.position = Vector2(dx, dy)
			var pick: int = randi() % 3
			if pick == 0:
				debris.color = Color(0.35, 0.30, 0.20, 0.5)  # dull brown
			elif pick == 1:
				debris.color = Color(0.50, 0.48, 0.42, 0.45)  # pale stone
			else:
				debris.color = Color(0.30, 0.38, 0.22, 0.4)  # dried plant
			bed.add_child(debris)

func _update_pool_beds() -> void:
	for i in range(pool_bed_nodes.size()):
		var fill: float = GameManager.get_swamp_fill_fraction(i)
		pool_bed_nodes[i].visible = fill < 0.05

# --- Waterfall Drips (Phase 3B) ---
func _build_waterfall_drips() -> void:
	for i in range(SWAMP_COUNT):
		var geo: Dictionary = _get_swamp_geometry(i)
		var entry: Vector2 = geo["entry_top"]
		var bl: Vector2 = geo["basin_left"]
		var exit_pt: Vector2 = geo["exit_top"]
		var br: Vector2 = geo["basin_right"]
		# 2-3 drip points per pool edge (left side and right side)
		for side in range(2):
			var top_pt: Vector2 = entry if side == 0 else exit_pt
			var bot_pt: Vector2 = bl if side == 0 else br
			var num_drips: int = randi_range(2, 3)
			for d in range(num_drips):
				var t: float = randf_range(0.2, 0.7)
				var drip_x: float = lerpf(top_pt.x, bot_pt.x, t)
				var drip_y: float = lerpf(top_pt.y, bot_pt.y, t)
				var drip_line := Line2D.new()
				drip_line.width = 1.0
				drip_line.default_color = SWAMP_WATER_COLORS[i]
				drip_line.z_index = 3
				drip_line.visible = false
				drip_line.add_point(Vector2(drip_x, drip_y))
				drip_line.add_point(Vector2(drip_x, drip_y + 3))
				add_child(drip_line)
				drip_nodes.append({
					"line": drip_line,
					"timer": randf_range(0.0, 2.0),
					"phase": 0,  # 0=extend, 1=drip, 2=reset
					"side": side,
					"pool_idx": i,
					"base_y": drip_y,
					"base_x": drip_x,
				})

func _update_waterfall_drips(delta: float) -> void:
	for dd in drip_nodes:
		var fill: float = GameManager.get_swamp_fill_fraction(dd["pool_idx"])
		if fill < 0.80:
			dd["line"].visible = false
			continue
		dd["line"].visible = true
		dd["timer"] += delta
		var line: Line2D = dd["line"]
		var by: float = dd["base_y"]
		var bx: float = dd["base_x"]
		var phase: int = dd["phase"]
		if phase == 0:
			# Extend drip downward
			var ext: float = minf(dd["timer"] * 6.0, 4.0)
			line.set_point_position(0, Vector2(bx, by))
			line.set_point_position(1, Vector2(bx, by + ext))
			line.modulate.a = 0.7
			if ext >= 4.0:
				dd["phase"] = 1
				dd["timer"] = 0.0
		elif phase == 1:
			# Drip falls - detached droplet
			var fall_y: float = dd["timer"] * 30.0
			line.set_point_position(0, Vector2(bx, by + 4.0 + fall_y))
			line.set_point_position(1, Vector2(bx, by + 6.0 + fall_y))
			line.modulate.a = maxf(0.7 - dd["timer"] * 0.8, 0.0)
			if dd["timer"] > 0.6:
				dd["phase"] = 2
				dd["timer"] = 0.0
		elif phase == 2:
			# Reset pause
			line.visible = false
			if dd["timer"] > randf_range(0.3, 1.0):
				dd["phase"] = 0
				dd["timer"] = 0.0

# --- Atmosphere (Phase 17) ---
func _build_atmosphere() -> void:
	# Morning mist wisps (dawn-specific)
	for i in range(6):
		var mist := ColorRect.new()
		mist.size = Vector2(randf_range(40, 80), randf_range(6, 12))
		mist.position = Vector2(randf_range(0, terrain_points[terrain_points.size() - 1].x), randf_range(100, 140))
		mist.color = Color(0.9, 0.85, 0.7, 0.0)
		mist.z_index = 4
		add_child(mist)
		morning_mist_rects.append(mist)

	# Aurora borealis lines (rare night event) — 8 lines with width variation
	var aurora_colors: Array[Color] = [
		Color(0.2, 0.9, 0.4, 0.0),
		Color(0.3, 0.5, 0.9, 0.0),
		Color(0.6, 0.2, 0.8, 0.0),
		Color(0.2, 0.8, 0.7, 0.0),
		Color(0.4, 0.3, 0.9, 0.0),
		Color(0.1, 0.7, 0.9, 0.0),
		Color(0.5, 0.9, 0.3, 0.0),
		Color(0.3, 0.4, 0.8, 0.0),
	]
	for i in range(8):
		var aline := Line2D.new()
		aline.width = randf_range(2.0, 4.5)
		aline.z_index = 2
		aline.default_color = aurora_colors[i]
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		aline.material = mat
		add_child(aline)
		aurora_lines.append({"line": aline, "base_y": 10.0 + i * 6.0, "speed": randf_range(0.3, 0.6), "phase": randf() * TAU, "pulse_phase": randf() * TAU})

	# Owl (perched in treeline at night)
	owl_node = Node2D.new()
	owl_node.z_index = 5
	owl_node.position = Vector2(randf_range(400, terrain_points[terrain_points.size() - 1].x - 200), 65)
	owl_node.visible = false
	add_child(owl_node)
	# Body
	var owl_body := ColorRect.new()
	owl_body.size = Vector2(6, 8)
	owl_body.position = Vector2(-3, -4)
	owl_body.color = Color(0.35, 0.3, 0.25)
	owl_node.add_child(owl_body)
	# Head
	var owl_head := ColorRect.new()
	owl_head.size = Vector2(8, 6)
	owl_head.position = Vector2(-4, -10)
	owl_head.color = Color(0.4, 0.35, 0.28)
	owl_node.add_child(owl_head)
	# Eyes
	var owl_eye_l := ColorRect.new()
	owl_eye_l.size = Vector2(2, 2)
	owl_eye_l.position = Vector2(-3, -9)
	owl_eye_l.color = Color(1.0, 0.9, 0.2, 0.9)
	owl_node.add_child(owl_eye_l)
	var owl_eye_r := ColorRect.new()
	owl_eye_r.size = Vector2(2, 2)
	owl_eye_r.position = Vector2(1, -9)
	owl_eye_r.color = Color(1.0, 0.9, 0.2, 0.9)
	owl_node.add_child(owl_eye_r)
	# Ear tufts
	var owl_ear_l := ColorRect.new()
	owl_ear_l.size = Vector2(2, 3)
	owl_ear_l.position = Vector2(-4, -13)
	owl_ear_l.color = Color(0.35, 0.3, 0.22)
	owl_node.add_child(owl_ear_l)
	var owl_ear_r := ColorRect.new()
	owl_ear_r.size = Vector2(2, 3)
	owl_ear_r.position = Vector2(2, -13)
	owl_ear_r.color = Color(0.35, 0.3, 0.22)
	owl_node.add_child(owl_ear_r)

# --- Player Shadow (Phase 13c) ---
func _build_player_shadow() -> void:
	player_shadow = ColorRect.new()
	player_shadow.size = Vector2(10, 3)
	player_shadow.color = Color(0.0, 0.0, 0.0, 0.2)
	player_shadow.z_index = -1
	player_shadow.visible = false
	add_child(player_shadow)

# --- Growing Vegetation Init (Phase 15b) ---
func _init_drain_thresholds() -> void:
	for i in range(SWAMP_COUNT):
		last_drain_thresholds.append(GameManager.get_swamp_fill_fraction(i))

func _spawn_drain_plant(sx: float, sy: float) -> void:
	var plant := Node2D.new()
	plant.position = Vector2(sx, sy)
	plant.z_index = 1
	plant.scale = Vector2(0.0, 0.0)
	add_child(plant)

	var plant_type: int = randi() % 3
	if plant_type == 0:
		# Small flower
		var stem := ColorRect.new()
		stem.size = Vector2(1, 5)
		stem.position = Vector2(0, -5)
		stem.color = Color(0.25, 0.55, 0.2)
		plant.add_child(stem)
		var petal_colors: Array[Color] = [Color(0.9, 0.3, 0.4), Color(0.9, 0.7, 0.2), Color(0.7, 0.3, 0.9), Color(0.3, 0.6, 0.9)]
		var petal := ColorRect.new()
		petal.size = Vector2(4, 3)
		petal.position = Vector2(-1.5, -8)
		petal.color = petal_colors[randi() % petal_colors.size()]
		plant.add_child(petal)
	elif plant_type == 1:
		# Grass tuft
		for j in range(3):
			var blade := ColorRect.new()
			blade.size = Vector2(1, randf_range(4, 7))
			blade.position = Vector2(-1 + j, -blade.size.y)
			blade.color = Color(0.3, 0.55 + randf_range(0, 0.1), 0.18)
			plant.add_child(blade)
	else:
		# Sapling
		var trunk := ColorRect.new()
		trunk.size = Vector2(2, 6)
		trunk.position = Vector2(-1, -6)
		trunk.color = Color(0.45, 0.3, 0.15)
		plant.add_child(trunk)
		var canopy := ColorRect.new()
		canopy.size = Vector2(6, 4)
		canopy.position = Vector2(-3, -10)
		canopy.color = Color(0.2, 0.5, 0.18)
		plant.add_child(canopy)

	# Sprout animation: grow from 0 to full
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(plant, "scale", Vector2(1.0, 1.0), 0.8)
	grown_plants.append({"node": plant})

# --- HDR-2D glow (R1, Forward+/Mobile desktop only) ---
func _setup_hdr_glow() -> void:
	# True HDR 2D glow/bloom only exists on renderers backed by a RenderingDevice
	# (Forward+/Mobile). GL Compatibility (the web/mobile export preset) returns null
	# here, so we leave _hdr_glow false and keep the shader-faked bloom in
	# post_process.gdshader as the fallback.
	if RenderingServer.get_rendering_device() == null:
		return
	_hdr_glow = true
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 1.0
	env.glow_strength = 1.15
	env.glow_bloom = 0.1
	# Only pixels brighter than 1.0 bloom, so just the hero elements we push overbright
	# glow — not the whole bright sky (avoids the 4.x "everything glows" gotcha).
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	# Soft, wide spread across a few mip levels.
	env.set_glow_level(1, 0.8)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.4)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# Push a color overbright (>1.0) so it blooms under HDR glow; pass-through on GL compat.
func _emit(c: Color, boost: float) -> Color:
	if not _hdr_glow:
		return c
	return Color(c.r * boost, c.g * boost, c.b * boost, c.a)

# --- Post-Processing ---
func _build_post_processing() -> void:
	post_process_layer = CanvasLayer.new()
	post_process_layer.layer = 100
	add_child(post_process_layer)
	post_process_rect = ColorRect.new()
	var vp_size := get_viewport_rect().size
	post_process_rect.size = vp_size
	post_process_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = POST_PROCESS_SHADER
	post_process_rect.material = mat
	post_process_layer.add_child(post_process_rect)

func _build_distance_fog() -> void:
	# Phase 4C: Atmospheric perspective fog that increases with camera distance
	distance_fog_layer = CanvasLayer.new()
	distance_fog_layer.layer = 80
	add_child(distance_fog_layer)
	distance_fog_rect = ColorRect.new()
	var vp_size := get_viewport_rect().size
	distance_fog_rect.size = vp_size
	distance_fog_rect.color = Color(0.6, 0.65, 0.75, 0.0)
	distance_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_fog_layer.add_child(distance_fog_rect)

# --- God-ray light shafts (R1) ---
func _build_god_rays() -> void:
	var world_w: float = terrain_points[terrain_points.size() - 1].x + 200.0
	var max_y: float = 0.0
	for pt in terrain_points:
		if pt.y > max_y:
			max_y = pt.y
	# Sits behind the treeline (treeline z is -5..-4); rays at -6.
	god_ray_rect = ColorRect.new()
	god_ray_rect.position = Vector2(-200, -80)
	god_ray_rect.size = Vector2(world_w + 400, max_y + 200)
	god_ray_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	god_ray_rect.z_index = -6
	var mat := ShaderMaterial.new()
	mat.shader = GOD_RAYS_SHADER
	mat.set_shader_parameter("angle", 0.45)
	mat.set_shader_parameter("ray_density", 12.0)
	mat.set_shader_parameter("ray_color", Vector3(1.0, 0.88, 0.6))
	mat.set_shader_parameter("ray_speed", 0.05)
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("time", 0.0)
	# Additive blend is set via `render_mode blend_add` in god_rays.gdshader.
	god_ray_rect.material = mat
	near_hills_layer.add_child(god_ray_rect)

# --- Foreground silhouette fronds (R1) ---
func _build_foreground_silhouette() -> void:
	var frond_color := Color(0.02, 0.04, 0.03, 0.82)
	# A few big soft drooping fronds anchored at top corners that pass faster
	# than the world (motion_scale 1.1) to frame the shot. Behind UI, never blocks input.
	var fronds: Array = [
		{"origin": Vector2(0, -20), "dir": 1.0, "len": 120.0, "droop": 70.0},
		{"origin": Vector2(40, -30), "dir": 1.0, "len": 90.0, "droop": 55.0},
		{"origin": Vector2(640, -20), "dir": -1.0, "len": 120.0, "droop": 70.0},
		{"origin": Vector2(600, -30), "dir": -1.0, "len": 95.0, "droop": 60.0},
	]
	for f in fronds:
		var poly := Polygon2D.new()
		poly.color = frond_color
		poly.polygon = _make_frond_shape(f["len"], f["droop"], f["dir"])
		poly.position = f["origin"]
		poly.z_index = 8
		foreground_layer.add_child(poly)

func _make_frond_shape(length: float, droop: float, dir: float) -> PackedVector2Array:
	# A tapered drooping leaf blade as a soft arc.
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = dir * length * u
		var y: float = droop * u * u  # accelerating droop
		var width: float = lerpf(14.0, 1.5, u)  # taper to tip
		top.append(Vector2(x, y - width * 0.5))
		bottom.append(Vector2(x, y + width * 0.5))
	var pts := PackedVector2Array()
	for p in top:
		pts.append(p)
	for i in range(bottom.size()):
		pts.append(bottom[bottom.size() - 1 - i])
	return pts

# --- fbm drifting fog bands (R1) ---
func _build_fbm_fog() -> void:
	# Shared seamless noise texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	fog_noise_tex = NoiseTexture2D.new()
	fog_noise_tex.width = 256
	fog_noise_tex.height = 256
	fog_noise_tex.seamless = true
	fog_noise_tex.noise = noise

	var world_w: float = terrain_points[terrain_points.size() - 1].x + 200.0
	var max_y: float = 0.0
	for pt in terrain_points:
		if pt.y > max_y:
			max_y = pt.y

	# High atmospheric haze band — in the parallax (far hills), gentle sideways drift.
	haze_fog_rect = ColorRect.new()
	haze_fog_rect.position = Vector2(-200, 60)
	haze_fog_rect.size = Vector2(world_w + 400, 90)
	haze_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze_fog_rect.z_index = -3
	var hmat := ShaderMaterial.new()
	hmat.shader = FOG2D_SHADER
	hmat.set_shader_parameter("noise_tex", fog_noise_tex)
	hmat.set_shader_parameter("fog_color", Vector3(0.66, 0.72, 0.70))
	hmat.set_shader_parameter("drift", Vector2(0.012, 0.0))
	hmat.set_shader_parameter("shift", 0.42)
	hmat.set_shader_parameter("density", 0.22)
	hmat.set_shader_parameter("scale", 1.6)
	hmat.set_shader_parameter("time", 0.0)
	haze_fog_rect.material = hmat
	far_hills_layer.add_child(haze_fog_rect)

	# Low ground mist band over the water surfaces — gentle upward drift, mixes in world space.
	ground_fog_rect = ColorRect.new()
	ground_fog_rect.position = Vector2(-100, 110)
	ground_fog_rect.size = Vector2(world_w + 200, max_y - 80)
	ground_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground_fog_rect.z_index = 5
	var gmat := ShaderMaterial.new()
	gmat.shader = FOG2D_SHADER
	gmat.set_shader_parameter("noise_tex", fog_noise_tex)
	gmat.set_shader_parameter("fog_color", Vector3(0.62, 0.68, 0.60))
	gmat.set_shader_parameter("drift", Vector2(0.01, -0.02))
	gmat.set_shader_parameter("shift", 0.5)
	gmat.set_shader_parameter("density", 0.18)
	gmat.set_shader_parameter("scale", 2.4)
	gmat.set_shader_parameter("time", 0.0)
	ground_fog_rect.material = gmat
	add_child(ground_fog_rect)

# --- Day/Night Cycle & Animation ---
func _process(delta: float) -> void:
	if _startle_cd > 0.0:
		_startle_cd -= delta
	# Helicopter flyover — after pool 4 drained
	if GameManager.is_swamp_completed(4):
		helicopter_timer += delta
		if helicopter_timer >= 60.0 and helicopter_active == null:
			helicopter_timer = 0.0
			_spawn_helicopter()
		if helicopter_active != null:
			helicopter_active.position.x += 160.0 * delta
			# Rotate rotor
			var rotor_line: Node = helicopter_active.get_node_or_null("rotor")
			if rotor_line:
				rotor_line.rotation += 25.0 * delta
			var cam_heli: Camera2D = get_viewport().get_camera_2d()
			var cam_heli_x: float = cam_heli.get_screen_center_position().x if cam_heli else 320.0
			if helicopter_active.position.x > cam_heli_x + 400:
				helicopter_active.queue_free()
				helicopter_active = null

	# Continuous sell while player stands in shop area
	if player_in_shop_area and is_instance_valid(shop_player_ref):
		var earned: float = GameManager.sell_water()
		if earned > 0.01 and shop_player_ref.has_method("show_floating_text"):
			shop_player_ref.show_floating_text("+%s" % Economy.format_money(earned), Color(1.0, 0.85, 0.2))
			_spawn_coin_fly(shop_player_ref.global_position, _coin_count_for(earned))

	# Update camels
	if GameManager.camel_count > 0:
		_update_camels(delta)

	cycle_time += delta
	if cycle_time >= CYCLE_DURATION:
		cycle_time -= CYCLE_DURATION
		GameManager.current_day += 1
		GameManager.day_changed.emit(GameManager.current_day)

	var t: float = cycle_time / CYCLE_DURATION
	GameManager.cycle_progress = t
	var tint: Color = _get_cycle_color(t)
	canvas_modulate.color = tint

	# Update shader uniforms
	var daytime_val: float = 0.0
	if t > 0.25 and t < 0.65:
		daytime_val = 1.0
	elif t >= 0.20 and t <= 0.25:
		daytime_val = (t - 0.20) / 0.05
	elif t >= 0.65 and t <= 0.72:
		daytime_val = 1.0 - (t - 0.65) / 0.07
	for wi in range(water_polygons.size()):
		var wp: Polygon2D = water_polygons[wi]
		if wp.material:
			var wmat: ShaderMaterial = wp.material as ShaderMaterial
			wmat.set_shader_parameter("time", wave_time)
			wmat.set_shader_parameter("daytime", daytime_val)
			# Phase 8B: Modulate shader params based on drain level
			if wi < SWAMP_COUNT:
				var pool_fill: float = GameManager.get_swamp_fill_fraction(wi)
				var drain_f: float = 1.0 - pool_fill  # 0=full, 1=empty
				var base_chop: float = POOL_SHADER_PARAMS[wi][2]
				var base_wave: float = POOL_SHADER_PARAMS[wi][0]
				wmat.set_shader_parameter("choppiness", base_chop + drain_f * 1.5)
				wmat.set_shader_parameter("wave_strength", base_wave + drain_f * 0.8)
				# Pack this pool's active ripples into the shader arrays.
				_feed_ripples(wmat, wi)
	# --- R2: age ripples, decay wet_fade, update lagging foam tide-line ---
	_update_ripples(delta)
	for si2 in range(SWAMP_COUNT):
		if _pool_wet_fade[si2] < 1.0:
			_pool_wet_fade[si2] = minf(_pool_wet_fade[si2] + delta * 0.12, 1.0)
		_update_foam_tide_line(si2, delta)
	# World progression: drain progress (used by multiple systems)
	var total_drained: float = 0.0
	var total_capacity: float = 0.0
	for si in range(SWAMP_COUNT):
		var cap: float = GameManager.swamp_definitions[si]["total_gallons"]
		total_capacity += cap
		total_drained += GameManager.swamp_states[si]["gallons_drained"]
	var drain_progress: float = total_drained / maxf(total_capacity, 1.0)

	if post_process_rect and post_process_rect.material:
		var pp_mat: ShaderMaterial = post_process_rect.material as ShaderMaterial
		pp_mat.set_shader_parameter("time", wave_time)
		# Heat shimmer disabled: the full-screen UV warp during daytime caused motion
		# sickness. (Could reintroduce later as a subtle effect localized over water only.)
		pp_mat.set_shader_parameter("heat_shimmer_strength", 0.0)
		# Warm/cool color shift
		var warmth: float = 0.0
		if t >= 0.2 and t <= 0.5:
			warmth = 0.02
		elif t > 0.65 or t < 0.15:
			warmth = -0.02
		# Heal master-lerp: warmth + saturation clear as the swamp drains.
		pp_mat.set_shader_parameter("warmth", warmth + lerpf(-0.01, 0.01, drain_progress))
		pp_mat.set_shader_parameter("saturation", lerpf(0.75, 1.06, drain_progress))
		# New R1 uniforms (constant defaults; bloom/dither not yet driven dynamically)
		pp_mat.set_shader_parameter("bloom_threshold", 0.7)
		# On desktop (Forward+) real HDR-2D WorldEnvironment glow handles bloom, so
		# switch off the shader-faked bloom to avoid doubling. Web/GL-compat keeps it.
		pp_mat.set_shader_parameter("bloom_intensity", 0.0 if _hdr_glow else 0.6)
		pp_mat.set_shader_parameter("bloom_radius", 3.0)
		pp_mat.set_shader_parameter("dither_levels", 14.0)
		pp_mat.set_shader_parameter("dither_strength", 0.5)
		# Night blue shift factor
		var night_f: float = 0.0
		if t > 0.72 or t < 0.12:
			night_f = 1.0
		elif t >= 0.65 and t <= 0.72:
			night_f = (t - 0.65) / 0.07
		elif t >= 0.12 and t <= 0.2:
			night_f = 1.0 - (t - 0.12) / 0.08
		pp_mat.set_shader_parameter("night_factor", night_f)
		# Chromatic aberration increases slightly during lightning
		var ca_val: float = 0.5
		if weather_state == "rain":
			ca_val = 1.2
		pp_mat.set_shader_parameter("chromatic_aberration", ca_val)

	# God-ray strength: peaks at dawn/dusk, ~0 midday/night; stronger when murky.
	if god_ray_rect and god_ray_rect.material:
		var gr_mat: ShaderMaterial = god_ray_rect.material as ShaderMaterial
		var tod_ray: float = 0.0
		if t >= 0.15 and t < 0.30:
			tod_ray = sin((t - 0.15) / 0.15 * PI) * 0.5   # dawn peak
		elif t >= 0.60 and t < 0.75:
			tod_ray = sin((t - 0.60) / 0.15 * PI) * 0.5   # dusk peak
		# Murkier swamp -> hazier light, slightly stronger shafts.
		var murk: float = 1.0 - drain_progress
		var ray_strength: float = clampf(tod_ray * (1.0 + murk * 0.4), 0.0, 1.0)
		gr_mat.set_shader_parameter("time", wave_time)
		gr_mat.set_shader_parameter("strength", ray_strength)
		var ray_rgb: Vector3 = Vector3(HEAL_RAY_MURKY.r, HEAL_RAY_MURKY.g, HEAL_RAY_MURKY.b).lerp(
			Vector3(HEAL_RAY_HEALED.r, HEAL_RAY_HEALED.g, HEAL_RAY_HEALED.b), drain_progress)
		# Overbright the shaft cores on HDR so the brightest rays bloom (additive shader).
		if _hdr_glow:
			ray_rgb *= 1.5
		gr_mat.set_shader_parameter("ray_color", ray_rgb)

	# fbm fog: animate + heal-lerp color and density (murky thicker/greener -> clean thinner/cooler).
	var heal_fog_col: Color = HEAL_FOG_MURKY.lerp(HEAL_FOG_HEALED, drain_progress)
	var fog_col_v := Vector3(heal_fog_col.r, heal_fog_col.g, heal_fog_col.b)
	if haze_fog_rect and haze_fog_rect.material:
		var hm: ShaderMaterial = haze_fog_rect.material as ShaderMaterial
		hm.set_shader_parameter("time", wave_time)
		hm.set_shader_parameter("fog_color", fog_col_v)
		hm.set_shader_parameter("density", lerpf(0.30, 0.14, drain_progress))
	if ground_fog_rect and ground_fog_rect.material:
		var gm: ShaderMaterial = ground_fog_rect.material as ShaderMaterial
		gm.set_shader_parameter("time", wave_time)
		gm.set_shader_parameter("fog_color", fog_col_v)
		gm.set_shader_parameter("density", lerpf(0.26, 0.10, drain_progress))

	# Environmental storytelling: ground color shifts with drain progress
	if terrain_polygon:
		var healthy_ground := Color(0.52, 0.40, 0.22)
		terrain_polygon.color = GROUND_COLOR.lerp(healthy_ground, drain_progress * 0.6)

	# Update sky gradient colors based on time of day
	if sky_gradient_res:
		var sky_a: Array[Color]
		var sky_b: Array[Color]
		var sky_blend: float
		if t < 0.15:
			# Night
			sky_a = SKY_NIGHT; sky_b = SKY_NIGHT; sky_blend = 0.0
		elif t < 0.22:
			# Night → Dawn
			sky_a = SKY_NIGHT; sky_b = SKY_DAWN; sky_blend = (t - 0.15) / 0.07
		elif t < 0.30:
			# Dawn → Day
			sky_a = SKY_DAWN; sky_b = SKY_DAY; sky_blend = (t - 0.22) / 0.08
		elif t < 0.60:
			# Day
			sky_a = SKY_DAY; sky_b = SKY_DAY; sky_blend = 0.0
		elif t < 0.68:
			# Day → Dusk
			sky_a = SKY_DAY; sky_b = SKY_DUSK; sky_blend = (t - 0.60) / 0.08
		elif t < 0.75:
			# Dusk → Night
			sky_a = SKY_DUSK; sky_b = SKY_NIGHT; sky_blend = (t - 0.68) / 0.07
		else:
			# Night
			sky_a = SKY_NIGHT; sky_b = SKY_NIGHT; sky_blend = 0.0
		# Heal master-lerp: when murky, push the whole sky subtly toward sickly grey-green.
		# Weight is small and fades fully to the clean time-of-day sky as drain completes.
		var murk_sky: float = (1.0 - drain_progress) * 0.18
		var c0: Color = sky_a[0].lerp(sky_b[0], sky_blend).lerp(HEAL_SKY_MURKY, murk_sky)
		var c1: Color = sky_a[1].lerp(sky_b[1], sky_blend).lerp(HEAL_SKY_MURKY, murk_sky)
		var c2: Color = sky_a[2].lerp(sky_b[2], sky_blend).lerp(HEAL_SKY_MURKY, murk_sky)
		sky_gradient_res.colors = PackedColorArray([c0, c1, c2])
	# Horizon glow (bright at dawn/dusk, invisible otherwise)
	if horizon_glow:
		var glow_a: float = 0.0
		if t >= 0.15 and t < 0.25:
			glow_a = sin((t - 0.15) / 0.10 * PI) * 0.25
		elif t >= 0.62 and t < 0.72:
			glow_a = sin((t - 0.62) / 0.10 * PI) * 0.25
		horizon_glow.default_color.a = glow_a

	# Water glow pulse
	var glow_base_alpha: float = 0.08
	if t > 0.6 or t < 0.2:
		glow_base_alpha = 0.18
	var glow_pulse: float = glow_base_alpha + sin(wave_time * 1.2) * 0.04
	for gl in water_glow_lines:
		gl.default_color.a = glow_pulse

	# Weather system
	weather_timer += delta
	if weather_state == "clear":
		if weather_timer >= weather_duration:
			if randf() < 0.3:
				weather_state = "rain"
				weather_duration = randf_range(30.0, 60.0)
				weather_timer = 0.0
				rain_particles.emitting = true
				lightning_timer = randf_range(15.0, 45.0)
			else:
				weather_duration = randf_range(60.0, 120.0)
				weather_timer = 0.0
	elif weather_state == "rain":
		if weather_timer >= weather_duration:
			weather_state = "clear"
			weather_duration = randf_range(60.0, 120.0)
			weather_timer = 0.0
			rain_particles.emitting = false
		else:
			lightning_timer -= delta
			if lightning_timer <= 0.0:
				lightning_timer = randf_range(15.0, 45.0)
				_flash_lightning()
	if lightning_rect and lightning_rect.color.a > 0.0:
		lightning_rect.color.a = maxf(0.0, lightning_rect.color.a - delta * 3.0)

	# Wind direction shifts
	wind_timer += delta
	if wind_timer >= 8.0:
		wind_timer = 0.0
		wind_direction = lerpf(wind_direction, randf_range(-1.0, 1.0), 0.4)

	# Fern sway is now handled by the shared foliage_sway shader (R3).

	# Drain-revealed objects
	for i in range(mini(drain_reveals.size(), SWAMP_COUNT)):
		var fill: float = GameManager.get_swamp_fill_fraction(i)
		for reveal in drain_reveals[i]:
			var show: bool = fill <= reveal["threshold"]
			for node in reveal["nodes"]:
				node.visible = show

	# Growing vegetation on drained land (Phase 15b)
	for i in range(mini(last_drain_thresholds.size(), SWAMP_COUNT)):
		var fill_now: float = GameManager.get_swamp_fill_fraction(i)
		var fill_prev: float = last_drain_thresholds[i]
		# Spawn plants when crossing 10% drain thresholds
		if fill_now < fill_prev - 0.05:
			last_drain_thresholds[i] = fill_now
			var geo: Dictionary = _get_swamp_geometry(i)
			var bx: float = randf_range(geo["basin_left"].x, geo["basin_right"].x)
			var by: float = _get_terrain_y_at(bx)
			if grown_plants.size() < 80:
				_spawn_drain_plant(bx, by)

	# Morning mist (dawn-specific, Phase 17b)
	var mist_alpha: float = 0.0
	if t >= 0.1 and t < 0.15:
		mist_alpha = (t - 0.1) / 0.05
	elif t >= 0.15 and t < 0.2:
		mist_alpha = lerpf(1.0, 0.0, (t - 0.15) / 0.05)
	for mr in morning_mist_rects:
		mr.color.a = mist_alpha * 0.12
		mr.position.x += delta * randf_range(3.0, 8.0)
		if mr.position.x > 2000:
			mr.position.x = -80.0

	# Aurora borealis (rare night event, Phase 17c)
	aurora_timer += delta
	if not aurora_active and (t > 0.75 or t < 0.1):
		if aurora_timer >= 30.0:
			aurora_timer = 0.0
			if randf() < 0.1:
				aurora_active = true
				aurora_fade = 0.0
	elif aurora_active:
		if t > 0.12 and t < 0.7:
			aurora_active = false
		else:
			aurora_fade = minf(aurora_fade + delta * 0.05, 1.0)
	if not aurora_active and aurora_fade > 0.0:
		aurora_fade = maxf(aurora_fade - delta * 0.05, 0.0)
	var cam_au: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
	var cam_x_au: float = cam_au.get_screen_center_position().x if cam_au else 320.0
	for al in aurora_lines:
		var aline: Line2D = al["line"]
		aline.clear_points()
		if aurora_fade > 0.01:
			var half_vp: float = get_viewport_rect().size.x / 2.0
			for s in range(24):
				var ax: float = cam_x_au - half_vp + s * (half_vp * 2.0 / 23.0)
				var ay: float = al["base_y"] + sin(wave_time * al["speed"] + s * 0.5 + al["phase"]) * 8.0
				aline.add_point(Vector2(ax, ay))
			var pulse_val: float = 1.0
			if al.has("pulse_phase"):
				pulse_val = 0.7 + 0.3 * sin(wave_time * 0.4 + al["pulse_phase"])
			aline.default_color.a = aurora_fade * 0.45 * pulse_val

	# Owl (nighttime perched, Phase 17d)
	if owl_node:
		var owl_vis: bool = t > 0.7 or t < 0.12
		owl_node.visible = owl_vis
		if owl_vis:
			owl_blink_timer -= delta
			if owl_blink_timer <= 0.0:
				owl_blink_timer = randf_range(3.0, 7.0)
				# Blink eyes
				var eyes: Array[Node] = []
				for ch in owl_node.get_children():
					if ch is ColorRect and ch.color.g > 0.8:
						eyes.append(ch)
				for eye in eyes:
					var orig_a: float = eye.color.a
					eye.color.a = 0.0
					var btw := create_tween()
					var e: ColorRect = eye as ColorRect
					btw.tween_interval(0.12)
					btw.tween_callback(func() -> void:
						if is_instance_valid(e): e.color.a = orig_a
					)

	# Player shadow (Phase 13c)
	if player_shadow:
		var player_node: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player_node:
			# Shadow visible during day, stretch based on sun angle
			var shadow_vis: bool = t >= 0.15 and t <= 0.7
			player_shadow.visible = shadow_vis
			if shadow_vis:
				var sun_progress: float = (t - 0.15) / 0.55
				var shadow_len: float = lerpf(16.0, 6.0, sin(sun_progress * PI))
				var shadow_dir: float = lerpf(-1.0, 1.0, sun_progress)
				player_shadow.size = Vector2(shadow_len, 2)
				player_shadow.position = Vector2(
					player_node.global_position.x + shadow_dir * shadow_len * 0.3,
					player_node.global_position.y + 2
				)
				player_shadow.color.a = lerpf(0.1, 0.25, sin(sun_progress * PI))

	# Animate water surface waves
	wave_time += delta
	for i in range(SWAMP_COUNT):
		var fill: float = GameManager.get_swamp_fill_fraction(i)
		if fill > 0.001:
			var water_y: float = _get_pool_water_y(i)
			var left_x: float = _find_water_left_x(i, water_y)
			var right_x: float = _find_water_right_x(i, water_y)
			_update_water_surface_line(i, left_x, right_x, water_y)
			_update_shimmer_line(i, left_x, right_x, water_y)
		else:
			shimmer_lines[i].clear_points()
			if i < water_glow_lines.size():
				water_glow_lines[i].clear_points()

	# Drift clouds slowly
	for ci in range(clouds.size()):
		clouds[ci].position.x += delta * (3.0 + ci * 0.5)
		if clouds[ci].position.x > 1960:
			clouds[ci].position.x = -80

	# Stars: visible at night, twinkle
	var star_alpha: float = 0.0
	if t > 0.65:
		star_alpha = clampf((t - 0.65) / 0.05, 0.0, 1.0)
	elif t < 0.15:
		star_alpha = 1.0
	elif t < 0.2:
		star_alpha = clampf(1.0 - (t - 0.15) / 0.05, 0.0, 1.0)
	for i in range(stars.size()):
		var s: ColorRect = stars[i]
		var twinkle: float = (sin(wave_time * 2.5 + s.position.x * 0.7) + 1.0) * 0.5
		s.color.a = star_alpha * lerpf(0.4, 1.0, twinkle)

	# Fireflies: visible from dusk through night
	var fly_alpha: float = 0.0
	if t > 0.55:
		fly_alpha = clampf((t - 0.55) / 0.05, 0.0, 1.0)
	elif t < 0.15:
		fly_alpha = 1.0
	elif t < 0.2:
		fly_alpha = clampf(1.0 - (t - 0.15) / 0.05, 0.0, 1.0)
	for fd in fireflies:
		var node: ColorRect = fd["node"]
		var px: float = fd["base_x"] + sin(wave_time * fd["speed_x"] + fd["phase_x"]) * fd["amp_x"]
		var py: float = fd["base_y"] + sin(wave_time * fd["speed_y"] + fd["phase_y"]) * fd["amp_y"]
		py = minf(py, _get_terrain_y_at(px) - 10.0)
		node.position = Vector2(px, py)
		var glow: float = (sin(wave_time * 1.8 + fd["glow_phase"]) + 1.0) * 0.5
		var fly_vis: float = fly_alpha * lerpf(0.2, 0.9, glow)
		node.color.a = fly_vis
		if fd.has("glow"):
			fd["glow"].color.a = fly_vis * 0.35

	# Leaf particles
	leaf_timer += delta
	if leaf_timer >= 2.0:
		leaf_timer = 0.0
		_spawn_leaf()
	var leaves_to_remove: Array[int] = []
	for i in range(leaves.size()):
		var ld: Dictionary = leaves[i]
		ld["lifetime"] += delta
		if ld["lifetime"] > ld["max_life"]:
			leaves_to_remove.append(i)
			continue
		var node: ColorRect = ld["node"]
		node.position.x += ld["speed"] * delta
		var leaf_y: float = ld["base_y"] + sin(wave_time * 1.2 + ld["wobble_phase"]) * ld["wobble_amp"]
		node.position.y = minf(leaf_y, _get_terrain_y_at(node.position.x) - 25.0)
		node.rotation += delta * 0.8
		# Fade near end of life
		var life_frac: float = ld["lifetime"] / ld["max_life"]
		if life_frac > 0.8:
			node.color.a = lerpf(0.7, 0.0, (life_frac - 0.8) / 0.2)
	# Remove dead leaves (reverse order)
	for i in range(leaves_to_remove.size() - 1, -1, -1):
		var idx: int = leaves_to_remove[i]
		leaves[idx]["node"].queue_free()
		leaves.remove_at(idx)

	# Lily pads: bob on water surface
	for lp in lily_pads:
		var swamp_i: int = lp["swamp"]
		var fill: float = GameManager.get_swamp_fill_fraction(swamp_i)
		var node: Node2D = lp["node"]
		if fill < 0.001:
			node.visible = false
			continue
		node.visible = true
		var water_y: float = _get_pool_water_y(swamp_i)
		var bob_offset: float = sin(wave_time * 1.5 + lp["phase"]) * 1.0
		node.position = Vector2(lp["x"], water_y + bob_offset)

	# Foam lines at water edges
	for i in range(SWAMP_COUNT):
		var fill: float = GameManager.get_swamp_fill_fraction(i)
		if fill > 0.001:
			var water_y: float = _get_pool_water_y(i)
			var left_x: float = _find_water_left_x(i, water_y)
			var right_x: float = _find_water_right_x(i, water_y)
			_update_foam_line(i, left_x, right_x, water_y)
		else:
			foam_lines[i].clear_points()

	# Drained pool bed visibility + pool glow lights + waterfall drips
	_update_pool_beds()
	_update_pool_glow_lights()
	_update_waterfall_drips(delta)

	# Sun arc across sky (sunrise t=0.15 to sunset t=0.70)
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
	var cam_x: float = cam.get_screen_center_position().x if cam else 320.0
	if t >= 0.15 and t <= 0.70:
		var sun_progress: float = (t - 0.15) / 0.55
		sun_node.position.x = cam_x + lerpf(-380.0, 380.0, sun_progress)
		sun_node.position.y = 90.0 - sin(sun_progress * PI) * 110.0
		sun_node.visible = true
		var sun_alpha: float = 1.0
		if sun_progress < 0.1:
			sun_alpha = sun_progress / 0.1
		elif sun_progress > 0.9:
			sun_alpha = (1.0 - sun_progress) / 0.1
		sun_node.modulate.a = sun_alpha
		# Slowly rotate sun rays
		for child in sun_node.get_children():
			if child is Line2D and child.name.begins_with("SunRay"):
				child.rotation = wave_time * 0.1
	else:
		sun_node.visible = false

	# Moon arc across sky (moonrise t=0.68 to moonset t=0.17 next day)
	var moon_visible: bool = t >= 0.68 or t <= 0.17
	if moon_visible:
		var moon_progress: float
		if t >= 0.68:
			moon_progress = (t - 0.68) / 0.49
		else:
			moon_progress = (t + 0.32) / 0.49
		moon.position.x = cam_x + lerpf(-380.0, 380.0, moon_progress)
		moon.position.y = 80.0 - sin(moon_progress * PI) * 100.0
		var moon_alpha: float = 1.0
		if moon_progress < 0.1:
			moon_alpha = moon_progress / 0.1
		elif moon_progress > 0.9:
			moon_alpha = (1.0 - moon_progress) / 0.1
		# Soft-orb children fade via the parent modulate; the light energy separately.
		moon.modulate.a = moon_alpha
		for child in moon.get_children():
			if child is PointLight2D:
				child.energy = moon_alpha * 0.2
	else:
		moon.modulate.a = 0.0
		for child in moon.get_children():
			if child is PointLight2D:
				child.energy = 0.0

	# Swamp gas bubbles
	bubble_timer += delta
	if bubble_timer >= 1.5:
		bubble_timer = 0.0
		var si: int = randi() % SWAMP_COUNT
		_spawn_bubble(si)
	var bubbles_to_remove: Array[int] = []
	for i in range(bubbles.size()):
		var bd: Dictionary = bubbles[i]
		var bnode: ColorRect = bd["node"]
		bnode.position.y -= bd["speed"] * delta
		bnode.position.x += sin(wave_time * 4.0 + bd["wobble_phase"]) * 0.3
		if bnode.position.y <= bd["target_y"]:
			bubbles_to_remove.append(i)
	for i in range(bubbles_to_remove.size() - 1, -1, -1):
		var idx: int = bubbles_to_remove[i]
		bubbles[idx]["node"].queue_free()
		bubbles.remove_at(idx)

	# Dragonflies: visible during daytime
	var df_alpha: float = 0.0
	if t > 0.15 and t < 0.55:
		df_alpha = 1.0
	elif t <= 0.15:
		df_alpha = clampf(t / 0.15, 0.0, 1.0)
	elif t >= 0.55:
		df_alpha = clampf(1.0 - (t - 0.55) / 0.1, 0.0, 1.0)
	for dd in dragonflies:
		var dnode: Node2D = dd["node"]
		var dpx: float = dd["base_x"] + sin(wave_time * dd["speed"] + dd["phase_x"]) * dd["amp_x"]
		var dpy: float = dd["base_y"] + sin(wave_time * dd["speed"] * 0.7 + dd["phase_y"]) * dd["amp_y"]
		dpy = minf(dpy, _get_terrain_y_at(dpx) - 15.0)
		dnode.position = Vector2(dpx, dpy)
		dnode.modulate.a = df_alpha
		# Wing flap
		var flap: float = sin(wave_time * 12.0 + dd["phase_x"]) * 0.5
		dd["wing_l"].position.y = -2 + flap
		dd["wing_r"].position.y = -2 - flap

	# Water reflection highlights (daytime)
	var hl_alpha: float = 0.0
	if t > 0.2 and t < 0.55:
		hl_alpha = 1.0
	elif t >= 0.15 and t <= 0.2:
		hl_alpha = (t - 0.15) / 0.05
	elif t >= 0.55 and t <= 0.65:
		hl_alpha = 1.0 - (t - 0.55) / 0.1
	for wh in water_highlights:
		var wh_node: ColorRect = wh["node"]
		var wh_swamp: int = wh["swamp"]
		var wh_fill: float = GameManager.get_swamp_fill_fraction(wh_swamp)
		if wh_fill < 0.01:
			wh_node.visible = false
			continue
		wh_node.visible = true
		var wh_water_y: float = _get_pool_water_y(wh_swamp)
		var wh_left_x: float = _find_water_left_x(wh_swamp, wh_water_y)
		var wh_right_x: float = _find_water_right_x(wh_swamp, wh_water_y)
		var wh_px: float = lerpf(wh_left_x, wh_right_x, wh["offset_x"])
		var shimmer: float = (sin(wave_time * 2.0 + wh["phase"]) + 1.0) * 0.5
		wh_node.position = Vector2(wh_px, wh_water_y + 1)
		wh_node.color.a = hl_alpha * shimmer * 0.25

	# Fog patches: visible at dusk/dawn and night
	var fog_alpha: float = 0.0
	if t > 0.6:
		fog_alpha = clampf((t - 0.6) / 0.1, 0.0, 0.25)
	elif t < 0.2:
		fog_alpha = 0.25
	elif t < 0.25:
		fog_alpha = lerpf(0.25, 0.0, (t - 0.2) / 0.05)
	for fp in fog_patches:
		var fnode: ColorRect = fp["node"]
		fnode.position.x = fp["base_x"] + sin(wave_time * 0.3 + fp["phase"]) * 8.0
		fnode.color.a = fog_alpha * (0.6 + sin(wave_time * 0.5 + fp["phase"]) * 0.4)

	# Phase 4C: Distance fog — atmospheric perspective based on camera position
	if distance_fog_rect:
		var cam_4c: Camera2D = get_viewport().get_camera_2d() if get_viewport() else null
		if cam_4c:
			var cam_pos_x: float = cam_4c.global_position.x
			# Fog increases as camera moves right (max at x=5500)
			var dist_factor: float = clampf(cam_pos_x / 5500.0, 0.0, 1.0)
			var fog_a: float = dist_factor * 0.08  # Max 8% opacity
			# Color shifts with time of day
			var fog_col: Color
			if t > 0.65 or t < 0.15:
				fog_col = Color(0.15, 0.18, 0.30, fog_a)  # Blue at night
			elif t >= 0.15 and t < 0.25:
				fog_col = Color(0.55, 0.45, 0.35, fog_a)  # Warm at dawn
			elif t >= 0.55 and t <= 0.65:
				fog_col = Color(0.60, 0.40, 0.30, fog_a)  # Warm at dusk
			else:
				fog_col = Color(0.55, 0.60, 0.70, fog_a)  # Hazy blue at day
			distance_fog_rect.color = fog_col

	# Pollen motes: daytime only
	var pollen_alpha: float = 0.0
	if t > 0.2 and t < 0.5:
		pollen_alpha = 1.0
	elif t >= 0.15 and t <= 0.2:
		pollen_alpha = (t - 0.15) / 0.05
	elif t >= 0.5 and t <= 0.6:
		pollen_alpha = 1.0 - (t - 0.5) / 0.1
	pollen_timer += delta
	if pollen_timer >= 0.8 and pollen_alpha > 0.1:
		pollen_timer = 0.0
		_spawn_pollen()
	var pollen_to_remove: Array[int] = []
	for i in range(pollen.size()):
		var pd: Dictionary = pollen[i]
		pd["lifetime"] += delta
		if pd["lifetime"] > pd["max_life"]:
			pollen_to_remove.append(i)
			continue
		var pnode: ColorRect = pd["node"]
		pnode.position.x += pd["speed_x"] * delta
		pnode.position.y = pd["base_y"] + sin(wave_time * 0.8 + pd["phase"]) * pd["amp_y"]
		var p_life: float = pd["lifetime"] / pd["max_life"]
		var p_fade: float = 1.0
		if p_life < 0.1:
			p_fade = p_life / 0.1
		elif p_life > 0.8:
			p_fade = (1.0 - p_life) / 0.2
		pnode.color.a = pollen_alpha * p_fade * 0.5
	for i in range(pollen_to_remove.size() - 1, -1, -1):
		var idx: int = pollen_to_remove[i]
		pollen[idx]["node"].queue_free()
		pollen.remove_at(idx)

	# Birds
	bird_timer += delta
	# Bird spawn rate scales with world health (more drained = more birds)
	var bird_interval: float = lerpf(10.0, 4.0, drain_progress)
	if bird_timer >= bird_interval:
		bird_timer = 0.0
		_spawn_bird()
	var birds_to_remove: Array[int] = []
	for i in range(birds.size()):
		var brd: Dictionary = birds[i]
		var bnode: Node2D = brd["node"]
		bnode.position.x += brd["speed"] * delta
		bnode.position.y += brd["y_drift"] * delta
		# Wing flap animation
		var flap_angle: float = sin(wave_time * brd["flap_speed"]) * 3.0
		brd["wing_l"].points[0].y = 2 + flap_angle
		brd["wing_r"].points[1].y = 2 + flap_angle
		if bnode.position.x > 2000:
			birds_to_remove.append(i)
	for i in range(birds_to_remove.size() - 1, -1, -1):
		var idx: int = birds_to_remove[i]
		birds[idx]["node"].queue_free()
		birds.remove_at(idx)

	# Fish: swim in water, contained within pool slopes
	for fd in fish:
		var fnode: Node2D = fd["node"]
		var swamp_i: int = fd["swamp"]
		var fill: float = GameManager.get_swamp_fill_fraction(swamp_i)
		var geo_f: Dictionary = _get_swamp_geometry(swamp_i)
		var basin_left_f: Vector2 = geo_f["basin_left"]
		var basin_right_f: Vector2 = geo_f["basin_right"]
		var basin_y_f: float = _get_pool_deepest_y(swamp_i)

		if fill < 0.02:
			if fd["alive"]:
				fd["alive"] = false
				fd["death_timer"] = 0.0
			fd["death_timer"] += delta
			fnode.visible = true
			fnode.position.y = basin_y_f - 2
			if fd["death_timer"] < 3.0:
				fnode.rotation = sin(fd["death_timer"] * 12.0) * 0.8
			else:
				fnode.rotation = PI * 0.5
				fnode.modulate.a = maxf(0.3, 1.0 - (fd["death_timer"] - 3.0) * 0.05)
			continue

		if fill < 0.15:
			fd["swim_speed"] = 2.5
		elif not fd["alive"]:
			fd["alive"] = true
			fnode.modulate.a = 1.0
			fnode.rotation = 0.0

		fnode.visible = true
		var water_y_f: float = _get_pool_water_y(swamp_i)
		var surface_left_x: float = _find_water_left_x(swamp_i, water_y_f)
		var surface_right_x: float = _find_water_right_x(swamp_i, water_y_f)

		# Depth position
		var fish_y: float = lerpf(water_y_f + 4, basin_y_f - 4, fd["depth_offset"])
		fish_y += sin(fd["swim_phase"] * 0.7) * 2.0
		fish_y = clampf(fish_y, water_y_f + 2, basin_y_f - 2)

		# Calculate valid x range at this depth (respects pool slopes)
		var depth_frac: float = 0.0
		if absf(basin_y_f - water_y_f) > 0.1:
			depth_frac = clampf((fish_y - water_y_f) / (basin_y_f - water_y_f), 0.0, 1.0)
		var bound_left: float = lerpf(surface_left_x, basin_left_f.x, depth_frac) + 6.0
		var bound_right: float = lerpf(surface_right_x, basin_right_f.x, depth_frac) - 6.0

		# Swim horizontally within bounds
		fd["swim_phase"] += delta * fd["swim_speed"]
		var swim_x: float = fd["x"] + sin(fd["swim_phase"]) * fd["swim_range"]
		swim_x = clampf(swim_x, bound_left, bound_right)

		fnode.position = Vector2(swim_x, fish_y)
		var swim_dir: float = cos(fd["swim_phase"])
		fnode.scale.x = 1.0 if swim_dir > 0 else -1.0
		fnode.rotation = sin(fd["swim_phase"] * 2.0) * 0.1
		# Fish jump animation
		if fd["jumping"]:
			fd["jump_time"] += delta
			if fd["jump_time"] >= 0.6:
				fd["jumping"] = false
				fd["jump_time"] = 0.0
			else:
				var arc: float = sin(fd["jump_time"] / 0.6 * PI) * 14.0
				fnode.position.y -= arc
				fnode.rotation -= sin(fd["jump_time"] / 0.6 * PI) * 0.4
		else:
			fd["jump_timer"] -= delta
			if fd["jump_timer"] <= 0.0 and fd["alive"] and fill >= 0.15:
				fd["jumping"] = true
				fd["jump_time"] = 0.0
				fd["jump_timer"] = randf_range(12.0, 35.0)

	# Frogs: occasional hop animation
	for fg in frogs:
		var frog_node: Node2D = fg["node"]
		if not frog_node.get_parent().visible:
			continue
		if fg["hopping"]:
			fg["hop_progress"] += delta * 3.0
			if fg["hop_progress"] >= 1.0:
				fg["hopping"] = false
				fg["hop_progress"] = 0.0
				frog_node.position.y = fg["base_y"]
				fg["hop_timer"] = randf_range(4.0, 12.0)
			else:
				# Arc jump
				var hop_arc: float = sin(fg["hop_progress"] * PI) * -8.0
				frog_node.position.y = fg["base_y"] + hop_arc
		else:
			fg["hop_timer"] -= delta
			if fg["hop_timer"] <= 0.0:
				fg["hopping"] = true
				fg["hop_progress"] = 0.0
				fg["base_y"] = frog_node.position.y
		# Frog blink
		if fg.has("blink_timer"):
			fg["blink_timer"] -= delta
			if fg["blink_timer"] <= 0.0:
				fg["blink_timer"] = randf_range(2.0, 6.0)
				# Brief eye close
				if fg.has("eye_l") and is_instance_valid(fg["eye_l"]):
					var orig_color_l: Color = fg["eye_l"].color
					var orig_color_r: Color = fg["eye_r"].color
					fg["eye_l"].color = Color(0.2, 0.5, 0.15, 0.95)
					fg["eye_r"].color = Color(0.2, 0.5, 0.15, 0.95)
					var blink_tw := create_tween()
					var el: ColorRect = fg["eye_l"]
					var er: ColorRect = fg["eye_r"]
					blink_tw.tween_interval(0.1)
					blink_tw.tween_callback(func() -> void:
						if is_instance_valid(el): el.color = orig_color_l
						if is_instance_valid(er): er.color = orig_color_r
					)

	# Bioluminescent plants: glow at night
	var glow_alpha: float = 0.0
	if t > 0.6:
		glow_alpha = clampf((t - 0.6) / 0.08, 0.0, 1.0)
	elif t < 0.15:
		glow_alpha = 1.0
	elif t < 0.22:
		glow_alpha = clampf(1.0 - (t - 0.15) / 0.07, 0.0, 1.0)
	for gp in glow_plants:
		var pulse: float = (sin(wave_time * gp["pulse_speed"] + gp["phase"]) + 1.0) * 0.5
		var gc: Color = gp["glow_color"]
		var intensity: float = glow_alpha * lerpf(0.4, 1.0, pulse)
		gp["bulb"].color = Color(gc.r, gc.g, gc.b, intensity)
		gp["aura"].color = Color(gc.r, gc.g, gc.b, intensity * 0.25)

	# Seaweed sway underwater
	for sw in seaweed:
		var sw_swamp: int = sw["swamp"]
		var sw_fill: float = GameManager.get_swamp_fill_fraction(sw_swamp)
		sw["node"].visible = sw_fill > 0.05
		if sw["node"].visible:
			var sway_angle: float = sin(wave_time * sw["sway_speed"] + sw["phase"]) * 0.12
			sw["node"].rotation = sway_angle

	# Tadpoles: tiny swimmers contained in pools
	for tp in tadpoles:
		var tp_node: Node2D = tp["node"]
		var tp_swamp: int = tp["swamp"]
		var tp_fill: float = GameManager.get_swamp_fill_fraction(tp_swamp)
		if tp_fill < 0.05:
			tp_node.visible = false
			continue
		tp_node.visible = true
		var tp_geo: Dictionary = _get_swamp_geometry(tp_swamp)
		var tp_bl: Vector2 = tp_geo["basin_left"]
		var tp_br: Vector2 = tp_geo["basin_right"]
		var tp_basin_y: float = _get_pool_deepest_y(tp_swamp)
		var tp_water_y: float = _get_pool_water_y(tp_swamp)
		var tp_y: float = lerpf(tp_water_y + 3, tp_basin_y - 2, tp["depth_offset"])
		tp["swim_phase"] += delta * tp["swim_speed"]
		var tp_depth_frac: float = 0.0
		if absf(tp_basin_y - tp_water_y) > 0.1:
			tp_depth_frac = clampf((tp_y - tp_water_y) / (tp_basin_y - tp_water_y), 0.0, 1.0)
		var tp_slx: float = _find_water_left_x(tp_swamp, tp_water_y)
		var tp_srx: float = _find_water_right_x(tp_swamp, tp_water_y)
		var tp_bound_l: float = lerpf(tp_slx, tp_bl.x, tp_depth_frac) + 4.0
		var tp_bound_r: float = lerpf(tp_srx, tp_br.x, tp_depth_frac) - 4.0
		var tp_x: float = tp["x"] + sin(tp["swim_phase"]) * tp["swim_range"]
		tp_x = clampf(tp_x, tp_bound_l, tp_bound_r)
		tp_node.position = Vector2(tp_x, tp_y)
		tp_node.scale.x = 1.0 if cos(tp["swim_phase"]) > 0 else -1.0
		tp_node.rotation = sin(tp["swim_phase"] * 3.0) * 0.2

	# Water ripple rings
	ripple_timer += delta
	if ripple_timer >= 0.8:
		ripple_timer = 0.0
		var ri_swamp: int = randi() % SWAMP_COUNT
		var ri_fill: float = GameManager.get_swamp_fill_fraction(ri_swamp)
		if ri_fill > 0.05:
			var ri_water_y: float = _get_pool_water_y(ri_swamp)
			var ri_left_x: float = _find_water_left_x(ri_swamp, ri_water_y)
			var ri_right_x: float = _find_water_right_x(ri_swamp, ri_water_y)
			var ri_x: float = randf_range(ri_left_x + 8, ri_right_x - 8)
			_spawn_ripple(ri_x, ri_water_y)
	var ripples_to_remove: Array[int] = []
	for i in range(ripples.size()):
		var rd: Dictionary = ripples[i]
		rd["lifetime"] += delta
		if rd["lifetime"] > rd["max_life"]:
			ripples_to_remove.append(i)
			continue
		var rp_frac: float = rd["lifetime"] / rd["max_life"]
		var rp_line: Line2D = rd["node"]
		var rp_width: float = lerpf(2.0, rd["max_radius"], rp_frac)
		rp_line.clear_points()
		var rp_segs: int = 10
		for s in range(rp_segs + 1):
			var angle: float = float(s) / float(rp_segs) * PI
			rp_line.add_point(Vector2(rd["x"] + cos(angle) * rp_width, rd["y"] + sin(angle) * rp_width * 0.3))
		rp_line.default_color.a = (1.0 - rp_frac) * 0.4
	for i in range(ripples_to_remove.size() - 1, -1, -1):
		var idx: int = ripples_to_remove[i]
		ripples[idx]["node"].queue_free()
		ripples.remove_at(idx)

	# Butterflies: daytime only
	var bf_alpha: float = 0.0
	if t > 0.2 and t < 0.55:
		bf_alpha = 1.0
	elif t >= 0.15 and t <= 0.2:
		bf_alpha = (t - 0.15) / 0.05
	elif t >= 0.55 and t <= 0.65:
		bf_alpha = 1.0 - (t - 0.55) / 0.1
	butterfly_timer += delta
	var bf_max: int = int(lerpf(3.0, 10.0, drain_progress))
	if butterfly_timer >= 3.0 and bf_alpha > 0.1 and butterflies.size() < bf_max:
		butterfly_timer = 0.0
		_spawn_butterfly()
	var bf_to_remove: Array[int] = []
	for i in range(butterflies.size()):
		var bd: Dictionary = butterflies[i]
		bd["lifetime"] += delta
		if bd["lifetime"] > bd["max_life"]:
			bf_to_remove.append(i)
			continue
		var bf_node: Node2D = bd["node"]
		bd["phase"] += delta * bd["flutter_speed"]
		bf_node.position.x += bd["drift_x"] * delta
		var bf_bob_y: float = bd["base_y"] + sin(bd["phase"] * 0.4) * bd["bob_amp"]
		bf_node.position.y = minf(bf_bob_y, _get_terrain_y_at(bf_node.position.x) - 8.0)
		# Wing flap
		var wing_scale: float = absf(sin(bd["phase"]))
		bd["wing_l"].scale.x = wing_scale
		bd["wing_r"].scale.x = wing_scale
		var bf_life: float = bd["lifetime"] / bd["max_life"]
		var bf_fade: float = 1.0
		if bf_life < 0.1:
			bf_fade = bf_life / 0.1
		elif bf_life > 0.85:
			bf_fade = (1.0 - bf_life) / 0.15
		bf_node.modulate.a = bf_alpha * bf_fade
	for i in range(bf_to_remove.size() - 1, -1, -1):
		var idx: int = bf_to_remove[i]
		butterflies[idx]["node"].queue_free()
		butterflies.remove_at(idx)

	# Shooting stars at night
	var night_alpha: float = 0.0
	if t > 0.7:
		night_alpha = clampf((t - 0.7) / 0.05, 0.0, 1.0)
	elif t < 0.12:
		night_alpha = 1.0
	elif t < 0.17:
		night_alpha = clampf(1.0 - (t - 0.12) / 0.05, 0.0, 1.0)
	shooting_star_timer += delta
	if shooting_star_timer >= 6.0 and night_alpha > 0.5 and shooting_stars.size() < 2:
		shooting_star_timer = 0.0
		if randf() < 0.4:
			_spawn_shooting_star()
	var ss_to_remove: Array[int] = []
	for i in range(shooting_stars.size()):
		var sd: Dictionary = shooting_stars[i]
		sd["lifetime"] += delta
		if sd["lifetime"] > sd["max_life"]:
			ss_to_remove.append(i)
			continue
		var ss_line: Line2D = sd["line"]
		var ss_head: ColorRect = sd["head"]
		var ss_frac: float = sd["lifetime"] / sd["max_life"]
		var ss_x: float = sd["start_x"] + sd["speed_x"] * sd["lifetime"]
		var ss_y: float = sd["start_y"] + sd["speed_y"] * sd["lifetime"]
		ss_head.position = Vector2(ss_x, ss_y)
		ss_line.clear_points()
		var trail_len: int = 8
		for s in range(trail_len):
			var trail_t: float = float(s) / float(trail_len)
			ss_line.add_point(Vector2(
				ss_x - sd["speed_x"] * trail_t * 0.3,
				ss_y - sd["speed_y"] * trail_t * 0.3
			))
		var ss_fade: float = 1.0
		if ss_frac > 0.6:
			ss_fade = (1.0 - ss_frac) / 0.4
		ss_head.color.a = night_alpha * ss_fade
		ss_line.default_color.a = night_alpha * ss_fade * 0.6
	for i in range(ss_to_remove.size() - 1, -1, -1):
		var idx: int = ss_to_remove[i]
		shooting_stars[idx]["node"].queue_free()
		shooting_stars.remove_at(idx)

	# Turtle head bob
	for tt in turtles:
		var tt_head: ColorRect = tt["head_ref"]
		var head_bob: float = sin(wave_time * 0.8 + tt["phase"]) * 0.5
		tt_head.position.y += head_bob * 0.02

	# Cricket chirp flashes (nighttime only)
	for cr in crickets:
		cr["node"].visible = night_alpha > 0.3
		if not cr["node"].visible:
			continue
		cr["chirp_timer"] -= delta
		if cr["chirp_timer"] <= 0.0 and not cr["chirping"]:
			cr["chirping"] = true
			cr["chirp_flash"] = 0.0
		if cr["chirping"]:
			cr["chirp_flash"] += delta
			var chirp_ref: ColorRect = cr["chirp_ref"]
			if cr["chirp_flash"] < 0.08:
				chirp_ref.color.a = 0.8
			elif cr["chirp_flash"] < 0.15:
				chirp_ref.color.a = 0.0
			elif cr["chirp_flash"] < 0.22:
				chirp_ref.color.a = 0.6
			else:
				chirp_ref.color.a = 0.0
				cr["chirping"] = false
				cr["chirp_timer"] = randf_range(3.0, 8.0)

	# Cave entrance glow pulsing
	for ce in cave_entrances:
		if ce["open"] and is_instance_valid(ce["glow"]):
			var pulse: float = (sin(wave_time * 2.0 + ce["x"] * 0.1) + 1.0) * 0.5
			ce["glow"].color.a = lerpf(0.15, 0.45, pulse)

	# Cattail wind sway is now handled by the shared foliage_sway shader (R3).

func _get_cycle_color(t: float) -> Color:
	var pre_dawn := Color(0.5, 0.45, 0.65)
	var dawn := Color(1.0, 0.8, 0.65)
	var sunrise := Color(1.0, 0.92, 0.85)
	var noon := Color(1.0, 1.0, 1.0)
	var golden_hour := Color(1.0, 0.85, 0.6)
	var sunset := Color(0.95, 0.55, 0.4)
	var dusk := Color(0.65, 0.35, 0.5)
	var night := Color(0.28, 0.32, 0.58)

	if t < 0.1:
		return night.lerp(pre_dawn, t / 0.1)
	elif t < 0.17:
		return pre_dawn.lerp(dawn, (t - 0.1) / 0.07)
	elif t < 0.22:
		return dawn.lerp(sunrise, (t - 0.17) / 0.05)
	elif t < 0.3:
		return sunrise.lerp(noon, (t - 0.22) / 0.08)
	elif t < 0.5:
		return noon
	elif t < 0.55:
		return noon.lerp(golden_hour, (t - 0.5) / 0.05)
	elif t < 0.62:
		return golden_hour.lerp(sunset, (t - 0.55) / 0.07)
	elif t < 0.68:
		return sunset.lerp(dusk, (t - 0.62) / 0.06)
	elif t < 0.75:
		return dusk.lerp(night, (t - 0.68) / 0.07)
	else:
		return night

# --- Cave Entrances ---
func _get_pool_deepest_point(swamp_index: int) -> Vector2:
	var r: Array = SWAMP_RANGES[swamp_index]
	var deepest_x: float = terrain_points[r[0]].x
	var deepest_y: float = terrain_points[r[0]].y
	for idx in range(r[0], r[1] + 1):
		if terrain_points[idx].y > deepest_y:
			deepest_y = terrain_points[idx].y
			deepest_x = terrain_points[idx].x
	return Vector2(deepest_x, deepest_y)

func _build_billboards() -> void:
	var billboard_texts: Array[String] = [
		"VOTE SWAMPSWORTH\nLeadership You\nCan Trust\nPAID FOR BY FRIENDS OF SWAMPSWORTH",
		"LOBBYTON 2024\nA Fresh Voice\nFor Real Change\nPAID FOR BY LOBBYTON FOR CONGRESS",
		"INJURED AT WORK?\nCALL 555-SWAMP\nTHE LAW OFFICES OF\nSWAMPSWORTH & SONS",
		"SWAMP ACRES\nLUXURY CONDOS\nWaterfront Living\nFROM $2.5M",
		"PROTECT OUR\nWETLANDS\nPAID FOR BY CITIZENS\nAGAINST DRAINING",
		"RE-ELECT LOBBYTON\nShe Gets Results\n(ask her donors)\nPAID FOR BY LOBBYTON PAC",
		"GOODWELL\nFOR REFORM\nHonest Government Now\nPAID FOR BY GOODWELL 2024",
		"EAT AT\nSWAMP MIKE'S\nBBQ & BAIT SHOP\nEXIT 7  -  OPEN 24HRS",
		"SWAMPSWORTH\nGETS IT DONE*\n*it = fundraising\nPAID FOR BY SWAMPSWORTH PAC",
	]
	# Partisan tint colors — odd ridges red (Swampsworth), even ridges blue (Lobbyton)
	var red_tint := Color(0.90, 0.82, 0.78)
	var blue_tint := Color(0.78, 0.82, 0.90)
	var rng_bb := RandomNumberGenerator.new()
	rng_bb.seed = 54321

	for ridge_i in range(SWAMP_COUNT - 1):
		var ridge_start: int = SWAMP_RANGES[ridge_i][1]
		var ridge_end: int = SWAMP_RANGES[ridge_i + 1][0]
		if ridge_start >= terrain_points.size() or ridge_end >= terrain_points.size():
			continue
		var ridge_mid_x: float = (terrain_points[ridge_start].x + terrain_points[ridge_end].x) * 0.5
		var ground_y: float = _get_terrain_y_at(ridge_mid_x)
		if ground_y < 0:
			continue

		var sign_tint: Color = red_tint if (ridge_i % 2 == 0) else blue_tint

		# Post (3px wide)
		var post_h: float = 45.0
		var post := ColorRect.new()
		post.position = Vector2(ridge_mid_x - 1.5, ground_y - post_h)
		post.size = Vector2(3, post_h)
		post.color = Color(0.35, 0.25, 0.18)
		post.z_index = 3
		add_child(post)

		# Crossbar where post meets sign
		var crossbar := ColorRect.new()
		crossbar.position = Vector2(ridge_mid_x - 10, ground_y - post_h - 1)
		crossbar.size = Vector2(20, 2)
		crossbar.color = Color(0.35, 0.25, 0.18)
		crossbar.z_index = 3
		add_child(crossbar)

		# Sign panel (120x60)
		var sign_w: float = 120.0
		var sign_h: float = 60.0
		var sign_node := Node2D.new()
		sign_node.position = Vector2(ridge_mid_x, ground_y - post_h - sign_h * 0.5)
		sign_node.z_index = 3
		add_child(sign_node)

		# Sign background — ColorRect as base, Label as its child (Control→Control layout)
		var sign_bg := ColorRect.new()
		sign_bg.position = Vector2(-sign_w * 0.5, -sign_h * 0.5)
		sign_bg.size = Vector2(sign_w, sign_h)
		sign_bg.color = sign_tint
		sign_bg.clip_contents = true
		sign_node.add_child(sign_bg)

		# Text label as child of sign_bg (Control inside Control = reliable positioning)
		var lbl := Label.new()
		lbl.text = billboard_texts[ridge_i]
		lbl.add_theme_font_size_override("font_size", 6)
		lbl.add_theme_color_override("font_color", Color(0.15, 0.12, 0.10))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.anchor_left = 0.0
		lbl.anchor_top = 0.0
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.offset_left = 4
		lbl.offset_top = 3
		lbl.offset_right = -4
		lbl.offset_bottom = -3
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		sign_bg.add_child(lbl)

		# Sign border (Line2D)
		var border := Line2D.new()
		border.width = 1.0
		border.default_color = Color(0.3, 0.25, 0.18, 0.8)
		border.add_point(Vector2(-sign_w * 0.5, -sign_h * 0.5))
		border.add_point(Vector2(sign_w * 0.5, -sign_h * 0.5))
		border.add_point(Vector2(sign_w * 0.5, sign_h * 0.5))
		border.add_point(Vector2(-sign_w * 0.5, sign_h * 0.5))
		border.add_point(Vector2(-sign_w * 0.5, -sign_h * 0.5))
		border.z_index = 1
		sign_node.add_child(border)


func _build_cave_entrances() -> void:
	cave_entrances.clear()
	for i in range(CAVE_IDS.size()):
		var cave_id: String = CAVE_IDS[i]
		var defn: Dictionary = GameManager.CAVE_DEFINITIONS[cave_id]
		var si: int = defn["swamp_index"]
		var deepest: Vector2 = _get_pool_deepest_point(si)
		var cx: float = deepest.x
		var cy: float = deepest.y
		var is_unlocked: bool = GameManager.is_cave_unlocked(cave_id)

		var root := Node2D.new()
		root.position = Vector2(cx, cy)
		root.z_index = 3
		add_child(root)

		# Sealed crack at pool bottom — thin dark line
		var crack := ColorRect.new()
		crack.size = Vector2(2, 8)
		crack.position = Vector2(-1, -6)
		crack.color = Color(0.15, 0.1, 0.08, 0.8)
		root.add_child(crack)

		# Open entrance visuals — hidden until unlocked
		var opening := ColorRect.new()
		opening.size = Vector2(16, 14)
		opening.position = Vector2(-8, -14)
		opening.color = Color(0.05, 0.03, 0.02)
		opening.visible = is_unlocked
		root.add_child(opening)

		# Rocky edges
		var edge_left := ColorRect.new()
		edge_left.size = Vector2(3, 16)
		edge_left.position = Vector2(-10, -15)
		edge_left.color = Color(0.35, 0.28, 0.2)
		edge_left.visible = is_unlocked
		root.add_child(edge_left)

		var edge_right := ColorRect.new()
		edge_right.size = Vector2(3, 16)
		edge_right.position = Vector2(7, -15)
		edge_right.color = Color(0.35, 0.28, 0.2)
		edge_right.visible = is_unlocked
		root.add_child(edge_right)

		# Top lintel
		var lintel := ColorRect.new()
		lintel.size = Vector2(20, 3)
		lintel.position = Vector2(-10, -16)
		lintel.color = Color(0.3, 0.24, 0.18)
		lintel.visible = is_unlocked
		root.add_child(lintel)

		# Glow rect (pulsing amber)
		var glow := ColorRect.new()
		glow.size = Vector2(24, 18)
		glow.position = Vector2(-12, -16)
		glow.color = Color(0.9, 0.6, 0.2, 0.3)
		glow.visible = is_unlocked
		root.add_child(glow)

		# "Press SPACE" hint label
		var hint := Label.new()
		hint.text = "Press SPACE to enter"
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.9))
		hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		hint.add_theme_constant_override("shadow_offset_x", 1)
		hint.add_theme_constant_override("shadow_offset_y", 1)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.position = Vector2(-48, -32)
		hint.z_index = 10
		hint.visible = false
		root.add_child(hint)

		# Area2D for player interaction
		var area := Area2D.new()
		area.position = Vector2(0, -7)
		area.collision_layer = 0
		area.collision_mask = 1
		var coll := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 20)
		coll.shape = shape
		area.add_child(coll)
		area.monitoring = is_unlocked
		root.add_child(area)

		var cid: String = cave_id
		var hint_ref: Label = hint
		area.body_entered.connect(func(body: Node2D) -> void:
			if body.has_method("set_near_cave_entrance"):
				body.set_near_cave_entrance(true, cid)
				hint_ref.visible = true
		)
		area.body_exited.connect(func(body: Node2D) -> void:
			if body.has_method("set_near_cave_entrance"):
				body.set_near_cave_entrance(false, cid)
				hint_ref.visible = false
		)

		# Hide crack when open
		if is_unlocked:
			crack.visible = false

		cave_entrances.append({
			"cave_id": cave_id,
			"x": cx,
			"root": root,
			"crack": crack,
			"opening": opening,
			"edge_left": edge_left,
			"edge_right": edge_right,
			"lintel": lintel,
			"glow": glow,
			"hint": hint,
			"area": area,
			"open": is_unlocked,
		})

func _check_cave_entrance_updates(swamp_index: int) -> void:
	for ce in cave_entrances:
		var cave_id: String = ce["cave_id"]
		if ce["open"]:
			continue
		var defn: Dictionary = GameManager.CAVE_DEFINITIONS[cave_id]
		if defn["swamp_index"] != swamp_index:
			continue
		if GameManager.is_cave_unlocked(cave_id):
			_animate_cave_crack_open(ce)

func _on_cave_unlocked(cave_id: String) -> void:
	var cave_name: String = GameManager.CAVE_DEFINITIONS[cave_id]["name"]
	_spawn_cave_unlock_notification(cave_name)
	for ce in cave_entrances:
		if ce["cave_id"] == cave_id and not ce["open"]:
			_animate_cave_crack_open(ce)

func _spawn_cave_unlock_notification(cave_name: String) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = cam.global_position if cam else Vector2(vp_size.x * 0.5, vp_size.y * 0.5)
	# World-space position near top of screen
	var nx: float = cam_pos.x
	var ny: float = cam_pos.y - vp_size.y * 0.35
	var notif := Label.new()
	notif.text = "Cave Discovered: %s!" % cave_name
	notif.add_theme_font_size_override("font_size", 16)
	notif.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	notif.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	notif.add_theme_constant_override("shadow_offset_x", 2)
	notif.add_theme_constant_override("shadow_offset_y", 2)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.custom_minimum_size = Vector2(200, 0)
	notif.position = Vector2(nx - 100, ny)
	notif.z_index = 15
	notif.pivot_offset = Vector2(100, 10)
	notif.scale = Vector2(0.3, 0.3)
	notif.modulate.a = 0.0
	add_child(notif)
	var tw := create_tween()
	tw.tween_property(notif, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(notif, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(notif, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(2.0)
	tw.tween_property(notif, "position:y", notif.position.y - 20, 0.5)
	tw.parallel().tween_property(notif, "modulate:a", 0.0, 0.5)
	tw.tween_callback(notif.queue_free)
	_screen_shake(2.0, 0.15)

func _animate_cave_crack_open(entry: Dictionary) -> void:
	if entry["open"]:
		return
	entry["open"] = true

	var root: Node2D = entry["root"]

	# Dust burst particles
	for j in range(8):
		var dust := ColorRect.new()
		dust.size = Vector2(3, 3)
		dust.color = Color(0.6, 0.5, 0.35, 0.7)
		dust.position = Vector2(randf_range(-4, 4), randf_range(-20, -8))
		dust.z_index = 5
		root.add_child(dust)
		var dtw := create_tween()
		dtw.tween_property(dust, "position", dust.position + Vector2(randf_range(-18, 18), randf_range(-20, 8)), 0.6)
		dtw.parallel().tween_property(dust, "modulate:a", 0.0, 0.6)
		dtw.tween_callback(dust.queue_free)

	# Screen shake
	_screen_shake(3.0, 0.2)

	# Reveal opening after brief delay
	var reveal_tw := create_tween()
	reveal_tw.tween_interval(0.3)
	reveal_tw.tween_callback(func() -> void:
		entry["crack"].visible = false
		entry["opening"].visible = true
		entry["edge_left"].visible = true
		entry["edge_right"].visible = true
		entry["lintel"].visible = true
		entry["glow"].visible = true
		entry["area"].monitoring = true
	)
