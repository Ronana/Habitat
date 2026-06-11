## Pause menu — CanvasLayer, toggled by Escape.
## Add as a child of the Garden scene (process_mode = ALWAYS so it
## still receives input when the tree is paused).
extends CanvasLayer

# ── Theme ─────────────────────────────────────────────────────────────────────
const C_BG     := Color(0.04, 0.07, 0.04, 0.92)
const C_BORDER := Color(0.28, 0.46, 0.22, 1.00)
const C_TEXT   := Color(0.93, 0.91, 0.82, 1.00)
const C_MUTED  := Color(0.62, 0.72, 0.52, 1.00)
const C_ACCENT := Color(0.52, 0.82, 0.32, 1.00)
const C_BTN    := Color(0.12, 0.22, 0.09, 1.00)
const C_BTN_H  := Color(0.22, 0.38, 0.17, 1.00)
const C_DANGER := Color(0.38, 0.10, 0.08, 1.00)
const C_DANGER_H := Color(0.55, 0.15, 0.10, 1.00)

var _root: Control = null
var _menu_container: PanelContainer = null
var _settings_panel = null
var _feedback_lbl: Label = null
var is_open: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10  # above game UI
	_build()
	hide_menu()

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _settings_panel and _settings_panel.visible:
				_close_settings()
			elif is_open:
				_resume()
			else:
				_open()
			get_viewport().set_input_as_handled()

# ── Build UI ──────────────────────────────────────────────────────────────────

func _build():
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Dark overlay behind the panel
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_root.add_child(overlay)

	# Centred panel
	_menu_container = PanelContainer.new()
	_menu_container.custom_minimum_size = Vector2(300, 0)
	_menu_container.set_anchors_preset(Control.PRESET_CENTER)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BG
	bg.border_color = C_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(14)
	bg.set_content_margin_all(28)
	_menu_container.add_theme_stylebox_override("panel", bg)
	_root.add_child(_menu_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_container.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⏸  Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(title)

	vbox.add_child(_separator())

	# Menu buttons
	_add_btn(vbox, "▶  Resume",    _resume,    false)
	_add_btn(vbox, "💾  Save Game", _save_game,  false)
	_add_btn(vbox, "📂  Load Game", _load_game,  false)
	_add_btn(vbox, "⚙  Settings",  _open_settings, false)
	vbox.add_child(_separator())
	_add_btn(vbox, "🏠  Main Menu", _go_main_menu, true)

	# Feedback label
	_feedback_lbl = Label.new()
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.add_theme_font_size_override("font_size", 11)
	_feedback_lbl.add_theme_color_override("font_color", C_MUTED)
	_feedback_lbl.visible = false
	vbox.add_child(_feedback_lbl)

	# Settings panel (hidden until needed)
	var settings_scene := load("res://scripts/settings_panel.gd")
	if settings_scene:
		_settings_panel = settings_scene.new()
		_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
		_settings_panel.visible = false
		_root.add_child(_settings_panel)
		_settings_panel.closed.connect(_close_settings)

# ── Visibility helpers ────────────────────────────────────────────────────────

func _open():
	is_open = true
	get_tree().paused = true
	_root.visible = true
	_menu_container.visible = true
	if _settings_panel:
		_settings_panel.visible = false
	# Animate in
	_menu_container.modulate = Color(1, 1, 1, 0)
	_menu_container.scale = Vector2(0.88, 0.88)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_menu_container, "modulate", Color(1, 1, 1, 1), 0.25)
	t.parallel().tween_property(_menu_container, "scale", Vector2(1, 1), 0.25)

func hide_menu():
	is_open = false
	_root.visible = false
	get_tree().paused = false

# ── Button actions ────────────────────────────────────────────────────────────

func _resume():
	hide_menu()
	AudioManager.play_select()

func _save_game():
	var garden = get_tree().get_root().get_node_or_null("Garden")
	if garden:
		SaveManager.save_game(garden)
		_show_feedback("✓ Game saved!", Color(0.4, 0.9, 0.4))
	AudioManager.play_place()

func _load_game():
	hide_menu()
	var garden = get_tree().get_root().get_node_or_null("Garden")
	if garden:
		SaveManager.load_game(garden)
	AudioManager.play_select()

func _open_settings():
	_menu_container.visible = false
	if _settings_panel:
		_settings_panel.visible = true
	AudioManager.play_select()

func _close_settings():
	if _settings_panel:
		_settings_panel.visible = false
	_menu_container.visible = true
	AudioManager.play_select()

func _go_main_menu():
	get_tree().paused = false
	AudioManager.play_select()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ── Feedback ──────────────────────────────────────────────────────────────────

func _show_feedback(msg: String, colour: Color):
	_feedback_lbl.text = msg
	_feedback_lbl.modulate = colour
	_feedback_lbl.visible = true
	await get_tree().create_timer(2.5).timeout
	_feedback_lbl.visible = false

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_btn(parent: VBoxContainer, text: String, callback: Callable, danger: bool):
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 44)
	var norm_col  := C_DANGER   if danger else C_BTN
	var hover_col := C_DANGER_H if danger else C_BTN_H
	var norm := _btn_style(norm_col)
	var hover := _btn_style(hover_col)
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_color_override("font_color",         C_TEXT)
	btn.add_theme_color_override("font_hover_color",   C_ACCENT if not danger else Color(1, 0.7, 0.5))
	btn.add_theme_color_override("font_pressed_color", C_TEXT)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.set_content_margin_all(10)
	return s

func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER, 0.45)
	s.set_content_margin_all(2)
	sep.add_theme_stylebox_override("separator", s)
	return sep
