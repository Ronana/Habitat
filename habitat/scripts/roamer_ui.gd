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

# Quest board
var _quest_panel: PanelContainer = null
var _quest_rows: Array = []

# Selected roamer info panel (built entirely in code)
var _info_panel: PanelContainer = null
var _info_name_lbl: Label = null
var _info_sub_lbl: Label = null
var _info_happiness_bar: ProgressBar = null
var _info_food_bar: ProgressBar = null
var _info_safety_bar: ProgressBar = null
var _info_space_bar: ProgressBar = null
var _info_den_lbl: Label = null
var _info_traits_lbl: Label = null

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
	$Panel/VBoxContainer/JournalButton.pressed.connect(_on_journal_button)
	$Panel/VBoxContainer/QuestsButton.pressed.connect(_on_quests_button)
	_apply_theme()
	_build_roamer_info_panel()
	_build_quest_panel()
	MilestoneManager.milestone_achieved.connect(_on_milestone_achieved)
	ObjectiveManager.objectives_updated.connect(_refresh_quest_panel)
	ObjectiveManager.objective_completed.connect(_on_objective_completed)

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
	_style_button($Panel/VBoxContainer/JournalButton)
	_style_button($Panel/VBoxContainer/QuestsButton)

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
	
	

# ── Selected roamer info panel ────────────────────────────────────────────────
func _build_roamer_info_panel():
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_info_panel.custom_minimum_size = Vector2(240, 0)
	# Anchor to right side, vertically centred
	_info_panel.anchor_left   = 1.0
	_info_panel.anchor_right  = 1.0
	_info_panel.anchor_top    = 0.5
	_info_panel.anchor_bottom = 0.5
	_info_panel.offset_left   = -260.0
	_info_panel.offset_right  = -20.0
	_info_panel.offset_top    = -180.0
	_info_panel.offset_bottom =  180.0
	_info_panel.visible = false
	add_child(_info_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_info_panel.add_child(vbox)

	_info_name_lbl = Label.new()
	_info_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_name_lbl.add_theme_font_size_override("font_size", 16)
	_info_name_lbl.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(_info_name_lbl)

	_info_sub_lbl = Label.new()
	_info_sub_lbl.add_theme_font_size_override("font_size", 11)
	_info_sub_lbl.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_info_sub_lbl)

	# Traits row
	_info_traits_lbl = Label.new()
	_info_traits_lbl.add_theme_font_size_override("font_size", 11)
	_info_traits_lbl.add_theme_color_override("font_color", Color(0.80, 0.90, 0.65, 1.0))
	_info_traits_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_traits_lbl.custom_minimum_size = Vector2(210, 0)
	vbox.add_child(_info_traits_lbl)

	vbox.add_child(HSeparator.new())

	# Helper to add a labelled progress bar
	for cfg in [
		["♥  Happiness", "h"],
		["🍃  Food",     "f"],
		["🛡  Safety",   "s"],
		["↔  Space",    "sp"]
	]:
		var lbl := Label.new()
		lbl.text = cfg[0]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", C_TEXT)
		vbox.add_child(lbl)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(0, 12)
		bar.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		vbox.add_child(bar)
		match cfg[1]:
			"h":  _info_happiness_bar = bar
			"f":  _info_food_bar      = bar
			"s":  _info_safety_bar    = bar
			"sp": _info_space_bar     = bar

	_style_bar(_info_happiness_bar, Color(0.35, 0.80, 0.35))
	_style_bar(_info_food_bar,      Color(0.90, 0.65, 0.20))
	_style_bar(_info_safety_bar,    Color(0.30, 0.60, 0.90))
	_style_bar(_info_space_bar,     Color(0.75, 0.45, 0.85))

	vbox.add_child(HSeparator.new())

	_info_den_lbl = Label.new()
	_info_den_lbl.add_theme_font_size_override("font_size", 11)
	_info_den_lbl.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_info_den_lbl)

