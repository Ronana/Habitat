extends Node3D

@export var tree_scene: PackedScene
@export var tree_count: int = 500
@export var forest_radius: float = 200.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.6
@export var starter_area_size: float = 40.0
var base_ground_level: float = 0.0

var berry_bush_scene: PackedScene = preload("res://scenes/berry_bush.tscn")

# Common tree assets — loaded at runtime to avoid preload path issues with spaces
var _tree_scenes: Array[PackedScene] = []

# ── Natural grass (MultiMesh) ─────────────────────────────────────────────────
var _grass_mmi : MultiMeshInstance3D = null
var _grass_mat : ShaderMaterial       = null

const GRASS_COUNT    := 10000
const GRASS_RADIUS   := 160.0
const GRASS_AVOID_C  := 3.0   # small clear patch at world origin

const SEASON_GRASS := {
	0: { "base": Color(0.24, 0.54, 0.16), "bright": Color(0.34, 0.66, 0.24) },
	1: { "base": Color(0.13, 0.44, 0.10), "bright": Color(0.20, 0.56, 0.16) },
	2: { "base": Color(0.50, 0.42, 0.14), "bright": Color(0.62, 0.50, 0.20) },
	3: { "base": Color(0.24, 0.30, 0.18), "bright": Color(0.30, 0.36, 0.22) },
}

# ── BinbunGrass palettes ──────────────────────────────────────────────────────
# Three stops per season: light → mid → dark green, matching palette_01.tres hues
const SEASON_BINBUN_PALETTE := {
	0: [Color(0.659, 0.792, 0.345), Color(0.459, 0.655, 0.263), Color(0.275, 0.510, 0.196)],
	1: [Color(0.580, 0.750, 0.290), Color(0.400, 0.615, 0.210), Color(0.200, 0.465, 0.140)],
	2: [Color(0.720, 0.580, 0.180), Color(0.560, 0.450, 0.130), Color(0.380, 0.320, 0.090)],
	3: [Color(0.480, 0.540, 0.360), Color(0.360, 0.420, 0.270), Color(0.240, 0.320, 0.190)],
}
var _ground_palette : GradientTexture1D = null
var _grass_palette  : GradientTexture1D = null

# ---------------------------------------------------------------------------
# Wild roamer attraction
# ---------------------------------------------------------------------------
var attraction_check_timer: float = 0.0
const ATTRACTION_CHECK_INTERVAL: float = 25.0
const ATTRACTION_COOLDOWN: float = 60.0
var attraction_cooldowns: Dictionary = {}  # species_id -> remaining seconds

# Requirements each species needs before a wild one will visit.
# Keys: scene, min_food, min_shelters, min_avg_happiness, max_in_garden, label
var species_requirements: Dictionary = {
	"GlowFox": {
		"scene": "res://creatures/glowfox.tscn",
		"min_food": 1,
		"min_shelters": 0,
		"min_avg_happiness": 0.4,
		"max_in_garden": 4,
		"label": "🦊 GlowFox"
	},
	"Mossdeer": {
		"scene": "res://creatures/mossdeer.tscn",
		"min_food": 2,
		"min_shelters": 1,
		"min_avg_happiness": 0.5,
		"max_in_garden": 3,
		"label": "🦌 Mossdeer"
	},
	"Stoneback": {
		"scene": "res://creatures/stoneback.tscn",
		"min_food": 1,
		"min_shelters": 2,
		"min_avg_happiness": 0.55,
		"max_in_garden": 2,
		"label": "🐢 Stoneback"
	},
}

func _ready():
	for i in range(1, 6):
		var path := "res://Stylized Nature MegaKit[Standard]/glTF/CommonTree_%d.gltf" % i
		var scene := load(path) as PackedScene
		if scene:
			_tree_scenes.append(scene)

	# Build terrain + collision first so all scatter functions can snap to ground
	create_starter_bumps()
	_apply_ground_shader()

	scatter_trees()
	scatter_natural_grass()
	create_boundary()
	_scatter_outer_forest()
	scatter_debris()
	_scatter_outer_decorations()
	plant_starting_bushes()
	give_starting_inventory()
	# Connect day night manager to scene lights
	var sun = get_node("DirectionalLight3D")
	var env = get_node("WorldEnvironment").environment
	DayNightManager.sun = sun
	DayNightManager.environment = env
	WeatherManager.environment = env
	WeatherManager.sun = sun
	WeatherManager.rain_particles = get_node("RainParticles")
	SeasonManager.environment = env
	SeasonManager.sun = sun
	_setup_sky(env)
	
	# ── Tool wheel (radial menu — open with Q) ───────────────────────────────
	var tool_wheel_script := load("res://scripts/tool_wheel.gd") as GDScript
	if tool_wheel_script:
		var wheel := CanvasLayer.new()
		wheel.name = "ToolWheel"
		wheel.set_script(tool_wheel_script)
		add_child(wheel)

		# ── Tool carrier (3D floating shovel beside cursor) ───────────────────
		var carrier_script := load("res://scripts/tool_carrier.gd") as GDScript
		if carrier_script:
			var carrier := Node3D.new()
			carrier.name = "ToolCarrier"
			carrier.set_script(carrier_script)
			add_child(carrier)

			# When a tool is selected: update tool_manager + carrier
			wheel.tool_selected.connect(func(tool_id: String) -> void:
				var tm := get_node_or_null("ToolManager")
				if tm:
					tm.set_active_tool(tool_id)
				carrier.set_tool(tool_id)
			)

	# ── Pause menu ───────────────────────────────────────────────────────────
	var pause_scene := load("res://scenes/pause_menu.tscn") as PackedScene
	if pause_scene:
		var pause_menu := pause_scene.instantiate()
		add_child(pause_menu)

	# Try to load save
	var loaded = await SaveManager.load_game(self)
	if not loaded:
		print("Fresh wilderness — no save found")

	# Show tutorial on first launch (after a short delay so the scene settles)
	await get_tree().create_timer(1.2).timeout
	TutorialManager.try_start()

