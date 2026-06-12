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

# Toast notifications
var _toast_stack: Array = []
const TOAST_WIDTH  := 280.0
const TOAST_HEIGHT := 56.0
const TOAST_PAD    := 8.0
const TOAST_MARGIN := 16.0

# Roamer hover card
var _hover_card: PanelContainer = null
var _hover_card_name: Label = null
var _hover_card_stage: Label = null
var _hover_card_bar: ProgressBar = null
var _hover_card_need: Label = null
var _hovered_roamer = null
var _hover_hide_tween: Tween = null
const HOVER_RADIUS_PX := 70.0

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
	PrestigeManager.score_changed.connect(_on_prestige_changed)
	_update_prestige_label(PrestigeManager.current_score)
	_build_hover_card()

# ── Theme ─────────────────────────────────────────────────────────────────────
const C_BG         := Color(0.04, 0.07, 0.04, 0.96)
const C_BG_LIGHT   := Color(0.07, 0.12, 0.06, 0.96)
const C_BORDER     := Color(0.28, 0.46, 0.22, 1.00)
const C_BORDER_DIM := Color(0.15, 0.26, 0.12, 1.00)
const C_TEXT       := Color(0.93, 0.91, 0.82, 1.00)
const C_MUTED      := Color(0.58, 0.70, 0.48, 1.00)
const C_ACCENT     := Color(0.52, 0.88, 0.32, 1.00)
const C_GOLD       := Color(0.95, 0.80, 0.28, 1.00)
const C_DEWDROP    := Color(0.55, 0.88, 1.00, 1.00)
const C_BTN_NORM   := Color(0.10, 0.19, 0.08, 1.00)
const C_BTN_HOVER  := Color(0.18, 0.34, 0.14, 1.00)
const C_BTN_PRESS  := Color(0.06, 0.12, 0.05, 1.00)

# Animated dewdrop display
var _disp_dewdrops: float = 0.0
var _tween_dewdrops: Tween = null

func _make_panel_style(bg: Color = C_BG, border: Color = C_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	s.shadow_size = 6
	s.shadow_offset = Vector2(2, 3)
	return s

func _make_hud_style() -> StyleBoxFlat:
	# Left accent bar — the hallmark of a premium game HUD
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.border_color = C_ACCENT  # accent colour on all sides; left is 3px so it dominates
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.set_corner_radius_all(10)
	s.content_margin_left   = 14
	s.content_margin_right  = 12
	s.content_margin_top    = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	s.shadow_size = 8
	s.shadow_offset = Vector2(3, 4)
	return s

func _make_btn_style(bg: Color, border: Color = C_BORDER_DIM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 7
	s.content_margin_bottom = 7
	return s

func _make_accent_btn_style(bg: Color) -> StyleBoxFlat:
	var s := _make_btn_style(bg, C_BORDER)
	s.set_corner_radius_all(6)
	return s

func _style_button(btn: Button, accent: bool = false):
	if accent:
		btn.add_theme_stylebox_override("normal",   _make_accent_btn_style(C_BTN_NORM))
		btn.add_theme_stylebox_override("hover",    _make_accent_btn_style(C_BTN_HOVER))
		btn.add_theme_stylebox_override("pressed",  _make_accent_btn_style(C_BTN_PRESS))
	else:
		btn.add_theme_stylebox_override("normal",   _make_btn_style(C_BTN_NORM))
		btn.add_theme_stylebox_override("hover",    _make_btn_style(C_BTN_HOVER))
		btn.add_theme_stylebox_override("pressed",  _make_btn_style(C_BTN_PRESS))
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color",          C_TEXT)
	btn.add_theme_color_override("font_hover_color",    C_ACCENT)
	btn.add_theme_color_override("font_pressed_color",  C_TEXT)
	btn.custom_minimum_size = Vector2(0, 32)

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

func _build_hover_card() -> void:
	_hover_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color      = Color(0.03, 0.06, 0.03, 0.94)
	style.border_color  = C_ACCENT
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.shadow_color  = Color(0, 0, 0, 0.6)
	style.shadow_size   = 8
	style.shadow_offset = Vector2(2, 3)
	_hover_card.add_theme_stylebox_override("panel", style)
	_hover_card.custom_minimum_size = Vector2(160, 0)
	_hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card.visible = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_hover_card.add_child(vbox)

	_hover_card_name = Label.new()
	_hover_card_name.add_theme_font_size_override("font_size", 14)
	_hover_card_name.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(_hover_card_name)

	_hover_card_stage = Label.new()
	_hover_card_stage.add_theme_font_size_override("font_size", 11)
	_hover_card_stage.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_hover_card_stage)

	_hover_card_bar = ProgressBar.new()
	_hover_card_bar.custom_minimum_size = Vector2(140, 8)
	_hover_card_bar.max_value = 1.0
	_hover_card_bar.show_percentage = false
	_style_bar(_hover_card_bar, C_ACCENT)
	vbox.add_child(_hover_card_bar)

	_hover_card_need = Label.new()
	_hover_card_need.add_theme_font_size_override("font_size", 11)
	_hover_card_need.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))
	vbox.add_child(_hover_card_need)

	add_child(_hover_card)

