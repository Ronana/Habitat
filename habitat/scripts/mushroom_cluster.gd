extends Node3D

# A cluster of 3-4 mushrooms in earthy autumn colours
const CAP_COLOURS: Array = [
	Color(0.62, 0.28, 0.12),  # burnt sienna
	Color(0.50, 0.38, 0.20),  # tan brown
	Color(0.72, 0.20, 0.12),  # deep red-brown
	Color(0.85, 0.65, 0.30),  # warm ochre
]

func _ready():
	add_to_group("decoratives")
	_build()

func _build():
	var stalk_mat := StandardMaterial3D.new()
	stalk_mat.albedo_color = Color(0.88, 0.80, 0.62)
	stalk_mat.roughness = 0.9

	var count := 3 + randi() % 2
	for i in range(count):
		var angle := (float(i) / count) * TAU + randf_range(-0.4, 0.4)
		var dist  := randf_range(0.05, 0.28)
		var x     := cos(angle) * dist
		var z     := sin(angle) * dist
		var h     := randf_range(0.14, 0.30)  # stalk height
		var cap_r := randf_range(0.09, 0.18)

		# Stalk
		var stalk_mesh := CylinderMesh.new()
		stalk_mesh.top_radius    = cap_r * 0.35
		stalk_mesh.bottom_radius = cap_r * 0.28
		stalk_mesh.height        = h
		var stalk_mi := MeshInstance3D.new()
		stalk_mi.mesh = stalk_mesh
		stalk_mi.set_surface_override_material(0, stalk_mat)
		stalk_mi.position = Vector3(x, h * 0.5, z)
		add_child(stalk_mi)

		# Cap
		var cap_mat := StandardMaterial3D.new()
		cap_mat.albedo_color = CAP_COLOURS[i % CAP_COLOURS.size()]
		cap_mat.roughness = 0.75
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = cap_r
		cap_mesh.height = cap_r * 1.6
		var cap_mi := MeshInstance3D.new()
		cap_mi.mesh = cap_mesh
		cap_mi.set_surface_override_material(0, cap_mat)
		cap_mi.position = Vector3(x, h + cap_r * 0.4, z)
		cap_mi.scale = Vector3(1.0, 0.65, 1.0)
		add_child(cap_mi)

		# Underside gills — slightly lighter disc
		var gill_mat := StandardMaterial3D.new()
		gill_mat.albedo_color = Color(0.88, 0.76, 0.58)
		gill_mat.roughness = 0.85
		var gill_mesh := CylinderMesh.new()
		gill_mesh.top_radius    = cap_r * 0.9
		gill_mesh.bottom_radius = cap_r * 0.6
		gill_mesh.height        = 0.01
		var gill_mi := MeshInstance3D.new()
		gill_mi.mesh = gill_mesh
		gill_mi.set_surface_override_material(0, gill_mat)
		gill_mi.position = Vector3(x, h + cap_r * 0.04, z)
		add_child(gill_mi)
