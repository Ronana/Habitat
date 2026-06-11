extends Node3D

@export var tree_scene: PackedScene
@export var tree_count: int = 30
@export var forest_radius: float = 80.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.6
@export var starter_area_size: float = 40.0
var base_ground_level: float = 0.0

var berry_bush_scene: PackedScene = preload("res://scenes/berry_bush.tscn")

# ---------------------------------------------------------------------------
# Wild roamer attraction
# ---------------------------------------------------------------------------
var attraction_check_timer: float = 0.0
const ATTRACTION_CHECK_INTERVAL: float = 25.0
const ATTRACTION_COOLDOWN: float = 60.0
var attraction_cooldowns: Dictionary = {}  # species_id -> remaining seconds

# Requirements each species needs before a wild one will visit.
# Keys: scene, min_food, min_shelters, min_avg_happiness, max_in_garden, label
var species_requirements: Dictionary = {
	"GlowFox": {
		"scene": "res://creatures/glowfox.tscn",
		"min_food": 1,
		"min_shelters": 0,
		"min_avg_happiness": 0.4,
		"max_in_garden": 4,
		"label": "🦊 GlowFox"
	},
	"Mossdeer": {
		"scene": "res://creatures/mossdeer.tscn",
		"min_food": 2,
		"min_shelters": 1,
		"min_avg_happiness": 0.5,
		"max_in_garden": 3,
		"label": "🦌 Mossdeer"
	},
}

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
		tree.add_to_group("trees")
		add_child(tree)

		var x = randf_range(-forest_radius, forest_radius)
		var z = randf_range(-forest_radius, forest_radius)
		tree.position = Vector3(x, 0, z)
		
		var tree_scale = randf_range(min_scale, max_scale)
		tree.scale = Vector3(tree_scale, tree_scale, tree_scale)
		
		tree.rotation.y = randf_range(0, TAU)
		i += 1

func create_boundary():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.88, 0.62, 1.0)  # soft mossy green
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var half = starter_area_size / 2.0
	var seg := 2.0
	var thickness := 0.12
	var height := 0.06
	var count := int(starter_area_size / seg)

	for i in range(count):
		var along: float = -half + (float(i) + 0.5) * seg
		# North/south edges run along X — pass run_axis "x"
		_add_boundary_segment(Vector3(along, 0.0, -half), Vector3(seg, height, thickness), mat, "x")
		_add_boundary_segment(Vector3(along, 0.0,  half), Vector3(seg, height, thickness), mat, "x")
		# East/west edges run along Z — pass run_axis "z"
		_add_boundary_segment(Vector3(-half, 0.0, along), Vector3(thickness, height, seg), mat, "z")
		_add_boundary_segment(Vector3( half, 0.0, along), Vector3(thickness, height, seg), mat, "z")

func _add_boundary_segment(pos: Vector3, size: Vector3, mat: StandardMaterial3D, run_axis: String):
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.set_meta("run_axis", run_axis)
	mi.set_surface_override_material(0, mat)
	mi.add_to_group("boundary_lines")
	add_child(mi)

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
# Start high — snap_all_statics() will land them on terrain surface
		debris_node.position = Vector3(x, 5.0, z)
		debris_node.rotation.y = randf_range(0, TAU)
		mesh_instance.scale = item["scale"]
		# Half-height offset so object sits ON terrain rather than half inside it
		debris_node.set_meta("snap_y_offset", item["scale"].y * 0.5)

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

var _boundary_timer: float = 0.0

func _process(delta):
	_boundary_timer += delta
	if _boundary_timer >= 0.2:
		_boundary_timer = 0.0
		update_boundary_heights()
	_tick_attraction(delta)

func update_boundary_heights():
	var space_state = get_world_3d().direct_space_state
	for line in get_tree().get_nodes_in_group("boundary_lines"):
		var ray_origin = Vector3(line.position.x, 10.0, line.position.z)
		var ray_end   = Vector3(line.position.x, -5.0, line.position.z)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		if not result:
			continue
		line.position.y = result.position.y + 0.04
		# Tilt the segment to lie flush with the terrain slope
		var n: Vector3 = result.normal
		var run_axis: String = line.get_meta("run_axis", "x")
		if run_axis == "x":
			# Segment runs along X — tilt around X to follow Z-slope
			line.rotation = Vector3(atan2(-n.z, n.y), 0.0, 0.0)
		else:
			# Segment runs along Z — tilt around Z to follow X-slope
			line.rotation = Vector3(0.0, 0.0, atan2(n.x, n.y))

