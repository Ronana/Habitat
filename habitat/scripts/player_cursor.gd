extends Node3D

@onready var roamer_ui = $"../RoamerUI"

var selected_roamer = null

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Click detected")
			if not try_clear_debris():
				try_select_roamer()
			try_interact_with_trader()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if selected_roamer:
				try_direct_roamer()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			if selected_roamer:
				selected_roamer.feed(0.3)

func try_direct_roamer():
	var cam = get_camera()
	if not cam:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + cam.project_ray_normal(mouse_pos) * 100.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result:
		var target = result.position
		selected_roamer.move_to(target)
		print("Directing to: ", target)

func get_camera():
	return get_viewport().get_camera_3d()

func try_select_roamer():
	var cam = get_camera()
	if not cam:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + cam.project_ray_normal(mouse_pos) * 100.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)

	if result:
		var node = result.collider
		while node:
			if node.is_in_group("roamers"):
				if node == selected_roamer:
					# Clicking the selected roamer again deselects it
					deselect_roamer()
				elif selected_roamer and _can_breed(selected_roamer, node):
					# Second click on a breed-eligible roamer — initiate bond
					_initiate_breed(selected_roamer, node)
				else:
					# Switch selection (or first selection)
					if selected_roamer:
						deselect_roamer()
					select_roamer(node)
				return
			node = node.get_parent()

	if selected_roamer:
		deselect_roamer()

func _can_breed(a, b) -> bool:
	if not a.is_bondable() or not b.is_bondable():
		return false
	if a.species_id == "" or a.species_id != b.species_id:
		return false
	if a._is_sibling(b):
		return false
	return true

func _initiate_breed(a, b):
	print(a.name, " + ", b.name, " — breeding initiated!")
	deselect_roamer()
	a.start_bond(b)

func select_roamer(roamer):
	selected_roamer = roamer
	roamer.on_selected()
	roamer_ui.show_roamer(roamer)

func deselect_roamer():
	selected_roamer.on_deselected()
	roamer_ui.hide_roamer()
	selected_roamer = null

func try_interact_with_trader():
	var cam = get_camera()
	if not cam:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + cam.project_ray_normal(mouse_pos) * 100.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	if result:
		var node = result.collider
		while node:
			if node.name == "Maren":
				node.show_selection_ring()
				roamer_ui.open_shop(node)
				return
			node = node.get_parent()

func try_clear_debris() -> bool:
	var cam = get_camera()
	if not cam:
		return false
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + cam.project_ray_normal(mouse_pos) * 100.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result:
		var node = result.collider
		while node:
			if node.is_in_group("debris"):
				clear_debris(node)
				return true
			node = node.get_parent()
	return false

func clear_debris(debris_node: Node):
	var reward = debris_node.get_meta("dewdrop_reward", 5.0)
	var xp = debris_node.get_meta("xp_reward", 5.0)
	var debris_name = debris_node.get_meta("debris_name", "Debris")
	
	# Reward the player
	CurrencyManager.add_dewdrops(reward)
	WardenManager.current_xp += xp
	WardenManager.check_level_up()
	
	print("Cleared ", debris_name, " — +" , reward, " Dewdrops, +", xp, " XP")
	
			# Spawn floating reward text
	spawn_reward_popup(debris_node.global_position, "+" + str(reward) + " 💧")
	# Remove the debris
	debris_node.queue_free()
	
func spawn_reward_popup(world_pos: Vector3, text: String):
	var label = Label3D.new()
	label.text = text
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.85, 0.3)
	get_tree().get_root().get_node("Garden").add_child(label)
	label.global_position = world_pos + Vector3(0, 1.0, 0)
	
	# Animate upward then disappear
	var tween = create_tween()
	tween.tween_property(label, "global_position", world_pos + Vector3(0, 3.0, 0), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
	
