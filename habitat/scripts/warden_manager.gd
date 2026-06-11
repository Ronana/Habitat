extends Node

signal xp_gained(amount, new_total)
signal level_up(new_level)

var current_level: int = 1
var current_xp: float = 0.0
var xp_to_next_level: float = 100.0
var xp_multiplier: float = 1.5

# XP rewards for actions
var xp_rewards = {
	"roamer_appears": 10.0,
	"roamer_visits": 25.0,
	"roamer_resident": 50.0,
	"roamer_bonded": 100.0,
	"roamer_fed": 2.0,
	"roamer_bred": 150.0,
	"soured_restored": 200.0,
	"bush_planted": 5.0,
	"terrain_shaped": 1.0
}

# What unlocks at each level
var level_unlocks = {
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

func gain_xp(action: String):
	if not xp_rewards.has(action):
		print("Unknown action: ", action)
		return
	
	var amount = xp_rewards[action]
	current_xp += amount
	emit_signal("xp_gained", amount, current_xp)
	print("+", amount, " XP for ", action, " (Total: ", current_xp, "/", xp_to_next_level, ")")
	
	check_level_up()

func check_level_up():
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		current_level += 1
		xp_to_next_level = round(xp_to_next_level * xp_multiplier)
		emit_signal("level_up", current_level)
		on_level_up(current_level)

func on_level_up(new_level: int):
	print("🌿 LEVEL UP! You are now Warden Level ", new_level)
	if level_unlocks.has(new_level):
		print("✨ Unlocked: ", level_unlocks[new_level])

# Returns which of the given shop_items array should be visible at the current level.
# Items with no "min_level" key are always available.
func filter_shop_items(all_items: Array) -> Array:
	var result = []
	for item in all_items:
		var min_lvl: int = item.get("min_level", 1)
		if current_level >= min_lvl:
			result.append(item)
	return result

# Returns locked items for display purposes (so the player can see what's coming).
func get_locked_shop_items(all_items: Array) -> Array:
	var result = []
	for item in all_items:
		var min_lvl: int = item.get("min_level", 1)
		if current_level < min_lvl:
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
