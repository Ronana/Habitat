extends CharacterBody3D

enum State { WANDERING, IDLE, FLEEING, BREEDING, SLEEPING, SLEEP_WALKING, AGITATED }
enum AttractionStage { APPEARS, VISITS, RESIDENT, BONDED }
enum BreedPhase { NONE, APPROACHING, GOING_TO_SHELTER, INSIDE, EXITING }

@export var species_id: String = ""
@export var creature_scene_path: String = ""

var roamer_uid: String = ""

var state = State.WANDERING

# ── Species conflict ──────────────────────────────────────────────────────────
const CONFLICTS: Dictionary = {
	"Mossdeer": ["Stoneback"],
	"GlowFox":  ["Stoneback"],
}
var _agitation_timer: float = 0.0
const AGITATION_CONTACT_TIME: float = 5.0   # seconds before happiness drain
const AGITATION_DRAIN: float = 0.2           # happiness lost per conflict
const AGITATION_COOLDOWN: float = 12.0       # seconds before re-agitation possible
var _agitation_cooldown: float = 0.0
var _conflict_partner: Node3D = null
var _eye_flash_timer: float = 0.0
var _eye_flashing: bool = false
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

# Selection glow colour — set per-species in _ready()
var _selection_color: Color = Color(1.0, 0.70, 0.15)

# ── Naming ────────────────────────────────────────────────────────────────────
var roamer_name: String = ""
var _name_label_3d: Label3D = null

const NAME_POOL: Array = [
	"Briar", "Fern", "Cobble", "Ash", "Clover", "Mossy", "Twig", "Reed",
	"Thistle", "Stone", "River", "Birch", "Elm", "Sage", "Hazel", "Thatch",
	"Pebble", "Dew", "Sorrel", "Wren", "Flint", "Cedar", "Ivy", "Burr",
	"Acorn", "Bramble", "Frost", "Glen", "Heath", "Larch"
]

# ── Traits ────────────────────────────────────────────────────────────────────
var traits: Array = []

# ── Interaction cooldowns ──────────────────────────────────────────────────────
const INTERACT_COOLDOWN := { "pet": 60.0, "play": 90.0, "gift": 30.0 }
var _interact_cd        := { "pet":  0.0, "play":  0.0, "gift":  0.0 }

const TRAIT_POOL: Dictionary = {
	"shy":       {"name": "Shy",       "icon": "😳", "desc": "Moves slowly, stays cautious",        "speed_mult": 0.85, "food_mult": 0.90, "safety_mult": 1.15, "dewdrop_mult": 1.0 },
	"bold":      {"name": "Bold",      "icon": "💪", "desc": "Confident, feels safer outdoors",     "speed_mult": 1.15, "food_mult": 1.0,  "safety_mult": 0.85, "dewdrop_mult": 1.0 },
	"greedy":    {"name": "Greedy",    "icon": "🍃", "desc": "Always hungry, earns more dewdrops",  "speed_mult": 1.0,  "food_mult": 1.25, "safety_mult": 1.0,  "dewdrop_mult": 1.3 },
	"playful":   {"name": "Playful",   "icon": "🎈", "desc": "Loves space, never feels crowded",    "speed_mult": 1.05, "food_mult": 1.0,  "safety_mult": 1.0,  "dewdrop_mult": 1.1 },
	"nocturnal": {"name": "Nocturnal", "icon": "🌙", "desc": "More active at night",                "speed_mult": 1.0,  "food_mult": 0.9,  "safety_mult": 1.0,  "dewdrop_mult": 1.2 },
	"hardy":     {"name": "Hardy",     "icon": "🛡", "desc": "All needs decay more slowly",         "speed_mult": 1.0,  "food_mult": 0.80, "safety_mult": 0.80, "dewdrop_mult": 1.0 },
	"gentle":    {"name": "Gentle",    "icon": "🌸", "desc": "Rarely stressed, bonds easily",       "speed_mult": 0.90, "food_mult": 0.95, "safety_mult": 0.75, "dewdrop_mult": 1.0 },
	"swift":     {"name": "Swift",     "icon": "💨", "desc": "Moves quickly across the garden",     "speed_mult": 1.30, "food_mult": 1.1,  "safety_mult": 1.0,  "dewdrop_mult": 1.0 },
	"timid":     {"name": "Timid",     "icon": "🐾", "desc": "Stays close to home, wanders little", "speed_mult": 0.80, "food_mult": 0.95, "safety_mult": 1.20, "dewdrop_mult": 1.0 },
	"radiant":   {"name": "Radiant",   "icon": "✨", "desc": "Glows brighter, earns more dewdrops", "speed_mult": 1.0,  "food_mult": 1.0,  "safety_mult": 1.0,  "dewdrop_mult": 1.5 },
}

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
var _in_water: bool = false
var _water_bob_timer: float = 0.0
var _water_seek_timer: float = 0.0
var _is_drinking: bool = false
var _drink_tween: Tween = null

