extends Node
## Reusable plant-growth component.
## Attach as a child of any plant node (berry_bush, etc.).
## The parent is scaled and tinted to reflect growth stage and hydration.

signal stage_changed(new_stage: int)
signal plant_wilting
signal plant_recovered
signal plant_died

enum Stage { SPROUT, GROWING, MATURE }

const STAGE_NAMES : Array  = ["Sprout", "Growing", "Mature"]
const STAGE_SCALES: Array  = [0.22,     0.60,      1.0    ]

# ── Timing (real seconds) ─────────────────────────────────────────────────────
const GROWTH_TIME    : float = 90.0   # seconds per stage when well-watered
const WATER_INTERVAL : float = 300.0  # must be watered at least once per 5 min
const WILT_GRACE     : float = 120.0  # 2 min grace before the plant dies

# ── State ─────────────────────────────────────────────────────────────────────
var stage            : int   = Stage.SPROUT
var growth_progress  : float = 0.0    # 0-1 within current stage
var time_dry         : float = 0.0    # seconds since last watered
var is_wilting       : bool  = false
var _wilt_progress   : float = 0.0    # 0-1; 1 = dead

# ── Cached mesh list (set by parent after build) ──────────────────────────────
var _meshes : Array = []

# ── Status UI ────────────────────────────────────────────────────────────────
var _ui_root    : Node3D   = null   # billboard container
var _ui_label   : Label3D  = null   # stage + water text
var _ui_timer   : float    = 0.0
const UI_UPDATE_INTERVAL : float = 1.0
const UI_STAGE_ICONS     : Array  = ["🌱", "🌿", "🌳"]

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_apply_stage_scale(false)
	_setup_ui()

func _process(delta: float) -> void:
	if is_wilting:
		_tick_wilt(delta)
	else:
		_tick_growth(delta)
	_apply_health_tint()
	_ui_timer += delta
	if _ui_timer >= UI_UPDATE_INTERVAL:
		_ui_timer = 0.0
		_update_ui()

# ── Public API ────────────────────────────────────────────────────────────────

func water() -> void:
	"""Called by the watering-can tool or any water interaction."""
	time_dry = 0.0
	if is_wilting:
		is_wilting    = false
		_wilt_progress = 0.0
		plant_recovered.emit()
		_update_ui()
	# Watering gives a small immediate growth boost
	if stage < Stage.MATURE:
		growth_progress = min(growth_progress + 0.08, 1.0)
	_update_ui()

func is_mature() -> bool:
	return stage == Stage.MATURE

func get_health_ratio() -> float:
	if is_wilting:
		return max(0.0, 1.0 - _wilt_progress)
	return clamp(1.0 - time_dry / WATER_INTERVAL, 0.15, 1.0)

func get_stage_name() -> String:
	return STAGE_NAMES[stage]

func register_meshes(meshes: Array) -> void:
	"""Parent passes its MeshInstance3D list so we can tint them."""
	_meshes = meshes

# ── Internal ──────────────────────────────────────────────────────────────────

func _tick_growth(delta: float) -> void:
	time_dry += delta

	# Check wilt threshold
	if time_dry >= WATER_INTERVAL:
		is_wilting = true
		plant_wilting.emit()
		_update_ui()
		return

	if stage >= Stage.MATURE:
		return

	# Growth rate scales with hydration (full rate when freshly watered, 10% when dry)
	var dry_ratio   : float = time_dry / WATER_INTERVAL
	var water_factor: float = lerp(1.0, 0.10, dry_ratio)
	growth_progress += delta * water_factor / GROWTH_TIME

	if growth_progress >= 1.0:
		growth_progress = 0.0
		stage           = min(stage + 1, Stage.MATURE)
		stage_changed.emit(stage)
		_apply_stage_scale(true)
		_update_ui()

func _tick_wilt(delta: float) -> void:
	_wilt_progress += delta / WILT_GRACE
	if _wilt_progress >= 1.0:
		plant_died.emit()

func _apply_stage_scale(animate: bool) -> void:
	var parent := get_parent() as Node3D
	if not parent:
		return
	var target: Vector3 = Vector3.ONE * (STAGE_SCALES[stage] as float)
	if animate:
		var tw := parent.create_tween()
		tw.tween_property(parent, "scale", target, 0.9)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		parent.scale = target

func _setup_ui() -> void:
	_ui_root = Node3D.new()
	_ui_root.name = "PlantStatusUI"
	get_parent().add_child(_ui_root)
	_ui_root.position = Vector3(0, 1.6, 0)

	_ui_label = Label3D.new()
	_ui_label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	_ui_label.no_depth_test = false
	_ui_label.font_size    = 22
	_ui_label.outline_size = 6
	_ui_label.modulate     = Color(1, 1, 1, 0.92)
	_ui_label.pixel_size   = 0.006
	_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui_root.add_child(_ui_label)

	_update_ui()

func _update_ui() -> void:
	if not is_instance_valid(_ui_label):
		return

	# Hide UI for healthy mature plants — nothing actionable to show
	var show_ui: bool = (stage < Stage.MATURE) or is_wilting or (time_dry > WATER_INTERVAL * 0.6)
	_ui_root.visible = show_ui
	if not show_ui:
		return

	# ── Water bar (5 segments) ───────────────────────────────────────────────
	var ratio        : float  = get_health_ratio()
	var filled_count : int    = int(round(ratio * 5.0))
	var bar          : String = ""
	for i in 5:
		bar += "█" if i < filled_count else "░"

	# ── Stage icon and name ──────────────────────────────────────────────────
	var icon  : String = UI_STAGE_ICONS[stage]
	var label : String = STAGE_NAMES[stage]

	# ── Status suffix ────────────────────────────────────────────────────────
	var status : String = ""
	if is_wilting:
		status = "\n⚠ Dying — water now!"
	elif time_dry > WATER_INTERVAL * 0.7:
		status = "\n💧 Thirsty"
	elif stage == Stage.MATURE:
		status = "\nHealthy"

	_ui_label.text = icon + " " + label + "\n[" + bar + "]" + status

	# ── Colour based on urgency ──────────────────────────────────────────────
	if is_wilting:
		_ui_label.modulate = Color(1.0, 0.40, 0.20, 0.95)
	elif time_dry > WATER_INTERVAL * 0.7:
		_ui_label.modulate = Color(1.0, 0.85, 0.25, 0.95)
	else:
		_ui_label.modulate = Color(0.85, 1.0, 0.85, 0.92)

func _apply_health_tint() -> void:
	if _meshes.is_empty():
		return
	var ratio := get_health_ratio()
	# Healthy = white tint (no shift); wilting = yellow → brown
	var tint := Color(
		1.0,
		lerp(0.55, 1.0, ratio),   # green drops toward 0.55 when dry
		lerp(0.15, 1.0, ratio),   # blue drops sharply
		1.0)
	for m in _meshes:
		if is_instance_valid(m):
			var mat := m.get_surface_override_material(0) as StandardMaterial3D
			if mat:
				mat.albedo_color = mat.albedo_color.lerp(tint, 0.08)
