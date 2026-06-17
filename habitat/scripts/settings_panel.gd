## settings_panel.gd
## Full-screen settings overlay with tabbed layout.
## Tabs: Audio · Graphics · Controls · Accessibility
## Emits "closed" signal when the Back button is pressed.
extends Control

signal closed

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG      := Color(0.04, 0.01, 0.09, 0.97)
const C_PANEL   := Color(0.06, 0.02, 0.13, 0.98)
const C_BORDER  := Color(0.55, 0.20, 0.80, 1.00)
const C_BORDER2 := Color(0.55, 0.20, 0.80, 0.35)
const C_TEXT    := Color(0.88, 0.80, 0.96, 1.00)
const C_MUTED   := Color(0.52, 0.44, 0.66, 1.00)
const C_ACCENT  := Color(0.78, 0.38, 0.96, 1.00)
const C_HOT     := Color(0.96, 0.52, 0.84, 1.00)
const C_BTN     := Color(0.10, 0.03, 0.20, 1.00)
const C_BTN_H   := Color(0.20, 0.06, 0.36, 1.00)

# ── Rebinding state ───────────────────────────────────────────────────────────
var _listening_action: String = ""
var _listening_btn: Button = null
var _rebind_labels: Dictionary = {}   # action → Button (displays current key)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

# ── Build ─────────────────────────────────────────────────────────────────────

func _build():
	# Dark overlay behind panel
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.00, 0.04, 0.72)
	add_child(overlay)

	# Centred panel container
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -440
	panel.offset_right  =  440
	panel.offset_top    = -340
	panel.offset_bottom =  340

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL
	panel_style.border_color = C_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	# Title row
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)

	var title := Label.new()
	title.text = "⚙  Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_ACCENT)
	title_row.add_child(title)

	# Separator
	outer.add_child(_separator())

	# Tab container
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 460)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tabs(tabs)
	outer.add_child(tabs)

	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_graphics_tab())
	tabs.add_child(_build_controls_tab())
	tabs.add_child(_build_accessibility_tab())

	# Bottom separator + back button
	outer.add_child(_separator())
	var back_btn := _make_button("← Back to Menu")
	back_btn.pressed.connect(_on_back)
	outer.add_child(back_btn)

# ═════════════════════════════════════════════════════════════════════════════
# TAB: AUDIO
# ═════════════════════════════════════════════════════════════════════════════

func _build_audio_tab() -> ScrollContainer:
	var scroll := _tab_scroll("🔊  Audio")
	var vbox: VBoxContainer = scroll.get_child(0)

	vbox.add_child(_section_header("Volume Levels"))
	_add_slider(vbox, "Master",  "master_volume",  0.0, 1.0, 0.01, true)
	_add_slider(vbox, "Music",   "music_volume",   0.0, 1.0, 0.01, true)
	_add_slider(vbox, "SFX",     "sfx_volume",     0.0, 1.0, 0.01, true)
	_add_slider(vbox, "Ambient", "ambient_volume", 0.0, 1.0, 0.01, true)
	_add_slider(vbox, "UI",      "ui_volume",      0.0, 1.0, 0.01, true)

	vbox.add_child(_separator())
	vbox.add_child(_section_header("Audio Buses"))
	var note := Label.new()
	note.text = "Each slider controls an independent audio bus.\nSet to 0 to mute that category entirely."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(C_MUTED, 0.7))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(note)

	return scroll

# ═════════════════════════════════════════════════════════════════════════════
# TAB: GRAPHICS
# ═════════════════════════════════════════════════════════════════════════════

