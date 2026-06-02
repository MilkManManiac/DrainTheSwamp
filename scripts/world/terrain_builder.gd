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

const GRASS_A := Color(0.32, 0.46, 0.21)
const GRASS_B := Color(0.28, 0.42, 0.19)
const DIRT_TOP := Color(0.49, 0.37, 0.24)
const DIRT_BOT := Color(0.18, 0.13, 0.10)
# layered soil strata top→bottom (topsoil, sandy, loam, clay, deep clay, bedrock-ish)
const STRATA: Array[Color] = [
	Color(0.50, 0.38, 0.25), Color(0.57, 0.46, 0.31), Color(0.45, 0.33, 0.21),
	Color(0.38, 0.28, 0.18), Color(0.30, 0.22, 0.15), Color(0.23, 0.17, 0.12),
	Color(0.17, 0.13, 0.10),
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

		# rounded top grass surface (smooth-shaded across X)
		_quad_n(st,
			Vector3(x0, h0, back_z), Vector3(x1, h1, back_z),
			Vector3(x1, h1, front_top_z), Vector3(x0, h0, front_top_z),
			g0, g1, g1, g0, n0, n1, n1, n0)

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
