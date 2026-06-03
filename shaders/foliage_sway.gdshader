shader_type canvas_item;

// Pivot-anchored wind sway for procedural foliage.
// Base stays put (UV.y = 1 at the planted base), tip moves the most (UV.y = 0).
// A world-X "gust" term makes one wave roll across the entire field so neighbours
// at different world-X already differ in phase (no per-instance material needed).
uniform float sway_strength = 3.0;     // peak horizontal tip travel (px)
uniform float sway_speed = 1.2;        // base oscillation speed
uniform float gust_wavelength = 220.0; // world-X length of one rolling gust
uniform float gust_speed = 60.0;       // how fast the gust rolls across (px/s)
uniform float stiffness = 1.6;         // >1 = stiffer base, whippier tip

void vertex() {
	float anchor = pow(clamp(1.0 - UV.y, 0.0, 1.0), stiffness);
	float wx = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
	float gust = sin((wx - TIME * gust_speed) / gust_wavelength * 6.2831);
	float wind = (sin(TIME * sway_speed + wx * 0.05) * 0.6 + gust * 0.8) * sway_strength * anchor;
	VERTEX.x += wind;
	VERTEX.y += abs(wind) * 0.15 * anchor; // slight vertical bob as it leans
}
