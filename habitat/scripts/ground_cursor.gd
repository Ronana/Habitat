extends Node3D

var cursor_mesh: MeshInstance3D
var cursor_mat: StandardMaterial3D
var pulse_timer: float = 0.0

var normal_colour: Color  = Color(1.00, 0.95, 0.80)
var limit_colour: Color   = Color(0.95, 0.30, 0.20)
var water_colour: Color   = Color(0.35, 0.70, 1.00)
var current_colour: Color

func _ready():
	cursor_mesh = $CursorMesh
	cursor_mesh.mesh = _build_ring(0.72, 1.0, 64)

	cursor_mat = StandardMaterial3D.new()
	cursor_mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_mat.no_depth_test   = true
	cursor_mat.emission_enabled = true
	cursor_mat.emission_energy_multiplier = 1.5
	cursor_mat.albedo_color    = Color(normal_colour, 0.85)
	cursor_mat.emission        = normal_colour
	cursor_mesh.set_surface_override_material(0, cursor_mat)

	current_colour = normal_colour
	scale = Vector3(1.4, 1.0, 1.4)

func _process(delta):
	pulse_timer += delta
	# Gentle breathe — scale the mesh child so the node position stays exact
	var pulse = 1.0 + 0.06 * sin(pulse_timer * 3.5)
	cursor_mesh.scale = Vector3(pulse, 1.0, pulse)
	update_cursor_position()

func update_cursor_position():
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end    = ray_origin + cam.project_ray_normal(mouse_pos) * 200.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	if result:
		global_position = Vector3(result.position.x, result.position.y + 0.05, result.position.z)
		rotation = Vector3.ZERO
		_update_colour(result.position)

func _update_colour(hit_pos: Vector3):
	var target: Color
	if hit_pos.y <= -1.8:
		target = limit_colour
	elif hit_pos.y <= -0.8:
		target = water_colour
	else:
		target = normal_colour
	if target != current_colour:
		current_colour = target
		cursor_mat.albedo_color = Color(target, 0.85)
		cursor_mat.emission     = target

# Builds a flat ring (annulus) mesh in the XZ plane.
func _build_ring(inner_r: float, outer_r: float, segments: int) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(segments):
		var a1 = (float(i)     / segments) * TAU
		var a2 = (float(i + 1) / segments) * TAU
		var p1i = Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var p1o = Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		var p2i = Vector3(cos(a2) * inner_r, 0.0, sin(a2) * inner_r)
		var p2o = Vector3(cos(a2) * outer_r, 0.0, sin(a2) * outer_r)
		st.add_vertex(p1o); st.add_vertex(p2o); st.add_vertex(p1i)
		st.add_vertex(p2o); st.add_vertex(p2i); st.add_vertex(p1i)
	return st.commit()
