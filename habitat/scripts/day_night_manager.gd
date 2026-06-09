extends Node

signal time_changed(hour)

# 24 minute real day = 1 game day (adjustable)
var day_length_seconds: float = 240.0
var current_time: float = 8.0 # Start at 8am
var is_paused: bool = false

# References set by garden
var sun: DirectionalLight3D
var environment: Environment

# Colour curves for sky throughout the day
var sky_colours = {
	0:  Color(0.02, 0.02, 0.08),  # Midnight — deep blue black
	5:  Color(0.4, 0.2, 0.1),     # Dawn — warm orange
	8:  Color(0.6, 0.8, 1.0),     # Morning — pale blue
	12: Color(0.5, 0.7, 1.0),     # Noon — bright blue
	17: Color(0.9, 0.5, 0.2),     # Sunset — golden orange
	20: Color(0.1, 0.05, 0.15),   # Dusk — purple
	24: Color(0.02, 0.02, 0.08),  # Midnight — deep blue black
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
	
	# Interpolate sun colour and energy
	sun.light_color = get_interpolated_colour(sun_colours, current_time)
	sun.light_energy = get_interpolated_float(sun_energy, current_time)
	
	# Interpolate ambient light colour
	environment.ambient_light_color = get_interpolated_colour(sky_colours, current_time)
	environment.ambient_light_energy = lerp(0.1, 0.5, sin((current_time / 24.0) * PI))

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
