extends Node3D

enum Tool { NONE, SPADE }

# ── Active tool from the wheel ─────────────────────────────────────────────────
# "hand"   = normal roamer/item interaction (no terrain editing on plain click)
# "shovel" = left-click digs, right-click raises terrain
var active_tool: String = "hand"

var current_tool = Tool.SPADE
var spade_radius: float = 1.2
var spade_strength: float = 1.8
var raise_terrain: bool = true
var placement_item: String = ""
var _fence_last_pos: Vector3   = Vector3.INF  # tracks last-placed fence for auto-orient
var _fence_manual_rot: float   = 0.0          # R-key manual rotation offset (radians)
var berry_bush_scene: PackedScene = preload("res://scenes/berry_bush.tscn")
var tree_scene: PackedScene = preload("res://scenes/tree.tscn")
var base_level: float = 0.0
var max_dig_depth: float = -2.0
var can_raise_terrain: bool = false
var terrain3d: Terrain3D        # Terrain3D plugin node (replaces old Ground MeshInstance3D)
var starter_area_size: float = 40.0
var glowfox_den_scene: PackedScene       = preload("res://scenes/glowfox_den.tscn")
var mossdeer_hollow_scene: PackedScene   = preload("res://scenes/mossdeer_hollow.tscn")
var stoneback_cave_scene: PackedScene    = preload("res://scenes/stoneback_cave.tscn")
var thornmouse_burrow_scene: PackedScene = preload("res://scenes/thornmouse_burrow.tscn")
var emberowl_roost_scene: PackedScene    = preload("res://scenes/emberowl_roost.tscn")
var crystalback_grotto_scene: PackedScene = preload("res://scenes/crystalback_grotto.tscn")
var wildgrass_scene: PackedScene       = preload("res://scenes/wildgrass.tscn")
var fence_panel_scene: PackedScene = preload("res://scenes/fence_panel.tscn")
# Decoratives
var flower_patch_scene: PackedScene     = preload("res://scenes/flower_patch.tscn")
var mossy_rock_scene: PackedScene       = preload("res://scenes/mossy_rock.tscn")
var mushroom_cluster_scene: PackedScene = preload("res://scenes/mushroom_cluster.tscn")
var fallen_log_scene: PackedScene       = preload("res://scenes/fallen_log.tscn")
# Lighting
var garden_lantern_scene: PackedScene   = preload("res://scenes/garden_lantern.tscn")
var glowing_mushroom_scene: PackedScene = preload("res://scenes/glowing_mushroom.tscn")
var firefly_jar_scene: PackedScene      = preload("res://scenes/firefly_jar.tscn")
var moss_torch_scene: PackedScene       = preload("res://scenes/moss_torch.tscn")
# Torvald commissions
var stone_bench_scene: PackedScene      = preload("res://scenes/stone_bench.tscn")
var mossy_fountain_scene: PackedScene   = preload("res://scenes/mossy_fountain.tscn")
var rune_totem_scene: PackedScene       = preload("res://scenes/rune_totem.tscn")
var fire_ring_scene: PackedScene        = preload("res://scenes/fire_ring.tscn")
var stone_archway_scene: PackedScene    = preload("res://scenes/stone_archway.tscn")
var lantern_arch_scene: PackedScene     = preload("res://scenes/lantern_arch.tscn")
var _shovel_menu: CanvasLayer = null
var _pending_hit_pos: Vector3 = Vector3.ZERO
var _pending_smash_item: Node3D = null
var _water_plane: MeshInstance3D = null
var _water_mat:   ShaderMaterial = null

# Y height at which standing water appears when terrain is dug below this level
const WATER_LEVEL := -0.65

# Shovel brush settings — tight circle for precision
const DIG_RADIUS   := 1.2
const DIG_STRENGTH := 1.8
const POND_RADIUS  := 2.5
const POND_DEPTH   := -3.2

