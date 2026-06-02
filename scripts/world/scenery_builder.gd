class_name SceneryBuilder
extends RefCounted

# Adds environmental depth + detail on top of the bare voxel terrain:
#   • layered background ridges (far mountains → near hills) fading into fog
#   • soft low-poly clouds
#   • scattered surface props (trees, rocks, grass tufts, flowers) via MultiMesh
# All deterministic (seeded) so the world is stable between runs.

const RNG_SEED: int = 13377

# Background ridge palette (blue far → green near = atmospheric depth)
const FAR_MTN := Color(0.50, 0.58, 0.76)
const MID_MTN := Color(0.43, 0.56, 0.58)
const NEAR_HILL := Color(0.35, 0.50, 0.35)

static func _rng(seed_add: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = RNG_SEED + seed_add
	return r

# ── Background ───────────────────────────────────────────────────────────────────
static func build_background(parent: Node3D) -> Node3D:
	var bg := Node3D.new()
	bg.name = "Background"
	parent.add_child(bg)

	var x0: float = WorldData.TERRAIN_POINTS[0].x * WorldData.SCALE - 60.0
	var x1: float = WorldData.TERRAIN_POINTS[WorldData.TERRAIN_POINTS.size() - 1].x * WorldData.SCALE + 60.0

	# far mountains (jagged blue) → mid → low green hills, near the horizon band
	_ridge(bg, x0, x1, -46.0, 2.0, 7.0, 14.0, 20.0, FAR_MTN, 1)
	_ridge(bg, x0, x1, -30.0, -1.0, 4.0, 9.0, 22.0, MID_MTN, 2)
	_ridge(bg, x0, x1, -17.0, -4.0, 2.0, 6.0, 14.0, NEAR_HILL, 3)
	_build_bg_trees(bg, x0, x1)
	_build_clouds(bg, x0, x1)
	return bg

static func _build_bg_trees(parent: Node3D, x0: float, x1: float) -> void:
	# dark forested silhouettes sitting on the near hill line
	var r := _rng(9)
	var tf: Array[Transform3D] = []
	var x := x0
	while x < x1:
		x += r.randf_range(2.5, 6.0)
		var hy: float = -4.0 + r.randf_range(1.0, 4.0)
		var s := r.randf_range(0.8, 1.6)
		tf.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, hy, -17.0 + r.randf_range(-1.0, 1.0))))
	if tf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bg_tree_mesh()
	mm.instance_count = tf.size()
	for i in range(tf.size()):
		mm.set_instance_transform(i, tf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BgTrees"
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = mat
	parent.add_child(mmi)

static func _bg_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.32, 0.45, 0.42)
	_box(st, Vector3(0, 1.2, 0), Vector3(1.4, 2.4, 1.0), c)
	_box(st, Vector3(0, 2.4, 0), Vector3(0.9, 1.4, 0.7), c)
	return st.commit()

