extends Node

signal dewdrops_changed(new_amount)

var dewdrops: float = 50.0
var eldermoss: int = 0

func add_dewdrops(amount: float):
	dewdrops += amount
	dewdrops_changed.emit(dewdrops)

func spend_dewdrops(amount: float) -> bool:
	if dewdrops >= amount:
		dewdrops -= amount
		dewdrops_changed.emit(dewdrops)
		return true
	return false

func add_eldermoss(amount: int):
	eldermoss += amount
