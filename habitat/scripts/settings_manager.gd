extends Node

signal settings_changed

const SAVE_PATH := "user://settings.cfg"

var settings: Dictionary = {
	# Camera
	"cam_move_speed":     20.0,
	"cam_zoom_speed":      3.0,
	"cam_pan_speed":       0.05,
	"cam_rotation_speed":  0.3,
	"cam_edge_scroll":     true,
	"cam_invert_y":        false,
	# Audio
	"master_volume":       0.85,
	# Display
	"fullscreen":          false,
}

func _ready():
	_load()
	_apply()

# ── Public API ────────────────────────────────────────────────────────────────

func get_setting(key: String, default = null):
	return settings.get(key, default)

func set_setting(key: String, value) -> void:
	settings[key] = value
	_apply()
	_save()
	emit_signal("settings_changed")

# ── Apply ─────────────────────────────────────────────────────────────────────

func _apply() -> void:
	# Master audio bus
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var vol: float = settings.get("master_volume", 0.85)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamp(vol, 0.001, 1.0)))

	# Display mode
	if settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# ── Persist ───────────────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in settings:
		settings[key] = cfg.get_value("settings", key, settings[key])
