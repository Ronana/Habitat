## field_journal.gd — Open-book UI. Home for Roamers, Wildlife guide, and Quests.
## All UI built procedurally; .tscn is a minimal CanvasLayer skeleton.
extends CanvasLayer

# ─── Data / state ─────────────────────────────────────────────────────────────
var journal_entries := {}
var _journal_roamer           = null
var _selected_quest: Dictionary = {}

## "roamers" | "wildlife" | "quests"
var _tab_mode := "roamers"

# ─── Node refs ────────────────────────────────────────────────────────────────
var _book_root:          Control       = null
var _dim:                ColorRect     = null
var _book_container:     Control       = null
var roamer_list:         VBoxContainer = null
var _left_vbox:          VBoxContainer = null

# Right-page containers (one shown at a time)
var _right_roamer_ctr:   Control       = null
var _right_quest_ctr:    Control       = null

# Roamer detail labels
var entry_name:          Label         = null
var entry_stage:         Label         = null
var stage_hint:          Label         = null
var entry_happiness:     Label         = null
var needs_detail:        Label         = null
var family_detail:       Label         = null
var discovery_detail:    Label         = null
var tips_detail:         Label         = null
var _rename_input:       LineEdit      = null

# Quest detail labels
var _quest_title_lbl:    Label         = null
var _quest_desc_lbl:     Label         = null
var _quest_reward_lbl:   Label         = null
var _quest_hint_lbl:     Label         = null
var _quest_empty_lbl:    Label         = null
var _warden_level_lbl:   Label         = null
var _warden_xp_lbl:      Label         = null
var _warden_done_lbl:    Label         = null

# Tab buttons
var _tab_roamers_btn:    Button        = null
var _tab_wildlife_btn:   Button        = null
var _tab_quests_btn:     Button        = null

# ─── Roamer data ──────────────────────────────────────────────────────────────
var roamer_tips := {
	"GlowFox":    "Glowfoxes are drawn to warmth and berry bushes. Plant berries nearby and they will visit more readily. They are most active at dusk when their fur begins to glow.",
	"Mossdeer":   "Mossdeer are gentle grazers that prefer open spaces. They are nervous creatures — avoid loud activities nearby. Their mossy antlers grow larger the happier they are.",
	"Stoneback":  "Stonebacks are ancient and patient. They require at least two shelters before they feel safe enough to settle. They live very long lives and generate steady dewdrops simply by existing in a calm garden.",
	"Thornmouse": "Thornmice are skittish but curious. Keep berry bushes well-watered and plant wildgrass to give them places to hide. Once they trust you they will dart about the garden in quick, energetic bursts.",
	"Emberowl":   "Emberowls sleep through daylight hours, so visit them after dark. They are drawn to trees and warm light sources. Their amber eyes glow brighter at night — a sign they are happy and alert.",
	"Crystalback":"Crystalbacks are slow, peaceful wanderers drawn to beautiful things. The more decorative items you place, the sooner one will appear. They retreat into their shells when startled, so keep the garden calm.",
}

var roamer_discovery_notes := {
	"GlowFox":    "A fox whose fur smoulders with a warm amber glow. First spotted at the edge of the wilderness, drawn by the scent of berries.",
	"Mossdeer":   "A graceful deer with antlers carpeted in living moss and tiny wildflowers. Moves slowly and deliberately through open clearings.",
	"Stoneback":  "A tortoise with a shell of ancient stone, etched with grooves that deepen with age. Moves with unhurried purpose and seems unbothered by the passage of seasons.",
	"Thornmouse": "A small, quick mouse with oversized ears and a cream-tipped tail. It twitches its nose constantly, reading the air for danger or food — usually in that order.",
	"Emberowl":   "A round, dark owl with eyes like smouldering coals. It perches in hollow trees by day and glides silently through the garden at night, its gaze casting a faint amber glow.",
	"Crystalback":"A gentle tortoise whose shell has grown a formation of pale blue crystals over many years. It moves slowly, pauses to admire things it finds interesting, and pulses with a soft inner light.",
}

# ─── Palette ──────────────────────────────────────────────────────────────────
const C_PARCH_L    := Color(0.925, 0.890, 0.778, 1.0)
const C_PARCH_R    := Color(0.910, 0.872, 0.758, 1.0)
const C_LEATHER    := Color(0.162, 0.098, 0.044, 1.0)
const C_SPINE      := Color(0.098, 0.055, 0.020, 1.0)
const C_INK        := Color(0.128, 0.092, 0.052, 1.0)
const C_INK_SOFT   := Color(0.340, 0.272, 0.168, 1.0)
const C_INK_FAINT  := Color(0.520, 0.452, 0.330, 1.0)
const C_GOLD       := Color(0.722, 0.520, 0.182, 1.0)
const C_GOLD_L     := Color(0.905, 0.748, 0.362, 1.0)
const C_MAGIC      := Color(0.548, 0.218, 0.822, 1.0)
const C_MAGIC_S    := Color(0.692, 0.448, 0.888, 1.0)
const C_POSITIVE   := Color(0.178, 0.452, 0.108, 1.0)
const C_WARNING    := Color(0.680, 0.385, 0.042, 1.0)
const C_DANGER     := Color(0.655, 0.095, 0.072, 1.0)

