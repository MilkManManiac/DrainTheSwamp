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
	var tree_var: Array[int] = []
	var pine_tf: Array[Transform3D] = []
	var pine_cols: Array[Color] = []
	var bush_tf: Array[Transform3D] = []
	var rock_tf: Array[Transform3D] = []
	var grass_tf: Array[Transform3D] = []
	var grass2_tf: Array[Transform3D] = []
	var grass3_tf: Array[Transform3D] = []
	var grass4_tf: Array[Transform3D] = []
	var smallgrass_tf: Array[Transform3D] = []
	var fern_tf: Array[Transform3D] = []
	var mush_tf: Array[Transform3D] = []
	var log_tf: Array[Transform3D] = []
	var stump_tf: Array[Transform3D] = []
	var fallen_tf: Array[Transform3D] = []
	var flower_tf: Array[Transform3D] = []
	var flower_cols: Array[Color] = []
	var cypress_tf: Array[Transform3D] = []
	var cypress_cols: Array[Color] = []
	var cypress_var: Array[int] = []
	var snag_tf: Array[Transform3D] = []
	var palm_tf: Array[Transform3D] = []

	# props spread across the whole landmass depth (front toward camera → forested back)
	var pzb := WorldData.FRONT_Z - WorldData.DEPTH + 1.0
	var pzf := WorldData.FRONT_Z - 0.5
	# tall props (trees/cypress/snags) must stay BEHIND the camera's nearest approach (~z 10)
	# or the camera clips through them and the double-sided foliage reads as see-through. The
	# foreground (bottom of screen, z≈10-18) is left to grass/low cover.
	var tall_zf := 7.0
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
			var z := r.randf_range(pzb, tall_zf)
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
					tree_var.append(r.randi() % TREE_VARIANTS)

		if r.randf() < 0.14:
			var bz := r.randf_range(pzb, minf(pzf, 9.0))
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
			var gtf := Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(gs * r.randf_range(0.85, 1.2), gs, gs * r.randf_range(0.85, 1.2))),
				Vector3(wx + r.randf_range(-1.5, 1.5), sy, gz))
			# spread across 4 grass styles (fine tuft / broad-leaf / tall wispy / dry brown)
			var gpick := r.randf()
			if gpick < 0.48:
				grass_tf.append(gtf)
			elif gpick < 0.68:
				grass2_tf.append(gtf)
			elif gpick < 0.82:
				grass3_tf.append(gtf)
			else:
				grass4_tf.append(gtf)   # dry brown clumps

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
			var cz := r.randf_range(pzb, tall_zf)
			if absf(cz - pz) >= PATH_CLEAR:
				var cs := r.randf_range(0.85, 1.5)
				cypress_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(cs, cs, cs)), Vector3(wx, sy, cz)))
				var cv := r.randf_range(0.85, 1.1)
				cypress_cols.append(Color(cv, cv * r.randf_range(0.97, 1.04), cv * 0.92))
				cypress_var.append(r.randi() % CYPRESS_VARIANTS)

		# dead snag — occasional grey skeleton
		if r.randf() < 0.035:
			var nz := r.randf_range(pzb, tall_zf)
			if absf(nz - pz) >= PATH_CLEAR:
				var ns := r.randf_range(0.8, 1.3)
				snag_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ns, ns, ns)), Vector3(wx, sy, nz)))

		# palmetto fan — low, clumps near water/forest, can sit closer to the path
		if r.randf() < (0.20 if (near_water or forest) else 0.08):
			var palz := r.randf_range(pzb, minf(pzf, 9.0))
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
			var lz := r.randf_range(pzb, tall_zf)
			if absf(lz - pz) >= PATH_CLEAR:
				log_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(-0.3, 0.3)), Vector3(wx, sy + 0.15, lz)))

		# cut stumps — old logging remnants, sit anywhere off the path
		if r.randf() < 0.022:
			var stz := r.randf_range(pzb, pzf)
			if absf(stz - pz) >= 2.4:
				var sts := r.randf_range(0.8, 1.35)
				stump_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(sts, sts * r.randf_range(0.8, 1.1), sts)), Vector3(wx, sy, stz)))

		# downed/fallen trunks — bigger, kept off the walking corridor
		if r.randf() < 0.014:
			var ftz := r.randf_range(pzb, tall_zf)
			if absf(ftz - pz) >= PATH_CLEAR:
				var fts := r.randf_range(0.85, 1.3)
				fallen_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(fts, fts, fts)), Vector3(wx, sy + 0.12, ftz)))

	var tvariants := _tree_variants()
	for vi in range(tvariants.size()):
		var vtf: Array[Transform3D] = []
		var vcl: Array[Color] = []
		for j in range(tree_tf.size()):
			if tree_var[j] == vi:
				vtf.append(tree_tf[j])
				vcl.append(tree_cols[j])
		_spawn_mm(parent, "Trees%d" % vi, tvariants[vi], vtf, vcl, 0.035)
	_spawn_mm(parent, "Pines", _pine_mesh(), pine_tf, pine_cols, 0.02)
	var cvariants := _cypress_variants()
	for ci in range(cvariants.size()):
		var ctf: Array[Transform3D] = []
		var ccl: Array[Color] = []
		for j in range(cypress_tf.size()):
			if cypress_var[j] == ci:
				ctf.append(cypress_tf[j])
				ccl.append(cypress_cols[j])
		_spawn_mm(parent, "Cypress%d" % ci, cvariants[ci], ctf, ccl, 0.03)
	_spawn_mm(parent, "Snags", _snag_mesh(), snag_tf, [], 0.02)
	_spawn_mm(parent, "Palmettos", _palmetto_mesh(), palm_tf, [], 0.07)
	_spawn_mm(parent, "Bushes", _bush_mesh(), bush_tf, [], 0.05)
	_spawn_mm(parent, "Logs", _log_mesh(), log_tf)
	_spawn_mm(parent, "Stumps", _stump_mesh(), stump_tf)
	_spawn_mm(parent, "FallenTrunks", _fallentrunk_mesh(), fallen_tf)
	_spawn_mm(parent, "Rocks", _rock_mesh(), rock_tf)
	_spawn_mm(parent, "Ferns", _fern_mesh(), fern_tf, [], 0.09, false)
	_spawn_mm(parent, "GrassTufts", _grass_mesh(), grass_tf, [], 0.11, false)
	_spawn_mm(parent, "GrassBroad", _grass_broad_mesh(), grass2_tf, [], 0.10, false)
	_spawn_mm(parent, "GrassWispy", _grass_wispy_mesh(), grass3_tf, [], 0.14, false)
	_spawn_mm(parent, "GrassDry", _grass_dry_mesh(), grass4_tf, [], 0.12, false)
	_spawn_mm(parent, "SmallGrass", _smallgrass_mesh(), smallgrass_tf, [], 0.13, false)
	_spawn_mm(parent, "Mushrooms", _mushroom_mesh(), mush_tf)
	_spawn_mm(parent, "Flowers", _flower_mesh(), flower_tf, flower_cols, 0.10, false)