# Radius (world units) that must be clear around the placement point per item
const PLACEMENT_RADII: Dictionary = {
	"Berry Seeds":      1.1,
	"Oak Sapling":      2.0,
	"GlowFox Den":      2.8,
	"MossDeer Hollow":  3.2,
	"Stoneback Cave":   2.8,
	"Thornmouse Burrow": 2.2,
	"Emberowl Roost":   2.5,
	"Crystalback Grotto": 3.0,
	"Wildgrass Seeds":  0.8,
	# Decoratives
	"Flower Patch":     0.6,
	"Mossy Rock":       0.9,
	"Mushroom Cluster": 0.7,
	"Fallen Log":       1.1,
	# Lighting
	"Garden Lantern":   0.7,
	"Glowing Mushroom": 0.5,
	"Firefly Jar":      0.4,
	"Moss Torch":       0.5,
	# Fencing (small radius — can be placed close together)
	"Fence Panel":      0.28,
	# Torvald commissions
	"Stone Bench":      1.0,
	"Mossy Fountain":   1.1,
	"Rune Totem":       0.7,
	"Fire Ring":        1.1,
	"Stone Archway":    1.6,
	"Lantern Arch":     1.5,
}
# How much space each existing object group occupies
const OBJECT_GROUP_RADII: Dictionary = {
	"food":        1.1,
	"trees":       2.0,
	"shelters":    3.0,
	"debris":      0.8,
	"decoratives": 0.6,
}

# Exposed publicly so ground_cursor can poll it for the preview colour.
func is_placement_clear(pos: Vector3, item_name: String) -> bool:
	var new_r: float = PLACEMENT_RADII.get(item_name, 1.5) * GusManager.placement_radius_mult()
	for group in OBJECT_GROUP_RADII:
		var existing_r: float = OBJECT_GROUP_RADII[group]
		var min_dist_sq: float = (new_r + existing_r) * (new_r + existing_r)
		for node in get_tree().get_nodes_in_group(group):
			var dx: float = pos.x - (node as Node3D).global_position.x
			var dz: float = pos.z - (node as Node3D).global_position.z
			if dx * dx + dz * dz < min_dist_sq:
				return false
	return true

func _ready():
	# Terrain3D node must be added to the scene manually (see setup guide).
	# The node should be named "Terrain3D" and be a child of the garden root.
	terrain3d = get_parent().get_node_or_null("Terrain3D")
	if terrain3d == null:
		push_warning("ToolManager: No Terrain3D node found! Add a Terrain3D node to the scene named 'Terrain3D'.")
	# Wait for the parent scene to finish adding all its children before we
	# try to add_child ourselves (avoids "parent is busy" errors).
	await get_tree().process_frame
	await get_tree().process_frame
	_create_water_plane()
	snap_all_statics()

	# Spawn shovel context menu
	_shovel_menu = load("res://scripts/shovel_menu.gd").new()
	get_parent().add_child(_shovel_menu)
	_shovel_menu.action_selected.connect(_on_shovel_action)

func _create_water_plane() -> void:
	_water_plane = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(starter_area_size, starter_area_size)
	_water_plane.mesh = quad
	_water_plane.position = Vector3(0.0, WATER_LEVEL, 0.0)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water_plane.gdshader")
	_water_mat.set_shader_parameter("water_mask", SplatMapManager.get_water_texture())
	# Must match SplatMapManager's WORLD_ORIGIN / WORLD_SIZE constants
	_water_mat.set_shader_parameter("world_origin", Vector2(-75.0, -75.0))
	_water_mat.set_shader_parameter("world_size",   Vector2(150.0, 150.0))
	_water_plane.set_surface_override_material(0, _water_mat)
	get_parent().add_child(_water_plane)

