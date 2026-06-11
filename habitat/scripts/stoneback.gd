extends "res://scripts/roamer_base.gd"

func _ready():
	species_id = "Stoneback"
	creature_scene_path = "res://creatures/stoneback.tscn"
	move_speed = 1.0          # slow and deliberate
	dewdrop_interval = 10.0   # generates dewdrops slowly but steadily
	hunger_threshold = 0.4    # less reliant on food than others
	need_decay["food"] = 0.007  # very slow hunger
	need_decay["safety"] = 0.002  # stone shell = naturally safer
	super._ready()

func on_selected():
	super.on_selected()
	# Shell is now named "Body" so the base class selection glow works automatically

func on_deselected():
	super.on_deselected()
