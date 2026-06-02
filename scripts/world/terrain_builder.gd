class_name TerrainBuilder
extends RefCounted

# Smooth, solid landmass (NOT stair-stepped voxels):
#   • rounded rolling top surface (smoothed contour + smooth shading along X)
#   • deep dig-face cross-section at the front that fills the bottom of the view
#   • extends well back in Z so it's a thick landmass that fills the frame, not a
#     floating ribbon; the back band gets forested by the scenery pass
#   • a soft grass bevel rounds the top-front edge so it isn't a razor 90°

const VIS_STEP: float = 0.6          # fine X sampling → smooth contour
const SMOOTH_PASSES: int = 5         # round off sharp corners → gentle walkable slopes
const WALL_DEPTH: float = 30.0       # dig-face depth (fills bottom of frame)
const COLLISION_DEPTH: float = 44.0
const BEVEL: float = 0.6             # rounded grass lip at the top-front edge
const BACK_RISE: float = 16.0        # land rises this much into hills behind the play band

# how much the surface lifts at a given z (0 in the play band z>=0, rising toward the back)
static func back_rise(z: float) -> float:
	if z >= 0.0:
		return 0.0
	var back: float = WorldData.FRONT_Z - WorldData.DEPTH
	var t: float = clampf(z / back, 0.0, 1.0)
	return BACK_RISE * t * t

# Swampy, grimy palette — dark mossy green-brown turf over wet muddy soil
const GRASS_A := Color(0.26, 0.32, 0.17)
const GRASS_B := Color(0.21, 0.27, 0.14)
const DIRT_TOP := Color(0.34, 0.28, 0.18)
const DIRT_BOT := Color(0.13, 0.10, 0.08)
# layered wet soil strata top→bottom (mossy mud, peat, clay, deep muck)
const STRATA: Array[Color] = [
	Color(0.33, 0.29, 0.18), Color(0.38, 0.32, 0.20), Color(0.29, 0.23, 0.15),
	Color(0.24, 0.19, 0.13), Color(0.19, 0.15, 0.11), Color(0.15, 0.12, 0.09),
	Color(0.11, 0.09, 0.07),
]

