extends CanvasLayer

@onready var roamer_name = $Panel/VBoxContainer/RoamerName
@onready var stage_label = $Panel/VBoxContainer/StageLabel
@onready var food_bar = $Panel/VBoxContainer/FoodBar
@onready var currency_label = $Panel/VBoxContainer/CurrencyLabel
@onready var placement_label = $Panel/VBoxContainer/PlacementLabel
@onready var attraction_hints = $Panel/VBoxContainer/AttractionHints
@onready var inventory_panel = $InventoryPanel
@onready var item_list = $InventoryPanel/VBoxContainer/ItemList
@onready var _tool_manager: Node = get_tree().get_root().get_node("Garden/ToolManager")
@onready var warden_title = $WardenPanel/VBoxContainer/WardenTitle
@onready var level_label = $WardenPanel/VBoxContainer/LevelLabel
@onready var xp_label = $WardenPanel/VBoxContainer/XPLabel
@onready var xp_bar = $WardenPanel/VBoxContainer/XPBar

var tracked_roamer = null
var current_trader = null
var _attraction_hint_timer: float = 0.0
var _shop_mode: String = "buy"            # "buy" or "sell"
var _shop_greeting_lbl: Label = null
var _shop_tab_bar: HBoxContainer = null

# Shop scroll UI (built procedurally in _build_scroll)
var shop_panel:          Control        = null   # points to _scroll_root for visibility checks
var shop_dewdrops:       Label          = null
var shop_feedback:       Label          = null
var shop_item_container: VBoxContainer  = null
var _scroll_title_lbl:   Label          = null
var _scroll_dim:         ColorRect      = null
var _scroll_root:        Control        = null
var _scroll_container:   VBoxContainer  = null
var _scroll_content_vbox: VBoxContainer = null

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
@warning_ignore("unused_private_class_variable")
var _hover_hide_tween: Tween = null  # reserved for future hide-on-idle animation
const HOVER_RADIUS_PX := 70.0

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

# Action buttons
var _action_btns: Dictionary = {}   # "pet" | "play" | "gift" → Button

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
	$Panel/VBoxContainer/JournalButton.pressed.connect(_on_journal_button)
	$Panel/VBoxContainer/QuestsButton.pressed.connect(_on_quests_button)
	_apply_theme()
	_build_scroll()
	_build_roamer_info_panel()
	MilestoneManager.milestone_achieved.connect(_on_milestone_achieved)
	ObjectiveManager.objective_completed.connect(_on_objective_completed)
	PrestigeManager.score_changed.connect(_on_prestige_changed)
	_update_prestige_label(PrestigeManager.current_score)
	_build_hover_card()

	# ── Bottom bar + portrait popup ───────────────────────────────────────────
	_build_bottom_bar()
	_build_portrait_popup()
	$Panel.visible          = false
	$WardenPanel.visible    = false
	# Redirect @onready display vars to bottom bar equivalents
	currency_label  = _bb_dewdrops_lbl
	warden_title    = _bb_warden_title_lbl
	level_label     = _bb_level_lbl
	xp_label        = _bb_xp_lbl
	xp_bar          = _bb_xp_bar_widget
	placement_label = _bb_placement_lbl
	roamer_name     = _bb_roamer_name_lbl
	stage_label     = _bb_roamer_stage_lbl
	food_bar        = _bb_food_bar_w
	# Re-populate bottom bar with current values
	update_currency()
	update_warden_ui()
	update_season_ui()
	update_weather_ui()
	_update_prestige_label(PrestigeManager.current_score)
	_bb_update_tool_highlights()

# ── Theme ─────────────────────────────────────────────────────────────────────
const C_BG         := Color(0.04, 0.01, 0.09, 0.96)
const C_BG_LIGHT   := Color(0.07, 0.03, 0.14, 0.96)
const C_BORDER     := Color(0.55, 0.20, 0.80, 1.00)
const C_BORDER_DIM := Color(0.30, 0.10, 0.50, 1.00)
const C_TEXT       := Color(0.93, 0.91, 0.96, 1.00)
const C_MUTED      := Color(0.60, 0.50, 0.75, 1.00)
const C_ACCENT     := Color(0.78, 0.38, 0.96, 1.00)
const C_GOLD       := Color(0.95, 0.80, 0.28, 1.00)
const C_DEWDROP    := Color(0.55, 0.82, 1.00, 1.00)
const C_BTN_NORM   := Color(0.10, 0.03, 0.20, 1.00)
const C_BTN_HOVER  := Color(0.20, 0.06, 0.36, 1.00)
const C_BTN_PRESS  := Color(0.06, 0.02, 0.12, 1.00)

# ── Scroll (NPC shop) palette ──────────────────────────────────────────────────
const SC_PARCH     := Color(0.918, 0.882, 0.770, 1.0)
const SC_PARCH_D   := Color(0.862, 0.822, 0.702, 1.0)
const SC_HANDLE    := Color(0.220, 0.132, 0.052, 1.0)   # dark wood
const SC_HANDLE_H  := Color(0.305, 0.192, 0.078, 1.0)   # lighter wood highlight
const SC_LEATHER   := Color(0.162, 0.098, 0.044, 1.0)
const SC_INK       := Color(0.128, 0.092, 0.052, 1.0)
const SC_INK_SOFT  := Color(0.340, 0.272, 0.168, 1.0)
const SC_INK_FAINT := Color(0.520, 0.452, 0.330, 1.0)
const SC_GOLD      := Color(0.722, 0.520, 0.182, 1.0)
const SC_GOLD_L    := Color(0.905, 0.748, 0.362, 1.0)
const SC_MAGIC     := Color(0.548, 0.218, 0.822, 1.0)
const SC_GREEN     := Color(0.148, 0.382, 0.108, 1.0)   # success text on parchment
const SC_WARN      := Color(0.588, 0.285, 0.032, 1.0)   # error/warning on parchment
const SCROLL_W          := 430.0
const SCROLL_BODY_H     := 510.0
const SCROLL_HANDLE_H   := 24.0
const SCROLL_TOTAL_H    := SCROLL_BODY_H + SCROLL_HANDLE_H * 2.0

# Animated dewdrop display
var _disp_dewdrops: float = 0.0
var _tween_dewdrops: Tween = null

# ── Bottom bar ────────────────────────────────────────────────────────────────
const BB_HEIGHT := 120.0
var _bottom_bar: PanelContainer = null
# Left — warden card
var _bb_warden_title_lbl : Label       = null
var _bb_level_lbl        : Label       = null
var _bb_xp_lbl           : Label       = null
var _bb_xp_bar_widget    : ProgressBar = null
var _bb_dewdrops_lbl     : Label       = null
var _bb_prestige_lbl     : Label       = null
# Center — time + tools
var _bb_clock_lbl        : Label       = null
var _bb_season_lbl       : Label       = null
var _bb_weather_lbl      : Label       = null
var _bb_tool_btns        : Dictionary  = {}
var _bb_placement_lbl    : Label       = null
# Right — selected roamer
var _bb_no_roamer_lbl    : Label       = null
var _bb_roamer_content   : Control     = null
var _bb_roamer_name_lbl  : Label       = null
var _bb_roamer_stage_lbl : Label       = null
var _bb_food_bar_w       : ProgressBar = null
var _bb_safety_bar_w     : ProgressBar = null
var _bb_happiness_bar_w  : ProgressBar = null