func _update_hover_card(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var roamers   := get_tree().get_nodes_in_group("roamers")

	var closest_roamer = null
	var closest_dist   := HOVER_RADIUS_PX

	for r in roamers:
		if not is_instance_valid(r):
			continue
		if r == tracked_roamer:
			continue  # already showing full info panel
		var screen_pos := camera.unproject_position(r.global_position + Vector3(0, 0.8, 0))
		var dist       := mouse_pos.distance_to(screen_pos)
		if dist < closest_dist:
			closest_dist   = dist
			closest_roamer = r

	if closest_roamer != _hovered_roamer:
		_hovered_roamer = closest_roamer
		if closest_roamer:
			_populate_hover_card(closest_roamer)
			_hover_card.visible = true
			_hover_card.modulate = Color(1, 1, 1, 1)
		else:
			if _hover_card.visible:
				var tw := create_tween()
				tw.tween_property(_hover_card, "modulate", Color(1, 1, 1, 0), 0.12)
				tw.tween_callback(func(): _hover_card.visible = false)

	if _hovered_roamer and _hover_card.visible:
		# Follow mouse with a small offset so the card doesn't overlap the cursor
		var card_pos := mouse_pos + Vector2(18, -10)
		var vp_size  := get_viewport().get_visible_rect().size
		card_pos.x = clamp(card_pos.x, 0, vp_size.x - _hover_card.size.x - 4)
		card_pos.y = clamp(card_pos.y, 0, vp_size.y - _hover_card.size.y - 4)
		_hover_card.position = card_pos
		# Refresh happiness bar live
		_hover_card_bar.value = _hovered_roamer.happiness
		_hover_card_bar.add_theme_stylebox_override("fill", _make_happiness_fill(_hovered_roamer.happiness))

func _populate_hover_card(roamer) -> void:
	var display_name: String = roamer.roamer_name if roamer.roamer_name != "" else roamer.name
	_hover_card_name.text  = display_name
	var stage_icons := ["👀 Appears", "🚶 Visits", "🏠 Resident", "💚 Bonded"]
	_hover_card_stage.text = stage_icons[roamer.attraction_stage]
	_hover_card_bar.value  = roamer.happiness
	_hover_card_bar.add_theme_stylebox_override("fill", _make_happiness_fill(roamer.happiness))
	# Worst need
	var worst_need := ""
	var worst_val  := 0.35
	for need_name in roamer.needs:
		if roamer.needs[need_name] < worst_val:
			worst_val = roamer.needs[need_name]
			match need_name:
				"food":   worst_need = "🍃 Hungry"
				"safety": worst_need = "⚠ Unsafe"
				"space":  worst_need = "↔ Crowded"
	_hover_card_need.text    = worst_need
	_hover_card_need.visible = worst_need != ""

func _make_happiness_fill(h: float) -> StyleBoxFlat:
	var col: Color
	if h > 0.7:
		col = C_ACCENT.lerp(Color(0.3, 0.9, 0.3), (h - 0.7) / 0.3)
	elif h > 0.4:
		col = Color(0.9, 0.75, 0.2)
	else:
		col = Color(0.9, 0.3, 0.2)
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(3)
	return s

# ── Toast notification system ─────────────────────────────────────────────────
func show_toast(icon: String, title: String, subtitle: String = "", duration: float = 3.2) -> void:
	var toast := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.04, 0.08, 0.04, 0.96)
	style.border_color = C_ACCENT
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.shadow_color  = Color(0, 0, 0, 0.55)
	style.shadow_size   = 6
	style.shadow_offset = Vector2(2, 3)
	toast.add_theme_stylebox_override("panel", style)
	toast.custom_minimum_size = Vector2(TOAST_WIDTH, TOAST_HEIGHT)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	toast.add_child(hbox)

	# Icon badge
	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", C_TEXT)
	text_vbox.add_child(title_lbl)

	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", C_MUTED)
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.custom_minimum_size = Vector2(TOAST_WIDTH - 60, 0)
		text_vbox.add_child(sub_lbl)

	add_child(toast)

	# Position: top-right, stacked below existing toasts
	var vp_size := get_viewport().get_visible_rect().size
	var stack_y := TOAST_MARGIN + _toast_stack.size() * (TOAST_HEIGHT + TOAST_PAD)
	var final_x := vp_size.x - TOAST_WIDTH - TOAST_MARGIN
	toast.position = Vector2(vp_size.x + 10, stack_y)  # start off-screen right

	_toast_stack.append(toast)

	# Slide in
	var tw_in := create_tween()
	tw_in.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(toast, "position:x", final_x, 0.25)

	# Hold, then fade out and remove
	var tw_out := create_tween()
	tw_out.tween_interval(duration)
	tw_out.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.30)
	tw_out.tween_callback(func():
		_toast_stack.erase(toast)
		toast.queue_free()
		_restack_toasts()
	)