func _input(event):
	if event is InputEventKey and event.pressed:
		# Press F5 to save manually
		if event.keycode == KEY_F5:
			SaveManager.save_game(self)
		# Press F9 to load
		if event.keycode == KEY_F9:
			SaveManager.load_game(self)
		# Press 1-4 to force weather for testing
		if event.keycode == KEY_1:
			WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
		if event.keycode == KEY_2:
			WeatherManager.set_weather(WeatherManager.Weather.RAIN)
		if event.keycode == KEY_3:
			WeatherManager.set_weather(WeatherManager.Weather.FOG)
		if event.keycode == KEY_4:
			WeatherManager.set_weather(WeatherManager.Weather.WIND)
			# Press F1-F4 to force seasons for testing
		if event.keycode == KEY_F1:
			SeasonManager.current_season = SeasonManager.Season.SPRING
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F2:
			SeasonManager.current_season = SeasonManager.Season.SUMMER
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F3:
			SeasonManager.current_season = SeasonManager.Season.AUTUMN
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F4:
			SeasonManager.current_season = SeasonManager.Season.WINTER
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)

func scatter_trees() -> void:
	if _tree_scenes.is_empty():
		return
	for _i in range(tree_count):
		var scene: PackedScene = _tree_scenes[randi() % _tree_scenes.size()]
		var tree := scene.instantiate()
		tree.add_to_group("trees")
		_apply_visibility_range(tree, 160.0)
		add_child(tree)
		var x := randf_range(-forest_radius, forest_radius)
		var z := randf_range(-forest_radius, forest_radius)
		tree.position = Vector3(x, _terrain_y(x, z), z)
		var s := randf_range(min_scale, max_scale)
		tree.scale = Vector3(s, s, s)
		tree.rotation.y = randf_range(0.0, TAU)

func scatter_natural_grass() -> void:
	# ── Quad mesh — BinbunGrass shader handles billboard facing ─────────────────
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.65)

	var mat := _build_binbun_grass_mat()
	if mat == null:
		# Fallback: legacy sphere-tuft shader
		mat = _build_grass_shader_legacy(SeasonManager.current_season)
	quad.material = mat

	# ── MultiMesh ────────────────────────────────────────────────────────────────
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count   = GRASS_COUNT
	mm.mesh             = quad

	var i := 0
	while i < GRASS_COUNT:
		var angle := randf() * TAU
		var dist  := sqrt(randf()) * GRASS_RADIUS
		var x     := cos(angle) * dist
		var z     := sin(angle) * dist
		if Vector2(x, z).length() < GRASS_AVOID_C:
			continue

		# Approximate terrain height with the same fbm used in create_starter_bumps
		# (avoids slow per-blade raycasts while staying close to actual surface)
		var h_approx: float = _tfbm(x * 0.045, z * 0.045) * 1.7 \
				+ _tvn(x * 0.14, z * 0.14) * 0.50 \
				+ _tvn(x * 0.38, z * 0.38) * 0.13
		var cd: float   = clamp(Vector2(x, z).length() / 9.0, 0.0, 1.0)
		cd = cd * cd * (3.0 - 2.0 * cd)
		h_approx *= cd
		var edge: float  = maxf(absf(x), absf(z))
		var efade: float = clamp(1.0 - (edge - 170.0) / 28.0, 0.0, 1.0)
		h_approx = maxf(h_approx * efade, 0.0)

		var bh: float = randf_range(0.38, 0.78)   # blade height multiplier
		var bw: float = randf_range(0.55, 1.25)   # blade width multiplier
		var ry: float = randf() * TAU
		var basis := Basis().scaled(Vector3(bw, bh, 1.0)).rotated(Vector3.UP, ry)
		# Centre the quad so its base sits on the terrain (base = centre - bh*0.325)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, h_approx + bh * 0.325, z)))
		i += 1

	# ── Attach to scene ──────────────────────────────────────────────────────────
	_grass_mmi = MultiMeshInstance3D.new()
	_grass_mmi.name        = "NaturalGrass"
	_grass_mmi.multimesh   = mm
	_grass_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grass_mmi)

	SeasonManager.season_changed.connect(_on_grass_season_changed)

## Build a ShaderMaterial using BinbunGrass/src/shader/grass.gdshader.
## Returns null if the shader file is not found.
func _build_binbun_grass_mat() -> ShaderMaterial:
	var grass_shader := load("res://BinbunGrass/src/shader/grass.gdshader") as Shader
	if grass_shader == null:
		push_warning("BinbunGrass grass shader not found — using legacy grass")
		return null

	# ── Shape textures ────────────────────────────────────────────────────────
	var shape_tex := load("res://BinbunGrass/src/texture/basic/grass_basic_02.png") as Texture2D
	var atlas_tex := load("res://BinbunGrass/src/texture/basic/grass_basic_atlas.png") as Texture2D

	# ── Colour noise (world-space variation) ──────────────────────────────────
	var fn_col := FastNoiseLite.new()
	fn_col.noise_type      = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn_col.frequency       = 0.008
	fn_col.fractal_type    = FastNoiseLite.FRACTAL_FBM
	fn_col.fractal_octaves = 4
	fn_col.seed            = 42
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise    = fn_col
	noise_tex.width    = 256
	noise_tex.height   = 256
	noise_tex.seamless = true

	# ── Wind noise ────────────────────────────────────────────────────────────
	var fn_wind := FastNoiseLite.new()
	fn_wind.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn_wind.frequency  = 0.03
	fn_wind.seed       = 7
	var wind_tex := NoiseTexture2D.new()
	wind_tex.noise    = fn_wind
	wind_tex.width    = 256
	wind_tex.height   = 256
	wind_tex.seamless = true

	_grass_palette = _build_binbun_palette(SeasonManager.current_season)

	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = grass_shader
	_grass_mat.set_shader_parameter("shape_texture",   shape_tex)
	_grass_mat.set_shader_parameter("shape_atlas",     atlas_tex)
	_grass_mat.set_shader_parameter("use_atlas",       true)
	_grass_mat.set_shader_parameter("billboard",       true)
	_grass_mat.set_shader_parameter("noise_texture",   noise_tex)
	_grass_mat.set_shader_parameter("color_gradient",  _grass_palette)
	_grass_mat.set_shader_parameter("wind_texture",    wind_tex)
	_grass_mat.set_shader_parameter("wind_velocity",   Vector2(1.8, 0.9))
	_grass_mat.set_shader_parameter("alpha_mode",      1)       # Dithered
	_grass_mat.set_shader_parameter("alpha_cut_start", 0.10)
	_grass_mat.set_shader_parameter("alpha_cut_end",   0.85)
	_grass_mat.set_shader_parameter("random_variation",0.08)
	return _grass_mat