# Roamer portrait popup (floats above the right section of the bar)
const PORTRAIT_W := 160.0
const PORTRAIT_H := 200.0
var _portrait_popup      : PanelContainer       = null
var _portrait_svp_cont   : SubViewportContainer = null
var _portrait_svp        : SubViewport          = null
var _portrait_model_root : Node3D               = null
var _portrait_rot_timer  : float                = 0.0

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
	bg_style.bg_color = Color(0.08, 0.02, 0.16, 1.0)
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
	style.bg_color      = Color(0.04, 0.01, 0.10, 0.94)
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

func _update_hover_card(_delta: float) -> void:
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
		col = C_ACCENT.lerp(Color(0.60, 0.30, 1.00), (h - 0.7) / 0.3)
	elif h > 0.4:
		col = Color(0.96, 0.72, 0.26)
	else:
		col = Color(0.90, 0.28, 0.36)
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(3)
	return s

# ── Toast notification system ─────────────────────────────────────────────────
func show_toast(icon: String, title: String, subtitle: String = "", duration: float = 3.2) -> void:
	var toast := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.05, 0.01, 0.12, 0.96)
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
	sep_style.bg_color = Color(0.55, 0.20, 0.80, 0.35)
	sep_style.content_margin_top    = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.custom_minimum_size = Vector2(0, 1)
	return sep

# ── Scroll style helpers ──────────────────────────────────────────────────────
func _style_scroll_label(lbl: Label, size: int = 13, color: Color = SC_INK) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

func _make_scroll_btn_style(bg: Color, border: Color = SC_GOLD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 7
	s.content_margin_bottom = 7
	return s

func _style_scroll_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",  _make_scroll_btn_style(SC_HANDLE))
	btn.add_theme_stylebox_override("hover",   _make_scroll_btn_style(SC_HANDLE_H, SC_GOLD_L))
	btn.add_theme_stylebox_override("pressed", _make_scroll_btn_style(SC_LEATHER))
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color",         SC_PARCH)
	btn.add_theme_color_override("font_hover_color",   SC_GOLD_L)
	btn.add_theme_color_override("font_pressed_color", SC_PARCH)
	btn.custom_minimum_size = Vector2(0, 32)

func _make_scroll_sep() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = SC_GOLD
	s.content_margin_top    = 1
	s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	sep.custom_minimum_size = Vector2(0, 1)
	return sep

func _make_scroll_handle() -> PanelContainer:
	var handle := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = SC_HANDLE
	# Gold bands on top/bottom simulate the end fittings of the wooden rod
	s.border_color = SC_GOLD
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_width_left   = 0
	s.border_width_right  = 0
	s.set_corner_radius_all(0)
	s.set_content_margin_all(0)
	s.shadow_color = Color(SC_MAGIC.r, SC_MAGIC.g, SC_MAGIC.b, 0.35)
	s.shadow_size  = 5
	s.shadow_offset = Vector2(0, 0)
	handle.add_theme_stylebox_override("panel", s)
	handle.custom_minimum_size = Vector2(0, SCROLL_HANDLE_H)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Highlight strip (specular simulation — lighter top edge)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	handle.add_child(inner)
	var hi := ColorRect.new()
	hi.color = SC_HANDLE_H
	hi.custom_minimum_size = Vector2(0, 6)
	hi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(hi)
	var mid := ColorRect.new()
	mid.color = SC_HANDLE
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(mid)
	return handle

# ── Scroll (NPC shop) — build, show, hide ────────────────────────────────────
func _build_scroll() -> void:
	# ── Dim overlay ───────────────────────────────────────────────────────────
	_scroll_dim = ColorRect.new()
	_scroll_dim.color = Color(0, 0, 0, 0)
	_scroll_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll_dim.visible = false
	_scroll_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_shop()
	)
	add_child(_scroll_dim)

	# ── Scroll root ───────────────────────────────────────────────────────────
	_scroll_root = Control.new()
	_scroll_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_root.visible = false
	add_child(_scroll_root)

	# ── Scroll container (VBox: top handle + parchment body + bottom handle) ──
	# Manually centered so we control pivot_offset for the unroll animation
	_scroll_container = VBoxContainer.new()
	_scroll_container.add_theme_constant_override("separation", 0)
	_scroll_container.anchor_left   = 0.5
	_scroll_container.anchor_right  = 0.5
	_scroll_container.anchor_top    = 0.5
	_scroll_container.anchor_bottom = 0.5
	_scroll_container.offset_left   = -SCROLL_W / 2.0
	_scroll_container.offset_right  =  SCROLL_W / 2.0
	_scroll_container.offset_top    = -SCROLL_TOTAL_H / 2.0
	_scroll_container.offset_bottom =  SCROLL_TOTAL_H / 2.0
	# Pivot at center so the scroll expands symmetrically (magical unroll)
	_scroll_container.pivot_offset  = Vector2(SCROLL_W / 2.0, SCROLL_TOTAL_H / 2.0)
	_scroll_root.add_child(_scroll_container)

	# ── Top handle ────────────────────────────────────────────────────────────
	_scroll_container.add_child(_make_scroll_handle())

	# ── Parchment body ────────────────────────────────────────────────────────
	var body := PanelContainer.new()
	var body_s := StyleBoxFlat.new()
	body_s.bg_color = SC_PARCH
	body_s.border_color = SC_LEATHER
	body_s.set_border_width_all(2)
	body_s.border_width_top    = 0   # flush with handle
	body_s.border_width_bottom = 0   # flush with handle
	body_s.set_corner_radius_all(0)
	body_s.set_content_margin_all(0)
	body_s.shadow_color = Color(SC_MAGIC.r, SC_MAGIC.g, SC_MAGIC.b, 0.55)
	body_s.shadow_size  = 16
	body_s.shadow_offset = Vector2(0, 2)
	body.add_theme_stylebox_override("panel", body_s)
	body.custom_minimum_size = Vector2(0, SCROLL_BODY_H)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(body)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	body.add_child(outer_vbox)

	# Title band (dark leather header)
	var title_band := PanelContainer.new()
	var band_s := StyleBoxFlat.new()
	band_s.bg_color = SC_LEATHER
	band_s.set_border_width_all(0)
	band_s.border_width_bottom = 2
	band_s.border_color = SC_GOLD
	band_s.set_corner_radius_all(0)
	band_s.content_margin_top    = 10
	band_s.content_margin_bottom = 10
	band_s.content_margin_left   = 16
	band_s.content_margin_right  = 16
	title_band.add_theme_stylebox_override("panel", band_s)
	title_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(title_band)

	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 2)
	title_band.add_child(title_vbox)

	_scroll_title_lbl = Label.new()
	_scroll_title_lbl.name = "ShopTitle"
	_scroll_title_lbl.text = "Sam's Seeds & Wares"
	_scroll_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_title_lbl.add_theme_font_size_override("font_size", 18)
	_scroll_title_lbl.add_theme_color_override("font_color", SC_GOLD_L)
	title_vbox.add_child(_scroll_title_lbl)

	var rune_lbl := Label.new()
	rune_lbl.text = "━━━ ✦ ━━━"
	rune_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rune_lbl.add_theme_font_size_override("font_size", 10)
	rune_lbl.add_theme_color_override("font_color", SC_GOLD)
	title_vbox.add_child(rune_lbl)

	# Scrollable content area
	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(margin)

	_scroll_content_vbox = VBoxContainer.new()
	_scroll_content_vbox.name = "VBoxContainer"
	_scroll_content_vbox.add_theme_constant_override("separation", 5)
	_scroll_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll_content_vbox)

	# Dewdrops label
	shop_dewdrops = Label.new()
	shop_dewdrops.name = "DewdropsLabel"
	shop_dewdrops.text = "💧 Dewdrops: 50"
	_style_scroll_label(shop_dewdrops, 13, SC_INK_SOFT)
	_scroll_content_vbox.add_child(shop_dewdrops)

	# Feedback label
	shop_feedback = Label.new()
	shop_feedback.name = "FeedbackLabel"
	shop_feedback.text = ""
	shop_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_feedback.custom_minimum_size = Vector2(SCROLL_W - 48.0, 0)
	_style_scroll_label(shop_feedback, 12, SC_INK)
	_scroll_content_vbox.add_child(shop_feedback)

	# Item container
	shop_item_container = VBoxContainer.new()
	shop_item_container.name = "ItemContainer"
	shop_item_container.add_theme_constant_override("separation", 6)
	shop_item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content_vbox.add_child(shop_item_container)

	# Close band (fixed footer, outside the scroll area)
	var close_band := PanelContainer.new()
	var close_s := StyleBoxFlat.new()
	close_s.bg_color = SC_PARCH_D
	close_s.set_border_width_all(0)
	close_s.border_width_top = 1
	close_s.border_color = SC_GOLD
	close_s.set_corner_radius_all(0)
	close_s.set_content_margin_all(6)
	close_band.add_theme_stylebox_override("panel", close_s)
	close_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(close_band)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "✕  Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(close_shop)
	_style_scroll_button(close_btn)
	close_band.add_child(close_btn)

	# ── Bottom handle ─────────────────────────────────────────────────────────
	_scroll_container.add_child(_make_scroll_handle())

	# shop_panel points to scroll root so existing visibility checks still work
	shop_panel = _scroll_root

