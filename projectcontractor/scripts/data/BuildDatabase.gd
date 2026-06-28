extends Node
## Static game data: building tier definitions + mining location definitions.
## Provides data to the build loop and mine loop at runtime.
##
## Autoload order: can live anywhere after GameState.

## Ordered tier progression for MVP (Shed -> Single House -> Two-Story House).
const TIER_ORDER: Array[String] = ["shed", "single_house", "two_story_house"]

## Ordered location progression for MVP (unlocked gradually).
const LOCATION_ORDER: Array[String] = ["lumber_yard", "stone_quarry"]

var _tiers: Dictionary = {}
var _crew_templates: Array[CrewMemberResource] = []
var _locations: Dictionary = {}

# ---------------------------------------------------------------------------
func _ready() -> void:
	_register_shed()
	_register_single_house()
	_register_two_story_house()
	_register_crew()
	_register_locations()

# ── Public API — Tiers ──────────────────────────────────────────────────────

func get_tier(tier_id: String) -> BuildingTierResource:
	return _tiers.get(tier_id, null)

## Returns the BuildStageResource for the stage the player is currently on,
## or null if the tier is complete.
func get_current_stage() -> BuildStageResource:
	var tier_id: String = GameState.current_building.get("tier_id", "shed")
	var tier := get_tier(tier_id)
	if not tier:
		return null
	var idx: int = int(GameState.current_building.get("stage_index", 0))
	if idx < 0 or idx >= tier.stages.size():
		return null
	return tier.stages[idx]

## Returns the next tier id after current_tier_id, or "" if at the last tier.
func get_next_tier_id(current_tier_id: String) -> String:
	var idx := TIER_ORDER.find(current_tier_id)
	if idx < 0 or idx >= TIER_ORDER.size() - 1:
		return ""
	return TIER_ORDER[idx + 1]

# ── Public API — Locations & Nodes ─────────────────────────────────────────

## Returns location data dict or {} if not found.
func get_location(loc_id: String) -> Dictionary:
	return _locations.get(loc_id, {})

## Returns the best unlocked node for a location at the given player level,
## or {} if the location doesn't exist.
func get_active_node(loc_id: String, player_level: int) -> Dictionary:
	var loc: Dictionary = _locations.get(loc_id, {})
	if loc.is_empty():
		return {}
	var best: Dictionary = {}
	for node: Dictionary in loc.get("nodes", []):
		if int(node.get("unlock_level", 1)) <= player_level:
			best = node
	return best

## Looks up a node dict by its string id across all locations.
func get_node_data(node_id: String) -> Dictionary:
	for loc: Dictionary in _locations.values():
		for node: Dictionary in loc.get("nodes", []):
			if node.get("id", "") == node_id:
				return node
	return {}

## XP required to advance from player_level → player_level+1.
## Formula: round(50 × 1.6^(level-1))  → L1:50  L2:80  L3:128  L4:205  L5:328…
func get_xp_needed(player_level: int) -> float:
	return round(50.0 * pow(1.6, float(player_level - 1)))

## Returns the starting location_nodes dict for a fresh save.
## Called by SaveManager._init_fresh_state().
func get_default_location_nodes() -> Dictionary:
	var result: Dictionary = {}
	for loc_id: String in LOCATION_ORDER:
		var first_node := get_active_node(loc_id, 1)
		if not first_node.is_empty():
			result[loc_id] = {
				"node_id": first_node.get("id", ""),
				"hp":      float(first_node.get("hp", 10))
			}
	return result

## Returns the full list of crew members available to hire.
func get_hireable_crew() -> Array[CrewMemberResource]:
	return _crew_templates

# ── Tier registration ───────────────────────────────────────────────────────

func _register_shed() -> void:
	var shed := BuildingTierResource.new()
	shed.id = "shed"
	shed.display_name = "Garden Shed"
	shed.build_power_required = 0
	shed.unlock_condition = "none"
	shed.stages = [
		_stage("shed_clearance",   "Site Clearance & Groundworks",
			{"timber": 20},                     0),
		_stage("shed_foundations", "Foundations & Base",
			{"stone": 30, "timber": 10},         1),
		_stage("shed_framing",     "Wall Framing & Sheathing",
			{"timber": 40, "stone": 10},         2),
		_stage("shed_finish",      "Roof, Door & Snagging",
			{"timber": 20, "stone": 15},         3),
	]
	_tiers["shed"] = shed