# ---------------------------------------------------------------------------
# Wild roamer attraction
# ---------------------------------------------------------------------------

func _tick_attraction(delta: float):
	# Count down per-species cooldowns
	for species in attraction_cooldowns.keys():
		attraction_cooldowns[species] -= delta
		if attraction_cooldowns[species] <= 0.0:
			attraction_cooldowns.erase(species)

	attraction_check_timer += delta
	if attraction_check_timer < ATTRACTION_CHECK_INTERVAL:
		return
	attraction_check_timer = 0.0
	_check_wild_attractions()

func _check_wild_attractions():
	var food_count = get_tree().get_nodes_in_group("food").size()
	var shelter_count = get_tree().get_nodes_in_group("shelters").size()
	var roamers = get_tree().get_nodes_in_group("roamers")

	# Average happiness across all current roamers (0.5 if none yet)
	var avg_happiness := 0.5
	if roamers.size() > 0:
		var total := 0.0
		for r in roamers:
			total += r.happiness
		avg_happiness = total / roamers.size()

	for species_id in species_requirements:
		var req = species_requirements[species_id]

		# Still on cooldown?
		if attraction_cooldowns.has(species_id):
			continue

		# Already at population cap?
		var count := 0
		for r in roamers:
			if r.species_id == species_id:
				count += 1
		if count >= req["max_in_garden"]:
			continue

		# Check requirements
		if food_count < req["min_food"]:
			continue
		if shelter_count < req["min_shelters"]:
			continue
		if avg_happiness < req["min_avg_happiness"]:
			continue

		# All requirements met — attract one!
		_spawn_wild_roamer(species_id, req)
		attraction_cooldowns[species_id] = ATTRACTION_COOLDOWN
		break  # one spawn per check cycle

func _spawn_wild_roamer(species_id: String, req: Dictionary):
	var scene = load(req["scene"])
	if not scene:
		return

	var roamer = scene.instantiate()
	var spawn_pos = _get_boundary_spawn_pos()
	# Stamp species before add_child so _ready() doesn't need to do it
	add_child(roamer)
	roamer.global_position = spawn_pos

	# Send it walking toward the garden centre so it naturally enters
	var centre_target = Vector3(
		randf_range(-8.0, 8.0),
		spawn_pos.y,
		randf_range(-8.0, 8.0)
	)
	roamer.wander_target = centre_target
	roamer.wander_timer = 30.0

	_show_attraction_popup(spawn_pos, req["label"] + " is visiting!")
	WardenManager.gain_xp("roamer_appears")
	print("Wild ", species_id, " attracted to the garden!")

func _get_boundary_spawn_pos() -> Vector3:
	var half = starter_area_size / 2.0
	# Pick a random edge and a random point along it, just outside the boundary
	var edge = randi() % 4
	var x: float; var z: float
	match edge:
		0: x = randf_range(-half, half); z = -(half + 1.5)
		1: x = randf_range(-half, half); z =   half + 1.5
		2: x = -(half + 1.5);           z = randf_range(-half, half)
		3: x =   half + 1.5;            z = randf_range(-half, half)

	# Snap to terrain height
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(x, 15.0, z), Vector3(x, -5.0, z)
	)
	var result = space_state.intersect_ray(query)
	var y = (result.position.y + 1.5) if result else 3.0
	return Vector3(x, y, z)

func _show_attraction_popup(pos: Vector3, text: String):
	var label = Label3D.new()
	label.text = text
	label.font_size = 56
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.7, 1.0, 0.55)
	add_child(label)
	label.global_position = pos + Vector3(0, 2.5, 0)
	var tween = create_tween()
	tween.tween_property(label, "global_position", pos + Vector3(0, 6.0, 0), 3.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 3.5)
	tween.tween_callback(label.queue_free)

