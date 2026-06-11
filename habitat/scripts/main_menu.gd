## Main Menu — the game's starting scene.
## Entirely built in GDScript (no .tscn nodes needed).
extends Control

# ── Theme ─────────────────────────────────────────────────────────────────────
const C_BG     := Color(0.03, 0.06, 0.03, 1.00)
const C_PANEL  := Color(0.06, 0.10, 0.06, 0.95)
const C_BORDER := Color(0.28, 0.46, 0.22, 1.00)
const C_TEXT   := Color(0.93, 0.91, 0.82, 1.00)
const C_MUTED  := Color(0.62, 0.72, 0.52, 1.00)
const C_ACCENT := Color(0.52, 0.82, 0.32, 1.00)
const C_BTN    := Color(0.10, 0.20, 0.08, 1.00)
const C_BTN_H  := Color(0.20, 0.36, 0.15, 1.00)
const C_GLOW   := Color(0.35, 0.70, 0.28, 0.18)

var _menu_vbox: VBoxContainer = null
var _settings_panel = null
var _particle_timer: float = 0.0
var _particle_container: Control = null

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()
	_build_settings_panel()
	_animate_in()

# ── Background ────────────────────────────────────────────────────────────────

func _build_background():
	# Deep dark-green base
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	add_child(bg)

	# Vignette: a slightly lighter centre gradient
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.08, 0.16, 0.06, 0.30)
	add_child(vignette)

	# Container for floating particles
	_particle_container = Control.new()
	_particle_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_container)

	# Decorative corner vines (label art)
	for corner_data in [
		[Vector2(20,  20),  "✿ ❧"],
		[Vector2(-20, 20),  "❧ ✿"],
	]:
		var vine := Label.new()
		vine.text = corner_data[1]
		vine.add_theme_font_size_override("font_size", 18)
		vine.add_theme_color_override("font_color", Color(C_ACCENT, 0.3))
		vine.set_anchors_preset(Control.PRESET_TOP_LEFT if corner_data[0].x > 0 else Control.PRESET_TOP_RIGHT)
		vine.offset_left  = corner_data[0].x
		vine.offset_top   = corner_data[0].y
		add_child(vine)

func _process(delta):
	_particle_timer += delta
	if _particle_timer >= randf_range(0.8, 2.2):
		_particle_timer = 0.0
		_spawn_particle()

func _spawn_particle():
	var dot := Label.new()
	var icons := ["✦", "•", "·", "⁕", "✧", "◦"]
	dot.text = icons[randi() % icons.size()]
	dot.add_theme_font_size_override("font_size", 10 + randi() % 16)
	dot.add_theme_color_override("font_color", Color(C_ACCENT, randf_range(0.15, 0.5)))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := get_viewport().get_visible_rect().size
	dot.position = Vector2(randf_range(0, vp.x), vp.y + 10)
	_particle_container.add_child(dot)
	var tween := create_tween().set_parallel(true)
	var rise := randf_range(220.0, 500.0)
	var drift := randf_range(-40.0, 40.0)
	tween.tween_property(dot, "position:y", dot.position.y - rise, randf_range(4.0, 9.0)) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(dot, "position:x", dot.position.x + drift, randf_range(4.0, 9.0)) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(dot, "modulate:a", 0.0, randf_range(3.0, 7.0)) \
		.set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(dot.queue_free)

# ── Menu panel ────────────────────────────────────────────────────────────────

func _build_menu():
	# Outer panel — centred on screen
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -180.0
	panel.offset_right  =  180.0
	panel.offset_top    = -260.0
	panel.offset_bottom =  260.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = C_PANEL
	bg.border_color = C_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(16)
	bg.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	_menu_vbox = VBoxContainer.new()
	_menu_vbox.add_theme_constant_override("separation", 10)
	_menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(_menu_vbox)

	# Title
	var title := Label.new()
	title.text = "HABITAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.16, 0.05))
	title.add_theme_constant_override("outline_size", 3)
	_menu_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a wildlife sanctuary"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", C_MUTED)
	_menu_vbox.add_child(subtitle)

	_menu_vbox.add_child(_separator())

	# Buttons
	var save_exists := FileAccess.file_exists("user://habitat_save.json")

	_add_menu_btn("🌿  New Game",  _on_new_game)
	var cont_btn := _add_menu_btn("📖  Continue",  _on_continue)
	if not save_exists:
		cont_btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
		cont_btn.disabled = true
		cont_btn.tooltip_text = "No save file found"

	_menu_vbox.add_child(_separator())
	_add_menu_btn("⚙  Settings",  _on_settings)
	_add_menu_btn("✕  Quit",      _on_quit, true)

	# Version tag
	var ver := Label.new()
	ver.text = "Early Build"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", Color(C_MUTED, 0.5))
	_menu_vbox.add_child(ver)

func _animate_in():
	_menu_vbox.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_menu_vbox, "modulate", Color(1, 1, 1, 1), 0.9)

# ── Settings panel ────────────────────────────────────────────────────────────

func _build_settings_panel():
	var settings_script := load("res://scripts/settings_panel.gd")
	if not settings_script:
		return
	_settings_panel = settings_script.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.offset_left   = -260.0
	_settings_panel.offset_right  =  260.0
	_settings_panel.offset_top    = -320.0
	_settings_panel.offset_bottom =  320.0
	_settings_panel.visible = false
	add_child(_settings_panel)
	_settings_panel.closed.connect(_on_settings_closed)

# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_new_game():
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/garden.tscn")

func _on_continue():
	get_tree().change_scene_to_file("res://scenes/garden.tscn")

func _on_settings():
	_menu_vbox.get_parent().visible = false
	if _settings_panel:
		_settings_panel.visible = true

func _on_settings_closed():
	if _settings_panel:
		_settings_panel.visible = false
	_menu_vbox.get_parent().visible = true

func _on_quit():
	get_tree().quit()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_menu_btn(text: String, callback: Callable, danger: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 46)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var bg  := Color(0.30, 0.08, 0.06, 1.0) if danger else C_BTN
	var bgh := Color(0.48, 0.12, 0.09, 1.0) if danger else C_BTN_H
	btn.add_theme_stylebox_override("normal",  _btn_style(bg))
	btn.add_theme_stylebox_override("hover",   _btn_style(bgh))
	btn.add_theme_stylebox_override("pressed", _btn_style(bg))
	btn.add_theme_color_override("font_color",
		Color(1.0, 0.6, 0.5) if danger else C_TEXT)
	btn.add_theme_color_override("font_hover_color",
		Color(1.0, 0.75, 0.6) if danger else C_ACCENT)
	btn.add_theme_color_override("font_pressed_color", C_TEXT)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(callback)
	_menu_vbox.add_child(btn)
	return btn

func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(C_BORDER, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left  = 16
	s.content_margin_right = 16
	s.content_margin_top   = 10
	s.content_margin_bottom = 10
	return s

func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER, 0.4)
	s.set_content_margin_all(4)
	sep.add_theme_stylebox_override("separator", s)
	return sep
