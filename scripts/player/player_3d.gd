extends CharacterBody3D

# Swamp-worker player on a Z-rail (free X, gravity Y, Z locked). Chunky-but-rounded body:
# capsule limbs that swing from real hip/shoulder joints, a sphere head, a big floppy hat,
# and lots of small detail. Lit by the shared stylized shader so he reads like the world.

const BASE_SPEED: float = 7.0
const GRAVITY: float = 26.0
const RAIL_Z: float = 0.0
const STYLIZED := preload("res://shaders/stylized.gdshader")

var visual: Node3D
var torso: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var walk_time: float = 0.0
var facing: float = 1.0
var _mats: Dictionary = {}

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(88)   # climb even steep pool/hill slopes
	floor_snap_length = 1.2            # stay glued to the ground walking up/down
	floor_block_on_wall = false
	_build_collision()
	_build_visual()

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.34
	caps.height = 1.95
	cs.shape = caps
	cs.position = Vector3(0, 0.98, 0)
	add_child(cs)

# ── stylized material (shared shader, per-piece albedo tint), cached by colour ──────
func _cmat(col: Color, rim: float = 0.12, rough: float = 0.82) -> ShaderMaterial:
	var key := "%s_%0.2f_%0.2f" % [col.to_html(), rim, rough]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = STYLIZED
	m.set_shader_parameter("albedo_tint", col)
	m.set_shader_parameter("backlight_strength", 0.0)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("surf_roughness", rough)
	_mats[key] = m
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, rim: float = 0.1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _cmat(col, rim)
	parent.add_child(mi)
	return mi

