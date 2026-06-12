## PrestigeManager — computes a live garden prestige score.
## Add as autoload in project.godot.
extends Node

signal score_changed(new_score: int)

var current_score: int = 0
var _poll_timer: float = 0.0
const POLL_INTERVAL: float = 3.0  # recalculate every 3 seconds

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		var new_score := compute_score()
		if new_score != current_score:
			current_score = new_score
			emit_signal("score_changed", current_score)

func compute_score() -> int:
	var tree := get_tree()
	if not tree:
		return 0
	var score := 0

	# ── Roamers ──────────────────────────────────────────────────────────────
	var roamers := tree.get_nodes_in_group("roamers")
	var species_seen: Array = []
	for r in roamers:
		score += 10  # base per roamer
		if r.attraction_stage == 3:   # BONDED
			score += 25
		elif r.attraction_stage == 2: # RESIDENT
			score += 10
		if r.happiness >= 0.8:
			score += 5
		var sid: String = r.species_id if r.species_id != "" else r.name
		if sid not in species_seen:
			species_seen.append(sid)
			score += 20  # diversity bonus per unique species

	# ── Items ─────────────────────────────────────────────────────────────────
	score += tree.get_nodes_in_group("shelters").size()    * 8
	score += tree.get_nodes_in_group("food").size()        * 4
	score += tree.get_nodes_in_group("decoratives").size() * 3

	# ── Season bonus ──────────────────────────────────────────────────────────
	var season := SeasonManager.current_season
	if season == SeasonManager.Season.SPRING or season == SeasonManager.Season.SUMMER:
		score += 10

	# ── Warden level bonus ────────────────────────────────────────────────────
	score += WardenManager.current_level * 2

	return score

func get_rank() -> String:
	if current_score < 50:
		return "Budding Garden"
	elif current_score < 150:
		return "Cosy Hollow"
	elif current_score < 300:
		return "Wild Sanctuary"
	elif current_score < 500:
		return "Thriving Haven"
	elif current_score < 800:
		return "Ancient Grove"
	else:
		return "Legendary Refuge"
