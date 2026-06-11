extends Node3D

var creature_scene_path: String = ""
var parent_a_id: String = ""
var parent_b_id: String = ""
var family_id: String = ""
var hatch_time: float = 20.0
var hatch_timer: float = 0.0

func _process(delta):
	hatch_timer += delta
	var scale_pulse = 1.0 + 0.05 * sin(hatch_timer * 3.0)
	scale = Vector3(scale_pulse, scale_pulse, scale_pulse)
	if hatch_timer >= hatch_time:
		hatch()

func hatch():
	if creature_scene_path == "":
		queue_free()
		return
	var creature_scene = load(creature_scene_path)
	if not creature_scene:
		queue_free()
		return
	var creature = creature_scene.instantiate()
	# Give the creature a proper species-based name before adding to the scene tree.
	# Without this Godot falls back to "@CharacterBody3D@215"-style auto-names.
	var species_name := creature_scene_path.get_file().get_basename().capitalize()
	creature.name = species_name
	# Stamp family data before add_child so _ready() doesn't overwrite roamer_uid
	creature.roamer_uid = str(Time.get_ticks_msec()) + "_" + str(randi())
	creature.is_adult = false
	creature.parent_a_id = parent_a_id
	creature.parent_b_id = parent_b_id
	creature.family_id = family_id
	creature.scale = Vector3(0.6, 0.6, 0.6)
	# Inherit traits from parents (one random trait from each parent's pool)
	creature.traits = _pick_offspring_traits()
	# Generate a name now so save_manager can persist it correctly
	creature.roamer_name = ""  # _ready() will generate one
	get_parent().add_child(creature)
	creature.global_position = global_position + Vector3(0, 1.0, 0)

	# Inherit parent's den so the offspring has a home from birth
	_try_inherit_den(creature)

	ObjectiveManager.record_hatch()
	MilestoneManager.fire("first_hatch", "New Life! 🥚", "Your first egg has hatched!")
	CurrencyManager.add_dewdrops(15.0)
	WardenManager.gain_xp("egg_hatched")
	print("An egg hatched! ", creature.name, " is a child of family ", family_id)
	queue_free()

func _pick_offspring_traits() -> Array:
	# Collect parent traits
	var parent_trait_pool: Array = []
	for roamer in get_tree().get_nodes_in_group("roamers"):
		if roamer.roamer_uid == parent_a_id or roamer.roamer_uid == parent_b_id:
			parent_trait_pool.append_array(roamer.traits)
	# 70% chance to inherit one parent trait, 30% chance for a fresh random one
	var result: Array = []
	if not parent_trait_pool.is_empty() and randf() < 0.7:
		result.append(parent_trait_pool[randi() % parent_trait_pool.size()])
	else:
		# Pick a random trait from the base TRAIT_POOL
		# Load roamer_base to access TRAIT_POOL keys
		var keys := ["shy","bold","greedy","playful","nocturnal","hardy","gentle","swift","timid","radiant"]
		result.append(keys[randi() % keys.size()])
	# 25% chance for a second trait
	if randf() < 0.25:
		var keys2 := ["shy","bold","greedy","playful","nocturnal","hardy","gentle","swift","timid","radiant"]
		keys2 = keys2.filter(func(k): return not result.has(k))
		if not keys2.is_empty():
			result.append(keys2[randi() % keys2.size()])
	return result

func _try_inherit_den(offspring):
	# Look for a parent roamer that has a shelter and matches our species
	for roamer in get_tree().get_nodes_in_group("roamers"):
		if roamer.roamer_uid == parent_a_id or roamer.roamer_uid == parent_b_id:
			if roamer.has_shelter and is_instance_valid(roamer.shelter_node):
				var den = roamer.shelter_node
				if den.has_method("can_accept") and den.can_accept(offspring):
					den.assign_roamer(offspring)
				return
