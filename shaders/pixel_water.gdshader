shader_type canvas_item;
// v3 pixel water (scripts/world/water_skin.gd). Everything is quantized to the
// art grid (1 world unit = 1 art px): flat depth bands with an integer wobble
// on the band edges, two rows of dashed highlight pixels that step one art px
// at a time, no gradients, no noise. Colours are decided on the CPU (murk /
// heal grade / time of day) so the shader only bands and dashes.

uniform float time = 0.0;
uniform float surface_y = 0.0;      // world y of the waterline
uniform float band1 : hint_range(1.0, 40.0) = 5.0;   // surface band thickness (art px)
uniform float band2 : hint_range(2.0, 80.0) = 14.0;  // surface + mid thickness
uniform vec3 col_top : source_color = vec3(0.52, 0.55, 0.32);   // 1 px waterline
uniform vec3 col_surf : source_color = vec3(0.33, 0.38, 0.19);
uniform vec3 col_mid : source_color = vec3(0.24, 0.29, 0.14);
uniform vec3 col_deep : source_color = vec3(0.16, 0.19, 0.10);
uniform vec3 col_hi : source_color = vec3(0.62, 0.64, 0.40);    // highlight dashes
uniform float hi_amount : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.97;
uniform float drift = 3.0;          // highlight scroll, art px per second

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// integer wobble in -1..1 for a band edge, slow, quantized
float wobble(float x, float freq, float phase, float speed) {
	return floor(sin(x * freq + phase + time * speed) * 1.5 + 0.5);
}

void fragment() {
	vec2 cell = floor(world_pos);
	float d = cell.y - floor(surface_y);     // depth in art px, 0 = waterline row
	float e1 = band1 + wobble(cell.x, 0.19, 0.0, 0.35);
	float e2 = band2 + wobble(cell.x, 0.11, 2.1, 0.22);
	vec3 c = col_deep;
	if (d < 1.0) {
		c = col_top;
	} else if (d < e1) {
		c = col_surf;
	} else if (d < e2) {
		c = col_mid;
	}
	// Highlight dashes: row A rides in the surface band, row B in the mid band.
	// Each steps one art px at a time; the rows drift in opposite directions and
	// bend by one px along a slow column sine so they never read as a ruler.
	float sA = floor(time * drift);
	float sB = floor(time * drift * 0.45);
	float xa = cell.x + sA;
	float xb = cell.x - sB;
	float rowA = 2.0 + floor(sin(cell.x * 0.07 + 0.8) + 0.5);
	float rowB = e1 + 2.0 + floor(sin(cell.x * 0.05 + 2.4) + 0.5);
	float sC = floor(time * drift * 0.7);
	float xc = cell.x + sC + 11.0;
	float rowC = e2 + 3.0 + floor(sin(cell.x * 0.06 + 4.0) + 0.5);
	float dashA = step(mod(xa, 20.0), 7.0) * step(3.0, mod(xa * 0.37 + 3.0, 9.0));
	float dashB = step(mod(xb, 27.0), 9.0);
	float dashC = step(mod(xc, 33.0), 4.0);
	float hi = 0.0;
	if (d >= 1.0 && abs(d - rowA) < 0.5) {
		hi = dashA;
	} else if (d >= 1.0 && abs(d - rowB) < 0.5) {
		hi = dashB * 0.8;
	} else if (d >= 1.0 && abs(d - rowC) < 0.5) {
		hi = dashC * 0.5;
	}
	c = mix(c, col_hi, hi * hi_amount);
	COLOR = vec4(c, alpha);
}