func _show_scroll() -> void:
	# Ignore mouse until animation ends — prevents the opening click from
	# immediately triggering close_shop() via the dim's gui_input callback.
	_scroll_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_dim.visible      = true
	_scroll_root.visible     = true
	_scroll_container.scale    = Vector2(1.0, 0.04)
	_scroll_container.modulate = Color(1, 1, 1, 0.0)
	_scroll_dim.color = Color(0, 0, 0, 0)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_scroll_dim,       "color",      Color(0, 0, 0, 0.50), 0.30)
	tw.tween_property(_scroll_container, "scale",      Vector2(1.0, 1.0),    0.38)
	tw.tween_property(_scroll_container, "modulate:a", 1.0,                  0.25)
	tw.chain().tween_callback(func():
		_scroll_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	)

func _hide_scroll() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(_scroll_dim,       "color",      Color(0, 0, 0, 0),   0.22)
	tw.tween_property(_scroll_container, "scale",      Vector2(1.0, 0.04),  0.26)
	tw.tween_property(_scroll_container, "modulate:a", 0.0,                 0.18)
	tw.chain().tween_callback(func():
		_scroll_root.visible         = false
		_scroll_dim.visible          = false
		_scroll_dim.mouse_filter     = Control.MOUSE_FILTER_IGNORE
		_scroll_container.scale      = Vector2(1.0, 1.0)
		_scroll_container.modulate   = Color(1, 1, 1, 1)
	)

func _inject_hud_separators():
	# Insert visual section breaks into the main HUD VBox after key nodes.
	# Runs once at startup — skips if already inserted.
	var vbox := $Panel/VBoxContainer
	var sep_after := ["FoodBar", "WeatherLabel", "PrestigeLabel", "QuestsButton"]
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
				i += 2
				continue
		i += 1

func _build_bottom_bar() -> void:
	_bottom_bar = PanelContainer.new()
	_bottom_bar.anchor_left   = 0.0
	_bottom_bar.anchor_right  = 1.0
	_bottom_bar.anchor_top    = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_top    = -BB_HEIGHT
	_bottom_bar.offset_bottom = 0.0
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.04, 0.01, 0.10, 0.97)
	bar_style.border_color = C_BORDER
	bar_style.border_width_top    = 2
	bar_style.border_width_left   = 0
	bar_style.border_width_right  = 0
	bar_style.border_width_bottom = 0
	bar_style.content_margin_left   = 14
	bar_style.content_margin_right  = 14
	bar_style.content_margin_top    = 8
	bar_style.content_margin_bottom = 8
	bar_style.shadow_color  = Color(0.40, 0.10, 0.70, 0.45)
	bar_style.shadow_size   = 10
	bar_style.shadow_offset = Vector2(0, -4)
	_bottom_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(_bottom_bar)

	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	_bottom_bar.add_child(root)

	root.add_child(_bb_build_left())
	root.add_child(_bb_vdivider())
	root.add_child(_bb_build_center())
	root.add_child(_bb_vdivider())
	root.add_child(_bb_build_right())

func _bb_vdivider() -> Control:
	var sep := VSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER, 0.35)
	s.content_margin_left  = 1
	s.content_margin_right = 1
	sep.add_theme_stylebox_override("separator", s)
	sep.custom_minimum_size = Vector2(2, 0)
	return sep

func _bb_build_left() -> Control:
	var c := VBoxContainer.new()
	c.custom_minimum_size = Vector2(240, 0)
	c.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 3)

	# Icon + rank title row
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	c.add_child(row1)
	var icon := Label.new()
	icon.text = "🌿"
	icon.add_theme_font_size_override("font_size", 18)
	row1.add_child(icon)
	_bb_warden_title_lbl = Label.new()
	_bb_warden_title_lbl.add_theme_font_size_override("font_size", 13)
	_bb_warden_title_lbl.add_theme_color_override("font_color", C_ACCENT)
	_bb_warden_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_bb_warden_title_lbl)

	# Level + XP text row
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	c.add_child(row2)
	_bb_level_lbl = Label.new()
	_bb_level_lbl.add_theme_font_size_override("font_size", 12)
	_bb_level_lbl.add_theme_color_override("font_color", C_TEXT)
	row2.add_child(_bb_level_lbl)
	_bb_xp_lbl = Label.new()
	_bb_xp_lbl.add_theme_font_size_override("font_size", 11)
	_bb_xp_lbl.add_theme_color_override("font_color", C_MUTED)
	_bb_xp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_bb_xp_lbl)

	# XP bar
	_bb_xp_bar_widget = ProgressBar.new()
	_bb_xp_bar_widget.max_value = 1.0
	_bb_xp_bar_widget.show_percentage = false
	_bb_xp_bar_widget.custom_minimum_size = Vector2(0, 6)
	_style_bar(_bb_xp_bar_widget, Color(0.65, 0.28, 0.96, 1.0))
	c.add_child(_bb_xp_bar_widget)

	# Dewdrops + prestige row
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	c.add_child(row3)
	_bb_dewdrops_lbl = Label.new()
	_bb_dewdrops_lbl.add_theme_font_size_override("font_size", 17)
	_bb_dewdrops_lbl.add_theme_color_override("font_color", C_DEWDROP)
	row3.add_child(_bb_dewdrops_lbl)
	_bb_prestige_lbl = Label.new()
	_bb_prestige_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bb_prestige_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	_bb_prestige_lbl.add_theme_font_size_override("font_size", 10)
	_bb_prestige_lbl.add_theme_color_override("font_color", C_GOLD)
	row3.add_child(_bb_prestige_lbl)

	return c