func _restack_toasts() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	for i in _toast_stack.size():
		var t: Control = _toast_stack[i]
		if not is_instance_valid(t):
			continue
		var target_y := TOAST_MARGIN + i * (TOAST_HEIGHT + TOAST_PAD)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "position:y", target_y, 0.18)

func _make_sep() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.28, 0.46, 0.22, 0.40)
	sep_style.content_margin_top    = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.custom_minimum_size = Vector2(0, 1)
	return sep

func _inject_hud_separators():
	# Insert visual section breaks into the main HUD VBox after key nodes.
	# Runs once at startup — skips if already inserted.
	var vbox := $Panel/VBoxContainer
	var sep_after := ["FoodBar", "WeatherLabel", "PrestigeLabel", "QuestsButton"]
	var inserted := 0
	var i := 0
	while i < vbox.get_child_count():
		var child := vbox.get_child(i)
		if child.name in sep_after:
			# Check the next sibling isn't already a separator
			var next := vbox.get_child(i + 1) if i + 1 < vbox.get_child_count() else null
			if next == null or not (next is HSeparator):
				var sep := _make_sep()
				vbox.add_child(sep)
				vbox.move_child(sep, i + 1)
				inserted += 1
				i += 2
				continue
		i += 1

func _apply_theme():
	# ── Main HUD panel — premium left-accent style ─────────────────────────────
	$Panel.add_theme_stylebox_override("panel", _make_hud_style())
	$Panel.custom_minimum_size = Vector2(240, 0)

	# All other panels — rich dark with shadow
	var panel_style := _make_panel_style()
	for panel in get_tree().get_nodes_in_group("ui_panels"):
		panel.add_theme_stylebox_override("panel", panel_style)

	# VBox separation
	$Panel/VBoxContainer.add_theme_constant_override("separation", 4)
	for vbox in [$ShopPanel/VBoxContainer, $InventoryPanel/VBoxContainer,
				 $WardenPanel/VBoxContainer]:
		vbox.add_theme_constant_override("separation", 5)

	# ── Main HUD labels — three visual tiers ──────────────────────────────────
	# Tier 1 — prominent (roamer name, dewdrops)
	_style_label($Panel/VBoxContainer/RoamerName,    16, C_ACCENT)
	_style_label($Panel/VBoxContainer/CurrencyLabel, 18, C_DEWDROP)
	# Tier 2 — secondary info
	_style_label($Panel/VBoxContainer/StageLabel,   12, C_MUTED)
	_style_label($Panel/VBoxContainer/FoodLabel,    11, C_MUTED)
	_style_label($Panel/VBoxContainer/ClockLabel,   13, C_TEXT)
	_style_label($Panel/VBoxContainer/WeatherLabel, 12, C_TEXT)
	_style_label($Panel/VBoxContainer/SeasonLabel,  12, Color(0.95, 0.80, 0.50, 1.0))
	# Tier 3 — subtle / supporting
	_style_label($Panel/VBoxContainer/ToolLabel,       11, C_MUTED)
	_style_label($Panel/VBoxContainer/PrestigeLabel,   12, C_GOLD)
	_style_label($Panel/VBoxContainer/PlacementLabel,  11, C_ACCENT)
	_style_label($Panel/VBoxContainer/AttractionTitle, 11, Color(0.75, 0.92, 0.55, 1.0))
	$Panel/VBoxContainer/AttractionTitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Panel/VBoxContainer/AttractionTitle.custom_minimum_size = Vector2(220, 0)
	_style_label($Panel/VBoxContainer/AttractionHints, 10, C_MUTED)

	# Food bar — amber
	_style_bar(food_bar, Color(0.90, 0.65, 0.20, 1.0))

	# Buttons — accent style for Journal/Quests
	_style_button($Panel/VBoxContainer/JournalButton, true)
	_style_button($Panel/VBoxContainer/QuestsButton,  true)

	# Inject section separators
	_inject_hud_separators()

	# ── Shop panel ─────────────────────────────────────────────────────────────
	_style_label($ShopPanel/VBoxContainer/ShopTitle,    17, C_ACCENT)
	_style_label($ShopPanel/VBoxContainer/DewdropsLabel,13, C_DEWDROP)
	_style_label($ShopPanel/VBoxContainer/FeedbackLabel,12, C_TEXT)
	_style_button($ShopPanel/VBoxContainer/CloseButton)

	# ── Inventory panel ────────────────────────────────────────────────────────
	_style_label($InventoryPanel/VBoxContainer/InventoryTitle, 14, C_ACCENT)

	# ── Warden panel ───────────────────────────────────────────────────────────
	_style_label(warden_title, 14, C_ACCENT)
	_style_label(level_label,  13, C_TEXT)
	_style_label(xp_label,     11, C_MUTED)
	_style_bar(xp_bar, Color(0.45, 0.85, 0.28, 1.0))

	

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
	# Use a toast for quick feedback — the icon is extracted from the title if present
	show_toast("🏆", title, subtitle, 4.0)