static func build(parent: Node3D) -> void:
	var pts := WorldData.TERRAIN_POINTS
	var x_start: float = pts[0].x
	var x_end: float = pts[pts.size() - 1].x
	var front_z: float = WorldData.FRONT_Z
	var back_z: float = WorldData.FRONT_Z - WorldData.DEPTH
	var front_top_z: float = front_z - BEVEL

	# sample a smooth height profile in world-x, then round the corners
	var span_px: float = VIS_STEP / WorldData.SCALE
	var n := int((x_end - x_start) / span_px) + 1
	var xs := PackedFloat32Array(); xs.resize(n)
	var hs := PackedFloat32Array(); hs.resize(n)
	for i in range(n):
		xs[i] = x_start + i * span_px
		hs[i] = WorldData.surface_y_at(xs[i])
	for _p in range(SMOOTH_PASSES):
		var src := hs.duplicate()
		for i in range(1, n - 1):
			hs[i] = src[i - 1] * 0.25 + src[i] * 0.5 + src[i + 1] * 0.25

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(n - 1):
		var x0: float = xs[i] * WorldData.SCALE
		var x1: float = xs[i + 1] * WorldData.SCALE
		var h0: float = hs[i]
		var h1: float = hs[i + 1]
		var n0 := _slope_normal(hs, xs, i)
		var n1 := _slope_normal(hs, xs, i + 1)
		var ao0 := _ao(hs, i)
		var ao1 := _ao(hs, i + 1)
		var g0 := _tint(GRASS_A if (i % 2 == 0) else GRASS_B, ao0)
		var g1 := _tint(GRASS_A if ((i + 1) % 2 == 0) else GRASS_B, ao1)

		# top grass surface — flat through the play band (front..z0), then RISES into
		# forested hills toward the back so there's never a sky-gap edge (anti-floating)
		var zbands := [front_top_z, 0.0, back_z * 0.34, back_z * 0.67, back_z]
		for zi in range(zbands.size() - 1):
			var za: float = zbands[zi]        # nearer (front)
			var zc: float = zbands[zi + 1]    # farther (back)
			var ra := back_rise(za)
			var rc := back_rise(zc)
			var zslope: float = (rc - ra) / (zc - za) if zc != za else 0.0
			var na0 := Vector3(n0.x, n0.y, -zslope).normalized()
			var na1 := Vector3(n1.x, n1.y, -zslope).normalized()
			var sh: float = 1.0 - 0.14 * clampf(-zc / maxf(-back_z, 0.001), 0.0, 1.0)
			var c0 := _tint(g0, sh)
			var c1 := _tint(g1, sh)
			_quad_n(st,
				Vector3(x0, h0 + rc, zc), Vector3(x1, h1 + rc, zc),
				Vector3(x1, h1 + ra, za), Vector3(x0, h0 + ra, za),
				c0, c1, c1, c0, na0, na1, na1, na0)

		# soft grass bevel rolling over the front edge
		var nb0 := (n0 + Vector3(0, 0, 1)).normalized()
		var nb1 := (n1 + Vector3(0, 0, 1)).normalized()
		_quad_n(st,
			Vector3(x0, h0, front_top_z), Vector3(x1, h1, front_top_z),
			Vector3(x1, h1 - BEVEL, front_z), Vector3(x0, h0 - BEVEL, front_z),
			g0, g1, _tint(g1, 0.9), _tint(g0, 0.9), n0, n1, nb1, nb0)

		# deep dig-face cross-section (flat-shaded) with layered soil strata
		var ftop0 := h0 - BEVEL
		var ftop1 := h1 - BEVEL
		var fb := front_z
		var nb := STRATA.size()
		# gently wavy strata boundaries (subtle, geological)
		var wob: float = sin(x0 * 0.6) * 0.5
		for bi in range(nb):
			var t0 := float(bi) / nb
			var t1 := float(bi + 1) / nb
			var ct := STRATA[bi]
			var cb := ct.darkened(0.06)
			_face(st, x0, x1,
				lerpf(ftop0, ftop0 - WALL_DEPTH, t0) + (wob if bi > 0 else 0.0),
				lerpf(ftop1, ftop1 - WALL_DEPTH, t0) + (wob if bi > 0 else 0.0),
				lerpf(ftop0, ftop0 - WALL_DEPTH, t1) + (wob if bi < nb - 1 else 0.0),
				lerpf(ftop1, ftop1 - WALL_DEPTH, t1) + (wob if bi < nb - 1 else 0.0),
				fb, ct, cb)

	# side end caps
	_cap(st, xs[0] * WorldData.SCALE, hs[0], front_z, back_z, Vector3.LEFT)
	_cap(st, xs[n - 1] * WorldData.SCALE, hs[n - 1], front_z, back_z, Vector3.RIGHT)

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	parent.add_child(mi)

	# smooth walkable collision: a trimesh of the rounded top surface (no steps to snag on)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	parent.add_child(body)
	var z_lo := -8.0
	var z_hi := WorldData.FRONT_Z
	var faces := PackedVector3Array()
	for i in range(n - 1):
		var x0 := xs[i] * WorldData.SCALE
		var x1 := xs[i + 1] * WorldData.SCALE
		var a := Vector3(x0, hs[i], z_lo)
		var b := Vector3(x1, hs[i + 1], z_lo)
		var c := Vector3(x1, hs[i + 1], z_hi)
		var d := Vector3(x0, hs[i], z_hi)
		faces.append_array([a, b, c, a, c, d])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

	_build_path(parent, xs, hs)

# Worn muddy walking path along the player's rail (z=0), draped over the surface
const PATH_HALF := 1.9
const PATH_MUD := Color(0.17, 0.13, 0.09)    # dark wet trodden mud
const PATH_EDGE := Color(0.27, 0.22, 0.14)   # lighter churned earth at the edges

