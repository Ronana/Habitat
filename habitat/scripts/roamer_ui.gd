extends CanvasLayer

@onready var roamer_name = $Panel/VBoxContainer/RoamerName
@onready var stage_label = $Panel/VBoxContainer/StageLabel
@onready var food_bar = $Panel/VBoxContainer/FoodBar
@onready var currency_label = $Panel/VBoxContainer/CurrencyLabel
@onready var shop_panel = $ShopPanel
@onready var shop_dewdrops = $ShopPanel/VBoxContainer/DewdropsLabel

var tracked_roamer = null
var current_trader = null

func _ready():
	CurrencyManager.dewdrops_changed.connect(_on_dewdrops_changed)
	update_currency()
	
	# Connect shop buttons
	$ShopPanel/VBoxContainer/Item0.pressed.connect(_on_buy_item.bind(0))
	$ShopPanel/VBoxContainer/Item1.pressed.connect(_on_buy_item.bind(1))
	$ShopPanel/VBoxContainer/Item2.pressed.connect(_on_buy_item.bind(2))
	$ShopPanel/VBoxContainer/Item3.pressed.connect(_on_buy_item.bind(3))
	$ShopPanel/VBoxContainer/CloseButton.pressed.connect(close_shop)

func _process(_delta):
	if tracked_roamer:
		update_ui()

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