func _process(delta: float) -> void:
	if tracked_roamer:
		update_ui()
	$Panel/VBoxContainer/ClockLabel.text = "🕐 " + DayNightManager.get_time_string()

	# Hover card — detect nearest roamer to mouse
	_update_hover_card(delta)

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
	if _info_panel and not _info_panel.visible:
		_show_panel(_info_panel, 16.0)
	_update_info_panel()

func hide_roamer():
	tracked_roamer = null
	roamer_name.text = "No Roamer Selected"
	stage_label.text = "Stage: —"
	food_bar.value = 0.0
	if _info_panel and _info_panel.visible:
		_hide_panel(_info_panel, 16.0)

func update_ui():
	var stage_names = ["Appears", "Visits", "Resident", "Bonded"]
	stage_label.text = "Stage: " + stage_names[tracked_roamer.attraction_stage]
	food_bar.value = tracked_roamer.needs["food"]
	_update_info_panel()

func _on_dewdrops_changed(_amount) -> void:
	_animate_dewdrops(CurrencyManager.dewdrops)

func _animate_dewdrops(target: float) -> void:
	if _tween_dewdrops:
		_tween_dewdrops.kill()
	_tween_dewdrops = create_tween()
	_tween_dewdrops.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween_dewdrops.tween_method(_set_dewdrop_display, _disp_dewdrops, target, 0.55)

