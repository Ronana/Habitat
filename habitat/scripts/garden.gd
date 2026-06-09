extends Node3D

@export var tree_scene: PackedScene
@export var tree_count: int = 30
@export var forest_radius: float = 80.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.6

func _ready():
	scatter_trees()
	
	# Connect day night manager to scene lights
	var sun = get_node("DirectionalLight3D")
	var env = get_node("WorldEnvironment").environment
	DayNightManager.sun = sun
	DayNightManager.environment = env
	WeatherManager.environment = env
	WeatherManager.sun = sun
	WeatherManager.rain_particles = get_node("RainParticles")
	SeasonManager.environment = env
	SeasonManager.sun = sun
	
	# Try to load save
	var loaded = await SaveManager.load_game(self)
	if not loaded:
		print("Fresh wilderness — no save found")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Press F5 to save manually
		if event.keycode == KEY_F5:
			SaveManager.save_game(self)
		# Press F9 to load
		if event.keycode == KEY_F9:
			SaveManager.load_game(self)
		# Press 1-4 to force weather for testing
		if event.keycode == KEY_1:
			WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
		if event.keycode == KEY_2:
			WeatherManager.set_weather(WeatherManager.Weather.RAIN)
		if event.keycode == KEY_3:
			WeatherManager.set_weather(WeatherManager.Weather.FOG)
		if event.keycode == KEY_4:
			WeatherManager.set_weather(WeatherManager.Weather.WIND)
			# Press F1-F4 to force seasons for testing
		if event.keycode == KEY_F1:
			SeasonManager.current_season = SeasonManager.Season.SPRING
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F2:
			SeasonManager.current_season = SeasonManager.Season.SUMMER
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F3:
			SeasonManager.current_season = SeasonManager.Season.AUTUMN
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)
		if event.keycode == KEY_F4:
			SeasonManager.current_season = SeasonManager.Season.WINTER
			SeasonManager.apply_season()
			WeatherManager.apply_weather_effects()
			SeasonManager.emit_signal("season_changed", SeasonManager.current_season)

func scatter_trees():
	var i = 0
	while i < tree_count:
		var tree = tree_scene.instantiate()
		add_child(tree)
		
		var x = randf_range(-forest_radius, forest_radius)
		var z = randf_range(-forest_radius, forest_radius)
		tree.position = Vector3(x, 0, z)
		
		var tree_scale = randf_range(min_scale, max_scale)
		tree.scale = Vector3(tree_scale, tree_scale, tree_scale)
		
		tree.rotation.y = randf_range(0, TAU)
		i += 1
