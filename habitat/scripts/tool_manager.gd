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
var original_material: Material
var placement_item: String = ""
var berry_bush_scene: PackedScene = preload("res://scenes/berry_bush.tscn")
var tree_scene: PackedScene = preload("res://scenes/tree.tscn")
var base_level: float = 0.0
var max_dig_depth: float = -2.0
var can_raise_terrain: bool = false
var ground_mesh: MeshInstance3D
var mesh_data_tool: MeshDataTool
var array_mesh: ArrayMesh
var starter_area_size: float = 40.0
var shelter_scene: PackedScene    = preload("res://scenes/shelter.tscn")
var wildgrass_scene: PackedScene  = preload("res://scenes/wildgrass.tscn")
var cosy_burrow_scene: PackedScene = preload("res://scenes/cosy_burrow.tscn")
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
var _terrain_mat: ShaderMaterial = null
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
	"Basic Shelter":    3.0,
	"Wildgrass Seeds":  0.8,
	"Cosy Burrow":      2.4,
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
	var new_r: float = PLACEMENT_RADII.get(item_name, 1.5)
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
	ground_mesh = get_parent().get_node("Ground")
	await get_tree().process_frame
	await get_tree().process_frame
	build_mesh_data_tool()
	apply_terrain_colours()
	_create_water_plane()
	snap_all_statics()
	print("Mesh data tool built successfully")

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

## After terrain deformation, check whether dug vertices cross the water level
## and paint / clear the water mask accordingly.
func _update_water_mask(center: Vector3, radius: float) -> void:
	var any_submerged := false
	for i in range(mesh_data_tool.get_vertex_count()):
		var v := mesh_data_tool.get_vertex(i)
		var dx := v.x - center.x
		var dz := v.z - center.z
		if dx * dx + dz * dz < radius * radius and v.y < WATER_LEVEL:
			any_submerged = true
			break
	if any_submerged:
		SplatMapManager.paint_water_circle(center, radius)
		# Paint a mud/dirt transition ring around the water edge
		SplatMapManager.paint_circle(center, SplatMapManager.LAYER_MUD, radius * 2.0, 0.6)
	else:
		# Check if all vertices in range are back above water (terrain was raised)
		var all_above := true
		for i in range(mesh_data_tool.get_vertex_count()):
			var v := mesh_data_tool.get_vertex(i)
			var dx := v.x - center.x
			var dz := v.z - center.z
			if dx * dx + dz * dz < radius * radius and v.y < WATER_LEVEL:
				all_above = false
				break
		if all_above:
			SplatMapManager.clear_water_circle(center, radius)
			# Restore grass over the mud ring when water is filled in
			SplatMapManager.paint_circle(center, SplatMapManager.LAYER_GRASS, radius * 2.2, 0.8)

func build_mesh_data_tool():
	original_material = ground_mesh.get_active_material(0)
	array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		ground_mesh.mesh.surface_get_arrays(0)
	)
	mesh_data_tool = MeshDataTool.new()
	mesh_data_tool.create_from_surface(array_mesh, 0)
	update_ground_collision()
	

## Called by the tool wheel when the player selects a tool.
func set_active_tool(tool_id: String) -> void:
	active_tool = tool_id

