## stone_bench.gd — Torvald commission item.
## A grand carved stone bench. Roamers idle nearby.
extends Node3D

var item_type: String = "Stone Bench"

func _ready() -> void:
	add_to_group("torvald_builds")
	add_to_group("decoratives")
	_build()

func _build() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.50, 0.46, 0.40)
	stone_mat.roughness = 0.88

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.32, 0.28, 0.24)
	dark_mat.roughness = 0.92

	var moss_mat := StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.24, 0.44, 0.16)
	moss_mat.roughness = 0.96

	# Seat slab
	_add_box(Vector3(0, 0.55, 0), Vector3(1.8, 0.14, 0.60), stone_mat)
	# Left leg
	_add_box(Vector3(-0.72, 0.26, 0), Vector3(0.26, 0.52, 0.55), dark_mat)
	# Right leg
	_add_box(Vector3( 0.72, 0.26, 0), Vector3(0.26, 0.52, 0.55), dark_mat)
	# Centre support
	_add_box(Vector3(0, 0.26, 0), Vector3(0.20, 0.52, 0.55), dark_mat)
	# Back rest
	_add_box(Vector3(0, 0.95, -0.24), Vector3(1.8, 0.72, 0.14), stone_mat)
	# Backrest cap
	_add_box(Vector3(0, 1.34, -0.24), Vector3(1.9, 0.10, 0.20), stone_mat)
	# Decorative carved end panels
	_add_box(Vector3(-0.90, 0.80, -0.10), Vector3(0.10, 0.60, 0.40), dark_mat)
	_add_box(Vector3( 0.90, 0.80, -0.10), Vector3(0.10, 0.60, 0.40), dark_mat)
	# Moss patches on top
	_add_box(Vector3(-0.55, 0.63, 0.10), Vector3(0.28, 0.04, 0.22), moss_mat)
	_add_box(Vector3( 0.40, 0.63, -0.05), Vector3(0.20, 0.04, 0.18), moss_mat)

	# Collision
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.5, 0.7)
	cs.shape = box
	cs.position = Vector3(0, 0.75, -0.05)
	body.add_child(cs)
	add_child(body)

	var lbl := Label3D.new()
	lbl.text = "Stone Bench"
	lbl.font_size = 24
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 1.8, 0)
	add_child(lbl)

func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)
