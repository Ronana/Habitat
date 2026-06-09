extends Node3D

enum Tool { NONE, SPADE }

var current_tool = Tool.SPADE
var spade_radius: float = 8.0
var spade_strength: float = 2.0
var raise_terrain: bool = true
var original_material: Material

var ground_mesh: MeshInstance3D
var mesh_data_tool: MeshDataTool
var array_mesh: ArrayMesh

func _ready():
	ground_mesh = get_parent().get_node("Ground")
	if ground_mesh:
		print("Ground found: ", ground_mesh.name)
		build_mesh_data_tool()
		print("Mesh data tool built successfully")
	else:
		print("ERROR: Ground node not found")

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
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Left click detected in ToolManager")
			if Input.is_key_pressed(KEY_SHIFT):
				raise_terrain = false
				use_spade()
			elif Input.is_key_pressed(KEY_ALT):
				raise_terrain = true
				use_spade()

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
	var direction = 1.0 if raise_terrain else -1.0
	var vertices_affected = 0
	
	for i in range(mesh_data_tool.get_vertex_count()):
		var vertex = mesh_data_tool.get_vertex(i)
		var distance = Vector2(vertex.x - hit_pos.x, vertex.z - hit_pos.z).length()
		
		if distance < spade_radius:
			var influence = 1.0 - (distance / spade_radius)
			vertex.y += direction * spade_strength * influence
			mesh_data_tool.set_vertex(i, vertex)
			vertices_affected += 1
	
	print("Vertices affected: ", vertices_affected)
	
	# Rebuild the mesh
	array_mesh.clear_surfaces()
	mesh_data_tool.commit_to_surface(array_mesh)
	ground_mesh.mesh = array_mesh
	ground_mesh.set_surface_override_material(0, original_material)
