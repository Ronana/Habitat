extends CanvasLayer

@onready var journal_panel = $JournalPanel
@onready var roamer_list = $JournalPanel/HBoxContainer/LeftPanel/ScrollContainer/RoamerList
@onready var entry_name = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryName
@onready var entry_stage = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryStage
@onready var stage_hint = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/StageHint
@onready var entry_happiness = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryHappiness
@onready var needs_detail = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/NeedsDetail
@onready var family_detail = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/FamilyDetail
@onready var discovery_detail = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/DiscoveryDetail
@onready var tips_detail = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/TipsDetail
@onready var close_button = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/CloseButton

# Journal data — stores discovered roamer info
var journal_entries = {}

# Roamer tips database
var roamer_tips = {
	"GlowFox": "Glowfoxes are drawn to warmth and berry bushes. Plant berries nearby and they will visit more readily. They are most active at dusk when their fur begins to glow.",
	"Mossdeer": "Mossdeer are gentle grazers that prefer open spaces. They are nervous creatures — avoid loud activities nearby. Their mossy antlers grow larger the happier they are.",
}

var roamer_discovery_notes = {
	"GlowFox": "A fox whose fur smoulders with a warm amber glow. First spotted at the edge of the wilderness, drawn by the scent of berries.",
	"Mossdeer": "A graceful deer with antlers carpeted in living moss and tiny wildflowers. Moves slowly and deliberately through open clearings.",
}

func _ready():
	close_button.pressed.connect(close_journal)
	journal_panel.visible = false
	_apply_theme()

# ── Theme ─────────────────────────────────────────────────────────────────────
const C_BG       := Color(0.07, 0.11, 0.07, 0.95)
const C_BORDER   := Color(0.28, 0.46, 0.22, 1.00)
const C_TEXT     := Color(0.93, 0.91, 0.82, 1.00)
const C_MUTED    := Color(0.62, 0.72, 0.52, 1.00)
const C_ACCENT   := Color(0.52, 0.82, 0.32, 1.00)
const C_HEADER   := Color(0.78, 0.90, 0.60, 1.00)
const C_BTN_NORM := Color(0.14, 0.24, 0.11, 1.00)
const C_BTN_HOV  := Color(0.22, 0.38, 0.17, 1.00)
const C_BTN_PRS  := Color(0.08, 0.15, 0.06, 1.00)

func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.border_color = C_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	return s

func _make_side_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.09, 0.05, 0.95)
	s.border_color = C_BORDER
	s.set_border_width_all(0)
	s.border_width_right = 2
	s.set_corner_radius_all(0)
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

func _style_btn(btn: Button, accent: bool = false):
	btn.add_theme_stylebox_override("normal",  _make_btn_style(C_BTN_NORM))
	btn.add_theme_stylebox_override("hover",   _make_btn_style(C_BTN_HOV))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(C_BTN_PRS))
	btn.add_theme_color_override("font_color",         C_TEXT if not accent else C_ACCENT)
	btn.add_theme_color_override("font_hover_color",   C_ACCENT)
	btn.add_theme_color_override("font_pressed_color", C_TEXT)

func _style_lbl(lbl: Label, size: int, color: Color):
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

func _apply_theme():
	# Main panel background
	journal_panel.add_theme_stylebox_override("panel", _make_panel_style())

	# Left sidebar — slightly darker strip
	var left = $JournalPanel/HBoxContainer/LeftPanel
	# Title
	var title_lbl = $JournalPanel/HBoxContainer/LeftPanel/JournalTitle
	_style_lbl(title_lbl, 17, C_ACCENT)

	# Right panel labels
	_style_lbl(entry_name,      20, C_ACCENT)
	_style_lbl(entry_stage,     13, C_HEADER)
	_style_lbl(stage_hint,      12, C_MUTED)
	_style_lbl(entry_happiness, 13, C_TEXT)
	_style_lbl(needs_detail,    12, C_TEXT)
	_style_lbl(family_detail,   12, C_MUTED)

	# Section header labels
	var disc_hdr = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryDiscovery
	var tips_hdr = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryTips
	var needs_hdr = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryNeeds
	_style_lbl(disc_hdr,  12, C_HEADER)
	_style_lbl(tips_hdr,  12, C_HEADER)
	_style_lbl(needs_hdr, 12, C_HEADER)
	_style_lbl(discovery_detail, 12, C_TEXT)
	discovery_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_lbl(tips_detail, 12, C_MUTED)
	tips_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Close button
	_style_btn(close_button)
	close_button.custom_minimum_size = Vector2(200, 36)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_J:
			toggle_journal()

func toggle_journal():
	journal_panel.visible = !journal_panel.visible
	if journal_panel.visible:
		refresh_journal()

func close_journal():
	journal_panel.visible = false

func discover_roamer(roamer_name: String):
	if not journal_entries.has(roamer_name):
		journal_entries[roamer_name] = {
			"discovered": true,
			"first_seen": get_time_string(),
			"times_fed": 0,
			"highest_stage": 0
		}
		print("📖 New journal entry: ", roamer_name)
		WardenManager.gain_xp("roamer_appears")