static func _ridge(parent: Node3D, x0: float, x1: float, z: float, base_y: float,
		hmin: float, hmax: float, spacing: float, col: Color, seed_add: int) -> void:
	var r := _rng(seed_add)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# sample a jagged skyline, build a filled curtain from base down
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var x := x0
	while x <= x1:
		xs.append(x)
		ys.append(base_y + r.randf_range(hmin, hmax))
		x += r.randf_range(spacing * 0.6, spacing * 1.4)
	if xs[xs.size() - 1] < x1:
		xs.append(x1); ys.append(base_y + r.randf_range(hmin, hmax))
	var bottom := base_y - 60.0
	for i in range(xs.size() - 1):
		var ax := xs[i]; var ay := ys[i]
		var bx := xs[i + 1]; var by := ys[i + 1]
		# slight vertical color gradient for soft volume
		var ctop := col
		var cbot := col.darkened(0.12)
		for tri in [[Vector3(ax, ay, z), ctop], [Vector3(bx, by, z), ctop], [Vector3(bx, bottom, z), cbot],
				[Vector3(ax, ay, z), ctop], [Vector3(bx, bottom, z), cbot], [Vector3(ax, bottom, z), cbot]]:
			st.set_color(tri[1]); st.set_normal(Vector3.BACK); st.add_vertex(tri[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # flat silhouette; fog gives depth
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	parent.add_child(mi)

static func _build_clouds(parent: Node3D, x0: float, x1: float) -> void:
	var r := _rng(7)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in range(n):
		var cx := lerpf(x0, x1, float(i) / n) + r.randf_range(-10, 10)
		var cy := r.randf_range(3.5, 9.0)
		var cz := r.randf_range(-34.0, -20.0)
		# a soft puff = 4-5 overlapping flattened boxes
		var puffs := r.randi_range(4, 5)
		for p in range(puffs):
			var pw := r.randf_range(5, 11)
			var ph := r.randf_range(1.8, 3.0)
			var oxx := r.randf_range(-6, 6)
			var oy := r.randf_range(-1.0, 1.2)
			_box(st, Vector3(cx + oxx, cy + oy, cz), Vector3(pw, ph, pw * 0.7), Color(0.98, 0.99, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.9)
	mi.material_override = mat
	parent.add_child(mi)

# ── Surface props (trees, rocks, grass, flowers, bushes, mushrooms, logs) ────────
static func build_surface_props(parent: Node3D) -> void:
	var x_start: float = WorldData.TERRAIN_POINTS[0].x
	var x_end: float = WorldData.TERRAIN_POINTS[WorldData.TERRAIN_POINTS.size() - 1].x

	var tree_tf: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	var pine_tf: Array[Transform3D] = []
	var pine_cols: Array[Color] = []
	var bush_tf: Array[Transform3D] = []
	var rock_tf: Array[Transform3D] = []
	var grass_tf: Array[Transform3D] = []
	var fern_tf: Array[Transform3D] = []
	var mush_tf: Array[Transform3D] = []
	var log_tf: Array[Transform3D] = []
	var flower_tf: Array[Transform3D] = []
	var flower_cols: Array[Color] = []
	var cypress_tf: Array[Transform3D] = []
	var cypress_cols: Array[Color] = []
	var snag_tf: Array[Transform3D] = []
	var palm_tf: Array[Transform3D] = []

	# props spread across the whole landmass depth (front toward camera → forested back)
	var pzb := WorldData.FRONT_Z - WorldData.DEPTH + 1.0
	var pzf := WorldData.FRONT_Z - 0.5
	var r := _rng(20)
	var ox := x_start
	# keep tall props off the walking path corridor (z ≈ 0)
	var PATH_CLEAR := 3.6
	while ox < x_end:
		ox += r.randf_range(1.5, 3.0)
		if WorldData.in_pool(ox):
			continue
		var wx: float = ox * WorldData.SCALE
		var sy: float = TerrainBuilder.surface_height(ox)
		var pz: float = WorldData.path_z(wx)   # winding path centre at this x
		var near_water: bool = WorldData.in_pool(ox - 30.0) or WorldData.in_pool(ox + 30.0)

		var forest: bool = ox < 90.0
		var tree_chance: float = 0.22 if forest else 0.05
		if r.randf() < tree_chance:
			var z := r.randf_range(pzb, pzf - 2.0)
			if absf(z - pz) >= PATH_CLEAR:   # never plant a tree on the path
				var s := r.randf_range(0.7, 1.4)
				var tf := Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(s, s, s)), Vector3(wx, sy, z))
				var v := r.randf_range(0.80, 1.12)
				var tint := Color(v * r.randf_range(0.9, 1.05), v, v * r.randf_range(0.78, 0.97))
				if r.randf() < 0.4:
					pine_tf.append(tf)
					pine_cols.append(tint)
				else:
					tree_tf.append(tf)
					tree_cols.append(tint)

		if r.randf() < 0.14:
			var bz := r.randf_range(pzb, pzf)
			if absf(bz - pz) >= PATH_CLEAR - 1.0:
				var bs := r.randf_range(0.7, 1.3)
				bush_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(bs, bs, bs)), Vector3(wx, sy, bz)))

		# LUSH grass — many tufts per step (kept off the walking path)
		for _g in range(r.randi_range(5, 11)):
			var gz := r.randf_range(pzb, pzf)
			if absf(gz - pz) < 2.2:
				continue
			var gs := r.randf_range(0.6, 1.4)
			grass_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(gs, gs, gs)),
				Vector3(wx + r.randf_range(-1.2, 1.2), sy, gz)))

		# ferns — common ground cover everywhere (denser near water/forest)
		if r.randf() < (0.45 if (near_water or forest) else 0.22):
			var fz := r.randf_range(pzb, pzf)
			if absf(fz - pz) >= 2.2:
				var fs := r.randf_range(0.75, 1.35)
				fern_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(fs, fs, fs)), Vector3(wx, sy, fz)))

		if r.randf() < 0.32:
			var flz := r.randf_range(pzb, pzf)
			if absf(flz - pz) >= 2.0:
				flower_tf.append(Transform3D(Basis(), Vector3(wx, sy, flz)))
				flower_cols.append(_FLOWER_COLS[r.randi() % _FLOWER_COLS.size()])

		# CYPRESS — bayou signature; loves the waterside, scattered elsewhere, off path
		if r.randf() < (0.18 if near_water else 0.05):
			var cz := r.randf_range(pzb, pzf - 2.0)
			if absf(cz - pz) >= PATH_CLEAR:
				var cs := r.randf_range(0.85, 1.5)
				cypress_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(cs, cs, cs)), Vector3(wx, sy, cz)))
				var cv := r.randf_range(0.85, 1.1)
				cypress_cols.append(Color(cv, cv * r.randf_range(0.97, 1.04), cv * 0.92))

		# dead snag — occasional grey skeleton
		if r.randf() < 0.035:
			var nz := r.randf_range(pzb, pzf - 2.0)
			if absf(nz - pz) >= PATH_CLEAR:
				var ns := r.randf_range(0.8, 1.3)
				snag_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ns, ns, ns)), Vector3(wx, sy, nz)))

		# palmetto fan — low, clumps near water/forest, can sit closer to the path
		if r.randf() < (0.20 if (near_water or forest) else 0.08):
			var palz := r.randf_range(pzb, pzf)
			if absf(palz - pz) >= 2.4:
				var ps := r.randf_range(0.8, 1.35)
				palm_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ps, ps, ps)), Vector3(wx, sy, palz)))

		if r.randf() < 0.10:
			var mz := r.randf_range(pzb, pzf)
			if absf(mz - pz) >= 2.0:
				mush_tf.append(Transform3D(Basis().scaled(Vector3.ONE * r.randf_range(0.8, 1.3)), Vector3(wx, sy, mz)))

		if r.randf() < 0.06:
			var rz := r.randf_range(pzb, pzf)
			if absf(rz - pz) >= 2.2:
				rock_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(r.randf_range(0.5, 1.4), r.randf_range(0.4, 1.0), r.randf_range(0.5, 1.4))), Vector3(wx, sy, rz)))

		if r.randf() < 0.025:
			var lz := r.randf_range(pzb, pzf - 2.0)
			if absf(lz - pz) >= PATH_CLEAR:
				log_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(-0.3, 0.3)), Vector3(wx, sy + 0.15, lz)))

	_spawn_mm(parent, "Trees", _tree_mesh(), tree_tf, tree_cols, 0.035)
	_spawn_mm(parent, "Pines", _pine_mesh(), pine_tf, pine_cols, 0.02)
	_spawn_mm(parent, "Cypress", _cypress_mesh(), cypress_tf, cypress_cols, 0.03)
	_spawn_mm(parent, "Snags", _snag_mesh(), snag_tf, [], 0.02)
	_spawn_mm(parent, "Palmettos", _palmetto_mesh(), palm_tf, [], 0.07)
	_spawn_mm(parent, "Bushes", _bush_mesh(), bush_tf, [], 0.05)
	_spawn_mm(parent, "Logs", _log_mesh(), log_tf)
	_spawn_mm(parent, "Rocks", _rock_mesh(), rock_tf)
	_spawn_mm(parent, "Ferns", _fern_mesh(), fern_tf, [], 0.09)
	_spawn_mm(parent, "GrassTufts", _grass_mesh(), grass_tf, [], 0.11)
	_spawn_mm(parent, "Mushrooms", _mushroom_mesh(), mush_tf)
	_spawn_mm(parent, "Flowers", _flower_mesh(), flower_tf, flower_cols, 0.10)