func _input(event):
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

	# ── Right click — place item if one is selected ───────────────────────────
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
					WardenManager.gain_xp("bush_planted")
					last_placed = bush
					placed = true
			"Oak Sapling":
				if InventoryManager.remove_item("Oak Sapling"):
					var tree = tree_scene.instantiate()
					get_parent().add_child(tree)
					tree.global_position = result.position
					WardenManager.gain_xp("bush_planted")
					last_placed = tree
					placed = true
			"Basic Shelter":
				if InventoryManager.remove_item("Basic Shelter"):
					var shelter = shelter_scene.instantiate()
					get_parent().add_child(shelter)
					shelter.global_position = result.position
					WardenManager.gain_xp("shelter_placed")
					last_placed = shelter
					placed = true
			"Wildgrass Seeds":
				if InventoryManager.remove_item("Wildgrass Seeds"):
					var grass = wildgrass_scene.instantiate()
					get_parent().add_child(grass)
					grass.global_position = result.position
					grass.rotation.y = randf_range(0.0, TAU)
					grass.add_to_group("debris")
					WardenManager.gain_xp("bush_planted")
					last_placed = grass
					placed = true
			"Cosy Burrow":
				if InventoryManager.remove_item("Cosy Burrow"):
					var burrow = cosy_burrow_scene.instantiate()
					get_parent().add_child(burrow)
					burrow.global_position = result.position
					WardenManager.gain_xp("shelter_placed")
					last_placed = burrow
					placed = true
			# ── Decoratives ───────────────────────────────────────────────────
			"Flower Patch":
				if InventoryManager.remove_item("Flower Patch"):
					var item = flower_patch_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Mossy Rock":
				if InventoryManager.remove_item("Mossy Rock"):
					var item = mossy_rock_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Mushroom Cluster":
				if InventoryManager.remove_item("Mushroom Cluster"):
					var item = mushroom_cluster_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Fallen Log":
				if InventoryManager.remove_item("Fallen Log"):
					var item = fallen_log_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			# ── Lighting ──────────────────────────────────────────────────────
			"Garden Lantern":
				if InventoryManager.remove_item("Garden Lantern"):
					var item = garden_lantern_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Glowing Mushroom":
				if InventoryManager.remove_item("Glowing Mushroom"):
					var item = glowing_mushroom_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Firefly Jar":
				if InventoryManager.remove_item("Firefly Jar"):
					var item = firefly_jar_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
			"Moss Torch":
				if InventoryManager.remove_item("Moss Torch"):
					var item = moss_torch_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					last_placed = item; placed = true
		if placed:
			if last_placed:
				last_placed.add_to_group("placeable_items")
			placement_item = ""
			AudioManager.play_place()
			var ui = get_parent().get_node_or_null("RoamerUI")
			if ui:
				ui.placement_label.modulate = Color(1, 1, 1, 1)
				ui.placement_label.text = ""


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
			_deform_circle(_pending_hit_pos, DIG_RADIUS, DIG_STRENGTH, false)
		"fill":
			# Strong fill — VP style, fills a crater in 1-2 clicks
			_deform_circle(_pending_hit_pos, DIG_RADIUS * 2.5, 12.0, true)
		"pond":
			_deform_circle(_pending_hit_pos, POND_RADIUS, absf(POND_DEPTH) * 2.2, false)
		"smash":
			if is_instance_valid(_pending_smash_item):
				var cursor := get_parent().get_node_or_null("PlayerCursor")
				if cursor:
					cursor.hit_world_item(_pending_smash_item)
			_pending_smash_item = null

func _deform_circle(hit_pos: Vector3, radius: float, strength: float, is_raise: bool) -> void:
	var half := starter_area_size / 2.0
	if absf(hit_pos.x) > half or absf(hit_pos.z) > half:
		return
	WardenManager.gain_xp("terrain_shaped")
	var direction := 1.0 if is_raise else -1.0
	# Vertex positions are in mesh local space which matches world XZ when the
	# Ground node has no scale/offset (standard setup). Compare directly.
	var affected := false
	for i in range(mesh_data_tool.get_vertex_count()):
		var vertex := mesh_data_tool.get_vertex(i)
		var dist: float = Vector2(vertex.x - hit_pos.x, vertex.z - hit_pos.z).length()
		if dist < radius:
			var influence: float = 1.0 - (dist / radius)
			influence = influence * influence   # smooth falloff
			var new_y: float = vertex.y + direction * strength * influence
			if direction < 0:
				new_y = maxf(new_y, POND_DEPTH)
			else:
				new_y = minf(new_y, base_level)
			vertex.y = new_y
			mesh_data_tool.set_vertex(i, vertex)
			affected = true
	if not affected:
		return
	array_mesh.clear_surfaces()
	mesh_data_tool.commit_to_surface(array_mesh)
	ground_mesh.mesh = array_mesh.duplicate()
	apply_terrain_colours()
	_update_water_mask(hit_pos, radius)
	update_ground_collision()
	snap_all_statics()
	var garden := get_parent()
	if garden.has_method("update_boundary_heights"):
		garden.update_boundary_heights()

	# ── Paint splat map to match terrain action ────────────────────────────────
	if is_raise:
		# Filling: restore grass over the filled area
		SplatMapManager.paint_circle(hit_pos, SplatMapManager.LAYER_GRASS, radius, 0.7)
	else:
		# Digging: expose dirt
		SplatMapManager.paint_circle(hit_pos, SplatMapManager.LAYER_DIRT, radius, 1.0)


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
	var _vertices_affected := 0

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
			_vertices_affected += 1

	array_mesh.clear_surfaces()
	mesh_data_tool.commit_to_surface(array_mesh)
	ground_mesh.mesh = array_mesh.duplicate()
	apply_terrain_colours()
	_update_water_mask(hit_pos, spade_radius)
	update_ground_collision()
	snap_all_statics()
	# Immediately re-conform the boundary to the new terrain shape
	var garden = get_parent()
	if garden.has_method("update_boundary_heights"):
		garden.update_boundary_heights()