func _build_graphics_tab() -> ScrollContainer:
	var scroll := _tab_scroll("🖥  Graphics")
	var vbox: VBoxContainer = scroll.get_child(0)

	# Quality preset buttons
	vbox.add_child(_section_header("Quality Preset"))
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	vbox.add_child(preset_row)
	for preset in ["Low", "Medium", "High", "Ultra"]:
		var btn := _make_small_button(preset)
		btn.pressed.connect(func(): SettingsManager.apply_quality_preset(preset))
		preset_row.add_child(btn)

	vbox.add_child(_separator())
	vbox.add_child(_section_header("Display"))
	_add_toggle(vbox, "Fullscreen",   "fullscreen")
	_add_toggle(vbox, "VSync",        "vsync")
	_add_dropdown(vbox, "Framerate Cap", "framerate_cap",
		["Unlimited", "30 FPS", "60 FPS", "120 FPS", "144 FPS"],
		[0, 30, 60, 120, 144])
	_add_slider(vbox, "Render Scale", "render_scale", 0.5, 1.5, 0.05)

	vbox.add_child(_separator())
	vbox.add_child(_section_header("Shadows & Lighting"))
	_add_dropdown(vbox, "Shadow Quality", "shadow_quality",
		["Off", "Low", "Medium", "High"], [0, 1, 2, 3])
	_add_dropdown(vbox, "Anti-Aliasing", "anti_aliasing",
		["None", "FXAA", "TAA"], [0, 1, 2])
	_add_toggle(vbox, "Bloom / Glow",      "bloom_enabled")
	_add_toggle(vbox, "Volumetric Fog",    "volumetric_fog")
	_add_toggle(vbox, "Ambient Occlusion", "ambient_occlusion")

	vbox.add_child(_separator())
	vbox.add_child(_section_header("Performance"))
	_add_slider(vbox, "Particle Density", "particle_density", 0.0, 1.0, 0.05)

	return scroll

# ═════════════════════════════════════════════════════════════════════════════
# TAB: CONTROLS
# ═════════════════════════════════════════════════════════════════════════════

func _build_controls_tab() -> ScrollContainer:
	var scroll := _tab_scroll("🎮  Controls")
	var vbox: VBoxContainer = scroll.get_child(0)

	vbox.add_child(_section_header("Camera"))
	_add_slider(vbox, "Move Speed",     "cam_move_speed",    5.0,  40.0, 1.0)
	_add_slider(vbox, "Zoom Speed",     "cam_zoom_speed",    0.5,  10.0, 0.5)
	_add_slider(vbox, "Rotation Speed", "cam_rotation_speed", 0.05, 1.0, 0.05)
	_add_slider(vbox, "Pan Speed",      "cam_pan_speed",     0.01, 0.15, 0.01)
	_add_toggle(vbox, "Edge Scrolling", "cam_edge_scroll")
	_add_toggle(vbox, "Invert Y Rotation", "cam_invert_y")

	vbox.add_child(_separator())
	vbox.add_child(_section_header("Key Bindings"))

	var note := Label.new()
	note.text = "Click a binding button, then press any key or mouse button to rebind."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(C_MUTED, 0.8))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(note)
	vbox.add_child(_gap(8))

	for action in SettingsManager.REBINDABLE_ACTIONS.keys():
		_add_rebind_row(vbox, action, SettingsManager.REBINDABLE_ACTIONS[action])

	vbox.add_child(_gap(8))
	var reset_btn := _make_button("↺  Reset to Defaults")
	reset_btn.pressed.connect(_reset_bindings)
	vbox.add_child(reset_btn)

	return scroll

# ═════════════════════════════════════════════════════════════════════════════
# TAB: ACCESSIBILITY
# ═════════════════════════════════════════════════════════════════════════════

func _build_accessibility_tab() -> ScrollContainer:
	var scroll := _tab_scroll("♿  Accessibility")
	var vbox: VBoxContainer = scroll.get_child(0)

	vbox.add_child(_section_header("Interface Scale"))
	_add_slider(vbox, "UI Scale",   "ui_scale",  0.75, 2.0, 0.05)
	_add_slider(vbox, "HUD Scale",  "hud_scale", 0.75, 1.5, 0.05)
	_add_slider(vbox, "HUD Opacity","hud_opacity",0.2, 1.0, 0.05)

	vbox.add_child(_separator())
	vbox.add_child(_section_header("Visual"))
	_add_toggle(vbox, "High Contrast Mode", "high_contrast")
	_add_toggle(vbox, "Reduced Motion",     "reduced_motion")
	_add_toggle(vbox, "Large Text",         "large_text")
	_add_dropdown(vbox, "Colorblind Mode", "colorblind_mode",
		["None", "Protanopia", "Deuteranopia", "Tritanopia"], [0, 1, 2, 3])

	vbox.add_child(_separator())
	vbox.add_child(_section_header("HUD Elements"))
	_add_toggle(vbox, "Show FPS Counter", "show_fps")
	_add_toggle(vbox, "Show Clock",       "show_clock")

	return scroll