const _FLOWER_COLS: Array[Color] = [
	Color(0.95, 0.95, 0.92), Color(0.97, 0.82, 0.30),
	Color(0.90, 0.45, 0.55), Color(0.70, 0.55, 0.85), Color(0.95, 0.60, 0.35),
]

const FOLIAGE_SHADER = preload("res://shaders/foliage.gdshader")

static func _spawn_mm(parent: Node3D, nm: String, mesh: Mesh, tfs: Array[Transform3D], cols: Array[Color] = [], sway: float = 0.0) -> void:
	if tfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = tfs.size()
	for i in range(tfs.size()):
		mm.set_instance_transform(i, tfs[i])
		if not cols.is_empty():
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	if sway > 0.0:
		var smat := ShaderMaterial.new()
		smat.shader = FOLIAGE_SHADER
		smat.set_shader_parameter("sway_strength", sway)
		mmi.material_override = smat
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.92
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mmi.material_override = mat
	parent.add_child(mmi)

static func _tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.40, 0.29, 0.18)
	var lo := Color(0.24, 0.40, 0.21)
	var hi := Color(0.36, 0.55, 0.29)
	_cyl(st, Vector3(0, 0, 0), 0.26, 0.20, 1.8, trunk, trunk.darkened(0.15))
	_sphere(st, Vector3(0, 2.3, 0), Vector3(1.15, 1.05, 1.15), 5, 8, hi, lo)
	_sphere(st, Vector3(0.55, 2.85, 0.1), Vector3(0.8, 0.78, 0.8), 4, 7, hi, lo)
	_sphere(st, Vector3(-0.45, 2.7, -0.15), Vector3(0.78, 0.74, 0.78), 4, 7, hi, lo)
	_sphere(st, Vector3(0.1, 3.35, 0.05), Vector3(0.72, 0.7, 0.72), 4, 7, hi, lo)
	return st.commit()