## After terrain deformation, check whether any dug point is below water level
## and paint / clear the water mask accordingly.
## Uses Terrain3D height queries instead of MeshDataTool vertex iteration.
func _update_water_mask(center: Vector3, radius: float) -> void:
	if terrain3d == null or not is_instance_valid(terrain3d):
		return
	var step := 1.0   # sample every 1 world unit — matches default vertex_spacing
	var r2    := radius * radius
	var any_submerged := false

	var x := center.x - radius
	while x <= center.x + radius:
		var z := center.z - radius
		while z <= center.z + radius:
			var dx := x - center.x
			var dz := z - center.z
			if dx * dx + dz * dz <= r2:
				var h := terrain3d.data.get_height(Vector3(x, 0.0, z))
				if not is_nan(h) and h < WATER_LEVEL:
					any_submerged = true
					break
			z += step
		if any_submerged:
			break
		x += step

	if any_submerged:
		SplatMapManager.paint_water_circle(center, radius)
		SplatMapManager.paint_circle(center, SplatMapManager.LAYER_MUD, radius * 2.0, 0.6)
	else:
		# Re-scan: if everything is back above water, clear the mask
		var all_above := true
		x = center.x - radius
		while x <= center.x + radius:
			var z := center.z - radius
			while z <= center.z + radius:
				var dx := x - center.x
				var dz := z - center.z
				if dx * dx + dz * dz <= r2:
					var h := terrain3d.data.get_height(Vector3(x, 0.0, z))
					if not is_nan(h) and h < WATER_LEVEL:
						all_above = false
						break
				z += step
			if not all_above:
				break
			x += step
		if all_above:
			SplatMapManager.clear_water_circle(center, radius)
			SplatMapManager.paint_circle(center, SplatMapManager.LAYER_GRASS, radius * 2.2, 0.8)


## Called by the tool wheel when the player selects a tool.
func set_active_tool(tool_id: String) -> void:
	active_tool = tool_id

func _input(event):
	# ── Fence mode keyboard shortcuts ────────────────────────────────────
	if placement_item == "Fence Panel":
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R:
				# Rotate next fence segment by 90°
				_fence_manual_rot = fmod(_fence_manual_rot + PI * 0.5, TAU)
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ESCAPE:
				# End fence mode
				placement_item   = ""
				_fence_last_pos  = Vector3.INF
				_fence_manual_rot = 0.0
				var ui_esc := get_parent().get_node_or_null("RoamerUI")
				if ui_esc:
					ui_esc.placement_label.modulate = Color(1, 1, 1, 1)
					ui_esc.placement_label.text = ""
				get_viewport().set_input_as_handled()
				return
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return

	# ── Shovel tool: left-click opens context menu at click position ──────────
	if active_tool == "shovel":
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _shovel_menu and not _shovel_menu._open:
				var hit := _raycast_terrain()
				if hit != Vector3.INF:
					_pending_hit_pos    = hit
					_pending_smash_item = _find_hittable_item()
					_shovel_menu.open(get_viewport().get_mouse_position(),
									  _pending_smash_item != null)
					# Show selection ring on shovel target before menu is confirmed
					if _pending_smash_item:
						var cursor := get_parent().get_node_or_null("PlayerCursor")
						if cursor:
							cursor.select_item(_pending_smash_item)
				get_viewport().set_input_as_handled()
			return

	# ── Watering can: left-click waters plants and roamers in range ─────────
	if active_tool == "watering_can":
		if event.button_index == MOUSE_BUTTON_LEFT:
			_do_water_action()
			get_viewport().set_input_as_handled()
			return

	# ── Right click — place item if one is selected ───────────────────────────
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if placement_item != "":
			place_item()
			get_viewport().set_input_as_handled()
			return
				