const BOOK_W  := 990
const BOOK_H  := 620
const SPINE_W := 20

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready():
	_build_book()
	ObjectiveManager.objectives_updated.connect(_on_objectives_updated)
	ObjectiveManager.objective_completed.connect(_on_objective_completed_journal)


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			toggle_journal()
		elif event.keycode == KEY_ESCAPE and _book_root and _book_root.visible:
			close_journal()


# ─── Book construction ────────────────────────────────────────────────────────

func _build_book():
	_book_root = Control.new()
	_book_root.name = "BookRoot"
	_book_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_root.visible = false
	_book_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_book_root)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_book_root.add_child(_dim)
	_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_journal()
	)

	_book_container = Control.new()
	_book_container.name = "BookContainer"
	_book_container.custom_minimum_size = Vector2(BOOK_W, BOOK_H)
	_book_container.size = Vector2(BOOK_W, BOOK_H)
	_book_container.set_anchor(SIDE_LEFT,   0.5)
	_book_container.set_anchor(SIDE_RIGHT,  0.5)
	_book_container.set_anchor(SIDE_TOP,    0.5)
	_book_container.set_anchor(SIDE_BOTTOM, 0.5)
	_book_container.set_offset(SIDE_LEFT,   -BOOK_W * 0.5)
	_book_container.set_offset(SIDE_RIGHT,   BOOK_W * 0.5)
	_book_container.set_offset(SIDE_TOP,    -BOOK_H * 0.5)
	_book_container.set_offset(SIDE_BOTTOM,  BOOK_H * 0.5)
	_book_container.pivot_offset = Vector2(BOOK_W * 0.5, BOOK_H * 0.5)
	_book_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_book_root.add_child(_book_container)

	# Magic glow
	var glow := Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.set_offset(SIDE_LEFT, -16);  glow.set_offset(SIDE_TOP, -10)
	glow.set_offset(SIDE_RIGHT, 16);  glow.set_offset(SIDE_BOTTOM, 10)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0, 0, 0, 0)
	glow_style.shadow_color = Color(0.42, 0.15, 0.72, 0.60)
	glow_style.shadow_size  = 28
	glow_style.set_corner_radius_all(14)
	glow.add_theme_stylebox_override("panel", glow_style)
	_book_container.add_child(glow)

	# Leather cover
	var outer := Panel.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = C_LEATHER
	outer_style.border_color = C_GOLD
	outer_style.set_border_width_all(3)
	outer_style.set_corner_radius_all(9)
	outer.add_theme_stylebox_override("panel", outer_style)
	_book_container.add_child(outer)

	_add_corner_ornaments(_book_container)

	# Inner pages
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.set_offset(SIDE_LEFT, 8);   hbox.set_offset(SIDE_TOP, 8)
	hbox.set_offset(SIDE_RIGHT, -8); hbox.set_offset(SIDE_BOTTOM, -8)
	hbox.add_theme_constant_override("separation", 0)
	_book_container.add_child(hbox)

	var left_page := _make_page_panel(true)
	hbox.add_child(left_page)
	_build_left_content(left_page)

	hbox.add_child(_make_spine())

	var right_page := _make_page_panel(false)
	hbox.add_child(right_page)
	_build_right_content(right_page)

	_book_container.add_child(_make_close_button())

	_build_tab_buttons()
	_build_rename_row()


func _make_page_panel(is_left: bool) -> PanelContainer:
	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = C_PARCH_L if is_left else C_PARCH_R
	style.set_content_margin_all(16)
	if is_left:
		style.corner_radius_top_left = 3;    style.corner_radius_bottom_left = 3
	else:
		style.corner_radius_top_right = 3;   style.corner_radius_bottom_right = 3
	page.add_theme_stylebox_override("panel", style)
	return page


func _make_spine() -> Control:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(SPINE_W, 0)
	c.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	c.color = C_SPINE
	var h := ColorRect.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.set_offset(SIDE_LEFT, 3);  h.set_offset(SIDE_RIGHT, -SPINE_W + 5)
	h.color = Color(1, 1, 1, 0.04);  h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	return c


func _add_corner_ornaments(parent: Control):
	for o in [
		{"t":"✦","x":6,           "y":2},
		{"t":"✦","x":BOOK_W - 22, "y":2},
		{"t":"✦","x":6,           "y":BOOK_H - 24},
		{"t":"✦","x":BOOK_W - 22, "y":BOOK_H - 24},
	]:
		var lbl := Label.new()
		lbl.text = o["t"];  lbl.position = Vector2(o["x"], o["y"])
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", C_GOLD)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)


