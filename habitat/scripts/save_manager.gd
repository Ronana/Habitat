extends Node

const SAVE_PATH = "user://habitat_save.json"

func save_game(_garden: Node):
	var save_data = {
		"version": 1,
		"currency": {
			"dewdrops": CurrencyManager.dewdrops,
			"eldermoss": CurrencyManager.eldermoss
		},
		
		"roamers": [],
		"berry_bushes": []
	}
		# Save terrain vertices
	var ground = get_tree().get_root().get_node("Garden/Ground")
	if ground and ground.mesh:
		var mdt = MeshDataTool.new()
		var arr_mesh = ArrayMesh.new()
		arr_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			ground.mesh.surface_get_arrays(0)
		)
		mdt.create_from_surface(arr_mesh, 0)
		var vertices = []
		for i in range(mdt.get_vertex_count()):
			var v = mdt.get_vertex(i)
			vertices.append({"x": v.x, "y": v.y, "z": v.z})
		save_data["terrain"] = vertices


	# Save all Roamers
	for roamer in get_tree().get_nodes_in_group("roamers"):
		save_data["roamers"].append({
			"name": roamer.name,
			"scene": roamer.scene_file_path,
			"position": {
				"x": roamer.global_position.x,
				"y": roamer.global_position.y,
				"z": roamer.global_position.z
			},
			"stage": roamer.attraction_stage,
			"needs": roamer.needs
		})
	
	# Save all berry bushes
	for bush in get_tree().get_nodes_in_group("food"):
		save_data["berry_bushes"].append({
			"position": {
				"x": bush.global_position.x,
				"y": bush.global_position.y,
				"z": bush.global_position.z
			}
		})
		
	# Save shelters
	save_data["shelters"] = []
	for shelter in get_tree().get_nodes_in_group("shelters"):
		save_data["shelters"].append({
			"position": {
				"x": shelter.global_position.x,
				"y": shelter.global_position.y,
				"z": shelter.global_position.z
			},
			"occupied": shelter.is_occupied,
			"assigned_roamer": shelter.assigned_roamer.name if shelter.assigned_roamer else ""
		})
	
	# Write to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("Game saved successfully!")

func load_game(_garden: Node):
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found — starting fresh")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("ERROR: Could not parse save file")
		return false
	
	var save_data = json.get_data()
	
	# Remove existing Roamers and bushes before loading
	for roamer in get_tree().get_nodes_in_group("roamers"):
		roamer.queue_free()
	for bush in get_tree().get_nodes_in_group("food"):
		bush.queue_free()
	
	# Wait one frame for queue_free to complete
	await get_tree().process_frame
	
	# Restore currency
	CurrencyManager.dewdrops = save_data["currency"]["dewdrops"]
	CurrencyManager.eldermoss = save_data["currency"]["eldermoss"]
	CurrencyManager.emit_signal("dewdrops_changed", CurrencyManager.dewdrops)
	
	# Restore terrain
	if save_data.has("terrain"):
		var ground = get_tree().get_root().get_node("Garden/Ground")
		if ground and ground.mesh:
			var mdt = MeshDataTool.new()
			var arr_mesh = ArrayMesh.new()
			arr_mesh.add_surface_from_arrays(
				Mesh.PRIMITIVE_TRIANGLES,
				ground.mesh.surface_get_arrays(0)
			)
			mdt.create_from_surface(arr_mesh, 0)
			
			var vertices = save_data["terrain"]
			if vertices.size() == mdt.get_vertex_count():
				for i in range(mdt.get_vertex_count()):
					var v = mdt.get_vertex(i)
					v.y = vertices[i]["y"]
					mdt.set_vertex(i, v)
				
				arr_mesh.clear_surfaces()
				mdt.commit_to_surface(arr_mesh)
				ground.mesh = arr_mesh
				
				# Rebuild tool manager mesh data
				await get_tree().process_frame
				var tool_manager = get_tree().get_root().get_node("Garden/ToolManager")
				if tool_manager:
					tool_manager.build_mesh_data_tool()
					tool_manager.apply_terrain_colours()
				
				print("Terrain restored successfully")
	
	# Restore Roamers
	for roamer_data in save_data["roamers"]:
		var scene = load(roamer_data["scene"])
		if scene:
			var roamer = scene.instantiate()
			roamer.name = roamer_data["name"]
			_garden.add_child(roamer)
			roamer.global_position = Vector3(
				roamer_data["position"]["x"],
				roamer_data["position"]["y"],
				roamer_data["position"]["z"]
			)
			roamer.attraction_stage = roamer_data["stage"]
			roamer.needs = roamer_data["needs"]
	
	# Restore berry bushes
	var bush_scene = load("res://scenes/berry_bush.tscn")
	for bush_data in save_data["berry_bushes"]:
		var bush = bush_scene.instantiate()
		_garden.add_child(bush)
		bush.global_position = Vector3(
			bush_data["position"]["x"],
			bush_data["position"]["y"],
			bush_data["position"]["z"]
		)
		
	# Restore shelters
	if save_data.has("shelters"):
		var shelter_scene = load("res://scenes/shelter.tscn")
		for shelter_data in save_data["shelters"]:
			var shelter = shelter_scene.instantiate()
			_garden.add_child(shelter)
			shelter.global_position = Vector3(
				shelter_data["position"]["x"],
				shelter_data["position"]["y"],
				shelter_data["position"]["z"]
			)
	
	print("Game loaded successfully!")
	return true

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")
