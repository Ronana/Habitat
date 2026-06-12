extends Node3D

@onready var roamer_ui = $"../RoamerUI"

# ── Selection state ───────────────────────────────────────────────────────────
var selected_roamer                    = null
var selected_item   : Node3D           = null
var _item_moving    : bool             = false
var _pre_focus_zoom : float            = -1.0

# ── Only items within this XZ distance from origin are selectable ─────────────
const GARDEN_HALF := 20.0

# ── Cursor world position (shared with roamers) ───────────────────────────────
var cursor_world_pos     : Vector3 = Vector3.ZERO
var _cursor_timer        : float   = 0.0

# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_cursor_timer -= delta
	if _cursor_timer <= 0.0:
		_cursor_timer = 0.1
		_refresh_cursor()

	# Dragging a placed item — snap it to terrain under cursor
	if _item_moving and is_instance_valid(selected_item):
		selected_item.global_position = cursor_world_pos

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
		cursor_world_pos = result.position

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
	# Double-click feeds a selected roamer
	if is_double and selected_roamer:
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

	# ── Hand / default: select roamer, then item, then trader ─────────────
	var hit_roamer := try_select_roamer()
	if not hit_roamer:
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
					# Second click on a placeable item → enter move mode
					if item.is_in_group("placeable_items"):
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

# ── Move mode ─────────────────────────────────────────────────────────────────

func _start_move(item: Node3D) -> void:
	_item_moving = true
	_set_collision(item, false)

func _confirm_move() -> void:
	if is_instance_valid(selected_item):
		_set_collision(selected_item, true)
	_item_moving = false

func _cancel_move() -> void:
	if is_instance_valid(selected_item):
		_set_collision(selected_item, true)
	_item_moving = false

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
			node.is_in_group("shelters"))

func _in_garden(item: Node3D) -> bool:
	return (abs(item.global_position.x) <= GARDEN_HALF and
			abs(item.global_position.z) <= GARDEN_HALF)

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
	var result := _raycast(100.0)
	if result:
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
	selected_roamer.on_deselected()
	roamer_ui.hide_roamer()
	selected_roamer = null

func try_interact_with_trader() -> void:
	var result := _raycast(100.0)
	if not result:
		return
	var node := result.collider as Node
	while node:
		if node.name == "Maren":
			node.show_selection_ring()
			roamer_ui.open_shop(node)
			return
		node = node.get_parent()
