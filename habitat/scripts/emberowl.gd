## emberowl.gd — nocturnal round owl, slow by day, alert at night.
extends "res://scripts/roamer_base.gd"

var _blink_timer  : float = 0.0
var _blink_open   : bool  = true
var _next_blink   : float = 3.5
var _bob_timer    : float = 0.0

func _ready() -> void:
	species_id          = "Emberowl"
	creature_scene_path = "res://creatures/emberowl.tscn"
	move_speed          = 1.4           # slow glide
	dewdrop_interval    = 7.0
	hunger_threshold    = 0.35
	need_decay["food"]  = 0.008
	need_decay["safety"] = 0.006
	_selection_color    = Color(0.95, 0.55, 0.15)  # warm amber glow
	super._ready()

# ── Nocturnal schedule — mirrors GlowFox ─────────────────────────────────────

func _check_sleep_state() -> void:
	if state == State.BREEDING:
		return
	var hour : float = DayNightManager.current_time
	var is_daytime : bool = hour >= 7.0 and hour < 19.0
	if is_daytime:
		if state != State.SLEEPING and state != State.SLEEP_WALKING:
			_begin_sleep_walk()
	else:
		if state == State.SLEEPING or state == State.SLEEP_WALKING:
			_wake_up()

# ── Night factor ──────────────────────────────────────────────────────────────

func _get_night_factor() -> float:
	var hour : float = DayNightManager.current_time
	if hour >= 21.0 or hour < 5.0:
		return 1.0
	elif hour >= 19.0:
		return (hour - 19.0) / 2.0
	elif hour < 7.0:
		return 1.0 - (hour - 5.0) / 2.0
	return 0.0

# ── Speed — faster at night ───────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var nf := _get_night_factor()
	move_speed = lerp(1.4, 2.8, nf)
	super._physics_process(delta)

# ── Per-frame — ember glow + blink ───────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	_update_ember_glow()
	_update_blink(delta)
	_update_head_bob(delta)

func _update_ember_glow() -> void:
	var nf   := _get_night_factor()
	var eyes := [get_node_or_null("EyeL"), get_node_or_null("EyeR")]
	for eye in eyes:
		if eye is MeshInstance3D:
			var mat := eye.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.emission_enabled = true
				mat.emission          = Color(1.0, 0.55, 0.05)
				mat.emission_energy_multiplier = lerp(0.5, 3.5, nf)

func _update_blink(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= _next_blink:
		_blink_timer = 0.0
		_next_blink  = randf_range(2.5, 6.0)
		_do_blink()

func _do_blink() -> void:
	var eyes := [get_node_or_null("EyeL"), get_node_or_null("EyeR")]
	for eye in eyes:
		if eye:
			var tw := create_tween()
			tw.tween_property(eye, "scale:y", 0.05, 0.07)
			tw.tween_property(eye, "scale:y", 1.00, 0.07)

func _update_head_bob(delta: float) -> void:
	if state == State.IDLE:
		_bob_timer += delta
		var head := get_node_or_null("Head")
		if head:
			head.position.y = 0.0 + 0.025 * sin(_bob_timer * 2.8)

# ── Wander — slow glide, biased toward trees at night ────────────────────────

func pick_wander_target() -> void:
	var half_area : float = ZoneManager.get_garden_half() - 1.0
	var nf := _get_night_factor()
	# At night: 35 % chance to drift near a tree
	if nf > 0.3 and randf() < 0.35:
		var trees := get_tree().get_nodes_in_group("trees")
		if not trees.is_empty():
			var t : Node3D = trees[randi() % trees.size()]
			wander_target = Vector3(
				clamp(t.global_position.x + randf_range(-2.0, 2.0), -half_area, half_area),
				t.global_position.y,
				clamp(t.global_position.z + randf_range(-2.0, 2.0), -half_area, half_area))
			wander_timer = randf_range(6.0, 12.0)
			return
	# Standard slow glide — wider range at night
	var r: float = lerp(6.0, 14.0, nf)
	var pos := global_position + Vector3(randf_range(-r, r), 0.0, randf_range(-r, r))
	wander_target = Vector3(clamp(pos.x, -half_area, half_area), pos.y, clamp(pos.z, -half_area, half_area))
	wander_timer  = randf_range(5.0, 10.0)
