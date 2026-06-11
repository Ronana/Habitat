extends Node3D

var _light: OmniLight3D = null
var _flame_mat: StandardMaterial3D = null
var _flicker_timer: float = 0.0
var _next_flicker: float = 0.0
var _base_energy: float = 3.5

func _ready():
	add_to_group("decoratives")
	_flicker_timer = randf_range(0.0, 1.5)
	_build()

func _build():
	# Stone shaft
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.42, 0.38, 0.30)
	stone_mat.roughness = 0.95

	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius    = 0.07
	shaft_mesh.bottom_radius = 0.09
	shaft_mesh.height        = 0.75
	var shaft_mi := MeshInstance3D.new()
	shaft_mi.mesh = shaft_mesh
	shaft_mi.set_surface_override_material(0, stone_mat)
	shaft_mi.position = Vector3(0.0, 0.38, 0.0)
	add_child(shaft_mi)

	# Moss wrap around the shaft
	var moss_mat := StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.25, 0.50, 0.18)
	moss_mat.roughness = 0.92
	for i in range(3):
		var angle := float(i) * (TAU / 3.0) + randf_range(-0.3, 0.3)
		var moss_mesh := SphereMesh.new()
		moss_mesh.radius = 0.055
		moss_mesh.height = 0.085
		var moss_mi := MeshInstance3D.new()
		moss_mi.mesh = moss_mesh
		moss_mi.set_surface_override_material(0, moss_mat)
		moss_mi.scale = Vector3(1.0, 0.4, 1.0)
		moss_mi.position = Vector3(
			cos(angle) * 0.09,
			randf_range(0.15, 0.55),
			sin(angle) * 0.09
		)
		add_child(moss_mi)

	# Bowl / cup at the top of the shaft
	var bowl_mat := StandardMaterial3D.new()
	bowl_mat.albedo_color = Color(0.28, 0.22, 0.14)
	bowl_mat.roughness = 0.88
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius    = 0.12
	bowl_mesh.bottom_radius = 0.08
	bowl_mesh.height        = 0.12
	var bowl_mi := MeshInstance3D.new()
	bowl_mi.mesh = bowl_mesh
	bowl_mi.set_surface_override_material(0, bowl_mat)
	bowl_mi.position = Vector3(0.0, 0.81, 0.0)
	add_child(bowl_mi)

	# Flame — glowing sphere above the bowl
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.albedo_color            = Color(1.0, 0.55, 0.10)
	_flame_mat.roughness               = 0.3
	_flame_mat.emission_enabled        = true
	_flame_mat.emission                = Color(1.0, 0.42, 0.05)
	_flame_mat.emission_energy_multiplier = 2.5

	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.10
	flame_mesh.height = 0.18
	var flame_mi := MeshInstance3D.new()
	flame_mi.mesh = flame_mesh
	flame_mi.set_surface_override_material(0, _flame_mat)
	flame_mi.position = Vector3(0.0, 0.96, 0.0)
	flame_mi.scale = Vector3(0.9, 1.3, 0.9)
	add_child(flame_mi)

	# OmniLight
	_light = OmniLight3D.new()
	_light.light_color      = Color(1.0, 0.55, 0.18)
	_light.light_energy     = _base_energy
	_light.omni_range       = 10.0
	_light.omni_attenuation = 1.0
	_light.shadow_enabled   = false
	_light.position         = Vector3(0.0, 0.96, 0.0)
	add_child(_light)

func _process(delta):
	_flicker_timer += delta
	if _flicker_timer >= _next_flicker:
		_flicker_timer = 0.0
		_next_flicker = randf_range(0.04, 0.22)
		var target_e := _base_energy + randf_range(-1.0, 0.8)
		target_e = clamp(target_e, 1.2, _base_energy + 1.0)
		var tween := create_tween().set_trans(Tween.TRANS_QUAD)
		tween.tween_property(_light, "light_energy", target_e, _next_flicker * 0.9)
		# Also flicker the flame emission
		if _flame_mat:
			var target_em := 1.8 + randf_range(-0.6, 0.8)
			tween.parallel().tween_property(
				_flame_mat, "emission_energy_multiplier", target_em, _next_flicker * 0.9)
