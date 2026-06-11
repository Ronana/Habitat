extends "res://scripts/roamer_base.gd"

# ── Per-instance material for night glow ──────────────────────────────────────
var _fox_mat: StandardMaterial3D = null

func _ready():
	move_speed     = 2.8
	dewdrop_interval = 4.0
	super._ready()
	# Duplicate body material so each GlowFox has its own emission energy
	await get_tree().process_frame
	_setup_fox_mat()

func _setup_fox_mat():
	var body := get_node_or_null("Body") as MeshInstance3D
	if not body:
		return
	var base: Material = body.get_active_material(0)
	if not base:
		return
	_fox_mat = base.duplicate() as StandardMaterial3D
	body.set_surface_override_material(0, _fox_mat)

# ── Per-frame updates ─────────────────────────────────────────────────────────

func _process(delta):
	super._process(delta)
	_update_fox_glow()

func _physics_process(delta):
	_update_fox_speed()
	super._physics_process(delta)

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
	# Bonded roamers: base class handles the warm happiness glow; we leave it alone.
	if attraction_stage == AttractionStage.BONDED or _is_sleeping:
		return
	var body := get_node_or_null("Body") as MeshInstance3D
	if not body:
		return
	# Re-create fox mat if it was cleared (e.g. after deselect restores null)
	if _fox_mat == null:
		var base: Material = body.get_active_material(0)
		if base:
			_fox_mat = base.duplicate() as StandardMaterial3D
	if _fox_mat == null:
		return
	body.set_surface_override_material(0, _fox_mat)
	var nf := _get_night_factor()
	_fox_mat.emission_energy_multiplier = lerp(0.5, 2.5, nf)

# After deselect the base class may restore null override — re-apply fox mat.
func on_deselected():
	super.on_deselected()
	if _glow_mat == null and _fox_mat != null:
		var body := get_node_or_null("Body") as MeshInstance3D
		if body:
			body.set_surface_override_material(0, _fox_mat)

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
	var range := 12.0
	var t := global_position + Vector3(
		randf_range(-range, range), 0.0, randf_range(-range, range))
	wander_target = Vector3(
		clamp(t.x, -half_area, half_area), t.y,
		clamp(t.z, -half_area, half_area))
	wander_timer = randf_range(3.0, 8.0)
