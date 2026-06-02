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

	var x0: float = WorldData.points()[0].x * WorldData.SCALE - 60.0
	var x1: float = WorldData.points()[WorldData.points().size() - 1].x * WorldData.SCALE + 60.0

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
	var x_start: float = WorldData.points()[0].x
	var x_end: float = WorldData.points()[WorldData.points().size() - 1].x

	var tree_tf: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	var pine_tf: Array[Transform3D] = []
	var pine_cols: Array[Color] = []
	var bush_tf: Array[Transform3D] = []
	var rock_tf: Array[Transform3D] = []
	var grass_tf: Array[Transform3D] = []
	var smallgrass_tf: Array[Transform3D] = []
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

		# THICK grass with SIZE LAYERING (curved higher-poly tufts) — off the path
		for _g in range(r.randi_range(30, 52)):
			var gz := r.randf_range(pzb, pzf)
			if absf(gz - pz) < 2.1:
				continue
			var gs := r.randf_range(0.35, 1.0)        # short→medium carpet
			if r.randf() < 0.18:
				gs = r.randf_range(1.3, 2.3)          # occasional tall clump
			grass_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(gs * r.randf_range(0.85, 1.2), gs, gs * r.randf_range(0.85, 1.2))),
				Vector3(wx + r.randf_range(-1.5, 1.5), sy, gz)))

		# SMALL filler grass — packs the bare gaps with short medium/small tufts
		for _sg in range(r.randi_range(40, 70)):
			var sgz := r.randf_range(pzb, pzf)
			if absf(sgz - pz) < 1.6:   # let grass creep onto the faded path edge
				continue
			var sgs := r.randf_range(0.5, 1.1)
			smallgrass_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(sgs, sgs, sgs)),
				Vector3(wx + r.randf_range(-1.6, 1.6), sy, sgz)))

		# ferns — dense ground cover everywhere (thicker near water/forest)
		for _f in range(r.randi_range(2, 5)):
			if r.randf() < (0.75 if (near_water or forest) else 0.5):
				var fz := r.randf_range(pzb, pzf)
				if absf(fz - pz) >= 2.1:
					var fs := r.randf_range(0.7, 1.4)
					fern_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(fs, fs, fs)), Vector3(wx + r.randf_range(-1.0, 1.0), sy, fz)))

		if r.randf() < 0.45:
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
	_spawn_mm(parent, "Ferns", _fern_mesh(), fern_tf, [], 0.09, false)
	_spawn_mm(parent, "GrassTufts", _grass_mesh(), grass_tf, [], 0.11, false)
	_spawn_mm(parent, "SmallGrass", _smallgrass_mesh(), smallgrass_tf, [], 0.13, false)
	_spawn_mm(parent, "Mushrooms", _mushroom_mesh(), mush_tf)
	_spawn_mm(parent, "Flowers", _flower_mesh(), flower_tf, flower_cols, 0.10, false)

const _FLOWER_COLS: Array[Color] = [
	Color(0.95, 0.95, 0.92), Color(0.97, 0.82, 0.30),
	Color(0.90, 0.45, 0.55), Color(0.70, 0.55, 0.85), Color(0.95, 0.60, 0.35),
]

const FOLIAGE_SHADER = preload("res://shaders/foliage.gdshader")