static func _rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := Color(0.50, 0.49, 0.50)
	var rock2 := Color(0.44, 0.43, 0.45)
	_box(st, Vector3(0, 0.24, 0), Vector3(1.0, 0.5, 0.8), rock)
	_box(st, Vector3(0.28, 0.42, 0.12), Vector3(0.55, 0.42, 0.55), rock2)
	return st.commit()

static func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# lush tapered blades, mossy-swamp gradient (dark wet base → pale mossy tip)
	var base_c := Color(0.18, 0.24, 0.12)
	var tip_c := Color(0.44, 0.50, 0.25)
	var blades := 7
	for i in range(blades):
		var ang := TAU * float(i) / blades + float(i) * 0.7
		var rad := 0.08 + float(i % 3) * 0.05
		var bx := cos(ang) * rad
		var bz := sin(ang) * rad
		var h := 0.55 + float(i % 4) * 0.12
		var lean := 0.18 + float(i % 2) * 0.1
		_blade(st, Vector3(bx, 0, bz), h, Vector3(cos(ang) * lean, 0, sin(ang) * lean), base_c, tip_c)
	return st.commit()

static func _blade(st: SurfaceTool, base: Vector3, height: float, lean: Vector3, cbase: Color, ctip: Color) -> void:
	var w := 0.045
	var perp := Vector3(-lean.z, 0, lean.x).normalized() * w
	if perp.length() < 0.001:
		perp = Vector3(w, 0, 0)
	var tip := base + Vector3(lean.x, height, lean.z)
	var nrm := Vector3(lean.x, 0.6, lean.z).normalized()
	for item in [[base - perp, cbase], [base + perp, cbase], [tip, ctip]]:
		st.set_color(item[1]); st.set_normal(nrm); st.add_vertex(item[0])

static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# stem (green) + blossom (white → tinted per-instance via MultiMesh color)
	_box(st, Vector3(0, 0.22, 0), Vector3(0.06, 0.44, 0.06), Color(0.34, 0.5, 0.24))
	_box(st, Vector3(0, 0.5, 0), Vector3(0.26, 0.16, 0.26), Color(1, 1, 1))
	return st.commit()

static func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.38, 0.27, 0.16)
	var lo := Color(0.20, 0.36, 0.21)
	var hi := Color(0.30, 0.48, 0.27)
	_cyl(st, Vector3(0, 0, 0), 0.2, 0.16, 1.1, trunk, trunk.darkened(0.15))
	_cone(st, Vector3(0, 1.0, 0), 1.25, 1.5, 9, hi, lo)
	_cone(st, Vector3(0, 1.95, 0), 1.0, 1.35, 9, hi, lo)
	_cone(st, Vector3(0, 2.85, 0), 0.72, 1.2, 9, hi, lo)
	return st.commit()

