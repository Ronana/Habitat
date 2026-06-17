extends Node3D

@onready var roamer_ui = $"../RoamerUI"

# ── Selection state ───────────────────────────────────────────────────────────
var selected_roamer                    = null
var selected_item   : Node3D           = null
var _item_moving    : bool             = false
var _pre_focus_zoom : float            = -1.0

# ── Garden half is dynamic (grows with zone unlocks) ─────────────────────────

# ── Cursor world position (shared with roamers) ───────────────────────────────
var cursor_world_pos     : Vector3 = Vector3.ZERO
var _cursor_timer        : float   = 0.0
var _raw_cursor_pos      : Vector3 = Vector3.ZERO  # unsnapped terrain hit
var _pc_lock_target      : Node3D  = null
const PC_LOCK_RADIUS     : float   = 2.4
const PC_LOCK_SPEED      : float   = 16.0
const PC_FREE_SPEED      : float   = 22.0

# ── Move (VP-style lift) ─────────────────────────────────────────────────────
const MOVE_LIFT_HEIGHT   : float   = 1.5
const MOVE_BOB_SPEED     : float   = 3.2
const MOVE_BOB_AMP       : float   = 0.07
var _move_bob_timer      : float   = 0.0
var _move_origin         : Vector3 = Vector3.ZERO   # for cancel/return
var _move_shadow         : MeshInstance3D = null

# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_cursor_timer -= delta
	if _cursor_timer <= 0.0:
		_cursor_timer = 0.05
		_refresh_cursor()

	# Lock-on disabled while moving (don't snap the hovering item to other objects)
	if _item_moving:
		cursor_world_pos = _raw_cursor_pos
	else:
		_pc_lock_target = _find_pc_lock_target()
		if is_instance_valid(_pc_lock_target):
			var dest := Vector3(_pc_lock_target.global_position.x,
								_raw_cursor_pos.y,
								_pc_lock_target.global_position.z)
			cursor_world_pos = cursor_world_pos.lerp(dest, delta * PC_LOCK_SPEED)
		else:
			cursor_world_pos = cursor_world_pos.lerp(_raw_cursor_pos, delta * PC_FREE_SPEED)

	# VP-style item lift — float the held item above the cursor with a gentle bob
	if _item_moving and is_instance_valid(selected_item):
		_move_bob_timer += delta
		var bob   := sin(_move_bob_timer * MOVE_BOB_SPEED) * MOVE_BOB_AMP
		var hover := Vector3(_raw_cursor_pos.x,
							 _raw_cursor_pos.y + MOVE_LIFT_HEIGHT + bob,
							 _raw_cursor_pos.z)
		selected_item.global_position = selected_item.global_position.lerp(hover, delta * 14.0)
		_update_move_shadow()

func _refresh_cursor() -> void:
	var cam : Camera3D = get_camera()
	if not cam:
		return
	var mp     := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mp)
	var end    := origin + cam.project_ray_normal(mp) * 200.0
	var query  := PhysicsRayQueryParameters3D.create(origin, end)

	# Exclude the dragged item so the ray sees the terrain beneath it
	if _item_moving and is_instance_valid(selected_item):
		var excl : Array[RID] = []
		_collect_rids(selected_item, excl)
		if not excl.is_empty():
			query.exclude = excl

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		_raw_cursor_pos = result.position
	else:
		# Terrain3D collision not hit — fall back to Y=0 world plane so the
		# cursor ring always tracks the mouse even before collision is ready.
		var plane := Plane(Vector3.UP, 0.0)
		var hit = plane.intersects_ray(origin, cam.project_ray_normal(mp))
		if hit != null:
			_raw_cursor_pos = hit
	# Clamp to the same bound as the camera
	var cb: float = ZoneManager.get_garden_half() + 10.0
	_raw_cursor_pos.x = clamp(_raw_cursor_pos.x, -cb, cb)
	_raw_cursor_pos.z = clamp(_raw_cursor_pos.z, -cb, cb)

func _find_pc_lock_target() -> Node3D:
	var best_dist: float = PC_LOCK_RADIUS
	var best: Node3D = null
	for g in ["roamers", "placeable_items", "food", "shelters", "zone_markers", "npcs", "debris", "trees"]:
		for node in get_tree().get_nodes_in_group(g):
			if not node is Node3D:
				continue
			var n3 := node as Node3D
			var d := Vector2(_raw_cursor_pos.x - n3.global_position.x,
							  _raw_cursor_pos.z - n3.global_position.z).length()
			if d < best_dist:
				best_dist = d
				best = n3
	return best

