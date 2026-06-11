extends Node3D

var _light: OmniLight3D = null
var _flicker_timer: float = 0.0
var _next_flicker: float = 0.0
var _sparkle_timer: float = 0.0
var _base_energy: float = 1.4

func _ready():
	add_to_group("decoratives")
	_flicker_timer = randf_range(0.0, 2.0)  # stagger jars placed together
	_build()

func _build():
	# Jar body — glass cylinder
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color         = Color(0.75, 0.88, 0.80, 0.45)
	glass_mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness            = 0.15
	glass_mat.metallic             = 0.05
	glass_mat.emission_enabled     = true
	glass_mat.emission             = Color(1.0, 0.88, 0.40)
	glass_mat.emission_energy_multiplier = 0.35

	var jar_mesh := CylinderMesh.new()
	jar_mesh.top_radius    = 0.13
	jar_mesh.bottom_radius = 0.14
	jar_mesh.height        = 0.30
	var jar_mi := MeshInstance3D.new()
	jar_mi.mesh = jar_mesh
	jar_mi.set_surface_override_material(0, glass_mat)
	jar_mi.position = Vector3(0.0, 0.18, 0.0)
	add_child(jar_mi)

	# Jar base (solid bottom)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.60, 0.75, 0.65)
	base_mat.roughness = 0.4
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius    = 0.14
	base_mesh.bottom_radius = 0.15
	base_mesh.height        = 0.04
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base_mesh
	base_mi.set_surface_override_material(0, base_mat)
	base_mi.position = Vector3(0.0, 0.02, 0.0)
	add_child(base_mi)

	# Metal lid
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.45, 0.38, 0.22)
	lid_mat.roughness = 0.65
	lid_mat.metallic = 0.5
	var lid_mesh := CylinderMesh.new()
	lid_mesh.top_radius    = 0.10
	lid_mesh.bottom_radius = 0.14
	lid_mesh.height        = 0.05
	var lid_mi := MeshInstance3D.new()
	lid_mi.mesh = lid_mesh
	lid_mi.set_surface_override_material(0, lid_mat)
	lid_mi.position = Vector3(0.0, 0.355, 0.0)
	add_child(lid_mi)

	# OmniLight — warm amber, will flicker
	_light = OmniLight3D.new()
	_light.light_color      = Color(1.0, 0.82, 0.30)
	_light.light_energy     = _base_energy
	_light.omni_range       = 6.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled   = false
	_light.position         = Vector3(0.0, 0.22, 0.0)
	add_child(_light)

func _process(delta):
	_flicker_timer += delta
	_sparkle_timer += delta

	# Irregular flicker
	if _flicker_timer >= _next_flicker:
		_flicker_timer = 0.0
		_next_flicker = randf_range(0.05, 0.35)
		var target := _base_energy + randf_range(-0.6, 0.5)
		target = clamp(target, 0.4, _base_energy + 0.6)
		var tween := create_tween().set_trans(Tween.TRANS_QUAD)
		tween.tween_property(_light, "light_energy", target, _next_flicker * 0.8)

	# Spawn a floating sparkle dot every few seconds
	if _sparkle_timer >= randf_range(1.8, 3.5):
		_sparkle_timer = 0.0
		_spawn_sparkle()

func _spawn_sparkle():
	var dot := Label3D.new()
	dot.text = "•"
	dot.font_size = 10 + randi() % 10
	dot.modulate = Color(1.0, 0.92, 0.30, 0.95)
	dot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dot.no_depth_test = true
	var start_offset := Vector3(
		randf_range(-0.08, 0.08),
		randf_range(0.25, 0.36),
		randf_range(-0.08, 0.08)
	)
	dot.position = start_offset
	add_child(dot)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dot, "position:y", start_offset.y + randf_range(0.3, 0.7), 1.8) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(dot, "modulate:a", 0.0, 1.8).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(dot.queue_free)