static func _bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := Color(0.26, 0.42, 0.23)
	var hi := Color(0.34, 0.52, 0.29)
	_sphere(st, Vector3(0, 0.42, 0), Vector3(0.7, 0.5, 0.65), 4, 7, hi, lo)
	_sphere(st, Vector3(0.42, 0.5, 0.1), Vector3(0.5, 0.46, 0.5), 4, 6, hi, lo)
	_sphere(st, Vector3(-0.34, 0.46, -0.08), Vector3(0.46, 0.42, 0.46), 4, 6, hi, lo)
	return st.commit()

# rounded ellipsoid blob with smooth normals + vertical gradient
static func _sphere(st: SurfaceTool, c: Vector3, rad: Vector3, rings: int, segs: int, top: Color, bot: Color) -> void:
	for ri in range(rings):
		var p0: float = PI * float(ri) / rings
		var p1: float = PI * float(ri + 1) / rings
		var ca := top.lerp(bot, float(ri) / rings)
		var cb := top.lerp(bot, float(ri + 1) / rings)
		for si in range(segs):
			var t0: float = TAU * float(si) / segs
			var t1: float = TAU * float(si + 1) / segs
			var a := _spt(c, rad, p0, t0)
			var b := _spt(c, rad, p1, t0)
			var d := _spt(c, rad, p1, t1)
			var e := _spt(c, rad, p0, t1)
			for item in [[a, ca], [b, cb], [d, cb], [a, ca], [d, cb], [e, ca]]:
				st.set_color(item[1])
				st.set_normal((item[0] - c).normalized())
				st.add_vertex(item[0])

static func _spt(c: Vector3, rad: Vector3, phi: float, theta: float) -> Vector3:
	return c + Vector3(rad.x * sin(phi) * cos(theta), rad.y * cos(phi), rad.z * sin(phi) * sin(theta))

static func _cone(st: SurfaceTool, base: Vector3, radius: float, height: float, segs: int, top: Color, bot: Color) -> void:
	var apex := base + Vector3(0, height, 0)
	for si in range(segs):
		var t0: float = TAU * float(si) / segs
		var t1: float = TAU * float(si + 1) / segs
		var b0 := base + Vector3(cos(t0) * radius, 0, sin(t0) * radius)
		var b1 := base + Vector3(cos(t1) * radius, 0, sin(t1) * radius)
		var nrm := ((b0 + b1) * 0.5 - base + Vector3(0, radius * 0.4, 0)).normalized()
		for item in [[apex, top], [b1, bot], [b0, bot]]:
			st.set_color(item[1]); st.set_normal(nrm); st.add_vertex(item[0])

static func _cyl(st: SurfaceTool, base: Vector3, r_top: float, r_bot: float, height: float, ctop: Color, cbot: Color) -> void:
	var segs := 6
	var top_y := base.y + height
	for si in range(segs):
		var t0: float = TAU * float(si) / segs
		var t1: float = TAU * float(si + 1) / segs
		var bt0 := base + Vector3(cos(t0) * r_bot, 0, sin(t0) * r_bot)
		var bt1 := base + Vector3(cos(t1) * r_bot, 0, sin(t1) * r_bot)
		var tp0 := Vector3(base.x + cos(t0) * r_top, top_y, base.z + sin(t0) * r_top)
		var tp1 := Vector3(base.x + cos(t1) * r_top, top_y, base.z + sin(t1) * r_top)
		var n0 := Vector3(cos(t0), 0.2, sin(t0)).normalized()
		var n1 := Vector3(cos(t1), 0.2, sin(t1)).normalized()
		st.set_color(cbot); st.set_normal(n0); st.add_vertex(bt0)
		st.set_color(cbot); st.set_normal(n1); st.add_vertex(bt1)
		st.set_color(ctop); st.set_normal(n1); st.add_vertex(tp1)
		st.set_color(cbot); st.set_normal(n0); st.add_vertex(bt0)
		st.set_color(ctop); st.set_normal(n1); st.add_vertex(tp1)
		st.set_color(ctop); st.set_normal(n0); st.add_vertex(tp0)

