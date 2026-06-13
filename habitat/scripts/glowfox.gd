extends "res://scripts/roamer_base.gd"

# ── Config — set these to match your imported GLB ─────────────────────────────
## Path to the AnimationPlayer inside the fox GLB (relative to this node)
@export var anim_player_path: NodePath = NodePath("FoxModel/AnimationPlayer")
## Exact name of the walk animation as it appears in the AnimationPlayer
@export var walk_anim_name: String = "walk"
## Exact name of the idle animation (leave blank if none)
@export var idle_anim_name: String = ""

# ── Internal refs ─────────────────────────────────────────────────────────────
var _anim: AnimationPlayer = null
var _fox_mat: ShaderMaterial = null   # tail shader (surface 1)

func _ready():
	move_speed       = 2.8
	dewdrop_interval = 4.0
	super._ready()
	await get_tree().process_frame
	_setup_anim()
	_setup_fox_mat()

func _setup_anim():
	_anim = get_node_or_null(anim_player_path) as AnimationPlayer
	if not _anim:
		push_warning("GlowFox: AnimationPlayer not found at " + str(anim_player_path))

func _setup_fox_mat():
	# Find the MeshInstance3D anywhere under FoxModel
	var model := get_node_or_null("FoxModel")
	if not model:
		return
	var mesh := _find_mesh(model)
	if not mesh:
		return
	# Duplicate the tail shader (surface 1) so each fox is independent
	var base: Material = mesh.get_active_material(1)
	if base:
		_fox_mat = base.duplicate() as ShaderMaterial
		mesh.set_surface_override_material(1, _fox_mat)

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null

# ── Per-frame updates ─────────────────────────────────────────────────────────

func _process(delta):
	super._process(delta)
	_update_fox_glow()

func _physics_process(delta):
	_update_fox_speed()
	super._physics_process(delta)
	_update_animation()

# ── Animation ────────────────────────────────────────────────────────────────

func _update_animation():
	if not _anim:
		return
	var is_moving := velocity.length() > 0.3
	if is_moving:
		if _anim.current_animation != walk_anim_name:
			_anim.play(walk_anim_name)
			# Scale playback speed with movement speed (faster at night)
			_anim.speed_scale = move_speed / 2.8
	else:
		if idle_anim_name != "" and _anim.current_animation != idle_anim_name:
			_anim.play(idle_anim_name)
		elif idle_anim_name == "" and _anim.is_playing():
			_anim.stop()

# ── Nocturnal sleep schedule — inverts the base class day/night logic ─────────
# Base sleeps 21:00–06:00. GlowFox sleeps 08:00–18:00 and is active at night.

func _check_sleep_state():
	if state == State.BREEDING:
		return
	var hour: float = DayNightManager.current_time
	var is_daytime: bool = hour >= 8.0 and hour < 18.0
	if is_daytime:
		if state != State.SLEEPING and state != State.SLEEP_WALKING:
			_begin_sleep_walk()
	else:
		# Nighttime — wake up if sleeping
		if state == State.SLEEPING or state == State.SLEEP_WALKING:
			_wake_up()

# ── Night factor (0 = day, 1 = full night) ────────────────────────────────────

func _get_night_factor() -> float:
	var hour: float = DayNightManager.current_time
	if hour >= 20.0 or hour < 6.0:
		return 1.0
	elif hour >= 18.0:
		return (hour - 18.0) / 2.0   # dusk fade-in  18 → 20
	elif hour < 8.0:
		return 1.0 - (hour - 6.0) / 2.0  # dawn fade-out 6 → 8
	return 0.0

# ── Speed — faster at night ───────────────────────────────────────────────────

func _update_fox_speed():
	if state == State.SLEEPING or state == State.SLEEP_WALKING:
		return
	var nf := _get_night_factor()
	move_speed = lerp(2.8, 4.2, nf)

# ── Night glow — intensifies at dusk, dims at dawn ───────────────────────────

func _update_fox_glow():
	if attraction_stage == AttractionStage.BONDED or _is_sleeping:
		return
	if not _fox_mat:
		return
	# Drive the tail shader's emission_strength uniform with the night factor
	var nf := _get_night_factor()
	_fox_mat.set_shader_parameter("emission_strength", lerp(1.0, 4.0, nf))

# ── Selection highlight — ShaderMaterial-safe override ───────────────────────

func _get_selectable_mesh() -> MeshInstance3D:
	var model := get_node_or_null("FoxModel")
	if model:
		return _find_mesh(model)
	return null

func on_selected():
	# Drive selection via shader uniform instead of StandardMaterial3D properties
	var mesh := _get_selectable_mesh()
	if mesh:
		var mat := mesh.get_active_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("selection_highlight", 1.0)
	if selection_ring:
		selection_ring.visible = true
		_ring_pulse_timer = 0.0

func on_deselected():
	var mesh := _get_selectable_mesh()
	if mesh:
		var mat := mesh.get_active_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("selection_highlight", 0.0)
	# Re-apply tail shader override in case it was cleared
	if _fox_mat:
		mesh = _get_selectable_mesh()
		if mesh:
			mesh.set_surface_override_material(1, _fox_mat)
	if selection_ring:
		selection_ring.visible = false

# ── Wander — tighter range, biased toward food ───────────────────────────────

func pick_wander_target():
	var half_area := 19.0
	# 30 % chance: drift toward the nearest berry bush
	if randf() < 0.3:
		var food_items := get_tree().get_nodes_in_group("food")
		if not food_items.is_empty():
			var nearest: Node3D = food_items[0]
			var best_dist := INF
			for item in food_items:
				var d := global_position.distance_to((item as Node3D).global_position)
				if d < best_dist:
					best_dist = d
					nearest = item
			var t := nearest.global_position + Vector3(
				randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
			wander_target = Vector3(
				clamp(t.x, -half_area, half_area), t.y,
				clamp(t.z, -half_area, half_area))
			wander_timer = randf_range(3.0, 7.0)
			return
	# Standard wander — tighter radius than base (12 vs 20)
	var wander_range := 12.0
	var t := global_position + Vector3(
		randf_range(-wander_range, wander_range), 0.0, randf_range(-wander_range, wander_range))
	wander_target = Vector3(
		clamp(t.x, -half_area, half_area), t.y,
		clamp(t.z, -half_area, half_area))
	wander_timer = randf_range(3.0, 8.0)
