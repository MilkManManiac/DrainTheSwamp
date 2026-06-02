shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx, diffuse_burley;

// Stylized water: animated wave surface with analytic normals, fresnel sky-rim,
// UV-based depth gradient (deep centre → light shore), drifting + shore foam.
// (Depth-texture absorption/refraction is a planned upgrade; this version is
// camera-agnostic and reliable.)

uniform vec3 deep_color : source_color = vec3(0.05, 0.20, 0.30);
uniform vec3 shallow_color : source_color = vec3(0.30, 0.60, 0.62);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform float wave_amp = 0.07;
uniform float wave_scale = 0.55;
uniform float wave_speed = 1.1;
uniform float water_alpha = 0.9;
uniform float foam_amount = 0.22;
uniform float sparkle = 0.25;

float h_wave(vec2 p, float t) {
	return sin(p.x * wave_scale + t) * 0.6
		+ sin(p.y * wave_scale * 0.8 - t * 0.9) * 0.4
		+ sin((p.x + p.y) * wave_scale * 1.3 + t * 1.4) * 0.25;
}
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	float t = TIME * wave_speed;
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float e = 0.35;
	float hc = h_wave(p, t);
	VERTEX.y += hc * wave_amp;
	NORMAL = normalize(vec3(-(h_wave(p + vec2(e, 0), t) - hc) / e * wave_amp, 1.0,
		-(h_wave(p + vec2(0, e), t) - hc) / e * wave_amp));
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));

	vec3 col = deep_color;
	col = mix(col, shallow_color, smoothstep(0.28, 0.0, edge) * 0.6);
	col = mix(col, shallow_color, fres * 0.35);

	float n = vnoise(UV * 11.0 + vec2(TIME * 0.04, TIME * 0.03));
	float n2 = vnoise(UV * 24.0 - vec2(TIME * 0.06, TIME * 0.02));
	float foam = smoothstep(0.88, 0.99, n * n2) * foam_amount;
	float shore = smoothstep(0.022, 0.0, edge) * 0.5;
	col = mix(col, foam_color, clamp(foam + shore, 0.0, 1.0));
	col += foam_color * smoothstep(0.975, 1.0, n2) * sparkle * 0.18;

	ALBEDO = col;
	ALPHA = water_alpha;
	ROUGHNESS = 0.36;
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