func _make_close_button() -> Button:
	var btn := Button.new()
	btn.text = "✕";  btn.custom_minimum_size = Vector2(30, 30)
	btn.position = Vector2(BOOK_W - 38, 3)
	btn.pressed.connect(close_journal)
	var norm := StyleBoxFlat.new()
	norm.bg_color = C_LEATHER;  norm.border_color = C_GOLD
	norm.set_border_width_all(1);  norm.set_corner_radius_all(15)
	norm.set_content_margin_all(3)
	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.35, 0.18, 0.05)
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",       C_GOLD)
	btn.add_theme_color_override("font_hover_color", C_GOLD_L)
	btn.add_theme_font_size_override("font_size", 13)
	return btn


# ─── Left page ────────────────────────────────────────────────────────────────

func _build_left_content(page: PanelContainer):
	_left_vbox = VBoxContainer.new()
	_left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_left_vbox.add_theme_constant_override("separation", 5)
	page.add_child(_left_vbox)

	var title := _ink_label("✦  Field Journal  ✦", 19, C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_vbox.add_child(title)  # index 0

	var pg_num := _ink_label("I", 10, C_INK_FAINT)
	pg_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_vbox.add_child(pg_num)  # index 1

	_left_vbox.add_child(_gold_divider())  # index 2

	# Tab row inserted at index 3 by _build_tab_buttons()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_vbox.add_child(scroll)  # index 4 (after tabs injected at 3)

	roamer_list = VBoxContainer.new()
	roamer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roamer_list.add_theme_constant_override("separation", 4)
	scroll.add_child(roamer_list)


# ─── Right page ───────────────────────────────────────────────────────────────

func _build_right_content(page: PanelContainer):
	# Container holds two sub-containers; only one visible at a time
	var root_ctr := Control.new()
	root_ctr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_ctr.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	page.add_child(root_ctr)

	# ── Roamer container ──────────────────────────────────────────────────────
	_right_roamer_ctr = ScrollContainer.new()
	_right_roamer_ctr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_right_roamer_ctr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_ctr.add_child(_right_roamer_ctr)

	var rvbox := VBoxContainer.new()
	rvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rvbox.add_theme_constant_override("separation", 7)
	_right_roamer_ctr.add_child(rvbox)

	var pg_r := _ink_label("II", 10, C_INK_FAINT)
	pg_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rvbox.add_child(pg_r)

	entry_name = _ink_label("Select a Roamer", 21, C_INK)
	rvbox.add_child(entry_name)

	entry_stage = _ink_label("Stage: —", 12, C_INK_SOFT)
	rvbox.add_child(entry_stage)

	stage_hint = _ink_label("", 11, C_MAGIC_S)
	stage_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_hint.custom_minimum_size = Vector2(380, 0)
	rvbox.add_child(stage_hint)

	rvbox.add_child(_ink_divider())

	entry_happiness = _ink_label("Happiness: —", 12, C_INK_SOFT)
	rvbox.add_child(entry_happiness)

	rvbox.add_child(_section_header("Needs"))
	needs_detail = _ink_label("—", 11, C_INK_SOFT)
	needs_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs_detail.custom_minimum_size = Vector2(380, 0)
	rvbox.add_child(needs_detail)

	family_detail = _ink_label("", 11, C_INK_FAINT)
	family_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	family_detail.custom_minimum_size = Vector2(380, 0)
	rvbox.add_child(family_detail)

	rvbox.add_child(_ink_divider())

	rvbox.add_child(_section_header("Discovery Notes"))
	discovery_detail = _ink_label("Not yet discovered.", 11, C_INK_SOFT)
	discovery_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discovery_detail.custom_minimum_size = Vector2(380, 0)
	rvbox.add_child(discovery_detail)

	rvbox.add_child(_ink_divider())

	rvbox.add_child(_section_header("Warden Notes"))
	tips_detail = _ink_label("Keep observing to learn more.", 11, C_INK_FAINT)
	tips_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips_detail.custom_minimum_size = Vector2(380, 0)
	rvbox.add_child(tips_detail)

	# ── Quest container ───────────────────────────────────────────────────────
	_right_quest_ctr = ScrollContainer.new()
	_right_quest_ctr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_right_quest_ctr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_quest_ctr.visible = false
	root_ctr.add_child(_right_quest_ctr)

	var qvbox := VBoxContainer.new()
	qvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qvbox.add_theme_constant_override("separation", 8)
	_right_quest_ctr.add_child(qvbox)

	var pg_q := _ink_label("II", 10, C_INK_FAINT)
	pg_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qvbox.add_child(pg_q)

	# Empty-state label (shown when no quest selected)
	_quest_empty_lbl = _ink_label(
		"Maren leaves notes about what she hopes\nto see in the garden.\n\nSelect a task on the left to read\nher full instructions.",
		12, C_INK_SOFT)
	_quest_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_empty_lbl.custom_minimum_size = Vector2(380, 0)
	qvbox.add_child(_quest_empty_lbl)

	qvbox.add_child(_ink_divider())

	# Quest detail (hidden until a quest is selected)
	_quest_title_lbl = _ink_label("", 20, C_INK)
	_quest_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_title_lbl.custom_minimum_size = Vector2(380, 0)
	_quest_title_lbl.visible = false
	qvbox.add_child(_quest_title_lbl)

	_quest_desc_lbl = _ink_label("", 12, C_INK_SOFT)
	_quest_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_desc_lbl.custom_minimum_size = Vector2(380, 0)
	_quest_desc_lbl.visible = false
	qvbox.add_child(_quest_desc_lbl)

	_quest_hint_lbl = _ink_label("", 11, C_MAGIC_S)
	_quest_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_hint_lbl.custom_minimum_size = Vector2(380, 0)
	_quest_hint_lbl.visible = false
	qvbox.add_child(_quest_hint_lbl)

	_quest_reward_lbl = _ink_label("", 13, C_GOLD)
	_quest_reward_lbl.visible = false
	qvbox.add_child(_quest_reward_lbl)

	qvbox.add_child(_ink_divider())

	# Warden progress (always shown at bottom of quests right page)
	qvbox.add_child(_section_header("Warden Progress"))
	_warden_level_lbl = _ink_label("Level —", 13, C_INK)
	qvbox.add_child(_warden_level_lbl)
	_warden_xp_lbl = _ink_label("", 11, C_INK_SOFT)
	qvbox.add_child(_warden_xp_lbl)
	_warden_done_lbl = _ink_label("", 11, C_INK_FAINT)
	qvbox.add_child(_warden_done_lbl)


# ─── Label helpers ────────────────────────────────────────────────────────────

func _ink_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", C_GOLD)
	return lbl


func _gold_divider() -> Label:
	var lbl := Label.new()
	lbl.text = "────────────────────────────"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", C_GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _ink_divider() -> Label:
	var lbl := Label.new()
	lbl.text = "  ─────────────────────────────"
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", C_INK_FAINT)
	return lbl


# ─── Tab buttons ──────────────────────────────────────────────────────────────

func _build_tab_buttons():
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 2)

	_tab_roamers_btn  = _make_tab_btn("📋 Roamers",  true)
	_tab_wildlife_btn = _make_tab_btn("🌿 Wildlife", false)
	_tab_quests_btn   = _make_tab_btn("📜 Quests",   false)

	_tab_roamers_btn.pressed.connect(_switch_tab.bind("roamers"))
	_tab_wildlife_btn.pressed.connect(_switch_tab.bind("wildlife"))
	_tab_quests_btn.pressed.connect(_switch_tab.bind("quests"))

	tab_row.add_child(_tab_roamers_btn)
	tab_row.add_child(_tab_wildlife_btn)
	tab_row.add_child(_tab_quests_btn)

	_left_vbox.add_child(tab_row)
	_left_vbox.move_child(tab_row, 3)  # after: title(0), pg_num(1), divider(2)


