extends Camera3D

var move_speed = 20.0
var zoom_speed = 5.0
var min_zoom = 5.0
var max_zoom = 40.0

func _process(delta):
	# Move camera with WASD or arrow keys
	if Input.is_action_pressed("ui_right"):
		position.x += move_speed * delta
	if Input.is_action_pressed("ui_left"):
		position.x -= move_speed * delta
	if Input.is_action_pressed("ui_up"):
		position.z -= move_speed * delta
	if Input.is_action_pressed("ui_down"):
		position.z += move_speed * delta

func _input(event):
	# Zoom with scroll wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position.y = max(min_zoom, position.y - zoom_speed)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position.y = min(max_zoom, position.y + zoom_speed)
