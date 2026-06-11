extends "res://scripts/roamer_base.gd"

# Shell-retreat state
var _in_shell: bool = false
var _shell_timer: float = 0.0

func _ready():
	species_id             = "Stoneback"
	creature_scene_path    = "res://creatures/stoneback.tscn"
	move_speed             = 1.0          # slow and deliberate
	dewdrop_interval       = 10.0         # slow but steady income
	hunger_threshold       = 0.4
	need_decay["food"]     = 0.007        # barely gets hungry
	need_decay["safety"]   = 0.002        # stone shell = naturally safe
	super._ready()

# ── Wander — very short range, always pauses on arrival ──────────────────────

func pick_wander_target():
	var half_area := 19.0
	var range := 8.0
	var t := global_position + Vector3(
		randf_range(-range, range), 0.0, randf_range(-range, range))
	wander_target = Vector3(
		clamp(t.x, -half_area, half_area), t.y,
		clamp(t.z, -half_area, half_area))
	wander_timer = randf_range(5.0, 10.0)

func handle_wandering(delta):
	wander_timer -= delta
	var direction := wander_target - global_position
	direction.y = 0.0
	if direction.length() < 1.5 or wander_timer <= 0:
		# Stoneback always pauses — never skips straight to another wander
		state = State.IDLE
		idle_timer = randf_range(5.0, 12.0)
		_just_became_idle = true
		_cursor_tilt_done = false
		_shell_timer = 0.0
		return
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)

# ── Idle — shell retreat after ~3.5 s of stillness ───────────────────────────

func handle_idle(delta):
	idle_timer -= delta
	velocity.x = 0
	velocity.z = 0
	_face_cursor(delta)

	_shell_timer += delta
	if not _in_shell and _shell_timer > 3.5:
		_enter_shell()

	if idle_timer <= 0:
		_shell_timer = 0.0
		if _in_shell:
			_exit_shell()
		pick_wander_target()
		state = State.WANDERING

# ── Shell animations ──────────────────────────────────────────────────────────

func _enter_shell():
	_in_shell = true
	_stop_idle_bob()
	var body := get_node_or_null("Body")
	if not body:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(body, "scale", Vector3(1.45, 0.46, 1.45), 0.55)

func _exit_shell():
	_in_shell = false
	var body := get_node_or_null("Body")
	if not body:
		return
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "scale", Vector3(1.0, 1.0, 1.0), 0.45)

func on_selected():
	super.on_selected()

func on_deselected():
	super.on_deselected()
