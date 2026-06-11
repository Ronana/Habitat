## Reusable settings panel — built entirely in code.
## Add to any scene, connect the "closed" signal for the back button.
extends PanelContainer

signal closed

# ── Theme constants ───────────────────────────────────────────────────────────
const C_BG     := Color(0.06, 0.10, 0.06, 0.98)
const C_BORDER := Color(0.28, 0.46, 0.22, 1.00)
const C_TEXT   := Color(0.93, 0.91, 0.82, 1.00)
const C_MUTED  := Color(0.62, 0.72, 0.52, 1.00)
const C_ACCENT := Color(0.52, 0.82, 0.32, 1.00)
const C_BTN    := Color(0.12, 0.22, 0.09, 1.00)
const C_BTN_H  := Color(0.20, 0.36, 0.15, 1.00)

func _ready():
	_apply_bg()
	_build()

# ── Background style ──────────────────────────────────────────────────────────

func _apply_bg():
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.border_color = C_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(24)
	add_theme_stylebox_override("panel", s)

# ── Build ─────────────────────────────────────────────────────────────────────

func _build():
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 480)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⚙  Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(title)
	vbox.add_child(_separator())

	# ── Camera section ────────────────────────────────────────────────────────
	vbox.add_child(_section_header("🎥  Camera"))

	_add_slider(vbox, "Move Speed",     "cam_move_speed",    5.0,  40.0,  1.0)
	_add_slider(vbox, "Zoom Speed",     "cam_zoom_speed",    1.0,  10.0,  0.5)
	_add_slider(vbox, "Rotation Speed", "cam_rotation_speed", 0.1, 1.0,  0.05)
	_add_slider(vbox, "Pan Speed",      "cam_pan_speed",     0.01, 0.15, 0.01)
	_add_toggle(vbox, "Edge Scrolling", "cam_edge_scroll")
	_add_toggle(vbox, "Invert Y Rotation", "cam_invert_y")

	vbox.add_child(_separator())

	# ── Audio section ─────────────────────────────────────────────────────────
	vbox.add_child(_section_header("🔊  Audio"))

	_add_slider(vbox, "Master Volume", "master_volume", 0.0, 1.0, 0.05)

	vbox.add_child(_separator())

	# ── Display section ───────────────────────────────────────────────────────
	vbox.add_child(_section_header("🖥  Display"))

	_add_toggle(vbox, "Fullscreen", "fullscreen")

	vbox.add_child(_separator())

	# Back button
	var back_btn := _make_button("← Back")
	back_btn.pressed.connect(func(): emit_signal("closed"))
	vbox.add_child(back_btn)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_ACCENT)
	return lbl

func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_BORDER, 0.5)
	s.set_content_margin_all(2)
	sep.add_theme_stylebox_override("separator", s)
	return sep

func _add_slider(parent: VBoxContainer, label: String, key: String,
				 min_v: float, max_v: float, step: float):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = SettingsManager.settings.get(key, min_v)
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(slider)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", C_MUTED)
	val_lbl.text = _fmt(slider.value, step)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = _fmt(v, step)
		SettingsManager.set_setting(key, v))

func _add_toggle(parent: VBoxContainer, label: String, key: String):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(lbl)

	var check := CheckButton.new()
	check.button_pressed = SettingsManager.settings.get(key, false)
	check.add_theme_color_override("font_color", C_TEXT)
	check.add_theme_color_override("font_pressed_color", C_ACCENT)
	row.add_child(check)

	check.toggled.connect(func(v: bool):
		SettingsManager.set_setting(key, v))

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	var norm := StyleBoxFlat.new()
	norm.bg_color = C_BTN
	norm.border_color = C_BORDER
	norm.set_border_width_all(1)
	norm.set_corner_radius_all(6)
	norm.set_content_margin_all(8)
	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_H
	hover.border_color = C_BORDER
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", norm)
	btn.add_theme_color_override("font_color",         C_TEXT)
	btn.add_theme_color_override("font_hover_color",   C_ACCENT)
	btn.add_theme_color_override("font_pressed_color", C_TEXT)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _style_slider(slider: HSlider):
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = C_ACCENT
	grabber.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(C_ACCENT, 0.5)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.18, 0.08, 1.0)
	bg.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("slider", bg)

func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(v))
	elif step >= 0.1:
		return "%.1f" % v
	else:
		return "%.2f" % v