func _bb_build_center() -> Control:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 5)

	# ── Row 1: Tool hotbar + Journal/Quests ──────────────────────────────────
	var tools_row := HBoxContainer.new()
	tools_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tools_row.add_theme_constant_override("separation", 6)
	c.add_child(tools_row)

	var tool_defs := [
		{"id": "hand",         "label": "✋ Hand",   "key": "H"},
		{"id": "shovel",       "label": "⛏ Shovel",  "key": "S"},
		{"id": "watering_can", "label": "💧 Water",   "key": "W"},
	]
	for t in tool_defs:
		var btn := Button.new()
		btn.text = t["label"] + "  [" + t["key"] + "]"
		btn.custom_minimum_size = Vector2(96, 36)
		_bb_style_tool_btn(btn, false)
		var tid: String = t["id"]
		btn.pressed.connect(func():
			_tool_manager.set_active_tool(tid)
			_bb_update_tool_highlights()
		)
		tools_row.add_child(btn)
		_bb_tool_btns[t["id"]] = btn

	# spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_row.add_child(spacer)

	var journal_btn := Button.new()
	journal_btn.text = "📖 Journal"
	journal_btn.custom_minimum_size = Vector2(100, 36)
	_style_button(journal_btn, true)
	journal_btn.pressed.connect(_on_journal_button)
	tools_row.add_child(journal_btn)

	var quests_btn := Button.new()
	quests_btn.text = "📋 Quests"
	quests_btn.custom_minimum_size = Vector2(100, 36)
	_style_button(quests_btn, true)
	quests_btn.pressed.connect(_on_quests_button)
	tools_row.add_child(quests_btn)

	# Inventory toggle
	var inv_btn := Button.new()
	inv_btn.text = "🎒 Bag"
	inv_btn.custom_minimum_size = Vector2(80, 36)
	_style_button(inv_btn, false)
	inv_btn.pressed.connect(func():
		inventory_panel.visible = not inventory_panel.visible
	)
	tools_row.add_child(inv_btn)

	# ── Row 2: Time controls + clock + season + weather ──────────────────────
	var time_row := HBoxContainer.new()
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	time_row.add_theme_constant_override("separation", 8)
	c.add_child(time_row)

	for cfg in [["⏸", true, false], ["▶", false, false], ["⏩", false, true]]:
		var btn := Button.new()
		btn.text = cfg[0]
		btn.custom_minimum_size = Vector2(32, 26)
		_style_button(btn, false)
		btn.add_theme_font_size_override("font_size", 13)
		var do_pause: bool = cfg[1]
		var do_fast:  bool = cfg[2]
		btn.pressed.connect(func():
			DayNightManager.is_paused = do_pause
			if not do_pause:
				DayNightManager.day_length_seconds = 60.0 if do_fast else 240.0
		)
		time_row.add_child(btn)

	var dot1 := Label.new(); dot1.text = "·"
	dot1.add_theme_color_override("font_color", C_MUTED)
	time_row.add_child(dot1)

	_bb_clock_lbl = Label.new()
	_bb_clock_lbl.add_theme_font_size_override("font_size", 13)
	_bb_clock_lbl.add_theme_color_override("font_color", C_TEXT)
	time_row.add_child(_bb_clock_lbl)

	var dot2 := Label.new(); dot2.text = "·"
	dot2.add_theme_color_override("font_color", C_MUTED)
	time_row.add_child(dot2)

	_bb_season_lbl = Label.new()
	_bb_season_lbl.add_theme_font_size_override("font_size", 12)
	_bb_season_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.50, 1.0))
	time_row.add_child(_bb_season_lbl)

	var dot3 := Label.new(); dot3.text = "·"
	dot3.add_theme_color_override("font_color", C_MUTED)
	time_row.add_child(dot3)

	_bb_weather_lbl = Label.new()
	_bb_weather_lbl.add_theme_font_size_override("font_size", 12)
	_bb_weather_lbl.add_theme_color_override("font_color", C_TEXT)
	time_row.add_child(_bb_weather_lbl)

	# ── Row 3: Placement / feedback label ────────────────────────────────────
	_bb_placement_lbl = Label.new()
	_bb_placement_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bb_placement_lbl.add_theme_font_size_override("font_size", 11)
	_bb_placement_lbl.add_theme_color_override("font_color", C_ACCENT)
	c.add_child(_bb_placement_lbl)

	return c

