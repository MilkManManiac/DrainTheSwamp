extends CharacterBody3D

# Voxel player on a Z-rail (free X, gravity Y, Z locked). Chunky low-poly body built
# from boxes, with a walk bob/stride. Movement speed reads GameManager so upgrades apply.
# Scoop/proximity wiring comes next; this first pass is about walking through the world.

const BASE_SPEED: float = 7.0
const GRAVITY: float = 26.0
const RAIL_Z: float = 0.0

var visual: Node3D
var torso: Node3D
var leg_l: MeshInstance3D
var leg_r: MeshInstance3D
var arm_l: MeshInstance3D
var arm_r: MeshInstance3D
var walk_time: float = 0.0
var facing: float = 1.0

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
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.7, 0.6)
	cs.shape = box
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)

func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	# palette — a grizzled swamp worker (faces local +Z = travel direction)
	var boot := Color(0.20, 0.14, 0.09)
	var denim := Color(0.23, 0.29, 0.44)     # muddy overalls
	var shirt := Color(0.62, 0.34, 0.27)     # faded flannel
	var skin := Color(0.80, 0.60, 0.45)
	var hat := Color(0.40, 0.31, 0.17)
	var dark := Color(0.12, 0.10, 0.07)
	var beardc := Color(0.46, 0.42, 0.36)
	var metal := Color(0.44, 0.46, 0.50)

	leg_l = _box(visual, Vector3(-0.16, 0.42, 0), Vector3(0.26, 0.5, 0.3), denim)
	leg_r = _box(visual, Vector3(0.16, 0.42, 0), Vector3(0.26, 0.5, 0.3), denim)
	_box(visual, Vector3(-0.16, 0.12, 0.03), Vector3(0.3, 0.2, 0.4), boot)
	_box(visual, Vector3(0.16, 0.12, 0.03), Vector3(0.3, 0.2, 0.4), boot)

	torso = Node3D.new()
	torso.position = Vector3(0, 0.95, 0)
	visual.add_child(torso)
	_box(torso, Vector3(0, 0.18, 0), Vector3(0.62, 0.66, 0.42), shirt)
	# overall straps down the chest
	_box(torso, Vector3(-0.14, 0.2, 0.20), Vector3(0.08, 0.54, 0.05), denim)
	_box(torso, Vector3(0.14, 0.2, 0.20), Vector3(0.08, 0.54, 0.05), denim)
	_box(torso, Vector3(0, -0.05, 0.20), Vector3(0.5, 0.28, 0.06), denim)   # overall bib

	arm_l = _box(torso, Vector3(-0.40, 0.12, 0), Vector3(0.18, 0.55, 0.22), shirt)
	arm_r = _box(torso, Vector3(0.40, 0.12, 0), Vector3(0.18, 0.55, 0.22), shirt)
	_box(arm_l, Vector3(0, -0.34, 0), Vector3(0.2, 0.16, 0.24), skin)        # hand
	_box(arm_r, Vector3(0, -0.34, 0), Vector3(0.2, 0.16, 0.24), skin)        # hand
	# a battered bucket swinging in his right hand
	_box(arm_r, Vector3(0, -0.56, 0.04), Vector3(0.28, 0.26, 0.28), metal)
	_box(arm_r, Vector3(0, -0.44, 0.04), Vector3(0.3, 0.05, 0.3), metal.lightened(0.1))

	_box(torso, Vector3(0, 0.62, 0), Vector3(0.4, 0.4, 0.4), skin)           # head
	_box(torso, Vector3(-0.10, 0.69, 0.21), Vector3(0.07, 0.09, 0.04), dark) # eye
	_box(torso, Vector3(0.10, 0.69, 0.21), Vector3(0.07, 0.09, 0.04), dark)  # eye
	_box(torso, Vector3(0, 0.61, 0.23), Vector3(0.09, 0.08, 0.08), skin)     # nose
	_box(torso, Vector3(0, 0.50, 0.17), Vector3(0.34, 0.22, 0.14), beardc)   # beard
	_box(torso, Vector3(0, 0.86, 0), Vector3(0.6, 0.1, 0.6), hat)            # wide hat brim
	_box(torso, Vector3(0, 0.99, 0), Vector3(0.36, 0.24, 0.36), hat)         # hat crown

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = dir * BASE_SPEED * GameManager.get_movement_speed_multiplier()
	velocity.z = 0.0
	move_and_slide()
	global_position.z = RAIL_Z

	# turn to face the direction of travel (profile), smoothly
	if dir != 0.0:
		facing = signf(dir)
	var target_yaw: float = PI * 0.5 * facing   # +X (right) → +90°, -X (left) → -90°
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
