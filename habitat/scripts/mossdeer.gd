extends "res://scripts/roamer_base.gd"

func _ready():
	# Mossdeer specific stats
	move_speed = 1.8
	dewdrop_interval = 7.0
	hunger_threshold = 0.5
	
	# Mossdeer needs more food than a fox
	need_decay["food"] = 0.015
	
	super._ready()

func on_selected():
	var body = get_node("Body")
	var mat = body.get_active_material(0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.0

func on_deselected():
	var body = get_node("Body")
	var mat = body.get_active_material(0)
	mat.emission_enabled = false
