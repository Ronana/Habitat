extends Node3D

# Season colours: [canopy_colour, canopy_scale_y]
const SEASON_COLOURS = {
	0: [Color(0.22, 0.50, 0.15, 1), 1.00],  # Spring — fresh light green
	1: [Color(0.14, 0.36, 0.09, 1), 1.00],  # Summer — rich dark green
	2: [Color(0.62, 0.36, 0.08, 1), 0.90],  # Autumn — warm amber orange
	3: [Color(0.28, 0.24, 0.20, 1), 0.60],  # Winter — sparse bare branches
}

func _ready():
	SeasonManager.season_changed.connect(_on_season_changed)
	_apply_season(SeasonManager.current_season)

func _on_season_changed(season: int):
	_apply_season(season)

func _apply_season(season: int):
	var data = SEASON_COLOURS.get(season, SEASON_COLOURS[0])
	var colour: Color = data[0]
	var scale_y: float = data[1]
	_set_mesh_colour($Canopy, colour)
	# Shrink canopy in winter to look bare, restore in spring
	var base_scale = $Canopy.scale
	$Canopy.scale = Vector3(base_scale.x, scale_y, base_scale.z)

func _set_mesh_colour(node: MeshInstance3D, colour: Color):
	var mat: StandardMaterial3D = node.get_surface_override_material(0)
	if mat == null:
		mat = node.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	else:
		mat = mat.duplicate() as StandardMaterial3D
	mat.albedo_color = colour
	node.set_surface_override_material(0, mat)