# ── Bayou foliage: cypress (flared trunk + knees + Spanish moss), dead snag, palmetto ──
static func _cypress_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.34, 0.27, 0.19)
	var barkd := Color(0.22, 0.17, 0.12)
	var lo := Color(0.24, 0.33, 0.21)
	var hi := Color(0.33, 0.44, 0.27)
	var moss := Color(0.56, 0.59, 0.47)   # ghostly grey-green Spanish moss
	# flared buttress base → tall slender trunk
	_cyl(st, Vector3(0, 0, 0), 0.32, 0.75, 1.3, bark, barkd)
	_cyl(st, Vector3(0, 1.3, 0), 0.2, 0.32, 4.2, bark, barkd)
	# cypress "knees" poking up around the base
	for k in range(5):
		var ka := float(k) * TAU / 5.0 + 0.4
		var kr := 0.75 + (k % 2) * 0.25
		_cone(st, Vector3(cos(ka) * kr, 0, sin(ka) * kr), 0.13, 0.3 + (k % 3) * 0.12, 5, bark, barkd)
	# sparse, wispy canopy high up
	_sphere(st, Vector3(0, 5.7, 0), Vector3(1.45, 0.85, 1.45), 4, 8, hi, lo)
	_sphere(st, Vector3(0.6, 6.2, 0.2), Vector3(0.85, 0.7, 0.85), 4, 7, hi, lo)
	_sphere(st, Vector3(-0.55, 6.0, -0.25), Vector3(0.8, 0.65, 0.8), 4, 7, hi, lo)
	# hanging Spanish moss strands draping from the canopy
	for m in range(10):
		var ma := float(m) * TAU / 10.0
		var mr := 1.0 + (m % 3) * 0.25
		var mx := cos(ma) * mr
		var mz := sin(ma) * mr
		var ml := 0.9 + (m % 4) * 0.45
		_box(st, Vector3(mx, 5.3 - ml * 0.5, mz), Vector3(0.09, ml, 0.09), moss)
	return st.commit()

static func _snag_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dead := Color(0.44, 0.40, 0.33)
	var deadd := Color(0.30, 0.27, 0.22)
	_cyl(st, Vector3(0, 0, 0), 0.16, 0.42, 4.3, dead, deadd)
	# a few broken bare branch stubs near the top
	_box(st, Vector3(0.7, 3.4, 0), Vector3(1.3, 0.14, 0.14), deadd)
	_box(st, Vector3(-0.5, 3.9, 0.1), Vector3(0.9, 0.12, 0.12), deadd)
	_box(st, Vector3(0.15, 4.2, -0.5), Vector3(0.12, 0.12, 0.9), deadd)
	# a wisp of moss on the dead branch
	_box(st, Vector3(1.1, 2.9, 0), Vector3(0.08, 0.8, 0.08), Color(0.54, 0.56, 0.46))
	return st.commit()

static func _palmetto_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := Color(0.22, 0.36, 0.18)
	var hi := Color(0.34, 0.5, 0.26)
	# low fan of broad fronds splaying out + up
	for i in range(9):
		var ang := float(i) * TAU / 9.0 + float(i) * 0.3
		var lean := 1.0 + (i % 3) * 0.2
		_frond(st, Vector3(0, 0.15, 0), 1.3 + (i % 2) * 0.3, Vector3(cos(ang) * lean, 0.7, sin(ang) * lean), lo, hi)
	return st.commit()

# a broad tapered frond/leaf (wider than a grass blade)
static func _frond(st: SurfaceTool, base: Vector3, length: float, dir: Vector3, cbase: Color, ctip: Color) -> void:
	var d := dir.normalized()
	var perp := Vector3(-d.z, 0, d.x).normalized() * 0.16
	var tip := base + d * length
	var mid := base + d * (length * 0.5) + Vector3(0, 0.12, 0)
	var nrm := Vector3(d.x, 0.7, d.z).normalized()
	# two triangles base→mid, then mid→tip
	for tri in [[base - perp, cbase, base + perp, cbase, mid + perp * 0.6, ctip],
			[base - perp, cbase, mid + perp * 0.6, ctip, mid - perp * 0.6, ctip],
			[mid - perp * 0.6, ctip, mid + perp * 0.6, ctip, tip, ctip]]:
		st.set_color(tri[1]); st.set_normal(nrm); st.add_vertex(tri[0])
		st.set_color(tri[3]); st.set_normal(nrm); st.add_vertex(tri[2])
		st.set_color(tri[5]); st.set_normal(nrm); st.add_vertex(tri[4])

static func _fern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frond := Color(0.26, 0.46, 0.22)
	# splayed blades leaning outward
	for i in range(5):
		var ang := -0.6 + i * 0.3
		var bx := sin(ang) * 0.35
		_box(st, Vector3(bx, 0.45, cos(ang) * 0.05), Vector3(0.12, 0.95, 0.12), frond)
	return st.commit()