func _register_single_house() -> void:
	var h := BuildingTierResource.new()
	h.id = "single_house"
	h.display_name = "Single-Storey House"
	h.build_power_required = 3
	h.unlock_condition = "build_power"
	h.stages = [
		_stage("sh_clearance",   "Site Clearance & Groundworks",
			{"timber": 40, "stone": 25},           0),
		_stage("sh_foundations", "Foundations & Footings",
			{"concrete": 20, "stone": 15},         1),
		_stage("sh_framing",     "Ground Floor Framing",
			{"lumber": 35, "concrete": 10},        2),
		_stage("sh_sheathing",   "Wall Sheathing & Roof",
			{"lumber": 50, "concrete": 20},        3),
		_stage("sh_finish",      "Snagging & Handover",
			{"lumber": 25, "concrete": 15},        4),
	]
	_tiers["single_house"] = h

func _register_two_story_house() -> void:
	var h := BuildingTierResource.new()
	h.id = "two_story_house"
	h.display_name = "Two-Storey House"
	h.build_power_required = 8
	h.unlock_condition = "build_power"
	h.stages = [
		_stage("th_clearance",   "Site Clearance & Groundworks",
			{"timber": 50, "stone": 35},           0),
		_stage("th_foundations", "Foundations",
			{"concrete": 35, "stone": 20},          1),
		_stage("th_gf_framing",  "Ground Floor Framing",
			{"lumber": 50, "concrete": 25},         2),
		_stage("th_ff_roof",     "First Floor, Joists & Roof",
			{"lumber": 70, "concrete": 35},         3),
		_stage("th_finish",      "Windows, Doors & Snagging",
			{"lumber": 40, "concrete": 25},         4),
	]
	_tiers["two_story_house"] = h

# ── Location registration ────────────────────────────────────────────────────
## Node HP/XP scaled similarly to IOM ore system.
## HP starts at 10 (Sapling / Pebble) and scales with unlock_level.
## Mine Power = player_level × 2, so level-appropriate nodes take ~5 taps.

func _register_locations() -> void:
	_locations["lumber_yard"] = {
		"display_name": "Lumber Yard",
		"material":     "timber",
		"unlock_level": 1,
		"nodes": [
			{"id": "sapling",  "name": "Sapling",  "hp": 10,  "drop_qty": 1, "xp": 2,  "unlock_level": 1},
			{"id": "pine_log", "name": "Pine Log",  "hp": 30,  "drop_qty": 2, "xp": 6,  "unlock_level": 3},
			{"id": "oak_log",  "name": "Oak Log",   "hp": 80,  "drop_qty": 3, "xp": 15, "unlock_level": 6},
			{"id": "hardwood", "name": "Hardwood",  "hp": 200, "drop_qty": 5, "xp": 35, "unlock_level": 10},
		]
	}
	_locations["stone_quarry"] = {
		"display_name": "Stone Quarry",
		"material":     "stone",
		"unlock_level": 1,
		"nodes": [
			{"id": "pebble",  "name": "Pebble",  "hp": 10,  "drop_qty": 1, "xp": 2,  "unlock_level": 1},
			{"id": "cobble",  "name": "Cobble",  "hp": 30,  "drop_qty": 2, "xp": 6,  "unlock_level": 3},
			{"id": "boulder", "name": "Boulder", "hp": 80,  "drop_qty": 3, "xp": 15, "unlock_level": 6},
			{"id": "granite", "name": "Granite", "hp": 200, "drop_qty": 5, "xp": 35, "unlock_level": 10},
		]
	}

# ── Crew registration ────────────────────────────────────────────────────────
## base_speed_bonus: material/s at level 1.
## Converted to HP/s in Main.gd: hp_per_s = bonus × level × 4.

func _register_crew() -> void:
	_crew_templates = [
		_crew("old_bob",      "Old Bob",      "timber", "lumber_yard",  40,  0.5),
		_crew("granite_pete", "Granite Pete", "stone",  "stone_quarry", 75,  1.0),
		_crew("nimble_nick",  "Nimble Nick",  "timber", "lumber_yard",  90,  1.0),
	]

func _crew(id: String, crew_name: String, mat: String, loc: String, cost: int, bonus: float) -> CrewMemberResource:
	var c := CrewMemberResource.new()
	c.id               = id
	c.display_name     = crew_name
	c.material_type    = mat
	c.location_id      = loc
	c.hire_cost        = cost
	c.base_speed_bonus = bonus
	c.level            = 1
	return c

# ── Factory helpers ─────────────────────────────────────────────────────────

func _stage(id: String, stage_name: String, mats: Dictionary, order: int) -> BuildStageResource:
	var s := BuildStageResource.new()
	s.id = id
	s.display_name = stage_name
	s.required_materials = mats
	s.stage_order = order
	return s
