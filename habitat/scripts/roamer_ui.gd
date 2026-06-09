extends CanvasLayer

@onready var roamer_name = $Panel/VBoxContainer/RoamerName
@onready var stage_label = $Panel/VBoxContainer/StageLabel
@onready var food_bar = $Panel/VBoxContainer/FoodBar

var tracked_roamer = null

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

func _ready():
	CurrencyManager.dewdrops_changed.connect(_on_dewdrops_changed)
	update_currency()

func _on_dewdrops_changed(_amount):
	update_currency()

func update_currency():
	$Panel/VBoxContainer/CurrencyLabel.text = "Dewdrops: " + str(snappedf(CurrencyManager.dewdrops, 0.1))
