extends Node3D

var cursor_mesh: MeshInstance3D
var tool_radius: float = 6.0
var normal_colour: Color = Color(0.83, 0.79, 0.66)
var limit_colour: Color = Color(0.9, 0.3, 0.2)
var water_colour: Color = Color(0.3, 0.6, 0.9)

func _ready():
	cursor_mesh = $CursorMesh
	scale = Vector3(tool_radius, 1.0, tool_radius)

func _process(_delta):
	update_cursor_position()

func update_cursor_position():
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
		var hit_pos = result.position
		# Always sit 0.3 units above whatever surface is hit
		global_position = Vector3(hit_pos.x, hit_pos.y + 0.1, hit_pos.z)
		# Keep cursor flat — don't rotate with terrain
		rotation = Vector3.ZERO
		update_cursor_colour(hit_pos)

func update_cursor_colour(hit_pos: Vector3):
	var mat = cursor_mesh.get_active_material(0)
	if not mat:
		return
	
	# Red when at dig limit
	if hit_pos.y <= -1.8:
		mat.albedo_color = limit_colour
		mat.emission = limit_colour
	# Blue when low enough for water
	elif hit_pos.y <= -0.8:
		mat.albedo_color = water_colour
		mat.emission = water_colour
	# Normal colour otherwise
	else:
		mat.albedo_color = normal_colour
		mat.emission = normal_colour

func set_radius(new_radius: float):
	tool_radius = new_radius
	scale = Vector3(tool_radius, 1.0, tool_radius)