# Cursor awareness
var _just_became_idle: bool = false
var _cursor_tilt_done: bool = false

# Needs indicators
var _need_label: Label3D = null
var _need_pulse_timer: float = 0.0
var _need_check_timer: float = 0.0
const NEED_CHECK_INTERVAL: float = 1.5
const NEED_WARN_THRESHOLD: float = 0.3  # show icon below this value

# Breeding heart indicator
var _heart_label: Label3D = null
var _heart_pulse_timer: float = 0.0
const HEART_HAPPINESS_THRESHOLD: float = 0.85
const POPULATION_CAP: int = 12

# ── Burden / departure system ─────────────────────────────────────────────────
enum BurdenState { HEALTHY, BURDENED, DEPARTING }
var burden_state: int = BurdenState.HEALTHY
var _critical_timer: float = 0.0    # cumulative seconds any need < CRITICAL_NEED_THRESHOLD
var _burdened_timer: float = 0.0    # seconds spent in BURDENED
var _cough_timer: float = 0.0       # countdown to next cough puff
var _depart_target: Vector3 = Vector3.ZERO
var _burden_aura: CPUParticles3D = null

const CRITICAL_NEED_THRESHOLD: float = 0.15
const BURDEN_TRIGGER_SECS: float = 45.0   # neglect this long → BURDENED
const DEPART_TRIGGER_SECS: float = 30.0   # burdened this long → DEPARTING
const COUGH_INTERVAL: float = 6.0

func _ready():
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(45)
	if roamer_uid == "":
		roamer_uid = str(get_instance_id())
	add_to_group("roamers")
	_create_selection_ring()
	pick_wander_target()
	_create_need_indicator()
	# Name: generate if not set (save/load stamps it before add_child)
	if roamer_name == "":
		roamer_name = NAME_POOL[randi() % NAME_POOL.size()]
	_create_name_label()
	# Traits: assign if not set (save/load stamps them before add_child)
	if traits.is_empty():
		var count := 2 if randf() < 0.3 else 1
		assign_random_traits(count)
	_apply_trait_modifiers()
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
	mat.albedo_color           = Color(_selection_color.r, _selection_color.g, _selection_color.b, 0.55)
	mat.emission               = _selection_color
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
	if state == State.BREEDING:
		return
	var hour: float = DayNightManager.current_time
	var is_night: bool = hour >= 21.0 or hour < 6.0
	if is_night:
		# Start heading to sleep if not already doing so
		if state != State.SLEEPING and state != State.SLEEP_WALKING:
			_begin_sleep_walk()
	else:
		# Dawn — wake up from any sleep state
		if state == State.SLEEPING or state == State.SLEEP_WALKING:
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
	_is_sleeping = false
	visible = true
	# If we were sleeping inside a shelter, reappear just outside it
	if has_shelter and is_instance_valid(shelter_node):
		var angle := randf() * TAU
		var exit_offset := Vector3(cos(angle) * 2.2, 0.5, sin(angle) * 2.2)
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

	_heart_label = Label3D.new()
	_heart_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_heart_label.no_depth_test = true
	_heart_label.font_size = 32
	_heart_label.visible = false
	_heart_label.position = Vector3(0.0, 2.2, 0.0)
	add_child(_heart_label)

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

