## crystalback.gd — slow peaceful creature with a glowing crystal shell.
## Drawn to decorations; admires them when idle nearby.
extends "res://scripts/roamer_base.gd"

var _admire_timer    : float = 0.0
var _pulse_timer     : float = 0.0
var _in_shell        : bool  = false
var _shell_timer     : float = 0.0

func _ready() -> void:
	species_id          = "Crystalback"
	creature_scene_path = "res://creatures/crystalback.tscn"
	move_speed          = 0.85         # very slow
	dewdrop_interval    = 12.0         # slow but good income (high prestige bonus)
	hunger_threshold    = 0.35
	need_decay["food"]  = 0.006
	need_decay["safety"] = 0.003       # crystal shell = very secure
	_selection_color    = Color(0.45, 0.78, 0.95)  # crystal blue
	super._ready()

# ── Wander — very short range, biased toward decorations ─────────────────────

func pick_wander_target() -> void:
	var half_area : float = ZoneManager.get_garden_half() - 1.0
	# 50 % chance: drift toward a random decoration
	if randf() < 0.5:
		var decos := get_tree().get_nodes_in_group("decoratives")
		# filter out fences
		var real_decos : Array = []
		for d in decos:
			if not (d as Node).is_in_group("fences"):
				real_decos.append(d)
		if not real_decos.is_empty():
			var d : Node3D = real_decos[randi() % real_decos.size()]
			wander_target = Vector3(
				clamp(d.global_position.x + randf_range(-1.5, 1.5), -half_area, half_area),
				d.global_position.y,
				clamp(d.global_position.z + randf_range(-1.5, 1.5), -half_area, half_area))
			wander_timer = randf_range(8.0, 14.0)
			return
	# Standard very-short wander
	var r := 5.0
	var pos := global_position + Vector3(randf_range(-r, r), 0.0, randf_range(-r, r))
	wander_target = Vector3(clamp(pos.x, -half_area, half_area), pos.y, clamp(pos.z, -half_area, half_area))
	wander_timer  = randf_range(6.0, 12.0)

# ── Idle — admires nearby decoration, retreats into shell after a while ───────

func handle_idle(delta: float) -> void:
	idle_timer   -= delta
	velocity.x    = 0.0
	velocity.z    = 0.0

	# Check for a nearby decoration to face
	var decos := get_tree().get_nodes_in_group("decoratives")
	var nearest_dist := INF
	var nearest_deco : Node3D = null
	for d in decos:
		if (d as Node).is_in_group("fences"):
			continue
		var dist := global_position.distance_to((d as Node3D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_deco = d as Node3D
	if nearest_deco and nearest_dist < 5.0:
		_admire_timer += delta
		# Face the decoration
		var dir := (nearest_deco.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			var target_y := atan2(dir.x, dir.z)
			rotation.y   = lerp_angle(rotation.y, target_y, delta * 1.5)
	else:
		_face_cursor(delta)

	# Shell retreat
	_shell_timer += delta
	if not _in_shell and _shell_timer > 4.0:
		_enter_shell()

	if idle_timer <= 0.0:
		_admire_timer = 0.0
		_shell_timer  = 0.0
		if _in_shell:
			_exit_shell()
		pick_wander_target()
		state = State.WANDERING

# ── Shell animations ──────────────────────────────────────────────────────────

func _enter_shell() -> void:
	_in_shell = true
	_stop_idle_bob()
	var shell := get_node_or_null("Shell")
	var head  := get_node_or_null("Head")
	if shell:
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(shell, "scale", Vector3(1.35, 1.25, 1.35), 0.5)
	if head:
		create_tween().tween_property(head, "scale", Vector3(0.01, 0.01, 0.01), 0.3)

func _exit_shell() -> void:
	_in_shell = false
	var shell := get_node_or_null("Shell")
	var head  := get_node_or_null("Head")
	if shell:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(shell, "scale", Vector3(1.0, 1.0, 1.0), 0.45)
	if head:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(head, "scale", Vector3(1.0, 1.0, 1.0), 0.45)

# ── Crystal shell pulse ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	_pulse_timer += delta
	var shell := get_node_or_null("Shell")
	if shell is MeshInstance3D:
		var mat := (shell as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if mat:
			var pulse := 0.5 + 0.5 * sin(_pulse_timer * 1.4)
			mat.emission_energy_multiplier = lerp(0.4, 1.2, pulse)
