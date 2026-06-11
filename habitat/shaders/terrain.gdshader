shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Pass world-space values from vertex → fragment so they don't shift with the camera
varying vec3 world_pos;
varying vec3 world_normal;

// ── Noise helpers ─────────────────────────────────────────────────────────────
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
		mix(hash(i),              hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.48;
	}
	return v;
}

// ── Vertex ────────────────────────────────────────────────────────────────────
void vertex() {
	// Capture world-space values before the view transform is applied
	world_pos    = (MODEL_MATRIX * vec4(VERTEX,  1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// ── Fragment ──────────────────────────────────────────────────────────────────
void fragment() {
	// World-space UV — stays fixed as the camera moves
	vec2 uv = world_pos.xz;

	// Noise at three scales
	float large  = fbm(uv * 0.07);               // broad colour patches
	float medium = fbm(uv * 0.35 + vec2(3.7, 1.2)); // grass clumping
	float fine   = vnoise(uv * 2.2 + vec2(8.1, 5.3)); // micro detail

	// Slope from world-space normal (0 = flat, 1 = vertical) — camera-independent
	float slope       = clamp(1.0 - world_normal.y, 0.0, 1.0);
	float slope_dirt  = smoothstep(0.10, 0.45, slope); // flat → dirt
	float slope_rock  = smoothstep(0.38, 0.72, slope); // dirt → rock

	// Base grass tint from vertex colour (height-based, set in GDScript)
	vec3 grass = COLOR.rgb;
	// Broad hue variation — some patches slightly warmer or cooler
	grass = mix(grass, grass * vec3(1.18, 1.06, 0.78), (large - 0.5) * 0.28);
	// Medium clump darkening
	grass *= 1.0 - medium * 0.12;

	// Earth colours
	vec3 dirt = vec3(0.44, 0.30, 0.15);
	dirt = mix(dirt, dirt * vec3(1.05, 0.92, 0.82), fine * 0.22);

	vec3 rock = vec3(0.40, 0.37, 0.31);
	rock = mix(rock, rock * vec3(0.92, 0.95, 1.0), medium * 0.15);

	// Blend surface by slope
	vec3 surface = mix(grass, dirt, slope_dirt);
	surface      = mix(surface, rock, slope_rock);

	// Micro detail on flat grass only
	surface += (fine - 0.5) * 0.05 * (1.0 - slope_dirt);
	surface  = clamp(surface, 0.0, 1.0);

	ALBEDO = surface;

	// Roughness: rough grass, slightly smoother rock
	float roughness = mix(0.92, 0.78, slope_rock);
	roughness += (fine - 0.5) * 0.06;
	ROUGHNESS = clamp(roughness, 0.70, 0.97);

	SPECULAR = 0.02;

	// Subtle ambient occlusion from noise (proxy for small crevices)
	AO             = clamp(0.82 + medium * 0.18, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.55;
}
