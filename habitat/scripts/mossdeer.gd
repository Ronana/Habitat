extends "res://scripts/roamer_base.gd"

func _ready():
	species_id = "Mossdeer"
	creature_scene_path = "res://creatures/mossdeer.tscn"
	move_speed = 1.8
	dewdrop_interval = 7.0
	hunger_threshold = 0.5
	need_decay["food"] = 0.015
	super._ready()

func on_selected():
	super.on_selected()
	# Tint emission green to distinguish from GlowFox
	var body = get_node("Body")
	var mat = body.get_surface_override_material(0)
	if mat:
		mat.emission = Color(0.2, 0.85, 0.2)

func on_deselected():
	super.on_deselected()
