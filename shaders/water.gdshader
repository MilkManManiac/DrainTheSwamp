shader_type canvas_item;

// --- Time / motion ---
uniform float time = 0.0;
uniform float wave_strength : hint_range(0.0, 4.0) = 1.5;
uniform float choppiness : hint_range(0.0, 3.0) = 0.0;

// --- Murky bayou depth tint (Beer-Lambert) ---
uniform vec3 shallow_color : source_color = vec3(0.14, 0.20, 0.13);
uniform vec3 deep_color : source_color = vec3(0.04, 0.08, 0.07);
uniform float beers : hint_range(0.0, 8.0) = 3.5;
uniform float opacity_floor : hint_range(0.0, 1.0) = 0.55;
uniform float turbidity : hint_range(0.0, 1.0) = 0.0;

// --- Reflection / surface ---
uniform vec3 sky_color : source_color = vec3(0.55, 0.62, 0.45); // warm canopy
uniform float reflect_strength : hint_range(0.0, 1.0) = 0.35;
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float foam_density : hint_range(0.0, 2.0) = 1.0;
uniform vec3 foam_color : source_color = vec3(0.85, 0.92, 0.80);
uniform float daytime : hint_range(0.0, 1.0) = 1.0;
// HDR: push surface highlights (sparkle/spec/glint) >1.0 so they bloom on Forward+.
// 1.0 = no change (GL-compat/web). Set ~2.5 from GDScript on desktop.
uniform float hdr_boost = 1.0;

// --- Screen-space refraction (opt-in; 0 = no-op, safe for caves) ---
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D distort_tex : repeat_enable, filter_linear;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.0;
uniform bool use_refraction = false;

// --- Tier-1 interactive ripples ---
uniform vec2 ripple_pos[8];
uniform float ripple_t[8];   // age in seconds; <0 = inactive
uniform float ripple_amp[8];

varying vec2 world_pos;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Single Gerstner-ish vertical contribution at a world-x for a given freq/speed.
float gerstner_y(float x, float freq, float speed, float amp) {
	return sin(x * freq + time * speed) * amp;
}

// Expanding decaying ring contribution from a ripple at world position rp.
float ripple_field(vec2 wp) {
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		float age = ripple_t[i];
		if (age < 0.0) {
			continue;
		}
		float d = distance(wp, ripple_pos[i]);
		float radius = age * 60.0;             // ring expansion speed (px/s)
		float life = clamp(1.0 - age / 2.5, 0.0, 1.0);
		float ring = sin(d * 0.45 - age * 9.0);
		// gaussian band around the expanding radius
		float band = exp(-pow((d - radius) * 0.08, 2.0));
		total += ring * band * life * ripple_amp[i];
	}
	return total;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// Only the top edge (UV.y near 0) moves; basin floor stays anchored to the bank.
	float surf = smoothstep(0.18, 0.0, UV.y);
	float disp = 0.0;
	disp += gerstner_y(world_pos.x, 0.10, 2.0, wave_strength);
	disp += gerstner_y(world_pos.x, 0.23, 3.1, wave_strength * 0.4);
	disp += gerstner_y(world_pos.x, 0.41, 4.3, choppiness * 0.5);
	// interactive ripple lift at the surface
	disp += ripple_field(world_pos) * 1.5;
	VERTEX.y += disp * surf;
	// slight horizontal sway near surface only
	VERTEX.x += cos(world_pos.y * 0.18 + time * 1.4) * wave_strength * 0.2 * surf;
}

void fragment() {
	vec4 col = COLOR;
	vec3 base = col.rgb;
	float alpha = col.a;

	// --- Screen-space refraction (composite the "behind" terrain first) ---
	if (use_refraction && refraction_strength > 0.0001) {
		vec2 dist_uv = world_pos * 0.01 + vec2(time * 0.03, time * 0.02);
		vec2 d = texture(distort_tex, dist_uv).rg * 2.0 - 1.0;
		float refr = refraction_strength * UV.y * (1.0 - turbidity * 0.85);
		vec2 suv = SCREEN_UV + d * refr;
		base = texture(screen_tex, suv).rgb;
		// refracted content fades to murk with depth; keep some opacity floor
		alpha = max(alpha, opacity_floor);
	}

	// --- Beer-Lambert depth tint (murky, reflection-dominated) ---
	float absorb = 1.0 - exp(-beers * UV.y);
	vec3 tint = mix(shallow_color, deep_color, absorb);
	// even shallow water stays mostly opaque (swamp murk)
	float murk = mix(opacity_floor, 1.0, absorb);
	base = mix(base, tint, murk);
	alpha = max(alpha, mix(opacity_floor, 1.0, absorb * 0.6));

	// --- Warm reflection rim at the waterline ---
	float rim = smoothstep(0.16, 0.0, UV.y);
	float shimmer = vnoise(world_pos * 0.08 + vec2(time * 0.25, 0.0));
	float reflect = rim * reflect_strength * (0.65 + shimmer * 0.7);
	base = mix(base, sky_color, clamp(reflect, 0.0, 1.0));

	// --- Specular glints across surface ---
	float spec_wave = sin(world_pos.x * 0.12 + time * 1.2) * sin(world_pos.x * 0.05 - time * 0.7);
	float spec = pow(max(0.0, spec_wave), 3.0) * specular_intensity;
	spec *= smoothstep(0.35, 0.0, UV.y);
	base += vec3(spec) * vec3(1.0, 0.96, 0.85) * hdr_boost;

	// --- Surface sparkle (warm tint) ---
	if (daytime > 0.1) {
		vec2 sparkle_uv = floor(FRAGCOORD.xy * 0.5) * 0.5;
		float sparkle = hash(sparkle_uv + vec2(floor(time * 4.0)));
		sparkle = step(0.984, sparkle) * daytime * 0.65;
		sparkle *= smoothstep(0.18, 0.0, UV.y);
		base += vec3(sparkle) * vec3(1.0, 0.95, 0.80) * hdr_boost;
	}

	// --- Drifting foam at the surface ---
	float foam_x = world_pos.x * 0.08 + time * 0.05;
	float foam_n = vnoise(vec2(foam_x, time * 0.1)) * 0.5 + vnoise(vec2(foam_x * 2.3, 0.0)) * 0.5;
	float foam = smoothstep(0.10, 0.0, UV.y) * 0.5 * foam_n * foam_density;
	base = mix(base, foam_color, clamp(foam, 0.0, 0.8));

	// --- Interactive ripple surface glint ---
	float rp = ripple_field(world_pos);
	base += vec3(max(0.0, rp)) * 0.15 * smoothstep(0.25, 0.0, UV.y) * vec3(1.0, 0.98, 0.9) * hdr_boost;

	// --- Faint caustics (swamp = murky; gated by turbidity) ---
	float caustic1 = sin(world_pos.x * 0.18 + UV.y * 8.0 + time * 1.5);
	float caustic2 = sin(world_pos.x * 0.14 - UV.y * 10.0 + time * 1.1);
	float caustic = pow(max(0.0, caustic1 * caustic2), 2.0) * 0.05 * (1.0 - turbidity * 0.9);
	caustic *= smoothstep(0.1, 0.45, UV.y);
	base += vec3(caustic * 0.5, caustic, caustic * 0.7);

	COLOR = vec4(base, clamp(alpha, 0.0, 1.0));
}