func _update_heart_indicator() -> void:
	if not _heart_label:
		return
	# Never show while sleeping or already breeding
	if _is_sleeping or is_breeding:
		_heart_label.visible = false
		return
	# Must be bonded adult with a mate and high enough happiness
	var breed_ready: bool = (
		attraction_stage == AttractionStage.BONDED
		and is_adult
		and happiness >= HEART_HAPPINESS_THRESHOLD
		and bond_target != null
		and is_instance_valid(bond_target)
	)
	if not breed_ready:
		_heart_label.visible = false
		return
	# Check population cap
	var total_roamers: int = get_tree().get_nodes_in_group("roamers").size()
	if total_roamers >= POPULATION_CAP:
		_heart_label.text    = "💙"
		_heart_label.modulate = Color(0.5, 0.7, 1.0, 0.9)
	else:
		_heart_label.text    = "❤"
		_heart_label.modulate = Color(1.0, 0.45, 0.55, 1.0)
	_heart_label.visible = true

func _process(delta):
	_tick_interaction_cooldowns(delta)
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

	# Tick interaction cooldowns
	for k in _interact_cd:
		if _interact_cd[k] > 0.0:
			_interact_cd[k] = max(0.0, _interact_cd[k] - delta)

	# Needs indicator — check periodically, pulse when visible
	_need_check_timer -= delta
	if _need_check_timer <= 0.0:
		_need_check_timer = NEED_CHECK_INTERVAL
		_update_need_indicator()
		_update_heart_indicator()
	if _need_label and _need_label.visible:
		_need_pulse_timer += delta
		var pulse_y := 1.55 + 0.08 * sin(_need_pulse_timer * 4.0)
		_need_label.position.y = pulse_y
	# Heart pulse — gentle float + scale throb
	if _heart_label and _heart_label.visible:
		_heart_pulse_timer += delta
		_heart_label.position.y = 2.2 + 0.07 * sin(_heart_pulse_timer * 2.8)
		var s: float = 1.0 + 0.12 * absf(sin(_heart_pulse_timer * 2.8))
		_heart_label.scale = Vector3(s, s, s)

func _physics_process(delta):
	_in_water = SplatMapManager.is_water_at(global_position)

	if _in_water:
		# Float on the water surface with a gentle bob
		_water_bob_timer += delta
		var target_y := SplatMapManager.WATER_LEVEL + sin(_water_bob_timer * 1.8) * 0.05
		global_position.y = lerp(global_position.y, target_y, delta * 6.0)
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# Occasionally seek nearby water
	if state == State.WANDERING or state == State.IDLE:
		_water_seek_timer -= delta
		if _water_seek_timer <= 0.0:
			_water_seek_timer = randf_range(18.0, 35.0)
			_try_seek_water()

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
		State.AGITATED:
			_handle_agitated(delta)

	# Conflict proximity scan
	if _agitation_cooldown > 0.0:
		_agitation_cooldown -= delta
	if state != State.BREEDING and state != State.SLEEPING and state != State.SLEEP_WALKING:
		_scan_for_conflicts()

	# Earn Dewdrops when happy — bonded roamers earn significantly more
	dewdrop_timer += delta
	if dewdrop_timer >= dewdrop_interval:
		dewdrop_timer = 0.0
		var stage_multiplier: float = 1.0
		match attraction_stage:
			AttractionStage.VISITS:   stage_multiplier = 1.5
			AttractionStage.RESIDENT: stage_multiplier = 3.0
			AttractionStage.BONDED:   stage_multiplier = 8.0
		var gus_mult: float = GusManager.dewdrop_income_mult() if attraction_stage == AttractionStage.BONDED else 1.0
		var earned = happiness * 2.0 * stage_multiplier * SeasonManager.get_dewdrop_multiplier() * gus_mult
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

func _enter_shelter():
	breed_phase = BreedPhase.INSIDE
	bond_target.breed_phase = BreedPhase.INSIDE
	bond_timer = 0.0
	visible = false
	bond_target.visible = false
	velocity = Vector3.ZERO
	bond_target.velocity = Vector3.ZERO

