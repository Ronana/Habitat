shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ── Splat map ─────────────────────────────────────────────────────────────────
// R = Grass   G = Dirt   B = Mud/Sand   A = Snow (future)
uniform sampler2D splat_map : filter_linear, repeat_disable;

// World-space bounds that the splat map covers (must match SplatMapManager consts)
uniform vec2 world_origin = vec2(-75.0, -75.0);
uniform vec2 world_size   = vec2(150.0, 150.0);

// ── Layer textures ────────────────────────────────────────────────────────────
uniform sampler2D grass_albedo  : source_color,  filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal  : hint_normal,   filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_height  :                filter_linear_mipmap, repeat_enable;
// Second grass variant — blended in by noise to break tiling repetition
uniform sampler2D grass_albedo2 : source_color,  filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal2 : hint_normal,   filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo   : source_color,  filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal   : hint_normal,   filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_height   :                filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_albedo    : source_color,  filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_normal    : hint_normal,   filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_height    :                filter_linear_mipmap, repeat_enable;

// Tiling scale — how many times the texture tiles per world unit
uniform float grass_scale : hint_range(0.01, 2.0) = 0.20;
uniform float dirt_scale  : hint_range(0.01, 2.0) = 0.22;
uniform float mud_scale   : hint_range(0.01, 2.0) = 0.20;

// Edge blending controls
// blend_sharpness: higher = crisper height-based edges (4–16 is a good range)
uniform float blend_sharpness   : hint_range(1.0, 32.0) = 8.0;
// edge_noise_strength: how much noise breaks up the splat boundary in UV space
uniform float edge_noise_strength : hint_range(0.0, 0.05) = 0.012;

// Per-layer colour tints — multiply against the texture albedo to adjust hue/saturation
uniform vec4 grass_tint : source_color = vec4(0.78, 0.88, 0.62, 1.0);
uniform vec4 dirt_tint  : source_color = vec4(1.00, 1.00, 1.00, 1.0);
uniform vec4 mud_tint   : source_color = vec4(1.00, 1.00, 1.00, 1.0);

// Snow (flat colour — no texture needed until winter assets arrive)
uniform vec4 snow_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);

// ── Varying ───────────────────────────────────────────────────────────────────
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
		mix(hash(i),               hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}
