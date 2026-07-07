shader_type canvas_item;

uniform float noise_scale : hint_range(0.5, 4.0) = 1.5;
uniform float noise_strength : hint_range(0.0, 0.15) = 0.06;
uniform float striation_strength : hint_range(0.0, 0.1) = 0.03;

// --- Ground detail (R3) ---
uniform float fbm_strength : hint_range(0.0, 0.2) = 0.08; // multi-octave mottling
uniform float depth_darken : hint_range(0.0, 1.0) = 0.28; // darken deeper soil
uniform float depth_range : hint_range(20.0, 400.0) = 280.0; // world-Y over which it darkens
uniform float surface_y = -100000.0; // world-Y of nearest surface band (set per-frame, optional)

// --- Receding waterline (R2) ---
// World-Y of the highest/most-recent water line (min screen-Y the water reached)
uniform float high_water_y = -100000.0;
// World-Y of the current water surface
uniform float cur_water_y = -100000.0;
// 0 = freshly exposed (wet/dark/glossy), 1 = fully dried out
uniform float wet_fade : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_pos;

// Simple hash-based noise
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Multi-octave fractal Brownian motion for soil mottling.
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

// 4x4 ordered (Bayer) dither threshold in [0,1).
float bayer4(vec2 fc) {
	int x = int(mod(fc.x, 4.0));
	int y = int(mod(fc.y, 4.0));
	int idx = x + y * 4;
	float m[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	return m[idx] / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 col = COLOR;

	// Procedural grain noise
	vec2 world_uv = FRAGCOORD.xy * noise_scale;
	float n = noise(world_uv * 0.15) * 2.0 - 1.0;
	col.rgb += n * noise_strength;

	// Horizontal striation bands
	float stria = sin(FRAGCOORD.y * 0.8) * 0.5 + 0.5;
	stria *= noise(vec2(FRAGCOORD.y * 0.3, 0.0));
	col.rgb -= stria * striation_strength;

	// Multi-octave FBM mottling (world-space so it doesn't crawl with the camera)
	float m = fbm(world_pos * 0.04) - 0.5;
	col.rgb += m * fbm_strength;
	// Coarser clay/humus blotches
	float blotch = fbm(world_pos * 0.012 + 17.0) - 0.5;
	col.rgb += blotch * fbm_strength * 0.7;

	// Vertical depth-darkening: deeper soil (larger world-Y below surface) is darker.
	if (surface_y > -90000.0) {
		float d = clamp((world_pos.y - surface_y) / depth_range, 0.0, 1.0);
		col.rgb *= mix(1.0, 1.0 - depth_darken, d);
	}

	// Ordered dither on the soil tone so banded gradients stipple intentionally.
	float dth = (bayer4(FRAGCOORD.xy) - 0.5) * (1.0 / 32.0);
	col.rgb += dth;

	// --- Receding waterline wet band ---
	// Band lives between the current water surface (cur_water_y) and the
	// highest line the water ever reached (high_water_y). Larger world-Y = lower.
	if (cur_water_y > -90000.0 && high_water_y > -90000.0) {
		// In the wet band when y is above current water AND below the old high line.
		float in_band = step(cur_water_y - 1.0, world_pos.y) * step(world_pos.y, high_water_y + 1.0);
		// Freshly-exposed strength: strongest right at the current waterline,
		// fading upward toward the old high line, and globally drying via wet_fade.
		float depth_into_band = clamp((world_pos.y - cur_water_y) / max(high_water_y - cur_water_y, 1.0), 0.0, 1.0);
		float band_falloff = 1.0 - depth_into_band;            // 1 near surface, 0 at old line
		float wetness = in_band * band_falloff * (1.0 - wet_fade);
		// Darken + saturate the wet mud
		vec3 wet = col.rgb * 0.55;
		wet = mix(vec3(dot(wet, vec3(0.299, 0.587, 0.114))), wet, 1.4); // boost saturation
		col.rgb = mix(col.rgb, wet, wetness * 0.85);

		// Thin glossy sheen right at the current waterline
		float sheen = smoothstep(3.0, 0.0, abs(world_pos.y - cur_water_y)) * (1.0 - wet_fade);
		col.rgb += vec3(0.10, 0.12, 0.10) * sheen;
	}

	COLOR = col;
}