func _bb_build_right() -> Control:
	var c := VBoxContainer.new()
	c.custom_minimum_size = Vector2(260, 0)
	c.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 4)

	# "No roamer selected" placeholder
	_bb_no_roamer_lbl = Label.new()
	_bb_no_roamer_lbl.text = "No Roamer Selected"
	_bb_no_roamer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bb_no_roamer_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_bb_no_roamer_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	_bb_no_roamer_lbl.add_theme_font_size_override("font_size", 12)
	_bb_no_roamer_lbl.add_theme_color_override("font_color", C_MUTED)
	c.add_child(_bb_no_roamer_lbl)

	# Roamer content — hidden until selected
	_bb_roamer_content = VBoxContainer.new()
	_bb_roamer_content.add_theme_constant_override("separation", 3)
	_bb_roamer_content.visible = false
	c.add_child(_bb_roamer_content)

	# Name + stage row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	_bb_roamer_content.add_child(name_row)
	_bb_roamer_name_lbl = Label.new()
	_bb_roamer_name_lbl.add_theme_font_size_override("font_size", 14)
	_bb_roamer_name_lbl.add_theme_color_override("font_color", C_ACCENT)
	_bb_roamer_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_bb_roamer_name_lbl)
	_bb_roamer_stage_lbl = Label.new()
	_bb_roamer_stage_lbl.add_theme_font_size_override("font_size", 11)
	_bb_roamer_stage_lbl.add_theme_color_override("font_color", C_MUTED)
	name_row.add_child(_bb_roamer_stage_lbl)

	# 3 needs bars
	for cfg: Array in [
		["♥ Happiness", Color(0.65, 0.28, 0.96, 1.0), "hap"],
		["🍃 Food",      Color(0.90, 0.65, 0.20, 1.0), "food"],
		["🛡 Safety",    Color(0.28, 0.75, 0.52, 1.0), "saf"],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_bb_roamer_content.add_child(row)
		var lbl := Label.new()
		lbl.text = cfg[0]
		lbl.custom_minimum_size = Vector2(88, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", C_MUTED)
		row.add_child(lbl)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		_style_bar(bar, cfg[1])
		row.add_child(bar)
		match cfg[2]:
			"hap":  _bb_happiness_bar_w = bar
			"food": _bb_food_bar_w      = bar
			"saf":  _bb_safety_bar_w    = bar

	# Action buttons row
	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 6)
	_bb_roamer_content.add_child(act_row)
	for cfg2: Array in [
		["🤲 Pet",  "pet"],
		["🎾 Play", "play"],
		["🍓 Gift", "gift"],
	]:
		var btn := Button.new()
		btn.text = cfg2[0]
		btn.custom_minimum_size = Vector2(70, 28)
		_style_button(btn, false)
		btn.add_theme_font_size_override("font_size", 11)
		var act: String = cfg2[1]
		btn.pressed.connect(func(): _on_action_pressed(act))
		act_row.add_child(btn)
		_action_btns[cfg2[1]] = btn   # overwrite so _update_action_buttons() uses these

	return c

func _build_portrait_popup() -> void:
	# ── Floating panel that sits above the bar's right section ────────────────
	_portrait_popup = PanelContainer.new()
	_portrait_popup.anchor_left   = 1.0
	_portrait_popup.anchor_right  = 1.0
	_portrait_popup.anchor_top    = 1.0
	_portrait_popup.anchor_bottom = 1.0
	_portrait_popup.offset_left   = -(PORTRAIT_W + 20.0)
	_portrait_popup.offset_right  = -20.0
	_portrait_popup.offset_top    = -(BB_HEIGHT + PORTRAIT_H + 10.0)
	_portrait_popup.offset_bottom = -(BB_HEIGHT + 10.0)
	_portrait_popup.pivot_offset  = Vector2(PORTRAIT_W * 0.5, PORTRAIT_H)  # scale from bottom
	_portrait_popup.scale         = Vector2(1.0, 0.0)   # start collapsed
	_portrait_popup.visible       = false
	_portrait_popup.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var pop_style := StyleBoxFlat.new()
	pop_style.bg_color = Color(0.04, 0.01, 0.10, 0.96)
	pop_style.border_color = C_BORDER
	pop_style.set_border_width_all(2)
	pop_style.set_corner_radius_all(12)
	pop_style.set_content_margin_all(0)   # viewport fills the whole panel
	pop_style.shadow_color  = Color(0.40, 0.10, 0.70, 0.55)
	pop_style.shadow_size   = 12
	pop_style.shadow_offset = Vector2(0, -4)
	_portrait_popup.add_theme_stylebox_override("panel", pop_style)
	add_child(_portrait_popup)

	# ── SubViewportContainer fills the panel ──────────────────────────────────
	_portrait_svp_cont = SubViewportContainer.new()
	_portrait_svp_cont.stretch = true
	_portrait_svp_cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_popup.add_child(_portrait_svp_cont)

	# ── SubViewport — 3D scene ────────────────────────────────────────────────
	_portrait_svp = SubViewport.new()
	_portrait_svp.size = Vector2i(int(PORTRAIT_W), int(PORTRAIT_H))
	_portrait_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_portrait_svp.transparent_bg = false
	_portrait_svp.own_world_3d = true   # isolate from main scene — prevents lights/env leaking
	_portrait_svp_cont.add_child(_portrait_svp)

	# Background environment — dark purple to match game palette
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode   = Environment.BG_COLOR
	env.background_color  = Color(0.04, 0.01, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.50, 0.20, 0.80)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	_portrait_svp.add_child(env_node)

	# Main directional light (warm front-left key light)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	key.light_color  = Color(1.00, 0.92, 0.80)
	key.light_energy = 1.4
	_portrait_svp.add_child(key)

	# Magic upward OmniLight — purple glow from below
	var glow := OmniLight3D.new()
	glow.position     = Vector3(0.0, -0.4, 0.6)
	glow.light_color  = Color(0.55, 0.15, 1.00)
	glow.light_energy = 2.5
	glow.omni_range   = 5.0
	_portrait_svp.add_child(glow)

	# Camera
	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.look_at_from_position(Vector3(0.0, 1.0, 2.5), Vector3(0.0, 0.7, 0.0))
	_portrait_svp.add_child(cam)

	# Model root — this node rotates each frame
	_portrait_model_root = Node3D.new()
	_portrait_svp.add_child(_portrait_model_root)

func _portrait_load(roamer) -> void:
	if not _portrait_model_root:
		return
	for c in _portrait_model_root.get_children():
		c.queue_free()
	var path: String = roamer.get("creature_scene_path") if roamer else ""
	if path == "":
		return
	var packed := load(path) as PackedScene
	if packed:
		var inst := packed.instantiate()
		_portrait_model_root.add_child(inst)

func _portrait_clear() -> void:
	if _portrait_model_root:
		for c in _portrait_model_root.get_children():
			c.queue_free()

func _portrait_show(show: bool) -> void:
	if show:
		_portrait_popup.visible = true
		_portrait_popup.scale   = Vector2(1.0, 0.0)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_portrait_popup, "scale", Vector2(1.0, 1.0), 0.32)
	else:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.tween_property(_portrait_popup, "scale", Vector2(1.0, 0.0), 0.20)
		tw.tween_callback(func(): _portrait_popup.visible = false)

func _bb_style_tool_btn(btn: Button, active: bool) -> void:
	var bg    := C_BTN_HOVER if active else C_BTN_NORM
	var bord  := C_BORDER    if active else C_BORDER_DIM
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = bord
	s.set_border_width_all(1 if not active else 2)
	s.set_corner_radius_all(6); s.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal",  s)
	var hs := StyleBoxFlat.new()
	hs.bg_color = C_BTN_HOVER; hs.border_color = C_BORDER
	hs.set_border_width_all(1); hs.set_corner_radius_all(6); hs.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover",   hs)
	btn.add_theme_stylebox_override("pressed", s)
	var col := C_ACCENT if active else C_TEXT
	btn.add_theme_color_override("font_color",        col)
	btn.add_theme_color_override("font_hover_color",  C_ACCENT)
	btn.add_theme_font_size_override("font_size", 12)

