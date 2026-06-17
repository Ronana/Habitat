extends Node

signal xp_gained(amount, new_total)
signal level_up(new_level)

var current_level: int = 1
var current_xp: float = 0.0
var xp_to_next_level: float = 100.0
var xp_multiplier: float = 1.5

# XP rewards for actions
var xp_rewards: Dictionary = {
	"roamer_appears":    10.0,
	"roamer_visits":     25.0,
	"roamer_resident":   50.0,
	"roamer_bonded":    100.0,
	"roamer_interacted":  5.0,
	"zone_unlocked":     50.0,
	"roamer_fed":         2.0,
	"roamer_bred":      150.0,
	"egg_laid":         150.0,  # alias used by roamer_base
	"egg_hatched":       30.0,
	"objective_complete": 20.0,
	"soured_restored":  200.0,
	"bush_planted":       5.0,
	"terrain_shaped":     1.0,
	"shelter_placed":    15.0,
	"decor_placed":       3.0,
	"season_advance":     5.0,
	"item_purchased":      2.0,
}

# What unlocks at each level
var level_unlocks: Dictionary = {
	2:  "Maren's shop expanded — Wildgrass Seeds available",
	5:  "Terrain tool upgraded — larger radius",
	10: "Old Cob the Tool Trader arrives",
	15: "Wetland biome unlocked",
	20: "Breeding system fully unlocked",
	25: "Rare Roamer appearances begin",
	30: "Meadow biome unlocked",
	40: "Soured Roamers begin appearing",
	50: "Elder variants begin appearing",
}

func gain_xp(action: String) -> void:
	if not xp_rewards.has(action):
		push_warning("WardenManager: unknown XP action '%s'" % action)
		return
	var amount: float = xp_rewards[action]
	current_xp += amount
	xp_gained.emit(amount, current_xp)
	check_level_up()

func check_level_up() -> void:
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		current_level += 1
		xp_to_next_level = round(xp_to_next_level * xp_multiplier)
		level_up.emit(current_level)
		on_level_up(current_level)

func on_level_up(_new_level: int) -> void:
	pass

## Returns items visible to the player at the current warden level.
func filter_shop_items(all_items: Array) -> Array:
	var result: Array = []
	for item: Dictionary in all_items:
		if current_level >= int(item.get("min_level", 1)):
			result.append(item)
	return result

## Returns items not yet unlocked — shown greyed out in the shop.
func get_locked_shop_items(all_items: Array) -> Array:
	var result: Array = []
	for item: Dictionary in all_items:
		if current_level < int(item.get("min_level", 1)):
			result.append(item)
	return result

func get_level_progress() -> float:
	return current_xp / xp_to_next_level

func get_title() -> String:
	if current_level < 5:
		return "Apprentice Warden"
	elif current_level < 15:
		return "Warden"
	elif current_level < 30:
		return "Senior Warden"
	elif current_level < 50:
		return "Master Warden"
	else:
		return "Grand Warden"
