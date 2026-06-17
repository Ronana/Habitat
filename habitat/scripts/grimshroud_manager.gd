## GrimshroudManager — autoload.
## Manages the single Grimshroud entity that appears when a roamer becomes
## burdened and stalks them until they recover or depart.
extends Node

# ── State ─────────────────────────────────────────────────────────────────────
enum GState { HIDDEN, ENTERING, STALKING, RETREATING }

var _state: int = GState.HIDDEN
var _target: Node3D = null
var _node: Node3D = null          # the actual 3D entity added to the scene
var _stalk_speed: float = 0.55    # m/s while approaching / stalking
var _retreat_speed: float = 1.8   # m/s while retreating
var _time: float = 0.0            # for shader / bob animation

# ── API ───────────────────────────────────────────────────────────────────────

## Called by roamer_base when a roamer enters BURDENED state.
func set_target(roamer: Node3D) -> void:
	_target = roamer
	var needs_build: bool = not _node or not is_instance_valid(_node)
	if needs_build:
		_build_grimshroud()
	# Defer position/visibility until the node is actually inside the scene tree
	# (it was added with call_deferred, so it may not be ready yet)
	_place_grimshroud.call_deferred(roamer)

func _place_grimshroud(roamer: Node3D) -> void:
	if not _node or not is_instance_valid(_node):
		return
	if not _node.is_inside_tree():
		# Still not in tree — defer one more frame
		_place_grimshroud.call_deferred(roamer)
		return
	var half: float = _get_garden_half()
	var dir: Vector3 = roamer.global_position.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3(1, 0, 0)
	_node.global_position = dir * (half + 1.5)
	_node.global_position.y = 0.0
	_node.visible = true
	_state = GState.ENTERING

## Called when roamer recovers or departs.
func clear_target(roamer: Node3D) -> void:
	if _target != roamer:
		return
	_target = null
	_state = GState.RETREATING

# ── Internal ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _node or not is_instance_valid(_node):
		return
	_time += delta
	_animate_node(delta)

	match _state:
		GState.ENTERING, GState.STALKING:
			if not _target or not is_instance_valid(_target):
				_state = GState.RETREATING
				return
			var to_target: Vector3 = _target.global_position - _node.global_position
			to_target.y = 0.0
			var dist: float = to_target.length()
			# Speed up if target is departing
			var spd: float = _stalk_speed
			if _target.has_method("get") and _target.get("burden_state") == 2:  # DEPARTING
				spd = _stalk_speed * 2.2
			if dist > 3.0:
				_node.global_position += to_target.normalized() * spd * delta
				_state = GState.ENTERING
			else:
				_state = GState.STALKING   # loiter at distance
			# Always face the target
			if dist > 0.2:
				var look_pos: Vector3 = _target.global_position
				look_pos.y = _node.global_position.y
				_node.look_at(look_pos, Vector3.UP)

		GState.RETREATING:
			# Walk back toward the boundary edge
			var half: float = _get_garden_half() + 4.0
			var dir: Vector3 = _node.global_position.normalized()
			if dir.length_squared() < 0.01:
				dir = Vector3(1, 0, 0)
			var edge: Vector3 = dir * half
			edge.y = _node.global_position.y
			var to_edge: Vector3 = edge - _node.global_position
			if to_edge.length() > 0.8:
				_node.global_position += to_edge.normalized() * _retreat_speed * delta
			else:
				_node.visible = false
				_state = GState.HIDDEN

func _animate_node(delta: float) -> void:
	# Gentle hover bob
	_node.position.y = 0.05 + 0.06 * sin(_time * 1.3)
	# Slow rotation — always turning slightly
	_node.rotation.y += 0.3 * delta

func _get_garden_half() -> float:
	return ZoneManager.get_garden_half()

func _build_grimshroud() -> void:
	_node = Node3D.new()
	_node.name = "Grimshroud"

	# ── Cloak body — tapered cylinder (wide base, narrow top) ─────────────────
	var body_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.18
	cyl.bottom_radius = 0.55
	cyl.height        = 1.8
	body_mesh.mesh = cyl
	body_mesh.position = Vector3(0, 0.9, 0)
	body_mesh.set_surface_override_material(0, _dark_mat(Color(0.04, 0.02, 0.08), Color(0.18, 0.05, 0.28), 0.6))
	_node.add_child(body_mesh)

	# ── Head — dark sphere ─────────────────────────────────────────────────────
	var head_mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	head_mesh.mesh = sph
	head_mesh.position = Vector3(0, 2.0, 0)
	head_mesh.set_surface_override_material(0, _dark_mat(Color(0.06, 0.04, 0.10), Color(0.0, 0.0, 0.0), 0.0))
	_node.add_child(head_mesh)

	# ── Red eye glow ───────────────────────────────────────────────────────────
	var eye_light := OmniLight3D.new()
	eye_light.position          = Vector3(0, 2.0, 0.18)
	eye_light.light_color       = Color(0.9, 0.1, 0.05)
	eye_light.light_energy      = 0.7
	eye_light.omni_range        = 2.5
	_node.add_child(eye_light)

	# ── Shadow tendrils — dark particles drifting downward ────────────────────
	var tendrils := CPUParticles3D.new()
	tendrils.amount              = 18
	tendrils.lifetime            = 1.8
	tendrils.explosiveness       = 0.0
	tendrils.spread              = 60.0
	tendrils.gravity             = Vector3(0, -0.4, 0)
	tendrils.initial_velocity_min = 0.1
	tendrils.initial_velocity_max = 0.4
	tendrils.scale_amount_min    = 0.05
	tendrils.scale_amount_max    = 0.14
	tendrils.color               = Color(0.15, 0.05, 0.25, 0.55)
	tendrils.position            = Vector3(0, 0.5, 0)
	_node.add_child(tendrils)

	# Add to scene — attach to the root so it persists regardless of garden state
	get_tree().get_root().add_child.call_deferred(_node)
	_node.visible = false

func _dark_mat(albedo: Color, emission: Color, emit_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = albedo
	mat.metallic                   = 0.0
	mat.roughness                  = 0.95
	mat.emission_enabled           = emit_energy > 0.0
	mat.emission                   = emission
	mat.emission_energy_multiplier = emit_energy
	return mat
