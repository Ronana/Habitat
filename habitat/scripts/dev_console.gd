## dev_console.gd — in-game developer console.
## Toggle with tilde (~) key.
## Commands: devmode | enable freecam | disable freecam | help | clear
extends CanvasLayer

var _open    : bool      = false
var _devmode : bool      = false
var _freecam : Camera3D  = null

@onready var _panel  : PanelContainer = $Panel
@onready var _output : RichTextLabel  = $Panel/VBox/Output
@onready var _input_field  : LineEdit       = $Panel/VBox/Input

func _ready() -> void:
	_panel.visible = false
	_input_field.text_submitted.connect(_on_submitted)

func _input(event: InputEvent) -> void:
	# Tilde / grave accent — toggle console regardless of focus
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_QUOTELEFT:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		# Pause freecam mouse look while console is up
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_input_field.grab_focus()
		_input_field.clear()
	else:
		_input_field.release_focus()
		# Restore captured mouse if freecam is running
		if is_instance_valid(_freecam):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_submitted(text: String) -> void:
	var cmd := text.strip_edges()
	_log("[color=cyan]> " + cmd + "[/color]")
	_input_field.clear()
	_parse(cmd.to_lower())

func _parse(cmd: String) -> void:
	match cmd:
		"devmode":
			_devmode = not _devmode
			if _devmode:
				_log("[color=lime]Developer mode [b]ON[/b][/color]")
			else:
				_log("[color=yellow]Developer mode [b]OFF[/b][/color]")
				# Disable freecam automatically when devmode is turned off
				if is_instance_valid(_freecam):
					_disable_freecam()

		"enable freecam":
			if not _devmode:
				_log("[color=red]Error:[/color] devmode must be enabled first.")
				return
			_enable_freecam()

		"disable freecam":
			_disable_freecam()

		"help":
			_log("[color=yellow]Commands:[/color]")
			_log("  [b]devmode[/b]         — toggle developer mode")
			_log("  [b]enable freecam[/b]  — fly camera (WASD + mouse, Q/E up/down, Shift = fast)")
			_log("  [b]disable freecam[/b] — return to normal camera")
			_log("  [b]clear[/b]           — clear console output")
			_log("  [b]help[/b]            — show this list")

		"clear":
			_output.clear()

		_:
			_log("[color=red]Unknown command:[/color] " + cmd + "  (type [b]help[/b] for list)")

func _enable_freecam() -> void:
	if is_instance_valid(_freecam):
		_log("[color=yellow]Freecam is already active.[/color]")
		return
	var script := load("res://scripts/freecam.gd")
	_freecam = Camera3D.new()
	_freecam.set_script(script)
	_freecam.name = "DevFreecam"
	get_tree().current_scene.add_child(_freecam)
	_freecam.console = self
	_log("[color=lime]Freecam enabled.[/color] Close console to fly.")
	_log("  WASD = move  |  Mouse = look  |  Q/E = up/down  |  Shift = fast")
	_toggle()   # close console so mouse is captured for freecam

func _disable_freecam() -> void:
	if not is_instance_valid(_freecam):
		_log("[color=yellow]Freecam is not active.[/color]")
		return
	_freecam.queue_free()
	_freecam = null
	_log("[color=lime]Freecam disabled.[/color] Normal camera restored.")

func _log(msg: String) -> void:
	_output.append_text(msg + "\n")
