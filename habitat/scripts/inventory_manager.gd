extends Node

signal inventory_changed

var items = {}

func add_item(item_name: String, amount: int = 1):
	if items.has(item_name):
		items[item_name] += amount
	else:
		items[item_name] = amount
	emit_signal("inventory_changed")
	print("Added ", amount, "x ", item_name, " to inventory")

func remove_item(item_name: String, amount: int = 1) -> bool:
	if not items.has(item_name) or items[item_name] < amount:
		print("Not enough ", item_name, " in inventory")
		return false
	items[item_name] -= amount
	if items[item_name] <= 0:
		items.erase(item_name)
	emit_signal("inventory_changed")
	return true

func has_item(item_name: String) -> bool:
	return items.has(item_name) and items[item_name] > 0

func get_count(item_name: String) -> int:
	if items.has(item_name):
		return items[item_name]
	return 0

func get_all_items() -> Dictionary:
	return items
