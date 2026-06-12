## tree.gd — realistic + magical tree.
## Procedural bark (trunk/root), leaf-cluster canopy, wind sway, seasonal emissive, night glow, sparkle particles.
extends Node3D

# ── Season data ───────────────────────────────────────────────────────────────
const SEASON_DATA: Array = [
	{  # Spring — fresh green, soft pink blossom emission
		"colour":        Color(0.24, 0.52, 0.14),
		"colour_bright": Color(0.36, 0.68, 0.24),
		"emissive":      Color(0.95, 0.55, 0.65),
		"emissive_e":    0.13,
		"scale_y":       1.00,
		"particle_col":  Color(0.96, 0.72, 0.82, 0.75),
	},
	{  # Summer — rich dark green, faint shimmer
		"colour":        Color(0.10, 0.38, 0.06),
		"colour_bright": Color(0.18, 0.54, 0.12),
		"emissive":      Color(0.20, 0.82, 0.30),
		"emissive_e":    0.04,
		"scale_y":       1.00,
		"particle_col":  Color(0.50, 0.96, 0.42, 0.55),
	},
	{  # Autumn — amber orange, warm ember glow
		"colour":        Color(0.66, 0.36, 0.07),
		"colour_bright": Color(0.82, 0.50, 0.12),
		"emissive":      Color(0.92, 0.50, 0.10),
		"emissive_e":    0.18,
		"scale_y":       0.88,
		"particle_col":  Color(0.94, 0.56, 0.14, 0.82),
	},
	{  # Winter — sparse grey-brown, no emission
		"colour":        Color(0.30, 0.26, 0.22),
		"colour_bright": Color(0.40, 0.34, 0.28),
		"emissive":      Color(0.0, 0.0, 0.0),
		"emissive_e":    0.0,
		"scale_y":       0.55,
		"particle_col":  Color(0.72, 0.88, 1.0, 0.28),
	},
]

# ── Wind ──────────────────────────────────────────────────────────────────────
const SWAY_SPEED    := 0.62
const SWAY_AMOUNT_Z := 0.030
const SWAY_AMOUNT_X := 0.016
const NIGHT_GLOW    := 0.90
const GLOW_HOUR_ON  := 20.0
const GLOW_HOUR_OFF := 6.5

# ── State ──────────────────────────────────────────────────────────────────────
var _time           : float = 0.0
var _sway_phase     : float = 0.0
var _is_night       : bool  = false
var _current_season : int   = 0
var _canopy_mats    : Array[ShaderMaterial] = []
var _magic_light    : OmniLight3D = null
var _magic_particles: GPUParticles3D = null

# Shared canopy shader (one Shader resource, many ShaderMaterial instances)
var _canopy_shader  : Shader = null

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_sway_phase = randf() * TAU

	_magic_light = $CanopyRoot/MagicLight as OmniLight3D
	if _magic_light:
		_magic_light.light_energy = 0.0

	_build_trunk_materials()
	_build_canopy_materials()

	_magic_particles = _build_magic_particles()
	$CanopyRoot.add_child(_magic_particles)

	SeasonManager.season_changed.connect(_on_season_changed)
	_apply_season(SeasonManager.current_season)

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	var s1 := sin(_time * SWAY_SPEED        + _sway_phase)
	var s2 := sin(_time * SWAY_SPEED * 1.34 + _sway_phase + 1.2)
	$CanopyRoot.rotation.z = s1 * SWAY_AMOUNT_Z
	$CanopyRoot.rotation.x = s2 * SWAY_AMOUNT_X

	var hour := DayNightManager.current_time
	var want_night := hour >= GLOW_HOUR_ON or hour <= GLOW_HOUR_OFF
	if want_night != _is_night:
		_is_night = want_night
		_on_night_changed()

# ── Trunk / root bark material ─────────────────────────────────────────────────
func _build_trunk_materials() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

