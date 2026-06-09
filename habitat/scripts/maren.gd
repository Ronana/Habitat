extends Node3D

var shop_items = [
	{"name": "Berry Seeds", "cost": 10.0, "description": "Grows a berry bush. Roamers love berries."},
	{"name": "Wildgrass Seeds", "cost": 5.0, "description": "Spreads ground cover. Attracts grazing Roamers."},
	{"name": "Oak Sapling", "cost": 25.0, "description": "Grows into a large oak. Woodland Roamers love these."},
	{"name": "Fresh Berries", "cost": 8.0, "description": "Feed directly to a Roamer to boost food need."},
]

var is_shop_open = false

func _ready():
	$InteractionArea.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Someone entered Maren's area: ", body.name)

func open_shop():
	is_shop_open = true
	print("Maren's shop is open!")
	print("--- Maren's Wares ---")
	for i in range(shop_items.size()):
		var item = shop_items[i]
		print(i, ". ", item["name"], " — ", item["cost"], " Dewdrops — ", item["description"])
	print("Current Dewdrops: ", CurrencyManager.dewdrops)

func buy_item(index: int):
	if index >= shop_items.size():
		print("Invalid item")
		return
	var item = shop_items[index]
	if CurrencyManager.spend_dewdrops(item["cost"]):
		print("Purchased: ", item["name"])
		apply_purchase(item["name"])
	else:
		print("Not enough Dewdrops!")

func apply_purchase(item_name: String):
	match item_name:
		"Berry Seeds":
			InventoryManager.add_item("Berry Seeds")
		"Wildgrass Seeds":
			InventoryManager.add_item("Wildgrass Seeds")
		"Oak Sapling":
			InventoryManager.add_item("Oak Sapling")
		"Fresh Berries":
			InventoryManager.add_item("Fresh Berries")
