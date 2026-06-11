extends Camera3D

# Movement
var move_speed: float = 20.0
var edge_scroll_speed: float = 15.0
var edge_margin: float = 20.0
var use_edge_scroll: bool = true

# Rotation
var is_rotating: bool = false
var rotation_speed: float = 0.3
var current_yaw: float = 0.0
var current_pitch: float = -35.0
var min_pitch: float = -70.0
var max_pitch: float = -10.0

# Zoom
var zoom_speed: float = 3.0
var min_zoom: float = 5.0
var max_zoom: float = 60.0
var target_zoom: float = 25.0
var current_zoom: float = 25.0

# Panning with middle mouse
var is_panning: bool = false
var pan_speed: float = 0.05

# Smoothing
var smooth_speed: float = 8.0

# Target values — no pivot needed
var target_position: Vector3 = Vector3(0, 25, 35)
var focus_point: Vector3 = Vector3(0, 0, 0)

func _ready():
	target_position = global_position
	_update_camera_transform()
	_apply_settings()
	if SettingsManager:
		SettingsManager.settings_changed.connect(_apply_settings)

func _apply_settings():
	move_speed      = SettingsManager.get_setting("cam_move_speed",     20.0)
	zoom_speed      = SettingsManager.get_setting("cam_zoom_speed",      3.0)
	pan_speed       = SettingsManager.get_setting("cam_pan_speed",       0.05)
	rotation_speed  = SettingsManager.get_setting("cam_rotation_speed",  0.3)
	use_edge_scroll = SettingsManager.get_setting("cam_edge_scroll",     true)
	# cam_invert_y is read live in _unhandled_input

func _process(delta):
	handle_keyboard_pan(delta)
	handle_edge_scroll(delta)
	handle_zoom(delta)
	
	# Smooth position
	global_position = global_position.lerp(target_position, smooth_speed * delta)
	look_at(focus_point, Vector3.UP)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating = event.pressed
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = max(min_zoom, target_zoom - zoom_speed)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = min(max_zoom, target_zoom + zoom_speed)

	if event is InputEventMouseMotion:
		if is_rotating:
			var invert_y: bool = SettingsManager.get_setting("cam_invert_y", false)
			current_yaw   -= event.relative.x * rotation_speed
			current_pitch -= event.relative.y * rotation_speed * (-1.0 if invert_y else 1.0)
			current_pitch  = clamp(current_pitch, min_pitch, max_pitch)
		if is_panning:
			var right = global_transform.basis.x
			var forward = Vector3(
				global_transform.basis.z.x,
				0,
				global_transform.basis.z.z
			).normalized()
			focus_point += right * event.relative.x * pan_speed * (current_zoom / 10.0)
			focus_point += forward * event.relative.y * pan_speed * (current_zoom / 10.0)

func handle_keyboard_pan(delta):
	var right = Vector3(sin(deg_to_rad(current_yaw + 90)), 0, cos(deg_to_rad(current_yaw + 90)))
	var forward = Vector3(sin(deg_to_rad(current_yaw + 180)), 0, cos(deg_to_rad(current_yaw + 180)))
	var speed = move_speed * delta

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		focus_point += right * speed
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		focus_point -= right * speed
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		focus_point += forward * speed
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		focus_point -= forward * speed

func handle_edge_scroll(delta):
	if not use_edge_scroll:
		return
	var viewport_rect = get_viewport().get_visible_rect()
	var mouse_pos = get_viewport().get_mouse_position()
	var speed = edge_scroll_speed * delta
	var right = Vector3(sin(deg_to_rad(current_yaw + 90)), 0, cos(deg_to_rad(current_yaw + 90)))
	var forward = Vector3(sin(deg_to_rad(current_yaw + 180)), 0, cos(deg_to_rad(current_yaw + 180)))

	if mouse_pos.x < edge_margin:
		focus_point -= right * speed
	if mouse_pos.x > viewport_rect.size.x - edge_margin:
		focus_point += right * speed
	if mouse_pos.y < edge_margin:
		focus_point += forward * speed
	if mouse_pos.y > viewport_rect.size.y - edge_margin:
		focus_point -= forward * speed

func handle_zoom(delta):
	current_zoom = lerp(current_zoom, target_zoom, smooth_speed * delta)
	_update_camera_transform()

func _update_camera_transform():
	var yaw_rad = deg_to_rad(current_yaw)
	var pitch_rad = deg_to_rad(current_pitch)
	var offset = Vector3(
		sin(yaw_rad) * cos(pitch_rad),
		-sin(pitch_rad),
		cos(yaw_rad) * cos(pitch_rad)
	) * current_zoom
	target_position = focus_point + offset