func _make_tab_btn(text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size   = Vector2(0, 26)

	var norm := StyleBoxFlat.new()
	norm.bg_color     = C_PARCH_L if active else Color(0.82, 0.78, 0.66, 1.0)
	norm.border_color = C_GOLD if active else C_INK_FAINT
	norm.set_border_width_all(1)
	norm.border_width_bottom = 0 if active else 1
	norm.corner_radius_top_left = 4;  norm.corner_radius_top_right = 4
	norm.set_content_margin_all(4)

	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = C_PARCH_L;  hov.border_color = C_GOLD

	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",       C_INK if active else C_INK_SOFT)
	btn.add_theme_color_override("font_hover_color", C_INK)
	btn.add_theme_font_size_override("font_size", 10)
	return btn


func _switch_tab(mode: String):
	_tab_mode = mode
	_restyle_tab(_tab_roamers_btn,  mode == "roamers")
	_restyle_tab(_tab_wildlife_btn, mode == "wildlife")
	_restyle_tab(_tab_quests_btn,   mode == "quests")
	_right_roamer_ctr.visible = (mode != "quests")
	_right_quest_ctr.visible  = (mode == "quests")
	if mode == "quests":
		_refresh_warden_progress()
	refresh_journal()


func _restyle_tab(btn: Button, active: bool):
	var norm := btn.get_theme_stylebox("normal") as StyleBoxFlat
	if norm:
		norm.bg_color     = C_PARCH_L if active else Color(0.82, 0.78, 0.66, 1.0)
		norm.border_color = C_GOLD if active else C_INK_FAINT
	btn.add_theme_color_override("font_color", C_INK if active else C_INK_SOFT)


# ─── Rename row ───────────────────────────────────────────────────────────────

func _build_rename_row():
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	row.add_child(_ink_label("Rename:", 11, C_INK_FAINT))

	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Enter name…"
	_rename_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_input.custom_minimum_size = Vector2(150, 28)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.88, 0.84, 0.72, 1.0)
	input_style.border_color = C_INK_FAINT
	input_style.set_border_width_all(1);  input_style.set_corner_radius_all(3)
	input_style.set_content_margin_all(5)
	_rename_input.add_theme_stylebox_override("normal", input_style)
	_rename_input.add_theme_stylebox_override("focus",  input_style)
	_rename_input.add_theme_color_override("font_color", C_INK)
	_rename_input.add_theme_font_size_override("font_size", 11)
	row.add_child(_rename_input)

	var btn := _make_ink_btn("✏ Rename")
	btn.pressed.connect(_confirm_rename)
	_rename_input.text_submitted.connect(func(_t): _confirm_rename())
	row.add_child(btn)

	# Insert after entry_name in rvbox — rvbox is child 0 of _right_roamer_ctr
	var rvbox := _right_roamer_ctr.get_child(0) as VBoxContainer
	if rvbox:
		rvbox.add_child(row)
		rvbox.move_child(row, 2)  # after pg_num(0), entry_name(1)


