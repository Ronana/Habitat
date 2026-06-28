extends Node
## Handles all save/load for Project Contractor.
## Runs load_game() at startup, autosaves every 30 s, and saves on
## app-pause / window-close so no progress is lost on mobile.

const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 30.0

var _autosave_timer: float = 0.0

# ---------------------------------------------------------------------------
func _ready() -> void:
	load_game()

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

# ---------------------------------------------------------------------------
func save_game() -> void:
	var now := Time.get_unix_time_from_system()
	GameState.last_saved_timestamp = now

	var data := {
		"version":               3,
		"cash":                  GameState.cash,
		"gems":                  GameState.gems,
		"materials":             GameState.materials,
		"crew":                  GameState.crew,
		"current_building":      GameState.current_building,
		"skyline":               GameState.skyline,
		"player_level":          GameState.player_level,
		"player_xp":             GameState.player_xp,
		"active_location_id":    GameState.active_location_id,
		"location_nodes":        GameState.location_nodes,
		"upgrades":              GameState.upgrades,
		"last_saved_timestamp":  now,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_error("SaveManager: could not open '%s' for writing (error %d)" \
			% [SAVE_PATH, FileAccess.get_open_error()])

# ---------------------------------------------------------------------------
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_fresh_state()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: could not open '%s' for reading." % SAVE_PATH)
		_init_fresh_state()
		return

	var raw := file.get_as_text()
	file.close()

	var parser := JSON.new()
	if parser.parse(raw) != OK:
		push_error("SaveManager: JSON parse error in save file -- starting fresh.")
		_init_fresh_state()
		return

	var d: Dictionary = parser.get_data()
	GameState.cash                 = d.get("cash", 100)
	GameState.gems                 = d.get("gems", 0)
	GameState.materials            = d.get("materials", {})
	GameState.crew                 = d.get("crew", [])
	GameState.current_building     = d.get("current_building", _default_building())
	GameState.skyline              = d.get("skyline", [])
	GameState.player_level         = int(d.get("player_level", 1))
	GameState.player_xp            = float(d.get("player_xp", 0.0))
	GameState.active_location_id   = d.get("active_location_id", "lumber_yard")
	GameState.last_saved_timestamp = d.get("last_saved_timestamp",
		Time.get_unix_time_from_system())

	# Migrate v1/v2/v3 saves: ensure new fields exist
	if not GameState.current_building.has("stage_started"):
		GameState.current_building["stage_started"] = false
	if not GameState.current_building.has("stage_progress"):
		GameState.current_building["stage_progress"] = 0.0
	GameState.upgrades = d.get("upgrades", {})

	# Migrate crew: add location_id if missing (timber → lumber_yard, stone → stone_quarry)
	for member: Dictionary in GameState.crew:
		if not member.has("location_id") or member["location_id"] == "":
			var mat: String = member.get("material_type", "timber")
			member["location_id"] = "stone_quarry" if mat == "stone" else "lumber_yard"

	# Load location_nodes; fill any missing locations from BuildDatabase defaults
	var saved_nodes: Dictionary = d.get("location_nodes", {})
	var defaults := BuildDatabase.get_default_location_nodes()
	for loc_id: String in defaults.keys():
		if saved_nodes.has(loc_id):
			GameState.location_nodes[loc_id] = saved_nodes[loc_id]
		else:
			GameState.location_nodes[loc_id] = defaults[loc_id]

# ---------------------------------------------------------------------------
func _init_fresh_state() -> void:
	GameState.cash                 = 100
	GameState.gems                 = 0
	GameState.materials            = {}
	GameState.crew                 = []
	GameState.current_building     = _default_building()
	GameState.skyline              = []
	GameState.player_level         = 1
	GameState.player_xp            = 0.0
	GameState.active_location_id   = "lumber_yard"
	GameState.location_nodes       = BuildDatabase.get_default_location_nodes()
	GameState.upgrades             = {}
	GameState.last_saved_timestamp = Time.get_unix_time_from_system()

func _default_building() -> Dictionary:
	return {
		"tier_id":        "shed",
		"stage_index":    0,
		"stage_progress": 0.0,
		"stage_started":  false,
	}
