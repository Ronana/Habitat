extends Node

signal settings_changed

const SAVE_PATH := "user://settings.cfg"

# ── Default settings ──────────────────────────────────────────────────────────
var settings: Dictionary = {
	# Camera
	"cam_move_speed":      20.0,
	"cam_zoom_speed":       3.0,
	"cam_pan_speed":        0.05,
	"cam_rotation_speed":   0.3,
	"cam_edge_scroll":      true,
	"cam_invert_y":         false,
	# Audio (per-bus, 0.0–1.0)
	"master_volume":        0.85,
	"music_volume":         0.80,
	"sfx_volume":           0.90,
	"ambient_volume":       0.85,
	"ui_volume":            0.70,
	# Graphics
	"shadow_quality":       2,      # 0=Off 1=Low 2=Medium 3=High
	"anti_aliasing":        1,      # 0=None 1=FXAA 2=TAA
	"bloom_enabled":        true,
	"volumetric_fog":       true,
	"ambient_occlusion":    false,
	"particle_density":     1.0,    # 0.0–1.0
	"render_scale":         1.0,    # 0.5–1.5
	"vsync":                true,
	"framerate_cap":        0,      # 0=Unlimited 30 60 120 144
	# Display
	"fullscreen":           false,
	# Accessibility / HUD
	"ui_scale":             1.0,
	"hud_scale":            1.0,
	"hud_opacity":          1.0,
	"high_contrast":        false,
	"colorblind_mode":      0,      # 0=None 1=Protanopia 2=Deuteranopia 3=Tritanopia
	"reduced_motion":       false,
	"large_text":           false,
	"show_fps":             false,
	"show_clock":           true,
}

# ── Rebindable actions — action_id : display name ─────────────────────────────
const REBINDABLE_ACTIONS: Dictionary = {
	"cam_forward":       "Camera Forward",
	"cam_back":          "Camera Back",
	"cam_left":          "Camera Left",
	"cam_right":         "Camera Right",
	"cam_rotate_cw":     "Rotate Camera CW",
	"cam_rotate_ccw":    "Rotate Camera CCW",
	"interact":          "Interact / Select",
	"cancel":            "Cancel / Deselect",
	"open_journal":      "Field Journal",
	"open_shop":         "Shop",
	"toggle_freecam":    "Free Camera",
	"time_speed":        "Speed Up Time",
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
	settings_changed.emit()

func apply_quality_preset(preset: String) -> void:
	match preset:
		"Low":
			settings["shadow_quality"]    = 0
			settings["anti_aliasing"]     = 0
			settings["bloom_enabled"]     = false
			settings["volumetric_fog"]    = false
			settings["ambient_occlusion"] = false
			settings["particle_density"]  = 0.3
			settings["render_scale"]      = 0.75
		"Medium":
			settings["shadow_quality"]    = 1
			settings["anti_aliasing"]     = 1
			settings["bloom_enabled"]     = true
			settings["volumetric_fog"]    = false
			settings["ambient_occlusion"] = false
			settings["particle_density"]  = 0.7
			settings["render_scale"]      = 0.9
		"High":
			settings["shadow_quality"]    = 2
			settings["anti_aliasing"]     = 1
			settings["bloom_enabled"]     = true
			settings["volumetric_fog"]    = true
			settings["ambient_occlusion"] = false
			settings["particle_density"]  = 1.0
			settings["render_scale"]      = 1.0
		"Ultra":
			settings["shadow_quality"]    = 3
			settings["anti_aliasing"]     = 2
			settings["bloom_enabled"]     = true
			settings["volumetric_fog"]    = true
			settings["ambient_occlusion"] = true
			settings["particle_density"]  = 1.0
			settings["render_scale"]      = 1.0
	_apply()
	_save()
	settings_changed.emit()

# ── Bindings ──────────────────────────────────────────────────────────────────

func save_binding(action: String, event: InputEvent) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	if event is InputEventKey:
		cfg.set_value("bindings", action, "key:" + str(event.keycode))
	elif event is InputEventMouseButton:
		cfg.set_value("bindings", action, "mouse:" + str(event.button_index))
	cfg.save(SAVE_PATH)

func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action in REBINDABLE_ACTIONS.keys():
		if not InputMap.has_action(action):
			continue
		var val: String = cfg.get_value("bindings", action, "")
		if val == "":
			continue
		var parts := val.split(":")
		if parts.size() < 2:
			continue
		InputMap.action_erase_events(action)
		match parts[0]:
			"key":
				var ev := InputEventKey.new()
				ev.keycode = int(parts[1]) as Key
				InputMap.action_add_event(action, ev)
			"mouse":
				var ev := InputEventMouseButton.new()
				ev.button_index = int(parts[1]) as MouseButton
				InputMap.action_add_event(action, ev)

func get_action_display(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.keycode)
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT:        return "LMB"
				MOUSE_BUTTON_RIGHT:       return "RMB"
				MOUSE_BUTTON_MIDDLE:      return "MMB"
				MOUSE_BUTTON_WHEEL_UP:    return "Scroll ↑"
				MOUSE_BUTTON_WHEEL_DOWN:  return "Scroll ↓"
				_: return "Mouse %d" % ev.button_index
	return "—"

# ── Apply all settings ────────────────────────────────────────────────────────

func _apply() -> void:
	# Audio buses
	_apply_bus("Master",  settings.get("master_volume",  0.85))
	_apply_bus("Music",   settings.get("music_volume",   0.80))
	_apply_bus("SFX",     settings.get("sfx_volume",     0.90))
	_apply_bus("Ambient", settings.get("ambient_volume", 0.85))
	_apply_bus("UI",      settings.get("ui_volume",      0.70))

	# Display mode
	if settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# VSync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings.get("vsync", true)
		else DisplayServer.VSYNC_DISABLED)

	# Framerate cap
	Engine.max_fps = settings.get("framerate_cap", 0)

	# Render scale
	if get_viewport():
		get_viewport().scaling_3d_scale = clamp(settings.get("render_scale", 1.0), 0.5, 2.0)

	# Shadow quality
	var sq: int = settings.get("shadow_quality", 2)
	var shadow_sizes := [0, 1024, 2048, 4096]
	if sq < shadow_sizes.size():
		RenderingServer.directional_shadow_atlas_set_size(shadow_sizes[sq], true)

	# Anti-aliasing
	var vp := get_viewport()
	if vp:
		var aa: int = settings.get("anti_aliasing", 1)
		match aa:
			0:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.use_taa = false
			1:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
				vp.use_taa = false
			2:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.use_taa = true

func _apply_bus(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(volume, 0.001, 1.0)))
		AudioServer.set_bus_mute(idx, volume <= 0.001)

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
	load_bindings()
