extends Node3D

var _light: OmniLight3D = null
var _lantern_mat: StandardMaterial3D = null
var _is_on: bool = false
var _check_timer: float = 0.0

func _ready():
	add_to_group("decoratives")
	_build()
	# Set initial state immediately
	_check_timer = 2.0  # force first check

func _build():
	# Post
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.22, 0.18, 0.12)
	post_mat.roughness = 0.92
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius    = 0.035
	post_mesh.bottom_radius = 0.042
	post_mesh.height        = 0.85
	var post_mi := MeshInstance3D.new()
	post_mi.mesh = post_mesh
	post_mi.set_surface_override_material(0, post_mat)
	post_mi.position = Vector3(0.0, 0.42, 0.0)
	add_child(post_mi)

	# Lantern frame (dark metal box)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.20, 0.16, 0.10)
	frame_mat.roughness = 0.75
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.22, 0.26, 0.22)
	var frame_mi := MeshInstance3D.new()
	frame_mi.mesh = frame_mesh
	frame_mi.set_surface_override_material(0, frame_mat)
	frame_mi.position = Vector3(0.0, 0.98, 0.0)
	add_child(frame_mi)

	# Glass glow sphere inside the lantern
	_lantern_mat = StandardMaterial3D.new()
	_lantern_mat.albedo_color       = Color(1.0, 0.82, 0.45, 0.7)
	_lantern_mat.transparency       = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lantern_mat.emission_enabled   = true
	_lantern_mat.emission           = Color(1.0, 0.72, 0.25)
	_lantern_mat.emission_energy_multiplier = 0.0  # off until night
	var glass_mesh := SphereMesh.new()
	glass_mesh.radius = 0.08
	glass_mesh.height = 0.14
	var glass_mi := MeshInstance3D.new()
	glass_mi.mesh = glass_mesh
	glass_mi.set_surface_override_material(0, _lantern_mat)
	glass_mi.position = Vector3(0.0, 0.98, 0.0)
	add_child(glass_mi)

	# Roof cap
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius    = 0.02
	cap_mesh.bottom_radius = 0.14
	cap_mesh.height        = 0.10
	var cap_mi := MeshInstance3D.new()
	cap_mi.mesh = cap_mesh
	cap_mi.set_surface_override_material(0, frame_mat)
	cap_mi.position = Vector3(0.0, 1.13, 0.0)
	add_child(cap_mi)

	# OmniLight — starts off
	_light = OmniLight3D.new()
	_light.light_color        = Color(1.0, 0.75, 0.35)
	_light.light_energy       = 0.0
	_light.omni_range         = 10.0
	_light.omni_attenuation   = 1.2
	_light.shadow_enabled     = false
	_light.position           = Vector3(0.0, 0.98, 0.0)
	add_child(_light)

func _process(delta):
	_check_timer += delta
	if _check_timer >= 1.5:
		_check_timer = 0.0
		_update_light_state()

func _update_light_state():
	var hour: float = DayNightManager.current_time
	var should_be_on: bool = hour >= 18.5 or hour < 7.0
	if should_be_on == _is_on:
		return
	_is_on = should_be_on
	var target_energy := 3.2 if _is_on else 0.0
	var target_emission := 2.2 if _is_on else 0.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_light_energy, _light.light_energy, target_energy, 1.5)
	if _lantern_mat:
		tween.parallel().tween_property(_lantern_mat, "emission_energy_multiplier", target_emission, 1.5)

func _set_light_energy(val: float):
	if _light:
		_light.light_energy = val
