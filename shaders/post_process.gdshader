shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float time = 0.0;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.15;
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float heat_shimmer_strength : hint_range(0.0, 1.0) = 0.0;
uniform float warmth : hint_range(-0.1, 0.1) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 3.0) = 0.5;
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float film_grain_strength : hint_range(0.0, 0.1) = 0.03;

// Wider bloom (single-pass threshold Gaussian bright-pass)
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float bloom_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float bloom_radius : hint_range(0.5, 6.0) = 3.0;

// Ordered (Bayer) posterize + dither
uniform float dither_levels : hint_range(2.0, 64.0) = 14.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.5;

// Simple hash for film grain noise
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0));

void fragment() {
	vec2 uv = SCREEN_UV;

	// Heat shimmer distortion (subtle wavy air)
	if (heat_shimmer_strength > 0.001) {
		float shimmer_x = sin(uv.y * 50.0 + time * 1.8) * 0.0008 * heat_shimmer_strength;
		float shimmer_y = cos(uv.x * 40.0 + time * 1.3) * 0.0004 * heat_shimmer_strength;
		uv += vec2(shimmer_x, shimmer_y);
	}

	// Chromatic aberration (subtle RGB split at screen edges)
	vec4 col;
	if (chromatic_aberration > 0.01) {
		vec2 ca_dir = (uv - 0.5) * chromatic_aberration * 0.002;
		float r = texture(screen_texture, uv + ca_dir).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv - ca_dir).b;
		col = vec4(r, g, b, 1.0);
	} else {
		col = texture(screen_texture, uv);
	}

	// Wider threshold-Gaussian bloom add (single pass, ~25-tap)
	if (bloom_intensity > 0.001) {
		vec3 b = vec3(0.0);
		float w = 0.0;
		vec2 tx = SCREEN_PIXEL_SIZE * bloom_radius;
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				float ww = exp(-float(x * x + y * y) * 0.4);
				vec3 c = texture(screen_texture, uv + vec2(float(x), float(y)) * tx).rgb;
				float l = dot(c, vec3(0.299, 0.587, 0.114));
				b += c * smoothstep(bloom_threshold, 1.0, l) * ww;
				w += ww;
			}
		}
		col.rgb += (b / w) * bloom_intensity;
	}

	// Ordered Bayer posterize + dither (subtle premium stipple)
	if (dither_strength > 0.001) {
		float dth = BAYER[int(FRAGCOORD.x) % 4][int(FRAGCOORD.y) % 4] / 16.0 - 0.5;
		vec3 q = floor(col.rgb * dither_levels + dth) / dither_levels;
		col.rgb = mix(col.rgb, q, dither_strength);
	}

	// Saturation adjustment (world progression: desaturated early, vibrant late)
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(gray), col.rgb, saturation);

	// Warm/cool color grading shift
	col.r += warmth;
	col.b -= warmth;

	// Night blue shift (beyond CanvasModulate darkening)
	if (night_factor > 0.001) {
		col.rgb = mix(col.rgb, col.rgb * vec3(0.7, 0.75, 1.15), night_factor * 0.3);
	}

	// Film grain (animated noise overlay)
	if (film_grain_strength > 0.001) {
		float grain = hash(uv * vec2(640.0, 360.0) + vec2(time * 7.3, time * 3.7)) - 0.5;
		col.rgb += grain * film_grain_strength;
	}

	// CRT scanlines (subtle darkening on alternating rows)
	float scanline = sin(FRAGCOORD.y * 3.14159265) * 0.5 + 0.5;
	col.rgb -= scanline_strength * (1.0 - scanline);

	// Vignette (darken edges)
	vec2 center = uv - 0.5;
	float dist = length(center);
	float vignette = smoothstep(0.4, 0.85, dist * 1.4);
	col.rgb *= 1.0 - vignette * vignette_strength;

	COLOR = col;
}
