## lantern_arch.gd — Torvald commission item.
## A wooden-and-iron arch hung with glowing lanterns.
## The centrepiece of any garden path.
extends Node3D

var item_type: String = "Lantern Arch"
var _time: float = 0.0
var _lantern_lights: Array = []

func _ready() -> void:
	add_to_group("torvald_builds")
	add_to_group("decoratives")
	add_to_group("lighting")
	_build()

func _process(delta: float) -> void:
	_time += delta
	# Gentle warm glow sway
	for i in range(_lantern_lights.size()):
		var light: OmniLight3D = _lantern_lights[i]
		if is_instance_valid(light):
			var offset := float(i) * 1.2
			light.light_energy = 1.1 + 0.25 * sin(_time * 1.4 + offset)

func _build() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.35, 0.22, 0.10)
	wood_mat.roughness = 0.88

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.17, 0.16)
	iron_mat.roughness = 0.75
	iron_mat.metallic = 0.6

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.95, 0.80, 0.30, 0.7)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(1.0, 0.75, 0.20)
	glass_mat.emission_energy_multiplier = 1.0

	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.14, 0.13, 0.12)
	cap_mat.roughness = 0.8
	cap_mat.metallic = 0.5

	# Left post
	_add_box(Vector3(-1.1, 1.8, 0), Vector3(0.22, 3.6, 0.22), wood_mat)
	# Right post
	_add_box(Vector3( 1.1, 1.8, 0), Vector3(0.22, 3.6, 0.22), wood_mat)
	# Left post base
	_add_box(Vector3(-1.1, 0.08, 0), Vector3(0.52, 0.16, 0.52), iron_mat)
	# Right post base
	_add_box(Vector3( 1.1, 0.08, 0), Vector3(0.52, 0.16, 0.52), iron_mat)

	# Horizontal top beam
	_add_box(Vector3(0, 3.68, 0), Vector3(2.55, 0.18, 0.22), wood_mat)
	# Top cap iron brackets
	_add_box(Vector3(-1.1, 3.72, 0), Vector3(0.32, 0.22, 0.30), iron_mat)
	_add_box(Vector3( 1.1, 3.72, 0), Vector3(0.32, 0.22, 0.30), iron_mat)

	# Decorative cross-brace (angled planks — approximated as thin boxes)
	_add_box(Vector3(-0.40, 2.6, 0), Vector3(0.10, 1.5, 0.18), wood_mat)
	_add_box(Vector3( 0.40, 2.6, 0), Vector3(0.10, 1.5, 0.18), wood_mat)

	# Three hanging lanterns on chains (chains = thin iron boxes)
	var lantern_x := [-0.75, 0.0, 0.75]
	var lantern_y := [3.20, 3.0, 3.20]  # centre hangs lower
	for i in range(3):
		var lx: float = lantern_x[i]
		var ly: float = lantern_y[i]
		# Chain
		_add_box(Vector3(lx, ly + 0.24, 0), Vector3(0.03, 0.28, 0.03), iron_mat)
		# Lantern body (glass)
		_add_box(Vector3(lx, ly, 0), Vector3(0.22, 0.35, 0.22), glass_mat)
		# Lantern top cap
		_add_box(Vector3(lx, ly + 0.20, 0), Vector3(0.26, 0.08, 0.26), cap_mat)
		# Lantern bottom cap
		_add_box(Vector3(lx, ly - 0.20, 0), Vector3(0.20, 0.06, 0.20), cap_mat)
		# Iron frame strips
		_add_box(Vector3(lx - 0.11, ly, 0), Vector3(0.02, 0.34, 0.24), iron_mat)
		_add_box(Vector3(lx + 0.11, ly, 0), Vector3(0.02, 0.34, 0.24), iron_mat)

		# Light source inside lantern
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.80, 0.32)
		light.light_energy = 1.2
		light.omni_range = 3.8
		light.position = Vector3(lx, ly, 0)
		add_child(light)
		_lantern_lights.append(light)

	# Hanging ivy detail on posts (green thin strips)
	var ivy_mat := StandardMaterial3D.new()
	ivy_mat.albedo_color = Color(0.20, 0.42, 0.14)
	ivy_mat.roughness = 0.95
	_add_box(Vector3(-1.0, 2.2, 0.12), Vector3(0.08, 1.4, 0.06), ivy_mat)
	_add_box(Vector3( 1.12, 1.8, 0.12), Vector3(0.08, 1.0, 0.06), ivy_mat)
	_add_box(Vector3(-1.12, 0.9, -0.12), Vector3(0.06, 0.6, 0.08), ivy_mat)

	# Collision: two posts + beam
	var body := StaticBody3D.new()
	for pos_x in [-1.1, 1.1]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.28, 3.7, 0.28)
		cs.shape = box
		cs.position = Vector3(pos_x, 1.85, 0)
		body.add_child(cs)
	var cs_top := CollisionShape3D.new()
	var box_top := BoxShape3D.new()
	box_top.size = Vector3(2.6, 0.24, 0.28)
	cs_top.shape = box_top
	cs_top.position = Vector3(0, 3.68, 0)
	body.add_child(cs_top)
	add_child(body)

	var lbl := Label3D.new()
	lbl.text = "Lantern Arch"
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