func selected_roamer_exists() -> bool:
	var cursor := get_parent().get_node_or_null("PlayerCursor")
	return cursor != null and is_instance_valid(cursor.selected_roamer)

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
		# ── Zone boundary check ───────────────────────────────────────────────
		var garden_half: float = ZoneManager.get_garden_half()
		if abs(result.position.x) > garden_half or abs(result.position.z) > garden_half:
			AudioManager.play_error()
			var ui_oor = get_parent().get_node_or_null("RoamerUI")
			if ui_oor:
				ui_oor.placement_label.modulate = Color(1.0, 0.5, 0.2)
				ui_oor.placement_label.text = "❌ Outside your garden boundary!"
			return
		# ── Clearance check ────────────────────────────────────────────────────
		if not is_placement_clear(result.position, placement_item):
			AudioManager.play_error()
			var ui_err = get_parent().get_node_or_null("RoamerUI")
			if ui_err:
				ui_err.placement_label.modulate = Color(1.0, 0.3, 0.3)
				ui_err.placement_label.text = "❌ Too close to another object!"
			return
		# ── Place ──────────────────────────────────────────────────────────────
		var placed      = false
		var last_placed : Node3D = null
		match placement_item:
			"Berry Seeds":
				if InventoryManager.remove_item("Berry Seeds"):
					var bush = berry_bush_scene.instantiate()
					get_parent().add_child(bush)
					bush.global_position = result.position
					_plant_with_anim(bush, result.position)
					WardenManager.gain_xp("bush_planted")
					last_placed = bush
					placed = true
			"Oak Sapling":
				if InventoryManager.remove_item("Oak Sapling"):
					var tree = tree_scene.instantiate()
					get_parent().add_child(tree)
					tree.global_position = result.position
					_plant_with_anim(tree, result.position, 2.2)
					WardenManager.gain_xp("bush_planted")
					last_placed = tree
					placed = true
			"GlowFox Den":
				if InventoryManager.remove_item("GlowFox Den"):
					var gf_den = glowfox_den_scene.instantiate()
					get_parent().add_child(gf_den)
					gf_den.global_position = result.position
					_popplace_anim(gf_den)
					WardenManager.gain_xp("shelter_placed")
					last_placed = gf_den
					placed = true
			"MossDeer Hollow":
				if InventoryManager.remove_item("MossDeer Hollow"):
					var md_hollow = mossdeer_hollow_scene.instantiate()
					get_parent().add_child(md_hollow)
					md_hollow.global_position = result.position
					_popplace_anim(md_hollow)
					WardenManager.gain_xp("shelter_placed")
					last_placed = md_hollow
					placed = true
			"Stoneback Cave":
				if InventoryManager.remove_item("Stoneback Cave"):
					var sb_cave = stoneback_cave_scene.instantiate()
					get_parent().add_child(sb_cave)
					sb_cave.global_position = result.position
					_popplace_anim(sb_cave)
					WardenManager.gain_xp("shelter_placed")
					last_placed = sb_cave
					placed = true
			"Thornmouse Burrow":
				if InventoryManager.remove_item("Thornmouse Burrow"):
					var tm_burrow = thornmouse_burrow_scene.instantiate()
					get_parent().add_child(tm_burrow)
					tm_burrow.global_position = result.position
					_popplace_anim(tm_burrow)
					WardenManager.gain_xp("shelter_placed")
					last_placed = tm_burrow
					placed = true
			"Emberowl Roost":
				if InventoryManager.remove_item("Emberowl Roost"):
					var eo_roost = emberowl_roost_scene.instantiate()
					get_parent().add_child(eo_roost)
					eo_roost.global_position = result.position
					_popplace_anim(eo_roost)
					WardenManager.gain_xp("shelter_placed")
					last_placed = eo_roost
					placed = true
			"Crystalback Grotto":
				if InventoryManager.remove_item("Crystalback Grotto"):
					var cb_grotto = crystalback_grotto_scene.instantiate()
					get_parent().add_child(cb_grotto)
					cb_grotto.global_position = result.position
					_popplace_anim(cb_grotto)
					WardenManager.gain_xp("shelter_placed")
					last_placed = cb_grotto
					placed = true
			"Wildgrass Seeds":
				if InventoryManager.remove_item("Wildgrass Seeds"):
					var grass = wildgrass_scene.instantiate()
					get_parent().add_child(grass)
					grass.global_position = result.position
					grass.rotation.y = randf_range(0.0, TAU)
					grass.add_to_group("debris")
					_plant_with_anim(grass, result.position, 1.4)
					WardenManager.gain_xp("bush_planted")
					last_placed = grass
					placed = true
			# ── Decoratives ───────────────────────────────────────────────────
			"Flower Patch":
				if InventoryManager.remove_item("Flower Patch"):
					var item = flower_patch_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Mossy Rock":
				if InventoryManager.remove_item("Mossy Rock"):
					var item = mossy_rock_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Mushroom Cluster":
				if InventoryManager.remove_item("Mushroom Cluster"):
					var item = mushroom_cluster_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Fallen Log":
				if InventoryManager.remove_item("Fallen Log"):
					var item = fallen_log_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			# ── Lighting ──────────────────────────────────────────────────────
			"Garden Lantern":
				if InventoryManager.remove_item("Garden Lantern"):
					var item = garden_lantern_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Glowing Mushroom":
				if InventoryManager.remove_item("Glowing Mushroom"):
					var item = glowing_mushroom_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Firefly Jar":
				if InventoryManager.remove_item("Firefly Jar"):
					var item = firefly_jar_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Moss Torch":
				if InventoryManager.remove_item("Moss Torch"):
					var item = moss_torch_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			# ── Torvald Commissions ───────────────────────────────────────────────
			"Stone Bench":
				if InventoryManager.remove_item("Stone Bench"):
					var item := stone_bench_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Mossy Fountain":
				if InventoryManager.remove_item("Mossy Fountain"):
					var item := mossy_fountain_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Rune Totem":
				if InventoryManager.remove_item("Rune Totem"):
					var item := rune_totem_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Fire Ring":
				if InventoryManager.remove_item("Fire Ring"):
					var item := fire_ring_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Stone Archway":
				if InventoryManager.remove_item("Stone Archway"):
					var item := stone_archway_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Lantern Arch":
				if InventoryManager.remove_item("Lantern Arch"):
					var item := lantern_arch_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					_popplace_anim(item)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			# ── Fencing ──────────────────────────────────────────────────────────
			"Fence Panel":
				if InventoryManager.remove_item("Fence Panel"):
					var panel = fence_panel_scene.instantiate()
					get_parent().add_child(panel)
					# Snap to 0.5-unit grid so segments align cleanly
					var fence_pos := Vector3(
						round(result.position.x * 2.0) / 2.0,
						result.position.y,
						round(result.position.z * 2.0) / 2.0)
					panel.global_position = fence_pos
					# Auto-orient toward last placed segment (nearest 90°)
					if _fence_last_pos != Vector3.INF:
						var dir2d := Vector2(fence_pos.x - _fence_last_pos.x, fence_pos.z - _fence_last_pos.z)
						if dir2d.length() > 0.1:
							var raw_ang := atan2(dir2d.x, dir2d.y)
							panel.rotation.y = round(raw_ang / (PI * 0.5)) * (PI * 0.5) + _fence_manual_rot
						else:
							panel.rotation.y = _fence_manual_rot
					else:
						panel.rotation.y = _fence_manual_rot
					_fence_last_pos = fence_pos
					_popplace_anim(panel)
					WardenManager.gain_xp("decor_placed")
					last_placed = panel; placed = true
		if placed:
			if last_placed:
				last_placed.add_to_group("placeable_items")
			# Fence mode is persistent — keep placing until player presses Escape
			if placement_item != "Fence Panel":
				placement_item = ""
				var ui_done = get_parent().get_node_or_null("RoamerUI")
				if ui_done:
					ui_done.placement_label.modulate = Color(1, 1, 1, 1)
					ui_done.placement_label.text = ""
			else:
				var ui_fence = get_parent().get_node_or_null("RoamerUI")
				if ui_fence:
					ui_fence.placement_label.modulate = Color(0.6, 0.9, 1.0, 1.0)
					ui_fence.placement_label.text = "🪵 Fence mode — right-click to place · R to rotate · Esc to finish"
			AudioManager.play_place()


