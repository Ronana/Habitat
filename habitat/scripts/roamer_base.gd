extends CharacterBody3D

enum State { WANDERING, IDLE, FLEEING, BREEDING, SLEEPING, SLEEP_WALKING }
enum AttractionStage { APPEARS, VISITS, RESIDENT, BONDED }
enum BreedPhase { NONE, APPROACHING, GOING_TO_SHELTER, INSIDE, EXITING }

@export var species_id: String = ""
@export var creature_scene_path: String = ""

var roamer_uid: String = ""

var state = State.WANDERING
var attraction_stage = AttractionStage.APPEARS
var wander_target: Vector3
var wander_timer: float = 0.0
var idle_timer: float = 0.0
var move_speed: float = 2.5
var gravity: float = -20.0
var dewdrop_timer: float = 0.0
var dewdrop_interval: float = 5.0
var hunger_threshold: float = 0.4
var food_seek_timer: float = 0.0
var food_seek_interval: float = 5.0
var has_shelter: bool = false
var shelter_node = null
var shelter_seek_timer: float = 0.0
var shelter_seek_interval: float = 10.0
var stage_check_timer: float = 0.0
var stage_check_interval: float = 5.0

# Breeding
var is_breeding: bool = false
var bond_target = null
var bond_timer: float = 0.0
var bond_duration: float = 5.0  # seconds inside shelter before egg
var breed_phase = BreedPhase.NONE
var is_breed_leader: bool = false

# Family system
var is_adult: bool = true
var family_id: String = ""
var parent_a_id: String = ""
var parent_b_id: String = ""
var grow_up_time: float = 90.0
var grow_up_timer: float = 0.0

# Needs — each fills from 0.0 to 1.0
var needs = {
	"food": 0.5,
	"safety": 1.0,
	"space": 1.0
}

# How fast each need depletes per second (base rates)
var need_decay = {
	"food": 0.01,
	"safety": 0.004,  # ~4 min to drain without shelter
	"space": 0.002    # ~8 min baseline; scales with crowding
}

var happiness: float = 1.0

# Sleep state
var _is_sleeping: bool = false
var _sleep_tween: Tween = null
var _name_label_default_modulate: Color = Color(1, 1, 1, 1)
var _sleep_rest_pos: Vector3 = Vector3.ZERO
var _sleep_z_timer: float = 0.0
var _sleep_z_interval: float = 1.8

var selection_ring: MeshInstance3D = null
var _ring_pulse_timer: float = 0.0

# Idle bob
var _idle_tween: Tween = null
var _body_rest_y: float = 0.0  # cached body origin Y
var _is_bobbing: bool = false

# Needs indicators
var _need_label: Label3D = null
var _need_pulse_timer: float = 0.0
var _need_check_timer: float = 0.0
const NEED_CHECK_INTERVAL: float = 1.5
const NEED_WARN_THRESHOLD: float = 0.3  # show icon below this value

func _ready():
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(45)
	if roamer_uid == "":
		roamer_uid = str(get_instance_id())
	add_to_group("roamers")
	_create_selection_ring()
	pick_wander_target()
	_create_need_indicator()
	# Start idle bob after one frame so body node is positioned
	await get_tree().process_frame
	_start_idle_bob()

func _create_selection_ring():
	selection_ring = MeshInstance3D.new()
	selection_ring.position = Vector3(0.0, 0.05, 0.0)
	selection_ring.mesh = _build_ring_mesh(0.74, 1.0, 48)
	var mat = StandardMaterial3D.new()
	mat.shading_mode           = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency           = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test          = true
	mat.emission_enabled       = true
	mat.albedo_color           = Color(0.85, 0.95, 1.0, 0.55)
	mat.emission               = Color(0.7, 0.88, 1.0)
	mat.emission_energy_multiplier = 1.2
	selection_ring.set_surface_override_material(0, mat)
	selection_ring.visible = false
	add_child(selection_ring)

func _build_ring_mesh(inner_r: float, outer_r: float, segments: int) -> ArrayMesh:
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

# ── Idle bob ──────────────────────────────────────────────────────────────────
func _start_idle_bob():
	var body = get_node_or_null("Body")
	if not body:
		return
	_body_rest_y = body.position.y
	_is_bobbing = true
	_run_bob_cycle()