static func _spawn_mm(parent: Node3D, nm: String, mesh: Mesh, tfs: Array[Transform3D], cols: Array[Color] = [], sway: float = 0.0, cast_shadows: bool = true) -> void:
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
	# thin grass/foliage casting shadows flickers badly — let it only RECEIVE shadows
	if not cast_shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var trunk := Color(0.42, 0.31, 0.19)
	var trunkd := Color(0.28, 0.20, 0.12)
	var lo := Color(0.17, 0.31, 0.15)     # shadowed underside
	var mid := Color(0.28, 0.44, 0.22)
	var hi := Color(0.45, 0.61, 0.32)     # sun-kissed top
	# flared root base → tapered trunk
	_cyl(st, Vector3(0, 0, 0), 0.23, 0.5, 0.55, trunk, trunkd)
	_cyl(st, Vector3(0, 0.55, 0), 0.15, 0.23, 1.35, trunk, trunkd)
	# the trunk SPLITS into a few branches reaching into the canopy (fractal structure)
	_tube(st, Vector3(0, 1.7, 0), Vector3(0.72, 2.5, 0.25), 0.1, 5, trunk, trunkd)
	_tube(st, Vector3(0, 1.7, 0), Vector3(-0.62, 2.6, -0.18), 0.09, 5, trunk, trunkd)
	_tube(st, Vector3(0, 1.8, 0), Vector3(0.12, 2.75, -0.55), 0.08, 5, trunk, trunkd)
	# FACETED, irregular foliage clumps clustered on the branch ends → jagged crown,
	# not a smooth bubble. Upper clumps sun-kissed (hi→mid), lower shadowed (mid→lo).
	_facet_blob(st, Vector3(0.72, 2.65, 0.25), Vector3(0.78, 0.72, 0.78), 3, 6, hi, mid)
	_facet_blob(st, Vector3(-0.62, 2.7, -0.18), Vector3(0.72, 0.66, 0.72), 3, 6, hi, mid)
	_facet_blob(st, Vector3(0.12, 2.95, -0.55), Vector3(0.68, 0.62, 0.68), 3, 6, hi, mid)
	_facet_blob(st, Vector3(0.0, 2.45, 0.05), Vector3(0.92, 0.85, 0.92), 3, 7, mid, lo)
	_facet_blob(st, Vector3(0.34, 3.15, 0.0), Vector3(0.6, 0.55, 0.6), 2, 6, hi, mid)
	_facet_blob(st, Vector3(-0.3, 2.35, 0.34), Vector3(0.55, 0.5, 0.55), 2, 5, mid, lo)
	_facet_blob(st, Vector3(0.5, 2.3, -0.32), Vector3(0.46, 0.44, 0.46), 2, 5, mid, lo)
	_facet_blob(st, Vector3(-0.46, 3.0, 0.28), Vector3(0.48, 0.45, 0.48), 2, 5, hi, mid)
	return st.commit()

# a low-poly FLAT-SHADED blob (faceted, gem-like) — reads as stylized foliage, not a bubble
static func _facet_blob(st: SurfaceTool, c: Vector3, rad: Vector3, rings: int, segs: int, top: Color, bot: Color) -> void:
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
			_facet_tri(st, c, a, b, d, ca, cb, cb)
			_facet_tri(st, c, a, d, e, ca, cb, ca)

static func _facet_tri(st: SurfaceTool, center: Vector3, a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color) -> void:
	var nrm := (b - a).cross(d - a).normalized()       # flat per-face normal → faceted
	if nrm.dot((a + b + d) / 3.0 - center) < 0.0:
		nrm = -nrm
	st.set_color(ca); st.set_normal(nrm); st.add_vertex(a)
	st.set_color(cb); st.set_normal(nrm); st.add_vertex(b)
	st.set_color(cd); st.set_normal(nrm); st.add_vertex(d)

static func _rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := Color(0.50, 0.49, 0.50)
	var rock2 := Color(0.39, 0.38, 0.40)
	_sphere(st, Vector3(0, 0.22, 0), Vector3(0.62, 0.46, 0.56), 5, 9, rock, rock2)
	_sphere(st, Vector3(0.3, 0.42, 0.12), Vector3(0.34, 0.3, 0.34), 4, 8, rock, rock2)
	return st.commit()

static func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# lush CURVED multi-segment blades, mossy-swamp gradient (dark base → pale tip)
	var base_c := Color(0.20, 0.27, 0.13)
	var tip_c := Color(0.46, 0.54, 0.27)
	var blades := 11
	for i in range(blades):
		var ang := TAU * float(i) / blades + float(i) * 0.7
		var rad := 0.07 + float(i % 3) * 0.05
		var bx := cos(ang) * rad
		var bz := sin(ang) * rad
		var h := 0.55 + float(i % 4) * 0.12
		var lean := 0.22 + float(i % 2) * 0.12
		_blade(st, Vector3(bx, 0, bz), h, Vector3(cos(ang) * lean, 0, sin(ang) * lean), base_c, tip_c)
	return st.commit()