func _update_info_panel():
	if not tracked_roamer or not _info_panel:
		return
	var stage_names := ["Appears", "Visits", "Resident", "Bonded"]
	_info_name_lbl.text = tracked_roamer.roamer_name if tracked_roamer.roamer_name != "" else tracked_roamer.name
	_info_sub_lbl.text  = tracked_roamer.species_id + "  ·  " + stage_names[tracked_roamer.attraction_stage]
	if _info_traits_lbl:
		_info_traits_lbl.text = tracked_roamer.get_traits_display() if tracked_roamer.has_method("get_traits_display") else ""

	var h: float = tracked_roamer.happiness
	_info_happiness_bar.value = h
	_info_food_bar.value      = tracked_roamer.needs.get("food",   0.0)
	_info_safety_bar.value    = tracked_roamer.needs.get("safety", 0.0)
	_info_space_bar.value     = tracked_roamer.needs.get("space",  0.0)

	# Recolour happiness bar: green → yellow → red
	var h_col: Color
	if h > 0.6:
		h_col = Color(0.35, 0.80, 0.35)
	elif h > 0.3:
		h_col = Color(0.85, 0.75, 0.10)
	else:
		h_col = Color(0.85, 0.25, 0.15)
	_style_bar(_info_happiness_bar, h_col)

	# Den status
	if tracked_roamer.has_shelter and is_instance_valid(tracked_roamer.shelter_node):
		var den = tracked_roamer.shelter_node
		_info_den_lbl.text = "🏠 " + den.get_display_name()
	else:
		_info_den_lbl.text = "🏠 No den yet"

# ── Milestone popup ───────────────────────────────────────────────────────────
func _on_milestone_achieved(title: String, subtitle: String):
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.06, 0.96)
	style.border_color = Color(0.95, 0.80, 0.30)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	popup.add_theme_stylebox_override("panel", style)
	popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	popup.offset_top = 80.0
	popup.offset_bottom = 80.0

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	popup.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30))
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.custom_minimum_size = Vector2(280, 0)
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", C_TEXT)
	vbox.add_child(sub_lbl)

	add_child(popup)
	popup.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(popup, "modulate", Color(1, 1, 1, 1), 0.4)
	tween.tween_interval(3.0)
	tween.tween_property(popup, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(popup.queue_free)

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
	if _info_panel:
		_info_panel.visible = true
	_update_info_panel()

func hide_roamer():
	tracked_roamer = null
	roamer_name.text = "No Roamer Selected"
	stage_label.text = "Stage: —"
	food_bar.value = 0.0
	if _info_panel:
		_info_panel.visible = false

func update_ui():
	var stage_names = ["Appears", "Visits", "Resident", "Bonded"]
	stage_label.text = "Stage: " + stage_names[tracked_roamer.attraction_stage]
	food_bar.value = tracked_roamer.needs["food"]
	_update_info_panel()

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

func _on_quests_button():
	if _quest_panel:
		_quest_panel.visible = not _quest_panel.visible

# ── Quest board ────────────────────────────────────────────────────────────────

func _build_quest_panel():
	_quest_panel = PanelContainer.new()
	_quest_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_quest_panel.custom_minimum_size = Vector2(280, 0)
	_quest_panel.anchor_left   = 0.0
	_quest_panel.anchor_right  = 0.0
	_quest_panel.anchor_top    = 0.0
	_quest_panel.anchor_bottom = 0.0
	_quest_panel.offset_left   = 20.0
	_quest_panel.offset_top    = 420.0
	_quest_panel.offset_right  = 300.0
	_quest_panel.offset_bottom = 700.0
	_quest_panel.visible = false
	add_child(_quest_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_quest_panel.add_child(vbox)

	var title := Label.new()
	title.text = "📋  Maren's Requests"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_quest_rows.clear()
	for i in range(ObjectiveManager.MAX_ACTIVE):
		var row_box := VBoxContainer.new()
		row_box.add_theme_constant_override("separation", 2)
		vbox.add_child(row_box)

		var desc_lbl := Label.new()
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(250, 0)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", C_TEXT)
		row_box.add_child(desc_lbl)

		var reward_lbl := Label.new()
		reward_lbl.add_theme_font_size_override("font_size", 10)
		reward_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		row_box.add_child(reward_lbl)

		_quest_rows.append({"desc": desc_lbl, "reward": reward_lbl, "box": row_box})

		if i < ObjectiveManager.MAX_ACTIVE - 1:
			vbox.add_child(HSeparator.new())

	_refresh_quest_panel()

func _refresh_quest_panel():
	for i in range(_quest_rows.size()):
		var row = _quest_rows[i]
		if i < ObjectiveManager.active_objectives.size():
			var obj: Dictionary = ObjectiveManager.active_objectives[i]
			row["desc"].text   = "• " + obj.get("desc", "")
			row["reward"].text = "Reward: " + str(obj.get("reward", 0)) + " 💧"
			row["box"].visible = true
		else:
			row["box"].visible = false

func _on_objective_completed(obj: Dictionary):
	var reward_text := "+ " + str(obj.get("reward", 0)) + " 💧  Quest complete!"
	_on_milestone_achieved("✓ Quest Complete!", obj.get("desc", "") + "\n" + reward_text)
	_refresh_quest_panel()

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
