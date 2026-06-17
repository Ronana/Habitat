## torvald_manager.gd — Autoload singleton.
## Manages Torvald the Wandering Carpenter's visit schedule.
##
## Visit cadence (real seconds, since DayNightManager has no day counter):
##   - Wait  randf_range(3, 5) * day_length_seconds  between visits  (12–20 min)
##   - Visit lasts  1 * day_length_seconds  (4 minutes = 1 game day)
##
## On visit start: Torvald spawns at a random boundary point, faces inward.
## On visit end:   Torvald disappears (queue_free) after a farewell.
extends Node

# ── Config ─────────────────────────────────────────────────────────────────────
const TORVALD_SCENE   := "res://scenes/torvald.tscn"
const SPAWN_RADIUS    := 14.0   # distance from garden centre to spawn at
const FACE_INWARD     := true

# ── State ──────────────────────────────────────────────────────────────────────
var _visit_timer     : float = 0.0
var _next_visit_wait : float = 0.0
var _in_visit        : bool  = false
var _torvald_node    : Node3D = null
var _garden_node     : Node3D = null   # set by garden.gd on ready

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_schedule_next_visit()

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_visit_timer += delta

	if not _in_visit:
		# Waiting for next visit
		if _visit_timer >= _next_visit_wait:
			_start_visit()
	else:
		# During visit — stay for one game day
		var stay_duration: float = DayNightManager.day_length_seconds
		if _visit_timer >= stay_duration:
			_end_visit()

# ── Visit lifecycle ────────────────────────────────────────────────────────────
func _schedule_next_visit() -> void:
	_visit_timer      = 0.0
	_next_visit_wait  = randf_range(3.0, 5.0) * DayNightManager.day_length_seconds
	_in_visit         = false

func _start_visit() -> void:
	if _torvald_node != null:
		return  # already here

	var scene: PackedScene = load(TORVALD_SCENE)
	if not scene:
		push_warning("TorvaldManager: could not load " + TORVALD_SCENE)
		return

	_torvald_node = scene.instantiate() as Node3D
	if not _torvald_node:
		return

	# Spawn at a random point on the boundary ring
	var angle := randf() * TAU
	var spawn_pos := Vector3(cos(angle) * SPAWN_RADIUS, 0.5, sin(angle) * SPAWN_RADIUS)
	_torvald_node.position = spawn_pos

	# Add to scene first — look_at() requires being in the tree
	var target_parent: Node = _garden_node if _garden_node else get_tree().current_scene
	target_parent.add_child(_torvald_node)

	if FACE_INWARD:
		_torvald_node.look_at(Vector3(0, spawn_pos.y, 0), Vector3.UP)

	_in_visit    = true
	_visit_timer = 0.0

## Called by garden.gd or any system that wants to force a visit (e.g. dev console).
func force_visit() -> void:
	_visit_timer     = _next_visit_wait  # tick over into visit immediately
	_next_visit_wait = 0.0

func _end_visit() -> void:
	if is_instance_valid(_torvald_node):
		_torvald_node.queue_free()
	_torvald_node = null
	_schedule_next_visit()

# ── Query ──────────────────────────────────────────────────────────────────────
func is_visiting() -> bool:
	return _in_visit and is_instance_valid(_torvald_node)

func get_torvald() -> Node3D:
	if is_visiting():
		return _torvald_node
	return null

## Register the garden so Torvald spawns as its child (correct scene tree position).
func register_garden(garden: Node3D) -> void:
	_garden_node = garden
