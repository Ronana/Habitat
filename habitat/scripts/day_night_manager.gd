extends Node

signal time_changed(hour)

# 24 minute real day = 1 game day (adjustable)
var day_length_seconds: float = 240.0
var current_time: float = 22.0 # Start at 10pm — deep night
var is_paused: bool = false

# References set by garden
var sun: DirectionalLight3D
var environment: Environment

# Sky top colour throughout the day
var sky_colours = {
	0:  Color(0.02, 0.02, 0.10),  # Midnight — deep blue-black
	5:  Color(0.28, 0.14, 0.10),  # Pre-dawn — dark amber
	6:  Color(0.55, 0.30, 0.12),  # Dawn — warm orange
	8:  Color(0.35, 0.55, 0.82),  # Morning — pale blue
	12: Color(0.22, 0.48, 0.90),  # Noon — rich blue
	17: Color(0.60, 0.32, 0.12),  # Sunset — golden orange
	19: Color(0.12, 0.07, 0.18),  # Dusk — deep purple
	21: Color(0.04, 0.03, 0.12),  # Night — near-black blue
	24: Color(0.02, 0.02, 0.10),  # Midnight
}

# Sky horizon colour throughout the day
var sky_horizon_colours = {
	0:  Color(0.04, 0.04, 0.14),
	5:  Color(0.70, 0.32, 0.08),  # Pre-dawn horizon glow
	6:  Color(0.95, 0.55, 0.18),  # Dawn — bright orange horizon
	8:  Color(0.72, 0.85, 0.98),  # Morning haze
	12: Color(0.60, 0.82, 1.00),  # Midday
	17: Color(0.98, 0.58, 0.18),  # Sunset horizon
	19: Color(0.40, 0.18, 0.28),  # Dusk
	21: Color(0.08, 0.06, 0.18),
	24: Color(0.04, 0.04, 0.14),
}

var sun_colours = {
	0:  Color(0.0, 0.0, 0.0),
	5:  Color(1.0, 0.5, 0.2),
	8:  Color(1.0, 0.9, 0.7),
	12: Color(1.0, 1.0, 0.95),
	17: Color(1.0, 0.6, 0.2),
	20: Color(0.3, 0.1, 0.2),
	24: Color(0.0, 0.0, 0.0),
}

var sun_energy = {
	0:  0.0,
	5:  0.3,
	8:  0.8,
	12: 1.8,
	17: 1.0,
	20: 0.2,
	24: 0.0,
}

func _process(delta):
	if is_paused:
		return
	
	# Advance time
	var time_per_second = 24.0 / day_length_seconds
	current_time += time_per_second * delta
	if current_time >= 24.0:
		current_time = 0.0
		emit_signal("time_changed", current_time)
	
	update_lighting()

func update_lighting():
	if not sun or not environment:
		return

	# Rotate sun across sky
	var sun_angle = (current_time / 24.0) * 360.0 - 90.0
	sun.rotation_degrees.x = -sun_angle

	# Sun colour and energy
	var season_base_energy: float = SeasonManager.season_data[SeasonManager.current_season]["sun_energy"]
	sun.light_color = get_interpolated_colour(sun_colours, current_time)
	var day_factor: float = get_interpolated_float(sun_energy, current_time)
	sun.light_energy = day_factor * season_base_energy

	# Ambient — blend season colour with time-of-day darkness
	var season_ambient: Color = SeasonManager.season_data[SeasonManager.current_season]["ambient_colour"]
	var night_factor: float = 1.0 - clamp(day_factor, 0.0, 1.0)
	environment.ambient_light_color = season_ambient.lerp(Color(0.04, 0.04, 0.12), night_factor * 0.7)
	environment.ambient_light_energy = lerp(0.15, 0.55, clamp(day_factor, 0.0, 1.0))

	# Sky — blend day/night colour with season's base sky
	var sky_top: Color = get_interpolated_colour(sky_colours, current_time)
	var sky_horiz: Color = get_interpolated_colour(sky_horizon_colours, current_time)
	# Tint towards season hue at midday
	var season_sky_top: Color   = SeasonManager.season_data[SeasonManager.current_season]["sky_top_colour"]
	var season_sky_horiz: Color = SeasonManager.season_data[SeasonManager.current_season]["sky_horizon_colour"]
	var season_blend: float = clamp(day_factor * 0.5, 0.0, 0.45)
	sky_top   = sky_top.lerp(season_sky_top,   season_blend)
	sky_horiz = sky_horiz.lerp(season_sky_horiz, season_blend)

	var sky_obj = environment.sky
	if sky_obj:
		var sky_mat = sky_obj.sky_material
		if sky_mat and sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_top_color      = sky_top
			sky_mat.sky_horizon_color  = sky_horiz
			sky_mat.ground_horizon_color = sky_horiz.darkened(0.25)

	# Dynamic fog — thicker at dawn/dusk and at night, off at midday
	var is_dawn_dusk: bool = (current_time > 5.0 and current_time < 7.5) or \
							 (current_time > 17.5 and current_time < 20.0)
	var is_night: bool = current_time < 5.0 or current_time > 21.0
	var season_fog_density: float = SeasonManager.season_data[SeasonManager.current_season]["fog_density"]
	if is_dawn_dusk:
		environment.fog_enabled = true
		environment.fog_density  = max(season_fog_density, 0.006)
		environment.fog_light_color = sky_horiz
	elif is_night:
		environment.fog_enabled = true
		environment.fog_density  = max(season_fog_density, 0.003)
		environment.fog_light_color = Color(0.05, 0.05, 0.12)
	elif season_fog_density > 0.0:
		environment.fog_enabled = true
		environment.fog_density  = season_fog_density
		environment.fog_light_color = SeasonManager.season_data[SeasonManager.current_season]["fog_colour"]
	else:
		environment.fog_enabled = false

func get_interpolated_colour(colour_map: Dictionary, time: float) -> Color:
	var keys = colour_map.keys()
	keys.sort()
	
	var prev_key = keys[0]
	var next_key = keys[keys.size() - 1]
	
	for key in keys:
		if time >= key:
			prev_key = key
		else:
			next_key = key
			break
	
	if prev_key == next_key:
		return colour_map[prev_key]
	
	var t = (time - prev_key) / (next_key - prev_key)
	return colour_map[prev_key].lerp(colour_map[next_key], t)

func get_interpolated_float(float_map: Dictionary, time: float) -> float:
	var keys = float_map.keys()
	keys.sort()
	
	var prev_key = keys[0]
	var next_key = keys[keys.size() - 1]
	
	for key in keys:
		if time >= key:
			prev_key = key
		else:
			next_key = key
			break
	
	if prev_key == next_key:
		return float_map[prev_key]
	
	var t = (time - prev_key) / (next_key - prev_key)
	return lerp(float_map[prev_key], float_map[next_key], t)

func get_time_string() -> String:
	var hours = int(current_time)
	var minutes = int((current_time - hours) * 60)
	return "%02d:%02d" % [hours, minutes]
