extends Node3D

enum Tool { NONE, SPADE }

var current_tool = Tool.SPADE
var spade_radius: float = 3.0
var spade_strength: float = 2.0
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
	snap_all_statics()
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
	update_ground_collision()
	

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
		# ── Clearance check ────────────────────────────────────────────────────
		if not is_placement_clear(result.position, placement_item):
			AudioManager.play_error()
			var ui_err = get_parent().get_node_or_null("RoamerUI")
			if ui_err:
				ui_err.placement_label.modulate = Color(1.0, 0.3, 0.3)
				ui_err.placement_label.text = "❌ Too close to another object!"
			return
		# ── Place ──────────────────────────────────────────────────────────────
		var placed = false
		match placement_item:
			"Berry Seeds":
				if InventoryManager.remove_item("Berry Seeds"):
					var bush = berry_bush_scene.instantiate()
					get_parent().add_child(bush)
					bush.global_position = result.position
					WardenManager.gain_xp("bush_planted")
					placed = true
			"Oak Sapling":
				if InventoryManager.remove_item("Oak Sapling"):
					var tree = tree_scene.instantiate()
					get_parent().add_child(tree)
					tree.global_position = result.position
					WardenManager.gain_xp("bush_planted")
					placed = true
			"Basic Shelter":
				if InventoryManager.remove_item("Basic Shelter"):
					var shelter = shelter_scene.instantiate()
					get_parent().add_child(shelter)
					shelter.global_position = result.position
					WardenManager.gain_xp("bush_planted")
					placed = true
			"Wildgrass Seeds":
				if InventoryManager.remove_item("Wildgrass Seeds"):
					var grass = wildgrass_scene.instantiate()
					get_parent().add_child(grass)
					grass.global_position = result.position
					grass.rotation.y = randf_range(0.0, TAU)
					grass.add_to_group("debris")
					WardenManager.gain_xp("bush_planted")
					placed = true
			"Cosy Burrow":
				if InventoryManager.remove_item("Cosy Burrow"):
					var burrow = cosy_burrow_scene.instantiate()
					get_parent().add_child(burrow)
					burrow.global_position = result.position
					WardenManager.gain_xp("bush_planted")
					placed = true
			# ── Decoratives ───────────────────────────────────────────────────
			"Flower Patch":
				if InventoryManager.remove_item("Flower Patch"):
					var item = flower_patch_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					placed = true
			"Mossy Rock":
				if InventoryManager.remove_item("Mossy Rock"):
					var item = mossy_rock_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					placed = true
			"Mushroom Cluster":
				if InventoryManager.remove_item("Mushroom Cluster"):
					var item = mushroom_cluster_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					placed = true
			"Fallen Log":
				if InventoryManager.remove_item("Fallen Log"):
					var item = fallen_log_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					placed = true
			# ── Lighting ──────────────────────────────────────────────────────
			"Garden Lantern":
				if InventoryManager.remove_item("Garden Lantern"):
					var item = garden_lantern_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					placed = true
			"Glowing Mushroom":
				if InventoryManager.remove_item("Glowing Mushroom"):
					var item = glowing_mushroom_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					placed = true
			"Firefly Jar":
				if InventoryManager.remove_item("Firefly Jar"):
					var item = firefly_jar_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					WardenManager.gain_xp("decor_placed")
					placed = true
			"Moss Torch":
				if InventoryManager.remove_item("Moss Torch"):
					var item = moss_torch_scene.instantiate()
					get_parent().add_child(item)
					item.global_position = result.position
					item.rotation.y = randf_range(0.0, TAU)
					WardenManager.gain_xp("decor_placed")
					placed = true
		if placed:
			placement_item = ""
			AudioManager.play_place()
			var ui = get_parent().get_node_or_null("RoamerUI")
			if ui:
				ui.placement_label.modulate = Color(1, 1, 1, 1)
				ui.placement_label.text = ""


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
	# Read vertex positions from the current (deformed) mesh
	var src_arrays = ground_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array    = src_arrays[Mesh.ARRAY_INDEX]

	# Compute height-based vertex colour for each vertex
	var vert_colors: Array[Color] = []
	vert_colors.resize(vertices.size())
	for i in range(vertices.size()):
		var y := vertices[i].y
		var colour: Color
		if y > 0.1:
			var t: float = clamp(y / 1.5, 0.0, 1.0)
			colour = Color(0.35, 0.50, 0.20).lerp(Color(0.08, 0.18, 0.05), t)
		elif y < -0.1:
			var t: float = clamp(abs(y) / 2.0, 0.0, 1.0)
			colour = Color(0.55, 0.40, 0.22).lerp(Color(0.18, 0.10, 0.05), t)
		else:
			colour = Color(0.29, 0.36, 0.18)
		vert_colors[i] = colour

	# Rebuild via SurfaceTool so generate_normals() recalculates correct normals
	# after any terrain deformation (MeshDataTool keeps the original flat normals).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if indices.size() > 0:
		for k in range(0, indices.size(), 3):
			for j in range(3):
				var vi := indices[k + j]
				st.set_color(vert_colors[vi])
				st.add_vertex(vertices[vi])
	else:
		for vi in range(vertices.size()):
			st.set_color(vert_colors[vi])
			st.add_vertex(vertices[vi])
	st.generate_normals()
	ground_mesh.mesh = st.commit()

	# Create ShaderMaterial once, reuse every subsequent call
	if _terrain_mat == null:
		_terrain_mat = ShaderMaterial.new()
		_terrain_mat.shader = load("res://shaders/terrain.gdshader")
	ground_mesh.set_surface_override_material(0, _terrain_mat)
	# NOTE: update_ground_collision() is called by deform_terrain() after this returns.

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