func _cap(parent: Node3D, pos: Vector3, radius: float, height: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 14
	cm.rings = 6
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _cmat(col)
	parent.add_child(mi)
	return mi

func _sph(parent: Node3D, pos: Vector3, scl: Vector3, col: Color, rim: float = 0.12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 18
	sm.rings = 10
	mi.mesh = sm
	mi.position = pos
	mi.scale = scl
	mi.material_override = _cmat(col, rim)
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, height: float, col: Color, rim: float = 0.1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = height
	cm.radial_segments = 20
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _cmat(col, rim)
	parent.add_child(mi)
	return mi

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	# palette — a grizzled swamp worker (faces local +Z = travel direction)
	var boot := Color(0.18, 0.13, 0.09)
	var bootsole := Color(0.10, 0.08, 0.06)
	var denim := Color(0.22, 0.28, 0.43)     # muddy overalls
	var denimd := Color(0.16, 0.21, 0.33)
	var shirt := Color(0.64, 0.33, 0.26)     # faded flannel
	var shirtd := Color(0.50, 0.25, 0.20)
	var skin := Color(0.82, 0.61, 0.46)
	var hat := Color(0.46, 0.35, 0.19)       # straw / canvas
	var hatd := Color(0.34, 0.25, 0.13)
	var dark := Color(0.10, 0.09, 0.07)
	var beardc := Color(0.52, 0.48, 0.42)
	var metal := Color(0.46, 0.48, 0.52)

	# ── LEGS (jointed at the hips) ──
	leg_l = _pivot(visual, Vector3(-0.18, 0.70, 0))
	leg_r = _pivot(visual, Vector3(0.18, 0.70, 0))
	for lp in [leg_l, leg_r]:
		_cap(lp, Vector3(0, -0.28, 0), 0.155, 0.56, denim)
		_box(lp, Vector3(0, -0.5, 0), Vector3(0.26, 0.18, 0.22), denimd)   # cuff
		_box(lp, Vector3(0, -0.62, 0.06), Vector3(0.32, 0.2, 0.46), boot)  # boot
		_box(lp, Vector3(0, -0.71, 0.07), Vector3(0.33, 0.06, 0.48), bootsole)

	# ── TORSO ──
	torso = Node3D.new()
	torso.position = Vector3(0, 0.98, 0)
	visual.add_child(torso)
	_box(torso, Vector3(0, 0.16, 0), Vector3(0.66, 0.72, 0.46), shirt)
	_box(torso, Vector3(0, 0.16, 0.0), Vector3(0.68, 0.36, 0.48), denim)        # overall waist
	_box(torso, Vector3(0, -0.04, 0.205), Vector3(0.5, 0.34, 0.06), denim)      # bib
	_box(torso, Vector3(-0.15, 0.22, 0.215), Vector3(0.08, 0.6, 0.05), denim)   # strap L
	_box(torso, Vector3(0.15, 0.22, 0.215), Vector3(0.08, 0.6, 0.05), denim)    # strap R
	_box(torso, Vector3(-0.15, 0.0, 0.235), Vector3(0.1, 0.08, 0.04), metal)    # buckle L
	_box(torso, Vector3(0.15, 0.0, 0.235), Vector3(0.1, 0.08, 0.04), metal)     # buckle R
	# flannel pocket + a couple of plaid seams
	_box(torso, Vector3(0, 0.34, 0.235), Vector3(0.5, 0.04, 0.02), shirtd)
	_box(torso, Vector3(-0.24, 0.16, 0.18), Vector3(0.04, 0.66, 0.04), shirtd)
	_box(torso, Vector3(0.24, 0.16, 0.18), Vector3(0.04, 0.66, 0.04), shirtd)

	# ── ARMS (jointed at the shoulders) ──
	arm_l = _pivot(torso, Vector3(-0.42, 0.42, 0))
	arm_r = _pivot(torso, Vector3(0.42, 0.42, 0))
	for ap in [arm_l, arm_r]:
		_cap(ap, Vector3(0, -0.26, 0), 0.105, 0.5, shirt)
		_box(ap, Vector3(0, -0.42, 0), Vector3(0.2, 0.14, 0.2), shirtd)   # rolled cuff
		_sph(ap, Vector3(0, -0.54, 0.01), Vector3(0.22, 0.2, 0.22), skin) # hand
	# a battered bucket hanging from his right hand
	_cyl(arm_r, Vector3(0, -0.78, 0.05), 0.19, 0.16, 0.32, metal)
	_cyl(arm_r, Vector3(0, -0.62, 0.05), 0.2, 0.2, 0.04, metal.lightened(0.12))  # rim
	_box(arm_r, Vector3(0, -0.62, 0.05), Vector3(0.42, 0.03, 0.03), metal.darkened(0.1))  # handle

	# ── HEAD ──
	var head := _sph(torso, Vector3(0, 0.62, 0), Vector3(0.47, 0.5, 0.47), skin, 0.14)
	_sph(torso, Vector3(-0.235, 0.6, 0.02), Vector3(0.1, 0.14, 0.1), skin)   # ear L
	_sph(torso, Vector3(0.235, 0.6, 0.02), Vector3(0.1, 0.14, 0.1), skin)    # ear R
	# eyes (white + dark pupil), brows, nose
	_sph(torso, Vector3(-0.1, 0.66, 0.2), Vector3(0.1, 0.12, 0.06), Color(0.93, 0.92, 0.88))
	_sph(torso, Vector3(0.1, 0.66, 0.2), Vector3(0.1, 0.12, 0.06), Color(0.93, 0.92, 0.88))
	_sph(torso, Vector3(-0.1, 0.66, 0.235), Vector3(0.05, 0.06, 0.04), dark)
	_sph(torso, Vector3(0.1, 0.66, 0.235), Vector3(0.05, 0.06, 0.04), dark)
	_box(torso, Vector3(-0.11, 0.74, 0.21), Vector3(0.13, 0.04, 0.05), beardc.darkened(0.15))  # brow L
	_box(torso, Vector3(0.11, 0.74, 0.21), Vector3(0.13, 0.04, 0.05), beardc.darkened(0.15))   # brow R
	_sph(torso, Vector3(0, 0.6, 0.245), Vector3(0.11, 0.1, 0.12), skin.darkened(0.05))         # nose
	# bushy beard wrapping the lower face
	_box(torso, Vector3(0, 0.49, 0.18), Vector3(0.4, 0.26, 0.16), beardc)
	_sph(torso, Vector3(0, 0.4, 0.16), Vector3(0.34, 0.26, 0.22), beardc)
	_sph(torso, Vector3(-0.2, 0.52, 0.1), Vector3(0.14, 0.2, 0.16), beardc)
	_sph(torso, Vector3(0.2, 0.52, 0.1), Vector3(0.14, 0.2, 0.16), beardc)

	# ── BIG HAT (wide floppy brim + tall crown + band) ──
	_cyl(torso, Vector3(0, 0.86, 0.0), 0.62, 0.66, 0.07, hat, 0.16)   # broad floppy brim
	_cyl(torso, Vector3(0, 0.85, 0.18), 0.5, 0.6, 0.05, hatd, 0.16)   # front brim droop
	_cyl(torso, Vector3(0, 1.0, 0), 0.3, 0.38, 0.34, hat, 0.16)       # crown
	_cyl(torso, Vector3(0, 1.18, 0), 0.31, 0.3, 0.06, hat, 0.16)      # crown top
	_cyl(torso, Vector3(0, 0.9, 0), 0.4, 0.41, 0.08, hatd, 0.12)      # hat band
	_box(torso, Vector3(0.0, 0.9, 0.4), Vector3(0.12, 0.08, 0.04), Color(0.7, 0.62, 0.4))  # band patch

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = dir * BASE_SPEED * GameManager.get_movement_speed_multiplier()
	velocity.z = 0.0
	move_and_slide()
	# follow the winding path in Z
	global_position.z = WorldData.path_z(global_position.x)

	# face along the path in the direction of travel, smoothly
	if dir != 0.0:
		facing = signf(dir)
	var target_yaw: float = PI * 0.5 * facing - WorldData.path_tangent_yaw(global_position.x)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(delta * 12.0, 0.0, 1.0))

	var walking: bool = absf(dir) > 0.01 and is_on_floor()
	if walking:
		walk_time += delta * 9.0
		var s := sin(walk_time)
		visual.position.y = absf(s) * 0.06
		leg_l.rotation.x = s * 0.5
		leg_r.rotation.x = -s * 0.5
		arm_l.rotation.x = -s * 0.5
		arm_r.rotation.x = s * 0.5
		torso.rotation.z = s * 0.03
	else:
		walk_time = 0.0
		visual.position.y = lerpf(visual.position.y, 0.0, 0.2)
		for n in [leg_l, leg_r, arm_l, arm_r]:
			n.rotation.x = lerpf(n.rotation.x, 0.0, 0.2)
		torso.rotation.z = lerpf(torso.rotation.z, 0.0, 0.2)
