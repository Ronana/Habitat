## shovel_menu.gd — small radial context menu shown on shovel left-click.
## Opens at the mouse position. Emits action_selected(id) on pick.
extends CanvasLayer

signal action_selected(action: String)   # "dig" | "fill" | "pond" | "smash"

const BASE_ACTIONS: Array = [
	{"id": "dig",   "label": "Dig Ground",    "letter": "D", "col": Color(0.55, 0.38, 0.18)},
	{"id": "fill",  "label": "Fill Ground",   "letter": "F", "col": Color(0.32, 0.58, 0.22)},
	{"id": "pond",  "label": "Dig Pond",      "letter": "P", "col": Color(0.18, 0.42, 0.72)},
]
const SMASH_ACTION: Dictionary = \
	{"id": "smash", "label": "Smash Object",  "letter": "S", "col": Color(0.72, 0.18, 0.18)}

# Active action list — rebuilt each time the menu opens
var ACTIONS: Array = []

const RING_R  := 68.0   # px — center to slot centre
const SLOT_R  := 30.0   # px — slot circle radius

var _open    := false
var _hovered := -1
var _root    : Control
var _slots   : Array = []
var _tip_lbl : Label

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 25   # above tool wheel (20)
	ACTIONS = BASE_ACTIONS.duplicate()
	_build_ui()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	# Tip label at centre — shows hovered action name
	_tip_lbl = Label.new()
	_tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_lbl.add_theme_font_size_override("font_size", 11)
	_tip_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 0.85))
	_tip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tip_lbl)

	_rebuild_slots()   # build initial 3-slot layout

# ── Open / close ──────────────────────────────────────────────────────────────
func open(at_mouse: Vector2, with_smash: bool = false) -> void:
	# Smashable item under cursor → show only the Smash action
	if with_smash:
		ACTIONS = [SMASH_ACTION]
	else:
		ACTIONS = BASE_ACTIONS.duplicate()
	_rebuild_slots()
	_open    = true
	_hovered = -1
	_root.visible = true
	_reposition(at_mouse)
	_refresh_slots()

func close() -> void:
	_open = false
	_root.visible = false

func _rebuild_slots() -> void:
	# Free old slot nodes
	for s in _slots:
		(s["bg"] as Panel).queue_free()
		(s["name_lbl"] as Label).queue_free()
	_slots.clear()

	for i in range(ACTIONS.size()):
		var angle := (float(i) / float(ACTIONS.size())) * TAU - PI / 2.0
		var rel   := Vector2(cos(angle), sin(angle)) * RING_R

		var bg := Panel.new()
		bg.custom_minimum_size = Vector2(SLOT_R * 2.0, SLOT_R * 2.0)
		bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		bg.pivot_offset        = Vector2(SLOT_R, SLOT_R)
		var sb := StyleBoxFlat.new()
		sb.bg_color     = ACTIONS[i]["col"]
		sb.border_color = Color(1.0, 1.0, 1.0, 0.30)
		sb.set_border_width_all(2)
		var sr := int(SLOT_R)
		sb.corner_radius_top_left     = sr
		sb.corner_radius_top_right    = sr
		sb.corner_radius_bottom_left  = sr
		sb.corner_radius_bottom_right = sr
		bg.add_theme_stylebox_override("panel", sb)
		_root.add_child(bg)

		var ltr := Label.new()
		ltr.text = ACTIONS[i]["letter"]
		ltr.set_anchors_preset(Control.PRESET_FULL_RECT)
		ltr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ltr.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		ltr.add_theme_font_size_override("font_size", 18)
		ltr.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		ltr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(ltr)

		var nlbl := Label.new()
		nlbl.text                 = ACTIONS[i]["label"]
		nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlbl.add_theme_font_size_override("font_size", 10)
		nlbl.add_theme_color_override("font_color", Color(0.88, 0.94, 0.80))
		nlbl.custom_minimum_size  = Vector2(SLOT_R * 3.0, 18)
		nlbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		_root.add_child(nlbl)

		_slots.append({
			"bg":       bg,
			"name_lbl": nlbl,
			"base_col": ACTIONS[i]["col"],
			"rel":      rel,
			"abs_ctr":  Vector2.ZERO,
		})

func _reposition(cx: Vector2) -> void:
	for i in range(_slots.size()):
		var s: Dictionary = _slots[i]
		var abs_ctr: Vector2 = cx + (s["rel"] as Vector2)
		s["abs_ctr"] = abs_ctr
		var bg: Panel = s["bg"]
		bg.position = abs_ctr - Vector2(SLOT_R, SLOT_R)
		var nl: Label = s["name_lbl"]
		nl.position = abs_ctr + Vector2(-SLOT_R * 1.5, SLOT_R + 4.0)
	_tip_lbl.position           = cx + Vector2(-50.0, -12.0)
	_tip_lbl.custom_minimum_size = Vector2(100, 20)

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _open:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hovered >= 0 and _hovered < ACTIONS.size():
				action_selected.emit(ACTIONS[_hovered]["id"])
			close()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			get_viewport().set_input_as_handled()

# ── Process ───────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not _open:
		return
	_update_hover()

func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var best  := -1
	var best_d := INF
	for i in range(_slots.size()):
		var d: float = (mouse - (_slots[i]["abs_ctr"] as Vector2)).length()
		if d < best_d:
			best_d = d
			best   = i
	_set_hovered(best if best_d < RING_R * 1.3 else -1)

func _set_hovered(idx: int) -> void:
	if _hovered == idx:
		return
	_hovered = idx
	_refresh_slots()
	_tip_lbl.text = (ACTIONS[idx]["label"] as String) if idx >= 0 else ""

func _refresh_slots() -> void:
	for i in range(_slots.size()):
		var s      : Dictionary = _slots[i]
		var bg     : Panel      = s["bg"]
		var base   : Color      = s["base_col"]
		var sb := bg.get_theme_stylebox("panel") as StyleBoxFlat
		if i == _hovered:
			sb.bg_color     = base.lightened(0.35)
			sb.border_color = Color(1.0, 1.0, 0.65, 0.90)
			sb.set_border_width_all(3)
			bg.scale = Vector2(1.22, 1.22)
		else:
			sb.bg_color     = base
			sb.border_color = Color(1.0, 1.0, 1.0, 0.25)
			sb.set_border_width_all(2)
			bg.scale = Vector2(1.0, 1.0)