func _make_ink_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 11)
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.82, 0.78, 0.66, 1.0);  norm.border_color = C_INK_SOFT
	norm.set_border_width_all(1);  norm.set_corner_radius_all(3)
	norm.set_content_margin_all(5)
	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.76, 0.70, 0.58, 1.0)
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", C_INK)
	return btn


func _confirm_rename():
	if not is_instance_valid(_journal_roamer):
		return
	var new_name := _rename_input.text.strip_edges()
	if new_name.is_empty():
		return
	_journal_roamer.set_roamer_name(new_name)
	ObjectiveManager.record_rename()
	entry_name.text = new_name
	refresh_journal()


# ─── Animation ────────────────────────────────────────────────────────────────

func toggle_journal():
	if _book_root and _book_root.visible:
		_hide_book()
	else:
		_show_book()


## Open journal directly on a specific tab ("roamers", "wildlife", "quests").
func open_on_tab(tab: String):
	_switch_tab(tab)
	if _book_root and not _book_root.visible:
		_show_book()


func close_journal():
	_hide_book()


func _show_book():
	refresh_journal()
	_book_root.visible = true
	_book_container.scale    = Vector2(0.04, 0.96)
	_book_container.modulate = Color(1, 1, 1, 0.0)
	_dim.color = Color(0, 0, 0, 0)

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dim,            "color",      Color(0, 0, 0, 0.65), 0.30)
	tw.tween_property(_book_container, "scale",      Vector2(1.0, 1.0),    0.32)
	tw.tween_property(_book_container, "modulate:a", 1.0,                  0.22)


func _hide_book():
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(_book_container, "scale",      Vector2(0.04, 0.96), 0.20)
	tw.tween_property(_book_container, "modulate:a", 0.0,                 0.16)
	tw.tween_property(_dim,            "color",      Color(0, 0, 0, 0),   0.20)
	tw.chain().tween_callback(func():
		_book_root.visible = false
		_book_container.scale   = Vector2(1.0, 1.0)
		_book_container.modulate = Color(1, 1, 1, 1.0)
	)


# ─── Refresh dispatch ─────────────────────────────────────────────────────────

func refresh_journal():
	if not roamer_list:
		return
	match _tab_mode:
		"roamers":  _build_roamer_list()
		"wildlife": _build_wildlife_list()
		"quests":   _build_quest_list()


func _clear_list():
	for child in roamer_list.get_children():
		child.queue_free()


# ─── Roamer list ──────────────────────────────────────────────────────────────

func _build_roamer_list():
	_clear_list()
	var roamers := get_tree().get_nodes_in_group("roamers")
	if roamers.is_empty():
		roamer_list.add_child(_ink_label("No Roamers discovered yet.", 12, C_INK_FAINT))
		return
	for roamer in roamers:
		var stage_icons := ["👀", "🚶", "🏠", "💚"]
		var display_name: String = roamer.roamer_name if roamer.roamer_name != "" else roamer.name
		var btn := _make_entry_btn(stage_icons[roamer.attraction_stage] + "  " + display_name)
		btn.pressed.connect(_on_roamer_selected.bind(roamer))
		roamer_list.add_child(btn)


func _make_entry_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 34)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 12)

	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0, 0, 0, 0);  norm.border_color = Color(0, 0, 0, 0)
	norm.set_border_width_all(0);  norm.border_width_left = 2
	norm.set_corner_radius_all(0);  norm.set_content_margin_all(6)
	norm.content_margin_left = 10

	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.0, 0.0, 0.0, 0.06);  hov.border_color = C_GOLD
	hov.border_width_left = 2

	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",       C_INK)
	btn.add_theme_color_override("font_hover_color", C_INK)
	return btn