const _FLOWER_COLS: Array[Color] = [
	Color(0.95, 0.95, 0.92), Color(0.97, 0.82, 0.30),
	Color(0.90, 0.45, 0.55), Color(0.70, 0.55, 0.85), Color(0.95, 0.60, 0.35),
]

const STYLIZED_SHADER = preload("res://shaders/stylized.gdshader")

# one shared premium stylized material per prop type (painterly light + backlight SSS +
# rim glow). Cached by (sway, roughness) so we don't make thousands of duplicate shaders.
static var _mat_cache: Dictionary = {}

static func _stylized_mat(sway: float, roughness: float) -> ShaderMaterial:
	var key := "%0.3f_%0.2f" % [sway, roughness]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var smat := ShaderMaterial.new()
	smat.shader = STYLIZED_SHADER
	smat.set_shader_parameter("sway_strength", sway)
	smat.set_shader_parameter("surf_roughness", roughness)
	_mat_cache[key] = smat
	return smat

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
	mmi.material_override = _stylized_mat(sway, 0.92 if sway <= 0.0 else 0.9)
	parent.add_child(mmi)

const TREE_VARIANTS := 4

static func _tree_mesh() -> ArrayMesh:
	return _tree_mesh_v(0)

# build a SET of distinct tree silhouettes so neighbours don't look copy-pasted.
# each is seeded → stable; per-instance scale/rotation/tint vary on top of these.
static func _tree_variants() -> Array:
	var out: Array = []
	for v in range(TREE_VARIANTS):
		out.append(_tree_mesh_v(v))
	return out