# Returns attraction status text for each species — used by the HUD.
func get_objective_hint() -> String:
	var roamers = get_tree().get_nodes_in_group("roamers")
	var food_count  = get_tree().get_nodes_in_group("food").size()
	var shelter_count = get_tree().get_nodes_in_group("shelters").size()

	if roamers.is_empty():
		if food_count == 0:
			return "🌿 Plant a berry bush so wild Roamers have a reason to visit."
		return "🌿 Wait — wild Roamers will wander in if your garden looks inviting."

	# Collect per-stage counts and needs
	var appears_unhappy  := []  # need happiness > 0.5
	var visits_no_shelter := [] # need shelter
	var visits_low_happy  := [] # need happiness > 0.7
	var resident_low_happy := [] # need happiness > 0.9
	var bonded := 0
	var hungry := []            # food < 0.3

	for r in roamers:
		if r.needs["food"] < 0.3:
			hungry.append(r.name)
		match r.attraction_stage:
			0: # APPEARS
				if r.happiness <= 0.5:
					appears_unhappy.append(r.name)
			1: # VISITS
				if not r.has_shelter:
					visits_no_shelter.append(r.name)
				elif r.happiness <= 0.7:
					visits_low_happy.append(r.name)
			2: # RESIDENT
				if r.happiness <= 0.9:
					resident_low_happy.append(r.name)
			3: # BONDED
				bonded += 1

	# Return the most urgent hint
	if not hungry.is_empty():
		return "🍓 " + hungry[0] + " is hungry — plant berry bushes or use a Roamer Treat."
	if not appears_unhappy.is_empty():
		return "💛 " + appears_unhappy[0] + " is exploring — keep happiness above 50" + "%" + " to earn their trust."
	if not visits_no_shelter.is_empty():
		return "🏠 " + visits_no_shelter[0] + " needs a shelter to become a Resident — buy one from Maren."
	if not visits_low_happy.is_empty():
		return "💛 " + visits_low_happy[0] + " needs happiness above 70" + "%" + " to settle in — feed them."
	if not resident_low_happy.is_empty():
		return "💚 " + resident_low_happy[0] + " needs happiness above 90" + "%" + " to Bond — keep all needs full."
	if bonded >= 2:
		return "💞 Two Bonded Roamers are ready — click one, then click the other to breed!"
	if bonded == 1:
		return "🌟 One Roamer is Bonded! Bond another to unlock breeding."
	if shelter_count == 0 and roamers.size() > 0:
		return "🏠 No shelters yet — buy a Basic Shelter from Maren and place it."
	return "✨ Garden is thriving! Attract more wild Roamers to grow your habitat."

func get_attraction_hints() -> Array:
	var hints = []
	var food_count = get_tree().get_nodes_in_group("food").size()
	var shelter_count = get_tree().get_nodes_in_group("shelters").size()
	var roamers = get_tree().get_nodes_in_group("roamers")
	var avg_happiness := 0.5
	if roamers.size() > 0:
		var total := 0.0
		for r in roamers:
			total += r.happiness
		avg_happiness = total / roamers.size()

	for species_id in species_requirements:
		var req = species_requirements[species_id]
		var count := 0
		for r in roamers:
			if r.species_id == species_id:
				count += 1
		if count >= req["max_in_garden"]:
			hints.append(req["label"] + ": garden full")
			continue
		if attraction_cooldowns.has(species_id):
			hints.append(req["label"] + ": on their way... ✨")
			continue
		var parts := []
		if food_count < req["min_food"]:
			parts.append(str(food_count) + "/" + str(req["min_food"]) + " food")
		if shelter_count < req["min_shelters"]:
			parts.append(str(shelter_count) + "/" + str(req["min_shelters"]) + " shelter")
		if avg_happiness < req["min_avg_happiness"]:
			parts.append("happiness too low")
		if parts.is_empty():
			hints.append(req["label"] + ": requirements met ✓")
		else:
			hints.append(req["label"] + ": needs " + ", ".join(parts))
	return hints
