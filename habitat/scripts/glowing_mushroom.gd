extends Node3D

var _light: OmniLight3D = null
var _cap_mat: StandardMaterial3D = null
var _glow_timer: float = 0.0

func _ready():
	add_to_group("decoratives")
	_build()

func _build():
	# Stalk — cream coloured
	var stalk_mat := StandardMaterial3D.new()
	stalk_mat.albedo_color = Color(0.82, 0.88, 0.80)
	stalk_mat.roughness = 0.85
	stalk_mat.emission_enabled = true
	stalk_mat.emission = Color(0.60, 0.95, 0.75)
	stalk_mat.emission_energy_multiplier = 0.18

	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius    = 0.10
	stalk_mesh.bottom_radius = 0.08
	stalk_mesh.height        = 0.42
	var stalk_mi := MeshInstance3D.new()
	stalk_mi.mesh = stalk_mesh
	stalk_mi.set_surface_override_material(0, stalk_mat)
	stalk_mi.position = Vector3(0.0, 0.21, 0.0)
	add_child(stalk_mi)

	# Cap — bioluminescent blue-green
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.albedo_color            = Color(0.22, 0.72, 0.58)
	_cap_mat.roughness               = 0.55
	_cap_mat.emission_enabled        = true
	_cap_mat.emission                = Color(0.18, 0.88, 0.65)
	_cap_mat.emission_energy_multiplier = 1.0

	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.28
	cap_mesh.height = 0.42
	var cap_mi := MeshInstance3D.new()
	cap_mi.mesh = cap_mesh
	cap_mi.set_surface_override_material(0, _cap_mat)
	cap_mi.position = Vector3(0.0, 0.54, 0.0)
	cap_mi.scale = Vector3(1.0, 0.72, 1.0)
	add_child(cap_mi)

	# Gill ring
	var gill_mat := StandardMaterial3D.new()
	gill_mat.albedo_color = Color(0.55, 0.92, 0.78)
	gill_mat.roughness = 0.7
	var gill_mesh := CylinderMesh.new()
	gill_mesh.top_radius    = 0.26
	gill_mesh.bottom_radius = 0.14
	gill_mesh.height        = 0.015
	var gill_mi := MeshInstance3D.new()
	gill_mi.mesh = gill_mesh
	gill_mi.set_surface_override_material(0, gill_mat)
	gill_mi.position = Vector3(0.0, 0.42, 0.0)
	add_child(gill_mi)

	# OmniLight — always on, soft blue-green
	_light = OmniLight3D.new()
	_light.light_color      = Color(0.35, 0.95, 0.70)
	_light.light_energy     = 1.2
	_light.omni_range       = 5.0
	_light.omni_attenuation = 1.5
	_light.shadow_enabled   = false
	_light.position         = Vector3(0.0, 0.55, 0.0)
	add_child(_light)

func _process(delta):
	_glow_timer += delta
	# Gentle breathing pulse on the cap emission
	if _cap_mat:
		_cap_mat.emission_energy_multiplier = 0.85 + 0.35 * sin(_glow_timer * 1.4)
	# Matching light pulse
	if _light:
		_light.light_energy = 1.0 + 0.30 * sin(_glow_timer * 1.4)
