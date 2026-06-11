extends Node3D

func _ready():
	add_to_group("decoratives")
	_build()

func _build():
	# Base rock — flattened irregular sphere
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.38, 0.32)
	rock_mat.roughness = 0.95

	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.38
	rock_mesh.height = 0.52
	var rock_mi := MeshInstance3D.new()
	rock_mi.mesh = rock_mesh
	rock_mi.set_surface_override_material(0, rock_mat)
	# Squish flat and randomise rotation slightly so no two look identical
	rock_mi.scale = Vector3(1.0 + randf_range(-0.15, 0.15), 0.55, 1.0 + randf_range(-0.15, 0.15))
	rock_mi.rotation.y = randf_range(0.0, TAU)
	rock_mi.position.y = 0.18
	add_child(rock_mi)

	# Moss patches — a few small squished green spheres sitting on top
	var moss_mat := StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.22, 0.52, 0.18)
	moss_mat.roughness = 0.90

	var patch_count := 3 + randi() % 3
	for i in range(patch_count):
		var angle := (float(i) / patch_count) * TAU + randf_range(-0.4, 0.4)
		var r := randf_range(0.08, 0.28)
		var patch_mesh := SphereMesh.new()
		patch_mesh.radius = randf_range(0.06, 0.12)
		patch_mesh.height = patch_mesh.radius * 1.8
		var patch_mi := MeshInstance3D.new()
		patch_mi.mesh = patch_mesh
		patch_mi.set_surface_override_material(0, moss_mat)
		patch_mi.scale = Vector3(1.0, 0.45, 1.0)
		patch_mi.position = Vector3(
			cos(angle) * r,
			0.30 + randf_range(0.0, 0.08),
			sin(angle) * r
		)
		add_child(patch_mi)