// Large-scale fbm — used for macro colour patches across the terrain
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void vertex() {
	world_pos    = (MODEL_MATRIX * vec4(VERTEX,  1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// ── Tiled UVs (needed before splat so height maps can perturb the boundary)
	vec2 grass_uv = world_pos.xz * grass_scale;
	vec2 dirt_uv  = world_pos.xz * dirt_scale;
	vec2 mud_uv   = world_pos.xz * mud_scale;

	// ── Noise-perturb the splat UV to break up straight/square edges ──────────
	// Two offset noise samples give a 2D displacement in splat-UV space.
	float nx = vnoise(world_pos.xz * 1.8)               - 0.5;
	float nz = vnoise(world_pos.xz * 1.8 + vec2(17.3, 8.7)) - 0.5;
	vec2 splat_uv_raw = clamp((world_pos.xz - world_origin) / world_size, 0.0, 1.0);
	vec2 splat_uv     = clamp(splat_uv_raw + vec2(nx, nz) * edge_noise_strength, 0.0, 1.0);
	vec4 splat        = texture(splat_map, splat_uv);

	float w_grass = splat.r;
	float w_dirt  = splat.g;
	float w_mud   = splat.b;
	float w_snow  = splat.a;

	// Normalise so weights always sum to 1
	float total = w_grass + w_dirt + w_mud + w_snow + 0.0001;
	w_grass /= total;
	w_dirt  /= total;
	w_mud   /= total;
	w_snow  /= total;

	// Slope-based dirt override — steep faces look earthy regardless of splat paint
	float slope        = clamp(1.0 - world_normal.y, 0.0, 1.0);
	float slope_factor = smoothstep(0.15, 0.55, slope);
	float slope_steal  = slope_factor * w_grass;
	w_grass -= slope_steal;
	w_dirt   = clamp(w_dirt + slope_steal, 0.0, 1.0);

	// ── Height-map blending ───────────────────────────────────────────────────
	// Each layer's height map biases which texture wins at transition pixels.
	// Grass blades poke up through dirt at the boundary, dirt sits in valleys, etc.
	float h_grass = texture(grass_height, grass_uv).r;
	float h_dirt  = texture(dirt_height,  dirt_uv).r;
	float h_mud   = texture(mud_height,   mud_uv).r;
	float h_snow  = 0.9;   // snow sits on top of everything

	// Combine splat weight with height — taller parts of a layer win the edge
	float hb_grass = h_grass + w_grass;
	float hb_dirt  = h_dirt  + w_dirt;
	float hb_mud   = h_mud   + w_mud;
	float hb_snow  = h_snow  + w_snow;

	float hb_max = max(max(hb_grass, hb_dirt), max(hb_mud, hb_snow));
	// Soft-clip: anything within blend_sharpness of the max contributes
	float inv_sharp = 1.0 / blend_sharpness;
	w_grass = max(0.0, hb_grass - (hb_max - inv_sharp));
	w_dirt  = max(0.0, hb_dirt  - (hb_max - inv_sharp));
	w_mud   = max(0.0, hb_mud   - (hb_max - inv_sharp));
	w_snow  = max(0.0, hb_snow  - (hb_max - inv_sharp));

	// Re-normalise after height blending
	float total2 = w_grass + w_dirt + w_mud + w_snow + 0.0001;
	w_grass /= total2;
	w_dirt  /= total2;
	w_mud   /= total2;
	w_snow  /= total2;

	// ── Grass: blend two variants to break tiling repetition ─────────────────
	vec2 grass_uv2   = world_pos.xz * grass_scale * 1.37 + vec2(5.3, 11.7);
	float blend_noise = vnoise(world_pos.xz * 0.12 + vec2(3.1, 7.4));
	float grass_blend = smoothstep(0.35, 0.65, blend_noise);

	vec3 col_grass = mix(
		texture(grass_albedo,  grass_uv).rgb,
		texture(grass_albedo2, grass_uv2).rgb,
		grass_blend
	) * grass_tint.rgb;

	vec3 n_grass = mix(
		texture(grass_normal,  grass_uv).rgb,
		texture(grass_normal2, grass_uv2).rgb,
		grass_blend
	);

	// ── Macro colour variation (broad fbm patches, camera-independent) ────────
	float macro  = fbm(world_pos.xz * 0.06);                    // very large scale
	float medium = vnoise(world_pos.xz * 0.28 + vec2(4.2, 9.1)); // mid scale clumps
	// Darken some areas, lighten others — keeps it within a natural range
	float macro_var = (macro - 0.5) * 0.18 + (medium - 0.5) * 0.09;
	col_grass = clamp(col_grass + vec3(macro_var * 0.55, macro_var, macro_var * 0.45), 0.0, 1.0);

	// ── Other layer albedos ───────────────────────────────────────────────────
	vec3 col_dirt  = texture(dirt_albedo, dirt_uv).rgb * dirt_tint.rgb;
	vec3 col_mud   = texture(mud_albedo,  mud_uv).rgb  * mud_tint.rgb;
	vec3 col_snow  = snow_color.rgb;

	vec3 albedo = col_grass * w_grass
	            + col_dirt  * w_dirt
	            + col_mud   * w_mud
	            + col_snow  * w_snow;
	albedo = clamp(albedo, 0.0, 1.0);

	// ── Normal map blend ──────────────────────────────────────────────────────
	vec3 n_dirt  = texture(dirt_normal, dirt_uv).rgb;
	vec3 n_mud   = texture(mud_normal,  mud_uv).rgb;
	vec3 n_flat  = vec3(0.5, 0.5, 1.0);

	vec3 normal_map = n_grass * w_grass
	                + n_dirt  * w_dirt
	                + n_mud   * w_mud
	                + n_flat  * w_snow;

	// ── PBR outputs ───────────────────────────────────────────────────────────
	ALBEDO     = albedo;
	NORMAL_MAP = normal_map;
	ROUGHNESS  = 0.88 + w_dirt * 0.06 + w_mud * 0.04 - w_snow * 0.12;
	METALLIC   = 0.0;
	SPECULAR   = 0.04 + w_snow * 0.18;
	float fine = vnoise(world_pos.xz * 2.2 + vec2(8.1, 5.3));
	AO         = clamp(0.80 + fine * 0.20, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.55;
}