## Legacy sphere-tuft grass shader — used as fallback if BinbunGrass is absent.
func _build_grass_shader_legacy(season: int) -> ShaderMaterial:
	var sd: Dictionary = SEASON_GRASS.get(season, SEASON_GRASS[0])
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque;
uniform vec4 albedo_base   : source_color = vec4(0.24, 0.54, 0.16, 1.0);
uniform vec4 albedo_bright : source_color = vec4(0.34, 0.66, 0.24, 1.0);
uniform float wind_strength : hint_range(0.0, 0.4) = 0.052;
uniform float wind_speed    : hint_range(0.0, 4.0) = 0.88;
varying float v_mix;
void vertex() {
	float px = MODEL_MATRIX[3].x; float pz = MODEL_MATRIX[3].z;
	v_mix = fract(sin(px * 127.1 + pz * 311.7) * 43758.5453);
	float h = clamp((VERTEX.y + 0.14) / 0.28, 0.0, 1.0); h = h * h;
	VERTEX.x += sin(TIME * wind_speed + px * 0.31 + pz * 0.19) * wind_strength * h;
	VERTEX.z += cos(TIME * wind_speed * 0.77 + pz * 0.27 + px * 0.14) * wind_strength * h;
}
void fragment() {
	ALBEDO = mix(albedo_base.rgb, albedo_bright.rgb, v_mix * 0.46);
	ROUGHNESS = 0.88; METALLIC = 0.0;
}
"""
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = shader
	_grass_mat.set_shader_parameter("albedo_base",   sd["base"])
	_grass_mat.set_shader_parameter("albedo_bright", sd["bright"])
	return _grass_mat

func _on_grass_season_changed(season: int) -> void:
	if _grass_mat == null:
		return
	if _grass_palette != null:
		# BinbunGrass path — swap the palette gradient
		_grass_palette = _build_binbun_palette(season)
		_grass_mat.set_shader_parameter("color_gradient", _grass_palette)
	else:
		# Legacy path — tween the colour uniforms
		var sd: Dictionary = SEASON_GRASS.get(season, SEASON_GRASS[0])
		var tw := create_tween().set_parallel(true)
		var from_base: Color   = _grass_mat.get_shader_parameter("albedo_base")
		var from_bright: Color = _grass_mat.get_shader_parameter("albedo_bright")
		tw.tween_method(func(c: Color): _grass_mat.set_shader_parameter("albedo_base",   c), from_base,   sd["base"],   3.0)
		tw.tween_method(func(c: Color): _grass_mat.set_shader_parameter("albedo_bright", c), from_bright, sd["bright"], 3.0)

var _ground_mat: ShaderMaterial = null

# Season terrain colours  [dark, mid, bright] — used by legacy ground shader
const SEASON_TERRAIN := {
	0: [Color(0.18, 0.42, 0.11), Color(0.26, 0.54, 0.17), Color(0.36, 0.66, 0.24)],
	1: [Color(0.11, 0.36, 0.08), Color(0.18, 0.46, 0.12), Color(0.26, 0.58, 0.18)],
	2: [Color(0.38, 0.38, 0.12), Color(0.48, 0.46, 0.16), Color(0.58, 0.52, 0.22)],
	3: [Color(0.18, 0.26, 0.14), Color(0.24, 0.32, 0.18), Color(0.30, 0.38, 0.22)],
}

## Build a GradientTexture1D from the BinbunGrass seasonal palette.
func _build_binbun_palette(season: int) -> GradientTexture1D:
	var colors: Array = SEASON_BINBUN_PALETTE.get(season, SEASON_BINBUN_PALETTE[0])
	var grad := Gradient.new()
	grad.colors  = PackedColorArray([colors[0], colors[1], colors[2]])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width    = 64
	return tex

func _apply_ground_shader() -> void:
	var ground: MeshInstance3D = get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		return

	var ground_shader := load("res://BinbunGrass/src/shader/ground.gdshader") as Shader
	if ground_shader == null:
		push_warning("BinbunGrass ground shader not found — using legacy procedural shader")
		_apply_ground_shader_legacy()
		return

	# Noise matching grass_ground_01.tres (seed=6, frequency=0.008)
	var fn := FastNoiseLite.new()
	fn.noise_type      = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency       = 0.008
	fn.fractal_type    = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 4
	fn.seed            = 6
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise    = fn
	noise_tex.width    = 512
	noise_tex.height   = 512
	noise_tex.seamless = true

	_ground_palette = _build_binbun_palette(SeasonManager.current_season)

	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = ground_shader
	_ground_mat.set_shader_parameter("noise_texture",  noise_tex)
	_ground_mat.set_shader_parameter("color_gradient", _ground_palette)

	ground.set_surface_override_material(0, _ground_mat)

	if not SeasonManager.season_changed.is_connected(_on_terrain_season_changed):
		SeasonManager.season_changed.connect(_on_terrain_season_changed)

## Legacy procedural ground shader — fallback if BinbunGrass is absent.
func _apply_ground_shader_legacy() -> void:
	var ground: MeshInstance3D = get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode depth_draw_opaque;
uniform vec4  col_dark   : source_color = vec4(0.15, 0.38, 0.09, 1.0);
uniform vec4  col_mid    : source_color = vec4(0.24, 0.50, 0.15, 1.0);
uniform vec4  col_bright : source_color = vec4(0.34, 0.62, 0.22, 1.0);
uniform vec4  col_dirt   : source_color = vec4(0.38, 0.28, 0.16, 1.0);
uniform float uv_scale        = 22.0;
uniform float wind_speed      = 0.22;
uniform float normal_strength = 0.55;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float vnoise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.0;float a=0.5;for(int i=0;i<5;i++){v+=vnoise(p)*a;p=p*2.1+vec2(1.7,9.2);a*=0.48;}return v;}
varying float v_height; varying vec2 v_world_xz;
void vertex(){v_height=VERTEX.y;v_world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
	vec2 uv=UV*uv_scale; float ripple=sin(TIME*wind_speed+uv.y*0.35)*0.022; vec2 uv_w=uv+vec2(ripple,0.0);
	float g=fbm(uv_w*0.17)*0.40+fbm(uv_w*0.68)*0.30+vnoise(uv_w*2.90)*0.20+vnoise(uv*7.50+vec2(31.1,17.3))*0.10;
	vec3 col=g<0.45?mix(col_dark.rgb,col_mid.rgb,g/0.45):mix(col_mid.rgb,col_bright.rgb,(g-0.45)/0.55);
	float h_norm=clamp(v_height/2.2,0.0,1.0); col=mix(col*0.75,col,0.30+h_norm*0.70);
	float dirt=smoothstep(5.5,1.5,length(v_world_xz))*0.60; col=mix(col,col_dirt.rgb,dirt*(1.0-h_norm*0.6));
	float roughness=mix(0.94,0.80,clamp(h_norm*2.0-0.4,0.0,1.0)); roughness=mix(roughness,0.87,dirt*0.5);
	float eps=0.45; NORMAL_MAP=normalize(vec3(-(fbm(uv_w+vec2(eps,0))-fbm(uv_w-vec2(eps,0))),-(fbm(uv_w+vec2(0,eps))-fbm(uv_w-vec2(0,eps))),1.0/max(normal_strength,0.01))); NORMAL_MAP_DEPTH=normal_strength;
	ALBEDO=col; ROUGHNESS=roughness; SPECULAR=0.06; METALLIC=0.0;
}
"""
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = shader
	var sd: Array = SEASON_TERRAIN.get(SeasonManager.current_season, SEASON_TERRAIN[0])
	_ground_mat.set_shader_parameter("col_dark",   sd[0])
	_ground_mat.set_shader_parameter("col_mid",    sd[1])
	_ground_mat.set_shader_parameter("col_bright", sd[2])
	ground.set_surface_override_material(0, _ground_mat)
	if not SeasonManager.season_changed.is_connected(_on_terrain_season_changed):
		SeasonManager.season_changed.connect(_on_terrain_season_changed)

