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
	get_parent().add_child(creature)
	creature.global_position = global_position + Vector3(0, 1.0, 0)

	# Stamp family data — creature starts as a child, can't breed until grown
	creature.is_adult = false
	creature.parent_a_id = parent_a_id
	creature.parent_b_id = parent_b_id
	creature.family_id = family_id
	creature.scale = Vector3(0.6, 0.6, 0.6)

	CurrencyManager.add_dewdrops(15.0)
	WardenManager.gain_xp("egg_hatched")
	print("An egg hatched! ", creature.name, " is a child of family ", family_id)
	queue_free()