uniform vec4 bark_dark  : source_color = vec4(0.10, 0.06, 0.03, 1.0);
uniform vec4 bark_light : source_color = vec4(0.30, 0.19, 0.09, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

void fragment() {
	vec2 uv = UV;

	// Vertical ridges — shift with noise so they're not perfectly straight
	float noise_warp = vnoise(uv * vec2(2.0, 5.0)) * 1.4;
	float ridges = sin((uv.x + noise_warp * 0.06) * 18.0) * 0.5 + 0.5;
	ridges = pow(ridges, 1.6);

	// Coarse, fine, and vertical streak noise layers
	float n_coarse = vnoise(uv * vec2(2.5, 1.2));
	float n_fine   = vnoise(uv * vec2(9.0, 5.0));
	float n_vert   = vnoise(vec2(uv.x * 1.8, uv.y * 14.0 + 2.3));

	float bark = ridges * 0.32 + n_coarse * 0.28 + n_fine * 0.22 + n_vert * 0.18;

	// Knot — one dark circular feature per trunk
	float knot = 1.0 - smoothstep(0.06, 0.16, length(uv - vec2(0.55, 0.38)));
	bark = mix(bark, 0.04, knot * 0.55);

	vec3 col = mix(bark_dark.rgb, bark_light.rgb, bark);

	// Base of trunk slightly darker (ground contact shadow)
	col *= mix(0.60, 1.0, smoothstep(0.0, 0.28, uv.y));

	ALBEDO    = col;
	ROUGHNESS = 0.96;
	METALLIC  = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	$Trunk.set_surface_override_material(0, mat)

	# Apply the same shader to the root flare (slightly darker knot position)
	var root_mat := ShaderMaterial.new()
	root_mat.shader = shader
	$RootFlare.set_surface_override_material(0, root_mat)

# ── Canopy leaf material ───────────────────────────────────────────────────────
func _build_canopy_materials() -> void:
	_canopy_shader = Shader.new()
	_canopy_shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo_base   : source_color = vec4(0.14, 0.36, 0.09, 1.0);
uniform vec4 albedo_bright : source_color = vec4(0.22, 0.52, 0.14, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform vec2 noise_offset = vec2(0.0, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

varying float v_leaf;

void vertex() {
	// Model-space position gives stable leaf texture that rotates with branch sway
	vec2 pos = VERTEX.xz + noise_offset;
	v_leaf =  vnoise(pos * 2.6)  * 0.50
			+ vnoise(pos * 6.0)  * 0.30
			+ vnoise(pos * 13.5) * 0.20;
}

void fragment() {
	vec3 col = mix(albedo_base.rgb, albedo_bright.rgb, v_leaf);

	// Fresnel: leaves catch light at glancing angles (backlit edge glow)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	col = mix(col, albedo_bright.rgb * 1.30, fresnel * 0.20);

	ALBEDO    = col;
	ROUGHNESS = 0.78;
	METALLIC  = 0.0;
	EMISSION  = emission_color.rgb * emission_energy;
}
"""
	for child_name: String in ["Canopy", "CanopyUpper", "CanopySide"]:
		var node: MeshInstance3D = $CanopyRoot.get_node_or_null(child_name) as MeshInstance3D
		if node == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = _canopy_shader
		# Random noise offset per layer so they each show a different leaf pattern
		mat.set_shader_parameter("noise_offset",
			Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)))
		node.set_surface_override_material(0, mat)
		_canopy_mats.append(mat)

# ── Season ─────────────────────────────────────────────────────────────────────
func _on_season_changed(season: int) -> void:
	_apply_season(season)

func _apply_season(season: int) -> void:
	_current_season = season
	var d: Dictionary = SEASON_DATA[clamp(season, 0, SEASON_DATA.size() - 1)]

	var col:    Color = d["colour"]
	var col_b:  Color = d["colour_bright"]
	var emiss:  Color = d["emissive"]
	var emiss_e: float = d["emissive_e"] + (0.12 if _is_night else 0.0)
	var scale_y: float = d["scale_y"]
	var pcol:   Color = d["particle_col"]

	# Smooth canopy scale
	var tw := create_tween()
	tw.tween_property($CanopyRoot, "scale", Vector3(1.0, scale_y, 1.0), 2.0)

	# Update canopy shader params
	for mat: ShaderMaterial in _canopy_mats:
		mat.set_shader_parameter("albedo_base",   col)
		mat.set_shader_parameter("albedo_bright", col_b)
		mat.set_shader_parameter("emission_color", emiss)
		mat.set_shader_parameter("emission_energy", emiss_e)

	# Update particle colour
	if _magic_particles and _magic_particles.process_material:
		var pm: ParticleProcessMaterial = _magic_particles.process_material as ParticleProcessMaterial
		if pm:
			var grad := Gradient.new()
			grad.add_point(0.0, Color(pcol.r, pcol.g, pcol.b, 0.0))
			grad.add_point(0.3, pcol)
			grad.add_point(1.0, Color(pcol.r, pcol.g, pcol.b, 0.0))
			var grad_tex := GradientTexture1D.new()
			grad_tex.gradient = grad
			pm.color_ramp = grad_tex

	if _magic_particles:
		_magic_particles.emitting = season != 3

# ── Night glow ─────────────────────────────────────────────────────────────────
func _on_night_changed() -> void:
	var target_energy := NIGHT_GLOW if _is_night else 0.0
	if _magic_light:
		var tw := create_tween()
		tw.tween_property(_magic_light, "light_energy", target_energy, 3.0)

	var d: Dictionary = SEASON_DATA[clamp(_current_season, 0, SEASON_DATA.size() - 1)]
	var night_e: float = d["emissive_e"] + (0.12 if _is_night else 0.0)
	for mat: ShaderMaterial in _canopy_mats:
		var current_e: float = mat.get_shader_parameter("emission_energy")
		var mat_tw := create_tween()
		mat_tw.tween_method(
			func(v: float): mat.set_shader_parameter("emission_energy", v),
			current_e, night_e, 3.0)

# ── Magic particles ─────────────────────────────────────────────────────────────
func _build_magic_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting        = true
	p.one_shot        = false
	p.amount          = 20
	p.lifetime        = 5.5
	p.visibility_aabb = AABB(Vector3(-3.0, -2.5, -3.0), Vector3(6.0, 7.0, 6.0))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape         = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.8
	mat.direction              = Vector3(0.0, 1.0, 0.0)
	mat.spread                 = 55.0
	mat.initial_velocity_min   = 0.08
	mat.initial_velocity_max   = 0.38
	mat.gravity                = Vector3(0.0, 0.04, 0.0)
	mat.scale_min              = 0.025
	mat.scale_max              = 0.065
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.60, 1.0, 0.50, 0.0))
	grad.add_point(0.3, Color(0.60, 1.0, 0.50, 0.72))
	grad.add_point(1.0, Color(0.60, 1.0, 0.50, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.048
	mesh.height = 0.096
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color               = Color(0.60, 1.0, 0.50, 0.80)
	draw_mat.emission_enabled           = true
	draw_mat.emission                   = Color(0.50, 0.90, 0.40)
	draw_mat.emission_energy_multiplier = 1.1
	draw_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	p.draw_pass_1 = mesh

	return p