func _on_terrain_season_changed(season: int) -> void:
	if _ground_mat == null:
		return
	if _ground_palette != null:
		# BinbunGrass path — rebuild and swap the palette gradient
		_ground_palette = _build_binbun_palette(season)
		_ground_mat.set_shader_parameter("color_gradient", _ground_palette)
	else:
		# Legacy path — tween the colour uniforms
		var sd: Array = SEASON_TERRAIN.get(season, SEASON_TERRAIN[0])
		var tw := create_tween().set_parallel(true)
		var from_d: Color = _ground_mat.get_shader_parameter("col_dark")
		var from_m: Color = _ground_mat.get_shader_parameter("col_mid")
		var from_b: Color = _ground_mat.get_shader_parameter("col_bright")
		tw.tween_method(func(c: Color): _ground_mat.set_shader_parameter("col_dark",   c), from_d, sd[0], 3.0)
		tw.tween_method(func(c: Color): _ground_mat.set_shader_parameter("col_mid",    c), from_m, sd[1], 3.0)
		tw.tween_method(func(c: Color): _ground_mat.set_shader_parameter("col_bright", c), from_b, sd[2], 3.0)

func create_boundary():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.88, 0.62, 1.0)  # soft mossy green
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var half = starter_area_size / 2.0
	var seg := 2.0
	var thickness := 0.12
	var height := 0.06
	var count := int(starter_area_size / seg)

	for i in range(count):
		var along: float = -half + (float(i) + 0.5) * seg
		# North/south edges run along X — pass run_axis "x"
		_add_boundary_segment(Vector3(along, 0.0, -half), Vector3(seg, height, thickness), mat, "x")
		_add_boundary_segment(Vector3(along, 0.0,  half), Vector3(seg, height, thickness), mat, "x")
		# East/west edges run along Z — pass run_axis "z"
		_add_boundary_segment(Vector3(-half, 0.0, along), Vector3(thickness, height, seg), mat, "z")
		_add_boundary_segment(Vector3( half, 0.0, along), Vector3(thickness, height, seg), mat, "z")

func _add_boundary_segment(pos: Vector3, size: Vector3, mat: StandardMaterial3D, run_axis: String):
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.set_meta("run_axis", run_axis)
	mi.set_surface_override_material(0, mat)
	mi.add_to_group("boundary_lines")
	add_child(mi)

## ── Sky shader setup ──────────────────────────────────────────────────────────
func _setup_sky(env: Environment) -> void:
	var sky_shader := load("res://GodotSkiesShaders/main.gdshader") as Shader
	if sky_shader == null:
		push_warning("GodotSkies shader not found — keeping default sky")
		return

	# ── Cloud texture 1 — large, fluffy shapes ────────────────────────────────
	var cn1 := FastNoiseLite.new()
	cn1.noise_type      = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn1.frequency       = 0.0025
	cn1.fractal_type    = FastNoiseLite.FRACTAL_FBM
	cn1.fractal_octaves = 5
	cn1.fractal_gain    = 0.55
	var ct1 := NoiseTexture2D.new()
	ct1.noise = cn1; ct1.width = 512; ct1.height = 512; ct1.seamless = true

	# ── Cloud texture 2 — detail / wisp layer ────────────────────────────────
	var cn2 := FastNoiseLite.new()
	cn2.noise_type      = FastNoiseLite.TYPE_PERLIN
	cn2.frequency       = 0.004
	cn2.fractal_type    = FastNoiseLite.FRACTAL_FBM
	cn2.fractal_octaves = 4
	cn2.fractal_gain    = 0.50
	var ct2 := NoiseTexture2D.new()
	ct2.noise = cn2; ct2.width = 512; ct2.height = 512; ct2.seamless = true

	# ── Star noise 1 — main star field ───────────────────────────────────────
	var sn1 := FastNoiseLite.new()
	sn1.noise_type = FastNoiseLite.TYPE_VALUE
	sn1.frequency  = 0.12
	var st1 := NoiseTexture2D.new()
	st1.noise = sn1; st1.width = 256; st1.height = 256; st1.seamless = true

	# ── Star noise 2 — subtle nebula tint ────────────────────────────────────
	var sn2 := FastNoiseLite.new()
	sn2.noise_type = FastNoiseLite.TYPE_VALUE
	sn2.frequency  = 0.06
	var st2 := NoiseTexture2D.new()
	st2.noise = sn2; st2.width = 256; st2.height = 256; st2.seamless = true

	# ── Build the ShaderMaterial ──────────────────────────────────────────────
	var mat := ShaderMaterial.new()
	mat.shader = sky_shader

	# Textures
	mat.set_shader_parameter("cloud_tex_01",   ct1)
	mat.set_shader_parameter("cloud_tex_02",   ct2)
	mat.set_shader_parameter("night_noise_01", st1)
	mat.set_shader_parameter("night_noise_02", st2)

	# Sky colours — tuned to match the garden's warm-green nature aesthetic
	mat.set_shader_parameter("sky_day",         Color(0.30, 0.55, 0.85, 1.0))
	mat.set_shader_parameter("horizon_day",     Color(0.68, 0.84, 0.72, 1.0))
	mat.set_shader_parameter("horizon_sunset",  Color(0.90, 0.46, 0.14, 1.0))
	mat.set_shader_parameter("sky_sunset",      Color(0.14, 0.18, 0.38, 1.0))
	mat.set_shader_parameter("horizon_night",   Color(0.08, 0.12, 0.20, 1.0))
	mat.set_shader_parameter("sky_night",       Color(0.04, 0.07, 0.14, 1.0))

	# Sun disc
	mat.set_shader_parameter("sun_scale",    0.042)
	mat.set_shader_parameter("sun_strength", 14.0)
	mat.set_shader_parameter("sun_color",    Color(1.0, 0.92, 0.72, 1.0))

	# Clouds
	mat.set_shader_parameter("cloud_density",         0.52)
	mat.set_shader_parameter("cloud_tiling",          Vector2(2.2, 2.2))
	mat.set_shader_parameter("wind_speed",            Vector2(0.25, 0.10))
	mat.set_shader_parameter("cloud_depth",           2.5)
	mat.set_shader_parameter("cloud_shape_exponent",  2.0)
	mat.set_shader_parameter("cloud_color",           Color(0.96, 0.97, 0.99, 1.0))

	# Horizon curve
	mat.set_shader_parameter("horizon_exponent",        2.2)
	mat.set_shader_parameter("use_directional_light",   true)

	# ── Assign to environment ─────────────────────────────────────────────────
	var sky := Sky.new()
	sky.sky_material   = mat
	sky.process_mode   = Sky.PROCESS_MODE_REALTIME  # update every frame (sun moves)
	env.sky            = sky
	env.background_mode = Environment.BG_SKY

