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
	
	# Write to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("Game saved successfully!")

func load_game(garden: Node):
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
	
	# Restore currency
	CurrencyManager.dewdrops = save_data["currency"]["dewdrops"]
	CurrencyManager.eldermoss = save_data["currency"]["eldermoss"]
	CurrencyManager.emit_signal("dewdrops_changed", CurrencyManager.dewdrops)
	
	# Restore Roamers
	for roamer_data in save_data["roamers"]:
		var scene = load(roamer_data["scene"])
		if scene:
			var roamer = scene.instantiate()
			garden.add_child(roamer)
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
		garden.add_child(bush)
		bush.global_position = Vector3(
			bush_data["position"]["x"],
			bush_data["position"]["y"],
			bush_data["position"]["z"]
		)
	
	print("Game loaded successfully!")
	return true

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")
