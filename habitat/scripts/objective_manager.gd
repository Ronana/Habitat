## ObjectiveManager — autoload that tracks Maren's active objectives.
## Objectives are picked from a pool and up to 3 are active at once.
## Completing one grants dewdrops and replaces it with a new one.
extends Node

signal objective_completed(obj: Dictionary)
signal objectives_updated

const MAX_ACTIVE := 3
const SAVE_PATH  := "user://objectives.cfg"

# ── Objective pool ────────────────────────────────────────────────────────────
# Each entry: id, desc, reward (dewdrops), condition_type, condition_value
# condition_type matches what _check_condition() evaluates.
const POOL: Array = [
	{"id": "attract_1",    "desc": "Attract your first wild Roamer",          "reward": 30,  "type": "roamers_total",   "value": 1  },
	{"id": "attract_3",    "desc": "Have 3 Roamers in your garden",           "reward": 50,  "type": "roamers_total",   "value": 3  },
	{"id": "attract_5",    "desc": "Have 5 Roamers in your garden",           "reward": 80,  "type": "roamers_total",   "value": 5  },
	{"id": "resident_1",   "desc": "Help a Roamer become a Resident",         "reward": 45,  "type": "residents",       "value": 1  },
	{"id": "resident_3",   "desc": "Have 3 Residents in your garden",         "reward": 90,  "type": "residents",       "value": 3  },
	{"id": "bonded_1",     "desc": "Bond your first Roamer",                  "reward": 75,  "type": "bonded",          "value": 1  },
	{"id": "bonded_2",     "desc": "Have 2 Bonded Roamers",                   "reward": 120, "type": "bonded",          "value": 2  },
	{"id": "breed_1",      "desc": "Breed a pair of Roamers",                 "reward": 60,  "type": "eggs_hatched",    "value": 1  },
	{"id": "breed_3",      "desc": "Hatch 3 eggs",                            "reward": 100, "type": "eggs_hatched",    "value": 3  },
	{"id": "food_3",       "desc": "Plant 3 Berry Bushes",                    "reward": 25,  "type": "food_count",      "value": 3  },
	{"id": "shelter_1",    "desc": "Place a shelter for your Roamers",        "reward": 30,  "type": "shelter_count",   "value": 1  },
	{"id": "shelter_3",    "desc": "Have 3 shelters in your garden",          "reward": 55,  "type": "shelter_count",   "value": 3  },
	{"id": "decor_3",      "desc": "Place 3 decorative items",                "reward": 20,  "type": "decor_count",     "value": 3  },
	{"id": "decor_5",      "desc": "Place 5 decorative items",                "reward": 35,  "type": "decor_count",     "value": 5  },
	{"id": "light_2",      "desc": "Place 2 lighting objects",                "reward": 30,  "type": "light_count",     "value": 2  },
	{"id": "happy_all",    "desc": "Have all Roamers above 70% happiness",    "reward": 65,  "type": "all_happy",       "value": 0.7},
	{"id": "dewdrops_100", "desc": "Earn 100 Dewdrops total",                 "reward": 15,  "type": "dewdrops_earned", "value": 100},
	{"id": "dewdrops_500", "desc": "Earn 500 Dewdrops total",                 "reward": 40,  "type": "dewdrops_earned", "value": 500},
	{"id": "name_roamer",  "desc": "Give a Roamer a custom name",             "reward": 15,  "type": "named_roamers",   "value": 1  },
	{"id": "traits_2",     "desc": "Have 2 Roamers with the Radiant trait",   "reward": 50,  "type": "trait_count",     "value": 2, "trait": "radiant"},
]

var active_objectives: Array = []        # Array of cloned pool entries
var completed_ids: Array  = []           # IDs of all ever-completed objectives
var dewdrops_earned: float = 0.0         # running total for dewdrops objectives
var eggs_hatched:   int   = 0            # running total

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready():
	_load()
	if active_objectives.is_empty():
		_fill_active()
	CurrencyManager.dewdrops_changed.connect(_on_dewdrops_changed)

func _on_dewdrops_changed(new_val: float):
	# We can't track the delta directly; just poll periodically in _process
	pass

