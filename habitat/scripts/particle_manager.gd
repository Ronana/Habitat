extends Node

# Spawns one-shot and looping particle effects without any external resources.
# All particle materials are built in code.

# ── Bond sparkle burst ────────────────────────────────────────────────────────
func spawn_bond_sparkle(world_pos: Vector3):
	var particles := GPUParticles3D.new()
	particles.emitting      = true
	particles.one_shot      = true
	particles.explosiveness = 0.95
	particles.amount        = 48
	particles.lifetime      = 1.6
	particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))

	var mat := ParticleProcessMaterial.new()
	mat.direction            = Vector3(0, 1, 0)
	mat.spread               = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity              = Vector3(0, -1.5, 0)
	mat.scale_min            = 0.06
	mat.scale_max            = 0.14
	mat.color                = Color(0.85, 1.0, 0.50, 1.0)
	# Fade out over lifetime
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 1.0, 0.6, 1.0))
	grad.add_point(0.7, Color(0.6, 1.0, 0.4, 0.8))
	grad.add_point(1.0, Color(0.4, 0.8, 0.3, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	particles.process_material = mat

	var mesh_inst := SphereMesh.new()
	mesh_inst.radius = 0.08
	mesh_inst.height = 0.16
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color         = Color(0.9, 1.0, 0.5, 1.0)
	draw_mat.emission_enabled     = true
	draw_mat.emission             = Color(0.7, 1.0, 0.3, 1.0)
	draw_mat.emission_energy_multiplier = 1.2
	draw_mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material            = draw_mat
	particles.draw_pass_1         = mesh_inst

	get_tree().get_root().add_child(particles)
	particles.global_position = world_pos + Vector3(0, 0.8, 0)

	# Auto-free after effect finishes
	await get_tree().create_timer(particles.lifetime + 0.5).timeout
	particles.queue_free()

# ── Floating dewdrop aura (looping, attached to roamer) ──────────────────────
func attach_dewdrop_aura(parent: Node3D) -> GPUParticles3D:
	# Don't add duplicates
	if parent.has_node("DewdropAura"):
		return parent.get_node("DewdropAura") as GPUParticles3D

	var particles := GPUParticles3D.new()
	particles.name          = "DewdropAura"
	particles.emitting      = true
	particles.one_shot      = false
	particles.amount        = 12
	particles.lifetime      = 3.0
	particles.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 4, 4))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape       = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.6
	mat.direction            = Vector3(0, 1, 0)
	mat.spread               = 20.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8
	mat.gravity              = Vector3(0, 0.05, 0)
	mat.scale_min            = 0.04
	mat.scale_max            = 0.09
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.5, 0.9, 1.0, 0.0))
	grad.add_point(0.3, Color(0.6, 0.95, 1.0, 0.9))
	grad.add_point(1.0, Color(0.4, 0.7,  0.9, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	particles.process_material = mat

	var mesh_inst := SphereMesh.new()
	mesh_inst.radius = 0.06
	mesh_inst.height = 0.12
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color         = Color(0.5, 0.9, 1.0, 0.85)
	draw_mat.emission_enabled     = true
	draw_mat.emission             = Color(0.3, 0.7, 1.0, 1.0)
	draw_mat.emission_energy_multiplier = 0.8
	draw_mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material            = draw_mat
	particles.draw_pass_1         = mesh_inst

	parent.add_child(particles)
	particles.position = Vector3(0, 0.5, 0)
	return particles

# ── Leaf drift (weather/season ambient) ──────────────────────────────────────
func spawn_leaf_drift(world_pos: Vector3):
	# Spawn a short burst of drifting leaves at a position
	var particles := GPUParticles3D.new()
	particles.emitting      = true
	particles.one_shot      = true
	particles.explosiveness = 0.0
	particles.amount        = 16
	particles.lifetime      = 4.0
	particles.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))

	var mat := ParticleProcessMaterial.new()
	mat.direction            = Vector3(1, 0.3, 0.2)
	mat.spread               = 40.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 2.2
	mat.gravity              = Vector3(0.2, -0.4, 0.1)
	mat.scale_min            = 0.06
	mat.scale_max            = 0.12
	# Autumn colour range
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.82, 0.45, 0.10, 0.9))
	grad.add_point(0.5, Color(0.70, 0.32, 0.08, 0.7))
	grad.add_point(1.0, Color(0.50, 0.22, 0.05, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	particles.process_material = mat

	var mesh_inst := SphereMesh.new()
	mesh_inst.radius = 0.08
	mesh_inst.height = 0.04  # Flat disc to suggest a leaf
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.75, 0.38, 0.08, 0.85)
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material    = draw_mat
	particles.draw_pass_1 = mesh_inst

	get_tree().get_root().add_child(particles)
	particles.global_position = world_pos

	await get_tree().create_timer(particles.lifetime + 0.3).timeout
	particles.queue_free()