## ── Terrain noise helpers ─────────────────────────────────────────────────────
func _th(px: float, pz: float) -> float:
	return fmod(abs(sin(px * 127.1 + pz * 311.7) * 43758.5453), 1.0)

func _tvn(px: float, pz: float) -> float:
	var ix: float = floor(px); var iz: float = floor(pz)
	var fx: float = px - ix;   var fz: float = pz - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	return lerp(lerp(_th(ix, iz), _th(ix + 1.0, iz), fx),
				lerp(_th(ix, iz + 1.0), _th(ix + 1.0, iz + 1.0), fx), fz)

func _tfbm(px: float, pz: float) -> float:
	var v := 0.0; var a := 0.5; var x := px; var z := pz
	for _i in range(6):
		v += _tvn(x, z) * a
		x = x * 2.1 + 1.7; z = z * 2.1 + 9.2; a *= 0.48
	return v

func create_starter_bumps() -> void:
	var ground_node: MeshInstance3D = get_node("Ground") as MeshInstance3D
	var mdt := MeshDataTool.new()
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		ground_node.mesh.surface_get_arrays(0))
	mdt.create_from_surface(arr_mesh, 0)

	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i)
		# Multi-octave smooth terrain: large rolling hills + medium undulation + fine bumps
		var h: float = _tfbm(v.x * 0.045, v.z * 0.045) * 1.7 \
			   + _tvn( v.x * 0.14,  v.z * 0.14)  * 0.50 \
			   + _tvn( v.x * 0.38,  v.z * 0.38)  * 0.13
		# Flat clearing at origin (player/Maren area) — smoothly eased
		var cd: float = clamp(Vector2(v.x, v.z).length() / 9.0, 0.0, 1.0)
		cd = cd * cd * (3.0 - 2.0 * cd)
		h *= cd
		# Taper to flat at map edges so there are no abrupt drop-offs
		var edge: float  = maxf(absf(v.x), absf(v.z))
		var efade: float = clamp(1.0 - (edge - 170.0) / 28.0, 0.0, 1.0)
		v.y = maxf(h * efade, 0.0)
		mdt.set_vertex(i, v)

	arr_mesh.clear_surfaces()
	mdt.commit_to_surface(arr_mesh)

	# Rebuild proper normals AND tangents so the normal-mapped shader works
	var st := SurfaceTool.new()
	st.create_from(arr_mesh, 0)
	st.generate_normals()
	st.generate_tangents()
	ground_node.mesh = st.commit()

	# Rebuild collision immediately from the bumped mesh so it's valid before
	# the first physics tick. tool_manager awaits 2 frames before rebuilding,
	# but _physics_process() fires in frame 1 — without this, roamers fall
	# through the empty ConcavePolygonShape3D that the scene starts with.
	var static_body := ground_node.get_node_or_null("StaticBody3D")
	if static_body:
		var col := static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.shape = ground_node.mesh.create_trimesh_shape()
	

## ── Outer world decoration ────────────────────────────────────────────────────

# Raycast straight down and return the terrain Y at (x, z), or fallback if no hit.
func _terrain_y(x: float, z: float, fallback: float = 0.0) -> float:
	var space := get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(
		Vector3(x, 30.0, z), Vector3(x, -10.0, z))
	var result := space.intersect_ray(query)
	return result.position.y if result else fallback

func _outer_annular_pos(inner_r: float, outer_r: float) -> Vector2:
	var angle := randf() * TAU
	var dist  := sqrt(randf() * (outer_r * outer_r - inner_r * inner_r) + inner_r * inner_r)
	return Vector2(cos(angle) * dist, sin(angle) * dist)

