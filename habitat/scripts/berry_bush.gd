extends Node3D

var food_value: float = 0.3
var eat_cooldown: float = 3.0
var cooldown_timer: float = 0.0
var is_depleted: bool = false
var eat_count: int = 0
var max_eats: int = 5
var regrow_time: float = 20.0
var regrow_timer: float = 0.0

func _ready():
	add_to_group("food")
	$FoodArea.body_entered.connect(_on_body_entered)

func _process(delta):
	if cooldown_timer > 0:
		cooldown_timer -= delta

	if is_depleted:
		regrow_timer += delta
		if regrow_timer >= regrow_time:
			regrow()

func _on_body_entered(body):
	if is_depleted or cooldown_timer > 0:
		return
	var node = body
	while node:
		if node.is_in_group("roamers"):
			feed_roamer(node)
			return
		node = node.get_parent()

func feed_roamer(roamer):
	roamer.feed(food_value)
	cooldown_timer = eat_cooldown
	eat_count += 1
	if eat_count >= max_eats:
		deplete()

func deplete():
	is_depleted = true
	regrow_timer = 0.0
	$Berries.visible = false

func regrow():
	is_depleted = false
	eat_count = 0
	$Berries.visible = true
