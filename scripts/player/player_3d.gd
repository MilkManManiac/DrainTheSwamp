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
	# palette — a swamp worker
	var boot := Color(0.28, 0.20, 0.12)
	var pants := Color(0.27, 0.34, 0.52)
	var shirt := Color(0.74, 0.36, 0.26)
	var skin := Color(0.85, 0.66, 0.50)
	var hat := Color(0.45, 0.34, 0.18)

	leg_l = _box(visual, Vector3(-0.16, 0.42, 0), Vector3(0.26, 0.5, 0.3), pants)
	leg_r = _box(visual, Vector3(0.16, 0.42, 0), Vector3(0.26, 0.5, 0.3), pants)
	_box(visual, Vector3(-0.16, 0.12, 0.02), Vector3(0.28, 0.2, 0.36), boot)
	_box(visual, Vector3(0.16, 0.12, 0.02), Vector3(0.28, 0.2, 0.36), boot)

	torso = Node3D.new()
	torso.position = Vector3(0, 0.95, 0)
	visual.add_child(torso)
	_box(torso, Vector3(0, 0.18, 0), Vector3(0.62, 0.66, 0.42), shirt)
	arm_l = _box(torso, Vector3(-0.40, 0.12, 0), Vector3(0.18, 0.55, 0.22), shirt)
	arm_r = _box(torso, Vector3(0.40, 0.12, 0), Vector3(0.18, 0.55, 0.22), shirt)
	_box(torso, Vector3(0, 0.62, 0), Vector3(0.4, 0.4, 0.4), skin)        # head
	_box(torso, Vector3(0, 0.86, 0), Vector3(0.52, 0.12, 0.52), hat)     # hat brim
	_box(torso, Vector3(0, 0.96, 0), Vector3(0.34, 0.16, 0.34), hat)     # hat top

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = dir * BASE_SPEED * GameManager.get_movement_speed_multiplier()
	velocity.z = 0.0
	move_and_slide()
	global_position.z = RAIL_Z

	if dir != 0.0:
		facing = signf(dir)
		visual.rotation.y = 0.0 if facing > 0.0 else PI

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