func _bb_update_tool_highlights() -> void:
	if not _tool_manager:
		return
	for tid in _bb_tool_btns:
		_bb_style_tool_btn(_bb_tool_btns[tid], _tool_manager.active_tool == tid)

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
	for vbox in [$InventoryPanel/VBoxContainer,
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
	_style_label($Panel/VBoxContainer/AttractionTitle, 11, Color(0.85, 0.65, 0.96, 1.0))
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

	# ── Inventory panel ────────────────────────────────────────────────────────
	_style_label($InventoryPanel/VBoxContainer/InventoryTitle, 14, C_ACCENT)

	# ── Warden panel ───────────────────────────────────────────────────────────
	_style_label(warden_title, 14, C_ACCENT)
	_style_label(level_label,  13, C_TEXT)
	_style_label(xp_label,     11, C_MUTED)
	_style_bar(xp_bar, Color(0.65, 0.28, 0.96, 1.0))

	

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
	_info_panel.offset_top    = -230.0
	_info_panel.offset_bottom =  230.0
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
	_info_traits_lbl.add_theme_color_override("font_color", Color(0.82, 0.65, 0.96, 1.0))
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

	_style_bar(_info_happiness_bar, Color(0.55, 0.28, 0.96))
	_style_bar(_info_food_bar,      Color(0.90, 0.65, 0.20))
	_style_bar(_info_safety_bar,    Color(0.38, 0.58, 0.96))
	_style_bar(_info_space_bar,     Color(0.78, 0.38, 0.96))

	vbox.add_child(HSeparator.new())

	_info_den_lbl = Label.new()
	_info_den_lbl.add_theme_font_size_override("font_size", 11)
	_info_den_lbl.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_info_den_lbl)

	# ── Action buttons ─────────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())

	var action_configs := [
		["pet",  "🤲 Pet",  "Comfort — boosts happiness & safety"],
		["play", "🎾 Play", "Enrichment — boosts space & happiness"],
		["gift", "🍓 Gift", "Feed a treat from inventory"],
	]
	for cfg in action_configs:
		var key: String   = cfg[0]
		var label: String = cfg[1]
		var tip: String   = cfg[2]
		var btn := Button.new()
		btn.text = label
		btn.tooltip_text = tip
		btn.custom_minimum_size = Vector2(0, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(btn, true)
		btn.pressed.connect(_on_action_pressed.bind(key))
		vbox.add_child(btn)
		_action_btns[key] = btn

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
		h_col = Color(0.55, 0.28, 0.96)
	elif h > 0.3:
		h_col = Color(0.96, 0.72, 0.26)
	else:
		h_col = Color(0.90, 0.28, 0.36)
	_style_bar(_info_happiness_bar, h_col)

	# Den status
	if tracked_roamer.has_shelter and is_instance_valid(tracked_roamer.shelter_node):
		var den = tracked_roamer.shelter_node
		_info_den_lbl.text = "🏠 " + den.get_display_name()
	else:
		_info_den_lbl.text = "🏠 No den yet"

# ── Action buttons ────────────────────────────────────────────────────────────

const _ACTION_LABELS := {
	"pet":  ["🤲 Pet",  "🤲 Pet (%ds)"],
	"play": ["🎾 Play", "🎾 Play (%ds)"],
	"gift": ["🍓 Gift", "🍓 Gift (%ds)"],
}

func _on_action_pressed(action: String) -> void:
	if not tracked_roamer or not is_instance_valid(tracked_roamer):
		return
	var display_name: String = tracked_roamer.roamer_name \
		if tracked_roamer.roamer_name != "" else tracked_roamer.name
	match action:
		"pet":
			if tracked_roamer.interact_pet():
				show_toast("🤲", "Petted " + display_name + "!",
					"+Happiness  +Safety", 2.5)
				AudioManager.play_select()
			else:
				_flash_cooldown_btn(_action_btns.get("pet"))
		"play":
			if tracked_roamer.interact_play():
				show_toast("🎾", "Played with " + display_name + "!",
					"+Space  +Happiness", 2.5)
				AudioManager.play_select()
			else:
				_flash_cooldown_btn(_action_btns.get("play"))
		"gift":
			if tracked_roamer.interact_gift():
				show_toast("🍓", display_name + " loves the treat!",
					"+Food  +Happiness", 2.5)
				AudioManager.play_buy()
			else:
				if not tracked_roamer.can_interact("gift"):
					_flash_cooldown_btn(_action_btns.get("gift"))
				else:
					show_toast("🎒", "No treats in your bag!",
						"Buy Roamer Treats from Maren.", 2.8)
					AudioManager.play_error()

func _flash_cooldown_btn(btn: Button) -> void:
	if not btn:
		return
	var orig_col := btn.get_theme_color("font_color")
	btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	await get_tree().create_timer(0.35).timeout
	btn.add_theme_color_override("font_color", orig_col)

func _update_action_buttons() -> void:
	if not tracked_roamer or not is_instance_valid(tracked_roamer):
		return
	for key in _action_btns:
		var btn: Button = _action_btns[key]
		var cd: float = tracked_roamer.get_cooldown_remaining(key)
		var labels: Array = _ACTION_LABELS[key]
		if cd > 0.0:
			btn.text = labels[1] % int(ceil(cd))
			btn.disabled = true
		else:
			btn.text = labels[0]
			btn.disabled = false

# ── Milestone popup ───────────────────────────────────────────────────────────
func _on_milestone_achieved(title: String, subtitle: String):
	# Use a toast for quick feedback — the icon is extracted from the title if present
	show_toast("🏆", title, subtitle, 4.0)

func _process(delta: float) -> void:
	if tracked_roamer:
		update_ui()
		_update_action_buttons()
	if _bb_clock_lbl:
		_bb_clock_lbl.text = "🕐 " + DayNightManager.get_time_string()
	_bb_update_tool_highlights()
	_bb_update_roamer_needs()
	# Gentle portrait sway
	if _portrait_model_root and _portrait_popup and _portrait_popup.visible:
		_portrait_rot_timer += delta
		_portrait_model_root.rotation.y = sin(_portrait_rot_timer * 0.55) * 0.40

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
		pass  # attraction title moved to bottom bar placement label area
	if garden.has_method("get_attraction_hints"):
		var hints: Array = garden.get_attraction_hints()
		attraction_hints.text = "\n".join(hints)

func show_roamer(roamer):
	tracked_roamer = roamer
	roamer_name.text = roamer.roamer_name if roamer.roamer_name != "" else roamer.name
	if _bb_no_roamer_lbl:    _bb_no_roamer_lbl.visible  = false
	if _bb_roamer_content:   _bb_roamer_content.visible = true
	_portrait_load(roamer)
	_portrait_show(true)
	_update_info_panel()

func hide_roamer():
	tracked_roamer = null
	if _bb_no_roamer_lbl:    _bb_no_roamer_lbl.visible  = true
	if _bb_roamer_content:   _bb_roamer_content.visible = false
	_portrait_show(false)
	_portrait_clear()

func update_ui():
	var stage_names = ["Appears", "Visits", "Resident", "Bonded"]
	stage_label.text = stage_names[tracked_roamer.attraction_stage]
	food_bar.value = tracked_roamer.needs["food"]
	_update_info_panel()

func _bb_update_roamer_needs() -> void:
	if not _bb_roamer_content or not _bb_roamer_content.visible:
		return
	if not tracked_roamer or not is_instance_valid(tracked_roamer):
		return
	if _bb_happiness_bar_w:
		_bb_happiness_bar_w.value = tracked_roamer.happiness
	if _bb_safety_bar_w:
		_bb_safety_bar_w.value = tracked_roamer.needs.get("safety", 0.0)

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
	_shop_mode = "buy"
	_show_scroll()
	shop_feedback.text = ""
	shop_feedback.add_theme_color_override("font_color", SC_INK)
	_ensure_shop_extras()
	# Show / hide Sell tab depending on whether this trader supports selling
	if _shop_tab_bar:
		var sell_tab: Button = _shop_tab_bar.get_node_or_null("SellTab")
		if sell_tab:
			sell_tab.visible = current_trader.has_method("sell_item")
		# Hide entire tab bar for upgrade-only traders (Gus)
		_shop_tab_bar.visible = not current_trader.has_method("upgrade_item")
	# Update shop title
	if _scroll_title_lbl:
		if current_trader.has_method("upgrade_item"):
			_scroll_title_lbl.text = "Gus's Groundwork"
		elif current_trader.has_method("commission_item"):
			_scroll_title_lbl.text = "Torvald's Commissions"
		elif current_trader.is_in_group("doc_birtle"):
			_scroll_title_lbl.text = "Doc Birtle's Remedies"
		else:
			_scroll_title_lbl.text = "Sam's Seeds & Wares"
	_update_shop_dewdrops()
	_rebuild_shop_content()
	# Time-of-day greeting
	if current_trader.has_method("get_greeting"):
		_show_shop_feedback(current_trader.get_greeting(), SC_INK_SOFT)

## Lazily inject the greeting label and Buy/Sell tab bar into the scroll content vbox.
func _ensure_shop_extras() -> void:
	var vbox := _scroll_content_vbox

	# Greeting label — inserted after DewdropsLabel (index 2)
	if not _shop_greeting_lbl:
		_shop_greeting_lbl = Label.new()
		_shop_greeting_lbl.name = "GreetingLabel"
		_shop_greeting_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_shop_greeting_lbl.custom_minimum_size = Vector2(SCROLL_W - 48.0, 0)
		_style_scroll_label(_shop_greeting_lbl, 11, SC_INK_SOFT)
		vbox.add_child(_shop_greeting_lbl)
		vbox.move_child(_shop_greeting_lbl, 2)

	# Buy / Sell tab bar — inserted after greeting (index 3)
	if not _shop_tab_bar:
		_shop_tab_bar = HBoxContainer.new()
		_shop_tab_bar.name = "TabBar"
		_shop_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		_shop_tab_bar.custom_minimum_size = Vector2(0, 34)

		var buy_btn := Button.new()
		buy_btn.name = "BuyTab"
		buy_btn.text = "🛒  Buy"
		buy_btn.custom_minimum_size = Vector2(130, 30)
		buy_btn.pressed.connect(_on_shop_tab.bind("buy"))
		_style_scroll_button(buy_btn)

		var sell_btn := Button.new()
		sell_btn.name = "SellTab"
		sell_btn.text = "💰  Sell"
		sell_btn.custom_minimum_size = Vector2(130, 30)
		sell_btn.pressed.connect(_on_shop_tab.bind("sell"))
		_style_scroll_button(sell_btn)

		_shop_tab_bar.add_child(buy_btn)
		_shop_tab_bar.add_child(sell_btn)
		vbox.add_child(_shop_tab_bar)
		vbox.move_child(_shop_tab_bar, 3)

func _on_shop_tab(mode: String) -> void:
	_shop_mode = mode
	shop_feedback.text = ""
	_rebuild_shop_content()

func _rebuild_shop_content() -> void:
	if _shop_mode == "sell":
		_rebuild_sell_items()
	else:
		_rebuild_buy_items()

func _rebuild_buy_items():
	for child in shop_item_container.get_children():
		child.queue_free()
	if not current_trader:
		return

	# Gus uses upgrade_items; Torvald uses commission_items; Sam uses shop_items
	var is_upgrade: bool   = current_trader.has_method("upgrade_item")
	var is_commission: bool = current_trader.has_method("commission_item")
	var all_items: Array
	if is_upgrade:
		all_items = current_trader.upgrade_items
	elif is_commission:
		all_items = current_trader.commission_items
	else:
		all_items = current_trader.shop_items

	# Unlocked items — fully interactive
	for i in range(all_items.size()):
		var item: Dictionary = all_items[i]
		if WardenManager.current_level < item.get("min_level", 1):
			continue
		var vbox := VBoxContainer.new()
		var btn := Button.new()
		if is_upgrade and current_trader.is_purchased(i):
			btn.text = "✓  " + item["name"] + "  —  Purchased"
			btn.disabled = true
			btn.modulate = Color(0.45, 0.78, 0.42, 0.90)
		else:
			btn.text = item["name"] + "  —  " + str(int(item["cost"])) + " 💧"
		btn.custom_minimum_size = Vector2(SCROLL_W - 56.0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_buy_item.bind(i))
		_style_scroll_button(btn)
		var desc := Label.new()
		desc.text = item["description"]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(SCROLL_W - 56.0, 0)
		_style_scroll_label(desc, 11, SC_INK_FAINT)
		vbox.add_child(btn)
		vbox.add_child(desc)
		shop_item_container.add_child(vbox)
	# Locked items — shown greyed with level requirement
	for item: Dictionary in all_items:
		var min_lvl: int = item.get("min_level", 1)
		if WardenManager.current_level >= min_lvl:
			continue
		var vbox := VBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "🔒 " + item["name"] + "  —  Lv." + str(min_lvl)
		lbl.custom_minimum_size = Vector2(SCROLL_W - 56.0, 36)
		_style_scroll_label(lbl, 12, SC_INK_FAINT)
		lbl.modulate = Color(1, 1, 1, 0.55)
		vbox.add_child(lbl)
		shop_item_container.add_child(vbox)

func _rebuild_sell_items() -> void:
	for child in shop_item_container.get_children():
		child.queue_free()
	if not current_trader:
		return

	var inv: Dictionary = InventoryManager.get_all_items()
	var has_sellable := false

	for item_name in inv:
		var count: int = inv[item_name]
		var price: float = current_trader.get_sell_price(item_name) if current_trader.has_method("get_sell_price") else 0.0
		if price <= 0.0:
			continue
		has_sellable = true
		var hbox := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = item_name + " x" + str(count)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_scroll_label(lbl, 12, SC_INK)
		var btn := Button.new()
		btn.text = "Sell  +" + str(int(price)) + " 💧"
		btn.custom_minimum_size = Vector2(120, 30)
		btn.pressed.connect(_on_sell_item.bind(item_name))
		_style_scroll_button(btn)
		hbox.add_child(lbl)
		hbox.add_child(btn)
		shop_item_container.add_child(hbox)

	if not has_sellable:
		var lbl := Label.new()
		lbl.text = "Nothing to sell right now."
		_style_scroll_label(lbl, 12, SC_INK_FAINT)
		shop_item_container.add_child(lbl)

func _update_shop_dewdrops():
	shop_dewdrops.text = "💧 " + str(int(CurrencyManager.dewdrops)) + " Dewdrops"

func close_shop():
	if current_trader and current_trader.has_method("hide_selection_ring"):
		current_trader.hide_selection_ring()
	_hide_scroll()
	current_trader = null

func _on_buy_item(index: int):
	if not current_trader:
		return
	# Determine the correct item list and purchase method
	var is_upgrade: bool    = current_trader.has_method("upgrade_item")
	var is_commission: bool = current_trader.has_method("commission_item")
	var all_items: Array
	if is_upgrade:
		all_items = current_trader.upgrade_items
	elif is_commission:
		all_items = current_trader.commission_items
	else:
		all_items = current_trader.shop_items
	if index < 0 or index >= all_items.size():
		return
	var item: Dictionary = all_items[index]

	if is_upgrade:
		# Gus: permanent upgrade path
		if current_trader.is_purchased(index):
			_show_shop_feedback(current_trader.get_already_purchased_line(), SC_INK_SOFT)
			return
		if CurrencyManager.dewdrops < item["cost"]:
			_show_shop_feedback(current_trader.get_broke_line(), SC_WARN)
			AudioManager.play_error()
			return
		if current_trader.upgrade_item(index):
			_update_shop_dewdrops()
			_rebuild_buy_items()  # refresh ✓ badges
			_show_shop_feedback(current_trader.get_purchase_line(), SC_GREEN)
			AudioManager.play_buy()
		return

	if CurrencyManager.dewdrops >= item["cost"]:
		var success: bool
		if is_commission:
			success = await current_trader.commission_item(index)
		else:
			current_trader.buy_item(index)
			success = true
		if success:
			_update_shop_dewdrops()
			var line: String = current_trader.get_commission_line() if current_trader.has_method("get_commission_line") \
				else (current_trader.get_purchase_line() if current_trader.has_method("get_purchase_line") else "Purchased!")
			_show_shop_feedback(line, SC_GREEN)
			AudioManager.play_buy()
		else:
			_show_shop_feedback("Missing materials for that one.", SC_WARN)
			AudioManager.play_error()
	else:
		var line: String = current_trader.get_broke_line() if current_trader.has_method("get_broke_line") else "Not enough Dewdrops!"
		_show_shop_feedback(line, SC_WARN)
		AudioManager.play_error()

func _on_sell_item(item_name: String) -> void:
	if not current_trader:
		return
	if current_trader.sell_item(item_name):
		_update_shop_dewdrops()
		var line: String = current_trader.get_sell_line() if current_trader.has_method("get_sell_line") else "Sold!"
		_show_shop_feedback(line, SC_GOLD)
		AudioManager.play_buy()
		_rebuild_sell_items()  # refresh so count updates

func _show_shop_feedback(msg: String, colour: Color):
	shop_feedback.text = msg
	shop_feedback.add_theme_color_override("font_color", colour)
	await get_tree().create_timer(2.5).timeout
	if shop_feedback:
		shop_feedback.text = ""
		shop_feedback.add_theme_color_override("font_color", SC_INK)

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
	# ── Doc Birtle consumables ──────────────────────────────────────────────────
	if item_name == "Calm Draught":
		_use_calm_draught()
		return
	if item_name == "Nourishing Paste":
		_use_nourishing_paste()
		return
	if item_name == "Tonic of Vigour":
		_use_tonic_of_vigour()
		return
	if item_name == "Burden Cure":
		_use_burden_cure()
		return
	# Set as active placement item
	_tool_manager.set_placement_item(item_name)
	placement_label.text = "📦 Placing: " + item_name + "  (right-click to place)"

func _use_calm_draught() -> void:
	if not tracked_roamer or not is_instance_valid(tracked_roamer):
		placement_label.text = "⚠ Select a roamer first!"
		placement_label.modulate = Color(1, 0.6, 0.2)
		return
	if tracked_roamer.state != tracked_roamer.State.AGITATED:
		placement_label.text = "ℹ " + tracked_roamer.roamer_name + " isn't agitated."
		placement_label.modulate = Color(0.8, 0.8, 0.8)
		return
	if InventoryManager.remove_item("Calm Draught"):
		tracked_roamer.calm_agitation()
		placement_label.text = "💧 " + tracked_roamer.roamer_name + " feels calm."
		placement_label.modulate = Color(0.5, 0.9, 0.7)

func _use_nourishing_paste() -> void:
	if not tracked_roamer or not is_instance_valid(tracked_roamer):
		placement_label.text = "⚠ Select a roamer first!"
		placement_label.modulate = Color(1, 0.6, 0.2)
		return
	if InventoryManager.remove_item("Nourishing Paste"):
		tracked_roamer.needs["food"] = 1.0
		placement_label.text = "🍃 " + tracked_roamer.roamer_name + "'s food restored!"
		placement_label.modulate = Color(0.5, 0.9, 0.5)

func _use_tonic_of_vigour() -> void:
	if not tracked_roamer or not is_instance_valid(tracked_roamer):
		placement_label.text = "⚠ Select a roamer first!"
		placement_label.modulate = Color(1, 0.6, 0.2)
		return
	if InventoryManager.remove_item("Tonic of Vigour"):
		for need in tracked_roamer.needs:
			tracked_roamer.needs[need] = max(tracked_roamer.needs[need], 0.80)
		tracked_roamer.happiness = min(1.0, tracked_roamer.happiness + 0.20)
		placement_label.text = "✨ " + tracked_roamer.roamer_name + " feels revitalised!"
		placement_label.modulate = Color(0.7, 0.55, 1.0)

func _use_burden_cure() -> void:
	if not tracked_roamer or not is_instance_valid(tracked_roamer):
		placement_label.text = "⚠ Select a roamer first!"
		placement_label.modulate = Color(1, 0.6, 0.2)
		return
	if tracked_roamer.burden_state == tracked_roamer.BurdenState.HEALTHY:
		placement_label.text = "ℹ " + tracked_roamer.roamer_name + " isn't burdened."
		placement_label.modulate = Color(0.8, 0.8, 0.8)
		return
	if InventoryManager.remove_item("Burden Cure"):
		tracked_roamer.recover_from_burden()
		placement_label.text = "💚 " + tracked_roamer.roamer_name + " is recovering!"
		placement_label.modulate = Color(0.4, 0.95, 0.55)

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
		1: "🌧️ Raining",
		2: "🌫️ Foggy",
		3: "💨 Windy"
	}
	if _bb_weather_lbl:
		_bb_weather_lbl.text = labels[WeatherManager.current_weather]