# one procedurally-varied broadleaf: random trunk height, branch count/spread, crown
# clumps, and a per-tree hue shift (some yellow-green, some deep shade).
static func _tree_mesh_v(variant: int) -> ArrayMesh:
	var r := _rng(700 + variant * 23)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.42, 0.31, 0.19)
	var trunkd := Color(0.28, 0.20, 0.12)
	# per-variant canopy hue (warm sun-green ↔ cool deep-green)
	var warm := r.randf_range(-0.04, 0.07)
	var lo := Color(0.17 + warm * 0.4, 0.31, 0.15 - warm * 0.3)
	var mid := Color(0.28 + warm, 0.44, 0.22 - warm * 0.5)
	var hi := Color(0.45 + warm, 0.61, 0.32 - warm * 0.6)
	# flared root base → tapered trunk of varying height
	var th := r.randf_range(1.15, 1.75)
	_cyl(st, Vector3(0, 0, 0), 0.22, 0.5, 0.55, trunk, trunkd)
	_cyl(st, Vector3(0, 0.55, 0), 0.15, 0.22, th, trunk, trunkd)
	var fork_y := 0.55 + th
	# trunk SPLITS into a varying number of branches at varying angles
	var nb := r.randi_range(3, 4)
	var ends: Array = []
	var a0 := r.randf_range(0.0, TAU)
	for b in range(nb):
		var ang := a0 + TAU * float(b) / nb + r.randf_range(-0.35, 0.35)
		var reach := r.randf_range(0.45, 0.95)
		var rise := r.randf_range(0.7, 1.25)
		var end := Vector3(cos(ang) * reach, fork_y + rise, sin(ang) * reach)
		_tube(st, Vector3(0, fork_y - 0.15, 0), end, r.randf_range(0.08, 0.11), 5, trunk, trunkd)
		ends.append(end)
	# foliage clumps on each branch end (sun-kissed) + a central mass (shaded). soft normals
	# (0.7) make each clump light as a soft volume; the irregular cluster keeps the silhouette.
	var sft := 0.7
	for e in ends:
		var rad := r.randf_range(0.52, 0.82)
		_facet_blob(st, e, Vector3(rad, rad * 0.92, rad), 4, r.randi_range(7, 9), hi, mid, sft)
	var cy := fork_y + r.randf_range(0.55, 0.95)
	_facet_blob(st, Vector3(0, cy, 0),
		Vector3(r.randf_range(0.84, 1.06), r.randf_range(0.78, 0.96), r.randf_range(0.84, 1.06)),
		4, 9, mid, lo, sft)
	# a few extra small clumps → irregular, non-spherical crown silhouette
	for k in range(r.randi_range(3, 5)):
		var ka := r.randf_range(0.0, TAU)
		var kr := r.randf_range(0.32, 0.75)
		var kh := cy + r.randf_range(-0.45, 0.6)
		var ks := r.randf_range(0.38, 0.6)
		var hot := r.randf() < 0.5
		_facet_blob(st, Vector3(cos(ka) * kr, kh, sin(ka) * kr), Vector3(ks, ks, ks),
			3, 6, hi if hot else mid, mid if hot else lo, sft)
	return st.commit()

