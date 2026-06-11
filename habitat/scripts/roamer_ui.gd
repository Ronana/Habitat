extends CanvasLayer

@onready var roamer_name = $Panel/VBoxContainer/RoamerName
@onready var stage_label = $Panel/VBoxContainer/StageLabel
@onready var food_bar = $Panel/VBoxContainer/FoodBar
@onready var currency_label = $Panel/VBoxContainer/CurrencyLabel
@onready var shop_panel = $ShopPanel
@onready var shop_dewdrops = $ShopPanel/VBoxContainer/DewdropsLabel
@onready var shop_feedback = $ShopPanel/VBoxContainer/FeedbackLabel
@onready var shop_item_container = $ShopPanel/VBoxContainer/ItemContainer
@onready var placement_label = $Panel/VBoxContainer/PlacementLabel
@onready var attraction_hints = $Panel/VBoxContainer/AttractionHints
@onready var inventory_panel = $InventoryPanel
@onready var item_list = $InventoryPanel/VBoxContainer/ItemList
@onready var ToolManager_ref = get_tree().get_root().get_node("Garden/ToolManager")
@onready var warden_title = $WardenPanel/VBoxContainer/WardenTitle
@onready var level_label = $WardenPanel/VBoxContainer/LevelLabel
@onready var xp_label = $WardenPanel/VBoxContainer/XPLabel
@onready var xp_bar = $WardenPanel/VBoxContainer/XPBar

var tracked_roamer = null
var current_trader = null
var _attraction_hint_timer: float = 0.0

func _ready():
	CurrencyManager.dewdrops_changed.connect(_on_dewdrops_changed)
	update_currency()
	InventoryManager.inventory_changed.connect(update_inventory_ui)
	update_inventory_ui()
	WeatherManager.weather_changed.connect(_on_weather_changed)
	WardenManager.xp_gained.connect(_on_xp_gained)
	WardenManager.level_up.connect(_on_level_up)
	update_warden_ui()
	SeasonManager.season_changed.connect(_on_season_changed)
	SeasonManager.day_passed.connect(_on_day_passed)
	update_season_ui()
	$ShopPanel/VBoxContainer/CloseButton.pressed.connect(close_shop)
	$Panel/VBoxContainer/SaveButton.pressed.connect(_on_save)
	$Panel/VBoxContainer/LoadButton.pressed.connect(_on_load)
	$Panel/VBoxContainer/JournalButton.pressed.connect(_on_journal_button)
	_apply_theme()

# ── Theme ─────────────────────────────────────────────────────────────────────
const C_BG        := Color(0.07, 0.11, 0.07, 0.90)
const C_BORDER     := Color(0.28, 0.46, 0.22, 1.00)
const C_TEXT       := Color(0.93, 0.91, 0.82, 1.00)
const C_MUTED      := Color(0.62, 0.72, 0.52, 1.00)
const C_ACCENT     := Color(0.52, 0.82, 0.32, 1.00)
const C_BTN_NORM   := Color(0.14, 0.24, 0.11, 1.00)
const C_BTN_HOVER  := Color(0.22, 0.38, 0.17, 1.00)
const C_BTN_PRESS  := Color(0.08, 0.15, 0.06, 1.00)