func _collect_rids(node: Node, out: Array[RID]) -> void:
	if node is PhysicsBody3D:
		out.append((node as PhysicsBody3D).get_rid())
	for child in node.get_children():
		_collect_rids(child, out)

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mb := event as InputEventMouseButton

	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_on_left_click(mb.double_click)

	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if _item_moving:
			_cancel_move()
		elif selected_roamer:
			_direct_roamer()

func _on_left_click(is_double: bool) -> void:
	# Double-click on an agitated roamer calms it; otherwise feed
	if is_double and selected_roamer:
		if selected_roamer.state == selected_roamer.State.AGITATED:
			selected_roamer.calm_agitation()
			_spawn_calm_splash(selected_roamer.global_position)
		else:
			selected_roamer.feed(0.3)
		return

	# ── Confirm a pending drag first ───────────────────────────────────────
	if _item_moving:
		_confirm_move()
		get_viewport().set_input_as_handled()
		return

	var tool := _active_tool()

	# ── Shovel mode: tool_manager owns all shovel clicks (menu + smash) ──
	if tool == "shovel":
		return

	# ── Hand / default: select roamer, then zone marker, then item, then trader ─
	var hit_roamer := try_select_roamer()
	if not hit_roamer:
		if not _try_interact_with_zone_marker():
			_try_select_item()
	try_interact_with_trader()

# ── Shovel hit logic ──────────────────────────────────────────────────────────

func _try_hit_item() -> bool:
	var result := _raycast(200.0)
	if not result:
		return false
	var node := result.collider as Node
	while node:
		if _is_world_item(node):
			var item := node as Node3D
			if item and _in_garden(item):
				_hit_item(item)
				return true
		node = node.get_parent()
	return false

func _hit_item(item: Node3D) -> void:
	var health := _ensure_health(item)
	if not health:
		return
	if health.take_hit():
		_destroy_item(item)

func _destroy_item(item: Node3D) -> void:
	if selected_item == item:
		_deselect_item()

	var reward : float = float(item.get_meta("dewdrop_reward")) if item.has_meta("dewdrop_reward") else 5.0
	var xp     : float = float(item.get_meta("xp_reward"))      if item.has_meta("xp_reward")      else 3.0

	CurrencyManager.add_dewdrops(reward)
	WardenManager.current_xp += xp
	WardenManager.check_level_up()
	_spawn_popup(item.global_position, "+" + str(int(reward)) + " 💧")
	item.queue_free()

# ── Item selection ────────────────────────────────────────────────────────────

func _try_select_item() -> bool:
	var result := _raycast(200.0)
	if not result:
		_deselect_item()
		return false

	var node := result.collider as Node
	while node:
		if _is_world_item(node):
			var item := node as Node3D
			if item and _in_garden(item):
				if selected_item == item:
					# Second click on a moveable item → enter move mode
					if _is_moveable(item):
						_start_move(item)
					return true
				_deselect_item()
				_select_item(item)
				return true
		node = node.get_parent()

	_deselect_item()
	return false

func _select_item(item: Node3D) -> void:
	selected_item = item
	var health := _ensure_health(item)
	if health:
		health.show_select(true)
	_focus_camera(item.global_position)

func _deselect_item() -> void:
	if selected_item and is_instance_valid(selected_item):
		var h := selected_item.get_node_or_null("ItemHealth")
		if h and h.has_method("show_select"):
			h.show_select(false)
	_item_moving  = false
	selected_item = null
	_restore_zoom()

# ── Move mode (VP-style) ─────────────────────────────────────────────────────

func _is_moveable(item: Node) -> bool:
	return (item.is_in_group("placeable_items") or
			item.is_in_group("shelters") or
			item.is_in_group("food") or
			item.is_in_group("decoratives"))

func _start_move(item: Node3D) -> void:
	_item_moving    = true
	_move_origin    = item.global_position
	_move_bob_timer = 0.0
	_set_collision(item, false)
	_create_move_shadow()
	AudioManager.play_select()

func _confirm_move() -> void:
	if not is_instance_valid(selected_item):
		_item_moving = false
		return
	_item_moving = false
	_destroy_move_shadow()
	var item := selected_item
	var land := Vector3(_raw_cursor_pos.x, _raw_cursor_pos.y, _raw_cursor_pos.z)
	var tw   := create_tween()
	tw.tween_property(item, "global_position", land, 0.18)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_callback(func(): _set_collision(item, true))
	AudioManager.play_place()