# ─── Wildlife list ────────────────────────────────────────────────────────────

func _build_wildlife_list():
	_clear_list()
	for species_id in AttractionManager.SPECIES:
		var data: Dictionary = AttractionManager.SPECIES[species_id]
		var icon: String     = data.get("icon", "🐾")
		var in_garden        := AttractionManager.count_in_garden(species_id)

		var status_text: String
		var status_color: Color
		if in_garden == 0:
			status_text = "Not yet seen";  status_color = C_INK_FAINT
		else:
			var highest := 0
			for r in get_tree().get_nodes_in_group("roamers"):
				if r.species_id == species_id:
					highest = max(highest, r.attraction_stage)
			var snames := ["Appears", "Visits", "Resident", "Bonded"]
			status_text  = snames[highest] + " (" + str(in_garden) + ")"
			status_color = C_POSITIVE

		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.add_child(_ink_label(icon + "  " + species_id, 13, C_INK))
		card.add_child(_ink_label(status_text, 10, status_color))
		card.add_child(_ink_label("Visit:", 10, C_GOLD))
		for req in AttractionManager.get_visit_status(species_id):
			card.add_child(_ink_label(("✓ " if req["met"] else "✗ ") + req["label"],
				10, C_POSITIVE if req["met"] else C_DANGER))
		card.add_child(_ink_label("Resident:", 10, C_GOLD))
		for req in AttractionManager.get_resident_status(species_id):
			card.add_child(_ink_label(("✓ " if req["met"] else "✗ ") + req["label"],
				10, C_POSITIVE if req["met"] else C_DANGER))
		card.add_child(_ink_divider())
		roamer_list.add_child(card)


# ─── Quest list ───────────────────────────────────────────────────────────────

func _build_quest_list():
	_clear_list()

	# Active quests section
	var hdr := _section_header("Active Tasks")
	roamer_list.add_child(hdr)

	var active: Array = ObjectiveManager.active_objectives
	if active.is_empty():
		roamer_list.add_child(_ink_label("All tasks complete — new ones coming soon.", 11, C_INK_FAINT))
	else:
		for obj in active:
			var btn := _make_quest_entry_btn(obj)
			btn.pressed.connect(_on_quest_selected.bind(obj))
			roamer_list.add_child(btn)

	roamer_list.add_child(_ink_divider())

	# Completed count
	var done_count := ObjectiveManager.completed_ids.size()
	var total      := ObjectiveManager.POOL.size()
	var done_lbl   := _ink_label(
		"Completed: " + str(done_count) + " / " + str(total), 11, C_INK_FAINT)
	roamer_list.add_child(done_lbl)

	# Progress bar (ink characters)
	var bar_val := float(done_count) / float(max(total, 1))
	var filled  := int(bar_val * 16)
	var bar_lbl := _ink_label("[" + "█".repeat(filled) + "░".repeat(16 - filled) + "]",
		10, C_GOLD)
	roamer_list.add_child(bar_lbl)


func _make_quest_entry_btn(obj: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = obj.get("desc", "Unknown task")
	btn.custom_minimum_size = Vector2(200, 0)
	btn.alignment   = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text   = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_size_override("font_size", 11)

	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0, 0, 0, 0.0);  norm.border_color = Color(0, 0, 0, 0)
	norm.set_border_width_all(0);  norm.border_width_left = 2
	norm.set_corner_radius_all(0);  norm.set_content_margin_all(5)
	norm.content_margin_left = 10

	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.0, 0.0, 0.0, 0.05);  hov.border_color = C_GOLD
	hov.border_width_left = 2

	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",       C_INK)
	btn.add_theme_color_override("font_hover_color", C_INK)
	return btn


func _on_quest_selected(obj: Dictionary):
	_selected_quest = obj
	_quest_empty_lbl.visible = false
	_quest_title_lbl.visible = true
	_quest_desc_lbl.visible  = true
	_quest_hint_lbl.visible  = true
	_quest_reward_lbl.visible = true

	_quest_title_lbl.text  = obj.get("desc", "")
	_quest_desc_lbl.text   = _quest_flavour(obj)
	_quest_hint_lbl.text   = _quest_progress_hint(obj)
	_quest_reward_lbl.text = "✦ Reward: " + str(obj.get("reward", 0)) + " Dewdrops"
	_refresh_warden_progress()


