extends Node3D

var food_value: float = 0.3
var eat_cooldown: float = 3.0
var cooldown_timer: float = 0.0
var is_depleted: bool = false
var eat_count: int = 0
var max_eats: int = 5
var regrow_time: float = 20.0
var regrow_timer: float = 0.0

# Season colours: [bush_colour, berry_colour]
const SEASON_COLOURS = {
	0: [Color(0.22, 0.46, 0.14, 1), Color(0.80, 0.40, 0.55, 1)],  # Spring — fresh green, pink blossom
	1: [Color(0.15, 0.38, 0.10, 1), Color(0.55, 0.10, 0.10, 1)],  # Summer — rich green, deep red
	2: [Color(0.52, 0.34, 0.10, 1), Color(0.65, 0.22, 0.08, 1)],  # Autumn — amber, burnt orange
	3: [Color(0.28, 0.24, 0.18, 1), Color(0.30, 0.26, 0.22, 1)],  # Winter — bare grey-brown
}

func _ready():
	add_to_group("food")
	$FoodArea.body_entered.connect(_on_body_entered)
	SeasonManager.season_changed.connect(_on_season_changed)
	_apply_season_colours(SeasonManager.current_season)

func _on_season_changed(season: int):
	_apply_season_colours(season)

func _apply_season_colours(season: int):
	var colours = SEASON_COLOURS.get(season, SEASON_COLOURS[0])
	_tint_all_meshes($Bush, colours[0])     # gltf root — walk its children
	_set_mesh_colour($Berries, colours[1])  # direct MeshInstance3D

# Recursively tint all MeshInstance3D nodes inside a node hierarchy.
# Needed because gltf assets import as Node3D with MeshInstance3D children.
func _tint_all_meshes(node: Node, colour: Color) -> void:
	if node is MeshInstance3D:
		_set_mesh_colour(node as MeshInstance3D, colour)
	for child in node.get_children():
		_tint_all_meshes(child, colour)

func _set_mesh_colour(node: MeshInstance3D, colour: Color):
	var mat: StandardMaterial3D = node.get_surface_override_material(0)
	if mat == null:
		var base = node.mesh.surface_get_material(0) if node.mesh else null
		mat = (base.duplicate() as StandardMaterial3D) if base is StandardMaterial3D else StandardMaterial3D.new()
	else:
		mat = mat.duplicate() as StandardMaterial3D
	mat.albedo_color = colour
	node.set_surface_override_material(0, mat)

func _process(delta):
	if cooldown_timer > 0:
		cooldown_timer -= delta

	if is_depleted:
		regrow_timer += delta
		if regrow_timer >= regrow_time:
			regrow()

func _on_body_entered(body):
	if is_depleted or cooldown_timer > 0:
		return
	var node = body
	while node:
		if node.is_in_group("roamers"):
			feed_roamer(node)
			return
		node = node.get_parent()

func feed_roamer(roamer):
	roamer.feed(food_value)
	cooldown_timer = eat_cooldown
	eat_count += 1
	if eat_count >= max_eats:
		deplete()

func deplete():
	is_depleted = true
	regrow_timer = 0.0
	$Berries.visible = false

func regrow():
	is_depleted = false
	eat_count = 0
	$Berries.visible = true
