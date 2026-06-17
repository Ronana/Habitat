## main_menu.gd
## Halo 3–style layout:
##   · Full-screen background art (place image at res://ui/menu_bg.png)
##   · "HABITAT" logo in the lower-right area
##   · Menu items stacked lower-left — selected item gets a solid highlight bar
##   · Settings sits separately at the very bottom-left
##   · Arrow-key / mouse navigation
extends Control

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG      := Color(0.03, 0.01, 0.07, 1.00)   # near-black purple
const C_TEXT    := Color(0.94, 0.90, 0.98, 1.00)   # bright lavender-white
const C_DIM     := Color(0.62, 0.56, 0.76, 1.00)   # unselected item text
const C_ACCENT  := Color(0.80, 0.38, 0.96, 1.00)   # vivid purple (logo)
const C_HOT     := Color(0.98, 0.56, 0.86, 1.00)   # hot pink (settings hover)
const C_BORDER  := Color(0.58, 0.22, 0.82, 1.00)   # purple border
const C_HILITE  := Color(0.24, 0.05, 0.42, 0.90)   # selected bar background
const C_HILITE_L:= Color(0.58, 0.22, 0.82, 1.00)   # left accent on selected bar
const C_DANGER  := Color(0.80, 0.18, 0.30, 1.00)   # quit button

# ── Item data ─────────────────────────────────────────────────────────────────
# [label, callback_name, is_danger, is_disabled_without_save]
const MENU_ITEMS := [
	["NEW GAME",  "_on_new_game",  false, false],
	["CONTINUE",  "_on_continue",  false, true ],
]

# ── State ─────────────────────────────────────────────────────────────────────
var _menu_root: Control = null
var _settings_panel = null
var _particle_container: Control = null
var _particle_timer: float = 0.0
var _title_label: Label = null
var _item_btns: Array = []    # Array[Button]
var _selected_idx: int = 0
var _save_exists: bool = false

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_exists = FileAccess.file_exists("user://habitat_save.json")
	_build_background()
	_build_particles_container()
	_build_logo()
	_build_menu()
	_build_settings_panel()
	_animate_in()
	_start_title_pulse()

# ── Background ────────────────────────────────────────────────────────────────

func _build_background():
	var base := ColorRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = C_BG
	add_child(base)

	# Game artwork — place a screenshot at res://ui/menu_bg.png
	var tex = null
	for path in ["res://ui/menu_bg.png", "res://ui/menu_bg.jpg"]:
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	if tex:
		var img := TextureRect.new()
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.texture = tex
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.modulate = Color(1, 1, 1, 0.58)
		add_child(img)

	# Overall dark tint
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.02, 0.00, 0.05, 0.50)
	add_child(tint)

	# Gradient: dark on left (menu side), transparent on right (logo/art side)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.01, 0.07, 0.90))
	grad.set_color(1, Color(0.03, 0.01, 0.07, 0.0))
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	gtex.width = 512
	var fade := TextureRect.new()
	fade.texture = gtex
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.anchor_right  = 0.55
	fade.anchor_bottom = 1.0
	add_child(fade)

	# Bottom gradient — dark strip at bottom where menu items sit
	var bgrad := Gradient.new()
	bgrad.set_color(0, Color(0.02, 0.00, 0.05, 0.0))
	bgrad.set_color(1, Color(0.02, 0.00, 0.05, 0.80))
	var bgtex := GradientTexture1D.new()
	bgtex.gradient = bgrad
	bgtex.width = 256
	var bot_fade := TextureRect.new()
	bot_fade.texture = bgtex
	bot_fade.stretch_mode = TextureRect.STRETCH_SCALE
	bot_fade.anchor_top    = 0.5
	bot_fade.anchor_bottom = 1.0
	bot_fade.anchor_right  = 1.0
	# Rotate the gradient so dark is at bottom
	bot_fade.flip_v = true
	add_child(bot_fade)