func _set_dewdrop_display(val: float) -> void:
	_disp_dewdrops = val
	currency_label.text = "💧 " + str(int(val))

func update_currency() -> void:
	_disp_dewdrops = CurrencyManager.dewdrops
	currency_label.text = "💧 " + str(int(_disp_dewdrops))

# ── Panel animation helpers ───────────────────────────────────────────────────
func _show_panel(panel: Control, slide_from_x: float = 0.0) -> void:
	panel.modulate = Color(1, 1, 1, 0)
	panel.visible  = true
	if slide_from_x != 0.0:
		panel.offset_left  += slide_from_x
		panel.offset_right += slide_from_x
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.22)
	if slide_from_x != 0.0:
		var tgt_left  := panel.offset_left  - slide_from_x
		var tgt_right := panel.offset_right - slide_from_x
		tw.tween_property(panel, "offset_left",  tgt_left,  0.22)
		tw.tween_property(panel, "offset_right", tgt_right, 0.22)

func _hide_panel(panel: Control, slide_to_x: float = 0.0) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.16)
	if slide_to_x != 0.0:
		tw.tween_property(panel, "offset_left",  panel.offset_left  + slide_to_x, 0.16)
		tw.tween_property(panel, "offset_right", panel.offset_right + slide_to_x, 0.16)
	tw.chain().tween_callback(func():
		panel.visible = false
		if slide_to_x != 0.0:
			panel.offset_left  -= slide_to_x
			panel.offset_right -= slide_to_x
	)

func open_shop(trader):
	current_trader = trader
	_show_panel(shop_panel, 20.0)
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
	_hide_panel(shop_panel, 20.0)
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
		
func _on_weather_changed(_new_weather) -> void:
	update_weather_ui()
	var weather_icons := {0: "☀️", 1: "🌧️", 2: "🌫️", 3: "💨"}
	var weather_names := {0: "Sunny", 1: "Raining", 2: "Foggy", 3: "Windy"}
	var w: int = WeatherManager.current_weather
	show_toast(weather_icons.get(w, "🌤"), weather_names.get(w, ""), "", 2.5)

func update_weather_ui():
	var labels = {
		0: "☀️ Sunny",
		1: "🌧️ Rain — roamers seek shelter",
		2: "🌫️ Foggy — roamers uneasy",
		3: "💨 Windy — roamers restless"
	}
	$Panel/VBoxContainer/WeatherLabel.text = labels[WeatherManager.current_weather]

func _on_xp_gained(_amount, _total):
	update_warden_ui()

func _on_level_up(_new_level: int) -> void:
	update_warden_ui()
	show_level_up_message()
	# Refresh shop so newly unlocked items appear immediately
	if shop_panel.visible:
		_rebuild_shop_buttons()

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

func _on_prestige_changed(new_score: int) -> void:
	_update_prestige_label(new_score)

func _update_prestige_label(score: int) -> void:
	var lbl := $Panel/VBoxContainer/PrestigeLabel
	if lbl:
		lbl.text = "⭐ " + PrestigeManager.get_rank() + "  (" + str(score) + ")"

func _on_journal_button():
	var journal = get_tree().get_root().get_node("Garden/FieldJournal")
	journal.toggle_journal()

func _on_quests_button():
	if not _quest_panel:
		return
	if _quest_panel.visible:
		_hide_panel(_quest_panel, -18.0)
	else:
		_show_panel(_quest_panel, -18.0)

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
	var reward := str(obj.get("reward", 0))
	show_toast("✅", "Quest Complete!", obj.get("desc", "") + "  +" + reward + " 💧")
	_refresh_quest_panel()

func _on_season_changed(_season):
	update_season_ui()
	show_toast("🌿", "Season changed", SeasonManager.get_season_string())

func _on_day_passed(_day):
	update_season_ui()

func update_season_ui():
	var label = $Panel/VBoxContainer/SeasonLabel
	if label:
		label.text = SeasonManager.get_season_string()
	else:
		print("ERROR: SeasonLabel not found")