func _cancel_move() -> void:
	if not is_instance_valid(selected_item):
		_item_moving = false
		return
	_item_moving = false
	_destroy_move_shadow()
	var item   := selected_item
	var origin := _move_origin
	var tw     := create_tween()
	tw.tween_property(item, "global_position", origin, 0.22)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func(): _set_collision(item, true))

func _create_move_shadow() -> void:
	_move_shadow = MeshInstance3D.new()
	var disc          := CylinderMesh.new()
	disc.top_radius    = 0.55
	disc.bottom_radius = 0.55
	disc.height        = 0.02
	_move_shadow.mesh  = disc
	var mat           := StandardMaterial3D.new()
	mat.albedo_color   = Color(0.0, 0.0, 0.0, 0.32)
	mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test  = false
	_move_shadow.set_surface_override_material(0, mat)
	get_parent().add_child(_move_shadow)

func _destroy_move_shadow() -> void:
	if is_instance_valid(_move_shadow):
		_move_shadow.queue_free()
	_move_shadow = null

func _update_move_shadow() -> void:
	if is_instance_valid(_move_shadow):
		_move_shadow.global_position = Vector3(
			_raw_cursor_pos.x, _raw_cursor_pos.y + 0.03, _raw_cursor_pos.z)

func _set_collision(node: Node3D, enabled: bool) -> void:
	# Handle root-level physics body
	if node is PhysicsBody3D:
		(node as PhysicsBody3D).collision_layer = 1 if enabled else 0
		(node as PhysicsBody3D).collision_mask  = 1 if enabled else 0
		return
	# Handle physics body children
	for child in node.get_children():
		if child is PhysicsBody3D:
			(child as PhysicsBody3D).collision_layer = 1 if enabled else 0
			(child as PhysicsBody3D).collision_mask  = 1 if enabled else 0

# ── Camera focus ──────────────────────────────────────────────────────────────

func _focus_camera(world_pos: Vector3) -> void:
	var cam : Camera3D = get_camera()
	if not cam or not cam.has_method("focus_on"):
		return
	_pre_focus_zoom = cam.target_zoom
	cam.focus_on(world_pos)

func _restore_zoom() -> void:
	if _pre_focus_zoom < 0.0:
		return
	var cam : Camera3D = get_camera()
	if cam:
		var tw := create_tween()
		tw.tween_property(cam, "target_zoom", _pre_focus_zoom, 0.6)
	_pre_focus_zoom = -1.0

## Called by tool_manager when the player picks "Smash" from the shovel menu.
func hit_world_item(item: Node3D) -> void:
	_hit_item(item)

## Called by tool_manager to show the selection ring on a shovel target.
func select_item(item: Node3D) -> void:
	if selected_item == item:
		return
	_deselect_item()
	_select_item(item)

# ── Health component ──────────────────────────────────────────────────────────

func _ensure_health(item: Node3D) -> Node:
	var existing := item.get_node_or_null("ItemHealth")
	if existing:
		return existing
	var script := load("res://scripts/item_health.gd") as GDScript
	if not script:
		return null
	var h := Node3D.new()
	h.name = "ItemHealth"
	h.set_script(script)
	item.add_child(h)
	h.setup(_hit_count(item))
	return h

func _hit_count(item: Node3D) -> int:
	if item.is_in_group("trees"):
		return 2
	var n := item.name.to_lower()
	if "rock" in n or "stone" in n or "boulder" in n or "log" in n or "stump" in n:
		return 3
	return 1

# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_world_item(node: Node) -> bool:
	return (node.is_in_group("debris") or
			node.is_in_group("trees") or
			node.is_in_group("placeable_items") or
			node.is_in_group("food") or
			node.is_in_group("shelters") or
			node.is_in_group("decoratives"))

func _in_garden(item: Node3D) -> bool:
	var half: float = ZoneManager.get_garden_half()
	return (abs(item.global_position.x) <= half and
			abs(item.global_position.z) <= half)

func _active_tool() -> String:
	var tm := get_parent().get_node_or_null("ToolManager")
	if tm:
		return str(tm.get("active_tool"))
	return "hand"

func _raycast(dist: float) -> Dictionary:
	var cam : Camera3D = get_camera()
	if not cam:
		return {}
	var mp  := get_viewport().get_mouse_position()
	var org := cam.project_ray_origin(mp)
	var end := org + cam.project_ray_normal(mp) * dist
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(org, end))