# a single curved tapering blade: 3 quad segments that bend toward the lean direction
static func _blade(st: SurfaceTool, base: Vector3, height: float, lean: Vector3, cbase: Color, ctip: Color) -> void:
	var segs := 3
	var w := 0.05
	var perp := Vector3(-lean.z, 0, lean.x).normalized()
	if perp.length() < 0.001:
		perp = Vector3(1, 0, 0)
	var nrm := Vector3(lean.x, 0.8, lean.z).normalized()
	var prev_c := base
	var prev_w := perp * w
	var prev_col := cbase
	for s in range(1, segs + 1):
		var t := float(s) / segs
		var pos := base + Vector3(lean.x * t * t, height * t, lean.z * t * t)
		var wv := perp * (w * (1.0 - t * 0.9))   # taper to a point
		var col := cbase.lerp(ctip, t)
		_tri(st, prev_c - prev_w, pos - wv, pos + wv, prev_col, col, col, nrm)
		_tri(st, prev_c - prev_w, pos + wv, prev_c + prev_w, prev_col, col, prev_col, nrm)
		prev_c = pos
		prev_w = wv
		prev_col = col

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, n: Vector3) -> void:
	st.set_color(ca); st.set_normal(n); st.add_vertex(a)
	st.set_color(cb); st.set_normal(n); st.add_vertex(b)
	st.set_color(cc); st.set_normal(n); st.add_vertex(c)

# short low-poly filler grass to pack the gaps between the big tufts
static func _smallgrass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bc := Color(0.22, 0.30, 0.14)
	var tc := Color(0.41, 0.50, 0.25)
	for i in range(5):
		var ang := TAU * float(i) / 5.0 + float(i) * 0.6
		var rad := 0.04 + float(i % 2) * 0.04
		_blade(st, Vector3(cos(ang) * rad, 0, sin(ang) * rad), 0.28 + float(i % 3) * 0.07, Vector3(cos(ang) * 0.12, 0, sin(ang) * 0.12), bc, tc)
	return st.commit()

static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# stem (green) + rounded blossom (white → tinted per-instance via MultiMesh color)
	_tube(st, Vector3(0, 0, 0), Vector3(0, 0.44, 0), 0.04, 5, Color(0.34, 0.5, 0.24), Color(0.28, 0.42, 0.2))
	_sphere(st, Vector3(0, 0.52, 0), Vector3(0.17, 0.13, 0.17), 4, 8, Color(1, 1, 1), Color(0.86, 0.86, 0.86))
	return st.commit()

static func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.38, 0.27, 0.16)
	var trunkd := Color(0.26, 0.18, 0.10)
	var lo := Color(0.16, 0.31, 0.18)
	var hi := Color(0.31, 0.49, 0.28)
	_cyl(st, Vector3(0, 0, 0), 0.2, 0.42, 0.55, trunk, trunkd)   # flared base
	_cyl(st, Vector3(0, 0.55, 0), 0.15, 0.2, 0.55, trunk, trunkd)
	_cone(st, Vector3(0, 0.9, 0), 1.3, 1.4, 16, hi, lo)
	_cone(st, Vector3(0, 1.7, 0), 1.05, 1.3, 16, hi, lo)
	_cone(st, Vector3(0, 2.5, 0), 0.8, 1.2, 16, hi, lo)
	_cone(st, Vector3(0, 3.3, 0), 0.5, 1.05, 16, hi, lo)
	return st.commit()

static func _bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := Color(0.26, 0.42, 0.23)
	var hi := Color(0.34, 0.52, 0.29)
	_sphere(st, Vector3(0, 0.42, 0), Vector3(0.72, 0.52, 0.67), 6, 11, hi, lo)
	_sphere(st, Vector3(0.42, 0.5, 0.1), Vector3(0.52, 0.48, 0.52), 6, 10, hi, lo)
	_sphere(st, Vector3(-0.34, 0.46, -0.08), Vector3(0.48, 0.44, 0.48), 6, 10, hi, lo)
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
	# sparse, wispy canopy high up (smoother)
	_sphere(st, Vector3(0, 5.7, 0), Vector3(1.5, 0.9, 1.5), 7, 13, hi, lo)
	_sphere(st, Vector3(0.6, 6.2, 0.2), Vector3(0.88, 0.72, 0.88), 6, 11, hi, lo)
	_sphere(st, Vector3(-0.55, 6.0, -0.25), Vector3(0.82, 0.67, 0.82), 6, 11, hi, lo)
	# hanging Spanish moss strands draping from the canopy
	for m in range(10):
		var ma := float(m) * TAU / 10.0
		var mr := 1.0 + (m % 3) * 0.25
		var mx := cos(ma) * mr
		var mz := sin(ma) * mr
		var ml := 0.9 + (m % 4) * 0.45
		_tube(st, Vector3(mx, 5.3, mz), Vector3(mx * 1.06, 5.3 - ml, mz * 1.06), 0.05, 4, moss, moss.darkened(0.12))
	return st.commit()