# ═════════════════════════════════════════════════════════════════════════════
# CONTROLS — REBINDING
# ═════════════════════════════════════════════════════════════════════════════

func _add_rebind_row(parent: VBoxContainer, action: String, display_name: String):
	if not InputMap.has_action(action):
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.custom_minimum_size = Vector2(180, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var key_btn := Button.new()
	key_btn.text = SettingsManager.get_action_display(action)
	key_btn.custom_minimum_size = Vector2(130, 32)
	_style_key_btn(key_btn, false)
	row.add_child(key_btn)

	_rebind_labels[action] = key_btn

	key_btn.pressed.connect(func():
		if _listening_action != "":
			_cancel_listen()
		_start_listen(action, key_btn))

func _start_listen(action: String, btn: Button):
	_listening_action = action
	_listening_btn = btn
	btn.text = "Press any key…"
	_style_key_btn(btn, true)
	set_process_unhandled_input(true)

func _cancel_listen():
	if _listening_btn:
		_listening_btn.text = SettingsManager.get_action_display(_listening_action)
		_style_key_btn(_listening_btn, false)
	_listening_action = ""
	_listening_btn = null
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent):
	if _listening_action == "":
		return
	if event is InputEventKey and not event.pressed:
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	# Escape cancels
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_cancel_listen()
		get_viewport().set_input_as_handled()
		return
	# Apply the new binding
	InputMap.action_erase_events(_listening_action)
	InputMap.action_add_event(_listening_action, event)
	SettingsManager.save_binding(_listening_action, event)
	# Update display
	if _listening_btn:
		_listening_btn.text = SettingsManager.get_action_display(_listening_action)
		_style_key_btn(_listening_btn, false)
	_listening_action = ""
	_listening_btn = null
	set_process_unhandled_input(false)
	get_viewport().set_input_as_handled()

func _reset_bindings():
	InputMap.load_from_project_settings()
	for action in _rebind_labels:
		_rebind_labels[action].text = SettingsManager.get_action_display(action)

func _on_back():
	if _listening_action != "":
		_cancel_listen()
	closed.emit()

# ═════════════════════════════════════════════════════════════════════════════
# WIDGET HELPERS
# ═════════════════════════════════════════════════════════════════════════════

func _tab_scroll(tab_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.custom_minimum_size = Vector2(800, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	return scroll

func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_ACCENT)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.5))
	lbl.add_theme_constant_override("outline_size", 1)
	return lbl

func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER, 0.3)
	s.set_content_margin_all(3)
	sep.add_theme_stylebox_override("separator", s)
	return sep

func _gap(height: int) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, height)
	return g

# ── Slider ────────────────────────────────────────────────────────────────────

func _add_slider(parent: VBoxContainer, label: String, key: String,
				 min_v: float, max_v: float, step: float, pct: bool = false):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(165, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = SettingsManager.settings.get(key, min_v)
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(slider)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", C_MUTED)
	val_lbl.text = _fmt_val(slider.value, step, pct)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = _fmt_val(v, step, pct)
		SettingsManager.set_setting(key, v))

# ── Toggle ────────────────────────────────────────────────────────────────────

