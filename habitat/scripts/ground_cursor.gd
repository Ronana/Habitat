extends Node3D

var cursor_mesh: MeshInstance3D
var cursor_mat: StandardMaterial3D
var pulse_timer: float = 0.0

var normal_colour: Color  = Color(1.00, 0.95, 0.80)
var limit_colour: Color   = Color(0.95, 0.30, 0.20)
var water_colour: Color   = Color(0.35, 0.70, 1.00)
var lock_colour: Color    = Color(0.78, 0.38, 0.96)   # purple snap tint
var current_colour: Color

# ── Lock-on ──────────────────────────────────────────────────────────────────
const LOCK_RADIUS : float = 2.4   # world-space snap distance
const LOCK_SPEED  : float = 16.0  # lerp speed when snapping
const FREE_SPEED  : float = 22.0  # lerp speed when releasing

var _raw_pos     : Vector3 = Vector3.ZERO   # raw terrain hit
var _display_pos : Vector3 = Vector3.ZERO   # smoothed position fed to the ring
var _lock_target : Node3D  = null           # current snap target

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

func _process(delta: float) -> void:
	pulse_timer += delta

	# 1. Raycast raw terrain position
	_update_raw_pos()

	# 2. Find nearest interactable within snap radius
	_lock_target = _find_lock_target()

	# 3. Lerp display pos toward lock target (or raw terrain)
	var dest: Vector3
	if is_instance_valid(_lock_target):
		dest = Vector3(_lock_target.global_position.x,
					   _raw_pos.y + 0.05,
					   _lock_target.global_position.z)
		_display_pos = _display_pos.lerp(dest, delta * LOCK_SPEED)
	else:
		dest = _raw_pos + Vector3(0, 0.05, 0)
		_display_pos = _display_pos.lerp(dest, delta * FREE_SPEED)

	global_position = _display_pos
	rotation = Vector3.ZERO

	# 4. Ring pulse — shrink slightly when locked for a tight-focus feel
	var locked: bool = is_instance_valid(_lock_target)
	var base_scale: float = 0.9 if locked else 1.4
	var pulse: float = 1.0 + 0.06 * sin(pulse_timer * 3.5)
	cursor_mesh.scale = Vector3(base_scale * pulse, 1.0, base_scale * pulse)

	# 5. Colour
	_apply_colour(locked)

func _update_raw_pos() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var mp  := get_viewport().get_mouse_position()
	var org := cam.project_ray_origin(mp)
	var end := org + cam.project_ray_normal(mp) * 200.0
	var result := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(org, end))
	if result:
		var cb: float = ZoneManager.get_garden_half() + 10.0
		_raw_pos = Vector3(
			clamp(result.position.x, -cb, cb),
			result.position.y,
			clamp(result.position.z, -cb, cb))

func _find_lock_target() -> Node3D:
	var best_dist: float = LOCK_RADIUS
	var best: Node3D = null
	var candidates: Array = []
	for g in ["roamers", "placeable_items", "food", "shelters", "zone_markers", "npcs", "debris", "trees"]:
		candidates.append_array(get_tree().get_nodes_in_group(g))
	for node in candidates:
		if not node is Node3D:
			continue
		var n3 := node as Node3D
		var d := Vector2(_raw_pos.x - n3.global_position.x,
						 _raw_pos.z - n3.global_position.z).length()
		if d < best_dist:
			best_dist = d
			best = n3
	return best

func update_cursor_position() -> void:
	# Legacy stub — logic now runs in _process
	pass

func _apply_colour(locked: bool) -> void:
	var target: Color
	var hit_pos: Vector3 = _raw_pos
	# Outside garden boundary — always red
	var gh: float = ZoneManager.get_garden_half()
	if abs(hit_pos.x) > gh or abs(hit_pos.z) > gh:
		target = limit_colour
	elif hit_pos.y <= -1.8:
		target = limit_colour
	elif hit_pos.y <= -0.8:
		target = water_colour
	elif locked:
		target = lock_colour
	else:
		# When a placement item is active, show red if the spot is blocked
		var tool_mgr: Node = get_tree().get_root().get_node_or_null("Garden/ToolManager")
		var _raw_pl = tool_mgr.get("placement_item") if tool_mgr else null
		var _placement: String = str(_raw_pl) if _raw_pl != null else ""
		if tool_mgr and _placement != "":
			if tool_mgr.is_placement_clear(hit_pos, _placement):
				target = normal_colour
			else:
				target = limit_colour  # red = blocked
		else:
			target = normal_colour
	if target != current_colour:
		current_colour = target
		cursor_mat.albedo_color = Color(target, 0.85)
		cursor_mat.emission     = target

func _update_colour(_hit_pos: Vector3) -> void:
	# Legacy compat wrapper
	_apply_colour(false)

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
