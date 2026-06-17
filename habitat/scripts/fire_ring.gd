## fire_ring.gd — Torvald commission item.
## A stone-circled fire pit. Provides warmth; roamers gather nearby at night.
extends Node3D

var item_type: String = "Fire Ring"
var _time: float = 0.0
var _fire_light: OmniLight3D = null

func _ready() -> void:
	add_to_group("torvald_builds")
	add_to_group("decoratives")
	add_to_group("lighting")
	_build()

func _process(delta: float) -> void:
	_time += delta
	if _fire_light:
		# Flicker: combine two sin waves at different frequencies
		var flicker := 0.7 + 0.2 * sin(_time * 7.3) + 0.1 * sin(_time * 13.7)
		_fire_light.light_energy = flicker * 2.2

func _build() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.34, 0.28)
	stone_mat.roughness = 0.90

	var dark_stone := StandardMaterial3D.new()
	dark_stone.albedo_color = Color(0.18, 0.15, 0.12)
	dark_stone.roughness = 0.95

	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(0.95, 0.35, 0.05)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.40, 0.05)
	ember_mat.emission_energy_multiplier = 1.8

	var coal_mat := StandardMaterial3D.new()
	coal_mat.albedo_color = Color(0.12, 0.10, 0.08)
	coal_mat.roughness = 1.0

	# Ground ash pit (flat dark circle)
	_add_cyl(Vector3(0, 0.04, 0), 0.55, 0.55, 0.08, dark_stone)

	# Ring of standing stones — 8 stones evenly spaced
	var num_stones := 8
	for i in range(num_stones):
		var angle := (float(i) / float(num_stones)) * TAU
		var r := 0.78
		var px := cos(angle) * r
		var pz := sin(angle) * r
		var w := randf_range(0.16, 0.24)
		var h := randf_range(0.38, 0.56)
		var d := randf_range(0.14, 0.20)
		_add_box(Vector3(px, h * 0.5, pz), Vector3(w, h, d), stone_mat)

	# Coal bed
	_add_cyl(Vector3(0, 0.09, 0), 0.30, 0.30, 0.10, coal_mat)
	# Ember glow layer
	_add_cyl(Vector3(0, 0.14, 0), 0.20, 0.20, 0.06, ember_mat)

	# Fire light
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.12)
	_fire_light.light_energy = 2.0
	_fire_light.omni_range = 5.5
	_fire_light.position = Vector3(0, 0.6, 0)
	add_child(_fire_light)

	# Fire particles
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.0
	p.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, -0.05, 0)
	pm.scale_min = 0.06
	pm.scale_max = 0.14
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.7, 0.1, 0.9))
	grad.add_point(0.5, Color(1.0, 0.25, 0.0, 0.6))
	grad.add_point(1.0, Color(0.2, 0.2, 0.2, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.07
	flame_mesh.height = 0.18
	p.draw_pass_1 = flame_mesh
	p.position = Vector3(0, 0.18, 0)
	add_child(p)

	# Smoke particles
	var sp := GPUParticles3D.new()
	sp.amount = 10
	sp.lifetime = 2.5
	sp.emitting = true
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spm.emission_sphere_radius = 0.10
	spm.direction = Vector3(0, 1, 0)
	spm.spread = 35.0
	spm.initial_velocity_min = 0.15
	spm.initial_velocity_max = 0.35
	spm.gravity = Vector3(0.05, 0.02, 0)
	spm.scale_min = 0.10
	spm.scale_max = 0.22
	var sgrad := Gradient.new()
	sgrad.add_point(0.0, Color(0.3, 0.3, 0.3, 0.25))
	sgrad.add_point(1.0, Color(0.5, 0.5, 0.5, 0.0))
	var sgt := GradientTexture1D.new()
	sgt.gradient = sgrad
	spm.color_ramp = sgt
	sp.process_material = spm
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.12
	smoke_mesh.height = 0.24
	sp.draw_pass_1 = smoke_mesh
	sp.position = Vector3(0, 0.9, 0)
	add_child(sp)

	# Collision ring (approximate with cylinder)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.85
	cyl.height = 0.65
	cs.shape = cyl
	cs.position = Vector3(0, 0.30, 0)
	body.add_child(cs)
	add_child(body)

	var lbl := Label3D.new()
	lbl.text = "Fire Ring"
	lbl.font_size = 24
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 1.4, 0)
	add_child(lbl)

func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)

func _add_cyl(pos: Vector3, top_r: float, bot_r: float, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = height
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)