# ── Particles ─────────────────────────────────────────────────────────────────

func _build_particles_container():
	_particle_container = Control.new()
	_particle_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_container)

func _process(delta):
	_particle_timer += delta
	if _particle_timer >= randf_range(0.6, 1.8):
		_particle_timer = 0.0
		_spawn_particle()

func _spawn_particle():
	var icons  := ["✦", "✧", "⋆", "✺", "✵", "⁕", "◦", "✾", "·"]
	var colors := [
		Color(0.72, 0.22, 0.96, randf_range(0.25, 0.65)),
		Color(0.96, 0.42, 0.84, randf_range(0.20, 0.55)),
		Color(0.88, 0.78, 0.22, randf_range(0.15, 0.45)),
		Color(0.50, 0.78, 0.98, randf_range(0.15, 0.40)),
	]
	var dot := Label.new()
	dot.text = icons[randi() % icons.size()]
	dot.add_theme_font_size_override("font_size", 8 + randi() % 18)
	dot.add_theme_color_override("font_color", colors[randi() % colors.size()])
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := get_viewport().get_visible_rect().size
	dot.position = Vector2(randf_range(0, vp.x), vp.y + 12)
	_particle_container.add_child(dot)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dot, "position:y",  dot.position.y - randf_range(150.0, 460.0),
		randf_range(6.0, 14.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dot, "position:x",  dot.position.x + randf_range(-45.0, 45.0),
		randf_range(6.0, 14.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dot, "modulate:a", 0.0, randf_range(5.0, 10.0)) \
		.set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(dot.queue_free)

# ── Logo (lower-right) ────────────────────────────────────────────────────────

func _build_logo():
	var logo_root := Control.new()
	# Anchor to lower-right quadrant
	logo_root.anchor_left   = 0.46
	logo_root.anchor_top    = 0.52
	logo_root.anchor_right  = 1.0
	logo_root.anchor_bottom = 0.92
	logo_root.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(logo_root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_root.add_child(vbox)

	# Small rune above title
	var rune := Label.new()
	rune.text = "✦  ·  ·  ✦  ·  ·  ✦"
	rune.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rune.add_theme_font_size_override("font_size", 11)
	rune.add_theme_color_override("font_color", Color(C_BORDER, 0.5))
	rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rune)

	# "HABITAT" title
	_title_label = Label.new()
	_title_label.text = "HABITAT"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 82)
	_title_label.add_theme_color_override("font_color", C_ACCENT)
	_title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.18, 0.85))
	_title_label.add_theme_constant_override("outline_size", 5)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	# Subtitle
	var sub := Label.new()
	sub.text = "a wildlife sanctuary"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(C_DIM, 0.80))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub)

# ── Menu items (lower-left) ───────────────────────────────────────────────────