## Raycast from mouse (centre + 4 offset rays) looking for a hittable world item.
## The spread makes items easier to click without needing pixel-perfect aim.
func _find_hittable_item() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return null
	var mp := get_viewport().get_mouse_position()
	# Centre + cardinal offsets (pixels) — gives ~20 px tolerance radius
	var offsets: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(18, 0), Vector2(-18, 0),
		Vector2(0, 18), Vector2(0, -18),
	]
	var space := get_world_3d().direct_space_state
	for off in offsets:
		var sample  := mp + off
		var origin  := cam.project_ray_origin(sample)
		var end     := origin + cam.project_ray_normal(sample) * 200.0
		var result  := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end))
		if not result:
			continue
		var node := result.collider as Node
		while node:
			if (node.is_in_group("debris") or node.is_in_group("trees") or
					node.is_in_group("placeable_items") or node.is_in_group("food") or
					node.is_in_group("shelters")):
				return node as Node3D
			node = node.get_parent()
	return null

func _raycast_terrain() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return Vector3.INF
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse_pos)
	var ray_end    := ray_origin + cam.project_ray_normal(mouse_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.position if result else Vector3.INF

func _on_shovel_action(action: String) -> void:
	match action:
		"dig":
			_deform_circle(_pending_hit_pos, DIG_RADIUS * GusManager.shovel_radius_mult(), DIG_STRENGTH, false)
		"fill":
			# Strong fill — VP style, fills a crater in 1-2 clicks
			_deform_circle(_pending_hit_pos, DIG_RADIUS * 2.5 * GusManager.shovel_radius_mult(), 12.0, true)
		"pond":
			_deform_circle(_pending_hit_pos, POND_RADIUS, absf(POND_DEPTH) * 2.2, false)
		"smash":
			if is_instance_valid(_pending_smash_item):
				var cursor := get_parent().get_node_or_null("PlayerCursor")
				if cursor:
					cursor.hit_world_item(_pending_smash_item)
			_pending_smash_item = null

func _deform_circle(hit_pos: Vector3, radius: float, strength: float, is_raise: bool) -> void:
	if terrain3d == null or not is_instance_valid(terrain3d):
		push_warning("ToolManager: Terrain3D node not found — cannot deform terrain.")
		return
	var half := starter_area_size / 2.0
	if absf(hit_pos.x) > half or absf(hit_pos.z) > half:
		return
	WardenManager.gain_xp("terrain_shaped")

	var direction    := 1.0 if is_raise else -1.0
	var region_size  := terrain3d.get_region_size()   # default 1024
	var v_spacing    := terrain3d.get_vertex_spacing() # default 1.0
	var step         := maxf(v_spacing, 0.5)

	# Cache of modified region heightmap images, keyed by region location Vector2i
	var dirty_regions: Dictionary = {}

	var x := hit_pos.x - radius - step
	while x <= hit_pos.x + radius + step:
		var z := hit_pos.z - radius - step
		while z <= hit_pos.z + radius + step:
			var wp  := Vector3(x, 0.0, z)
			var dist: float = Vector2(x - hit_pos.x, z - hit_pos.z).length()
			if dist <= radius:
				_sculpt_point(wp, dist, radius, direction, strength, region_size, v_spacing, dirty_regions)
			z += step
		x += step

	if dirty_regions.is_empty():
		return

	# Rebuild GPU heightmap textures for all touched regions
	terrain3d.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)

	_update_water_mask(hit_pos, radius)
	snap_all_statics()
	var garden := get_parent()
	if garden.has_method("update_boundary_heights"):
		garden.update_boundary_heights()

	if is_raise:
		SplatMapManager.paint_circle(hit_pos, SplatMapManager.LAYER_GRASS, radius, 0.7)
	else:
		SplatMapManager.paint_circle(hit_pos, SplatMapManager.LAYER_DIRT, radius, 1.0)