static func _snag_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dead := Color(0.44, 0.40, 0.33)
	var deadd := Color(0.30, 0.27, 0.22)
	_cyl(st, Vector3(0, 0, 0), 0.16, 0.42, 4.3, dead, deadd)
	# a few broken bare branch stubs near the top (rounded, angled)
	_tube(st, Vector3(0.05, 3.3, 0), Vector3(1.2, 3.7, 0.1), 0.08, 6, dead, deadd)
	_tube(st, Vector3(-0.05, 3.8, 0.05), Vector3(-0.85, 4.2, 0.15), 0.07, 6, dead, deadd)
	_tube(st, Vector3(0.1, 4.1, -0.05), Vector3(0.2, 4.5, -0.8), 0.06, 6, dead, deadd)
	# a wisp of moss hanging off the branch
	_tube(st, Vector3(1.05, 3.55, 0.05), Vector3(1.1, 2.8, 0.05), 0.05, 4, Color(0.54, 0.56, 0.46), Color(0.46, 0.48, 0.4))
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

# a smooth tube/cylinder between two points (rounded logs, branches, stalks)
static func _tube(st: SurfaceTool, p0: Vector3, p1: Vector3, rad: float, segs: int, c0: Color, c1: Color) -> void:
	var axis := p1 - p0
	var ln := axis.length()
	if ln < 0.0001:
		return
	axis /= ln
	var up := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var u := axis.cross(up).normalized() * rad
	var v := axis.cross(u.normalized()).normalized() * rad
	for s in range(segs):
		var a0 := TAU * float(s) / segs
		var a1 := TAU * float(s + 1) / segs
		var r0 := u * cos(a0) + v * sin(a0)
		var r1 := u * cos(a1) + v * sin(a1)
		var n0 := r0.normalized()
		var n1 := r1.normalized()
		_tri(st, p0 + r0, p0 + r1, p1 + r1, c0, c0, c1, n1)
		_tri(st, p0 + r0, p1 + r1, p1 + r0, c0, c1, c1, n0)

# a flat n-gon disc (lily pads)
static func _disc(st: SurfaceTool, center: Vector3, radius: float, segs: int, col: Color) -> void:
	for s in range(segs):
		var a0 := TAU * float(s) / segs
		var a1 := TAU * float(s + 1) / segs
		var p0 := center + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := center + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		_tri(st, center, p1, p0, col, col, col, Vector3.UP)

static func _fern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fbase := Color(0.20, 0.34, 0.16)
	var ftip := Color(0.34, 0.50, 0.24)
	# splayed CURVED fronds arching outward
	for i in range(7):
		var ang := -0.95 + i * 0.32
		_blade(st, Vector3(sin(ang) * 0.18, 0, cos(ang) * 0.1), 1.0, Vector3(sin(ang) * 0.55, 0.4, cos(ang) * 0.25), fbase, ftip)
	return st.commit()

static func _mushroom_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, Vector3(0, 0, 0), Vector3(0, 0.3, 0), 0.08, 7, Color(0.90, 0.86, 0.78), Color(0.78, 0.74, 0.66))  # stem
	_sphere(st, Vector3(0, 0.32, 0), Vector3(0.3, 0.2, 0.3), 5, 10, Color(0.80, 0.27, 0.22), Color(0.6, 0.18, 0.15))  # rounded cap
	return st.commit()

static func _log_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.36, 0.26, 0.16)
	var barkd := Color(0.26, 0.18, 0.11)
	var ring := Color(0.55, 0.42, 0.28)
	# rounded horizontal log with sawn ends
	_tube(st, Vector3(-1.0, 0.26, 0), Vector3(1.0, 0.26, 0), 0.26, 9, bark, barkd)
	_sphere(st, Vector3(1.0, 0.26, 0), Vector3(0.26, 0.26, 0.26), 4, 8, ring, ring.darkened(0.1))
	_sphere(st, Vector3(-1.0, 0.26, 0), Vector3(0.26, 0.26, 0.26), 4, 8, ring, ring.darkened(0.1))
	return st.commit()

# ── Forest walls bounding the play corridor (RPG-map style: frame is all terrain) ──
static func build_tree_walls(parent: Node3D) -> void:
	var x_start: float = WorldData.points()[0].x
	var x_end: float = WorldData.points()[WorldData.points().size() - 1].x
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