static func _mushroom_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0.16, 0), Vector3(0.12, 0.32, 0.12), Color(0.90, 0.86, 0.78))  # stem
	_box(st, Vector3(0, 0.34, 0), Vector3(0.34, 0.16, 0.34), Color(0.78, 0.26, 0.22))  # red cap
	return st.commit()

static func _log_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.36, 0.26, 0.16)
	var ring := Color(0.55, 0.42, 0.28)
	_box(st, Vector3(0, 0.22, 0), Vector3(2.0, 0.44, 0.44), bark)
	_box(st, Vector3(1.0, 0.22, 0), Vector3(0.06, 0.4, 0.4), ring)
	_box(st, Vector3(-1.0, 0.22, 0), Vector3(0.06, 0.4, 0.4), ring)
	return st.commit()

# ── Forest walls bounding the play corridor (RPG-map style: frame is all terrain) ──
static func build_tree_walls(parent: Node3D) -> void:
	var x_start: float = WorldData.TERRAIN_POINTS[0].x
	var x_end: float = WorldData.TERRAIN_POINTS[WorldData.TERRAIN_POINTS.size() - 1].x
	var tree_tf: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	var pine_tf: Array[Transform3D] = []
	var pine_cols: Array[Color] = []
	var r := _rng(50)
	var ox := x_start
	while ox < x_end:
		ox += r.randf_range(2.4, 4.6)
		var wx: float = ox * WorldData.SCALE
		var sy: float = TerrainBuilder.surface_height(ox)
		# a deep, dense band of big trees behind the corridor → fills the top of frame
		for _t in range(r.randi_range(1, 2)):
			var z := r.randf_range(-22.0, -12.0)
			var s := r.randf_range(1.4, 2.3)
			var tf := Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(s, s, s)), Vector3(wx, sy, z))
			# darker, receding into shade
			var d := r.randf_range(0.6, 0.85)
			var tint := Color(d * 0.95, d, d * 0.85)
			if r.randf() < 0.45:
				pine_tf.append(tf)
				pine_cols.append(tint)
			else:
				tree_tf.append(tf)
				tree_cols.append(tint)
	_spawn_mm(parent, "WallTrees", _tree_mesh(), tree_tf, tree_cols, 0.02)
	_spawn_mm(parent, "WallPines", _pine_mesh(), pine_tf, pine_cols, 0.015)

# ── Water-edge props (reeds, lily pads) ──────────────────────────────────────────
static func build_water_props(parent: Node3D) -> void:
	var reed_tf: Array[Transform3D] = []
	var pad_tf: Array[Transform3D] = []
	var r := _rng(40)
	for i in range(WorldData.SWAMP_COUNT):
		var rng: Array = WorldData.SWAMP_RANGES[i]
		var ea: Vector2 = WorldData.TERRAIN_POINTS[rng[0]]
		var eb: Vector2 = WorldData.TERRAIN_POINTS[rng[1]]
		var wx0: float = ea.x * WorldData.SCALE
		var wx1: float = eb.x * WorldData.SCALE
		var water_y: float = WorldData.elev(minf(ea.y, eb.y)) - 0.45

		var pads: int = clampi(int((wx1 - wx0) * 0.5), 2, 16)
		for _p in range(pads):
			var px := r.randf_range(wx0 + 0.6, wx1 - 0.6)
			var ps := r.randf_range(0.7, 1.35)
			pad_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ps, 1.0, ps)),
				Vector3(px, water_y + 0.04, r.randf_range(WorldData.FRONT_Z - WorldData.DEPTH + 2.0, WorldData.FRONT_Z - 2.0))))

		for edge_x in [ea.x, eb.x]:
			for _c in range(r.randi_range(2, 4)):
				var ex: float = edge_x + r.randf_range(-7.0, 7.0)
				var sy: float = TerrainBuilder.surface_height(ex)
				reed_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3.ONE * r.randf_range(0.8, 1.3)),
					Vector3(ex * WorldData.SCALE, sy, r.randf_range(WorldData.FRONT_Z - WorldData.DEPTH + 2.0, WorldData.FRONT_Z - 2.0))))

	_spawn_mm(parent, "LilyPads", _lilypad_mesh(), pad_tf)
	_spawn_mm(parent, "Reeds", _reed_mesh(), reed_tf, [], 0.08)

