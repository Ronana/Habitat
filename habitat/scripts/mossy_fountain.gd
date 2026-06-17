## mossy_fountain.gd — Torvald commission item.
## A stone basin with glowing water. Roamers visit to drink.
extends Node3D

var item_type: String = "Mossy Fountain"
var _time: float = 0.0
var _water_light: OmniLight3D = null

func _ready() -> void:
	add_to_group("torvald_builds")
	add_to_group("decoratives")
	add_to_group("water_sources")
	_build()

func _process(delta: float) -> void:
	_time += delta
	if _water_light:
		_water_light.light_energy = 0.6 + 0.3 * sin(_time * 2.2)

func _build() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.34, 0.28)
	stone_mat.roughness = 0.90

	var moss_mat := StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.22, 0.42, 0.18)
	moss_mat.roughness = 0.95

	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.18, 0.52, 0.72, 0.85)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.05
	water_mat.metallic = 0.3
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.10, 0.40, 0.65)
	water_mat.emission_energy_multiplier = 0.35

	# Pedestal
	_add_cyl(Vector3(0, 0.55, 0), 0.22, 0.22, 1.1, stone_mat)
	# Basin outer rim — wide flat cylinder
	_add_cyl(Vector3(0, 1.18, 0), 0.95, 0.85, 0.26, stone_mat)
	# Basin inner (moss ring)
	_add_cyl(Vector3(0, 1.18, 0), 0.82, 0.72, 0.22, moss_mat)
	# Water surface
	_add_cyl(Vector3(0, 1.26, 0), 0.68, 0.68, 0.04, water_mat)
	# Base slab
	_add_cyl(Vector3(0, 0.06, 0), 0.60, 0.60, 0.12, stone_mat)

	# Water glow
	_water_light = OmniLight3D.new()
	_water_light.light_color = Color(0.20, 0.65, 0.90)
	_water_light.light_energy = 0.7
	_water_light.omni_range = 3.5
	_water_light.position = Vector3(0, 1.4, 0)
	add_child(_water_light)

	# Drip particles (simple upward + down cycle)
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 1.2
	p.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.18
	pm.gravity = Vector3(0, -0.5, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.04
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.3, 0.7, 1.0, 0.8))
	grad.add_point(1.0, Color(0.3, 0.7, 1.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.03
	drop_mesh.height = 0.06
	p.draw_pass_1 = drop_mesh
	p.position = Vector3(0, 1.3, 0)
	add_child(p)

	# Collision
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.96
	cyl.height = 1.4
	cs.shape = cyl
	cs.position = Vector3(0, 0.7, 0)
	body.add_child(cs)
	add_child(body)

	var lbl := Label3D.new()
	lbl.text = "Mossy Fountain"
	lbl.font_size = 24
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 1.9, 0)
	add_child(lbl)

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
