## ground_fog.gd
## Spawns a low-lying ground fog volume over the garden.
## Add as a child of the garden root node (or any Node3D in the scene).
## Works at both runtime and in the editor (@tool).
@tool
extends Node3D

@export var fog_half_size   : Vector3 = Vector3(22.0, 1.8, 22.0)  # covers the garden + a bit
@export var fog_height      : float   = 0.6    # centre height above ground
@export var fog_density     : float   = 8.0    # local density — higher = thicker
@export var fog_albedo      : Color   = Color(0.65, 0.75, 1.00)   # blue-white mist
@export var fog_emission    : Color   = Color(0.06, 0.08, 0.22)   # subtle bioluminescent tint
@export var fog_emission_energy : float = 0.5

var _volume : FogVolume

func _ready() -> void:
	_build()

func _build() -> void:
	# Remove any previous volume so re-running @tool doesn't duplicate
	if is_instance_valid(_volume):
		_volume.queue_free()

	# FogMaterial
	var mat := FogMaterial.new()
	mat.density        = fog_density
	mat.albedo         = fog_albedo
	mat.emission       = fog_emission * fog_emission_energy
	mat.height_falloff = 3.5   # fade out quickly above fog_height

	# FogVolume — box shape covering the garden floor
	_volume                    = FogVolume.new()
	_volume.name               = "GroundFogVolume"
	_volume.size               = fog_half_size * 2.0
	_volume.shape              = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_volume.material           = mat
	_volume.position           = Vector3(0.0, fog_height, 0.0)

	add_child(_volume)
	if Engine.is_editor_hint():
		_volume.set_owner(get_tree().edited_scene_root)
