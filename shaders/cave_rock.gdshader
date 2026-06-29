shader_type canvas_item;

// Procedural rock surface for cave Polygon2D fills. Driven by world position
// (via VERTEX) so there's no Polygon2D-UV gotcha and the texture doesn't crawl with
// the camera. Fragment-based faux relief (a fixed light direction shades the derived
// normal) so the rock reads 3D everywhere — not only where a Light2D happens to reach.
// GL-Compatibility safe (no screen texture, no derivatives).

uniform float surf_scale : hint_range(0.5, 8.0) = 2.4;   // rock-grain frequency
uniform float relief_strength : hint_range(0.0, 1.2) = 0.6; // how chunky the bumps read
uniform float crack_strength : hint_range(0.0, 1.0) = 0.45; // dark Voronoi fissures
uniform float crack_scale : hint_range(0.5, 6.0) = 1.8;
uniform float strata_strength : hint_range(0.0, 0.5) = 0.12; // horizontal sediment banding
uniform float mottle_strength : hint_range(0.0, 0.3) = 0.10;
uniform vec2 light_dir = vec2(-0.55, -0.8);              // faux key light (upper-left)
uniform float emit_boost : hint_range(1.0, 3.0) = 1.0;   // >1 when HDR is on, to bloom highlights

varying vec2 world_pos;

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

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p = p * 2.0 + 7.0;
		amp *= 0.5;
	}
	return v;
}

// Domain-warped fbm — flowing sedimentary strata instead of uniform mush.
float warped(vec2 p) {
	vec2 q = vec2(fbm(p), fbm(p + vec2(5.2, 1.3)));
	return fbm(p + 1.8 * q);
}

// Voronoi F1 distance — small near cell borders, used to carve crack seams.
float voronoi_f1(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float md = 1.5;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash(ip + g), hash(ip + g + 19.7));
			vec2 r = g + o - fp;
			md = min(md, dot(r, r));
		}
	}
	return sqrt(md);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 col = COLOR;
	vec2 wp = world_pos / 64.0;

	// Height field + finite-difference normal for faux relief shading.
	float e = 0.045;
	float h  = warped(wp * surf_scale);
	float hx = warped((wp + vec2(e, 0.0)) * surf_scale);
	float hy = warped((wp + vec2(0.0, e)) * surf_scale);
	vec3 nrm = normalize(vec3((h - hx) * relief_strength * 12.0, (h - hy) * relief_strength * 12.0, 1.0));
	float diff = clamp(dot(nrm, normalize(vec3(light_dir, 0.9))), 0.0, 1.0);
	// Map relief into a shade multiplier (recess dark -> ridge bright).
	float shade = mix(1.0 - relief_strength * 0.6, 1.0 + relief_strength * 0.45, diff);
	col.rgb *= shade;

	// Coarse mottling so flat areas aren't uniform.
	float m = warped(wp * surf_scale * 0.35 + 11.0) - 0.5;
	col.rgb += m * mottle_strength;

	// Horizontal strata banding (squash Y so bands are wide and rocky).
	float band = sin(world_pos.y * 0.06 + warped(wp * 0.6) * 3.0);
	col.rgb -= smoothstep(0.4, 1.0, band) * strata_strength;

	// Voronoi crack seams — darken thin borders.
	float vd = voronoi_f1(wp * crack_scale);
	float crack = 1.0 - smoothstep(0.0, 0.07, vd);
	col.rgb *= 1.0 - crack * crack_strength;

	// Faint ridge sheen on the brightest relief (kept subtle so it reads as damp
	// stone catching light, not snow). Tinted to the rock, not pure white.
	float spark = smoothstep(0.92, 1.0, diff) * 0.05;
	col.rgb += col.rgb * spark * emit_boost;

	COLOR = col;
}