func _build_menu():
	_menu_root = Control.new()
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_root)

	# Container anchored to lower-left
	var col := VBoxContainer.new()
	col.anchor_left   = 0.0
	col.anchor_top    = 1.0
	col.anchor_right  = 0.0
	col.anchor_bottom = 1.0
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(col)

	# We'll use a MarginContainer to position from the bottom
	var margin := MarginContainer.new()
	margin.anchor_left   = 0.0
	margin.anchor_top    = 0.62
	margin.anchor_right  = 0.44
	margin.anchor_bottom = 0.96
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_bottom", 72)
	_menu_root.add_child(margin)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_END
	inner.add_theme_constant_override("separation", 0)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(inner)

	# ── Main items ────────────────────────────────────────────────────────────
	for i in MENU_ITEMS.size():
		var data = MENU_ITEMS[i]
		var label: String  = data[0]
		var cb_name: String = data[1]
		var is_danger: bool = data[2]
		var needs_save: bool = data[3]
		var disabled: bool = needs_save and not _save_exists

		var btn := _make_item_btn(label, disabled, is_danger, i)
		btn.pressed.connect(Callable(self, cb_name))
		inner.add_child(btn)
		_item_btns.append(btn)

	# Small separator gap
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	inner.add_child(gap)

	# ── Settings row (like Halo 3's "Settings" at bottom) ─────────────────────
	var settings_btn := _make_settings_btn()
	inner.add_child(settings_btn)

	# ── Quit (danger, below settings) ─────────────────────────────────────────
	var quit_row := _make_quit_btn()
	inner.add_child(quit_row)

	# ── Version — very bottom-left ─────────────────────────────────────────────
	var ver_root := Control.new()
	ver_root.anchor_left   = 0.0
	ver_root.anchor_top    = 1.0
	ver_root.anchor_right  = 0.3
	ver_root.anchor_bottom = 1.0
	ver_root.offset_top    = -22
	_menu_root.add_child(ver_root)

	var ver := Label.new()
	ver.text = "Early Build · v0.1"
	ver.position = Vector2(136, 0)
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", Color(C_DIM, 0.35))
	ver_root.add_child(ver)

	# Highlight the first item
	_set_selected(_selected_idx)

# ── Item button factory ───────────────────────────────────────────────────────

func _make_item_btn(label: String, disabled: bool, is_danger: bool, idx: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(400, 52)
	btn.disabled = disabled

	# We use StyleBoxFlat for all states; _set_selected drives the look
	btn.add_theme_font_size_override("font_size", 24)
	btn.focus_mode = Control.FOCUS_NONE

	# Hover: enter selected state visually
	btn.mouse_entered.connect(func(): _set_selected(idx))

	# Store metadata
	btn.set_meta("idx", idx)
	btn.set_meta("danger", is_danger)
	btn.set_meta("disabled_item", disabled)

	_apply_item_style(btn, false)
	return btn

func _apply_item_style(btn: Button, selected: bool):
	var is_disabled: bool = btn.get_meta("disabled_item", false)
	var is_danger: bool   = btn.get_meta("danger", false)

	var text_col: Color
	var bg_col: Color

	if is_disabled:
		text_col = Color(C_DIM, 0.30)
		bg_col   = Color(0, 0, 0, 0)
	elif selected:
		text_col = C_TEXT if not is_danger else C_DANGER
		bg_col   = C_HILITE
	else:
		text_col = Color(C_DIM, 0.85)
		bg_col   = Color(0, 0, 0, 0)

	# Normal style
	var norm := StyleBoxFlat.new()
	norm.bg_color = bg_col
	if selected and not is_disabled:
		norm.border_color = C_HILITE_L
		norm.border_width_left = 4
	norm.set_corner_radius_all(0)
	norm.content_margin_left  = selected and not is_disabled and 60 or 64
	norm.content_margin_right = 20
	norm.content_margin_top   = 12
	norm.content_margin_bottom = 12

	btn.add_theme_stylebox_override("normal",   norm)
	btn.add_theme_stylebox_override("hover",    norm)
	btn.add_theme_stylebox_override("pressed",  norm)
	btn.add_theme_stylebox_override("disabled", norm)
	btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",          text_col)
	btn.add_theme_color_override("font_hover_color",    text_col)
	btn.add_theme_color_override("font_pressed_color",  text_col)
	btn.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.28))

func _set_selected(idx: int):
	_selected_idx = idx
	for i in _item_btns.size():
		_apply_item_style(_item_btns[i], i == idx)

func _make_settings_btn() -> Button:
	var btn := Button.new()
	btn.text = "▶  SETTINGS"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(400, 44)
	btn.focus_mode = Control.FOCUS_NONE

	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0, 0, 0, 0)
	norm.content_margin_left  = 64
	norm.content_margin_right = 20
	norm.content_margin_top   = 8
	norm.content_margin_bottom = 8

	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(C_HILITE.r, C_HILITE.g, C_HILITE.b, 0.65)
	hov.border_color = C_BORDER
	hov.border_width_left = 3
	hov.content_margin_left  = 61
	hov.content_margin_right = 20
	hov.content_margin_top   = 8
	hov.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",        Color(C_DIM, 0.75))
	btn.add_theme_color_override("font_hover_color",  C_ACCENT)
	btn.add_theme_color_override("font_pressed_color",C_ACCENT)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_settings)
	return btn