func _run_bob_cycle():
	if not _is_bobbing:
		return
	var body = get_node_or_null("Body")
	if not body:
		return
	# Each species gets a slightly different bob height/speed via species_id hash
	var speed_var: float = 1.0 + (roamer_uid.hash() % 7) * 0.08
	var height_var: float = 0.04 + (roamer_uid.hash() % 5) * 0.008
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(body, "position:y", _body_rest_y + height_var, 0.55 / speed_var)
	_idle_tween.tween_property(body, "position:y", _body_rest_y,               0.55 / speed_var)
	_idle_tween.tween_interval(0.1 + randf() * 0.3)
	_idle_tween.tween_callback(_run_bob_cycle)

func _stop_idle_bob():
	_is_bobbing = false
	if _idle_tween:
		_idle_tween.kill()
		_idle_tween = null
	var body = get_node_or_null("Body")
	if body:
		body.position.y = _body_rest_y

# ── Sleep / wake ──────────────────────────────────────────────────────────────
func _check_sleep_state():
	if state == State.BREEDING or state == State.SLEEPING:
		if state == State.SLEEPING:
			# Still check for dawn wake-up
			var hour: float = DayNightManager.current_time
			if hour >= 6.0 and hour < 21.0:
				_wake_up()
		return
	var hour: float = DayNightManager.current_time
	var is_night: bool = hour >= 21.0 or hour < 6.0
	if is_night and not _is_sleeping and state != State.SLEEP_WALKING:
		_begin_sleep_walk()
	elif not is_night and _is_sleeping:
		_wake_up()

func _begin_sleep_walk():
	# Choose where to go — shelter if available, random rest spot otherwise
	_stop_idle_bob()
	if has_shelter and is_instance_valid(shelter_node):
		_sleep_rest_pos = shelter_node.global_position
	else:
		# Pick a random nearby spot to curl up
		var offset := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		_sleep_rest_pos = global_position + offset
	wander_target = _sleep_rest_pos
	state = State.SLEEP_WALKING

func _arrive_at_sleep_spot():
	_is_sleeping = true
	velocity = Vector3.ZERO
	if has_shelter and is_instance_valid(shelter_node):
		# Go inside — become invisible
		visible = false
	else:
		# No shelter — hunker down visually
		_do_hunker_down_anim()
		_sleep_z_timer = 0.5  # start Zs soon

func _do_hunker_down_anim():
	var body = get_node_or_null("Body")
	var label = get_node_or_null("NameLabel")
	if _sleep_tween:
		_sleep_tween.kill()
	_sleep_tween = create_tween().set_parallel(true)
	if body:
		_sleep_tween.tween_property(body, "scale", Vector3(1.3, 0.55, 1.3), 1.0).set_trans(Tween.TRANS_SINE)
	if label:
		_name_label_default_modulate = label.modulate
		_sleep_tween.tween_property(label, "modulate", Color(0.5, 0.6, 0.5, 0.35), 1.5)