func _scatter_outer_decorations() -> void:
	var rock_shader := _build_rock_shader()
	var log_shader  := _build_log_shader()

	# ── Mossy boulders ──────────────────────────────────────────────────────────
	for _i in range(130):
		var xz := _outer_annular_pos(26.0, 185.0)
		var cluster_count := randi_range(1, 3)
		for _j in range(cluster_count):
			var ox: float = randf_range(-1.8, 1.8)
			var oz: float = randf_range(-1.8, 1.8)
			var cx: float = xz.x + ox
			var cz: float = xz.y + oz
			var rs: float = randf_range(0.55, 2.20)
			var ty: float = _terrain_y(cx, cz)
			var mi  := MeshInstance3D.new()
			var sm  := SphereMesh.new()
			sm.radius = rs; sm.height = rs * randf_range(0.55, 0.85)
			sm.radial_segments = 10; sm.rings = 5
			mi.mesh = sm
			mi.set_surface_override_material(0, rock_shader)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end        = 120.0
			mi.visibility_range_fade_mode  = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mi.position = Vector3(cx, ty + rs * 0.28, cz)
			mi.rotation.y = randf() * TAU
			add_child(mi)

	# ── Fallen logs ─────────────────────────────────────────────────────────────
	for _i in range(65):
		var xz := _outer_annular_pos(28.0, 185.0)
		var tr: float = randf_range(0.22, 0.52)
		var ty: float = _terrain_y(xz.x, xz.y)
		var mi  := MeshInstance3D.new()
		var cm  := CylinderMesh.new()
		cm.top_radius    = tr
		cm.bottom_radius = tr * randf_range(0.85, 1.10)
		cm.height        = randf_range(1.8, 5.5)
		cm.radial_segments = 8
		mi.mesh = cm
		mi.set_surface_override_material(0, log_shader)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end       = 120.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.rotation = Vector3(0.0, randf() * TAU, PI * 0.5)
		mi.position = Vector3(xz.x, ty + tr, xz.y)
		add_child(mi)

	# ── Mushroom clusters ────────────────────────────────────────────────────────
	var mush_mat := StandardMaterial3D.new()
	mush_mat.albedo_color = Color(0.72, 0.48, 0.28)
	mush_mat.roughness    = 0.80
	var mush_cap_mat := StandardMaterial3D.new()
	mush_cap_mat.albedo_color = Color(0.54, 0.22, 0.12)
	mush_cap_mat.roughness    = 0.72
	for _i in range(90):
		var xz := _outer_annular_pos(22.0, 160.0)
		var cluster_count := randi_range(2, 5)
		for _j in range(cluster_count):
			var ox: float = randf_range(-1.2, 1.2)
			var oz: float = randf_range(-1.2, 1.2)
			var mx: float = xz.x + ox
			var mz: float = xz.y + oz
			var ty: float = _terrain_y(mx, mz)
			var h: float  = randf_range(0.18, 0.55)
			# Stem — base sits exactly on terrain
			var stem := MeshInstance3D.new()
			var sm   := CylinderMesh.new()
			sm.top_radius = 0.06; sm.bottom_radius = 0.08; sm.height = h
			sm.radial_segments = 6; stem.mesh = sm
			stem.set_surface_override_material(0, mush_mat)
			stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stem.visibility_range_end       = 80.0
			stem.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			stem.position = Vector3(mx, ty + h * 0.5, mz)
			add_child(stem)
			var cap  := MeshInstance3D.new()
			var spm  := SphereMesh.new()
			spm.radius = h * randf_range(0.9, 1.4)
			spm.height = spm.radius * 0.55
			spm.radial_segments = 8; spm.rings = 4
			cap.mesh = spm
			cap.set_surface_override_material(0, mush_cap_mat)
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cap.visibility_range_end       = 80.0
			cap.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			cap.position = Vector3(mx, ty + h + spm.height * 0.3, mz)
			add_child(cap)

## ── LOD helper — recursively set visibility_range_end on all geometry ─────────
func _apply_visibility_range(node: Node, max_dist: float) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.visibility_range_end        = max_dist
		gi.visibility_range_end_margin = 8.0
		gi.visibility_range_fade_mode  = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for child in node.get_children():
		_apply_visibility_range(child, max_dist)

## ── Dense outer forest ring ───────────────────────────────────────────────────
func _scatter_outer_forest() -> void:
	if _tree_scenes.is_empty():
		return
	var inner_r := starter_area_size * 0.65   # ~26 — just outside the boundary
	var outer_r := 182.0

	for _i in range(260):
		var xz    := _outer_annular_pos(inner_r, outer_r)
		var ty    := _terrain_y(xz.x, xz.y, 0.0)
		var scene : PackedScene = _tree_scenes[randi() % _tree_scenes.size()]
		var tree  := scene.instantiate()
		tree.add_to_group("trees")
		# Cull trees that are far from the camera — big perf saving for a dense forest
		_apply_visibility_range(tree, 145.0)
		add_child(tree)
		tree.position  = Vector3(xz.x, ty, xz.y)
		var s := randf_range(min_scale * 0.75, max_scale * 1.15)
		tree.scale     = Vector3(s, s, s)
		tree.rotation.y = randf() * TAU