# a low-poly blob with a faceted SILHOUETTE but optional "inflated" spherical normals so
# the clump lights as one soft volume (BotW/Europa foliage trick). soft=0 → flat gem-faceted
# (rocks); soft≈0.7 → smooth volume lighting while geometry stays chunky (premium canopy).
static func _facet_blob(st: SurfaceTool, c: Vector3, rad: Vector3, rings: int, segs: int, top: Color, bot: Color, soft: float = 0.0) -> void:
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
			_facet_tri(st, c, a, b, d, ca, cb, cb, soft)
			_facet_tri(st, c, a, d, e, ca, cb, ca, soft)

static func _facet_tri(st: SurfaceTool, center: Vector3, a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color, soft: float = 0.0) -> void:
	var face := (b - a).cross(d - a).normalized()       # flat per-face normal
	if face.dot((a + b + d) / 3.0 - center) < 0.0:
		face = -face
	# blend toward the radial (spherical) normal → "inflated" soft-volume lighting
	# (egg-shaped: squash the vertical so the top catches more light than the sides)
	for item in [[a, ca], [b, cb], [d, cd]]:
		var rel: Vector3 = item[0] - center
		rel.y *= 1.35
		var radial := rel.normalized()
		var n := face.lerp(radial, soft).normalized()
		st.set_color(item[1]); st.set_normal(n); st.add_vertex(item[0])

static func _rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := Color(0.52, 0.51, 0.52)
	var rock2 := Color(0.37, 0.36, 0.38)
	# faceted "cut" boulder (low soft → keep crisp gem facets) with an irregular silhouette
	_facet_blob(st, Vector3(0, 0.2, 0), Vector3(0.64, 0.48, 0.58), 4, 9, rock, rock2, 0.12)
	_facet_blob(st, Vector3(0.32, 0.42, 0.12), Vector3(0.36, 0.32, 0.36), 3, 7, rock, rock2, 0.12)
	_facet_blob(st, Vector3(-0.28, 0.16, -0.1), Vector3(0.28, 0.24, 0.3), 3, 6, rock, rock2, 0.12)
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

# a single curved tapering blade: 4 quad segments that bend toward the lean direction
static func _blade(st: SurfaceTool, base: Vector3, height: float, lean: Vector3, cbase: Color, ctip: Color) -> void:
	var segs := 4
	var w := 0.055
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

# broad-leaf swamp grass — fewer, wider arching fronds, cooler blue-green
static func _grass_broad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bc := Color(0.17, 0.29, 0.15)
	var tc := Color(0.36, 0.49, 0.27)
	for i in range(7):
		var ang := TAU * float(i) / 7.0 + float(i) * 0.5
		var rad := 0.08 + float(i % 2) * 0.07
		var lean := 0.85 + float(i % 3) * 0.2
		_frond(st, Vector3(cos(ang) * rad, 0.0, sin(ang) * rad), 0.62 + float(i % 3) * 0.16,
			Vector3(cos(ang) * lean, 0.95, sin(ang) * lean), bc, tc)
	return st.commit()

# dry brown grass — sun-bleached straw clump (mixes parched patches into the green)
static func _grass_dry_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bc := Color(0.31, 0.26, 0.13)
	var tc := Color(0.56, 0.47, 0.25)
	for i in range(9):
		var ang := TAU * float(i) / 9.0 + float(i) * 0.7
		var rad := 0.06 + float(i % 3) * 0.04
		var h := 0.5 + float(i % 4) * 0.13
		var lean := 0.28 + float(i % 2) * 0.16   # droops more than green grass
		_blade(st, Vector3(cos(ang) * rad, 0, sin(ang) * rad), h, Vector3(cos(ang) * lean, 0, sin(ang) * lean), bc, tc)
	return st.commit()

