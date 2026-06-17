## ZoneManager — autoload that tracks which garden zones are unlocked.
## Each zone expands the playable half-size; costs Dewdrops to unlock.
extends Node

signal zone_unlocked(zone_index: int)

## Zones ordered smallest → largest.
## "half" = half-width of the square garden at that tier.
const ZONES: Array = [
	{"id": "starter",  "name": "Starter Glade",  "half": 20.0, "cost": 0,   "desc": "Your cosy starting garden."},
	{"id": "glade",    "name": "Outer Glade",     "half": 28.0, "cost": 75,  "desc": "A wider clearing beyond the boundary runes."},
	{"id": "woodland", "name": "Deep Woodland",   "half": 36.0, "cost": 175, "desc": "Ancient trees and hidden mossy pools."},
	{"id": "reach",    "name": "Elder Reach",     "half": 44.0, "cost": 350, "desc": "Where elder creatures roam freely."},
]

var current_zone: int = 0

# ── Queries ───────────────────────────────────────────────────────────────────

func get_garden_half() -> float:
	return float(ZONES[current_zone]["half"])

func is_max_zone() -> bool:
	return current_zone >= ZONES.size() - 1

func get_next_zone() -> Dictionary:
	if is_max_zone():
		return {}
	return ZONES[current_zone + 1]

func can_unlock_next() -> bool:
	if is_max_zone():
		return false
	return CurrencyManager.dewdrops >= float(ZONES[current_zone + 1]["cost"])

# ── Actions ───────────────────────────────────────────────────────────────────

func unlock_next() -> bool:
	if is_max_zone():
		return false
	var next: Dictionary = ZONES[current_zone + 1]
	if CurrencyManager.spend_dewdrops(float(next["cost"])):
		current_zone += 1
		zone_unlocked.emit(current_zone)
		return true
	return false