func _build_rock_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void fragment() {
	vec2 uv = UV * vec2(4.5, 3.0);
	float n_coarse = vnoise(uv * 1.2);
	float n_fine   = vnoise(uv * 4.5);
	float n_micro  = vnoise(uv * 11.0);
	float rock = n_coarse * 0.50 + n_fine * 0.32 + n_micro * 0.18;

	// Moss grows on upper faces and in crevices
	float top_face = clamp(NORMAL.y * 1.8, 0.0, 1.0);
	float moss_n   = vnoise(UV * vec2(3.0, 2.5));
	float moss     = clamp(top_face * moss_n * 1.4, 0.0, 1.0);

	vec3 rock_col = mix(vec3(0.28, 0.26, 0.24), vec3(0.42, 0.38, 0.34), rock);
	vec3 moss_col = mix(vec3(0.18, 0.26, 0.12), vec3(0.26, 0.36, 0.18), n_fine);
	vec3 col      = mix(rock_col, moss_col, moss * 0.70);

	ALBEDO    = col;
	ROUGHNESS = mix(0.92, 0.80, moss);
	METALLIC  = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _build_log_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void fragment() {
	vec2 uv = UV * vec2(2.5, 9.0);
	float ridges  = sin(uv.x * 12.0 + vnoise(uv * vec2(0.8, 2.0)) * 2.0) * 0.5 + 0.5;
	ridges = pow(ridges, 1.5);
	float n_grain = vnoise(uv * vec2(1.5, 5.0));
	float bark    = ridges * 0.55 + n_grain * 0.45;

	// Decay and moss on top
	float decay_n = vnoise(UV * 2.5);
	float top     = clamp(NORMAL.y * 2.0, 0.0, 1.0);
	float moss    = clamp(top * decay_n * 1.2, 0.0, 1.0);

	vec3 bark_col = mix(vec3(0.22, 0.14, 0.08), vec3(0.36, 0.24, 0.14), bark);
	vec3 moss_col = vec3(0.22, 0.30, 0.14);
	vec3 col      = mix(bark_col, moss_col, moss * 0.60);

	ALBEDO    = col;
	ROUGHNESS = 0.94;
	METALLIC  = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func scatter_debris():
	var half := starter_area_size / 2.0
	var base_path := "res://Stylized Nature MegaKit[Standard]/glTF/"

	# ── Load asset pools at runtime (paths have spaces so no preload) ────────────
	var rock_scenes  : Array[PackedScene] = []
	var pebble_scenes: Array[PackedScene] = []
	var log_scenes   : Array[PackedScene] = []

	for i in range(1, 4):   # Rock_Medium_1..3
		var s := load(base_path + "Rock_Medium_%d.gltf" % i) as PackedScene
		if s: rock_scenes.append(s)

	for i in range(1, 6):   # Pebble_Round_1..5
		var s := load(base_path + "Pebble_Round_%d.gltf" % i) as PackedScene
		if s: pebble_scenes.append(s)
	for i in range(1, 6):   # Pebble_Square_1..5
		var s := load(base_path + "Pebble_Square_%d.gltf" % i) as PackedScene
		if s: pebble_scenes.append(s)

	for i in range(1, 4):   # DeadTree_1..3 — used as small fallen-log stumps
		var s := load(base_path + "DeadTree_%d.gltf" % i) as PackedScene
		if s: log_scenes.append(s)

	# ── Debris definition: name, scene pool, scale range, collision r, reward/xp
	# collision_r is radius of the SphereShape3D used for click detection
	var groups := [
		{"name": "Rock",      "scenes": rock_scenes,   "scale_min": 0.55, "scale_max": 1.10,
		 "col_r": 0.55, "reward": 5.0, "xp": 8.0,  "count": 5},
		{"name": "SmallRock", "scenes": pebble_scenes, "scale_min": 0.80, "scale_max": 1.60,
		 "col_r": 0.30, "reward": 3.0, "xp": 5.0,  "count": 6},
		{"name": "Log",       "scenes": log_scenes,    "scale_min": 0.18, "scale_max": 0.30,
		 "col_r": 0.45, "reward": 8.0, "xp": 10.0, "count": 4},
	]

	for group in groups:
		var pool: Array[PackedScene] = group["scenes"]
		for j in range(group["count"]):
			var debris_node := StaticBody3D.new()
			debris_node.name          = "%s_%d" % [group["name"], j]
			debris_node.add_to_group("debris")
			debris_node.set_meta("dewdrop_reward", group["reward"])
			debris_node.set_meta("xp_reward",      group["xp"])
			debris_node.set_meta("debris_name",    group["name"])

			# ── Visual — gltf instance if available, fallback sphere ───────────
			if not pool.is_empty():
				var visual := pool[randi() % pool.size()].instantiate()
				var s: float = randf_range(group["scale_min"], group["scale_max"])
				visual.scale = Vector3(s, s, s)
				debris_node.add_child(visual)
			else:
				var mi := MeshInstance3D.new()
				mi.mesh = SphereMesh.new()
				debris_node.add_child(mi)

			# ── Collision — sphere approximation, good enough for clicking ─────
			var col := CollisionShape3D.new()
			var sp  := SphereShape3D.new()
			sp.radius  = group["col_r"]
			col.shape  = sp
			debris_node.add_child(col)

			# ── Position — snap to terrain surface via raycast ─────────────────
			var x := randf_range(-half + 4.0, half - 4.0)
			var z := randf_range(-half + 4.0, half - 4.0)
			var ty := _terrain_y(x, z, 0.0)
			debris_node.position   = Vector3(x, ty, z)
			debris_node.rotation.y = randf() * TAU

			add_child(debris_node)
		
		
func plant_starting_bushes():
	# Three bushes spread around the starter area so roamers have immediate food.
	# Raycast down to terrain surface so each bush sits at the right height.
	var positions = [
		Vector3(5.0, 10.0, 3.0),
		Vector3(-6.0, 10.0, 5.0),
		Vector3(3.0, 10.0, -7.0),
	]
	var space_state = get_world_3d().direct_space_state
	for pos in positions:
		var query = PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -15, 0))
		var result = space_state.intersect_ray(query)
		var plant_y = result.position.y if result else 1.0
		var bush = berry_bush_scene.instantiate()
		add_child(bush)
		bush.global_position = Vector3(pos.x, plant_y, pos.z)

func give_starting_inventory():
	InventoryManager.add_item("Berry Seeds", 5)
	InventoryManager.add_item("Basic Shelter", 2)

var _boundary_timer: float = 0.0

func _process(delta):
	_boundary_timer += delta
	if _boundary_timer >= 0.2:
		_boundary_timer = 0.0
		update_boundary_heights()
	_tick_attraction(delta)

func update_boundary_heights():
	var space_state = get_world_3d().direct_space_state
	for line in get_tree().get_nodes_in_group("boundary_lines"):
		var ray_origin = Vector3(line.position.x, 10.0, line.position.z)
		var ray_end   = Vector3(line.position.x, -5.0, line.position.z)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		if not result:
			continue
		line.position.y = result.position.y + 0.04
		# Tilt the segment to lie flush with the terrain slope
		var n: Vector3 = result.normal
		var run_axis: String = line.get_meta("run_axis", "x")
		if run_axis == "x":
			# Segment runs along X — tilt around X to follow Z-slope
			line.rotation = Vector3(atan2(-n.z, n.y), 0.0, 0.0)
		else:
			# Segment runs along Z — tilt around Z to follow X-slope
			line.rotation = Vector3(0.0, 0.0, atan2(n.x, n.y))

# ---------------------------------------------------------------------------
# Wild roamer attraction
# ---------------------------------------------------------------------------

func _tick_attraction(delta: float):
	# Count down per-species cooldowns
	for species in attraction_cooldowns.keys():
		attraction_cooldowns[species] -= delta
		if attraction_cooldowns[species] <= 0.0:
			attraction_cooldowns.erase(species)

	attraction_check_timer += delta
	if attraction_check_timer < ATTRACTION_CHECK_INTERVAL:
		return
	attraction_check_timer = 0.0
	_check_wild_attractions()

func _check_wild_attractions():
	var food_count = get_tree().get_nodes_in_group("food").size()
	var shelter_count = get_tree().get_nodes_in_group("shelters").size()
	var roamers = get_tree().get_nodes_in_group("roamers")

	# Average happiness across all current roamers (0.5 if none yet)
	var avg_happiness := 0.5
	if roamers.size() > 0:
		var total := 0.0
		for r in roamers:
			total += r.happiness
		avg_happiness = total / roamers.size()

	for species_id in species_requirements:
		var req = species_requirements[species_id]

		# Still on cooldown?
		if attraction_cooldowns.has(species_id):
			continue

		# Already at population cap?
		var count := 0
		for r in roamers:
			if r.species_id == species_id:
				count += 1
		if count >= req["max_in_garden"]:
			continue

		# Check requirements
		if food_count < req["min_food"]:
			continue
		if shelter_count < req["min_shelters"]:
			continue
		if avg_happiness < req["min_avg_happiness"]:
			continue

		# All requirements met — attract one!
		_spawn_wild_roamer(species_id, req)
		attraction_cooldowns[species_id] = ATTRACTION_COOLDOWN
		break  # one spawn per check cycle

