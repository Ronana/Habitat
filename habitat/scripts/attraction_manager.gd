extends Node
## AttractionManager — defines per-species visit + resident requirements and
## evaluates them against current world state.
##
## garden.gd calls can_visit() / can_reside() to gate spawning and stage
## transitions.  FieldJournal calls get_visit_status() / get_resident_status()
## to populate the Wildlife tab.

# ── Species data ──────────────────────────────────────────────────────────────

const SPECIES: Dictionary = {
	"GlowFox": {
		"icon":         "🦊",
		"scene":        "res://creatures/glowfox.tscn",
		"max_in_garden": 4,
		"visit_requirements": [
			{"type": "food_min",  "count": 1, "label": "Grow 1 berry bush"},
			{"type": "group_min", "group": "lighting", "count": 1, "label": "Place a light source"},
		],
		"resident_requirements": [
			{"type": "den_for_species", "den_species": "GlowFox",   "label": "Place a GlowFox Den"},
		],
	},
	"Mossdeer": {
		"icon":         "🦌",
		"scene":        "res://creatures/mossdeer.tscn",
		"max_in_garden": 3,
		"visit_requirements": [
			{"type": "food_min",  "count": 3, "label": "Grow 3 berry bushes"},
			{"type": "group_min", "group": "trees", "count": 1, "label": "Have at least 1 tree"},
		],
		"resident_requirements": [
			{"type": "den_for_species", "den_species": "Mossdeer",  "label": "Place a MossDeer Hollow"},
		],
	},
	"Stoneback": {
		"icon":         "🐢",
		"scene":        "res://creatures/stoneback.tscn",
		"max_in_garden": 2,
		"visit_requirements": [
			{"type": "group_min",  "group": "decoratives", "count": 3, "label": "Place 3 decorations"},
			{"type": "roamer_min", "count": 2, "label": "Have 2 other roamers visiting"},
		],
		"resident_requirements": [
			{"type": "den_for_species", "den_species": "Stoneback", "label": "Place a Stoneback Cave"},
		],
	},
	"Thornmouse": {
		"icon":         "🐭",
		"scene":        "res://creatures/thornmouse.tscn",
		"max_in_garden": 5,
		"visit_requirements": [
			{"type": "food_min",  "count": 2, "label": "Grow 2 berry bushes"},
			{"type": "group_min", "group": "debris", "count": 2, "label": "Have 2 wildgrass patches"},
		],
		"resident_requirements": [
			{"type": "den_for_species", "den_species": "Thornmouse", "label": "Place a Thornmouse Burrow"},
		],
	},
	"Emberowl": {
		"icon":         "🦉",
		"scene":        "res://creatures/emberowl.tscn",
		"max_in_garden": 3,
		"visit_requirements": [
			{"type": "group_min", "group": "trees",    "count": 2, "label": "Have at least 2 trees"},
			{"type": "group_min", "group": "lighting", "count": 1, "label": "Place a light source"},
		],
		"resident_requirements": [
			{"type": "den_for_species", "den_species": "Emberowl", "label": "Place an Emberowl Roost"},
		],
	},
	"Crystalback": {
		"icon":         "💎",
		"scene":        "res://creatures/crystalback.tscn",
		"max_in_garden": 2,
		"visit_requirements": [
			{"type": "group_min",  "group": "decoratives", "count": 5, "label": "Place 5 decorations"},
			{"type": "roamer_min", "count": 3, "label": "Have 3 other roamers visiting"},
		],
		"resident_requirements": [
			{"type": "den_for_species", "den_species": "Crystalback", "label": "Place a Crystalback Grotto"},
		],
	},
}

# ── Public API ────────────────────────────────────────────────────────────────

## True when every visit requirement for species_id is met.
func can_visit(species_id: String) -> bool:
	if not SPECIES.has(species_id):
		return false
	for req in SPECIES[species_id]["visit_requirements"]:
		if not _check_req(req):
			return false
	return true

## True when the species-specific den exists and can accept the given roamer.
## Pass roamer=null to check without a specific roamer in mind.
func can_reside(species_id: String, roamer = null) -> bool:
	if not SPECIES.has(species_id):
		return false
	for req in SPECIES[species_id]["resident_requirements"]:
		if not _check_req(req, roamer):
			return false
	return true

## Returns Array[{label, met}] for each visit requirement.
func get_visit_status(species_id: String) -> Array:
	var out: Array = []
	if not SPECIES.has(species_id):
		return out
	for req in SPECIES[species_id]["visit_requirements"]:
		out.append({"label": req["label"], "met": _check_req(req)})
	return out

## Returns Array[{label, met}] for each resident requirement.
func get_resident_status(species_id: String) -> Array:
	var out: Array = []
	if not SPECIES.has(species_id):
		return out
	for req in SPECIES[species_id]["resident_requirements"]:
		out.append({"label": req["label"], "met": _check_req(req)})
	return out

## How many of this species are currently in the garden.
func count_in_garden(species_id: String) -> int:
	var n := 0
	for r in get_tree().get_nodes_in_group("roamers"):
		if r.species_id == species_id:
			n += 1
	return n

## True when the garden is at or above the population cap for this species.
func is_at_cap(species_id: String) -> bool:
	if not SPECIES.has(species_id):
		return false
	return count_in_garden(species_id) >= SPECIES[species_id]["max_in_garden"]

# ── Requirement evaluator ─────────────────────────────────────────────────────

func _check_req(req: Dictionary, roamer = null) -> bool:
	match req["type"]:
		"food_min":
			return get_tree().get_nodes_in_group("food").size() >= req["count"]

		"group_min":
			# "decoratives" group includes fences + decorative items but NOT shelters/trees.
			# We exclude fences so only actual decorative items count for Stoneback.
			var grp: String = req["group"]
			if grp == "decoratives":
				var non_fence := 0
				for n in get_tree().get_nodes_in_group("decoratives"):
					if not n.is_in_group("fences"):
						non_fence += 1
				return non_fence >= req["count"]
			return get_tree().get_nodes_in_group(grp).size() >= req["count"]

		"roamer_min":
			return get_tree().get_nodes_in_group("roamers").size() >= req["count"]

		"den_for_species":
			for shelter in get_tree().get_nodes_in_group("shelters"):
				if shelter.locked_species == req["den_species"]:
					if roamer == null or shelter.can_accept(roamer):
						return true
			return false

	return false
