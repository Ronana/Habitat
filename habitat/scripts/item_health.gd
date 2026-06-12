## ItemHealth — add as a child Node3D to any selectable world item.
##
## Responsibilities:
##   • Love-heart health display (Label3D billboards, stacked vertically)
##   • Glowing selection ring (TorusMesh flat on the ground)
##   • take_hit()  → decrements health, returns true when destroyed
##   • show_select(bool) → shows / hides ring + hearts

extends Node3D

# ── Tunables ──────────────────────────────────────────────────────────────────
const HEART_FULL        := "❤"
const HEART_EMPTY       := "♡"
const COLOR_FULL        := Color(1.00, 0.18, 0.22)
const COLOR_EMPTY       := Color(0.28, 0.28, 0.28, 0.60)
const HEART_SPACING     := 0.44   # world units between heart slots (bottom → top)
const FONT_SIZE         := 56

# ── State ─────────────────────────────────────────────────────────────────────
var max_hits     : int = 1
var current_hits : int = 1

var _hearts      : Array = []          # Array[Label3D]
var _ring        : MeshInstance3D = null

# ── Public API ────────────────────────────────────────────────────────────────

## Call once after add_child() to initialise with the correct hit count.
func setup(hits: int) -> void:
	max_hits     = hits
	current_hits = hits
	_build_ring()
	_build_hearts()
	_refresh_hearts()
	_set_hearts_visible(false)
	if _ring:
		_ring.visible = false

## Show / hide the selection ring and hearts together.
func show_select(on: bool) -> void:
	if _ring:
		_ring.visible = on
	_set_hearts_visible(on)

## Deal one hit. Returns true when the item has been destroyed.
func take_hit() -> bool:
	current_hits = max(0, current_hits - 1)
	_refresh_hearts()
	_set_hearts_visible(true)
	_pulse()
	return current_hits <= 0

# ── Internal builders ─────────────────────────────────────────────────────────

func _build_hearts() -> void:
	for h in _hearts:
		h.queue_free()
	_hearts.clear()

	var base_y := _item_height() + 0.15

	for i in range(max_hits):
		var lbl := Label3D.new()
		lbl.font_size       = FONT_SIZE
		lbl.billboard       = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test   = true
		lbl.render_priority = 1
		# Index 0 = bottom heart, higher index = higher up
		lbl.position = Vector3(0.0, base_y + float(i) * HEART_SPACING, 0.0)
		add_child(lbl)
		_hearts.append(lbl)

func _ring_radius() -> float:
	var parent := get_parent()
	if not parent:
		return 0.80
	# Prefer CollisionShape3D — most reliable footprint source
	for child in parent.get_children():
		if child is CollisionShape3D:
			var shape := (child as CollisionShape3D).shape
			if shape is SphereShape3D:
				return clampf((shape as SphereShape3D).radius * 1.15, 0.5, 4.0)
			elif shape is BoxShape3D:
				var ext := (shape as BoxShape3D).size / 2.0
				return clampf(max(ext.x, ext.z) * 1.15, 0.5, 4.0)
			elif shape is CapsuleShape3D:
				return clampf((shape as CapsuleShape3D).radius * 1.15, 0.5, 4.0)
	# Fall back to the largest MeshInstance3D XZ footprint
	for child in parent.get_children():
		if child is MeshInstance3D:
			var aabb := (child as MeshInstance3D).get_aabb()
			var r: float = max(aabb.size.x, aabb.size.z) * 0.5
			if r > 0.1:
				return clampf(r * 1.1, 0.5, 4.0)
	# Group-based fallbacks
	if parent.is_in_group("trees"):    return 1.5
	if parent.is_in_group("shelters"): return 1.2
	return 0.80

func _build_ring() -> void:
	var r     := _ring_radius()
	var mi    := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius  = r * 0.80
	torus.outer_radius  = r
	torus.rings         = 24
	torus.ring_segments = 24
	mi.mesh       = torus
	mi.position.y = 0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = Color(1.0, 0.93, 0.28)
	mat.emission_enabled = true
	mat.emission         = Color(1.0, 0.85, 0.10) * 2.2
	mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.set_surface_override_material(0, mat)
	add_child(mi)
	_ring = mi

# ── Internal helpers ──────────────────────────────────────────────────────────

func _refresh_hearts() -> void:
	for i in range(_hearts.size()):
		var lbl : Label3D = _hearts[i]
		if i < current_hits:
			lbl.text     = HEART_FULL
			lbl.modulate = COLOR_FULL
		else:
			lbl.text     = HEART_EMPTY
			lbl.modulate = COLOR_EMPTY

func _set_hearts_visible(v: bool) -> void:
	for lbl in _hearts:
		lbl.visible = v

func _pulse() -> void:
	# Brief scale pop so the player feels the hit
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.30, 1.30, 1.30), 0.06)
	tw.tween_property(self, "scale", Vector3(1.00, 1.00, 1.00), 0.11)

func _item_height() -> float:
	var parent := get_parent()
	if not parent:
		return 1.0
	if parent.is_in_group("trees"):
		return 2.6
	if parent.is_in_group("shelters"):
		return 1.5
	# Try to measure from a MeshInstance3D child
	for child in parent.get_children():
		if child is MeshInstance3D:
			var mi    := child as MeshInstance3D
			var aabb  := mi.get_aabb()
			return max(0.5, aabb.size.y * mi.scale.y)
	return 1.1
