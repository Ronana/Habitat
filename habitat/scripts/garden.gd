extends Node3D

@export var tree_scene: PackedScene
@export var tree_count: int = 30
@export var forest_radius: float = 80.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.6
@export var starter_area_size: float = 40.0
var base_ground_level: float = 0.0

var berry_bush_scene: PackedScene = preload("res://scenes/berry_bush.tscn")

func _ready():
	scatter_trees()
	create_boundary()
	create_starter_bumps()
	scatter_debris()
	plant_starting_bushes()
	give_starting_inventory()
	# Connect day night manager to scene lights
	var sun = get_node("DirectionalLight3D")
	var env = get_node("WorldEnvironment").environment
	DayNightManager.sun = sun
	DayNightManager.environment = env
	WeatherManager.environment = env
	WeatherManager.sun = sun
	WeatherManager.rain_particles = get_node("RainParticles")
	SeasonManager.environment = env
	SeasonManager.sun = sun
	
	# Try to load save
	var loaded = await SaveManager.load_game(self)
	if not loaded:
		print("Fresh wilderness — no save found")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Press F5 to save manually
		if event.keycode == KEY_F5:
			SaveManager.save_game(self)
		# Press F9 to load
		if event.keycode == KEY_F9:
			SaveManager.load_game(self)
		# Press 1-4 to force weather for testing
		if event.keycode == KEY_1:
			WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
		if event.keycode == KEY_2:
			WeatherManager.set_weather(WeatherManager.Weather.RAIN)
		if event.keycode == KEY_3:
			WeatherManager.set_weather(WeatherManager.Weather.FOG)
		if event.keycode == KEY_4:
			WeatherManager.set_weather(WeatherManager.Weather.WIND)
			# Press F1-F4 to force seasons for testing
		if event.keycode == KEY_F1:
			SeasonManager.current_season = SeasonManager.Season.SPRING
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F2:
			SeasonManager.current_season = SeasonManager.Season.SUMMER
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F3:
			SeasonManager.current_season = SeasonManager.Season.AUTUMN
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F4:
			SeasonManager.current_season = SeasonManager.Season.WINTER
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)

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

func create_boundary():
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color(0.85, 0.82, 0.75, 0.9)
	line_material.roughness = 1.0
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.no_depth_test = true
	line_material.render_priority = 1
	
	var half = starter_area_size / 2.0
	var lines = [
		[Vector3(0, 0.05, -half), Vector3(starter_area_size + 0.4, 0.05, 0.15)],
		[Vector3(0, 0.05, half), Vector3(starter_area_size + 0.4, 0.05, 0.15)],
		[Vector3(-half, 0.05, 0), Vector3(0.15, 0.05, starter_area_size)],
		[Vector3(half, 0.05, 0), Vector3(0.15, 0.05, starter_area_size)],
	]
	
	for line_data in lines:
		var mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = line_data[1]
		mesh_instance.mesh = box_mesh
		mesh_instance.position = line_data[0]
		var mat = line_material.duplicate()
		mesh_instance.set_surface_override_material(0, mat)
		mesh_instance.add_to_group("boundary_lines")
		add_child(mesh_instance)

func create_starter_bumps():
	var ground_node = get_node("Ground")
	var mdt = MeshDataTool.new()
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		ground_node.mesh.surface_get_arrays(0)
	)
	mdt.create_from_surface(array_mesh, 0)
	
	var half = starter_area_size / 2.0
	
	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		# Only bump vertices inside the starter area
		if abs(vertex.x) < half and abs(vertex.z) < half:
			# Random bumps above ground level
			vertex.y = randf_range(0.2, 1.5)
		mdt.set_vertex(i, vertex)
	
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)
	ground_node.mesh = array_mesh
	var mat = ground_node.get_active_material(0)
	if mat:
		ground_node.set_surface_override_material(0, mat)

	# Restore material after mesh rebuild
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.29, 0.36, 0.18)
	ground_mat.roughness = 0.9
	ground_node.set_surface_override_material(0, ground_mat)

	# Rebuild collision immediately from the bumped mesh so it's valid before
	# the first physics tick. tool_manager awaits 2 frames before rebuilding,
	# but _physics_process() fires in frame 1 — without this, roamers fall
	# through the empty ConcavePolygonShape3D that the scene starts with.
	var static_body = ground_node.get_node_or_null("StaticBody3D")
	if static_body:
		var col = static_body.get_node_or_null("CollisionShape3D")
		if col:
			col.shape = ground_node.mesh.create_trimesh_shape()
	