# tall wispy seed-grass — many thin blades with pale, almost-blond tips
static func _grass_wispy_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bc := Color(0.24, 0.31, 0.16)
	var tc := Color(0.58, 0.56, 0.34)
	for i in range(14):
		var ang := TAU * float(i) / 14.0 + float(i) * 0.9
		var rad := 0.05 + float(i % 3) * 0.035
		var h := 0.85 + float(i % 4) * 0.2
		var lean := 0.12 + float(i % 2) * 0.1
		_blade(st, Vector3(cos(ang) * rad, 0, sin(ang) * rad), h, Vector3(cos(ang) * lean, 0, sin(ang) * lean), bc, tc)
	return st.commit()

# cut tree stump — flared base, exposed growth rings on top, a few surface roots
static func _stump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.34, 0.25, 0.16)
	var barkd := Color(0.23, 0.17, 0.11)
	var ring := Color(0.56, 0.44, 0.29)
	var ringd := Color(0.45, 0.34, 0.22)
	_cyl(st, Vector3(0, 0, 0), 0.4, 0.52, 0.62, bark, barkd)
	# concentric rings on the sawn top
	_disc(st, Vector3(0, 0.62, 0), 0.4, 14, ring)
	_disc(st, Vector3(0, 0.625, 0), 0.27, 12, ringd)
	_disc(st, Vector3(0, 0.63, 0), 0.13, 10, ring)
	# surface roots flaring out at the base
	for k in range(4):
		var ka := float(k) * TAU / 4.0 + 0.4
		_tube(st, Vector3(cos(ka) * 0.32, 0.12, sin(ka) * 0.32), Vector3(cos(ka) * 0.72, 0.0, sin(ka) * 0.72), 0.08, 5, bark, barkd)
	return st.commit()

# fallen/downed trunk lying on the ground — sawn ends, mossy top, broken branch stub
static func _fallentrunk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.33, 0.24, 0.15)
	var barkd := Color(0.23, 0.16, 0.10)
	var ring := Color(0.52, 0.40, 0.27)
	var moss := Color(0.29, 0.40, 0.21)
	_tube(st, Vector3(-1.7, 0.32, 0), Vector3(1.55, 0.30, 0.1), 0.32, 9, bark, barkd)
	_sphere(st, Vector3(-1.7, 0.32, 0), Vector3(0.32, 0.32, 0.32), 4, 9, ring, ring.darkened(0.1))
	_sphere(st, Vector3(1.55, 0.30, 0.1), Vector3(0.3, 0.3, 0.3), 4, 9, ring, ring.darkened(0.12))
	# moss draped along the top
	_sphere(st, Vector3(0.0, 0.56, 0.04), Vector3(0.8, 0.12, 0.34), 4, 10, moss, moss.darkened(0.12))
	# a broken branch stub sticking up
	_tube(st, Vector3(-0.4, 0.5, 0), Vector3(-0.72, 1.15, 0.22), 0.09, 5, bark, barkd)
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
	var lo := Color(0.21, 0.36, 0.20)
	var hi := Color(0.37, 0.55, 0.31)
	# de-bubbled: faceted-silhouette clumps with soft-volume normals (matches the trees)
	_facet_blob(st, Vector3(0, 0.42, 0), Vector3(0.74, 0.54, 0.68), 4, 10, hi, lo, 0.7)
	_facet_blob(st, Vector3(0.42, 0.5, 0.1), Vector3(0.52, 0.48, 0.52), 4, 8, hi, lo, 0.7)
	_facet_blob(st, Vector3(-0.34, 0.46, -0.08), Vector3(0.48, 0.44, 0.48), 4, 8, hi, lo, 0.7)
	_facet_blob(st, Vector3(0.08, 0.74, 0.05), Vector3(0.4, 0.36, 0.4), 3, 7, hi, lo, 0.7)
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
const CYPRESS_VARIANTS := 3

