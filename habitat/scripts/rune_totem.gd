## rune_totem.gd — Torvald commission item.
## A tall carved standing stone pulsing with ancient rune light.
extends Node3D

var item_type: String = "Rune Totem"
var _time: float = 0.0
var _rune_lights: Array = []

func _ready() -> void:
	add_to_group("torvald_builds")
	add_to_group("decoratives")
	add_to_group("lighting")
	_build()

func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 1.8)
	for light in _rune_lights:
		if is_instance_valid(light):
			light.light_energy = 0.8 + pulse * 0.7

func _build() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.28, 0.25, 0.22)
	stone_mat.roughness = 0.95

	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.40, 0.75, 0.60)
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.25, 0.90, 0.55)
	rune_mat.emission_energy_multiplier = 1.2
	rune_mat.roughness = 0.3

	# Main stone shaft — slightly tapered look via stacked boxes
	_add_box(Vector3(0, 1.5,  0), Vector3(0.55, 3.0, 0.42), stone_mat)
	_add_box(Vector3(0, 3.1,  0), Vector3(0.48, 0.4, 0.36), stone_mat)  # cap
	# Base slab
	_add_box(Vector3(0, 0.08, 0), Vector3(0.85, 0.16, 0.72), stone_mat)

	# Rune stripe panels on the stone face
	_add_box(Vector3(0.22, 1.5, 0), Vector3(0.06, 2.4, 0.44), rune_mat)
	_add_box(Vector3(-0.22, 0.9, 0), Vector3(0.06, 1.2, 0.44), rune_mat)
	_add_box(Vector3(0, 2.4, 0.22), Vector3(0.50, 0.8, 0.06), rune_mat)

	# Glowing OmniLight
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 1.0, 0.60)
	light.light_energy = 1.2
	light.omni_range = 4.5
	light.position = Vector3(0, 2.2, 0)
	add_child(light)
	_rune_lights.append(light)

	# Collision
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 3.3, 0.5)
	cs.shape = box
	cs.position = Vector3(0, 1.65, 0)
	body.add_child(cs)
	add_child(body)

	var lbl := Label3D.new()
	lbl.text = "Rune Totem"
	lbl.font_size = 24
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 3.7, 0)
	add_child(lbl)

func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)
