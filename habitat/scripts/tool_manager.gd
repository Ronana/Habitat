extends Node3D

enum Tool { NONE, SPADE }

var current_tool = Tool.SPADE
var spade_radius: float = 3.0
var spade_strength: float = 2.0
var raise_terrain: bool = true
var original_material: Material
var placement_item: String = ""
var berry_bush_scene: PackedScene = preload("res://scenes/berry_bush.tscn")
var base_level: float = 0.0
var max_dig_depth: float = -2.0
var can_raise_terrain: bool = false
var ground_mesh: MeshInstance3D
var mesh_data_tool: MeshDataTool
var array_mesh: ArrayMesh
var starter_area_size: float = 40.0

func _ready():
	ground_mesh = get_parent().get_node("Ground")
	await get_tree().process_frame
	await get_tree().process_frame
	build_mesh_data_tool()
	apply_terrain_colours()
	print("Mesh data tool built successfully")

func build_mesh_data_tool():
	original_material = ground_mesh.get_active_material(0)
	array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		ground_mesh.mesh.surface_get_arrays(0)
	)
	mesh_data_tool = MeshDataTool.new()
	mesh_data_tool.create_from_surface(array_mesh, 0)

func _input(event):
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	
	# Left click — terrain tools only
	if event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT):
			raise_terrain = false
			use_spade()
			get_viewport().set_input_as_handled()
			return
		if Input.is_key_pressed(KEY_ALT):
			raise_terrain = true
			use_spade()
			get_viewport().set_input_as_handled()
			return
	
	# Right click — place item if one is selected
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if placement_item != "":
			place_item()
			get_viewport().set_input_as_handled()
			return
				
func selected_roamer_exists() -> bool:
	return get_parent().get_node("PlayerCursor").selected_roamer != null

func place_item():
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + cam.project_ray_normal(mouse_pos) * 200.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)

	if result:
		match placement_item:
			"Berry Seeds":
				if InventoryManager.remove_item("Berry Seeds"):
					var bush = berry_bush_scene.instantiate()
					get_parent().add_child(bush)
					bush.global_position = result.position
					print("Berry bush planted!")
					placement_item = ""


func use_spade():
	print("use_spade called")
	var cam = get_viewport().get_camera_3d()
	if not cam:
		print("ERROR: No camera")
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + cam.project_ray_normal(mouse_pos) * 200.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	if result:
		print("Ray hit: ", result.collider.name, " at ", result.position)
		var hit_pos = result.position
		deform_terrain(hit_pos)
	else:
		print("Ray hit nothing")

func deform_terrain(hit_pos: Vector3):
	var half = starter_area_size / 2.0
	if abs(hit_pos.x) > half or abs(hit_pos.z) > half:
		print("Outside playable area")
		return
	WardenManager.gain_xp("terrain_shaped")
	var direction = 1.0 if raise_terrain else -1.0
	var vertices_affected = 0

	for i in range(mesh_data_tool.get_vertex_count()):
		var vertex = mesh_data_tool.get_vertex(i)
		var distance = Vector2(vertex.x - hit_pos.x, vertex.z - hit_pos.z).length()

		if distance < spade_radius:
			var influence = 1.0 - (distance / spade_radius)
			var new_y = vertex.y + (direction * spade_strength * influence)
			
			# Enforce limits
			if direction > 0 and not can_raise_terrain:
				# Can only raise up to base level with basic shovel
				new_y = min(new_y, base_level)
			if direction < 0:
				# Can't dig below max depth
				new_y = max(new_y, max_dig_depth)
			
			vertex.y = new_y
			mesh_data_tool.set_vertex(i, vertex)
			vertices_affected += 1

	array_mesh.clear_surfaces()
	mesh_data_tool.commit_to_surface(array_mesh)
	ground_mesh.mesh = array_mesh.duplicate()
	apply_terrain_colours()
	
func set_placement_item(item_name: String):
	placement_item = item_name
	print("Ready to place: ", item_name)

func apply_terrain_colours():
	var surface_tool = SurfaceTool.new()
	var mdt = MeshDataTool.new()
	var temp_mesh = ArrayMesh.new()
	temp_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		ground_mesh.mesh.surface_get_arrays(0)
	)
	mdt.create_from_surface(temp_mesh, 0)
	
	# Colour each vertex based on height
	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		var colour: Color
		
		if vertex.y > 0.1:
			# Above ground — starts bright green, gets very dark green at peak
			var t = clamp(vertex.y / 1.5, 0.0, 1.0)
			colour = Color(0.35, 0.50, 0.20).lerp(Color(0.08, 0.18, 0.05), t)
		elif vertex.y < -0.1:
			# Below ground — starts light dirt, gets very dark soil at depth
			var t = clamp(abs(vertex.y) / 2.0, 0.0, 1.0)
			colour = Color(0.55, 0.40, 0.22).lerp(Color(0.18, 0.10, 0.05), t)
		else:
			# At ground level — base green
			colour = Color(0.29, 0.36, 0.18)
		
		mdt.set_vertex_color(i, colour)
	
	temp_mesh.clear_surfaces()
	mdt.commit_to_surface(temp_mesh)
	ground_mesh.mesh = temp_mesh
	
	# Use vertex colours — set material to use them
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	ground_mesh.set_surface_override_material(0, mat)