func _complete_bond():
	var mate = bond_target

	# Assign family IDs
	if family_id == "":
		var ids = [roamer_uid, mate.roamer_uid if mate and is_instance_valid(mate) else ""]
		ids.sort()
		family_id = "_".join(ids)
	if mate and is_instance_valid(mate) and mate.family_id == "":
		mate.family_id = family_id

	MilestoneManager.fire("first_bred", "Love is in the Air! 💕", "Your first pair of roamers has bred.")

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

	var half_area: float = ZoneManager.get_garden_half() - 1.0
	if burden_state == BurdenState.DEPARTING:
		# Departing roamers walk through the boundary — check if they've left
		var gone_dist: float = ZoneManager.get_garden_half() + 4.0
		if abs(global_position.x) > gone_dist or abs(global_position.z) > gone_dist:
			_on_departed()
		else:
			wander_target = _depart_target  # keep heading for the exit
	elif abs(global_position.x) > half_area or abs(global_position.z) > half_area:
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

func update_needs(delta):
	# ── Weather modifiers ────────────────────────────────────────────────────
	var food_weather   := 1.0
	var safety_weather := 1.0
	var space_weather  := 1.0
	var weather := WeatherManager.current_weather
	match weather:
		WeatherManager.Weather.RAIN:
			food_weather   = 0.80  # plants grow → food lasts longer
			safety_weather = 1.15  # roamers feel exposed in rain
		WeatherManager.Weather.FOG:
			safety_weather = 1.08  # unsettled in the murk
		WeatherManager.Weather.WIND:
			space_weather  = 1.20  # restless — feel crowded faster
			safety_weather = 1.10

	# Burdened roamers suffer accelerated need decay
	var burden_mult: float = 2.0 if burden_state == BurdenState.BURDENED else 1.0

	# Food — straight decay
	needs["food"] = max(0.0, needs["food"] - need_decay["food"] * food_weather * burden_mult * delta)

	# Safety — decays normally; shelter restores it passively
	if has_shelter and is_instance_valid(shelter_node):
		needs["safety"] = min(1.0, needs["safety"] + 0.008 * delta)
	else:
		needs["safety"] = max(0.0, needs["safety"] - need_decay["safety"] * safety_weather * burden_mult * delta)
		# Rain / wind with no shelter: seek one urgently
		if (weather == WeatherManager.Weather.RAIN or weather == WeatherManager.Weather.WIND) \
				and state == State.WANDERING:
			shelter_seek_timer = shelter_seek_interval  # trigger shelter seek next tick

	# Space — decays faster the more roamers are in the garden
	var roamer_count: int = get_tree().get_nodes_in_group("roamers").size()
	var crowding_factor: float = clamp(float(roamer_count) / 6.0, 0.5, 3.0)
	needs["space"] = max(0.0, needs["space"] - need_decay["space"] * crowding_factor * space_weather * burden_mult * delta)

	_update_burden_state(delta)

func update_happiness():
	var total = 0.0
	for need in needs:
		total += needs[need]
	happiness = clamp((total / needs.size()) + SeasonManager.get_happiness_bonus(), 0.0, 1.0)
	_update_happiness_glow()

# ── Burden / departure state machine ─────────────────────────────────────────
func _update_burden_state(delta: float) -> void:
	if burden_state == BurdenState.DEPARTING:
		return   # no further transitions once departing

	var any_critical := false
	for n in needs:
		if needs[n] < CRITICAL_NEED_THRESHOLD:
			any_critical = true
			break

	match burden_state:
		BurdenState.HEALTHY:
			if any_critical:
				_critical_timer += delta
				if _critical_timer >= BURDEN_TRIGGER_SECS:
					_enter_burdened()
			else:
				_critical_timer = max(0.0, _critical_timer - delta * 2.0)

		BurdenState.BURDENED:
			if not any_critical:
				recover_from_burden()
				return
			# Extra happiness drain while burdened
			happiness = max(0.0, happiness - 0.003 * delta)
			_burdened_timer += delta
			# Periodic cough puff
			_cough_timer -= delta
			if _cough_timer <= 0.0:
				_cough_timer = COUGH_INTERVAL + randf_range(-1.5, 1.5)
				_spawn_cough_puff()
			if _burdened_timer >= DEPART_TRIGGER_SECS:
				_enter_departing()