## Modify a single terrain heightmap pixel at the given world position.
## dirty_regions caches Image references so we only call get_map() once per region.
func _sculpt_point(
		world_pos:      Vector3,
		dist:           float,
		radius:         float,
		direction:      float,
		strength:       float,
		region_size:    int,
		v_spacing:      float,
		dirty_regions:  Dictionary) -> void:

	# get_regionp returns null if no region exists at this position
	var region: Terrain3DRegion = terrain3d.data.get_regionp(world_pos)
	if region == null:
		return

	# Current height (NaN if the region has no data there yet)
	var current_h := terrain3d.data.get_height(world_pos)
	if is_nan(current_h):
		current_h = 0.0

	# Smooth falloff: quadratic ease-in from edge → centre
	var influence := pow(1.0 - dist / radius, 2.0)
	var new_h     := current_h + direction * strength * influence * 0.05

	if direction < 0:
		new_h = maxf(new_h, POND_DEPTH)  # don't dig below pond floor
	else:
		new_h = minf(new_h, 6.0)          # can raise up to 6 m

	# ── Convert world position → pixel coordinates within the region ──────────
	var region_loc: Vector2i = terrain3d.data.get_region_location(world_pos)

	var hmap: Image
	if dirty_regions.has(region_loc):
		hmap = dirty_regions[region_loc]
	else:
		hmap = region.get_map(Terrain3DRegion.TYPE_HEIGHT)
		dirty_regions[region_loc] = hmap

	# Region world-space origin (bottom-left corner in XZ)
	var origin_x := region_loc.x * region_size * v_spacing
	var origin_z := region_loc.y * region_size * v_spacing
	var lx := clampi(int((world_pos.x - origin_x) / v_spacing), 0, region_size - 1)
	var lz := clampi(int((world_pos.z - origin_z) / v_spacing), 0, region_size - 1)

	# Terrain3D stores heights as FORMAT_RF — raw float in the R channel (metres)
	hmap.set_pixel(lx, lz, Color(new_h, 0.0, 0.0, 1.0))