func _quest_flavour(obj: Dictionary) -> String:
	# A short atmospheric note to go with the mechanical description
	match obj.get("type", ""):
		"roamers_total":   return "Maren scrawls a note in the margin:\n\"More life in the garden. Every creature that wanders in is another small miracle.\""
		"residents":       return "Maren's handwriting is neat and careful here:\n\"A Resident is a Roamer that has decided to stay. That trust is earned slowly and cannot be rushed.\""
		"bonded":          return "Underlined twice:\n\"Bonded Roamers are the heart of a great garden. Keep them happy and they will reward you generously.\""
		"eggs_hatched":    return "\"The egg is the beginning of everything.\nWhat hatches is yours to care for.\""
		"food_count":      return "\"A garden without food is merely a yard.\nPlant well and they will come.\""
		"shelter_count":   return "\"Every creature needs a safe place to sleep.\nShelters are an act of welcome.\""
		"decor_count":     return "\"Beauty matters. A well-kept garden draws curious eyes\n— both creature and warden.\""
		"light_count":     return "\"Darkness keeps timid things away.\nLight invites them closer.\""
		"all_happy":       return "\"Happiness is not an accident.\nIt is the result of a hundred small good decisions.\""
		"dewdrops_earned": return "\"Dewdrops are the garden's way of saying thank you.\nKeep earning them.\""
		"named_roamers":   return "\"Give a creature a name and it stops being a visitor.\nIt becomes yours — and you become theirs.\""
		"trait_count":     return "\"Some Roamers carry something special inside them.\nA good warden learns to see it.\""
		"interactions":    return "\"Spend time with them. Sit nearby. Offer your hand.\nThey remember kindness.\""
		"species_count":   return "\"Every species has its own story.\nLearn what " + obj.get("species", "it") + " needs and the rest will follow.\""
		"species_resident":return "\"A " + obj.get("species", "Roamer") + " that stays is a " + obj.get("species", "Roamer") + " that trusts you.\""
		"all_species":     return "\"Six kinds of creature, six kinds of wonder.\nA garden that holds them all is something rare.\""
	return "Maren has left a note here, but the ink has faded."


func _quest_progress_hint(obj: Dictionary) -> String:
	var type: String = obj.get("type", "")
	var value        := int(obj.get("value", 0))

	match type:
		"roamers_total":
			var cur := get_tree().get_nodes_in_group("roamers").size()
			return "Current: " + str(cur) + " / " + str(value) + " Roamers in garden"
		"residents":
			var cur := 0
			for r in get_tree().get_nodes_in_group("roamers"):
				if r.attraction_stage >= 2: cur += 1
			return "Current: " + str(cur) + " / " + str(value) + " Residents"
		"bonded":
			var cur := 0
			for r in get_tree().get_nodes_in_group("roamers"):
				if r.attraction_stage == 3: cur += 1
			return "Current: " + str(cur) + " / " + str(value) + " Bonded"
		"eggs_hatched":
			return "Hatched: " + str(ObjectiveManager.eggs_hatched) + " / " + str(value)
		"food_count":
			var cur := get_tree().get_nodes_in_group("food").size()
			return "Planted: " + str(cur) + " / " + str(value) + " berry bushes"
		"shelter_count":
			var cur := get_tree().get_nodes_in_group("shelters").size()
			return "Placed: " + str(cur) + " / " + str(value) + " shelters"
		"decor_count":
			var cur := get_tree().get_nodes_in_group("decoratives").size()
			return "Placed: " + str(cur) + " / " + str(value) + " decoratives"
		"interactions":
			return "Interactions: " + str(ObjectiveManager.interactions) + " / " + str(value)
		"species_count":
			var target: String = obj.get("species", "")
			var cur := 0
			for r in get_tree().get_nodes_in_group("roamers"):
				if r.species_id == target: cur += 1
			return target + " in garden: " + str(cur) + " / " + str(value)
		"species_resident":
			var target: String = obj.get("species", "")
			for r in get_tree().get_nodes_in_group("roamers"):
				if r.species_id == target and r.attraction_stage >= 2:
					return target + " is a Resident ✓"
			return "No " + target + " Resident yet"
		"all_species":
			var present: Array = []
			for r in get_tree().get_nodes_in_group("roamers"):
				if not present.has(r.species_id): present.append(r.species_id)
			return "Species present: " + str(present.size()) + " / 6"
	return ""


func _refresh_warden_progress():
	if not _warden_level_lbl:
		return
	var lvl:   int = WardenManager.current_level
	var xp:    int = int(WardenManager.current_xp)
	var next:  int = int(WardenManager.xp_to_next_level)
	var done:  int = ObjectiveManager.completed_ids.size()
	var total: int = ObjectiveManager.POOL.size()

	_warden_level_lbl.text = "Warden Level " + str(lvl)
	_warden_xp_lbl.text    = "XP: " + str(xp) + " / " + str(next) + \
		"  [" + "█".repeat(int(float(xp) / float(max(next, 1)) * 10)) + \
		"░".repeat(10 - int(float(xp) / float(max(next, 1)) * 10)) + "]"
	_warden_done_lbl.text  = "Quests completed: " + str(done) + " / " + str(total)


# ─── Objective signal handlers ────────────────────────────────────────────────

func _on_objectives_updated():
	if _tab_mode == "quests" and _book_root and _book_root.visible:
		_build_quest_list()
		_refresh_warden_progress()