func _on_xp_gained(_amount, _total):
	update_warden_ui()

func _on_level_up(_new_level: int) -> void:
	update_warden_ui()
	show_level_up_message()
	# Refresh shop so newly unlocked items appear immediately
	if _scroll_root != null and _scroll_root.visible:
		_rebuild_shop_content()

func update_warden_ui():
	warden_title.text = WardenManager.get_title()
	level_label.text = "Level " + str(WardenManager.current_level)
	xp_label.text = str(int(WardenManager.current_xp)) + " / " + str(int(WardenManager.xp_to_next_level)) + " XP"
	xp_bar.value = WardenManager.get_level_progress()

func show_level_up_message():
	# Build a centred popup panel
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.02, 0.14, 0.97)
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
		unlock_lbl.add_theme_color_override("font_color", Color(0.88, 0.72, 1.00, 1.0))
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
	if _bb_prestige_lbl:
		_bb_prestige_lbl.text = "⭐ " + PrestigeManager.get_rank() + "  (" + str(score) + ")"

func _on_journal_button():
	var journal = get_tree().get_root().get_node("Garden/FieldJournal")
	journal.toggle_journal()

func _on_quests_button():
	var journal = get_tree().get_root().get_node("Garden/FieldJournal")
	journal.open_on_tab("quests")

func _on_objective_completed(obj: Dictionary):
	var reward := str(obj.get("reward", 0))
	show_toast("✅", "Quest Complete!", obj.get("desc", "") + "  +" + reward + " 💧")

func _on_season_changed(_season):
	update_season_ui()
	show_toast("🌿", "Season changed", SeasonManager.get_season_string())

func _on_day_passed(_day):
	update_season_ui()

func update_season_ui():
	if _bb_season_lbl:
		_bb_season_lbl.text = SeasonManager.get_season_string()
