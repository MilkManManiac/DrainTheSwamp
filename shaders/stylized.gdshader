shader_type spatial;
render_mode cull_disabled;

// Shared "premium cozy stylized" material for the whole scene — gives a cohesive
// painterly read across foliage, props and ground. Built from the research playbook:
//   • custom light(): half-Lambert WRAP (soft cozy terminator) + soft AA bands +
//     saturation split (rich light / muted shade). Cool "never-black" shade comes from
//     ambient/GI (sky + SDFGI), so cast shadows still read correctly.
//   • BACKLIGHT / fake subsurface scattering, auto-masked to green foliage (COLOR.g)
//     so leaves/grass glow when backlit while trunks/rocks stay solid.
//   • fresnel RIM pushed to EMISSION → silhouettes separate from the dark swamp + fog.
//   • optional height-based wind sway (trunks anchored, canopies/blades sway).

uniform float sway_strength = 0.0;          // 0 = static (props/ground); >0 = foliage sway
uniform float sway_speed = 1.4;
uniform float surf_roughness : hint_range(0.0, 1.0) = 0.9;
uniform vec4  albedo_tint : source_color = vec4(1.0);           // multiplies COLOR (char pieces)
uniform float backlight_strength : hint_range(0.0, 2.0) = 0.4;  // masks to greenery (ALBEDO.g)
uniform vec3  rim_color : source_color = vec3(0.96, 0.99, 0.82);
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.14;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.18;
uniform float bands : hint_range(1.0, 5.0) = 3.0;
uniform float band_softness : hint_range(0.0, 0.5) = 0.09;
uniform float sat_split : hint_range(0.0, 0.6) = 0.22;          // shade desat ↔ light oversat

void vertex() {
	if (sway_strength > 0.0) {
		vec3 wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float phase = wpos.x * 0.25 + wpos.z * 0.25 + TIME * sway_speed;
		float s = sin(phase) + 0.4 * sin(phase * 2.3 + 1.0);
		VERTEX.x += s * sway_strength * h;
		VERTEX.z += cos(phase * 0.8) * sway_strength * h * 0.5;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * albedo_tint.rgb;
	ROUGHNESS = surf_roughness;
	METALLIC = 0.0;
	// stylized edge glow that survives shadow + fog (additive into emission)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION += rim_color * fres * rim_strength * 0.5;
}

void light() {
	// half-Lambert wrap → lifted, cozy terminator
	float ndl = dot(NORMAL, LIGHT);
	float lambert = clamp((ndl + light_wrap) / (1.0 + light_wrap), 0.0, 1.0);

	// soft, anti-aliased bands (painterly, not hard cel)
	float stepped = floor(lambert * bands) / bands;
	float frac = fract(lambert * bands);
	float aa = fwidth(lambert * bands) + 0.001;
	float soft = smoothstep(0.5 - band_softness - aa, 0.5 + band_softness + aa, frac) / bands;
	float band = clamp(stepped + soft, 0.0, 1.0);
	float key = band * ATTENUATION;          // zero in cast shadow → shadows read; ambient fills

	// saturation split: rich in the light, muted toward the shade
	vec3 base = ALBEDO;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(lum), base, mix(1.0 - sat_split, 1.0 + sat_split, key));
	DIFFUSE_LIGHT += graded * LIGHT_COLOR * key * (1.0 / PI);

	// backlight / fake SSS — light transmitted through thin greenery. COLOR isn't available
	// in light(), so mask on ALBEDO.g (green = leaves/grass glow; brown/grey stays opaque).
	vec3 lt = normalize(LIGHT + NORMAL * 0.02);
	float back = pow(clamp(dot(VIEW, -lt), 0.0, 1.0), 5.0) * 3.0;
	float greenish = clamp(ALBEDO.g - max(ALBEDO.r, ALBEDO.b) * 0.6, 0.0, 1.0);
	float sss = back * greenish * backlight_strength * ATTENUATION;
	DIFFUSE_LIGHT += base * LIGHT_COLOR * sss * (1.0 / PI);
}
