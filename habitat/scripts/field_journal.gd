extends CanvasLayer

@onready var journal_panel = $JournalPanel
@onready var roamer_list = $JournalPanel/HBoxContainer/LeftPanel/ScrollContainer/RoamerList
@onready var entry_name = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryName
@onready var entry_stage = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryStage
@onready var entry_happiness = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/EntryHappiness
@onready var needs_detail = $JournalPanel/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer/NeedsDetail
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
		discover_roamer(roamer.name)
		var btn = Button.new()
		btn.text = roamer.name
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_roamer_selected.bind(roamer))
		roamer_list.add_child(btn)
		print("Added button for: ", roamer.name)
		
	

func _on_roamer_selected(roamer):
	var stage_names = ["Appears", "Visits", "Resident", "Bonded"]
	entry_name.text = "🦊 " + roamer.name
	entry_stage.text = "Stage: " + stage_names[roamer.attraction_stage]
	entry_happiness.text = "Happiness: " + str(int(roamer.happiness * 100)) + "%"

	# Build needs string
	var needs_text = ""
	for need in roamer.needs:
		var bar = _make_bar(roamer.needs[need])
		needs_text += need.capitalize() + ": " + bar + " " + str(int(roamer.needs[need] * 100)) + "%\n"
	needs_detail.text = needs_text

	# Discovery notes
	if roamer_discovery_notes.has(roamer.name):
		discovery_detail.text = roamer_discovery_notes[roamer.name]
	else:
		discovery_detail.text = "Still learning about this creature..."

	# Warden tips
	if roamer_tips.has(roamer.name):
		tips_detail.text = roamer_tips[roamer.name]
	else:
		tips_detail.text = "Keep observing to learn more."

func _make_bar(value: float) -> String:
	var filled = int(value * 10)
	var empty = 10 - filled
	return "[" + "█".repeat(filled) + "░".repeat(empty) + "]"

func get_time_string() -> String:
	return DayNightManager.get_time_string()