func _make_panel_style(bg: Color = C_BG, border: Color = C_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	return s

func _make_btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(6)
	return s

func _style_button(btn: Button):
	btn.add_theme_stylebox_override("normal",   _make_btn_style(C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",    _make_btn_style(C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed",  _make_btn_style(C_BTN_PRESS))
	btn.add_theme_color_override("font_color",  C_TEXT)
	btn.add_theme_color_override("font_hover_color",   C_ACCENT)
	btn.add_theme_color_override("font_pressed_color", C_TEXT)

func _style_bar(bar: ProgressBar, fill: Color):
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(4)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.10, 0.16, 0.08, 1.0)
	bg_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_color_override("font_color", Color(0, 0, 0, 0))  # hide default % text

func _style_label(lbl: Label, size: int = 13, color: Color = C_TEXT):
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

func _apply_theme():
	# Panels
	var panel_style = _make_panel_style()
	for panel in get_tree().get_nodes_in_group("ui_panels"):
		panel.add_theme_stylebox_override("panel", panel_style)

	# VBox separation
	for vbox in [$Panel/VBoxContainer, $ShopPanel/VBoxContainer,
				 $InventoryPanel/VBoxContainer, $WardenPanel/VBoxContainer]:
		vbox.add_theme_constant_override("separation", 5)

	# ── Main panel labels ──────────────────────────────────────────────────────
	_style_label($Panel/VBoxContainer/RoamerName, 15, C_ACCENT)
	_style_label($Panel/VBoxContainer/StageLabel, 12, C_MUTED)
	_style_label($Panel/VBoxContainer/FoodLabel,  11, C_MUTED)
	_style_label($Panel/VBoxContainer/CurrencyLabel, 13, Color(0.55, 0.85, 1.0, 1.0))
	_style_label($Panel/VBoxContainer/ToolLabel,  11, C_MUTED)
	_style_label($Panel/VBoxContainer/ClockLabel, 12, C_TEXT)
	_style_label($Panel/VBoxContainer/WeatherLabel, 12, C_TEXT)
	_style_label($Panel/VBoxContainer/SeasonLabel,  12, Color(0.95, 0.80, 0.50, 1.0))
	_style_label($Panel/VBoxContainer/PlacementLabel, 11, C_ACCENT)
	_style_label($Panel/VBoxContainer/AttractionTitle, 12, Color(0.85, 0.95, 0.65, 1.0))
	$Panel/VBoxContainer/AttractionTitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/VBoxContainer/AttractionTitle.custom_minimum_size = Vector2(220, 0)
	_style_label($Panel/VBoxContainer/AttractionHints, 10, C_MUTED)

	# Food bar — amber
	_style_bar(food_bar, Color(0.90, 0.65, 0.20, 1.0))

	# Main panel buttons
	_style_button($Panel/VBoxContainer/SaveButton)
	_style_button($Panel/VBoxContainer/LoadButton)
	_style_button($Panel/VBoxContainer/JournalButton)

	# ── Shop panel ─────────────────────────────────────────────────────────────
	_style_label($ShopPanel/VBoxContainer/ShopTitle, 16, C_ACCENT)
	_style_label($ShopPanel/VBoxContainer/DewdropsLabel, 13, Color(0.55, 0.85, 1.0, 1.0))
	_style_label($ShopPanel/VBoxContainer/FeedbackLabel, 12, C_TEXT)
	_style_button($ShopPanel/VBoxContainer/CloseButton)

	# ── Inventory panel ────────────────────────────────────────────────────────
	_style_label($InventoryPanel/VBoxContainer/InventoryTitle, 14, C_ACCENT)

	# ── Warden panel ───────────────────────────────────────────────────────────
	_style_label(warden_title, 14, C_ACCENT)
	_style_label(level_label,  13, C_TEXT)
	_style_label(xp_label,     11, C_MUTED)
	# XP bar — bright green
	_style_bar(xp_bar, Color(0.45, 0.80, 0.28, 1.0))
	
	

func _process(delta):
	if tracked_roamer:
		update_ui()
	$Panel/VBoxContainer/ClockLabel.text = "🕐 " + DayNightManager.get_time_string()

	# Update attraction hints every 3 seconds to avoid per-frame work
	_attraction_hint_timer += delta
	if _attraction_hint_timer >= 3.0:
		_attraction_hint_timer = 0.0
		_update_attraction_hints()

func _update_attraction_hints():
	var garden = get_tree().get_root().get_node_or_null("Garden")
	if not garden:
		return
	if garden.has_method("get_objective_hint"):
		$Panel/VBoxContainer/AttractionTitle.text = garden.get_objective_hint()
	if garden.has_method("get_attraction_hints"):
		var hints: Array = garden.get_attraction_hints()
		attraction_hints.text = "\n".join(hints)

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
	shop_feedback.text = ""
	_rebuild_shop_buttons()
	_update_shop_dewdrops()

func _rebuild_shop_buttons():
	for child in shop_item_container.get_children():
		child.queue_free()
	if not current_trader:
		return
	var all_items = current_trader.shop_items
	# Unlocked items — fully interactive
	for i in range(all_items.size()):
		var item = all_items[i]
		if WardenManager.current_level < item.get("min_level", 1):
			continue
		var vbox = VBoxContainer.new()
		var btn = Button.new()
		btn.text = item["name"] + "  —  " + str(item["cost"]) + " 💧"
		btn.custom_minimum_size = Vector2(260, 36)
		btn.pressed.connect(_on_buy_item.bind(i))
		_style_button(btn)
		var desc = Label.new()
		desc.text = item["description"]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(260, 0)
		_style_label(desc, 11, C_MUTED)
		vbox.add_child(btn)
		vbox.add_child(desc)
		shop_item_container.add_child(vbox)
	# Locked items — shown greyed with level requirement
	for item in all_items:
		var min_lvl: int = item.get("min_level", 1)
		if WardenManager.current_level >= min_lvl:
			continue
		var vbox = VBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "🔒 " + item["name"] + "  —  Lv." + str(min_lvl)
		lbl.modulate = Color(0.55, 0.55, 0.55, 1.0)
		lbl.custom_minimum_size = Vector2(260, 36)
		vbox.add_child(lbl)
		shop_item_container.add_child(vbox)

func _update_shop_dewdrops():
	shop_dewdrops.text = "💧 " + str(int(CurrencyManager.dewdrops)) + " Dewdrops"

func close_shop():
	if current_trader and current_trader.has_method("hide_selection_ring"):
		current_trader.hide_selection_ring()
	shop_panel.visible = false
	current_trader = null

func _on_buy_item(index: int):
	if not current_trader:
		return
	var item = current_trader.shop_items[index]
	if CurrencyManager.dewdrops >= item["cost"]:
		current_trader.buy_item(index)
		_update_shop_dewdrops()
		_show_shop_feedback("Purchased: " + item["name"] + "!", Color(0.3, 0.9, 0.3))
		AudioManager.play_buy()
	else:
		_show_shop_feedback("Not enough Dewdrops! (need " + str(int(item["cost"])) + ")", Color(1, 0.3, 0.3))
		AudioManager.play_error()

func _show_shop_feedback(msg: String, colour: Color):
	shop_feedback.text = msg
	shop_feedback.modulate = colour
	await get_tree().create_timer(2.5).timeout
	shop_feedback.text = ""

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
		_style_button(btn)
		item_list.add_child(btn)

func _on_inventory_item_pressed(item_name: String):
	AudioManager.play_select()
	if item_name == "Roamer Treat":
		use_roamer_treat()
		return
	if item_name == "Fresh Berries":
		use_roamer_treat_named("Fresh Berries")
		return
	# Set as active placement item
	ToolManager_ref.set_placement_item(item_name)
	placement_label.text = "📦 Placing: " + item_name + "  (right-click to place)"

func use_roamer_treat():
	use_roamer_treat_named("Roamer Treat")

func use_roamer_treat_named(item_name: String):
	if not tracked_roamer:
		placement_label.text = "⚠ Select a Roamer first!"
		placement_label.modulate = Color(1, 0.6, 0.2)
		return
	if InventoryManager.remove_item(item_name):
		tracked_roamer.feed(0.5)
		placement_label.text = "🍓 Fed " + item_name + " to " + tracked_roamer.name
		placement_label.modulate = Color(0.4, 0.9, 0.4)
		
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

func _on_xp_gained(_amount, _total):
	update_warden_ui()

func _on_level_up(_new_level):
	update_warden_ui()
	show_level_up_message()

func update_warden_ui():
	warden_title.text = "🌿 " + WardenManager.get_title()
	level_label.text = "Level " + str(WardenManager.current_level)
	xp_label.text = "XP: " + str(int(WardenManager.current_xp)) + " / " + str(int(WardenManager.xp_to_next_level))
	xp_bar.value = WardenManager.get_level_progress()

func show_level_up_message():
	# Build a centred popup panel
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.06, 0.96)
	style.border_color = C_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	popup.add_theme_stylebox_override("panel", style)
	popup.set_anchors_preset(Control.PRESET_CENTER)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	popup.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "✨ LEVEL UP!"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(title_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "Warden Level " + str(WardenManager.current_level)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 16)
	level_lbl.add_theme_color_override("font_color", C_TEXT)
	vbox.add_child(level_lbl)

	var unlock_text: String = WardenManager.level_unlocks.get(WardenManager.current_level, "")
	if unlock_text != "":
		var sep := HSeparator.new()
		vbox.add_child(sep)
		var unlock_lbl := Label.new()
		unlock_lbl.text = "🔓 " + unlock_text
		unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unlock_lbl.custom_minimum_size = Vector2(300, 0)
		unlock_lbl.add_theme_font_size_override("font_size", 12)
		unlock_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.65, 1.0))
		vbox.add_child(unlock_lbl)

	add_child(popup)

	# Animate: fade in, hold, fade out
	popup.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(popup, "modulate", Color(1, 1, 1, 1), 0.4)
	tween.tween_interval(2.8)
	tween.tween_property(popup, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(popup.queue_free)

func _on_journal_button():
	var journal = get_tree().get_root().get_node("Garden/FieldJournal")
	journal.toggle_journal()

func _on_season_changed(_season):
	update_season_ui()

func _on_day_passed(_day):
	update_season_ui()

func update_season_ui():
	var label = $Panel/VBoxContainer/SeasonLabel
	if label:
		label.text = SeasonManager.get_season_string()
	else:
		print("ERROR: SeasonLabel not found")