static func _cypress_mesh() -> ArrayMesh:
	return _cypress_mesh_v(0)

# distinct bayou cypress silhouettes so the vine-draped trees aren't copy-pasted
static func _cypress_variants() -> Array:
	var out: Array = []
	for v in range(CYPRESS_VARIANTS):
		out.append(_cypress_mesh_v(v))
	return out

# tall buttressed cypress: faceted (de-bubbled) wispy crown + lots of hanging Spanish
# moss / vines. Trunk height, knees, branches, canopy + moss all varied per variant.
static func _cypress_mesh_v(variant: int) -> ArrayMesh:
	var r := _rng(800 + variant * 31)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.34, 0.27, 0.19)
	var barkd := Color(0.22, 0.17, 0.12)
	var lo := Color(0.21, 0.32, 0.20)
	var mid := Color(0.27, 0.40, 0.24)
	var hi := Color(0.35, 0.48, 0.29)
	var moss := Color(0.58, 0.61, 0.49)   # ghostly grey-green Spanish moss
	var mossd := Color(0.47, 0.51, 0.40)
	# flared buttress base → tall slender trunk (height varies)
	var trunk_h := r.randf_range(3.7, 5.1)
	_cyl(st, Vector3(0, 0, 0), 0.3, 0.7 + r.randf_range(0.0, 0.14), 1.3, bark, barkd)
	_cyl(st, Vector3(0, 1.3, 0), 0.18, 0.3, trunk_h, bark, barkd)
	var top_y := 1.3 + trunk_h
	# cypress "knees" poking up around the base (count + spread vary)
	var nk := r.randi_range(4, 6)
	for k in range(nk):
		var ka := float(k) * TAU / nk + r.randf_range(-0.3, 0.3)
		var kr := r.randf_range(0.6, 1.05)
		_cone(st, Vector3(cos(ka) * kr, 0, sin(ka) * kr), 0.13, r.randf_range(0.24, 0.56), 5, bark, barkd)
	# a few branches splaying out near the top
	var nb := r.randi_range(3, 4)
	var ends: Array = []
	var a0 := r.randf_range(0.0, TAU)
	for b in range(nb):
		var ang := a0 + float(b) * TAU / nb + r.randf_range(-0.3, 0.3)
		var reach := r.randf_range(0.75, 1.45)
		var end := Vector3(cos(ang) * reach, top_y + r.randf_range(0.15, 0.7), sin(ang) * reach)
		_tube(st, Vector3(0, top_y - 0.35, 0), end, 0.07, 5, bark, barkd)
		ends.append(end)
	# wispy canopy clumps with soft-volume normals on branch ends + a central mass
	for e in ends:
		var rad := r.randf_range(0.68, 1.02)
		_facet_blob(st, e, Vector3(rad, rad * 0.72, rad), 4, r.randi_range(8, 9), hi, mid, 0.72)
	_facet_blob(st, Vector3(0, top_y + 0.3, 0),
		Vector3(r.randf_range(1.1, 1.45), r.randf_range(0.7, 0.92), r.randf_range(1.1, 1.45)),
		4, 10, mid, lo, 0.72)
	# LOTS of hanging Spanish moss / vines draping from canopy + branch ends (varied)
	var nm := r.randi_range(12, 18)
	for m in range(nm):
		var ma := r.randf_range(0.0, TAU)
		var mr := r.randf_range(0.8, 1.55)
		var mx := cos(ma) * mr
		var mz := sin(ma) * mr
		var my := top_y - r.randf_range(0.0, 0.7)
		var ml := r.randf_range(0.9, 2.2)
		# slight outward drift as the strand falls → natural drape
		_tube(st, Vector3(mx, my, mz), Vector3(mx * 1.08, my - ml, mz * 1.08), r.randf_range(0.035, 0.06), 4, moss, mossd)
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
	var tree_var: Array[int] = []
	var pine_tf: Array[Transform3D] = []
	var pine_cols: Array[Color] = []
	var r := _rng(50)
	var ox := x_start
	while ox < x_end:
		ox += r.randf_range(1.7, 3.3)               # tighter spacing → fuller treeline
		var wx: float = ox * WorldData.SCALE
		var sy: float = TerrainBuilder.surface_height(ox)
		# a deep, dense band of big trees behind the corridor → fills the top of frame
		for _t in range(r.randi_range(2, 3)):
			var z := r.randf_range(-22.0, -12.5)
			var s := r.randf_range(1.5, 2.4)
			var tf := Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(s, s, s)), Vector3(wx, sy, z))
			# leafy green (was too dark → read as grey bubbles in fog); slight depth shading
			var d := r.randf_range(0.82, 1.06)
			var tint := Color(d * 0.86, d, d * 0.7)   # push green, not grey
			if r.randf() < 0.45:
				pine_tf.append(tf)
				pine_cols.append(tint)
			else:
				tree_tf.append(tf)
				tree_cols.append(tint)
				tree_var.append(r.randi() % TREE_VARIANTS)
	var tvariants := _tree_variants()
	for vi in range(tvariants.size()):
		var vtf: Array[Transform3D] = []
		var vcl: Array[Color] = []
		for j in range(tree_tf.size()):
			if tree_var[j] == vi:
				vtf.append(tree_tf[j])
				vcl.append(tree_cols[j])
		_spawn_mm(parent, "WallTrees%d" % vi, tvariants[vi], vtf, vcl, 0.02)
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
		# sparse embedded stones (was a dense scatter — thinned right down)
		if r.randf() < 0.4:
			var ss := r.randf_range(0.3, 0.66)
			stone_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ss, ss * 0.55, ss)),
				Vector3(wx + r.randf_range(-0.4, 0.4), sy + 0.03, pz + r.randf_range(-1.7, 1.7))))
		# occasional puddle — much rarer + widely varied size/aspect/rotation so no two match
		if r.randf() < 0.05:
			var ps := r.randf_range(0.55, 2.3)
			var asp := r.randf_range(0.4, 1.0)
			puddle_tf.append(Transform3D(Basis().rotated(Vector3.UP, r.randf_range(0, TAU)).scaled(Vector3(ps, 1.0, ps * asp)),
				Vector3(wx + r.randf_range(-0.5, 0.5), sy + 0.045, pz + r.randf_range(-1.1, 1.1))))
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
	# faceted, gem-cut cobble (two lobes) — reads as a real stone, not a smooth blob
	_facet_blob(st, Vector3(0, 0.07, 0), Vector3(0.28, 0.15, 0.24), 3, 6, Color(0.52, 0.50, 0.47), Color(0.34, 0.33, 0.33))
	_facet_blob(st, Vector3(0.13, 0.13, 0.05), Vector3(0.14, 0.1, 0.13), 2, 5, Color(0.56, 0.53, 0.50), Color(0.37, 0.36, 0.35))
	return st.commit()

static func _puddle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# organic wavy outline (not a clean circle) so puddles read as natural pooled water
	var col := Color(0.09, 0.11, 0.10)
	var segs := 18
	for s in range(segs):
		var a0 := TAU * float(s) / segs
		var a1 := TAU * float(s + 1) / segs
		var r0 := 0.5 * (0.74 + 0.26 * sin(a0 * 3.0 + 1.3) + 0.12 * sin(a0 * 7.0))
		var r1 := 0.5 * (0.74 + 0.26 * sin(a1 * 3.0 + 1.3) + 0.12 * sin(a1 * 7.0))
		var p0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		_tri(st, Vector3.ZERO, p1, p0, col, col, col, Vector3.UP)
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
