## freecam.gd — developer fly camera.
## Spawned by DevConsole when "enable freecam" is entered.
## Attach to a Camera3D node.
extends Camera3D

const SPEED_NORMAL := 10.0
const SPEED_FAST   := 30.0
const MOUSE_SENS   := 0.003

var _yaw   : float = 0.0
var _pitch : float = 0.0

## Set by DevConsole after spawning so freecam can check if console is open.
var console = null

func _ready() -> void:
	# Inherit the position/rotation of whatever camera is currently active
	# before we steal 'current'.
	var prev := get_viewport().get_camera_3d()
	if prev and prev != self:
		global_transform = prev.global_transform
	_yaw   = rotation.y
	_pitch = rotation.x
	make_current()

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	if _console_open():
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	_yaw   -= motion.relative.x * MOUSE_SENS
	_pitch -= motion.relative.y * MOUSE_SENS
	_pitch  = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
	rotation = Vector3(_pitch, _yaw, 0.0)

func _process(delta: float) -> void:
	if _console_open():
		return
	var speed := SPEED_FAST if Input.is_key_pressed(KEY_SHIFT) else SPEED_NORMAL
	var dir   := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += global_transform.basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	if dir != Vector3.ZERO:
		global_position += dir.normalized() * speed * delta

func _console_open() -> bool:
	return console != null and console._open
