extends Node
## Defines all purchasable upgrades for Project Contractor.
## Upgrades unlock at player level gates, scale with levels 1→max,
## and are purchased with materials or cash (exponential cost per level).
##
## Autoload order: after BuildDatabase, before Main.

## All upgrades in unlock-level order.
## Fields:
##   id            : String   — unique key (also used in GameState.upgrades)
##   name          : String   — display name
##   description   : String   — one-line effect description
##   max_level     : int      — levels purchasable (1..max_level)
##   unlock_level  : int      — player level required to see/buy
##   effect        : String   — effect type tag (read by GameState helpers)
##   bonus         : float    — bonus per level (fractional where applicable)
##   base_cost     : Dictionary  — {mat_id: amount} for level 1 purchase
##                                 level N cost = base_cost[mat] * 2^(N-1)

const UPGRADES: Array[Dictionary] = [
	{
		"id":           "sharper_tools",
		"name":         "Sharper Tools",
		"description":  "+10% Mine Power per level",
		"max_level":    5,
		"unlock_level": 1,
		"effect":       "mine_power_pct",
		"bonus":        0.10,
		"base_cost":    {"timber": 20},
	},
	{
		"id":           "cash_bonus",
		"name":         "Cash Bonus",
		"description":  "+10% cash reward per stage per level",
		"max_level":    5,
		"unlock_level": 2,
		"effect":       "stage_cash_pct",
		"bonus":        0.10,
		"base_cost":    {"cash": 30},
	},
	{
		"id":           "quick_crew",
		"name":         "Quick Crew",
		"description":  "+8% worker HP/s per level",
		"max_level":    5,
		"unlock_level": 3,
		"effect":       "worker_rate_pct",
		"bonus":        0.08,
		"base_cost":    {"stone": 20},
	},
	{
		"id":           "power_tools",
		"name":         "Power Tools",
		"description":  "+10% Build Power per level",
		"max_level":    5,
		"unlock_level": 4,
		"effect":       "build_power_pct",
		"bonus":        0.10,
		"base_cost":    {"lumber": 10},
	},
	{
		"id":           "bonus_drop",
		"name":         "Bonus Drop",
		"description":  "+1 material per node break per level",
		"max_level":    3,
		"unlock_level": 5,
		"effect":       "drop_bonus",
		"bonus":        1.0,
		"base_cost":    {"timber": 40},
	},
	{
		"id":           "xp_rush",
		"name":         "XP Rush",
		"description":  "+15% XP per node break per level",
		"max_level":    5,
		"unlock_level": 6,
		"effect":       "xp_pct",
		"bonus":        0.15,
		"base_cost":    {"timber": 30, "stone": 30},
	},
	{
		"id":           "double_craft",
		"name":         "Double Craft",
		"description":  "+5% chance to yield 2x when crafting per level",
		"max_level":    5,
		"unlock_level": 8,
		"effect":       "double_craft_chance",
		"bonus":        0.05,
		"base_cost":    {"lumber": 15},
	},
	{
		"id":           "fast_build",
		"name":         "Fast Build",
		"description":  "+5% build progress per tap per level",
		"max_level":    3,
		"unlock_level": 10,
		"effect":       "build_progress_pct",
		"bonus":        0.05,
		"base_cost":    {"concrete": 10},
	},
]

# ── Public API ─────────────────────────────────────────────────────────────

## Returns all upgrade definitions.
func get_all() -> Array[Dictionary]:
	return UPGRADES

## Returns a single upgrade definition by id, or {}.
func get_upgrade(id: String) -> Dictionary:
	for u: Dictionary in UPGRADES:
		if u["id"] == id:
			return u
	return {}

## Returns the cost to purchase the NEXT level of an upgrade.
## level is the player's CURRENT level in that upgrade (0 = not bought yet).
## Cost = base_cost[mat] × 2^current_level  (exponential per level)
func get_cost(upgrade_id: String, current_level: int) -> Dictionary:
	var u := get_upgrade(upgrade_id)
	if u.is_empty():
		return {}
	var result: Dictionary = {}
	for mat: String in u["base_cost"]:
		var base: int = int(u["base_cost"][mat])
		result[mat] = base * int(pow(2.0, float(current_level)))
	return result

## Returns the total bonus value at a given level (bonus × level).
func get_total_bonus(upgrade_id: String, level: int) -> float:
	var u := get_upgrade(upgrade_id)
	if u.is_empty():
		return 0.0
	return float(u["bonus"]) * float(level)

## Returns all upgrades available to a player of the given level.
func get_available(player_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for u: Dictionary in UPGRADES:
		if int(u["unlock_level"]) <= player_level:
			result.append(u)
	return result