func _make_quit_btn() -> Button:
	var btn := Button.new()
	btn.text = "✕  QUIT"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(400, 44)
	btn.focus_mode = Control.FOCUS_NONE

	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0, 0, 0, 0)
	norm.content_margin_left  = 64
	norm.content_margin_right = 20
	norm.content_margin_top   = 8
	norm.content_margin_bottom = 8

	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.25, 0.02, 0.06, 0.70)
	hov.border_color = C_DANGER
	hov.border_width_left = 3
	hov.content_margin_left  = 61
	hov.content_margin_right = 20
	hov.content_margin_top   = 8
	hov.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",        Color(C_DIM, 0.50))
	btn.add_theme_color_override("font_hover_color",  C_DANGER)
	btn.add_theme_color_override("font_pressed_color",C_DANGER)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_quit)
	return btn

# ── Settings overlay ──────────────────────────────────────────────────────────

func _build_settings_panel():
	var script = load("res://scripts/settings_panel.gd")
	if not script:
		return
	_settings_panel = script.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	add_child(_settings_panel)
	if _settings_panel.has_signal("closed"):
		_settings_panel.closed.connect(_on_settings_closed)

# ── Keyboard navigation ───────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent):
	if not _menu_root.visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_set_selected(max(0, _selected_idx - 1))
			KEY_DOWN:
				_set_selected(min(_item_btns.size() - 1, _selected_idx + 1))
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not _item_btns[_selected_idx].disabled:
					_item_btns[_selected_idx].pressed.emit()

# ── Animations ────────────────────────────────────────────────────────────────

func _animate_in():
	_menu_root.modulate = Color(1, 1, 1, 0)
	create_tween().set_trans(Tween.TRANS_SINE) \
		.tween_property(_menu_root, "modulate:a", 1.0, 1.2)

func _start_title_pulse():
	if not _title_label:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_title_label, "modulate",
		Color(1.10, 0.90, 1.15), 2.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_title_label, "modulate",
		Color(0.88, 0.78, 1.00), 2.5).set_trans(Tween.TRANS_SINE)

# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_new_game():
	if Engine.has_singleton("SaveManager"):
		SaveManager.delete_save()
	_go_to_loading("res://scenes/garden.tscn")

func _on_continue():
	_go_to_loading("res://scenes/garden.tscn")

func _go_to_loading(target: String):
	_fade_out_then(func():
		# Pass the target scene to the loading screen via metadata on the tree
		get_tree().set_meta("loading_target", target)
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn"))

func _on_settings():
	create_tween().tween_property(_menu_root, "modulate:a", 0.0, 0.22)
	await get_tree().create_timer(0.22).timeout
	_menu_root.visible = false
	if _settings_panel:
		_settings_panel.modulate.a = 0.0
		_settings_panel.visible   = true
		create_tween().tween_property(_settings_panel, "modulate:a", 1.0, 0.28)

func _on_settings_closed():
	if _settings_panel:
		create_tween().tween_property(_settings_panel, "modulate:a", 0.0, 0.22)
		await get_tree().create_timer(0.22).timeout
		_settings_panel.visible = false
	_menu_root.modulate.a = 0.0
	_menu_root.visible    = true
	create_tween().tween_property(_menu_root, "modulate:a", 1.0, 0.28)

func _on_quit():
	_fade_out_then(get_tree().quit)

func _fade_out_then(callback: Callable):
	create_tween().tween_property(self, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.4).timeout
	callback.call()
