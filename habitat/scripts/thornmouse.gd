## thornmouse.gd — small skittish forager, biased toward berry bushes and wildgrass.
extends "res://scripts/roamer_base.gd"

var _crouching  : bool  = false
var _nose_timer : float = 0.0

func _ready() -> void:
	species_id          = "Thornmouse"
	creature_scene_path = "res://creatures/thornmouse.tscn"
	move_speed          = 3.8
	dewdrop_interval    = 5.0
	hunger_threshold    = 0.45
	need_decay["food"]  = 0.013   # eats often
	need_decay["safety"] = 0.009
	_selection_color    = Color(0.88, 0.62, 0.22)  # warm amber
	super._ready()

# ── Wander — quick dashes, biased toward food and wildgrass ──────────────────

func pick_wander_target() -> void:
	var half_area : float = ZoneManager.get_garden_half() - 1.0
	# 40 % chance: dash to the nearest berry bush
	if randf() < 0.4:
		var food_items := get_tree().get_nodes_in_group("food")
		if not food_items.is_empty():
			var nearest : Node3D = food_items[0]
			var best_dist := INF
			for item in food_items:
				var d := global_position.distance_to((item as Node3D).global_position)
				if d < best_dist:
					best_dist = d
					nearest = item
			var food_pos := nearest.global_position
			wander_target = Vector3(
				clamp(food_pos.x + randf_range(-1.2, 1.2), -half_area, half_area),
				food_pos.y,
				clamp(food_pos.z + randf_range(-1.2, 1.2), -half_area, half_area))
			wander_timer = randf_range(2.5, 5.0)
			return
	# 20 % chance: scatter toward wildgrass
	if randf() < 0.2:
		var grass_nodes := get_tree().get_nodes_in_group("wildgrass")
		if not grass_nodes.is_empty():
			var g : Node3D = grass_nodes[randi() % grass_nodes.size()]
			wander_target = Vector3(
				clamp(g.global_position.x + randf_range(-0.8, 0.8), -half_area, half_area),
				g.global_position.y,
				clamp(g.global_position.z + randf_range(-0.8, 0.8), -half_area, half_area))
			wander_timer = randf_range(2.0, 4.0)
			return
	# Standard short-range dash
	var r := 7.0
	var t := global_position + Vector3(randf_range(-r, r), 0.0, randf_range(-r, r))
	wander_target = Vector3(clamp(t.x, -half_area, half_area), t.y, clamp(t.z, -half_area, half_area))
	wander_timer  = randf_range(2.0, 4.5)

# ── Idle — nose twitch ────────────────────────────────────────────────────────

func handle_idle(delta: float) -> void:
	idle_timer  -= delta
	velocity.x   = 0.0
	velocity.z   = 0.0
	_face_cursor(delta)

	_nose_timer += delta
	var head := get_node_or_null("Head")
	if head:
		# Small rapid oscillation on X axis — nose twitching
		head.rotation.x = 0.06 * sin(_nose_timer * 8.0)

	if idle_timer <= 0.0:
		_nose_timer = 0.0
		if head:
			head.rotation.x = 0.0
		pick_wander_target()
		state = State.WANDERING

# ── Agitation — crouch into the grass ────────────────────────────────────────

func play_agitated() -> void:
	super.play_agitated()
	if not _crouching:
		_crouching = true
		var body := get_node_or_null("Body")
		if body:
			var tw := create_tween().set_trans(Tween.TRANS_SINE)
			tw.tween_property(body, "scale", Vector3(1.3, 0.3, 1.3), 0.3)

func calm_agitation() -> void:
	super.calm_agitation()
	if _crouching:
		_crouching = false
		var body := get_node_or_null("Body")
		if body:
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(body, "scale", Vector3(1.0, 1.0, 1.0), 0.35)
