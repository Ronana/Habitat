extends Node3D
## Decorative fence panel — 1 unit wide, VP-style segment-by-segment placement.
## Procedural mesh: two wooden posts + two horizontal rails + three pickets.
## Added to "decoratives" (save/load) and "fences" (placement clearance) groups.

const WOOD_COLOUR   : Color = Color(0.52, 0.33, 0.16)
const POST_COLOUR   : Color = Color(0.45, 0.28, 0.12)

var _static_body : StaticBody3D = null
var _meshes      : Array        = []

func _ready() -> void:
	add_to_group("decoratives")
	add_to_group("fences")
	add_to_group("placeable_items")
	_build_mesh()
	_build_collision()
	_add_health_hearts()

# ── Mesh construction ─────────────────────────────────────────────────────────

func _build_mesh() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = WOOD_COLOUR
	wood_mat.roughness    = 0.88
	wood_mat.metallic     = 0.0

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = POST_COLOUR
	post_mat.roughness    = 0.90
	post_mat.metallic     = 0.0

	# ── Two end posts ─────────────────────────────────────────────────────────
	for px in [-0.46, 0.46]:
		var post := _make_box(Vector3(0.09, 0.88, 0.09), post_mat)
		post.position = Vector3(px, 0.44, 0.0)
		add_child(post)
		_meshes.append(post)

	# ── Top rail ──────────────────────────────────────────────────────────────
	var top_rail := _make_box(Vector3(0.84, 0.07, 0.07), wood_mat)
	top_rail.position = Vector3(0.0, 0.74, 0.0)
	add_child(top_rail)
	_meshes.append(top_rail)

	# ── Bottom rail ───────────────────────────────────────────────────────────
	var bot_rail := _make_box(Vector3(0.84, 0.07, 0.07), wood_mat)
	bot_rail.position = Vector3(0.0, 0.26, 0.0)
	add_child(bot_rail)
	_meshes.append(bot_rail)

	# ── Three vertical pickets ────────────────────────────────────────────────
	for px in [-0.23, 0.0, 0.23]:
		var picket := _make_box(Vector3(0.065, 0.55, 0.065), wood_mat)
		picket.position = Vector3(px, 0.50, 0.0)
		add_child(picket)
		_meshes.append(picket)

func _make_box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size  = size
	mi.mesh  = bm
	mi.set_surface_override_material(0, mat.duplicate())
	return mi

# ── Collision (for cursor raycast + item_health) ──────────────────────────────

func _build_collision() -> void:
	_static_body = StaticBody3D.new()
	_static_body.name = "FenceCollision"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size  = Vector3(1.0, 0.9, 0.12)
	col.shape  = box
	col.position = Vector3(0, 0.45, 0)
	_static_body.add_child(col)
	add_child(_static_body)

# ── Health hearts ─────────────────────────────────────────────────────────────

func _add_health_hearts() -> void:
	var ih_script := load("res://scripts/item_health.gd")
	if ih_script:
		var ih: Node = ih_script.new()
		ih.name = "ItemHealth"
		add_child(ih)

# ── Public helpers ────────────────────────────────────────────────────────────

func get_type() -> String:
	return "Fence Panel"
