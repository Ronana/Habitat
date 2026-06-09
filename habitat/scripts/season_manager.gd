extends Node

signal season_changed(new_season)
signal day_passed(day_number)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var current_season: Season = Season.SPRING
var current_day: int = 1
var days_per_season: int = 7
var day_timer: float = 0.0
var day_length_seconds: float = 240.0 # Matches DayNightManager

var season_data = {
	Season.SPRING: {
	"name": "Spring",
	"icon": "🌸",
	"ambient_colour": Color(0.7, 1.0, 0.7),
	"fog_colour": Color(0.8, 1.0, 0.8),
	"fog_density": 0.004,
	"sun_energy": 1.2,
	"sky_top_colour": Color(0.4, 0.7, 0.5),
	"sky_horizon_colour": Color(0.7, 0.95, 0.75),
	"description": "Roamers emerge and new species appear for the first time.",
	"roamer_happiness_bonus": 0.1,
	"dewdrop_multiplier": 1.0
	},
	Season.SUMMER: {
	"name": "Summer",
	"icon": "☀️",
	"ambient_colour": Color(1.0, 0.9, 0.5),
	"fog_colour": Color(1.0, 0.95, 0.6),
	"fog_density": 0.0,
	"sun_energy": 2.2,
	"sky_top_colour": Color(0.2, 0.5, 0.9),
	"sky_horizon_colour": Color(0.6, 0.85, 1.0),
	"description": "Peak activity. Most Roamers active. Breeding rates highest.",
	"roamer_happiness_bonus": 0.2,
	"dewdrop_multiplier": 1.5
	},
	Season.AUTUMN: {
	"name": "Autumn",
	"icon": "🍂",
	"ambient_colour": Color(0.9, 0.7, 0.4),
	"fog_colour": Color(0.85, 0.7, 0.5),
	"fog_density": 0.002,
	"sun_energy": 1.2,
	"sky_top_colour": Color(0.5, 0.35, 0.2),
	"sky_horizon_colour": Color(0.85, 0.6, 0.3),
	"description": "Rare Roamers appear. Some species prepare to hibernate.",
	"roamer_happiness_bonus": 0.0,
	"dewdrop_multiplier": 1.2
	},
	Season.WINTER: {
	"name": "Winter",
	"icon": "❄️",
	"ambient_colour": Color(0.7, 0.8, 0.95),
	"fog_colour": Color(0.85, 0.9, 1.0),
	"fog_density": 0.003,
	"sun_energy": 0.8,
	"sky_top_colour": Color(0.15, 0.2, 0.4),
	"sky_horizon_colour": Color(0.6, 0.7, 0.9),
	"description": "Nocturnal Roamers most active. Exclusive winter Roamers appear.",
	"roamer_happiness_bonus": -0.1,
	"dewdrop_multiplier": 0.8
	},
}

# References
var environment: Environment
var sun: DirectionalLight3D

func _process(delta):
	day_timer += delta
	if day_timer >= day_length_seconds:
		day_timer = 0.0
		advance_day()

func advance_day():
	current_day += 1
	emit_signal("day_passed", current_day)
	print("📅 Day ", current_day, " of ", get_season_name())
	
	if current_day > days_per_season:
		current_day = 1
		advance_season()

func advance_season():
	var next_season = (current_season + 1) % 4
	current_season = next_season
	emit_signal("season_changed", current_season)
	apply_season()
	print("🌿 Season changed to: ", get_season_name())
	WardenManager.gain_xp("roamer_appears")

func apply_season():
	print("apply_season called — season: ", get_season_name())
	if not environment or not sun:
		print("ERROR: Missing environment or sun reference")
		return
	var data = season_data[current_season]
	
	environment.ambient_light_color = data["ambient_colour"]
	sun.light_energy = data["sun_energy"]
	
	if data["fog_density"] > 0:
		environment.fog_enabled = true
		environment.fog_density = data["fog_density"]
		environment.fog_light_color = data["fog_colour"]
	else:
		environment.fog_enabled = false
	
	# Update procedural sky colours
	var sky = environment.sky
	if sky:
		var sky_mat = sky.sky_material
		if sky_mat and sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_top_color = data["sky_top_colour"]
			sky_mat.sky_horizon_color = data["sky_horizon_colour"]
			sky_mat.ground_horizon_color = data["sky_horizon_colour"]

func get_season_name() -> String:
	return season_data[current_season]["name"]

func get_season_icon() -> String:
	return season_data[current_season]["icon"]

func get_season_description() -> String:
	return season_data[current_season]["description"]

func get_happiness_bonus() -> float:
	return season_data[current_season]["roamer_happiness_bonus"]

func get_dewdrop_multiplier() -> float:
	return season_data[current_season]["dewdrop_multiplier"]

func get_season_string() -> String:
	return get_season_icon() + " " + get_season_name() + " — Day " + str(current_day)
