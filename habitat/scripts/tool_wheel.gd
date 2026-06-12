## tool_wheel.gd — Viva Piñata–style radial tool selector.
## Press Q to open/close. Hover over a slot and click to select.
## Emits tool_selected(tool_id: String) on selection.
extends CanvasLayer

signal tool_selected(tool_id: String)

# ── Tool definitions ──────────────────────────────────────────────────────────
const TOOLS: Array = [
	{"id": "hand",   "name": "Hand",   "letter": "H", "col": Color(0.60, 0.62, 0.65)},
	{"id": "shovel", "name": "Shovel", "letter": "S", "col": Color(0.78, 0.55, 0.12)},
]

# ── Layout constants ──────────────────────────────────────────────────────────
const WHEEL_R    := 120.0   # px — center-to-slot-center distance
const SLOT_R     := 46.0    # px — slot circle radius (half-size)
const DEAD_ZONE  := 38.0    # px — inside this = no hover (shows current tool)

# ── State ─────────────────────────────────────────────────────────────────────
var _open        := false
var _selected    := "hand"
var _hovered     := -1

# ── Node refs ─────────────────────────────────────────────────────────────────
var _root        : Control
var _dim         : ColorRect
var _slots       : Array = []   # Array of { bg, name_lbl, center }
var _center_lbl  : Label
var _hint_lbl    : Label        # "Q to close" hint

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 20          # above gameplay UI
	_build_ui()

func _build_ui() -> void:
	var vp_size := Vector2(1152, 648)   # safe fallback; updated on open
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	# ── Dark overlay ───────────────────────────────────────────────────────────
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	# ── Wheel background disc ─────────────────────────────────────────────────
	var disc_size := (WHEEL_R + SLOT_R + 18.0) * 2.0
	var disc := Panel.new()
	disc.name = "WheelDisc"
	disc.custom_minimum_size = Vector2(disc_size, disc_size)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc_sb := StyleBoxFlat.new()
	disc_sb.bg_color         = Color(0.08, 0.10, 0.09, 0.90)
	disc_sb.border_color     = Color(0.55, 0.72, 0.42, 0.55)
	disc_sb.set_border_width_all(2)
	var disc_r: int = int(disc_size / 2.0)
	disc_sb.corner_radius_top_left     = disc_r
	disc_sb.corner_radius_top_right    = disc_r
	disc_sb.corner_radius_bottom_left  = disc_r
	disc_sb.corner_radius_bottom_right = disc_r
	disc.add_theme_stylebox_override("panel", disc_sb)
	disc.name = "WheelDisc"
	_root.add_child(disc)

	# ── Center panel — shows selected tool name ───────────────────────────────
	var center_size := DEAD_ZONE * 2.0 + 8.0
	var center_bg := Panel.new()
	center_bg.custom_minimum_size = Vector2(center_size, center_size)
	center_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.18, 0.22, 0.18, 0.95)
	csb.border_color = Color(0.65, 0.82, 0.48, 0.70)
	csb.set_border_width_all(2)
	var cr: int = int(center_size / 2.0)
	csb.corner_radius_top_left     = cr
	csb.corner_radius_top_right    = cr
	csb.corner_radius_bottom_left  = cr
	csb.corner_radius_bottom_right = cr
	center_bg.add_theme_stylebox_override("panel", csb)
	center_bg.name = "CenterBg"
	_root.add_child(center_bg)

	_center_lbl = Label.new()
	_center_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_center_lbl.add_theme_font_size_override("font_size", 12)
	_center_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	center_bg.add_child(_center_lbl)

	# ── Tool slots ────────────────────────────────────────────────────────────
	var n := TOOLS.size()
	for i in range(n):
		var angle := (float(i) / float(n)) * TAU - PI / 2.0
		# Slot center relative to wheel center; absolute position set in open()
		var rel := Vector2(cos(angle), sin(angle)) * WHEEL_R

		# Slot background circle
		var slot_bg := Panel.new()
		slot_bg.custom_minimum_size = Vector2(SLOT_R * 2.0, SLOT_R * 2.0)
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_bg.pivot_offset = Vector2(SLOT_R, SLOT_R)   # scale from centre
		var ssb := StyleBoxFlat.new()
		ssb.bg_color         = TOOLS[i]["col"]
		ssb.border_color     = Color(1.0, 1.0, 1.0, 0.25)
		ssb.set_border_width_all(2)
		ssb.corner_radius_top_left     = int(SLOT_R)
		ssb.corner_radius_top_right    = int(SLOT_R)
		ssb.corner_radius_bottom_left  = int(SLOT_R)
		ssb.corner_radius_bottom_right = int(SLOT_R)
		slot_bg.add_theme_stylebox_override("panel", ssb)
		_root.add_child(slot_bg)

		# Letter label inside slot
		var letter_lbl := Label.new()
		letter_lbl.text = TOOLS[i]["letter"]
		letter_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		letter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		letter_lbl.add_theme_font_size_override("font_size", 22)
		letter_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		letter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_bg.add_child(letter_lbl)

		# Name label below slot
		var name_lbl := Label.new()
		name_lbl.text = TOOLS[i]["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 0.80))
		name_lbl.custom_minimum_size = Vector2(SLOT_R * 2.8, 20)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(name_lbl)

		_slots.append({
			"bg":       slot_bg,
			"name_lbl": name_lbl,
			"base_col": TOOLS[i]["col"],
			"rel":      rel,         # relative to wheel center
			"abs_ctr":  Vector2.ZERO # absolute — filled in _reposition()
		})

	# ── Hint label ────────────────────────────────────────────────────────────
	_hint_lbl = Label.new()
	_hint_lbl.text = "[Q] close"
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.60, 0.80))
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint_lbl)

