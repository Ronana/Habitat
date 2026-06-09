extends Node3D

var food_value: float = 0.3
var eat_cooldown: float = 3.0
var cooldown_timer: float = 0.0
var is_depleted: bool = false

func _ready():
	$FoodArea.body_entered.connect(_on_body_entered)

func _process(delta):
	if cooldown_timer > 0:
		cooldown_timer -= delta

func _on_body_entered(body):
	if is_depleted:
		return
	if cooldown_timer > 0:
		return
	
	# Walk up tree to find roamer
	var node = body
	while node:
		if node.is_in_group("roamers"):
			feed_roamer(node)
			return
		node = node.get_parent()

func feed_roamer(roamer):
	roamer.feed(food_value)
	cooldown_timer = eat_cooldown
	print("Roamer ate from berry bush!")