func set_placement_item(item_name: String):
	# Reset fence state when switching away from fence mode
	if item_name != "Fence Panel":
		_fence_last_pos   = Vector3.INF
		_fence_manual_rot = 0.0
	placement_item = item_name

## Terrain3D handles its own normals, collision, and rendering.
## apply_terrain_colours() and update_ground_collision() are no longer needed.

func snap_all_statics():
	var space_state = get_world_3d().direct_space_state
	for group in ["shelters", "food", "debris", "trees", "decoratives"]:
		for node in get_tree().get_nodes_in_group(group):
			_snap_node_to_ground(node, space_state)
	var maren = get_parent().get_node_or_null("Maren")
	if maren:
		_snap_node_to_ground(maren, space_state)

func _snap_node_to_ground(node: Node3D, space_state):
	var from = node.global_position + Vector3(0, 10.0, 0)
	var to = node.global_position + Vector3(0, -5.0, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# Exclude ALL collision objects in this node's subtree so the ray can't
	# hit the object's own colliders and falsely report a raised terrain hit.
	query.exclude = _get_collision_rids(node)
	var result = space_state.intersect_ray(query)
	if result:
		var y_offset: float = node.get_meta("snap_y_offset", 0.0)
		node.global_position.y = result.position.y + y_offset

func _get_collision_rids(node: Node) -> Array:
	var rids: Array = []
	if node is CollisionObject3D:
		rids.append(node.get_rid())
	for child in node.get_children():
		rids.append_array(_get_collision_rids(child))
	return rids


# ── Placement animations ──────────────────────────────────────────────────────

## Full seed planting animation (Berry Seeds, Wildgrass Seeds, Oak Sapling).
## Animates only visual children (Node3D / MeshInstance3D that are NOT
## CollisionObject3D), so Jolt Physics never sees a non-uniform scaled shape.
## Call without await — runs as a fire-and-forget coroutine.
func _plant_with_anim(node: Node3D, pos: Vector3, drop_height: float = 1.8) -> void:
	# Collect visual children — skip any CollisionObject3D (Area3D, StaticBody3D …)
	var visuals: Array[Node3D] = []
	for child in node.get_children():
		if child is Node3D and not (child is CollisionObject3D):
			visuals.append(child as Node3D)

	# Keep root at scale 1 (physics bodies stay happy); hide the whole node
	node.visible = false

	# ── Build glowing seed mesh ───────────────────────────────────────────────
	var seed_mesh := MeshInstance3D.new()
	var sphere    := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	seed_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = Color(0.25, 0.75, 0.20)
	mat.emission_enabled           = true
	mat.emission                   = Color(0.35, 1.0, 0.25)
	mat.emission_energy_multiplier = 2.0
	seed_mesh.set_surface_override_material(0, mat)
	get_parent().add_child(seed_mesh)
	seed_mesh.global_position = pos + Vector3(0.0, drop_height, 0.0)

	var ground_y := pos.y

	# ── Phase 1: Drop with bounce ─────────────────────────────────────────────
	var t1 := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t1.tween_property(seed_mesh, "position:y", ground_y + 0.06, 0.42)
	await t1.finished

	# ── Phase 2: Little hop upward ────────────────────────────────────────────
	var t2 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t2.tween_property(seed_mesh, "position:y", ground_y + 0.45, 0.18)
	await t2.finished

	# ── Phase 3: Plant itself — drops and shrinks into ground ─────────────────
	var t3 := create_tween()
	t3.set_parallel(true)
	t3.tween_property(seed_mesh, "position:y", ground_y - 0.04, 0.17) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t3.tween_property(seed_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.17) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t3.finished

	seed_mesh.queue_free()
	_spawn_soil_puff(pos)

	# ── Phase 4: Reveal node; spring-grow the visual children only ────────────
	node.visible = true
	if visuals.is_empty():
		return
	for v in visuals:
		v.scale = Vector3(0.01, 0.01, 0.01)
	# TRANS_SPRING naturally overshoots to ~1.05 then settles — no non-uniform needed
	var t4 := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	t4.set_parallel(true)
	for v in visuals:
		t4.tween_property(v, "scale", Vector3(1.0, 1.0, 1.0), 0.55)


## Simple pop-in for shelters, decoratives, and lighting items.
## Same rule: animate visual children only, keep physics root at scale 1.
func _popplace_anim(node: Node3D) -> void:
	# Scale the root node so child proportions (non-uniform Transform3D scales) are preserved.
	node.scale = Vector3(0.01, 0.01, 0.01)
	var t := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector3(1.0, 1.0, 1.0), 0.38)