func _spawn_wild_roamer(species_id: String, req: Dictionary):
	var scene = load(req["scene"])
	if not scene:
		return

	var roamer = scene.instantiate()
	var spawn_pos = _get_boundary_spawn_pos()
	# Stamp species before add_child so _ready() doesn't need to do it
	add_child(roamer)
	roamer.global_position = spawn_pos

	# Send it walking toward the garden centre so it naturally enters
	var centre_target = Vector3(
		randf_range(-8.0, 8.0),
		spawn_pos.y,
		randf_range(-8.0, 8.0)
	)
	roamer.wander_target = centre_target
	roamer.wander_timer = 30.0

	_show_attraction_popup(spawn_pos, req["label"] + " is visiting!")
	WardenManager.gain_xp("roamer_appears")
	print("Wild ", species_id, " attracted to the garden!")

func _get_boundary_spawn_pos() -> Vector3:
	var half = starter_area_size / 2.0
	# Pick a random edge and a random point along it, just outside the boundary
	var edge = randi() % 4
	var x: float; var z: float
	match edge:
		0: x = randf_range(-half, half); z = -(half + 1.5)
		1: x = randf_range(-half, half); z =   half + 1.5
		2: x = -(half + 1.5);           z = randf_range(-half, half)
		3: x =   half + 1.5;            z = randf_range(-half, half)

	# Snap to terrain height
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(x, 15.0, z), Vector3(x, -5.0, z)
	)
	var result = space_state.intersect_ray(query)
	var y = (result.position.y + 1.5) if result else 3.0
	return Vector3(x, y, z)

func _show_attraction_popup(pos: Vector3, text: String):
	var label = Label3D.new()
	label.text = text
	label.font_size = 56
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.7, 1.0, 0.55)
	add_child(label)
	label.global_position = pos + Vector3(0, 2.5, 0)
	var tween = create_tween()
	tween.tween_property(label, "global_position", pos + Vector3(0, 6.0, 0), 3.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 3.5)
	tween.tween_callback(label.queue_free)

# Returns attraction status text for each species — used by the HUD.
func get_objective_hint() -> String:
	var roamers = get_tree().get_nodes_in_group("roamers")
	var food_count  = get_tree().get_nodes_in_group("food").size()
	var shelter_count = get_tree().get_nodes_in_group("shelters").size()

	if roamers.is_empty():
		if food_count == 0:
			return "🌿 Plant a berry bush so wild Roamers have a reason to visit."
		return "🌿 Wait — wild Roamers will wander in if your garden looks inviting."

	# Collect per-stage counts and needs
	var appears_unhappy  := []  # need happiness > 0.5
	var visits_no_shelter := [] # need shelter
	var visits_low_happy  := [] # need happiness > 0.7
	var resident_low_happy := [] # need happiness > 0.9
	var bonded := 0
	var hungry := []            # food < 0.3

	for r in roamers:
		if r.needs["food"] < 0.3:
			hungry.append(r.name)
		match r.attraction_stage:
			0: # APPEARS
				if r.happiness <= 0.5:
					appears_unhappy.append(r.name)
			1: # VISITS
				if not r.has_shelter:
					visits_no_shelter.append(r.name)
				elif r.happiness <= 0.7:
					visits_low_happy.append(r.name)
			2: # RESIDENT
				if r.happiness <= 0.9:
					resident_low_happy.append(r.name)
			3: # BONDED
				bonded += 1

	# Return the most urgent hint
	if not hungry.is_empty():
		return "🍓 " + hungry[0] + " is hungry — plant berry bushes or use a Roamer Treat."
	if not appears_unhappy.is_empty():
		return "💛 " + appears_unhappy[0] + " is exploring — keep happiness above 50" + "%" + " to earn their trust."
	if not visits_no_shelter.is_empty():
		return "🏠 " + visits_no_shelter[0] + " needs a shelter to become a Resident — buy one from Maren."
	if not visits_low_happy.is_empty():
		return "💛 " + visits_low_happy[0] + " needs happiness above 70" + "%" + " to settle in — feed them."
	if not resident_low_happy.is_empty():
		return "💚 " + resident_low_happy[0] + " needs happiness above 90" + "%" + " to Bond — keep all needs full."
	if bonded >= 2:
		return "💞 Two Bonded Roamers are ready — click one, then click the other to breed!"
	if bonded == 1:
		return "🌟 One Roamer is Bonded! Bond another to unlock breeding."
	if shelter_count == 0 and roamers.size() > 0:
		return "🏠 No shelters yet — buy a Basic Shelter from Maren and place it."
	return "✨ Garden is thriving! Attract more wild Roamers to grow your habitat."

func get_attraction_hints() -> Array:
	var hints = []
	var food_count = get_tree().get_nodes_in_group("food").size()
	var shelter_count = get_tree().get_nodes_in_group("shelters").size()
	var roamers = get_tree().get_nodes_in_group("roamers")
	var avg_happiness := 0.5
	if roamers.size() > 0:
		var total := 0.0
		for r in roamers:
			total += r.happiness
		avg_happiness = total / roamers.size()

	for species_id in species_requirements:
		var req = species_requirements[species_id]
		var count := 0
		for r in roamers:
			if r.species_id == species_id:
				count += 1
		if count >= req["max_in_garden"]:
			hints.append(req["label"] + ": garden full")
			continue
		if attraction_cooldowns.has(species_id):
			hints.append(req["label"] + ": on their way... ✨")
			continue
		var parts := []
		if food_count < req["min_food"]:
			parts.append(str(food_count) + "/" + str(req["min_food"]) + " food")
		if shelter_count < req["min_shelters"]:
			parts.append(str(shelter_count) + "/" + str(req["min_shelters"]) + " shelter")
		if avg_happiness < req["min_avg_happiness"]:
			parts.append("happiness too low")
		if parts.is_empty():
			hints.append(req["label"] + ": requirements met ✓")
		else:
			hints.append(req["label"] + ": needs " + ", ".join(parts))
	return hints