static func _build_path(parent: Node3D, xs: PackedFloat32Array, hs: PackedFloat32Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := xs.size()
	for i in range(n - 1):
		var x0 := xs[i] * WorldData.SCALE
		var x1 := xs[i + 1] * WorldData.SCALE
		# slight worn wobble on the path edges
		var w0 := PATH_HALF * (0.85 + 0.15 * sin(xs[i] * 0.5))
		var w1 := PATH_HALF * (0.85 + 0.15 * sin(xs[i + 1] * 0.5))
		var y0 := hs[i] + 0.04
		var y1 := hs[i + 1] + 0.04
		# centre strip (dark wet mud) + two lighter edge strips that blend to turf
		_strip(st, x0, x1, y0, y1, -w0 * 0.5, w0 * 0.5, -w1 * 0.5, w1 * 0.5, PATH_MUD, PATH_MUD)
		_strip(st, x0, x1, y0, y1, w0 * 0.5, w0, w1 * 0.5, w1, PATH_MUD, PATH_EDGE)
		_strip(st, x0, x1, y0, y1, -w0, -w0 * 0.5, -w1, -w1 * 0.5, PATH_EDGE, PATH_MUD)
	var mi := MeshInstance3D.new()
	mi.name = "Path"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6      # wet-mud sheen
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	parent.add_child(mi)

static func _strip(st: SurfaceTool, x0: float, x1: float, y0: float, y1: float,
		za0: float, zb0: float, za1: float, zb1: float, ca: Color, cb: Color) -> void:
	var p00 := Vector3(x0, y0, za0)
	var p01 := Vector3(x0, y0, zb0)
	var p11 := Vector3(x1, y1, zb1)
	var p10 := Vector3(x1, y1, za1)
	for item in [[p00, ca], [p01, cb], [p11, cb], [p00, ca], [p11, cb], [p10, ca]]:
		st.set_color(item[1]); st.set_normal(Vector3.UP); st.add_vertex(item[0])

# smoothed surface height in 3D units at an original-x (used for collision + prop placement)
static func surface_height(orig_x: float) -> float:
	return WorldData.surface_y_at(orig_x)

static func _slope_normal(hs: PackedFloat32Array, xs: PackedFloat32Array, i: int) -> Vector3:
	var a: int = maxi(i - 1, 0)
	var b: int = mini(i + 1, hs.size() - 1)
	var dy: float = hs[b] - hs[a]
	var dx: float = (xs[b] - xs[a]) * WorldData.SCALE
	if dx == 0.0:
		return Vector3.UP
	return Vector3(-dy / dx, 1.0, 0.0).normalized()

static func _ao(hs: PackedFloat32Array, i: int) -> float:
	var a: int = maxi(i - 1, 0)
	var b: int = mini(i + 1, hs.size() - 1)
	var rel: float = hs[i] - (hs[a] + hs[b]) * 0.5
	return clampf(1.0 + rel * 0.16, 0.8, 1.06)

static func _tint(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, 1.0)

static func _face(st: SurfaceTool, x0: float, x1: float, ty0: float, ty1: float, by0: float, by1: float, z: float, ctop: Color, cbot: Color) -> void:
	_quad_n(st, Vector3(x0, ty0, z), Vector3(x1, ty1, z), Vector3(x1, by1, z), Vector3(x0, by0, z),
		ctop, ctop, cbot, cbot, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK)

static func _cap(st: SurfaceTool, x: float, h: float, front_z: float, back_z: float, nrm: Vector3) -> void:
	var by := h - WALL_DEPTH
	if nrm == Vector3.LEFT:
		_quad_n(st, Vector3(x, h, back_z), Vector3(x, h, front_z), Vector3(x, by, front_z), Vector3(x, by, back_z),
			DIRT_TOP, DIRT_TOP, DIRT_BOT, DIRT_BOT, nrm, nrm, nrm, nrm)
	else:
		_quad_n(st, Vector3(x, h, front_z), Vector3(x, h, back_z), Vector3(x, by, back_z), Vector3(x, by, front_z),
			DIRT_TOP, DIRT_TOP, DIRT_BOT, DIRT_BOT, nrm, nrm, nrm, nrm)

static func _quad_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	var v := [a, b, c, a, c, d]
	var cols := [ca, cb, cc, ca, cc, cd]
	var nrm := [na, nb, nc, na, nc, nd]
	for i in range(6):
		st.set_color(cols[i]); st.set_normal(nrm[i]); st.add_vertex(v[i])