func _on_objective_completed_journal(_obj: Dictionary):
	if _tab_mode == "quests" and _book_root and _book_root.visible:
		_build_quest_list()
		_refresh_warden_progress()


# ─── Roamer detail ────────────────────────────────────────────────────────────

func _on_roamer_selected(roamer):
	_journal_roamer = roamer
	var stage_names := ["Appears", "Visits", "Resident", "Bonded"]
	var display: String = roamer.roamer_name if roamer.roamer_name != "" else roamer.name

	entry_name.text  = display
	if _rename_input:
		_rename_input.text = roamer.roamer_name

	entry_stage.text = "Stage: " + stage_names[roamer.attraction_stage]
	stage_hint.text  = _get_stage_hint(roamer)

	entry_happiness.text = "Happiness: " + str(int(roamer.happiness * 100)) + "%" + \
		("  ·  Has shelter" if roamer.has_shelter else "  ·  Needs shelter")

	var needs_text := ""
	var worst := 1.0
	for need in roamer.needs:
		var val: float = roamer.needs[need]
		if val < worst: worst = val
		needs_text += need.capitalize() + ":  " + _make_bar(val) + "  " + str(int(val * 100)) + "%\n"
	needs_detail.text = needs_text.strip_edges()
	if worst < 0.3:
		needs_detail.add_theme_color_override("font_color", C_DANGER)
	elif worst < 0.6:
		needs_detail.add_theme_color_override("font_color", C_WARNING)
	else:
		needs_detail.add_theme_color_override("font_color", C_POSITIVE)

	family_detail.text = _get_family_text(roamer)
	if roamer.traits.is_empty():
		family_detail.text += "\nTraits: None"
	else:
		var t_text := "\nTraits: "
		for t in roamer.traits:
			var td: Dictionary = roamer.TRAIT_POOL.get(t, {})
			t_text += td.get("icon", "") + " " + td.get("name", t) + "  "
		family_detail.text += t_text.strip_edges()

	var key: String = roamer.species_id if roamer.species_id != "" else roamer.name
	discovery_detail.text = roamer_discovery_notes.get(key, "Still learning about this creature...")
	tips_detail.text      = roamer_tips.get(key,             "Keep observing to learn more.")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_stage_hint(roamer) -> String:
	match roamer.attraction_stage:
		0: return "→ Reach 50% happiness to progress  (currently " + str(int(roamer.happiness * 100)) + "%)"
		1:
			var pct := str(int(roamer.happiness * 100))
			if not AttractionManager.can_reside(roamer.species_id, roamer):
				return "→ Place a " + roamer.species_id + " den and reach 70% happiness  (currently " + pct + "%)"
			return "→ Reach 70% happiness to become Resident  (currently " + pct + "%)"
		2:
			if not roamer.is_adult:
				return "→ Still growing up — must be an adult to become Bonded"
			return "→ Reach 90% happiness to become Bonded  (currently " + str(int(roamer.happiness * 100)) + "%)"
		3: return "✓ Fully bonded — ready to breed!"
	return ""


func _get_family_text(roamer) -> String:
	var lines: Array = []
	if roamer.is_adult:
		lines.append("Adult")
	else:
		lines.append("Child (" + str(int((roamer.grow_up_timer / roamer.grow_up_time) * 100)) + "% grown)")
	if roamer.family_id != "":
		lines.append("Family: " + roamer.family_id.left(12) + "…")
	if roamer.parent_a_id != "" or roamer.parent_b_id != "":
		var pnames: Array = []
		for r in get_tree().get_nodes_in_group("roamers"):
			if str(r.get_instance_id()) == roamer.parent_a_id or \
			   str(r.get_instance_id()) == roamer.parent_b_id:
				pnames.append(r.roamer_name if r.roamer_name != "" else r.name)
		lines.append("Parents: " + (", ".join(pnames) if pnames.size() > 0 else "(no longer in garden)"))
	if roamer.is_breeding:
		lines.append("Currently breeding ♥")
	return "\n".join(lines)


func _make_bar(value: float) -> String:
	var f := int(value * 10)
	return "[" + "█".repeat(f) + "░".repeat(10 - f) + "]"


# ─── Journal data API ─────────────────────────────────────────────────────────

func discover_roamer(roamer_name: String):
	if not journal_entries.has(roamer_name):
		journal_entries[roamer_name] = {
			"discovered": true, "first_seen": get_time_string(),
			"times_fed": 0,     "highest_stage": 0,
		}
		WardenManager.gain_xp("roamer_appears")


func update_entry(roamer_name: String, stage: int, times_fed: int):
	if journal_entries.has(roamer_name):
		journal_entries[roamer_name]["highest_stage"] = max(
			journal_entries[roamer_name]["highest_stage"], stage)
		journal_entries[roamer_name]["times_fed"] = times_fed


func get_time_string() -> String:
	return DayNightManager.get_time_string()
