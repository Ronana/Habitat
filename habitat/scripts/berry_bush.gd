extends Node3D

var food_value: float = 0.3
var eat_cooldown: float = 3.0
var cooldown_timer: float = 0.0
var is_depleted: bool = false
var eat_count: int = 0
var max_eats: int = 5
var regrow_time: float = 20.0
var regrow_timer: float = 0.0

# Season colours: [bush_colour, berry_colour]
const SEASON_COLOURS = {
	0: [Color(0.22, 0.46, 0.14, 1), Color(0.80, 0.40, 0.55, 1)],  # Spring — fresh green, pink blossom
	1: [Color(0.15, 0.38, 0.10, 1), Color(0.55, 0.10, 0.10, 1)],  # Summer — rich green, deep red
	2: [Color(0.52, 0.34, 0.10, 1), Color(0.65, 0.22, 0.08, 1)],  # Autumn — amber, burnt orange
	3: [Color(0.28, 0.24, 0.18, 1), Color(0.30, 0.26, 0.22, 1)],  # Winter — bare grey-brown
}

var _growth: Node = null

func _ready():
	add_to_group("food")
	add_to_group("placeable_items")
	# Hardy Stock upgrade — bush sustains more eats before depleting
	if GusManager.has_upgrade(GusManager.UPGRADE_HARDY_STOCK):
		max_eats = roundi(max_eats / GusManager.bush_depletion_mult())
	# Click/selection body — lets raycast hit this item
	var _cb := StaticBody3D.new()
	var _cs := CollisionShape3D.new()
	var _sp := SphereShape3D.new()
	_sp.radius = 1.1
	_cs.shape  = _sp
	_cb.add_child(_cs)
	add_child(_cb)
	# Plant growth component
	_growth = load("res://scripts/plant_growth.gd").new()
	_growth.name = "PlantGrowth"
	add_child(_growth)
	_growth.stage_changed.connect(_on_growth_stage_changed)
	_growth.plant_wilting.connect(_on_plant_wilting)
	_growth.plant_recovered.connect(_on_plant_recovered)
	_growth.plant_died.connect(_on_plant_died)
	$FoodArea.body_entered.connect(_on_body_entered)
	SeasonManager.season_changed.connect(_on_season_changed)
	_apply_season_colours(SeasonManager.current_season)

func _on_season_changed(season: int):
	_apply_season_colours(season)

func _apply_season_colours(season: int):
	var colours = SEASON_COLOURS.get(season, SEASON_COLOURS[0])
	_tint_all_meshes($Bush, colours[0])     # gltf root — walk its children
	_set_mesh_colour($Berries, colours[1])  # direct MeshInstance3D

# Recursively tint all MeshInstance3D nodes inside a node hierarchy.
# Needed because gltf assets import as Node3D with MeshInstance3D children.
func _tint_all_meshes(node: Node, colour: Color) -> void:
	if node is MeshInstance3D:
		_set_mesh_colour(node as MeshInstance3D, colour)
	for child in node.get_children():
		_tint_all_meshes(child, colour)

func _set_mesh_colour(node: MeshInstance3D, colour: Color):
	var mat: StandardMaterial3D = node.get_surface_override_material(0)
	if mat == null:
		var base = node.mesh.surface_get_material(0) if node.mesh else null
		mat = (base.duplicate() as StandardMaterial3D) if base is StandardMaterial3D else StandardMaterial3D.new()
	else:
		mat = mat.duplicate() as StandardMaterial3D
	mat.albedo_color = colour
	node.set_surface_override_material(0, mat)

func _process(delta):
	if cooldown_timer > 0:
		cooldown_timer -= delta

	if is_depleted:
		regrow_timer += delta
		if regrow_timer >= regrow_time:
			regrow()

func _on_body_entered(body):
	if is_depleted or cooldown_timer > 0:
		return
	# Only mature plants can feed roamers
	if _growth and not _growth.is_mature():
		return
	var node = body
	while node:
		if node.is_in_group("roamers"):
			feed_roamer(node)
			return
		node = node.get_parent()

func feed_roamer(roamer):
	roamer.feed(food_value)
	cooldown_timer = eat_cooldown
	eat_count += 1
	_shiver()
	if eat_count >= max_eats:
		deplete()

## Quick shiver when a roamer eats from the bush.
func _shiver() -> void:
	var bush := get_node_or_null("Bush") as Node3D
	if not bush:
		return
	# Always snap to 0 before animating so repeated calls can't accumulate rotation drift
	bush.rotation.z = 0.0
	var t := create_tween()
	t.tween_property(bush, "rotation:z",  0.12, 0.06).set_trans(Tween.TRANS_SINE)
	t.tween_property(bush, "rotation:z", -0.10, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(bush, "rotation:z",  0.07, 0.06).set_trans(Tween.TRANS_SINE)
	t.tween_property(bush, "rotation:z",  0.0,  0.08).set_trans(Tween.TRANS_SINE)

func deplete():
	is_depleted = true
	regrow_timer = 0.0
	$Berries.visible = false

func regrow():
	is_depleted = false
	eat_count = 0
	regrow_timer = 0.0
	$Berries.visible = true

# ── Watering Can API ──────────────────────────────────────────────────────────

func water() -> void:
	if _growth:
		_growth.water()
		_shiver()

# ── Plant Growth callbacks ────────────────────────────────────────────────────

func _on_growth_stage_changed(_new_stage: int) -> void:
	# Re-register meshes after scale change so tint works
	if _growth:
		var meshes: Array = []
		_collect_meshes(self, meshes)
		_growth.register_meshes(meshes)

func _on_plant_wilting() -> void:
	# Turn the bush visibly yellow-brown via tint (handled by _apply_health_tint in component)
	pass

func _on_plant_recovered() -> void:
	_apply_season_colours(SeasonManager.current_season)

func _on_plant_died() -> void:
	# Wither animation then remove
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.6).set_trans(Tween.TRANS_EXPO)
	tw.tween_callback(queue_free)

func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

# ── Growth stage/progress accessors (used by save_manager) ───────────────────

func get_growth_stage() -> int:
	return _growth.stage if _growth else 0

func get_growth_progress() -> float:
	return _growth.growth_progress if _growth else 0.0

func restore_growth(stage: int, progress: float) -> void:
	if not _growth:
		return
	_growth.stage           = stage
	_growth.growth_progress = progress
	_growth._apply_stage_scale(false)