## Burst of small soil particles at the planting point.
func _spawn_soil_puff(pos: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.emitting                = false
	puff.one_shot                = true
	puff.amount                  = 16
	puff.lifetime                = 0.65
	puff.explosiveness           = 0.92
	puff.spread                  = 55.0
	puff.gravity                 = Vector3(0.0, -5.0, 0.0)
	puff.initial_velocity_min    = 1.2
	puff.initial_velocity_max    = 2.8
	puff.scale_amount_min        = 0.04
	puff.scale_amount_max        = 0.13
	puff.color                   = Color(0.28, 0.52, 0.14, 0.85)
	get_parent().add_child(puff)
	puff.global_position = pos + Vector3(0.0, 0.05, 0.0)
	puff.emitting = true
	await get_tree().create_timer(1.0).timeout
	puff.queue_free()

# ── Watering Can ──────────────────────────────────────────────────────────────

func _do_water_action() -> void:
	var hit_pos := _raycast_terrain()
	if hit_pos == Vector3.INF:
		return
	const WATER_RADIUS := 2.5
	var watered_any := false

	# Water plants (food group)
	for node in get_tree().get_nodes_in_group("food"):
		if not node is Node3D:
			continue
		if node.global_position.distance_to(hit_pos) <= WATER_RADIUS:
			if node.has_method("water"):
				node.water()
				watered_any = true

	# Also water decorative plants (wildgrass seeds etc.)
	for node in get_tree().get_nodes_in_group("placeable_items"):
		if not node is Node3D:
			continue
		if node.global_position.distance_to(hit_pos) <= WATER_RADIUS:
			if node.has_method("water"):
				node.water()
				watered_any = true

	# Calm agitated roamers nearby
	for node in get_tree().get_nodes_in_group("roamers"):
		if not node is Node3D:
			continue
		if node.global_position.distance_to(hit_pos) <= WATER_RADIUS:
			if node.has_method("calm_agitation"):
				node.calm_agitation()
				watered_any = true

	# Always play splash at hit position
	_spawn_water_splash(hit_pos)
	if watered_any:
		AudioManager.play_water()

func _spawn_water_splash(pos: Vector3) -> void:
	var p          := GPUParticles3D.new()
	p.emitting      = true
	p.one_shot      = true
	p.explosiveness = 0.85
	p.amount        = 24
	p.lifetime      = 0.9
	var mat                      := ParticleProcessMaterial.new()
	mat.direction                 = Vector3(0, 1, 0)
	mat.spread                    = 55.0
	mat.initial_velocity_min      = 1.2
	mat.initial_velocity_max      = 3.2
	mat.gravity                   = Vector3(0, -5.0, 0)
	mat.color                     = Color(0.35, 0.75, 1.0, 0.85)
	p.process_material            = mat
	var mesh      := SphereMesh.new()
	mesh.radius    = 0.04
	mesh.height    = 0.08
	p.draw_pass_1  = mesh
	get_parent().add_child(p)   # must be in tree before setting global_position
	p.global_position = pos + Vector3(0, 0.15, 0)
	p.finished.connect(p.queue_free)