func _enter_burdened() -> void:
	burden_state = BurdenState.BURDENED
	_burdened_timer = 0.0
	_cough_timer = 2.0   # first cough after 2 s
	_spawn_burden_aura()
	GrimshroudManager.set_target(self)
	_show_toast("⚠", roamer_name + " is struggling...", "Care for them urgently!", 4.5)

func _enter_departing() -> void:
	burden_state = BurdenState.DEPARTING
	# Pick a boundary-exit point in roughly the direction the roamer is already facing
	var half: float = ZoneManager.get_garden_half() + 6.0
	var dir: Vector3 = (global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))).normalized()
	_depart_target = dir * half
	_depart_target.y = global_position.y
	wander_target  = _depart_target
	move_speed     = move_speed * 0.55   # slow, mournful walk
	_show_toast("🌿", roamer_name + " is leaving the garden...", "Act fast to keep them!", 5.0)

## Restore the roamer to healthy. Called by item use or when needs recover naturally.
func recover_from_burden() -> void:
	if burden_state == BurdenState.HEALTHY:
		return
	var was_departing: bool = burden_state == BurdenState.DEPARTING
	burden_state = BurdenState.HEALTHY
	_critical_timer = 0.0
	_burdened_timer = 0.0
	# Undo the departure slow-down if the roamer was already walking out
	if was_departing:
		move_speed /= 0.55
	_remove_burden_aura()
	GrimshroudManager.clear_target(self)
	WardenManager.gain_xp("burden_rescued")
	MilestoneManager.fire("first_rescue", "Kind Warden!", "You rescued a struggling roamer!")
	_show_toast("✨", roamer_name + " is recovering!", "", 3.0)

func _on_departed() -> void:
	_remove_burden_aura()
	GrimshroudManager.clear_target(self)
	_show_toast("🌿", roamer_name + " returned to the wild.", "", 4.0)
	queue_free()

## Helper — posts a toast via RoamerUI using the correct 4-arg signature.
func _show_toast(icon: String, title: String, subtitle: String = "", duration: float = 3.2) -> void:
	var ui := get_tree().get_root().find_child("RoamerUI", true, false)
	if ui and ui.has_method("show_toast"):
		ui.show_toast(icon, title, subtitle, duration)

func _spawn_burden_aura() -> void:
	if _burden_aura and is_instance_valid(_burden_aura):
		return
	_burden_aura = CPUParticles3D.new()
	_burden_aura.amount          = 10
	_burden_aura.lifetime        = 2.0
	_burden_aura.explosiveness   = 0.0
	_burden_aura.spread          = 180.0
	_burden_aura.gravity         = Vector3(0, 0.3, 0)
	_burden_aura.initial_velocity_min = 0.1
	_burden_aura.initial_velocity_max = 0.3
	_burden_aura.scale_amount_min = 0.04
	_burden_aura.scale_amount_max = 0.10
	_burden_aura.color            = Color(0.25, 0.10, 0.35, 0.7)
	_burden_aura.position         = Vector3(0, 0.6, 0)
	add_child(_burden_aura)

func _remove_burden_aura() -> void:
	if _burden_aura and is_instance_valid(_burden_aura):
		_burden_aura.queue_free()
		_burden_aura = null

func _spawn_cough_puff() -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot       = true
	puff.amount         = 8
	puff.lifetime       = 0.7
	puff.explosiveness  = 0.9
	puff.spread         = 40.0
	puff.gravity        = Vector3(0, 0.5, 0)
	puff.initial_velocity_min = 0.5
	puff.initial_velocity_max = 1.2
	puff.scale_amount_min = 0.05
	puff.scale_amount_max = 0.12
	puff.color          = Color(0.65, 0.60, 0.70, 0.6)
	puff.position       = Vector3(0, 1.0, 0)
	add_child(puff)
	puff.emitting = true
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(puff):
		puff.queue_free()

# ── Happiness glow ────────────────────────────────────────────────────────────
var _glow_mat: StandardMaterial3D = null

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
	# Pulse the glow energy with happiness — use wall-clock time, no accumulator needed
	var t: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 0.5 + 0.3 * sin(t * 1.8)
	_glow_mat.emission = Color(1.0, 0.75, 0.25)
	_glow_mat.emission_energy_multiplier = happiness * pulse * 1.8

