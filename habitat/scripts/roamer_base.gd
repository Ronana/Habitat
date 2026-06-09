extends CharacterBody3D

enum State { WANDERING, IDLE, FLEEING }
enum AttractionStage { APPEARS, VISITS, RESIDENT, BONDED }

var state = State.WANDERING
var attraction_stage = AttractionStage.APPEARS
var wander_target: Vector3
var wander_timer: float = 0.0
var idle_timer: float = 0.0
var move_speed: float = 2.5
var gravity: float = -20.0

# Needs — each fills from 0.0 to 1.0
var needs = {
	"food": 0.5,
	"safety": 1.0,
	"space": 1.0
}

# How fast each need depletes per second
var need_decay = {
	"food": 0.01,
	"safety": 0.0,
	"space": 0.0
}

var happiness: float = 1.0

func _ready():
	pick_wander_target()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	update_needs(delta)
	update_happiness()

	match state:
		State.WANDERING:
			handle_wandering(delta)
		State.IDLE:
			handle_idle(delta)

	move_and_slide()

func update_needs(delta):
	for need in needs:
		needs[need] = max(0.0, needs[need] - need_decay[need] * delta)

func update_happiness():
	var total = 0.0
	for need in needs:
		total += needs[need]
	happiness = total / needs.size()

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
	wander_target = global_position + Vector3(
		randf_range(-wander_range, wander_range),
		0,
		randf_range(-wander_range, wander_range)
	)
	wander_timer = randf_range(4.0, 10.0)

func move_to(target: Vector3):
	wander_target = target
	state = State.WANDERING
	wander_timer = 20.0

func feed(food_value: float):
	needs["food"] = min(1.0, needs["food"] + food_value)
	print("Fed! Food need: ", needs["food"])
	check_stage_progress()

func check_stage_progress():
	match attraction_stage:
		AttractionStage.APPEARS:
			if happiness > 0.5:
				attraction_stage = AttractionStage.VISITS
				print(name, " is now VISITING!")
		AttractionStage.VISITS:
			if happiness > 0.7:
				attraction_stage = AttractionStage.RESIDENT
				print(name, " is now a RESIDENT!")
		AttractionStage.RESIDENT:
			if happiness > 0.9:
				attraction_stage = AttractionStage.BONDED
				print(name, " is now BONDED!")

func on_selected():
	var body = get_node("Body")
	var mat = body.get_active_material(0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 2.0

func on_deselected():
	var body = get_node("Body")
	var mat = body.get_active_material(0)
	mat.emission_enabled = false
