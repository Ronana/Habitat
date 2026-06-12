## tool_carrier.gd — 3D tool that floats beside the player cursor.
## Attach to a Node3D in the garden scene.  Call set_tool(id) to switch.
extends Node3D

# ── Constants ─────────────────────────────────────────────────────────────────
const SHOVEL_PATH := "res://assets/models/exported/shovel_basic.glb"

# Offset from the terrain hit point (camera-relative right + world up)
const OFFSET_RIGHT  := 1.10   # world units to the camera's right
const OFFSET_UP     := 2.50   # world units above terrain hit
const OFFSET_TOWARD := 0.30   # world units toward the camera

# Float animation
const BOB_SPEED    := 2.40    # rad/s
const BOB_AMP      := 0.165   # world units
const TILT_SPEED   := 1.70    # rad/s
const TILT_AMP     := 0.055   # radians
const DRIFT_SPEED  := 1.20    # subtle XZ drift speed
const DRIFT_AMP    := 0.020   # world units

# Position smoothing
const LERP_SPEED   := 10.0

# ── State ─────────────────────────────────────────────────────────────────────
var _tool_id    : String   = ""
var _model      : Node3D   = null
var _time       : float    = 0.0
var _camera     : Camera3D = null
var _target_pos : Vector3  = Vector3.ZERO
var _active     : bool     = false

# ── Public API ────────────────────────────────────────────────────────────────
func set_tool(tool_id: String) -> void:
	if _tool_id == tool_id:
		return
	_tool_id = tool_id

	# Remove previous model
	if _model:
		_model.queue_free()
		_model = null

	match tool_id:
		"shovel":
			var scene := load(SHOVEL_PATH) as PackedScene
			if scene:
				_model = scene.instantiate()
				add_child(_model)
				# Orient so the shovel faces the right way (blade down, handle up)
				_model.rotation_degrees = Vector3(-15.0, -35.0, 0.0)
				_model.scale = Vector3(0.04, 0.04, 0.04)
				_active = true
		_:
			_active = false

	visible = _active

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if not _active or not _model:
		return

	_time += delta
	_camera = get_viewport().get_camera_3d()
	if not _camera:
		return

	# ── Find world hit point under mouse ──────────────────────────────────────
	var mouse    := get_viewport().get_mouse_position()
	var ray_orig := _camera.project_ray_origin(mouse)
	var ray_dir  := _camera.project_ray_normal(mouse)

	# Intersect with horizontal plane at y=0 first, then adjust with terrain
	var plane  := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(ray_orig, ray_dir)

	if hit == null:
		# Ray is parallel to plane — stay at last known position
		hit = _target_pos

	# ── Compute offset position ───────────────────────────────────────────────
	var cam_right   := _camera.global_transform.basis.x.normalized()
	var cam_forward := -_camera.global_transform.basis.z.normalized()

	var xz_hit := (hit as Vector3) + cam_right * OFFSET_RIGHT - cam_forward * OFFSET_TOWARD

	# Raycast straight down to find actual terrain height at that XZ position
	var space := get_world_3d().direct_space_state
	var ray_params := PhysicsRayQueryParameters3D.create(
		xz_hit + Vector3.UP * 20.0,
		xz_hit + Vector3.DOWN * 20.0
	)
	ray_params.collision_mask = 0xFFFFFFFF   # all layers
	var result := space.intersect_ray(ray_params)
	var ground_y: float = xz_hit.y
	if not result.is_empty():
		ground_y = (result["position"] as Vector3).y

	_target_pos = Vector3(xz_hit.x, ground_y + OFFSET_UP, xz_hit.z)

	# ── Smooth follow ─────────────────────────────────────────────────────────
	global_position = global_position.lerp(_target_pos, LERP_SPEED * delta)

	# ── Float animation on the model (local space) ────────────────────────────
	# Gentle bob up/down
	_model.position.y = sin(_time * BOB_SPEED) * BOB_AMP

	# Subtle forward tilt — like the tool is alive
	_model.rotation.x = deg_to_rad(-15.0) + sin(_time * TILT_SPEED) * TILT_AMP

	# Very slight XZ drift to feel weightless
	_model.position.x = sin(_time * DRIFT_SPEED + 1.3) * DRIFT_AMP
	_model.position.z = cos(_time * DRIFT_SPEED * 0.7) * DRIFT_AMP * 0.5


	# ── Face the camera (yaw only) so the tool is always readable ─────────────
	var to_cam_xz := Vector3(
		_camera.global_position.x - global_position.x,
		0.0,
		_camera.global_position.z - global_position.z
	).normalized()
	if to_cam_xz.length_squared() > 0.01:
		var target_yaw := atan2(to_cam_xz.x, to_cam_xz.z)
		rotation.y     = lerp_angle(rotation.y, target_yaw, delta * 4.0)