func _process(_delta):
	_check_all()

# ── Public ────────────────────────────────────────────────────────────────────

## Call this from egg.gd when an egg hatches.
func record_hatch():
	eggs_hatched += 1

## Call this when a roamer is renamed.
func record_rename():
	pass  # naming is evaluated by counting named roamers in _check_condition

# ── Internal ──────────────────────────────────────────────────────────────────

func _fill_active():
	var available := POOL.filter(func(e): return not completed_ids.has(e["id"]) \
		and not active_objectives.any(func(a): return a["id"] == e["id"]))
	available.shuffle()
	while active_objectives.size() < MAX_ACTIVE and not available.is_empty():
		active_objectives.append(available.pop_front().duplicate())
	emit_signal("objectives_updated")

func _check_all():
	var changed := false
	for obj in active_objectives.duplicate():
		if _check_condition(obj):
			_complete(obj)
			changed = true
	if changed:
		_fill_active()
		_save()

func _complete(obj: Dictionary):
	active_objectives.erase(obj)
	completed_ids.append(obj["id"])
	var reward: float = float(obj.get("reward", 0))
	CurrencyManager.add_dewdrops(reward)
	WardenManager.gain_xp("objective_complete")
	emit_signal("objective_completed", obj)

func _check_condition(obj: Dictionary) -> bool:
	var tree := get_tree()
	if not tree:
		return false
	var roamers := tree.get_nodes_in_group("roamers")
	match obj["type"]:
		"roamers_total":
			return roamers.size() >= int(obj["value"])
		"residents":
			var count := 0
			for r in roamers:
				if r.attraction_stage >= 2:
					count += 1
			return count >= int(obj["value"])
		"bonded":
			var count := 0
			for r in roamers:
				if r.attraction_stage == 3:
					count += 1
			return count >= int(obj["value"])
		"eggs_hatched":
			return eggs_hatched >= int(obj["value"])
		"food_count":
			return tree.get_nodes_in_group("food").size() >= int(obj["value"])
		"shelter_count":
			return tree.get_nodes_in_group("shelters").size() >= int(obj["value"])
		"decor_count":
			return tree.get_nodes_in_group("decoratives").size() >= int(obj["value"])
		"light_count":
			var lights := tree.get_nodes_in_group("decoratives").filter(
				func(n): return n.scene_file_path.contains("lantern") \
					or n.scene_file_path.contains("mushroom") \
					or n.scene_file_path.contains("firefly") \
					or n.scene_file_path.contains("torch"))
			return lights.size() >= int(obj["value"])
		"all_happy":
			if roamers.is_empty():
				return false
			for r in roamers:
				if r.happiness < float(obj["value"]):
					return false
			return true
		"dewdrops_earned":
			return CurrencyManager.dewdrops >= float(obj["value"])
		"named_roamers":
			var count := 0
			for r in roamers:
				if r.roamer_name != "" and r.roamer_name != r.name:
					count += 1
			return count >= int(obj["value"])
		"trait_count":
			var target_trait: String = obj.get("trait", "")
			var count := 0
			for r in roamers:
				if target_trait in r.traits:
					count += 1
			return count >= int(obj["value"])
	return false

# ── Persistence ───────────────────────────────────────────────────────────────

func _save():
	var cfg := ConfigFile.new()
	cfg.set_value("state", "completed_ids", completed_ids)
	cfg.set_value("state", "eggs_hatched",  eggs_hatched)
	# Active objectives serialised as JSON strings
	var active_json := []
	for obj in active_objectives:
		active_json.append(JSON.stringify(obj))
	cfg.set_value("state", "active", active_json)
	cfg.save(SAVE_PATH)

func _load():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	completed_ids  = cfg.get_value("state", "completed_ids", [])
	eggs_hatched   = cfg.get_value("state", "eggs_hatched",  0)
	var active_json: Array = cfg.get_value("state", "active", [])
	active_objectives.clear()
	for s in active_json:
		var parsed = JSON.parse_string(s)
		if parsed is Dictionary:
			active_objectives.append(parsed)

func save_to_main():
	_save()

func load_from_main():
	_load()
	if active_objectives.is_empty():
		_fill_active()
