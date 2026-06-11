extends Node

# Procedural audio manager — no external audio files required.
# Generates simple tones for UI feedback and a gentle ambient pad.

var _ui_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _ambient_timer: float = 0.0
const AMBIENT_INTERVAL := 8.0   # seconds between ambient chirps

func _ready():
	_setup_ui_player()
	_setup_ambient_player()
	# Connect to game signals for audio feedback
	if CurrencyManager.has_signal("dewdrops_changed"):
		CurrencyManager.dewdrops_changed.connect(_on_dewdrops_changed)
	if WardenManager.has_signal("level_up"):
		WardenManager.level_up.connect(_on_level_up)

func _process(delta):
	_ambient_timer += delta
	if _ambient_timer >= AMBIENT_INTERVAL:
		_ambient_timer = 0.0
		_play_ambient_chirp()

# ── Setup ─────────────────────────────────────────────────────────────────────
func _setup_ui_player():
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "Master"
	_ui_player.volume_db = -12.0
	add_child(_ui_player)

func _setup_ambient_player():
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	_ambient_player.volume_db = -20.0
	add_child(_ambient_player)

# ── Tone generation ───────────────────────────────────────────────────────────
func _play_tone(frequency: float, duration: float, volume_db: float = -12.0,
				shape: String = "sine", fade_out: bool = true):
	var sample_rate := 44100
	var samples := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := 1.0
		if fade_out:
			envelope = clamp(1.0 - (float(i) / samples) * 1.2, 0.0, 1.0)
		# Attack
		if i < sample_rate * 0.01:
			envelope *= float(i) / (sample_rate * 0.01)

		var wave := 0.0
		match shape:
			"sine":
				wave = sin(TAU * frequency * t)
			"triangle":
				var phase := fmod(frequency * t, 1.0)
				wave = 1.0 - 4.0 * abs(phase - 0.5)
			"soft_square":
				wave = clamp(sin(TAU * frequency * t) * 3.0, -1.0, 1.0) * 0.5

		var sample_val := int(wave * envelope * 28000.0)
		sample_val = clamp(sample_val, -32768, 32767)
		data[i * 2]     = sample_val & 0xFF
		data[i * 2 + 1] = (sample_val >> 8) & 0xFF

	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "Master"
	add_child(player)
	player.play()
	# Auto-free after playback
	await get_tree().create_timer(duration + 0.1).timeout
	player.queue_free()

# ── Public sound calls ────────────────────────────────────────────────────────
func play_buy():
	_play_tone(523.25, 0.12, -10.0, "sine")          # C5
	await get_tree().create_timer(0.10).timeout
	_play_tone(659.25, 0.15, -10.0, "sine")          # E5

func play_place():
	_play_tone(440.0, 0.08, -14.0, "triangle")
	await get_tree().create_timer(0.07).timeout
	_play_tone(550.0, 0.10, -14.0, "triangle")

func play_level_up():
	var notes := [261.63, 329.63, 392.0, 523.25]    # C4 E4 G4 C5
	for note in notes:
		_play_tone(note, 0.18, -8.0, "sine")
		await get_tree().create_timer(0.14).timeout

func play_select():
	_play_tone(660.0, 0.07, -16.0, "triangle", false)

func play_error():
	_play_tone(220.0, 0.15, -12.0, "soft_square")
	await get_tree().create_timer(0.12).timeout
	_play_tone(196.0, 0.20, -12.0, "soft_square")

func _play_ambient_chirp():
	# A gentle random bird-like chirp
	var base := 800.0 + randf_range(-200.0, 400.0)
	_play_tone(base, 0.06, -22.0, "sine", true)
	await get_tree().create_timer(0.05 + randf() * 0.08).timeout
	_play_tone(base * 1.25, 0.08, -24.0, "sine", true)

# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_dewdrops_changed(_amount):
	pass  # Only play on explicit buy, not every change

func _on_level_up(_level):
	play_level_up()
