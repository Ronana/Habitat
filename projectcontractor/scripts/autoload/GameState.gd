extends Node
## Central runtime state. All values are plain GDScript types so they
## serialise cleanly to JSON via SaveManager.
## Do NOT store Godot Resource objects here -- keep those in /data/resources/.

# -- Currency ----------------------------------------------------------------
var cash: int = 100
var gems: int = 0

# -- Materials ---------------------------------------------------------------
## Keys: material id (String) -> current inventory count (int).
var materials: Dictionary = {}

# -- Crew --------------------------------------------------------------------
## Each entry is a plain Dictionary:
## { "id", "display_name", "level", "material_type", "base_speed_bonus", "location_id" }
var crew: Array = []

# -- Active build ------------------------------------------------------------
## Tracks the single building currently under construction.
## stage_started: true once materials are consumed and tapping has begun.
var current_building: Dictionary = {
	"tier_id":       "shed",
	"stage_index":   0,
	"stage_progress": 0.0,  # 0.0 -> 1.0 tap progress within the started stage
	"stage_started": false,  # true = materials consumed, tap to build
}

# -- Skyline -----------------------------------------------------------------
## Ordered list of tier_ids for every building ever completed.
var skyline: Array = []

# -- Player progression ------------------------------------------------------
## Player level (Mine Power = player_level × 2).
var player_level: int = 1
## XP accumulated toward the next level.
var player_xp: float = 0.0

# -- Mining ------------------------------------------------------------------
## Which location is currently selected on the Mine screen.
var active_location_id: String = "lumber_yard"
## Per-location node state: { loc_id: { "node_id": String, "hp": float } }
## Persisted so workers continue damaging nodes even while app is closed.
var location_nodes: Dictionary = {}

# -- Upgrades ----------------------------------------------------------------
## Keys: upgrade_id (String) -> purchased level (int, 0 = not bought).
var upgrades: Dictionary = {}

# -- Save metadata -----------------------------------------------------------
var last_saved_timestamp: float = 0.0

# ---------------------------------------------------------------------------
## Derived stat: sum of all hired crew member levels,
## multiplied by the Power Tools upgrade bonus.
func get_build_power() -> int:
	var total := 0
	for member: Dictionary in crew:
		total += int(member.get("level", 1))
	var mult := 1.0 + UpgradeDatabase.get_total_bonus("power_tools", upgrades.get("power_tools", 0))
	return max(int(float(total) * mult), 0)

## Derived stat: damage per tap to ore nodes,
## multiplied by the Sharper Tools upgrade bonus.
func get_mine_power() -> int:
	var base := player_level * 2
	var mult := 1.0 + UpgradeDatabase.get_total_bonus("sharper_tools", upgrades.get("sharper_tools", 0))
	return max(int(float(base) * mult), 1)

## Multiplier applied to worker HP/s from the Quick Crew upgrade.
func get_worker_rate_mult() -> float:
	return 1.0 + UpgradeDatabase.get_total_bonus("quick_crew", upgrades.get("quick_crew", 0))

## Flat bonus drops added per node break from the Bonus Drop upgrade.
func get_drop_bonus() -> int:
	return int(UpgradeDatabase.get_total_bonus("bonus_drop", upgrades.get("bonus_drop", 0)))

## XP multiplier from the XP Rush upgrade.
func get_xp_mult() -> float:
	return 1.0 + UpgradeDatabase.get_total_bonus("xp_rush", upgrades.get("xp_rush", 0))

## Cash multiplier applied to stage completion rewards.
func get_stage_cash_mult() -> float:
	return 1.0 + UpgradeDatabase.get_total_bonus("cash_bonus", upgrades.get("cash_bonus", 0))

## Chance (0.0–1.0) to yield 2× output when crafting.
func get_double_craft_chance() -> float:
	return UpgradeDatabase.get_total_bonus("double_craft", upgrades.get("double_craft", 0))

## Extra build progress multiplier from the Fast Build upgrade.
func get_build_progress_mult() -> float:
	return 1.0 + UpgradeDatabase.get_total_bonus("fast_build", upgrades.get("fast_build", 0))
