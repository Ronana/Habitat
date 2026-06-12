## TutorialManager — shows a guided tooltip sequence on the player's first session.
## Add as an autoload. Reads/writes a "tutorial_done" flag via SaveManager / ConfigFile.
extends CanvasLayer

const SAVE_PATH := "user://tutorial.cfg"

signal tutorial_finished

var _active    := false
var _step      := 0
var _overlay   : ColorRect = null
var _card      : PanelContainer = null
var _title_lbl : Label = null
var _body_lbl  : Label = null
var _btn       : Button = null
var _skip_btn  : Button = null
var _highlight : Panel = null  # transparent punch-out highlight box

# ── Step data ─────────────────────────────────────────────────────────────────
# Each step: { title, body, anchor } where anchor is a node path hint or ""
const STEPS: Array = [
	{
		"icon":  "🌿",
		"title": "Welcome to Habitat",
		"body":  "You are an Apprentice Warden — a keeper of wild creatures called Roamers.\n\nBuild a garden they'll love, earn their trust, and help them thrive.",
		"anchor": ""
	},
	{
		"icon":  "🦊",
		"title": "Roamers will find you",
		"body":  "Wild Roamers appear at the edges of your garden on their own. Click one to learn about it.\n\nThe Field Journal (J) keeps notes on every creature you've met.",
		"anchor": ""
	},
	{
		"icon":  "🍃",
		"title": "Plant food first",
		"body":  "Open Maren's shop and buy Berry Seeds. Place them anywhere in the garden.\n\nHungry Roamers will seek out food on their own.",
		"anchor": ""
	},
	{
		"icon":  "🏠",
		"title": "Give them shelter",
		"body":  "A Basic Shelter lets a Roamer become a Resident — the first step toward bonding.\n\nPlace it somewhere sheltered and watch them move in.",
		"anchor": ""
	},
	{
		"icon":  "💧",
		"title": "Earn Dewdrops",
		"body":  "Happy Roamers generate Dewdrops over time. Bonded Roamers earn significantly more.\n\nSpend Dewdrops in Maren's shop to expand your garden.",
		"anchor": ""
	},
	{
		"icon":  "✨",
		"title": "You're ready!",
		"body":  "That's everything you need to get started. Your garden will grow with time.\n\nGood luck, Warden.",
		"anchor": ""
	},
]

# ── Colours ───────────────────────────────────────────────────────────────────
const C_BG      := Color(0.03, 0.06, 0.03, 0.97)
const C_BORDER  := Color(0.52, 0.88, 0.32, 1.00)
const C_TEXT    := Color(0.93, 0.91, 0.82, 1.00)
const C_MUTED   := Color(0.58, 0.70, 0.48, 1.00)
const C_ACCENT  := Color(0.52, 0.88, 0.32, 1.00)
const C_GOLD    := Color(0.95, 0.80, 0.28, 1.00)
const C_BTN_N   := Color(0.10, 0.19, 0.08, 1.00)
const C_BTN_H   := Color(0.18, 0.34, 0.14, 1.00)

func _ready() -> void:
	layer = 128  # on top of everything

func try_start() -> void:
	if _is_done():
		return
	_build_ui()
	_show_step(0)
	_active = true

func _is_done() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return cfg.get_value("tutorial", "done", false)

func _mark_done() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "done", true)
	cfg.save(SAVE_PATH)

