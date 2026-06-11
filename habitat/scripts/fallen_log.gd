extends Node3D

func _ready():
	add_to_group("decoratives")
	_build()

func _build():
	# Main log body — cylinder lying on its side
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.36, 0.22, 0.12)
	bark_mat.roughness = 0.95

	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius    = 0.18
	log_mesh.bottom_radius = 0.20
	log_mesh.height        = 0.90
	var log_mi := MeshInstance3D.new()
	log_mi.mesh = log_mesh
	log_mi.set_surface_override_material(0, bark_mat)
	# Rotate to lie on its side and add a bit of rotation for variety
	log_mi.rotation.z = PI * 0.5
	log_mi.rotation.y = randf_range(0.0, TAU)
	log_mi.position.y = 0.19
	add_child(log_mi)

	# Wood-end caps (flat circles at each end)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.50, 0.30, 0.16)
	wood_mat.roughness = 0.85

	for end_sign in [-1.0, 1.0]:
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius    = 0.19
		cap_mesh.bottom_radius = 0.19
		cap_mesh.height        = 0.03
		var cap_mi := MeshInstance3D.new()
		cap_mi.mesh = cap_mesh
		cap_mi.set_surface_override_material(0, wood_mat)
		cap_mi.rotation.z = PI * 0.5
		# Offset along the log's local X axis (world Z after rotation)
		cap_mi.position = Vector3(0.0, 0.19, end_sign * 0.45)
		add_child(cap_mi)

	# Moss strips along the top — a couple of small green squished spheres
	var moss_mat := StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.24, 0.52, 0.16)
	moss_mat.roughness = 0.90

	for i in range(3):
		var t := (float(i) - 1.0) * 0.28
		var moss_mesh := SphereMesh.new()
		moss_mesh.radius = 0.08
		moss_mesh.height = 0.12
		var moss_mi := MeshInstance3D.new()
		moss_mi.mesh = moss_mesh
		moss_mi.set_surface_override_material(0, moss_mat)
		moss_mi.scale = Vector3(1.2, 0.45, 0.9)
		moss_mi.position = Vector3(0.0, 0.37, t)
		add_child(moss_mi)
