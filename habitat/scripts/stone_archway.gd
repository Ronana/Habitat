## stone_archway.gd — Torvald commission item.
## A grand stone archway with carved rune accents.
extends Node3D

var item_type: String = "Stone Archway"

func _ready() -> void:
	add_to_group("torvald_builds")
	add_to_group("decoratives")
	_build()

func _build() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.42, 0.38, 0.32)
	stone_mat.roughness = 0.92

	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.30, 0.55, 0.70)
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.20, 0.45, 0.85)
	rune_mat.emission_energy_multiplier = 0.6
	rune_mat.roughness = 0.4

	# Left pillar
	_add_box(Vector3(-1.2, 1.6, 0), Vector3(0.55, 3.2, 0.55), stone_mat)
	# Right pillar
	_add_box(Vector3( 1.2, 1.6, 0), Vector3(0.55, 3.2, 0.55), stone_mat)
	# Arch beam across the top
	_add_box(Vector3(0, 3.35, 0), Vector3(2.8, 0.45, 0.55), stone_mat)
	# Keystone accent
	_add_box(Vector3(0, 3.65, 0), Vector3(0.45, 0.55, 0.60), rune_mat)
	# Pillar rune strips
	_add_box(Vector3(-1.2, 1.6, 0.28), Vector3(0.12, 2.4, 0.04), rune_mat)
	_add_box(Vector3( 1.2, 1.6, 0.28), Vector3(0.12, 2.4, 0.04), rune_mat)

	# Ground base slabs
	_add_box(Vector3(-1.2, 0.07, 0), Vector3(0.9, 0.14, 0.9), stone_mat)
	_add_box(Vector3( 1.2, 0.07, 0), Vector3(0.9, 0.14, 0.9), stone_mat)

	# Collision
	var body := StaticBody3D.new()
	var cs_l := CollisionShape3D.new()
	var cs_r := CollisionShape3D.new()
	var cs_t := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 3.4, 0.6)
	cs_l.shape = box; cs_l.position = Vector3(-1.2, 1.7, 0)
	cs_r.shape = box; cs_r.position = Vector3( 1.2, 1.7, 0)
	var box_t := BoxShape3D.new()
	box_t.size = Vector3(3.0, 0.5, 0.6)
	cs_t.shape = box_t; cs_t.position = Vector3(0, 3.35, 0)
	body.add_child(cs_l)
	body.add_child(cs_r)
	body.add_child(cs_t)
	add_child(body)

	# Label
	var lbl := Label3D.new()
	lbl.text = "Stone Archway"
	lbl.font_size = 24
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 4.3, 0)
	add_child(lbl)

func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)