func scatter_debris():
	var half = starter_area_size / 2.0
	var debris_items = [
		{"name": "Rock", "colour": Color(0.45, 0.35, 0.25), "scale": Vector3(0.8, 0.4, 0.6), "mesh": "box", "reward": 5.0, "xp": 8.0},
		{"name": "Log", "colour": Color(0.35, 0.25, 0.15), "scale": Vector3(1.2, 0.3, 0.4), "mesh": "box", "reward": 8.0, "xp": 10.0},
		{"name": "SmallRock", "colour": Color(0.3, 0.28, 0.2), "scale": Vector3(0.5, 0.5, 0.5), "mesh": "sphere", "reward": 3.0, "xp": 5.0},
		{"name": "Stone", "colour": Color(0.4, 0.32, 0.22), "scale": Vector3(0.6, 0.35, 0.5), "mesh": "sphere", "reward": 4.0, "xp": 6.0},
	]
	
	for j in range(15):
		var item = debris_items[randi() % debris_items.size()]
		
		# Root node for the debris item
		var debris_node = StaticBody3D.new()
		debris_node.name = item["name"] + "_" + str(j)
		debris_node.add_to_group("debris")
		
		# Store reward data on the node
		debris_node.set_meta("dewdrop_reward", item["reward"])
		debris_node.set_meta("xp_reward", item["xp"])
		debris_node.set_meta("debris_name", item["name"])
		
		# Visual mesh
		var mesh_instance = MeshInstance3D.new()
		if item["mesh"] == "box":
			mesh_instance.mesh = BoxMesh.new()
		else:
			mesh_instance.mesh = SphereMesh.new()
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = item["colour"]
		mat.roughness = 1.0
		mesh_instance.set_surface_override_material(0, mat)
		debris_node.add_child(mesh_instance)
		
		# Collision shape
		var collision = CollisionShape3D.new()
		if item["mesh"] == "box":
			var box_shape = BoxShape3D.new()
			box_shape.size = item["scale"]
			collision.shape = box_shape
		else:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = item["scale"].x * 0.5
			collision.shape = sphere_shape
		debris_node.add_child(collision)
		
		# Position and transform
		var x = randf_range(-half + 3, half - 3)
		var z = randf_range(-half + 3, half - 3)
# Position and transform — apply scale to mesh only not the body
		debris_node.position = Vector3(x, 0.3, z)
		debris_node.rotation.y = randf_range(0, TAU)
		mesh_instance.scale = item["scale"]
		
		add_child(debris_node)
		
		
func plant_starting_bushes():
	# Three bushes spread around the starter area so roamers have immediate food.
	# Raycast down to terrain surface so each bush sits at the right height.
	var positions = [
		Vector3(5.0, 10.0, 3.0),
		Vector3(-6.0, 10.0, 5.0),
		Vector3(3.0, 10.0, -7.0),
	]
	var space_state = get_world_3d().direct_space_state
	for pos in positions:
		var query = PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -15, 0))
		var result = space_state.intersect_ray(query)
		var plant_y = result.position.y if result else 1.0
		var bush = berry_bush_scene.instantiate()
		add_child(bush)
		bush.global_position = Vector3(pos.x, plant_y, pos.z)

func give_starting_inventory():
	InventoryManager.add_item("Berry Seeds", 5)
	InventoryManager.add_item("Basic Shelter", 2)

func _process(_delta):
	update_boundary_heights()

func update_boundary_heights():
	var half = starter_area_size / 2.0
	var space_state = get_world_3d().direct_space_state
	
	var boundary_lines = get_tree().get_nodes_in_group("boundary_lines")
	for line in boundary_lines:
		# Cast ray down from above the line position
		var ray_origin = Vector3(line.position.x, 10.0, line.position.z)
		var ray_end = Vector3(line.position.x, -5.0, line.position.z)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		if result:
			line.position.y = result.position.y + 0.05