func update_entry(roamer_name: String, stage: int, times_fed: int):
	if journal_entries.has(roamer_name):
		journal_entries[roamer_name]["highest_stage"] = max(
			journal_entries[roamer_name]["highest_stage"], stage
		)
		journal_entries[roamer_name]["times_fed"] = times_fed

func refresh_journal():
	for child in roamer_list.get_children():
		child.queue_free()

	var roamers = get_tree().get_nodes_in_group("roamers")
	print("Roamers found in journal: ", roamers.size())
	for r in roamers:
		print(" - ", r.name)

	if roamers.is_empty():
		var empty = Label.new()
		empty.text = "No Roamers discovered yet."
		roamer_list.add_child(empty)
		return

	for roamer in roamers:
		var btn = Button.new()
		var stage_icons = ["👀", "🚶", "🏠", "💚"]
		btn.text = stage_icons[roamer.attraction_stage] + " " + roamer.name
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_roamer_selected.bind(roamer))
		_style_btn(btn)
		roamer_list.add_child(btn)
		
	

func _on_roamer_selected(roamer):
	var stage_names = ["Appears", "Visits", "Resident", "Bonded"]
	entry_name.text = "🦊 " + roamer.name
	entry_stage.text = "Stage: " + stage_names[roamer.attraction_stage]
	stage_hint.text = _get_stage_hint(roamer)

	# Show shelter status
	if roamer.has_shelter:
		entry_happiness.text = "Happiness: " + str(int(roamer.happiness * 100)) + "% 🏠"
	else:
		entry_happiness.text = "Happiness: " + str(int(roamer.happiness * 100)) + "% (Needs shelter)"

	# Build needs string with colour-coded bars
	var needs_text = ""
	var worst_val := 1.0
	for need in roamer.needs:
		var val: float = roamer.needs[need]
		if val < worst_val:
			worst_val = val
		var bar = _make_bar(val)
		needs_text += need.capitalize() + ": " + bar + "  " + str(int(val * 100)) + "%\n"
	needs_detail.text = needs_text.strip_edges()
	# Colour the whole needs block by the worst need
	if worst_val < 0.3:
		needs_detail.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25, 1.0))
	elif worst_val < 0.6:
		needs_detail.add_theme_color_override("font_color", Color(0.95, 0.75, 0.20, 1.0))
	else:
		needs_detail.add_theme_color_override("font_color", Color(0.52, 0.82, 0.32, 1.0))

	family_detail.text = _get_family_text(roamer)

	# Discovery notes — use species_id for lookup, fall back to name
	var lookup_key = roamer.species_id if roamer.species_id != "" else roamer.name
	if roamer_discovery_notes.has(lookup_key):
		discovery_detail.text = roamer_discovery_notes[lookup_key]
	else:
		discovery_detail.text = "Still learning about this creature..."

	# Warden tips
	if roamer_tips.has(lookup_key):
		tips_detail.text = roamer_tips[lookup_key]
	else:
		tips_detail.text = "Keep observing to learn more."

func _get_stage_hint(roamer) -> String:
	match roamer.attraction_stage:
		0: # APPEARS
			var pct = int(roamer.happiness * 100)
			return "→ Reach 50% happiness to progress  (currently " + str(pct) + "%)"
		1: # VISITS
			var pct = int(roamer.happiness * 100)
			if not roamer.has_shelter:
				return "→ Place a shelter and reach 70% happiness to become Resident  (currently " + str(pct) + "%, no shelter)"
			else:
				return "→ Reach 70% happiness to become Resident  (currently " + str(pct) + "%)"
		2: # RESIDENT
			if not roamer.is_adult:
				return "→ Still growing up — must be an adult to become Bonded"
			var pct = int(roamer.happiness * 100)
			return "→ Reach 90% happiness to become Bonded  (currently " + str(pct) + "%)"
		3: # BONDED
			return "✓ Fully bonded — ready to breed!"
	return ""

func _get_family_text(roamer) -> String:
	var lines = []

	if roamer.is_adult:
		lines.append("Adult")
	else:
		var pct = int((roamer.grow_up_timer / roamer.grow_up_time) * 100)
		lines.append("Child (" + str(pct) + "% grown)")

	if roamer.family_id != "":
		lines.append("Family ID: " + roamer.family_id.left(12) + "…")

	if roamer.parent_a_id != "" or roamer.parent_b_id != "":
		var parent_names = []
		for r in get_tree().get_nodes_in_group("roamers"):
			if str(r.get_instance_id()) == roamer.parent_a_id or \
			   str(r.get_instance_id()) == roamer.parent_b_id:
				parent_names.append(r.name)
		if parent_names.size() > 0:
			lines.append("Parents: " + ", ".join(parent_names))
		else:
			lines.append("Parents: (no longer in garden)")

	if roamer.is_breeding:
		lines.append("Currently breeding ♥")

	if lines.is_empty():
		return ""
	return "\n".join(lines)

func _make_bar(value: float) -> String:
	var filled = int(value * 10)
	var empty = 10 - filled
	return "[" + "█".repeat(filled) + "░".repeat(empty) + "]"

func get_time_string() -> String:
	return DayNightManager.get_time_string()
