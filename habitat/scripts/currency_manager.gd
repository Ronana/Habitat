extends Node

signal dewdrops_changed(new_amount)

var dewdrops: float = 50.0
var eldermoss: int = 0

func add_dewdrops(amount: float):
	dewdrops += amount
	emit_signal("dewdrops_changed", dewdrops)
	print("Dewdrops: ", dewdrops)

func spend_dewdrops(amount: float) -> bool:
	if dewdrops >= amount:
		dewdrops -= amount
		emit_signal("dewdrops_changed", dewdrops)
		print("Spent ", amount, " Dewdrops. Remaining: ", dewdrops)
		return true
	print("Not enough Dewdrops!")
	return false

func add_eldermoss(amount: int):
	eldermoss += amount
	print("Eldermoss: ", eldermoss)