func _add_toggle(parent: VBoxContainer, label: String, key: String):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(165, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(lbl)

	var check := CheckButton.new()
	check.button_pressed = SettingsManager.settings.get(key, false)
	check.add_theme_color_override("font_color",         C_TEXT)
	check.add_theme_color_override("font_pressed_color", C_ACCENT)
	row.add_child(check)

	check.toggled.connect(func(v: bool): SettingsManager.set_setting(key, v))

# ── Dropdown ──────────────────────────────────────────────────────────────────

func _add_dropdown(parent: VBoxContainer, label: String, key: String,
				   option_labels: Array, option_values: Array):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(165, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(170, 32)
	_style_option(opt)
	var current_val = SettingsManager.settings.get(key, option_values[0])
	for i in option_labels.size():
		opt.add_item(option_labels[i], i)
		if option_values[i] == current_val:
			opt.selected = i
	row.add_child(opt)

	opt.item_selected.connect(func(idx: int):
		SettingsManager.set_setting(key, option_values[idx]))

# ── Buttons ───────────────────────────────────────────────────────────────────

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 42)
	var norm := _flat_style(C_BTN)
	var hov  := _flat_style(C_BTN_H)
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",        C_TEXT)
	btn.add_theme_color_override("font_hover_color",  C_HOT)
	btn.add_theme_color_override("font_pressed_color",C_TEXT)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _make_small_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 34)
	var norm := _flat_style(C_BTN)
	var hov  := _flat_style(C_BTN_H)
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",        C_MUTED)
	btn.add_theme_color_override("font_hover_color",  C_HOT)
	btn.add_theme_color_override("font_pressed_color",C_TEXT)
	btn.add_theme_font_size_override("font_size", 12)
	return btn

func _style_key_btn(btn: Button, listening: bool):
	var col := Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.18) if listening \
			   else Color(C_BTN.r, C_BTN.g, C_BTN.b, 1.0)
	var bdr := C_HOT if listening else C_BORDER
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = bdr
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", C_HOT if listening else C_TEXT)
	btn.add_theme_font_size_override("font_size", 12)

# ── Style helpers ─────────────────────────────────────────────────────────────

func _style_slider(slider: HSlider):
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(C_ACCENT, 0.55)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.02, 0.16, 1.0)
	bg.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("slider",       bg)
	slider.add_theme_color_override("grabber_color",   C_ACCENT)

func _style_option(opt: OptionButton):
	var norm := _flat_style(C_BTN)
	var hov  := _flat_style(C_BTN_H)
	opt.add_theme_stylebox_override("normal",   norm)
	opt.add_theme_stylebox_override("hover",    hov)
	opt.add_theme_stylebox_override("pressed",  norm)
	opt.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	opt.add_theme_color_override("font_color",       C_TEXT)
	opt.add_theme_color_override("font_hover_color", C_HOT)
	opt.add_theme_font_size_override("font_size", 12)

func _style_tabs(tabs: TabContainer):
	var active := StyleBoxFlat.new()
	active.bg_color = Color(0.12, 0.03, 0.22, 1.0)
	active.border_color = C_BORDER
	active.border_width_top = 2
	active.set_corner_radius_all(6)
	active.set_content_margin_all(10)
	var inactive := StyleBoxFlat.new()
	inactive.bg_color = Color(0.06, 0.02, 0.12, 1.0)
	inactive.set_corner_radius_all(6)
	inactive.set_content_margin_all(10)
	tabs.add_theme_stylebox_override("tab_selected",   active)
	tabs.add_theme_stylebox_override("tab_unselected", inactive)
	tabs.add_theme_stylebox_override("panel",          StyleBoxEmpty.new())
	tabs.add_theme_color_override("font_selected_color",   C_ACCENT)
	tabs.add_theme_color_override("font_unselected_color", C_MUTED)
	tabs.add_theme_font_size_override("font_size", 13)

func _flat_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(C_BORDER, 0.5)
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.set_content_margin_all(10)
	return s

func _fmt_val(v: float, step: float, pct: bool) -> String:
	if pct:
		return "%d%%" % int(v * 100.0)
	if step >= 1.0:
		return str(int(v))
	elif step >= 0.1:
		return "%.1f" % v
	else:
		return "%.2f" % v