# ── Open / close / toggle ──────────────────────────────────────────────────────
func open() -> void:
	_open    = true
	_hovered = -1
	_root.visible = true
	_reposition()
	_update_dim(0.0)
	_update_center_label()
	_refresh_slots()

func close() -> void:
	_open = false
	_root.visible = false

func toggle() -> void:
	if _open: close()
	else:     open()

func get_selected() -> String:
	return _selected

func set_selected(id: String) -> void:
	_selected = id
	_update_center_label()

# ── Position all nodes around viewport centre ──────────────────────────────────
func _reposition() -> void:
	var cx := get_viewport().get_visible_rect().size / 2.0

	# Wheel disc
	var disc: Panel = _root.get_node_or_null("WheelDisc")
	if disc:
		disc.position = cx - disc.custom_minimum_size / 2.0

	# Center bg
	var cbg: Panel = _root.get_node_or_null("CenterBg")
	if cbg:
		var cs := cbg.custom_minimum_size
		cbg.position = cx - cs / 2.0

	# Slots
	for i in range(_slots.size()):
		var s = _slots[i]
		var abs_ctr: Vector2 = cx + (s["rel"] as Vector2)
		s["abs_ctr"] = abs_ctr
		var bg: Panel = s["bg"]
		bg.position = abs_ctr - Vector2(SLOT_R, SLOT_R)
		var nl: Label = s["name_lbl"]
		nl.position = abs_ctr + Vector2(-SLOT_R * 1.4, SLOT_R + 6.0)

	# Hint label — below wheel
	var disc_r := (WHEEL_R + SLOT_R + 20.0)
	_hint_lbl.position = cx + Vector2(-50.0, disc_r + 4.0)
	_hint_lbl.custom_minimum_size = Vector2(100, 18)

	_update_dim(0.30)

func _update_dim(alpha: float) -> void:
	_dim.color.a = alpha

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# Toggle on Q
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()
			return
		if _open and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return

	if not _open:
		return

	# Click to select hovered slot
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hovered >= 0 and _hovered < TOOLS.size():
				_selected = TOOLS[_hovered]["id"]
				tool_selected.emit(_selected)
			close()
			get_viewport().set_input_as_handled()

# ── Process ───────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not _open:
		return
	_update_hover()

func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var cx    := get_viewport().get_visible_rect().size / 2.0

	# Dead zone = no hover (shows current selection label)
	if (mouse - cx).length() < DEAD_ZONE:
		_set_hovered(-1)
		return

	# Find closest slot
	var best := -1
	var best_d := INF
	for i in range(_slots.size()):
		var d: float = (mouse - (_slots[i]["abs_ctr"] as Vector2)).length()
		if d < best_d:
			best_d = d
			best   = i

	_set_hovered(best if best_d < WHEEL_R * 0.85 else -1)

func _set_hovered(idx: int) -> void:
	if _hovered == idx:
		return
	_hovered = idx
	_refresh_slots()
	_update_center_label()

func _refresh_slots() -> void:
	for i in range(_slots.size()):
		var s      = _slots[i]
		var bg     : Panel  = s["bg"]
		var base   : Color  = s["base_col"]
		var is_sel : bool   = (TOOLS[i]["id"] == _selected)
		var is_hov : bool   = (i == _hovered)

		var sb := bg.get_theme_stylebox("panel") as StyleBoxFlat
		if is_hov:
			sb.bg_color = base.lightened(0.30)
			sb.border_color = Color(1.0, 1.0, 0.8, 0.80)
			sb.set_border_width_all(3)
			bg.scale = Vector2(1.18, 1.18)
		elif is_sel:
			sb.bg_color = base.lightened(0.12)
			sb.border_color = Color(0.75, 0.95, 0.55, 0.80)
			sb.set_border_width_all(2)
			bg.scale = Vector2(1.0, 1.0)
		else:
			sb.bg_color = base
			sb.border_color = Color(1.0, 1.0, 1.0, 0.22)
			sb.set_border_width_all(2)
			bg.scale = Vector2(1.0, 1.0)

func _update_center_label() -> void:
	if not _center_lbl:
		return
	if _hovered >= 0 and _hovered < TOOLS.size():
		# Show hovered tool name in italics-style
		_center_lbl.text = TOOLS[_hovered]["name"]
		_center_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	else:
		# Show currently equipped tool
		for t in TOOLS:
			if t["id"] == _selected:
				_center_lbl.text = t["name"]
				_center_lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 0.60))
				break
