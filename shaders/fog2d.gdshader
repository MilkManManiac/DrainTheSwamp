shader_type canvas_item;
// fbm fog overlay using a seamless NoiseTexture2D. Drifting velocity.
// Use on a ColorRect band; BLEND_MODE_MIX (low ground mist) or in parallax (high haze).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float time = 0.0;
uniform vec3 fog_color : source_color = vec3(0.72, 0.78, 0.74);
uniform vec2 drift = vec2(0.015, -0.006);  // velocity (x sideways, y upward = negative)
uniform float shift : hint_range(0.0, 1.0) = 0.45;  // sparsity threshold
uniform float density : hint_range(0.0, 1.0) = 0.35; // master opacity
uniform float scale : hint_range(0.5, 6.0) = 2.0;    // uv tiling

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += texture(noise_tex, p).r * amp;
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	if (density < 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = UV * scale + drift * time;
		float n = fbm(p);
		// Sparsity: only the denser pockets show as fog
		float a = smoothstep(shift, shift + 0.45, n) * density;
		// Fade top & bottom edges of the band so it blends softly
		a *= smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.8, UV.y);
		COLOR = vec4(fog_color, a);
	}
}