func _handle_sleep_walk(_delta):
	var dir := _sleep_rest_pos - global_position
	dir.y = 0.0
	if dir.length() < 2.5:
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
			_just_became_idle = true
			_cursor_tilt_done = false
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
	_face_cursor(delta)
	# Drink when idling at the water's edge
	if not _in_water and not _is_drinking:
		_check_drink_from_edge()
	if idle_timer <= 0:
		_is_drinking = false
		pick_wander_target()
		state = State.WANDERING

func _face_cursor(delta):
	var cursor_node = get_tree().get_root().get_node_or_null("Garden/PlayerCursor")
	if not cursor_node:
		return
	var target_pos: Vector3 = cursor_node.cursor_world_pos
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length() < 1.5:
		return  # cursor too close — don't spin on the spot
	var target_angle := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, delta * 1.8)
	# One-shot curious head-tilt when first noticing the cursor
	if _just_became_idle and not _cursor_tilt_done and dir.length() < 12.0:
		_cursor_tilt_done = true
		_just_became_idle = false
		_do_curious_tilt()

func _do_curious_tilt():
	var body := get_node_or_null("Body")
	if not body or _is_sleeping:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(body, "position:y", _body_rest_y + 0.06, 0.18)
	tween.tween_property(body, "position:y", _body_rest_y - 0.04, 0.14)
	tween.tween_property(body, "position:y", _body_rest_y,         0.22).set_ease(Tween.EASE_OUT)

func pick_wander_target():
	var wander_range = 20.0
	var half_area: float = ZoneManager.get_garden_half() - 1.0
	var new_target = global_position + Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	new_target.x = clamp(new_target.x, -half_area, half_area)
	new_target.z = clamp(new_target.z, -half_area, half_area)
	wander_target = new_target
	wander_timer = randf_range(4.0, 10.0)

## Try to find a water cell nearby and set it as the wander target.
## Called periodically so roamers are drawn toward ponds.
func _try_seek_water() -> void:
	for _attempt in range(12):
		var angle := randf() * TAU
		var dist  := randf_range(2.0, 14.0)
		var candidate := global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if SplatMapManager.is_water_at(candidate):
			wander_target = candidate
			wander_timer  = randf_range(5.0, 10.0)
			state = State.WANDERING
			return

## If idling right next to water, play a short drinking head-dip animation.
func _check_drink_from_edge() -> void:
	var angles := [0.0, TAU * 0.25, TAU * 0.5, TAU * 0.75]
	for angle in angles:
		var probe := global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.0
		if SplatMapManager.is_water_at(probe):
			_is_drinking = true
			_do_drink_animation()
			return

func _do_drink_animation() -> void:
	var body := get_node_or_null("Body")
	if not body or _is_sleeping:
		_is_drinking = false
		return
	if _drink_tween:
		_drink_tween.kill()
	_drink_tween = create_tween().set_trans(Tween.TRANS_SINE).set_loops(3)
	_drink_tween.tween_property(body, "position:y", _body_rest_y - 0.12, 0.35)
	_drink_tween.tween_property(body, "position:y", _body_rest_y,         0.30).set_ease(Tween.EASE_OUT)
	_drink_tween.tween_interval(0.5)
	_drink_tween.finished.connect(func(): _is_drinking = false)

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
	var eat_tween := create_tween().set_trans(Tween.TRANS_SINE).set_loops(2)
	eat_tween.tween_property(body, "position:y", _body_rest_y - 0.15, 0.25)
	eat_tween.tween_property(body, "position:y", _body_rest_y,         0.20).set_ease(Tween.EASE_OUT)
	eat_tween.tween_interval(0.3)
	eat_tween.finished.connect(_start_idle_bob)


# -- Name Label -------------------------------------------------------------

func _create_name_label() -> void:
	if _name_label_3d:
		return
	_name_label_3d = Label3D.new()
	_name_label_3d.name = "NameLabel"
	_name_label_3d.text = roamer_name
	_name_label_3d.font_size = 48
	_name_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label_3d.no_depth_test = true
	_name_label_3d.position = Vector3(0.0, 1.8, 0.0)
	_name_label_3d.modulate = Color(0.9, 1.0, 0.85)
	_name_label_default_modulate = _name_label_3d.modulate
	add_child(_name_label_3d)