# ── Dig-face detail (pebbles, roots, strata) ─────────────────────────────────────
static func build_digface_detail(parent: Node3D) -> void:
	var x_start: float = WorldData.TERRAIN_POINTS[0].x
	var x_end: float = WorldData.TERRAIN_POINTS[WorldData.TERRAIN_POINTS.size() - 1].x
	var zf: float = WorldData.FRONT_Z + 0.03
	var pebble_tf: Array[Transform3D] = []
	var root_tf: Array[Transform3D] = []
	var strata_tf: Array[Transform3D] = []
	var r := _rng(60)
	var ox := x_start
	while ox < x_end:
		ox += r.randf_range(3.0, 7.0)
		var sy: float = TerrainBuilder.surface_height(ox)
		var wx: float = ox * WorldData.SCALE
		for _k in range(r.randi_range(1, 3)):
			var dy := r.randf_range(0.9, TerrainBuilder.WALL_DEPTH - 0.4)
			var y := sy - dy
			var x := wx + r.randf_range(-0.7, 0.7)
			var pick := r.randf()
			if pick < 0.5:
				var ps := r.randf_range(0.7, 1.5)
				pebble_tf.append(Transform3D(Basis().rotated(Vector3.FORWARD, r.randf_range(0, TAU)).scaled(Vector3(ps, ps, ps)), Vector3(x, y, zf)))
			elif pick < 0.78:
				root_tf.append(Transform3D(Basis().rotated(Vector3.FORWARD, r.randf_range(-0.5, 0.5)), Vector3(x, y, zf)))
			else:
				strata_tf.append(Transform3D(Basis(), Vector3(wx, sy - r.randf_range(1.5, TerrainBuilder.WALL_DEPTH - 1.0), zf - 0.01)))
	_spawn_mm(parent, "Pebbles", _pebble_mesh(), pebble_tf)
	_spawn_mm(parent, "Roots", _root_mesh(), root_tf)
	_spawn_mm(parent, "Strata", _strata_mesh(), strata_tf)

static func _pebble_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3.ZERO, Vector3(0.22, 0.18, 0.12), Color(0.46, 0.43, 0.42))
	return st.commit()

static func _root_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0, 0), Vector3(0.7, 0.08, 0.06), Color(0.30, 0.21, 0.12))
	_box(st, Vector3(0.3, -0.12, 0), Vector3(0.08, 0.24, 0.06), Color(0.30, 0.21, 0.12))
	return st.commit()

static func _strata_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3.ZERO, Vector3(1.9, 0.12, 0.04), Color(0.44, 0.32, 0.20, 0.5))
	return st.commit()

static func _lilypad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0, 0), Vector3(0.6, 0.05, 0.6), Color(0.27, 0.46, 0.26))
	_box(st, Vector3(0.18, 0.01, 0.12), Vector3(0.34, 0.05, 0.34), Color(0.31, 0.51, 0.29))
	return st.commit()

static func _reed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := Color(0.34, 0.48, 0.24)
	var tip := Color(0.45, 0.30, 0.16)
	var offs := [Vector3(0, 0, 0), Vector3(0.16, 0, 0.1), Vector3(-0.14, 0, -0.08), Vector3(0.05, 0, -0.16)]
	for o in offs:
		_box(st, o + Vector3(0, 0.6, 0), Vector3(0.09, 1.2, 0.09), stalk)
	_box(st, offs[0] + Vector3(0, 1.25, 0), Vector3(0.16, 0.34, 0.16), tip)
	_box(st, offs[1] + Vector3(0, 1.2, 0), Vector3(0.15, 0.30, 0.15), tip)
	return st.commit()

static func _box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c := center
	var v := [
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),       # front
		c + Vector3(h.x, -h.y, -h.z), c + Vector3(-h.x, -h.y, -h.z), c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z),    # back
	]
	var faces := [[0,1,2,3, Vector3.BACK], [4,5,6,7, Vector3.FORWARD], [5,0,3,6, Vector3.LEFT],
		[1,4,7,2, Vector3.RIGHT], [3,2,7,6, Vector3.UP], [5,4,1,0, Vector3.DOWN]]
	for f in faces:
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.set_color(col); st.set_normal(f[4]); st.add_vertex(v[idx])
