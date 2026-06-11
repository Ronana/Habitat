extends Node

signal milestone_achieved(title: String, subtitle: String)

# Persisted across save/load by save_manager.gd
var achieved: Dictionary = {}

# Call this whenever a milestone condition is met.
# Safe to call repeatedly — fires only once per key.
func fire(key: String, title: String, subtitle: String):
	if achieved.has(key):
		return
	achieved[key] = true
	emit_signal("milestone_achieved", title, subtitle)
	print("🏆 Milestone: ", title)