# -- Traits -----------------------------------------------------------------

func assign_random_traits(count: int) -> void:
	var keys: Array = TRAIT_POOL.keys()
	keys.shuffle()
	traits = keys.slice(0, min(count, keys.size()))
	_apply_trait_modifiers()

func _apply_trait_modifiers() -> void:
	var speed_mult   := 1.0
	var food_mult    := 1.0
	var safety_mult  := 1.0
	var dewdrop_mult := 1.0
	for trait_id in traits:
		if TRAIT_POOL.has(trait_id):
			var t: Dictionary = TRAIT_POOL[trait_id]
			speed_mult   *= t.get("speed_mult",   1.0)
			food_mult    *= t.get("food_mult",    1.0)
			safety_mult  *= t.get("safety_mult",  1.0)
			dewdrop_mult *= t.get("dewdrop_mult", 1.0)
	move_speed           = 2.5 * speed_mult
	need_decay["food"]   = 0.004 * food_mult
	need_decay["safety"] = 0.002 * safety_mult
	dewdrop_interval     = 5.0 / max(0.1, dewdrop_mult)


# -- Stage progression ------------------------------------------------------

func check_stage_progress() -> void:
	match attraction_stage:
		AttractionStage.APPEARS:
			if needs["food"] > 0.5 and happiness > 0.5:
				attraction_stage = AttractionStage.VISITS
		AttractionStage.VISITS:
			# Requires a species-specific den (not just any shelter) + happiness threshold
			var has_own_den: bool = AttractionManager.can_reside(species_id, self)
			if has_own_den and happiness > 0.7:
				attraction_stage = AttractionStage.RESIDENT
				WardenManager.gain_xp("roamer_resident")
		AttractionStage.RESIDENT:
			if happiness > 0.9:
				attraction_stage = AttractionStage.BONDED
				WardenManager.gain_xp("roamer_bonded")
				_update_happiness_glow()


# -- Interactions (pet / play / gift) -------------------------------------

const INTERACTION_COOLDOWNS := {
	"pet":  30.0,
	"play": 45.0,
	"gift": 60.0,
}

var _interaction_timers: Dictionary = {
	"pet":  0.0,
	"play": 0.0,
	"gift": 0.0,
}

func _tick_interaction_cooldowns(delta: float) -> void:
	for key in _interaction_timers:
		if _interaction_timers[key] > 0.0:
			_interaction_timers[key] = max(0.0, _interaction_timers[key] - delta)

func can_interact(action: String) -> bool:
	return _interaction_timers.get(action, 0.0) <= 0.0

func get_cooldown_remaining(action: String) -> float:
	return _interaction_timers.get(action, 0.0)

func interact_pet() -> bool:
	if not can_interact("pet"):
		return false
	_interaction_timers["pet"] = INTERACTION_COOLDOWNS["pet"]
	needs["safety"] = min(1.0, needs["safety"] + 0.25)
	happiness = min(1.0, happiness + 0.10)
	ObjectiveManager.record_event("interaction")
	check_stage_progress()
	return true

func interact_play() -> bool:
	if not can_interact("play"):
		return false
	_interaction_timers["play"] = INTERACTION_COOLDOWNS["play"]
	needs["space"] = min(1.0, needs["space"] + 0.30)
	happiness = min(1.0, happiness + 0.10)
	ObjectiveManager.record_event("interaction")
	check_stage_progress()
	return true

func interact_gift() -> bool:
	if not can_interact("gift"):
		return false
	# Attempt to consume a treat from inventory
	var consumed := false
	if InventoryManager.remove_item("Roamer Treat"):
		consumed = true
	elif InventoryManager.remove_item("Fresh Berries"):
		consumed = true
	if not consumed:
		return false
	_interaction_timers["gift"] = INTERACTION_COOLDOWNS["gift"]
	needs["food"] = min(1.0, needs["food"] + 0.50)
	happiness = min(1.0, happiness + 0.15)
	ObjectiveManager.record_event("interaction")
	check_stage_progress()
	return true


# -- Selection ------------------------------------------------------------

