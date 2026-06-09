extends CanvasLayer

@onready var roamer_name = $Panel/VBoxContainer/RoamerName
@onready var stage_label = $Panel/VBoxContainer/StageLabel
@onready var food_bar = $Panel/VBoxContainer/FoodBar
@onready var currency_label = $Panel/VBoxContainer/CurrencyLabel
@onready var shop_panel = $ShopPanel
@onready var shop_dewdrops = $ShopPanel/VBoxContainer/DewdropsLabel
@onready var inventory_panel = $InventoryPanel
@onready var item_list = $InventoryPanel/VBoxContainer/ItemList
@onready var ToolManager_ref = get_tree().get_root().get_node("Garden/ToolManager")

var tracked_roamer = null
var current_trader = null

func _ready():
	CurrencyManager.dewdrops_changed.connect(_on_dewdrops_changed)
	update_currency()
	InventoryManager.inventory_changed.connect(update_inventory_ui)
	update_inventory_ui()
	WeatherManager.weather_changed.connect(_on_weather_changed)
	
	# Connect shop buttons
	$ShopPanel/VBoxContainer/Item0.pressed.connect(_on_buy_item.bind(0))
	$ShopPanel/VBoxContainer/Item1.pressed.connect(_on_buy_item.bind(1))
	$ShopPanel/VBoxContainer/Item2.pressed.connect(_on_buy_item.bind(2))
	$ShopPanel/VBoxContainer/Item3.pressed.connect(_on_buy_item.bind(3))
	$ShopPanel/VBoxContainer/CloseButton.pressed.connect(close_shop)
	$Panel/VBoxContainer/SaveButton.pressed.connect(_on_save)
	$Panel/VBoxContainer/LoadButton.pressed.connect(_on_load)
	

func _process(_delta):
	if tracked_roamer:
		update_ui()
		
	# Day/Night Cycle
	$Panel/VBoxContainer/ClockLabel.text = "🕐 " + DayNightManager.get_time_string()

func show_roamer(roamer):
	tracked_roamer = roamer
	roamer_name.text = roamer.name

func hide_roamer():
	tracked_roamer = null
	roamer_name.text = "No Roamer Selected"
	stage_label.text = "Stage: —"
	food_bar.value = 0.0

func update_ui():
	var stage_names = ["Appears", "Visits", "Resident", "Bonded"]
	stage_label.text = "Stage: " + stage_names[tracked_roamer.attraction_stage]
	food_bar.value = tracked_roamer.needs["food"]

func _on_dewdrops_changed(_amount):
	update_currency()

func update_currency():
	currency_label.text = "Dewdrops: " + str(snappedf(CurrencyManager.dewdrops, 0.1))

func open_shop(trader):
	current_trader = trader
	shop_panel.visible = true
	shop_dewdrops.text = "Dewdrops: " + str(snappedf(CurrencyManager.dewdrops, 0.1))

func close_shop():
	shop_panel.visible = false
	current_trader = null

func _on_buy_item(index: int):
	if current_trader:
		current_trader.buy_item(index)
		shop_dewdrops.text = "Dewdrops: " + str(snappedf(CurrencyManager.dewdrops, 0.1))

func _on_save():
	SaveManager.save_game(get_tree().get_root().get_node("Garden"))
	print("Saved from UI!")

func _on_load():
	SaveManager.load_game(get_tree().get_root().get_node("Garden"))
	print("Loaded from UI!")

func update_inventory_ui():
	# Clear existing items
	for child in item_list.get_children():
		child.queue_free()
	
	var items = InventoryManager.get_all_items()
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Empty"
		item_list.add_child(empty_label)
		return
	
	# Add a button for each item
	for item_name in items:
		var btn = Button.new()
		btn.text = item_name + " x" + str(items[item_name])
		btn.pressed.connect(_on_inventory_item_pressed.bind(item_name))
		item_list.add_child(btn)

func _on_inventory_item_pressed(item_name: String):
	if item_name == "Fresh Berries":
		use_fresh_berries()
		return
	# Set as active placement item
	ToolManager_ref.set_placement_item(item_name)
	print("Selected for placement: ", item_name)
	
func use_fresh_berries():
	if not tracked_roamer:
		print("Select a Roamer first!")
		return
	if InventoryManager.remove_item("Fresh Berries"):
		tracked_roamer.feed(0.5)
		print("Fed fresh berries to ", tracked_roamer.name)
		
func _on_weather_changed(new_weather):
	update_weather_ui()

func update_weather_ui():
	var icons = {
		0: "☀️ Sunny",
		1: "🌧️ Raining",
		2: "🌫️ Foggy",
		3: "💨 Windy"
	}
	$Panel/VBoxContainer/WeatherLabel.text = icons[WeatherManager.current_weather]
