## doc_birtle_manager.gd — Autoload singleton.
## Schedules Doc Birtle's visits to the garden.
## He visits more frequently than Torvald or Gus — his role is reactive to
## roamer health crises, so a 2–3 day interval keeps him accessible.
extends Node

const DOC_SCENE    := "res://scenes/doc_birtle.tscn"
const SPAWN_RADIUS := 14.0

var _visit_timer     : float  = 0.0
var _next_visit_wait : float  = 0.0
var _in_visit        : bool   = false
var _doc_node        : Node3D = null
var _garden_node     : Node3D = null

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_schedule_next_visit()

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_visit_timer += delta
	if not _in_visit:
		if _visit_timer >= _next_visit_wait:
			_start_visit()
	else:
		if _visit_timer >= DayNightManager.day_length_seconds:
			_end_visit()

# ── Visit lifecycle ────────────────────────────────────────────────────────────
func _schedule_next_visit() -> void:
	_visit_timer     = 0.0
	_next_visit_wait = randf_range(2.0, 3.0) * DayNightManager.day_length_seconds
	_in_visit        = false

func _start_visit() -> void:
	if _doc_node != null:
		return
	var scene: PackedScene = load(DOC_SCENE)
	if not scene:
		push_warning("DocBirtleManager: could not load " + DOC_SCENE)
		return
	_doc_node = scene.instantiate() as Node3D
	if not _doc_node:
		return
	var angle := randf() * TAU
	var spawn_pos := Vector3(cos(angle) * SPAWN_RADIUS, 0.5, sin(angle) * SPAWN_RADIUS)
	_doc_node.position = spawn_pos
	var target: Node = _garden_node if _garden_node else get_tree().current_scene
	target.add_child(_doc_node)
	_doc_node.look_at(Vector3(0, spawn_pos.y, 0), Vector3.UP)
	_in_visit    = true
	_visit_timer = 0.0

func _end_visit() -> void:
	if is_instance_valid(_doc_node):
		_doc_node.queue_free()
	_doc_node = null
	_schedule_next_visit()

func force_visit() -> void:
	_visit_timer     = _next_visit_wait
	_next_visit_wait = 0.0

func is_visiting() -> bool:
	return _in_visit and is_instance_valid(_doc_node)

func register_garden(garden: Node3D) -> void:
	_garden_node = garden