# ── Road detail: embedded stones, wet puddles, stepping stones along the path ──────
static func build_path_detail(parent: Node3D) -> void:
	var x_start: float = WorldData.points()[0].x
	var x_end: float = WorldData.points()[WorldData.points().size() - 1].x
	var stone_tf: Array[Transform3D] = []
	var big_tf: Array[Transform3D] = []
	var puddle_tf: Array[Transform3D] = []
	var r := _rng(70)
	var x := x_start
	while x < x_end:
		x += r.randf_range(1.4, 3.2)
		if WorldData.in_pool(x):
			continue
		var wx: float = x * WorldData.SCALE
		var sy: float = TerrainBuilder.surface_height(x)
		var pz: float = WorldData.path_z(wx)
		for _p in range(r.randi_range(1, 3)):
			var ss := r.randf_range(0.28, 0.72)
			stone_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ss, ss * 0.6, ss)),
				Vector3(wx + r.randf_range(-0.4, 0.4), sy + 0.03, pz + r.randf_range(-1.7, 1.7))))
		if r.randf() < 0.13:
			var ps := r.randf_range(0.8, 1.6)
			puddle_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ps, 1.0, ps * 0.7)),
				Vector3(wx, sy + 0.05, pz + r.randf_range(-0.8, 0.8))))
		if r.randf() < 0.05:
			var bs := r.randf_range(0.9, 1.4)
			big_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(bs, bs * 0.4, bs)),
				Vector3(wx, sy + 0.05, pz + r.randf_range(-1.0, 1.0))))
	_spawn_mm(parent, "PathPebbles", _pathstone_mesh(), stone_tf)
	_spawn_mm(parent, "SteppingStones", _pathstone_mesh(), big_tf)
	# wet puddles get a glossy dark material (catches the sky → wet sheen)
	if not puddle_tf.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _puddle_mesh()
		mm.instance_count = puddle_tf.size()
		for i in range(puddle_tf.size()):
			mm.set_instance_transform(i, puddle_tf[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Puddles"
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.12
		mat.metallic = 0.35
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mmi.material_override = mat
		parent.add_child(mmi)

static func _pathstone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sphere(st, Vector3(0, 0.08, 0), Vector3(0.3, 0.18, 0.26), 4, 8, Color(0.46, 0.44, 0.43), Color(0.33, 0.32, 0.33))
	return st.commit()

static func _puddle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_disc(st, Vector3.ZERO, 0.5, 12, Color(0.09, 0.11, 0.10))
	return st.commit()

# ── Water-edge props (reeds, lily pads) ──────────────────────────────────────────
static func build_water_props(parent: Node3D) -> void:
	var reed_tf: Array[Transform3D] = []
	var pad_tf: Array[Transform3D] = []
	var r := _rng(40)
	for i in range(WorldData.SWAMP_COUNT):
		var rng: Array = WorldData.SWAMP_RANGES[i]
		var ea: Vector2 = WorldData.points()[rng[0]]
		var eb: Vector2 = WorldData.points()[rng[1]]
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
	var x_start: float = WorldData.points()[0].x
	var x_end: float = WorldData.points()[WorldData.points().size() - 1].x
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
	_disc(st, Vector3(0, 0, 0), 0.56, 10, Color(0.27, 0.46, 0.26))
	_disc(st, Vector3(0.12, 0.012, 0.08), 0.3, 8, Color(0.32, 0.52, 0.30))
	return st.commit()

static func _reed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := Color(0.34, 0.48, 0.24)
	var stalkd := Color(0.26, 0.38, 0.18)
	var tip := Color(0.42, 0.28, 0.15)
	var offs := [Vector3(0, 0, 0), Vector3(0.16, 0, 0.1), Vector3(-0.14, 0, -0.08), Vector3(0.05, 0, -0.16)]
	for o in offs:
		_tube(st, o, o + Vector3(0, 1.2, 0), 0.045, 5, stalk, stalkd)
	# rounded cattail sausage tips
	_sphere(st, offs[0] + Vector3(0, 1.3, 0), Vector3(0.1, 0.24, 0.1), 5, 8, tip, tip.darkened(0.12))
	_sphere(st, offs[1] + Vector3(0, 1.25, 0), Vector3(0.09, 0.21, 0.09), 5, 8, tip, tip.darkened(0.12))
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
