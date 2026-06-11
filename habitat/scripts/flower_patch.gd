extends Node3D

# Colours cycle through a soft garden palette
const PETAL_COLOURS: Array = [
	Color(0.95, 0.40, 0.65),  # pink
	Color(0.95, 0.85, 0.25),  # yellow
	Color(0.85, 0.55, 0.90),  # lilac
	Color(1.00, 0.95, 0.90),  # cream-white
	Color(0.45, 0.75, 0.95),  # sky-blue
]

func _ready():
	add_to_group("decoratives")
	_build()

func _build():
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.22, 0.55, 0.12)
	stem_mat.roughness = 0.85

	# Spawn 4-6 flowers in a loose cluster
	var count := 4 + randi() % 3
	for i in range(count):
		var angle := (float(i) / count) * TAU + randf_range(-0.3, 0.3)
		var radius := randf_range(0.12, 0.38)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := randf_range(0.14, 0.22)

		# Stem
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius    = 0.012
		stem_mesh.bottom_radius = 0.018
		stem_mesh.height        = height
		var stem_mi := MeshInstance3D.new()
		stem_mi.mesh = stem_mesh
		stem_mi.set_surface_override_material(0, stem_mat)
		stem_mi.position = Vector3(x, height * 0.5, z)
		add_child(stem_mi)

		# Petal bloom — squished sphere
		var petal_mat := StandardMaterial3D.new()
		petal_mat.albedo_color = PETAL_COLOURS[i % PETAL_COLOURS.size()]
		petal_mat.roughness = 0.6
		petal_mat.emission_enabled = true
		petal_mat.emission = petal_mat.albedo_color
		petal_mat.emission_energy_multiplier = 0.12

		var bloom_mesh := SphereMesh.new()
		bloom_mesh.radius = 0.07
		bloom_mesh.height = 0.10
		var bloom_mi := MeshInstance3D.new()
		bloom_mi.mesh = bloom_mesh
		bloom_mi.set_surface_override_material(0, petal_mat)
		bloom_mi.position = Vector3(x, height + 0.05, z)
		bloom_mi.scale = Vector3(1.0, 0.55, 1.0)
		add_child(bloom_mi)

		# Tiny yellow centre
		var centre_mat := StandardMaterial3D.new()
		centre_mat.albedo_color = Color(0.98, 0.88, 0.15)
		centre_mat.roughness = 0.5
		var centre_mesh := SphereMesh.new()
		centre_mesh.radius = 0.028
		centre_mesh.height = 0.042
		var centre_mi := MeshInstance3D.new()
		centre_mi.mesh = centre_mesh
		centre_mi.set_surface_override_material(0, centre_mat)
		centre_mi.position = Vector3(x, height + 0.09, z)
		add_child(centre_mi)
