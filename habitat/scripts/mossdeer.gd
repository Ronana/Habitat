extends "res://scripts/roamer_base.gd"

func _ready():
	species_id             = "Mossdeer"
	creature_scene_path    = "res://creatures/mossdeer.tscn"
	move_speed             = 1.8
	dewdrop_interval       = 7.0
	hunger_threshold       = 0.5
	need_decay["food"]     = 0.015
	food_seek_interval     = 3.5   # checks for food more often — it's a grazer
	super._ready()

# ── Wander — large range, biased toward trees or food ────────────────────────

func pick_wander_target():
	var half_area := 19.0
	# 35 % chance: drift toward nearest tree (grazes in shade)
	if randf() < 0.35:
		var trees := get_tree().get_nodes_in_group("trees")
		if not trees.is_empty():
			var nearest: Node3D = trees[0]
			var best_dist := INF
			for t in trees:
				var d := global_position.distance_to((t as Node3D).global_position)
				if d < best_dist:
					best_dist = d
					nearest = t
			var target := nearest.global_position + Vector3(
				randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
			wander_target = Vector3(
				clamp(target.x, -half_area, half_area), target.y,
				clamp(target.z, -half_area, half_area))
			wander_timer = randf_range(6.0, 14.0)
			return
	# 20 % chance: wander near nearest food source
	if randf() < 0.20:
		var food_items := get_tree().get_nodes_in_group("food")
		if not food_items.is_empty():
			var nearest: Node3D = food_items[0]
			var best_dist := INF
			for item in food_items:
				var d := global_position.distance_to((item as Node3D).global_position)
				if d < best_dist:
					best_dist = d
					nearest = item
			var target := nearest.global_position + Vector3(
				randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
			wander_target = Vector3(
				clamp(target.x, -half_area, half_area), target.y,
				clamp(target.z, -half_area, half_area))
			wander_timer = randf_range(5.0, 10.0)
			return
	# Standard wide wander
	var range := 25.0
	var t := global_position + Vector3(
		randf_range(-range, range), 0.0, randf_range(-range, range))
	wander_target = Vector3(
		clamp(t.x, -half_area, half_area), t.y,
		clamp(t.z, -half_area, half_area))
	wander_timer = randf_range(6.0, 14.0)

# ── Idle — longer pause + occasional gentle graze dip ────────────────────────

func handle_idle(delta):
	idle_timer -= delta
	velocity.x = 0
	velocity.z = 0
	_face_cursor(delta)
	# ~0.3 % per frame: do a gentle graze animation
	if not _is_sleeping and randf() < 0.003:
		_do_graze_anim()
	if idle_timer <= 0:
		pick_wander_target()
		state = State.WANDERING

# Gentle two-dip head-graze (no food consumed — purely visual)
func _do_graze_anim():
	var body := get_node_or_null("Body")
	if not body or _is_sleeping:
		return
	_stop_idle_bob()
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(body, "position:y", _body_rest_y - 0.08, 0.45)
	t.tween_property(body, "position:y", _body_rest_y,         0.35)
	t.tween_interval(0.2)
	t.tween_property(body, "position:y", _body_rest_y - 0.06, 0.35)
	t.tween_property(body, "position:y", _body_rest_y,         0.40)
	t.tween_callback(_start_idle_bob)

func on_selected():
	super.on_selected()

func on_deselected():
	super.on_deselected()
