extends Node3D

@export var tree_scene: PackedScene
@export var tree_count: int = 30
@export var forest_radius: float = 80.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.6

func _ready():
	scatter_trees()

func scatter_trees():
	var i = 0
	while i < tree_count:
		var tree = tree_scene.instantiate()
		add_child(tree)
		
		var x = randf_range(-forest_radius, forest_radius)
		var z = randf_range(-forest_radius, forest_radius)
		tree.position = Vector3(x, 0, z)
		
		var tree_scale = randf_range(min_scale, max_scale)
		tree.scale = Vector3(tree_scale, tree_scale, tree_scale)
		
		tree.rotation.y = randf_range(0, TAU)
		i += 1
