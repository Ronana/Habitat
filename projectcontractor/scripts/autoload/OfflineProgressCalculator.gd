extends Node
## Called once at startup (after SaveManager.load_game()) to credit the
## materials the player would have gathered while the app was closed.
##
## Autoload order in project.godot MUST be:
##   1. GameState
##   2. BuildDatabase
##   3. SaveManager   (loads persisted state into GameState)
##   4. OfflineProgressCalculator  (reads GameState, applies gains)

## Maximum offline time that will be credited (12 hours).
const MAX_OFFLINE_SECONDS := 43200.0
## Don't bother if less than this many seconds have passed.
const MIN_ELAPSED_SECONDS := 10.0

var _last_gains: Dictionary = {}
var _last_elapsed: float = 0.0

# ---------------------------------------------------------------------------
func _ready() -> void:
	var result := calculate_and_apply()
	_last_gains   = result.gains
	_last_elapsed = result.elapsed
	if not result.gains.is_empty():
		print("OfflineProgressCalculator: +%s after %.0fs offline" \
			% [str(result.gains), result.elapsed])

func get_offline_summary() -> Dictionary:
	return {"gains": _last_gains, "elapsed": _last_elapsed}

func clear_offline_summary() -> void:
	_last_gains   = {}
	_last_elapsed = 0.0

# ---------------------------------------------------------------------------
func calculate_and_apply() -> Dictionary:
	var now     := Time.get_unix_time_from_system()
	var elapsed := minf(now - GameState.last_saved_timestamp, MAX_OFFLINE_SECONDS)

	if elapsed < MIN_ELAPSED_SECONDS:
		return {"gains": {}, "elapsed": elapsed}

	var rates := _get_idle_rates()
	var gains: Dictionary = {}

	for material_id: String in rates:
		var amount := int(rates[material_id] * elapsed)
		if amount > 0:
			gains[material_id] = amount
			GameState.materials[material_id] = \
				GameState.materials.get(material_id, 0) + amount

	GameState.last_saved_timestamp = now
	return {"gains": gains, "elapsed": elapsed}

# ---------------------------------------------------------------------------
## Calculates effective material/s for each hired crew member based on the
## node HP and drop_qty at their assigned location. This matches the online
## mine-tick behaviour (hp_per_s / node_hp × drop_qty = mat_per_s).
func _get_idle_rates() -> Dictionary:
	var rates: Dictionary = {}
	for member: Dictionary in GameState.crew:
		var loc_id: String = member.get("location_id", "lumber_yard")
		var bonus:  float  = float(member.get("base_speed_bonus", 0.1)) \
			* float(member.get("level", 1))
		var hp_per_s := bonus * 4.0

		var loc_data := BuildDatabase.get_location(loc_id)
		if loc_data.is_empty():
			continue
		var mat: String = loc_data.get("material", "timber")

		# Use the node currently active at this location
		var node_state: Dictionary = GameState.location_nodes.get(loc_id, {})
		var node_id: String = node_state.get("node_id", "")
		var node_data := BuildDatabase.get_node_data(node_id)
		if node_data.is_empty():
			# Fallback: use the level-1 node
			node_data = BuildDatabase.get_active_node(loc_id, GameState.player_level)
		if node_data.is_empty():
			continue

		var node_hp:  float = float(node_data.get("hp", 10))
		var drop_qty: int   = int(node_data.get("drop_qty", 1))
		var mat_per_s := (hp_per_s / node_hp) * float(drop_qty)

		rates[mat] = rates.get(mat, 0.0) + mat_per_s
	return rates
