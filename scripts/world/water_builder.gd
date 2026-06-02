class_name WaterBuilder
extends RefCounted

# One animated water surface per pool (subdivided plane + water3d shader). Level driven
# by the drain fill fraction. Reuses WorldData geometry + per-pool colors.

const WATER_SHADER = preload("res://shaders/water3d.gdshader")
const RIM_DROP: float = 0.45        # sit the full surface just below the rim

var pools: Array = []   # [{node, floor_y, full_h}]

func build(parent: Node3D) -> void:
	pools.clear()
	for i in range(WorldData.SWAMP_COUNT):
		var r: Array = WorldData.SWAMP_RANGES[i]
		var ea: Vector2 = WorldData.TERRAIN_POINTS[r[0]]
		var eb: Vector2 = WorldData.TERRAIN_POINTS[r[1]]
		var x0: float = WorldData.to_world_x(ea.x)
		var x1: float = WorldData.to_world_x(eb.x)

		var full_orig_y: float = minf(ea.y, eb.y)
		var floor_orig_y: float = ea.y
		for idx in range(r[0], r[1] + 1):
			floor_orig_y = maxf(floor_orig_y, WorldData.TERRAIN_POINTS[idx].y)
		var floor_y: float = WorldData.elev(floor_orig_y)
		var full_top_y: float = WorldData.elev(full_orig_y) - RIM_DROP
		var full_h: float = maxf(full_top_y - floor_y, 0.05)

		# full-depth channel pond (fills the screen) — the look the user preferred
		var zf := WorldData.FRONT_Z - 1.5
		var zb := WorldData.FRONT_Z - WorldData.DEPTH + 1.5
		var width := x1 - x0
		var depth := zf - zb

		var plane := PlaneMesh.new()
		plane.size = Vector2(width, depth)
		plane.subdivide_width = clampi(int(width), 2, 48)
		plane.subdivide_depth = clampi(int(depth * 0.5), 2, 48)

		var col: Color = WorldData.SWAMP_WATER_COLORS[i]
		var shallow: Color = col.lerp(Color(0.34, 0.46, 0.36), 0.4)   # murky, not bright
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("deep_color", col)
		mat.set_shader_parameter("shallow_color", shallow)
		# bigger pools = larger, slower swells
		var size_f: float = clampf(width / 30.0, 0.4, 2.2)
		mat.set_shader_parameter("wave_amp", 0.04 + size_f * 0.035)
		mat.set_shader_parameter("wave_scale", 0.85 - size_f * 0.18)
		mat.set_shader_parameter("wave_speed", 1.2 - size_f * 0.25)
		mat.set_shader_parameter("water_alpha", 0.98)   # opaque swamp water, not see-through

		var mi := MeshInstance3D.new()
		mi.name = "Water%d" % i
		mi.mesh = plane
		mi.material_override = mat
		mi.position = Vector3((x0 + x1) * 0.5, full_top_y, (zf + zb) * 0.5)
		parent.add_child(mi)

		pools.append({"node": mi, "floor_y": floor_y, "full_h": full_h})
		update_fill(i, GameManager.get_swamp_fill_fraction(i))

func update_fill(i: int, fill: float) -> void:
	if i < 0 or i >= pools.size():
		return
	var p: Dictionary = pools[i]
	var mi: MeshInstance3D = p["node"]
	fill = clampf(fill, 0.0, 1.0)
	if fill <= 0.001:
		mi.visible = false
		return
	mi.visible = true
	mi.position.y = p["floor_y"] + p["full_h"] * fill