# ── UI build ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Dim overlay — semi-transparent dark wash
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.02, 0.0, 0.52)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Tutorial card — centred, slightly below middle
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.border_width_left  = 4
	style.border_width_bottom = 3
	style.set_corner_radius_all(12)
	style.content_margin_left   = 28
	style.content_margin_right  = 28
	style.content_margin_top    = 24
	style.content_margin_bottom = 24
	style.shadow_color  = Color(0, 0, 0, 0.7)
	style.shadow_size   = 12
	style.shadow_offset = Vector2(4, 6)
	_card.add_theme_stylebox_override("panel", style)
	_card.custom_minimum_size = Vector2(420, 0)
	_card.anchor_left   = 0.5
	_card.anchor_right  = 0.5
	_card.anchor_top    = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left   = -210.0
	_card.offset_right  =  210.0
	_card.offset_top    = -130.0
	_card.offset_bottom =  130.0
	add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_card.add_child(vbox)

	# Step counter dots will be added dynamically — just placeholders for layout
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var icon_lbl := Label.new()
	icon_lbl.name = "IconLbl"
	icon_lbl.add_theme_font_size_override("font_size", 32)
	top_row.add_child(icon_lbl)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", C_ACCENT)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_title_lbl)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.28, 0.46, 0.22, 0.40)
	sep_style.content_margin_top    = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	_body_lbl = Label.new()
	_body_lbl.add_theme_font_size_override("font_size", 13)
	_body_lbl.add_theme_color_override("font_color", C_TEXT)
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(_body_lbl)

	# Progress dots
	var dots_row := HBoxContainer.new()
	dots_row.name = "DotsRow"
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.add_theme_constant_override("separation", 6)
	vbox.add_child(dots_row)
	for i in STEPS.size():
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 10)
		dot.add_theme_color_override("font_color", C_MUTED)
		dots_row.add_child(dot)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip Tutorial"
	_skip_btn.add_theme_font_size_override("font_size", 11)
	_skip_btn.add_theme_color_override("font_color", C_MUTED)
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0, 0, 0, 0)
	skip_style.set_border_width_all(0)
	_skip_btn.add_theme_stylebox_override("normal",  skip_style)
	_skip_btn.add_theme_stylebox_override("hover",   skip_style)
	_skip_btn.add_theme_stylebox_override("pressed", skip_style)
	_skip_btn.pressed.connect(_finish)
	btn_row.add_child(_skip_btn)

	_btn = Button.new()
	_btn.text = "Next  →"
	_btn.custom_minimum_size = Vector2(120, 36)
	_btn.add_theme_font_size_override("font_size", 13)
	var btn_n := _make_btn_style(C_BTN_N)
	var btn_h := _make_btn_style(C_BTN_H)
	var btn_p := _make_btn_style(Color(0.06, 0.12, 0.05))
	_btn.add_theme_stylebox_override("normal",  btn_n)
	_btn.add_theme_stylebox_override("hover",   btn_h)
	_btn.add_theme_stylebox_override("pressed", btn_p)
	_btn.add_theme_color_override("font_color",         C_ACCENT)
	_btn.add_theme_color_override("font_hover_color",   C_ACCENT)
	_btn.add_theme_color_override("font_pressed_color", C_TEXT)
	_btn.pressed.connect(_next_step)
	btn_row.add_child(_btn)

	# Start hidden — _show_step will animate in
	_card.modulate   = Color(1, 1, 1, 0)
	_overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "modulate", Color(1, 1, 1, 1), 0.4)
	tw.tween_property(_card,    "modulate", Color(1, 1, 1, 1), 0.5)

func _make_btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.content_margin_left   = 14
	s.content_margin_right  = 14
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s

func _show_step(index: int) -> void:
	_step = index
	var data: Dictionary = STEPS[index]

	# Icon
	var icon_lbl := _card.find_child("IconLbl", true, false) as Label
	if icon_lbl:
		icon_lbl.text = data["icon"]

	_title_lbl.text = data["title"]
	_body_lbl.text  = data["body"]

	# Last step — change button text
	if index == STEPS.size() - 1:
		_btn.text = "Begin  ✓"

	# Update progress dots
	var dots_row := _card.find_child("DotsRow", true, false)
	if dots_row:
		for i in dots_row.get_child_count():
			var dot := dots_row.get_child(i) as Label
			dot.add_theme_color_override("font_color",
				C_ACCENT if i == index else C_MUTED)

	# Subtle cross-fade of card content
	var tw := create_tween()
	tw.tween_property(_card, "modulate", Color(1, 1, 1, 0.5), 0.08)
	tw.tween_property(_card, "modulate", Color(1, 1, 1, 1.0), 0.12)

func _next_step() -> void:
	if _step < STEPS.size() - 1:
		_show_step(_step + 1)
	else:
		_finish()

func _finish() -> void:
	_active = false
	_mark_done()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card,    "modulate", Color(1, 1, 1, 0), 0.25)
	tw.tween_property(_overlay, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.chain().tween_callback(func():
		_card.queue_free()
		_overlay.queue_free()
		_card    = null
		_overlay = null
	)
	emit_signal("tutorial_finished")
