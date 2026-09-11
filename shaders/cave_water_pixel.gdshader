shader_type canvas_item;
// v3 cave water: flat banded pixel water (2026-09-11). UV.x runs across the pool,
// UV.y is depth below the surface (0 = surface, 1 = deepest point). No noise,
// no specular: three flat tones stepped in bands whose edges wobble on the art
// grid, plus a row of slow sparkle dashes near the surface.
uniform float time = 0.0;
uniform vec4 top_col : source_color = vec4(0.32, 0.58, 0.72, 0.82);
uniform vec4 mid_col : source_color = vec4(0.18, 0.38, 0.56, 0.86);
uniform vec4 deep_col : source_color = vec4(0.08, 0.18, 0.34, 0.92);
uniform vec4 spark_col : source_color = vec4(0.75, 0.92, 1.0, 0.9);
uniform float hdr_boost = 1.0;
uniform float span_px = 300.0;   // pool width in world units, so the wobble is in pixels

void fragment() {
	float xpx = floor(UV.x * span_px);            // art-grid x
	float w = sin(xpx * 0.11 + time * 1.3) * 0.5 + sin(xpx * 0.043 - time * 0.7) * 0.5;
	float d = UV.y + w * 0.05;
	vec4 c = deep_col;
	if (d < 0.22) {
		c = top_col;
	} else if (d < 0.58) {
		c = mid_col;
	}
	// sparkle dashes: 3-px runs drifting right, only in the top band
	float lane = floor(UV.y * 40.0);
	float drift = fract((xpx + time * 6.0 * (1.0 + mod(lane, 3.0))) / 41.0);
	if (UV.y < 0.12 && drift < 0.07 && mod(lane, 2.0) == 0.0) {
		c = vec4(spark_col.rgb * hdr_boost, spark_col.a);
	} else {
		c = vec4(c.rgb * (1.0 + (hdr_boost - 1.0) * 0.25), c.a);
	}
	COLOR = c;
}
