## gus_manager.gd — Autoload singleton.
## Tracks Gus the Groundskeeper's purchased upgrades and exposes
## multiplier getters that the rest of the game queries.
##
## Visit cadence mirrors TorvaldManager:
##   wait  randf_range(4, 6) * day_length_seconds  between visits  (16–24 min)
##   stay  1 * day_length_seconds  (4 minutes = 1 game day)
##
## Gus visits slightly less frequently than Torvald — his upgrades are
## permanent, so the anticipation is part of the reward.
extends Node

# ── Upgrade IDs ────────────────────────────────────────────────────────────────
const UPGRADE_SEASONED_SHOVEL  := "seasoned_shovel"
const UPGRADE_GENEROUS_WELLS   := "generous_wells"
const UPGRADE_HARDY_STOCK      := "hardy_stock"
const UPGRADE_WIDE_BERTH       := "wide_berth"
const UPGRADE_WARM_WELCOME     := "warm_welcome"
const UPGRADE_DEEP_POCKETS     := "deep_pockets"

# ── State ──────────────────────────────────────────────────────────────────────
var purchased: Array = []   # Array[String] of upgrade IDs

var _visit_timer     : float = 0.0
var _next_visit_wait : float = 0.0
var _in_visit        : bool  = false
var _gus_node        : Node3D = null
var _garden_node     : Node3D = null

const GUS_SCENE    := "res://scenes/gus.tscn"
const SPAWN_RADIUS := 14.0

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
	_next_visit_wait = randf_range(4.0, 6.0) * DayNightManager.day_length_seconds
	_in_visit        = false

func _start_visit() -> void:
	if _gus_node != null:
		return
	var scene: PackedScene = load(GUS_SCENE)
	if not scene:
		push_warning("GusManager: could not load " + GUS_SCENE)
		return
	_gus_node = scene.instantiate() as Node3D
	if not _gus_node:
		return
	var angle := randf() * TAU
	var spawn_pos := Vector3(cos(angle) * SPAWN_RADIUS, 0.5, sin(angle) * SPAWN_RADIUS)
	_gus_node.position = spawn_pos
	var target: Node = _garden_node if _garden_node else get_tree().current_scene
	target.add_child(_gus_node)
	_gus_node.look_at(Vector3(0, spawn_pos.y, 0), Vector3.UP)
	_in_visit    = true
	_visit_timer = 0.0

func _end_visit() -> void:
	if is_instance_valid(_gus_node):
		_gus_node.queue_free()
	_gus_node = null
	_schedule_next_visit()

func force_visit() -> void:
	_visit_timer     = _next_visit_wait
	_next_visit_wait = 0.0

func is_visiting() -> bool:
	return _in_visit and is_instance_valid(_gus_node)

func get_gus() -> Node3D:
	return _gus_node if is_visiting() else null

func register_garden(garden: Node3D) -> void:
	_garden_node = garden

# ── Upgrade purchase ───────────────────────────────────────────────────────────
func has_upgrade(id: String) -> bool:
	return purchased.has(id)

func buy_upgrade(id: String) -> void:
	if not purchased.has(id):
		purchased.append(id)
		# Apply Deep Pockets immediately as a one-time bonus
		if id == UPGRADE_DEEP_POCKETS:
			CurrencyManager.add_dewdrops(50.0)

# ── Multiplier getters — queried by tool_manager, berry_bush, garden, etc. ────

## Shovel dig/raise radius multiplier.
func shovel_radius_mult() -> float:
	return 1.4 if has_upgrade(UPGRADE_SEASONED_SHOVEL) else 1.0

## Bonded roamer dewdrop income multiplier.
func dewdrop_income_mult() -> float:
	return 1.25 if has_upgrade(UPGRADE_GENEROUS_WELLS) else 1.0

## Berry bush food depletion rate multiplier (< 1 = slower depletion).
func bush_depletion_mult() -> float:
	return 0.70 if has_upgrade(UPGRADE_HARDY_STOCK) else 1.0

## Placement clearance radius multiplier (< 1 = tighter packing).
func placement_radius_mult() -> float:
	return 0.80 if has_upgrade(UPGRADE_WIDE_BERTH) else 1.0

## Wild roamer visit interval multiplier (< 1 = visits arrive sooner).
func visit_interval_mult() -> float:
	return 0.70 if has_upgrade(UPGRADE_WARM_WELCOME) else 1.0
