extends Node

signal weather_changed(new_weather)

enum Weather { SUNNY, RAIN, FOG, WIND }

var current_weather: Weather = Weather.SUNNY
var weather_timer: float = 0.0
var weather_duration: float = 120.0 # 2 minutes per weather cycle
var transition_speed: float = 1.0

# References set by garden
var environment: Environment
var sun: DirectionalLight3D

# Weather probabilities
var weather_chances = {
	Weather.SUNNY: 0.4,
	Weather.RAIN: 0.3,
	Weather.FOG: 0.2,
	Weather.WIND: 0.1
}

# Particle nodes
var rain_particles: GPUParticles3D
var is_transitioning: bool = false

func _ready():
	weather_timer = weather_duration

func _process(delta):
	weather_timer -= delta
	if weather_timer <= 0:
		pick_new_weather()
		weather_timer = weather_duration

func pick_new_weather():
	var roll = randf()
	var cumulative = 0.0
	for weather in weather_chances:
		cumulative += weather_chances[weather]
		if roll <= cumulative:
			if weather != current_weather:
				set_weather(weather)
			return

func set_weather(new_weather: Weather):
	current_weather = new_weather
	emit_signal("weather_changed", new_weather)
	apply_weather_effects()
	print("Weather changed to: ", get_weather_name())

func apply_weather_effects():
	if not environment or not sun:
		return
	
	# Get base values from current season
	var season_sun_energy = SeasonManager.season_data[SeasonManager.current_season]["sun_energy"]
	var season_ambient = SeasonManager.season_data[SeasonManager.current_season]["ambient_colour"]
	
	match current_weather:
		Weather.SUNNY:
			sun.light_energy = season_sun_energy
			environment.ambient_light_color = season_ambient
			environment.fog_enabled = false
			if rain_particles:
				rain_particles.emitting = false
		Weather.RAIN:
			sun.light_energy = season_sun_energy * 0.4
			environment.ambient_light_color = season_ambient.darkened(0.3)
			environment.fog_enabled = true
			environment.fog_density = 0.003
			environment.fog_light_color = Color(0.6, 0.6, 0.7)
			if rain_particles:
				rain_particles.emitting = true
		Weather.FOG:
			sun.light_energy = season_sun_energy * 0.3
			environment.ambient_light_color = season_ambient.lightened(0.1)
			environment.fog_enabled = true
			environment.fog_density = 0.015
			environment.fog_light_color = Color(0.8, 0.85, 0.9)
			if rain_particles:
				rain_particles.emitting = false
		Weather.WIND:
			sun.light_energy = season_sun_energy * 0.9
			environment.ambient_light_color = season_ambient
			environment.fog_enabled = false
			if rain_particles:
				rain_particles.emitting = false

func get_weather_name() -> String:
	match current_weather:
		Weather.SUNNY: return "Sunny"
		Weather.RAIN: return "Raining"
		Weather.FOG: return "Foggy"
		Weather.WIND: return "Windy"
	return "Unknown"

func get_weather_effect_on_roamer(roamer_type: String) -> float:
	# Returns a happiness modifier based on weather and roamer type
	match current_weather:
		Weather.RAIN:
			if roamer_type == "wetland":
				return 0.2  # Wetland roamers love rain
			return -0.1     # Others slightly unhappy
		Weather.FOG:
			return 0.1      # All roamers like fog slightly
		Weather.SUNNY:
			return 0.1      # All roamers like sunshine
		Weather.WIND:
			return 0.0      # Neutral
	return 0.0
