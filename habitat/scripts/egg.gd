extends Node3D

var creature_scene_path: String = ""
var parent_a_id: String = ""
var parent_b_id: String = ""
var family_id: String = ""
var hatch_time: float = 20.0
var hatch_timer: float = 0.0
var is_hatching: bool = false

func _ready() -> void:
	_wobble_loop()

func _process(delta: float) -> void:
	if is_hatching:
		return
	hatch_timer += delta
	if hatch_timer >= hatch_time:
		is_hatching = true
		_hatch_sequence()

# ── Wobble loop — runs continuously until hatch ───────────────────────────────
# Gentle rocks slowly in the first 75% of hatch_time, then speeds up and
# intensifies as the egg gets ready to pop.
func _wobble_loop() -> void:
	if is_hatching:
		return

	var near_hatch: bool = hatch_timer >= hatch_time * 0.75
	var intensity: float = 0.22 if near_hatch else 0.10
	var speed: float    = 0.60 if near_hatch else 1.0   # multiplier on timings
	var gap: float      = 0.10 if near_hatch else 0.45  # pause between wobbles

	var t := create_tween()
	t.tween_property($EggMesh, "rotation:z",  intensity,       speed * 0.13).set_trans(Tween.TRANS_SINE)
	t.tween_property($EggMesh, "rotation:z", -intensity,       speed * 0.15).set_trans(Tween.TRANS_SINE)
	t.tween_property($EggMesh, "rotation:z",  intensity * 0.5, speed * 0.10).set_trans(Tween.TRANS_SINE)
	t.tween_property($EggMesh, "rotation:z",  0.0,             speed * 0.09).set_trans(Tween.TRANS_SINE)
	await t.finished

	if not is_hatching:
		await get_tree().create_timer(gap).timeout
		_wobble_loop()

# ── Full hatch animation ──────────────────────────────────────────────────────
func _hatch_sequence() -> void:
	var egg_mesh: MeshInstance3D = $EggMesh

	# Phase 1 — Rapid panic shake
	var t1 := create_tween()
	for i in 7:
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var amp: float = 0.35 - i * 0.02       # dampen toward end
		t1.tween_property(egg_mesh, "rotation:z", dir * amp, 0.045).set_trans(Tween.TRANS_SINE)
	t1.tween_property(egg_mesh, "rotation:z", 0.0, 0.05)
	await t1.finished

	# Phase 2 — Squish outward (egg cracks open)
	var t2 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.tween_property(egg_mesh, "scale", Vector3(1.5, 0.3, 1.5), 0.09)
	await t2.finished

	# Phase 3 — Shrink to nothing
	var t3 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t3.tween_property(egg_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.10)
	await t3.finished

	egg_mesh.visible = false
	_spawn_hatch_burst(global_position)

	# Brief beat before the baby pops up
	await get_tree().create_timer(0.08).timeout

	# Phase 4 — Spawn baby and spring it into the world
	_spawn_baby()

# ── Sparkle burst at hatch position ──────────────────────────────────────────
func _spawn_hatch_burst(pos: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot      = true
	burst.amount        = 24
	burst.lifetime      = 0.9
	burst.explosiveness = 0.95
	burst.spread        = 70.0
	burst.gravity       = Vector3(0, -1.5, 0)
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.5
	burst.scale_amount_min     = 0.06
	burst.scale_amount_max     = 0.14
	# Warm golden sparkle colour
	burst.color = Color(1.0, 0.88, 0.30, 1.0)
	get_parent().add_child(burst)
	burst.global_position = pos + Vector3(0, 0.35, 0)
	burst.emitting = true
	# Auto-free after particles die
	var timer := burst.get_tree().create_timer(1.6)
	await timer.timeout
	if is_instance_valid(burst):
		burst.queue_free()

# ── Spawn the baby roamer with a spring-grow ─────────────────────────────────
func _spawn_baby() -> void:
	if creature_scene_path == "":
		queue_free()
		return
	var creature_scene = load(creature_scene_path)
	if not creature_scene:
		queue_free()
		return

	var creature = creature_scene.instantiate()
	var species_name := creature_scene_path.get_file().get_basename().capitalize()
	creature.name       = species_name
	creature.roamer_uid = str(Time.get_ticks_msec()) + "_" + str(randi())
	creature.is_adult   = false
	creature.parent_a_id = parent_a_id
	creature.parent_b_id = parent_b_id
	creature.family_id   = family_id
	creature.scale       = Vector3(0.6, 0.6, 0.6)
	creature.traits      = _pick_offspring_traits()
	creature.roamer_name = ""   # _ready() generates name

	get_parent().add_child(creature)
	creature.global_position = global_position + Vector3(0, 0.5, 0)

	# Spring-grow on visual children only — avoids Jolt Physics errors on
	# the CharacterBody3D / CollisionShape children.
	var visuals: Array[Node3D] = []
	for child in creature.get_children():
		if child is Node3D and not (child is CollisionObject3D):
			visuals.append(child as Node3D)
	if not visuals.is_empty():
		for v in visuals:
			v.scale = Vector3(0.01, 0.01, 0.01)
		var tg := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tg.set_parallel(true)
		for v in visuals:
			tg.tween_property(v, "scale", Vector3(1.0, 1.0, 1.0), 0.55)

	_try_inherit_den(creature)

	ObjectiveManager.record_hatch()
	MilestoneManager.fire("first_hatch", "New Life! 🥚", "Your first egg has hatched!")
	CurrencyManager.add_dewdrops(15.0)
	WardenManager.gain_xp("egg_hatched")

	queue_free()

# ── Trait inheritance ─────────────────────────────────────────────────────────
func _pick_offspring_traits() -> Array:
	var parent_trait_pool: Array = []
	for roamer in get_tree().get_nodes_in_group("roamers"):
		if roamer.roamer_uid == parent_a_id or roamer.roamer_uid == parent_b_id:
			parent_trait_pool.append_array(roamer.traits)
	var result: Array = []
	var keys := ["shy","bold","greedy","playful","nocturnal","hardy","gentle","swift","timid","radiant"]
	if not parent_trait_pool.is_empty() and randf() < 0.7:
		result.append(parent_trait_pool[randi() % parent_trait_pool.size()])
	else:
		result.append(keys[randi() % keys.size()])
	if randf() < 0.25:
		var keys2 := keys.filter(func(k): return not result.has(k))
		if not keys2.is_empty():
			result.append(keys2[randi() % keys2.size()])
	return result

# ── Den inheritance ───────────────────────────────────────────────────────────
func _try_inherit_den(offspring) -> void:
	for roamer in get_tree().get_nodes_in_group("roamers"):
		if roamer.roamer_uid == parent_a_id or roamer.roamer_uid == parent_b_id:
			if roamer.has_shelter and is_instance_valid(roamer.shelter_node):
				var den = roamer.shelter_node
				if den.has_method("can_accept") and den.can_accept(offspring):
					den.assign_roamer(offspring)
				return
