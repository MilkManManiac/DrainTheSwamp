shader_type canvas_item;
render_mode blend_add;
// Procedural additive god-rays / light shafts. No textures.
// Mount on a full-rect ColorRect behind the treeline (additive via render_mode).

uniform float time = 0.0;
uniform float angle : hint_range(-1.5, 1.5) = 0.5;     // shaft tilt (radians)
uniform float ray_density : hint_range(2.0, 40.0) = 12.0;
uniform vec3 ray_color : source_color = vec3(1.0, 0.9, 0.65);
uniform float strength : hint_range(0.0, 1.0) = 0.0;   // master fade (time-of-day driven)
uniform float ray_speed : hint_range(0.0, 1.0) = 0.05;

// 1D-ish hash for an animated noise field
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// Smooth 1D value noise
float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void fragment() {
	if (strength < 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = UV;
		// Rotate UV so the shaft axis tilts
		float s = sin(angle);
		float c = cos(angle);
		float axis = uv.x * c - uv.y * s;

		// Animated 1D noise field across the shaft axis = soft ray bands
		float coord = axis * ray_density + time * ray_speed;
		float n = noise1(coord) * 0.6 + noise1(coord * 2.3 + 5.0) * 0.4;
		float rays = smoothstep(0.45, 0.95, n);

		// Fade the screen sides so rays don't hit hard edges
		float side_fade = smoothstep(0.0, 0.25, uv.x) * smoothstep(1.0, 0.75, uv.x);
		// Rays emanate from the top (sky) and fade toward the ground
		float vert_fade = smoothstep(1.0, 0.15, uv.y);

		float a = rays * side_fade * vert_fade * strength * 0.5;
		COLOR = vec4(ray_color * a, a);
	}
}