func on_selected() -> void:
	if selection_ring:
		selection_ring.visible = true
	if _name_label_3d:
		_name_label_3d.modulate = Color(1.0, 0.95, 0.5)

func on_deselected() -> void:
	if selection_ring:
		selection_ring.visible = false
	if _name_label_3d:
		_name_label_3d.modulate = _name_label_default_modulate

func show_selection_ring() -> void:
	if selection_ring:
		selection_ring.visible = true

func hide_selection_ring() -> void:
	if selection_ring:
		selection_ring.visible = false


# -- Public name / trait helpers ------------------------------------------

func set_roamer_name(new_name: String) -> void:
	roamer_name = new_name
	if _name_label_3d:
		_name_label_3d.text = new_name

func get_traits_display() -> String:
	if traits.is_empty():
		return "None"
	var parts: Array = []
	for trait_id in traits:
		var t: Dictionary = TRAIT_POOL.get(trait_id, {})
		var icon: String = t.get("icon", "")
		var tname: String = t.get("name", trait_id)
		parts.append(icon + " " + tname if icon != "" else tname)
	return "  ".join(parts)


# ── Species Conflict System ────────────────────────────────────────────────────

func _scan_for_conflicts() -> void:
	if state == State.AGITATED or _agitation_cooldown > 0.0:
		return
	if not CONFLICTS.has(species_id):
		return
	var rivals: Array = CONFLICTS[species_id]
	for body in get_tree().get_nodes_in_group("roamers"):
		if body == self:
			continue
		if not (body.species_id in rivals):
			continue
		var dist: float = global_position.distance_to(body.global_position)
		if dist < 4.0:
			_begin_agitation(body)
			return

func _begin_agitation(partner: Node) -> void:
	state = State.AGITATED
	_agitation_timer = 0.0
	_conflict_partner = partner
	_eye_flashing = true
	_eye_flash_timer = 0.0
	AudioManager.play_agitated()
	if partner.has_method("_begin_agitation") and partner.state != State.AGITATED:
		partner._begin_agitation(self)

func _handle_agitated(delta: float) -> void:
	# Flash eye shader param
	_eye_flash_timer += delta
	if _eye_flashing:
		var flash: float = abs(sin(_eye_flash_timer * 6.0))
		_set_eye_flash(flash)

	# Face the conflict partner
	if is_instance_valid(_conflict_partner):
		var dir: Vector3 = (_conflict_partner as Node3D).global_position - global_position
		dir.y = 0.0
		if dir.length() > 0.01:
			var target_basis := Basis.looking_at(dir.normalized(), Vector3.UP)
			global_basis = global_basis.slerp(target_basis, delta * 4.0)
			velocity.x = 0.0
			velocity.z = 0.0

	_agitation_timer += delta
	if _agitation_timer >= AGITATION_CONTACT_TIME:
		_resolve_conflict()

func _resolve_conflict() -> void:
	# Drain happiness and bounce apart
	happiness = max(0.0, happiness - AGITATION_DRAIN)
	_set_eye_flash(0.0)
	_eye_flashing = false
	# Push away from partner
	if is_instance_valid(_conflict_partner):
		var away: Vector3 = (global_position - (_conflict_partner as Node3D).global_position).normalized()
		away.y = 0.0
		wander_target = global_position + away * 6.0
	_conflict_partner = null
	state = State.WANDERING
	_agitation_cooldown = AGITATION_COOLDOWN
	_show_toast("😤", roamer_name + " had a conflict!", "They've lost some happiness.", 3.5)

## Override in subclasses to add species-specific agitation visuals.
func play_agitated() -> void:
	pass

func calm_agitation() -> void:
	"""Called by player (watering can interaction) to soothe the roamer."""
	if state != State.AGITATED:
		return
	_set_eye_flash(0.0)
	_eye_flashing = false
	_conflict_partner = null
	state = State.WANDERING
	_agitation_cooldown = AGITATION_COOLDOWN * 0.5
	happiness = min(1.0, happiness + 0.05)
	_show_toast("💧", roamer_name + " has calmed down!", "", 3.0)

func _set_eye_flash(intensity: float) -> void:
	"""Override per-species to drive a shader param or material colour."""
	pass
 