func _wake_up():
	if not _is_sleeping:
		state = State.WANDERING
		return
	_is_sleeping = false
	visible = true
	# If we were in a shelter, reappear just outside it
	if has_shelter and is_instance_valid(shelter_node):
		var exit_offset := Vector3(randf_range(-1.0, 1.0), 0.5, randf_range(-1.0, 1.0))
		global_position = shelter_node.global_position + exit_offset
	state = State.WANDERING
	var body = get_node_or_null("Body")
	var label = get_node_or_null("NameLabel")
	if _sleep_tween:
		_sleep_tween.kill()
	_sleep_tween = create_tween().set_parallel(true)
	if body:
		_sleep_tween.tween_property(body, "scale", Vector3(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_BACK)
	if label:
		_sleep_tween.tween_property(label, "modulate", _name_label_default_modulate, 0.8)
	_start_idle_bob()

func _spawn_sleep_z():
	# Float a small "z" label upward and fade it out
	var z_label := Label3D.new()
	z_label.text = ["z", "z", "Z"].pick_random()
	z_label.font_size = 18 + randi() % 12
	z_label.modulate = Color(0.7, 0.85, 1.0, 0.9)
	z_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z_label.no_depth_test = true
	var offset := Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.2, 0.2))
	z_label.position = offset
	add_child(z_label)
	var t := create_tween().set_parallel(true)
	t.tween_property(z_label, "position:y", offset.y + 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(z_label, "modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_QUAD)
	t.chain().tween_callback(z_label.queue_free)

# ── Needs indicator ──────────────────────────────────────────────────────────
func _create_need_indicator():
	_need_label = Label3D.new()
	_need_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_need_label.no_depth_test = true
	_need_label.font_size = 28
	_need_label.visible = false
	_need_label.position = Vector3(0.0, 1.6, 0.0)
	add_child(_need_label)

func _update_need_indicator():
	if not _need_label:
		return
	# Don't show indicators while sleeping
	if _is_sleeping:
		_need_label.visible = false
		return
	# Pick the worst need below the warn threshold
	var icon := ""
	var worst_val := NEED_WARN_THRESHOLD
	var col := Color(1, 1, 1, 1)
	for need_name in needs:
		var val: float = needs[need_name]
		if val < worst_val:
			worst_val = val
			match need_name:
				"food":
					icon = "🍃"
					col = Color(0.6, 0.9, 0.3)
				"safety":
					icon = "⚠"
					col = Color(1.0, 0.7, 0.1)
				"space":
					icon = "↔"
					col = Color(0.7, 0.8, 1.0)
	if icon == "":
		_need_label.visible = false
	else:
		_need_label.text = icon
		_need_label.modulate = col
		_need_label.visible = true

func _process(delta):
	if selection_ring and selection_ring.visible:
		_ring_pulse_timer += delta
		var pulse = 1.0 + 0.05 * sin(_ring_pulse_timer * 3.2)
		selection_ring.scale = Vector3(pulse, 1.0, pulse)

	# Pause bob while moving, resume when idle
	var moving: bool = velocity.length() > 0.3
	if moving and _is_bobbing:
		_stop_idle_bob()
	elif not moving and not _is_bobbing and state == State.IDLE:
		_start_idle_bob()

	# Floating Zs for roamers sleeping without a shelter
	if _is_sleeping and not has_shelter:
		_sleep_z_timer -= delta
		if _sleep_z_timer <= 0.0:
			_sleep_z_timer = _sleep_z_interval + randf_range(-0.4, 0.4)
			_spawn_sleep_z()

	# Needs indicator — check periodically, pulse when visible
	_need_check_timer -= delta
	if _need_check_timer <= 0.0:
		_need_check_timer = NEED_CHECK_INTERVAL
		_update_need_indicator()
	if _need_label and _need_label.visible:
		_need_pulse_timer += delta
		var pulse_y := 1.55 + 0.08 * sin(_need_pulse_timer * 4.0)
		_need_label.position.y = pulse_y

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	update_needs(delta)
	update_happiness()

	# Sleep/wake check (only roamers with a shelter sleep)
	_check_sleep_state()

	match state:
		State.WANDERING:
			handle_wandering(delta)
		State.IDLE:
			handle_idle(delta)
		State.BREEDING:
			handle_breeding(delta)
		State.SLEEP_WALKING:
			_handle_sleep_walk(delta)
		State.SLEEPING:
			velocity.x = 0.0
			velocity.z = 0.0

	# Earn Dewdrops when happy — bonded roamers earn significantly more
	dewdrop_timer += delta
	if dewdrop_timer >= dewdrop_interval:
		dewdrop_timer = 0.0
		var stage_multiplier: float = 1.0
		match attraction_stage:
			AttractionStage.VISITS:   stage_multiplier = 1.5
			AttractionStage.RESIDENT: stage_multiplier = 3.0
			AttractionStage.BONDED:   stage_multiplier = 8.0
		var earned = happiness * 2.0 * stage_multiplier * SeasonManager.get_dewdrop_multiplier()
		CurrencyManager.add_dewdrops(earned)

	# Seek food when hungry (skip during breeding and sleep)
	if state != State.BREEDING and state != State.SLEEPING and state != State.SLEEP_WALKING:
		food_seek_timer += delta
		if food_seek_timer >= food_seek_interval:
			food_seek_timer = 0.0
			if needs["food"] < hunger_threshold:
				seek_nearest_food()

		# Seek shelter if visiting and no shelter assigned
		shelter_seek_timer += delta
		if shelter_seek_timer >= shelter_seek_interval:
			shelter_seek_timer = 0.0
			if attraction_stage == AttractionStage.VISITS and not has_shelter:
				seek_nearest_shelter()

		# Periodically check stage progression
		stage_check_timer += delta
		if stage_check_timer >= stage_check_interval:
			stage_check_timer = 0.0
			check_stage_progress()

	# Grow up over time
	if not is_adult:
		grow_up_timer += delta
		if grow_up_timer >= grow_up_time:
			is_adult = true
			scale = Vector3.ONE
			print(name, " has grown up!")

	move_and_slide()

# ---------------------------------------------------------------------------
# Breeding sequence
# ---------------------------------------------------------------------------

func start_bond(mate):
	is_breeding = true
	is_breed_leader = true
	bond_target = mate
	bond_timer = 0.0
	breed_phase = BreedPhase.APPROACHING
	state = State.BREEDING

	mate.is_breeding = true
	mate.is_breed_leader = false
	mate.bond_target = self
	mate.breed_phase = BreedPhase.APPROACHING
	mate.state = State.BREEDING

	# Both walk toward each other
	wander_target = mate.global_position
	mate.wander_target = global_position
	print(name, " and ", mate.name, " are heading toward each other!")

func handle_breeding(delta):
	# Both leader and follower: move toward their current wander_target
	var dir = (wander_target - global_position)
	dir.y = 0
	if dir.length() > 0.4:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		if dir.length() > 0.01:
			look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0

	# Only the leader manages phase transitions
	if not is_breed_leader:
		return

	if not bond_target or not is_instance_valid(bond_target):
		_cancel_bond()
		return

	match breed_phase:
		BreedPhase.APPROACHING:
			# Continuously update targets so they converge dynamically
			wander_target = bond_target.global_position
			bond_target.wander_target = global_position
			if global_position.distance_to(bond_target.global_position) < 2.0:
				_transition_to_shelter()

		BreedPhase.GOING_TO_SHELTER:
			# Both are already walking to shelter; wait until leader arrives
			if global_position.distance_to(wander_target) < 1.5:
				_enter_shelter()

		BreedPhase.INSIDE:
			bond_timer += delta
			if bond_timer >= bond_duration:
				_complete_bond()

		BreedPhase.EXITING:
			pass  # handled fully in _complete_bond

func _get_breed_shelter():
	if shelter_node and is_instance_valid(shelter_node):
		return shelter_node
	if bond_target and is_instance_valid(bond_target) and \
	   bond_target.shelter_node and is_instance_valid(bond_target.shelter_node):
		return bond_target.shelter_node
	return null

func _transition_to_shelter():
	var shelter = _get_breed_shelter()
	if not shelter:
		# No shelter — cancel rather than breed in the open
		_cancel_bond()
		return
	breed_phase = BreedPhase.GOING_TO_SHELTER
	bond_target.breed_phase = BreedPhase.GOING_TO_SHELTER
	wander_target = shelter.global_position
	bond_target.wander_target = shelter.global_position
	print(name, " and ", bond_target.name, " are heading to the shelter!")

func _enter_shelter():
	breed_phase = BreedPhase.INSIDE
	bond_target.breed_phase = BreedPhase.INSIDE
	bond_timer = 0.0
	visible = false
	bond_target.visible = false
	velocity = Vector3.ZERO
	bond_target.velocity = Vector3.ZERO
	print(name, " and ", bond_target.name, " are inside the shelter!")

func _complete_bond():
	var mate = bond_target

	# Assign family IDs
	if family_id == "":
		var ids = [roamer_uid, mate.roamer_uid if mate and is_instance_valid(mate) else ""]
		ids.sort()
		family_id = "_".join(ids)
	if mate and is_instance_valid(mate) and mate.family_id == "":
		mate.family_id = family_id

	# Spawn egg at shelter
	var shelter = _get_breed_shelter()
	var spawn_pos = shelter.global_position if shelter else global_position

	var egg_scene = load("res://scenes/egg.tscn")
	if egg_scene:
		var egg = egg_scene.instantiate()
		egg.creature_scene_path = creature_scene_path
		egg.parent_a_id = roamer_uid
		egg.parent_b_id = mate.roamer_uid if mate and is_instance_valid(mate) else ""
		egg.family_id = family_id
		get_parent().add_child(egg)
		egg.global_position = spawn_pos + Vector3(0, 0.3, 0)

	# Celebration from shelter
	_spawn_celebration(spawn_pos)
	WardenManager.gain_xp("egg_laid")
	print(name, " laid an egg!")

	# Exit shelter — both become visible and wander away
	visible = true
	breed_phase = BreedPhase.EXITING
	is_breeding = false
	is_breed_leader = false
	bond_target = null
	pick_wander_target()
	state = State.WANDERING

	if mate and is_instance_valid(mate):
		mate.visible = true
		mate.breed_phase = BreedPhase.NONE
		mate.is_breeding = false
		mate.is_breed_leader = false
		mate.bond_target = null
		mate.pick_wander_target()
		mate.state = State.WANDERING

func _cancel_bond():
	is_breeding = false
	is_breed_leader = false
	breed_phase = BreedPhase.NONE
	visible = true
	if bond_target and is_instance_valid(bond_target):
		bond_target.is_breeding = false
		bond_target.is_breed_leader = false
		bond_target.breed_phase = BreedPhase.NONE
		bond_target.visible = true
		bond_target.bond_target = null
		bond_target.pick_wander_target()
		bond_target.state = State.WANDERING
	bond_target = null
	pick_wander_target()
	state = State.WANDERING

func _spawn_celebration(pos: Vector3):
	var label = Label3D.new()
	label.text = "♥  ♥  ♥"
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.4, 0.7)
	get_parent().add_child(label)
	label.global_position = pos + Vector3(0, 2.0, 0)
	var tween = create_tween()
	tween.tween_property(label, "global_position", pos + Vector3(0, 4.5, 0), 2.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label.queue_free)

# ---------------------------------------------------------------------------
# Family helpers
# ---------------------------------------------------------------------------

func is_bondable() -> bool:
	return attraction_stage == AttractionStage.BONDED and is_adult and not is_breeding

func _is_sibling(other) -> bool:
	if (parent_a_id == "" and parent_b_id == "") or \
	   (other.parent_a_id == "" and other.parent_b_id == ""):
		return false
	var my_parents = [parent_a_id, parent_b_id]
	for p in [other.parent_a_id, other.parent_b_id]:
		if p != "" and p in my_parents:
			return true
	return false

# ---------------------------------------------------------------------------
# Needs / happiness
# ---------------------------------------------------------------------------

func seek_nearest_shelter():
	var shelters = get_tree().get_nodes_in_group("shelters")
	if shelters.is_empty():
		return
	var nearest = null
	var nearest_dist = INF
	for shelter in shelters:
		if shelter.has_method("can_accept") and shelter.can_accept(self):
			var dist = global_position.distance_to(shelter.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = shelter
	if nearest:
		move_to(nearest.global_position)
		print(name, " is seeking a shelter!")

	var half_area = 19.0
	if abs(global_position.x) > half_area or abs(global_position.z) > half_area:
		global_position.x = clamp(global_position.x, -half_area, half_area)
		global_position.z = clamp(global_position.z, -half_area, half_area)
		pick_wander_target()

func seek_nearest_food():
	var food_items = get_tree().get_nodes_in_group("food")
	if food_items.is_empty():
		return
	var nearest = null
	var nearest_dist = INF
	for item in food_items:
		var dist = global_position.distance_to(item.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = item
	if nearest:
		move_to(nearest.global_position)
		print(name, " is seeking food!")

func update_needs(delta):
	# Food — straight decay
	needs["food"] = max(0.0, needs["food"] - need_decay["food"] * delta)

	# Safety — decays normally; shelter restores it passively
	if has_shelter and is_instance_valid(shelter_node):
		# Shelter present: restore safety faster than it decays
		needs["safety"] = min(1.0, needs["safety"] + 0.008 * delta)
	else:
		needs["safety"] = max(0.0, needs["safety"] - need_decay["safety"] * delta)

	# Space — decays faster the more roamers are in the garden
	var roamer_count: int = get_tree().get_nodes_in_group("roamers").size()
	var crowding_factor: float = clamp(float(roamer_count) / 6.0, 0.5, 3.0)
	needs["space"] = max(0.0, needs["space"] - need_decay["space"] * crowding_factor * delta)

func update_happiness():
	var total = 0.0
	for need in needs:
		total += needs[need]
	happiness = clamp((total / needs.size()) + SeasonManager.get_happiness_bonus(), 0.0, 1.0)
	_update_happiness_glow()

# ── Happiness glow ────────────────────────────────────────────────────────────
var _glow_mat: StandardMaterial3D = null
var _glow_timer: float = 0.0

func _update_happiness_glow():
	if _is_sleeping:
		return
	var body := get_node_or_null("Body")
	if not body:
		return
	# Only bonded roamers get a persistent warm glow; others get none
	if attraction_stage != AttractionStage.BONDED:
		if _glow_mat != null:
			body.set_surface_override_material(0, null)
			_glow_mat = null
		return
	# Set up the glow material once
	if _glow_mat == null:
		var base = body.get_active_material(0)
		if not base:
			return
		_glow_mat = base.duplicate()
		_glow_mat.emission_enabled = true
		body.set_surface_override_material(0, _glow_mat)
	# Pulse the glow energy with happiness
	_glow_timer += 0.016  # approximate frame step; close enough for a cosmetic pulse
	var pulse := 0.5 + 0.3 * sin(_glow_timer * 1.8)
	_glow_mat.emission = Color(1.0, 0.75, 0.25)
	_glow_mat.emission_energy_multiplier = happiness * pulse * 1.8

func _handle_sleep_walk(delta):
	var dir := _sleep_rest_pos - global_position
	dir.y = 0.0
	if dir.length() < 0.8:
		state = State.SLEEPING
		_arrive_at_sleep_spot()
		return
	dir = dir.normalized()
	velocity.x = dir.x * move_speed * 0.6
	velocity.z = dir.z * move_speed * 0.6
	look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
	# move_and_slide() is called once at the end of _physics_process — don't call it again here

func handle_wandering(delta):
	wander_timer -= delta
	var direction = (wander_target - global_position)
	direction.y = 0
	if direction.length() < 1.5 or wander_timer <= 0:
		if randf() > 0.4:
			state = State.IDLE
			idle_timer = randf_range(2.0, 5.0)
		else:
			pick_wander_target()
		return
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)

func handle_idle(delta):
	idle_timer -= delta
	velocity.x = 0
	velocity.z = 0
	if idle_timer <= 0:
		pick_wander_target()
		state = State.WANDERING

func pick_wander_target():
	var wander_range = 20.0
	var half_area = 19.0
	var new_target = global_position + Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	new_target.x = clamp(new_target.x, -half_area, half_area)
	new_target.z = clamp(new_target.z, -half_area, half_area)
	wander_target = new_target
	wander_timer = randf_range(4.0, 10.0)

func move_to(target: Vector3):
	wander_target = target
	state = State.WANDERING
	wander_timer = 20.0

func feed(food_value: float):
	needs["food"] = min(1.0, needs["food"] + food_value)
	WardenManager.gain_xp("roamer_fed")
	check_stage_progress()
	_play_eat_animation()

func _play_eat_animation():
	var body = get_node_or_null("Body")
	if not body or _is_sleeping:
		return
	_stop_idle_bob()
	var eat_tween := create_tween().set_trans(Tween.TRANS_SINE)
	# Dip down, squish wide, pop back
	eat_tween.tween_property(body, "position:y", _body_rest_y - 0.10, 0.18)
	eat_tween.parallel().tween_property(body, "scale", Vector3(1.25, 0.78, 1.25), 0.18)
	eat_tween.tween_property(body, "position:y", _body_rest_y + 0.08,  0.14)
	eat_tween.parallel().tween_property(body, "scale", Vector3(0.90, 1.15, 0.90), 0.14)
	eat_tween.tween_property(body, "position:y", _body_rest_y,          0.20).set_ease(Tween.EASE_OUT)
	eat_tween.parallel().tween_property(body, "scale", Vector3(1.0, 1.0, 1.0),   0.20)
	eat_tween.tween_callback(_start_idle_bob)

func check_stage_progress():
	match attraction_stage:
		AttractionStage.APPEARS:
			if happiness > 0.5:
				attraction_stage = AttractionStage.VISITS
				print(name, " is now VISITING!")
				WardenManager.gain_xp("roamer_visits")
		AttractionStage.VISITS:
			if happiness > 0.7 and has_shelter:
				attraction_stage = AttractionStage.RESIDENT
				print(name, " is now a RESIDENT!")
				WardenManager.gain_xp("roamer_resident")
			elif happiness > 0.7 and not has_shelter:
				print(name, " needs a shelter to become Resident!")
		AttractionStage.RESIDENT:
			if happiness > 0.9 and is_adult:
				attraction_stage = AttractionStage.BONDED
				print(name, " is now BONDED!")
				WardenManager.gain_xp("roamer_bonded")
				AudioManager.play_level_up()
				ParticleManager.spawn_bond_sparkle(global_position)
				ParticleManager.attach_dewdrop_aura(self)

func on_selected():
	var body = get_node("Body")
	var unique_mat = body.get_active_material(0).duplicate()
	unique_mat.emission_enabled = true
	unique_mat.emission = Color(1.0, 0.6, 0.1)
	unique_mat.emission_energy_multiplier = 2.0
	body.set_surface_override_material(0, unique_mat)
	if selection_ring:
		selection_ring.visible = true
		_ring_pulse_timer = 0.0

func on_deselected():
	var body = get_node("Body")
	# Restore glow mat if bonded, otherwise clear override
	body.set_surface_override_material(0, _glow_mat)
	if selection_ring:
		selection_ring.visible = false
