shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// ── Water mask ────────────────────────────────────────────────────────────────
// R8 image from SplatMapManager — 1.0 = water, 0.0 = dry land.
uniform sampler2D water_mask : filter_linear, repeat_disable;

// Must match SplatMapManager constants
uniform vec2 world_origin = vec2(-75.0, -75.0);
uniform vec2 world_size   = vec2(150.0, 150.0);

// ── Appearance ────────────────────────────────────────────────────────────────
uniform vec4 color_shallow : source_color = vec4(0.22, 0.62, 0.72, 0.78);
uniform vec4 color_deep    : source_color = vec4(0.06, 0.32, 0.52, 0.92);
uniform float wave_speed   : hint_range(0.0, 3.0) = 0.45;
uniform float wave_scale   : hint_range(0.1, 8.0) = 2.8;

// ── Varying ───────────────────────────────────────────────────────────────────
varying vec3 world_pos;

// ── Noise helpers (no async textures — purely procedural) ────────────────────
float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.39);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i),               hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), f.x),
		f.y
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// ── Water mask — only render where cells are marked as water ─────────────
	vec2 mask_uv = clamp((world_pos.xz - world_origin) / world_size, 0.0, 1.0);
	float mask = texture(water_mask, mask_uv).r;

	// ── Animated ripples (two offset noise layers cancel repetition) ──────────
	vec2 t1 = world_pos.xz * wave_scale + vec2(TIME * wave_speed * 0.70,  TIME * wave_speed * 0.45);
	vec2 t2 = world_pos.xz * wave_scale * 0.65 + vec2(-TIME * wave_speed * 0.55, TIME * wave_speed * 0.60);
	float w1 = vnoise(t1);
	float w2 = vnoise(t2);
	float waves = w1 * 0.55 + w2 * 0.45;

	// ── Colour blend shallow → deep ───────────────────────────────────────────
	vec3 col  = mix(color_shallow.rgb, color_deep.rgb, waves);
	float alpha = mix(color_shallow.a, color_deep.a, waves) * smoothstep(0.0, 0.25, mask);

	// ── Fake ripple normal for specular highlights ────────────────────────────
	float eps = 0.02;
	float dx = vnoise(t1 + vec2(eps, 0.0)) - vnoise(t1 - vec2(eps, 0.0));
	float dz = vnoise(t1 + vec2(0.0, eps)) - vnoise(t1 - vec2(0.0, eps));
	// Pack into normal map format (0.5 = neutral)
	NORMAL_MAP = vec3(dx * 0.25 + 0.5, dz * 0.25 + 0.5, 1.0);

	ALBEDO    = col;
	ALPHA     = alpha;
	ROUGHNESS = 0.06;
	METALLIC  = 0.0;
	SPECULAR  = 0.92;
}
