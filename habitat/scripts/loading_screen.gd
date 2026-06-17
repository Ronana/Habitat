## loading_screen.gd
## Magical loading screen shown between main menu and the game.
## Set target_scene before adding to the scene tree.
extends ColorRect

# ── Config ────────────────────────────────────────────────────────────────────
var target_scene: String = "res://scenes/garden.tscn"

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG     := Color(0.02, 0.01, 0.06, 1.00)
const C_ACCENT := Color(0.80, 0.38, 0.96, 1.00)
const C_HOT    := Color(0.96, 0.52, 0.84, 1.00)
const C_DIM    := Color(0.50, 0.42, 0.64, 1.00)
const C_BORDER := Color(0.55, 0.20, 0.78, 1.00)

# ── Loading tips ──────────────────────────────────────────────────────────────
const TIPS: Array = [
	"GlowFoxes are most active at night — try visiting after dusk.",
	"Roamers bond faster when all their needs are met.",
	"A well-tended sanctuary attracts rarer species over time.",
	"Plant berry bushes near shelters to keep roamers fed.",
	"Bonded roamers earn far more dewdrops than visitors.",
	"Each roamer has unique traits that affect their behaviour.",
	"Shelters keep roamers safe — safety is a core need.",
	"The Field Journal tracks every roamer you've ever met.",
	"Seasons change the garden — some species prefer certain weather.",
	"Dewdrops are the lifeblood of your sanctuary. Spend wisely.",
]

# ── Internal ──────────────────────────────────────────────────────────────────
var _progress_bar: ProgressBar = null
var _status_label: Label = null
var _fade_rect: ColorRect = null
var _dot_timer: float = 0.0
var _dot_count: int = 0
var _load_started: bool = false
var _load_complete: bool = false
var _particle_timer: float = 0.0
var _particle_container: Control = null

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Read target scene passed from main menu via tree metadata
	if get_tree().has_meta("loading_target"):
		target_scene = get_tree().get_meta("loading_target")
		get_tree().remove_meta("loading_target")
	_build_ui()
	_fade_in()
	_start_load()

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui():
	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	add_child(bg)

	# Particles
	_particle_container = Control.new()
	_particle_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_container)

	# Centre logo vbox
	var centre := VBoxContainer.new()
	centre.anchor_left   = 0.5
	centre.anchor_top    = 0.5
	centre.anchor_right  = 0.5
	centre.anchor_bottom = 0.5
	centre.offset_left   = -260
	centre.offset_right  =  260
	centre.offset_top    = -120
	centre.offset_bottom =  120
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 10)
	add_child(centre)

	# Small rune
	var rune := Label.new()
	rune.text = "✦  ·  ·  ✦  ·  ·  ✦"
	rune.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rune.add_theme_font_size_override("font_size", 12)
	rune.add_theme_color_override("font_color", Color(C_BORDER, 0.55))
	centre.add_child(rune)

	# Title
	var title := Label.new()
	title.text = "HABITAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", C_ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.18, 0.85))
	title.add_theme_constant_override("outline_size", 5)
	centre.add_child(title)
	_pulse_label(title)

	# Status label
	_status_label = Label.new()
	_status_label.text = "Loading sanctuary"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(C_DIM, 0.85))
	centre.add_child(_status_label)

	# Progress bar
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left",  0)
	bar_margin.add_theme_constant_override("margin_right", 0)
	centre.add_child(bar_margin)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(520, 6)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_style_progress_bar(_progress_bar)
	bar_margin.add_child(_progress_bar)

	# Tip
	var tip_label := Label.new()
	tip_label.text = "✦  " + TIPS[randi() % TIPS.size()]
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_size_override("font_size", 11)
	tip_label.add_theme_color_override("font_color", Color(C_DIM, 0.60))
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(520, 0)
	centre.add_child(tip_label)

	# Fade-out overlay (starts transparent)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.02, 0.01, 0.06, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

# ── Loading ───────────────────────────────────────────────────────────────────

func _start_load():
	ResourceLoader.load_threaded_request(target_scene)
	_load_started = true

func _process(delta):
	_particle_timer += delta
	if _particle_timer >= randf_range(0.4, 1.2):
		_particle_timer = 0.0
		_spawn_particle()

	if not _load_started or _load_complete:
		return

	# Animated dots on status label
	_dot_timer += delta
	if _dot_timer >= 0.45:
		_dot_timer = 0.0
		_dot_count = (_dot_count + 1) % 4
		_status_label.text = "Loading sanctuary" + ".".repeat(_dot_count)

	# Check load progress
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(target_scene, progress)

	if progress.size() > 0:
		# Animate bar smoothly toward actual progress
		_progress_bar.value = lerpf(_progress_bar.value, progress[0] * 100.0, delta * 4.0)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_on_loaded()
		ResourceLoader.THREAD_LOAD_FAILED:
			_status_label.text = "Failed to load. Please restart."
			_status_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3))

func _on_loaded():
	_load_complete = true
	_status_label.text = "Ready."
	_progress_bar.value = 100.0

	# Brief pause so the bar fully fills, then fade to black and switch
	await get_tree().create_timer(0.35).timeout
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	await tw.finished
	var packed := ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(packed)

# ── Animations ────────────────────────────────────────────────────────────────

func _fade_in():
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

func _pulse_label(lbl: Label):
	var tw := create_tween().set_loops()
	tw.tween_property(lbl, "modulate", Color(1.10, 0.88, 1.15), 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate", Color(0.86, 0.76, 1.00), 2.2).set_trans(Tween.TRANS_SINE)

func _spawn_particle():
	var icons  := ["✦", "✧", "⋆", "✺", "✵", "⁕", "◦", "·"]
	var colors := [
		Color(0.72, 0.22, 0.96, randf_range(0.2, 0.6)),
		Color(0.96, 0.42, 0.84, randf_range(0.2, 0.5)),
		Color(0.88, 0.78, 0.22, randf_range(0.1, 0.4)),
	]
	var dot := Label.new()
	dot.text = icons[randi() % icons.size()]
	dot.add_theme_font_size_override("font_size", 8 + randi() % 16)
	dot.add_theme_color_override("font_color", colors[randi() % colors.size()])
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := get_viewport().get_visible_rect().size
	dot.position = Vector2(randf_range(0, vp.x), vp.y + 10)
	_particle_container.add_child(dot)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dot, "position:y", dot.position.y - randf_range(140.0, 400.0),
		randf_range(5.0, 11.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dot, "position:x", dot.position.x + randf_range(-40.0, 40.0),
		randf_range(5.0, 11.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dot, "modulate:a", 0.0, randf_range(4.0, 8.0)).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(dot.queue_free)

# ── Style ─────────────────────────────────────────────────────────────────────

func _style_progress_bar(bar: ProgressBar):
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_ACCENT
	fill.set_corner_radius_all(3)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.03, 0.20, 1.0)
	bg.set_corner_radius_all(3)
	bg.border_color = Color(C_BORDER, 0.4)
	bg.set_border_width_all(1)

	bar.add_theme_stylebox_override("fill",       fill)
	bar.add_theme_stylebox_override("background", bg)
