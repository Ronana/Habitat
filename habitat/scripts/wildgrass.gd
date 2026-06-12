## wildgrass.gd — planted wildgrass clump.
## Gently sways in the wind and responds to season colour changes.
extends Node3D

const SWAY_SPEED  := 1.15
const SWAY_Z      := 0.055   # max Z-axis tilt (radians)
const SWAY_X      := 0.028   # max X-axis tilt

# Season colours: [darker_blade, lighter_blade]
const SEASON_COLOURS: Array = [
	[Color(0.32, 0.60, 0.18), Color(0.45, 0.74, 0.26)],  # Spring — fresh greens
	[Color(0.18, 0.48, 0.10), Color(0.32, 0.62, 0.18)],  # Summer — deep green
	[Color(0.56, 0.44, 0.14), Color(0.68, 0.54, 0.20)],  # Autumn — amber tones
	[Color(0.26, 0.30, 0.20), Color(0.34, 0.38, 0.26)],  # Winter — muted sage
]

var _time  : float = 0.0
var _phase : float = 0.0

# Cache the three distinct materials so we can colour them per-season
var _mat_a : StandardMaterial3D = null
var _mat_b : StandardMaterial3D = null
var _mat_c : StandardMaterial3D = null

func _ready() -> void:
	# Random phase so nearby clumps don't sway identically
	_phase = randf() * TAU

	# Create fresh materials — don't read from the shared mesh resource,
	# as surface_get_material(0) returns null on SubResource meshes at runtime.
	_mat_a = StandardMaterial3D.new()
	_mat_a.roughness = 0.90
	_mat_b = StandardMaterial3D.new()
	_mat_b.roughness = 0.90
	_mat_c = StandardMaterial3D.new()
	_mat_c.roughness = 0.92
	_apply_mats_to_blades()

	# Season response
	SeasonManager.season_changed.connect(_on_season_changed)
	_apply_season(SeasonManager.current_season)

func _process(delta: float) -> void:
	_time += delta
	# Gentle two-axis sway of the whole clump
	rotation.z = sin(_time * SWAY_SPEED         + _phase) * SWAY_Z
	rotation.x = sin(_time * SWAY_SPEED * 0.79  + _phase + 1.4) * SWAY_X

func _apply_mats_to_blades() -> void:
	# A-material (dark): blades 1, 3, 5
	for name: String in ["Blade1", "Blade3", "Blade5"]:
		var node: MeshInstance3D = get_node_or_null(name) as MeshInstance3D
		if node and _mat_a:
			node.set_surface_override_material(0, _mat_a)
	# B-material (bright): blades 2, 4, 7
	for name: String in ["Blade2", "Blade4", "Blade7"]:
		var node: MeshInstance3D = get_node_or_null(name) as MeshInstance3D
		if node and _mat_b:
			node.set_surface_override_material(0, _mat_b)
	# C-material (mid): blades 6, 8
	for name: String in ["Blade6", "Blade8"]:
		var node: MeshInstance3D = get_node_or_null(name) as MeshInstance3D
		if node and _mat_c:
			node.set_surface_override_material(0, _mat_c)

func _on_season_changed(season: int) -> void:
	_apply_season(season)

func _apply_season(season: int) -> void:
	var cols: Array = SEASON_COLOURS[clamp(season, 0, SEASON_COLOURS.size() - 1)]
	var dark: Color   = cols[0]
	var light: Color  = cols[1]
	var mid: Color    = dark.lerp(light, 0.5)

	if _mat_a:
		_mat_a.albedo_color = dark
	if _mat_b:
		_mat_b.albedo_color = light
	if _mat_c:
		_mat_c.albedo_color = mid
