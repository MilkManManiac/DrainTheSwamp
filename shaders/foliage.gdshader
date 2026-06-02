shader_type spatial;
render_mode cull_disabled;

// Wind-swayed foliage: vertex colour as albedo, gentle sway that scales with height
// (trunks stay put, canopies/blades sway). Per-instance phase from world position so
// the forest doesn't sway in lockstep.

uniform float sway_strength = 0.06;
uniform float sway_speed = 1.4;

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float phase = wpos.x * 0.25 + wpos.z * 0.25 + TIME * sway_speed;
	float s = sin(phase) + 0.4 * sin(phase * 2.3 + 1.0);
	VERTEX.x += s * sway_strength * h;
	VERTEX.z += cos(phase * 0.8) * sway_strength * h * 0.5;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.93;
	METALLIC = 0.0;
}