## Like _raycast but passes THROUGH bodies that don't belong to the target group,
## retrying up to max_depth times. Allows selecting roamers sitting on rocks/terrain.
func _raycast_to_group(group: String, dist: float, max_depth: int = 8) -> Dictionary:
	var cam : Camera3D = get_camera()
	if not cam:
		return {}
	var mp  := get_viewport().get_mouse_position()
	var org := cam.project_ray_origin(mp)
	var end := org + cam.project_ray_normal(mp) * dist
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for _i in range(max_depth):
		var params := PhysicsRayQueryParameters3D.create(org, end)
		params.exclude = exclude
		var result := space.intersect_ray(params)
		if result.is_empty():
			break
		# Walk up from the collider — if any ancestor is in the group, return this hit
		var node := result.collider as Node
		while node:
			if node.is_in_group(group):
				return result
			node = node.get_parent()
		# Not in the group — exclude this body and try deeper
		exclude.append(result.rid)
	return {}

func get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()

func _spawn_popup(world_pos: Vector3, text: String) -> void:
	var lbl := Label3D.new()
	lbl.text          = text
	lbl.font_size     = 48
	lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate      = Color(1.0, 0.85, 0.3)
	get_parent().add_child(lbl)
	lbl.global_position = world_pos + Vector3(0, 1.0, 0)
	var tw := create_tween()
	tw.tween_property(lbl, "global_position", world_pos + Vector3(0, 3.0, 0), 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)

# ── Roamer logic (preserved) ──────────────────────────────────────────────────

func try_select_roamer() -> bool:
	var result := _raycast_to_group("roamers", 100.0)
	if not result.is_empty():
		var node := result.collider as Node
		while node:
			if node.is_in_group("roamers"):
				if node == selected_roamer:
					deselect_roamer()
				elif selected_roamer and _can_breed(selected_roamer, node):
					_initiate_breed(selected_roamer, node)
				else:
					if selected_roamer:
						deselect_roamer()
					select_roamer(node)
				return true
			node = node.get_parent()
	if selected_roamer:
		deselect_roamer()
	return false

func _direct_roamer() -> void:
	var result := _raycast(100.0)
	if result:
		selected_roamer.move_to(result.position)

func _can_breed(a, b) -> bool:
	if not a.is_bondable() or not b.is_bondable():
		return false
	if a.species_id == "" or a.species_id != b.species_id:
		return false
	if a._is_sibling(b):
		return false
	return true

func _initiate_breed(a, b) -> void:
	deselect_roamer()
	a.start_bond(b)

func select_roamer(roamer) -> void:
	selected_roamer = roamer
	roamer.on_selected()
	roamer_ui.show_roamer(roamer)

func deselect_roamer() -> void:
	if is_instance_valid(selected_roamer):
		selected_roamer.on_deselected()
	roamer_ui.hide_roamer()
	selected_roamer = null

func _try_interact_with_zone_marker() -> bool:
	var result := _raycast(100.0)
	if not result:
		return false
	var node := result.collider as Node
	while node:
		if node.is_in_group("zone_markers"):
			var garden := get_parent()
			if garden and garden.has_method("show_zone_unlock_popup"):
				garden.show_zone_unlock_popup()
			return true
		node = node.get_parent()
	return false

func try_interact_with_trader() -> void:
	var result := _raycast_to_group("npcs", 100.0)
	if result.is_empty():
		return
	var node := result.collider as Node
	while node:
		if node.name == "Maren" or node.is_in_group("torvald") or node.is_in_group("gus") or node.is_in_group("doc_birtle"):
			if node.has_method("show_selection_ring"):
				node.show_selection_ring()
			roamer_ui.open_shop(node)
			return
		node = node.get_parent()

func _spawn_calm_splash(pos: Vector3) -> void:
	# Simple GPUParticles3D burst — gentle blue-white dots
	var p := GPUParticles3D.new()
	p.emitting   = true
	p.one_shot   = true
	p.explosiveness = 0.9
	p.amount     = 18
	p.lifetime   = 0.8
	p.global_position = pos + Vector3(0, 0.5, 0)
	var mat := ParticleProcessMaterial.new()
	mat.direction        = Vector3(0, 1, 0)
	mat.spread           = 60.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.0
	mat.gravity          = Vector3(0, -4, 0)
	mat.color            = Color(0.5, 0.85, 1.0, 0.9)
	p.process_material   = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	p.draw_pass_1 = mesh
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