func set_placement_item(item_name: String):
	placement_item = item_name
	print("Ready to place: ", item_name)

func apply_terrain_colours():
	# Read vertex positions and index buffer from the current (deformed) mesh
	var src_arrays := ground_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array    = src_arrays[Mesh.ARRAY_INDEX]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if indices.size() > 0:
		for k in range(0, indices.size(), 3):
			for j in range(3):
				st.add_vertex(vertices[indices[k + j]])
	else:
		for vi in range(vertices.size()):
			st.add_vertex(vertices[vi])
	st.generate_normals()
	ground_mesh.mesh = st.commit()

	# Create ShaderMaterial once, then keep it alive so splat_map is preserved.
	if _terrain_mat == null:
		_terrain_mat = ShaderMaterial.new()
		_terrain_mat.shader = load("res://shaders/terrain_splat.gdshader")

		# ── Assign textures from the Stylized_GrassAndDirt pack ───────────────
		var base := "res://Stylized_GrassAndDirt/JPEG/"
		_terrain_mat.set_shader_parameter("grass_albedo",
			load(base + "Stylized_HandpaintedGrass_01/Stylized_HandpaintedGrass_01_basecolor.jpg"))
		_terrain_mat.set_shader_parameter("grass_normal",
			load(base + "Stylized_HandpaintedGrass_01/Stylized_HandpaintedGrass_01_normalogl.jpg"))
		_terrain_mat.set_shader_parameter("grass_height",
			load(base + "Stylized_HandpaintedGrass_01/Stylized_HandpaintedGrass_01_height.jpg"))
		_terrain_mat.set_shader_parameter("grass_albedo2",
			load(base + "Stylized_HandpaintedGrass_02/Stylized_HandpaintedGrass_02_basecolor.jpg"))
		_terrain_mat.set_shader_parameter("grass_normal2",
			load(base + "Stylized_HandpaintedGrass_02/Stylized_HandpaintedGrass_02_normalogl.jpg"))
		_terrain_mat.set_shader_parameter("dirt_albedo",
			load(base + "Stylized_HandpaintedDirt_01/Stylized_HandpaintedDirt_01_basecolor.jpg"))
		_terrain_mat.set_shader_parameter("dirt_normal",
			load(base + "Stylized_HandpaintedDirt_01/Stylized_HandpaintedDirt_01_normalogl.jpg"))
		_terrain_mat.set_shader_parameter("dirt_height",
			load(base + "Stylized_HandpaintedDirt_01/Stylized_HandpaintedDirt_01_height.jpg"))
		_terrain_mat.set_shader_parameter("mud_albedo",
			load(base + "Stylized_HandpaintedSand_01/Stylized_HandpaintedSand_01_basecolor.jpg"))
		_terrain_mat.set_shader_parameter("mud_normal",
			load(base + "Stylized_HandpaintedSand_01/Stylized_HandpaintedSand_01_normalogl.jpg"))
		_terrain_mat.set_shader_parameter("mud_height",
			load(base + "Stylized_HandpaintedSand_01/Stylized_HandpaintedSand_01_height.jpg"))

		# Tiling scale
		_terrain_mat.set_shader_parameter("grass_scale", 0.22)
		_terrain_mat.set_shader_parameter("dirt_scale",  0.22)
		_terrain_mat.set_shader_parameter("mud_scale",   0.20)

		# Colour tints — multiply against each texture to correct hue/saturation
		# Grass: reduce the lime-yellow, push toward a richer softer green
		_terrain_mat.set_shader_parameter("grass_tint", Color(0.72, 0.88, 0.56))
		_terrain_mat.set_shader_parameter("dirt_tint",  Color(1.00, 1.00, 1.00))
		_terrain_mat.set_shader_parameter("mud_tint",   Color(1.00, 1.00, 1.00))

	# Always refresh the splat map texture (it changes as the player paints terrain)
	_terrain_mat.set_shader_parameter("splat_map", SplatMapManager.get_texture())
	ground_mesh.set_surface_override_material(0, _terrain_mat)

func update_ground_collision():
	# Update the shape in-place — no queue_free/await so there's never a
	# frame gap where ground collision is absent (which causes is_on_floor()
	# to flicker and roamers to fall through).
	var static_body = ground_mesh.get_node_or_null("StaticBody3D")
	if not static_body:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		ground_mesh.add_child(static_body)

	var collision_shape = static_body.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)

	collision_shape.shape = ground_mesh.mesh.create_trimesh_shape()

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
