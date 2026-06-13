shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4  rune_color     : source_color = vec4(1.0, 0.45, 0.05, 1.0);
uniform float glow_intensity : hint_range(0.5, 6.0) = 2.8;
uniform float rune_density   : hint_range(2.0, 24.0) = 9.0;  // runes per UV unit
uniform float pulse_speed    : hint_range(0.0, 4.0)  = 0.6;  // slow breath pulse

// ── Deterministic hash ────────────────────────────────────────────────────────
float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float h2(vec2  p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// ── Soft anti-aliased line segment ────────────────────────────────────────────
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float t  = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	float d  = length(pa - ba * t);
	return smoothstep(w, w * 0.3, d);
}

// ── Draw one rune glyph in [0,1]² UV space ───────────────────────────────────
// Uses a seed integer to deterministically vary the internal strokes.
float draw_rune(vec2 uv, float seed) {
	float w  = 0.07;   // stroke half-width
	float ws = 0.055;  // secondary strokes
	float val = 0.0;

	// Outer rectangular frame — always present
	val += seg(uv, vec2(0.10, 0.12), vec2(0.90, 0.12), w);   // bottom
	val += seg(uv, vec2(0.10, 0.88), vec2(0.90, 0.88), w);   // top
	val += seg(uv, vec2(0.10, 0.12), vec2(0.10, 0.88), w);   // left
	val += seg(uv, vec2(0.90, 0.12), vec2(0.90, 0.88), w);   // right

	// Internal strokes — chosen by hash of seed
	float r1 = h1(seed);
	float r2 = h1(seed + 1.0);
	float r3 = h1(seed + 2.0);
	float r4 = h1(seed + 3.0);
	float r5 = h1(seed + 4.0);
	float r6 = h1(seed + 5.0);
	float r7 = h1(seed + 6.0);

	if (r1 > 0.20) val += seg(uv, vec2(0.10, 0.50), vec2(0.90, 0.50), ws);         // h-mid
	if (r2 > 0.30) val += seg(uv, vec2(0.50, 0.12), vec2(0.50, 0.88), ws);         // v-mid
	if (r3 > 0.40) val += seg(uv, vec2(0.10, 0.68), vec2(0.50, 0.68), ws);         // h-upper-left
	if (r4 > 0.40) val += seg(uv, vec2(0.50, 0.32), vec2(0.90, 0.32), ws);         // h-lower-right
	if (r5 > 0.55) val += seg(uv, vec2(0.10, 0.12), vec2(0.50, 0.50), ws * 0.9);   // diag ↗ left
	if (r6 > 0.60) val += seg(uv, vec2(0.90, 0.88), vec2(0.50, 0.50), ws * 0.9);   // diag ↙ right
	if (r7 > 0.65) val += seg(uv, vec2(0.30, 0.12), vec2(0.30, 0.50), ws);         // v-left-lower

	// Corner ticks — vary independently
	if (h1(seed + 7.0) > 0.50) val += seg(uv, vec2(0.10, 0.88), vec2(0.00, 0.98), ws * 0.8);
	if (h1(seed + 8.0) > 0.55) val += seg(uv, vec2(0.90, 0.88), vec2(1.00, 0.98), ws * 0.8);
	if (h1(seed + 9.0) > 0.50) val += seg(uv, vec2(0.50, 0.88), vec2(0.50, 1.00), ws * 0.8);

	return clamp(val, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;   // U runs along strip length, V across width

	// Slow pulse — gives the runes a breathing glow
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);

	// ── Tile rune cells along the strip ──────────────────────────────────────
	float cell_x  = uv.x * rune_density;
	float cell_id = floor(cell_x);
	vec2  cell_uv = vec2(fract(cell_x), uv.y);

	// Small gap between symbols
	float gap  = 0.09;
	vec2  inner = (cell_uv - gap) / (1.0 - 2.0 * gap);

	float rune_mask = 0.0;
	if (inner.x > 0.0 && inner.x < 1.0 &&
		inner.y > 0.0 && inner.y < 1.0) {
		// Use a large prime-spaced seed so adjacent runes differ clearly
		float seed = h2(vec2(cell_id * 7.0, 13.0)) * 64.0;
		rune_mask  = draw_rune(inner, floor(seed));
	}

	// ── Edge glow — thin bright line at top and bottom of strip ──────────────
	float edge_w    = 0.06;
	float edge_top  = smoothstep(edge_w, 0.0, uv.y - (1.0 - edge_w));
	float edge_bot  = smoothstep(edge_w, 0.0, edge_w - uv.y);
	float edge_glow = max(edge_top, edge_bot) * 0.5;

	// ── Combine and apply glow colour ─────────────────────────────────────────
	float total = clamp(rune_mask + edge_glow, 0.0, 1.0) * pulse;
	vec3  col   = rune_color.rgb * total * glow_intensity;

	ALBEDO   = col;
	EMISSION = col;
	ALPHA    = total;
}
