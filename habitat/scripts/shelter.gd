extends Node3D

var assigned_roamer = null
var shelter_type: String = "Basic Shelter"
var is_occupied: bool = false

func _ready():
	$ShelterArea.body_entered.connect(_on_body_entered)
	add_to_group("shelters")

func _on_body_entered(body):
	var node = body
	while node:
		if node.is_in_group("roamers"):
			if not is_occupied and assigned_roamer == null:
				offer_shelter(node)
			return
		node = node.get_parent()

func offer_shelter(roamer):
	# Only offer to Roamers at Visit stage or higher
	if roamer.attraction_stage >= 1:
		assign_roamer(roamer)

func assign_roamer(roamer):
	assigned_roamer = roamer
	is_occupied = true
	roamer.has_shelter = true
	roamer.shelter_node = self
	$ShelterLabel.text = roamer.name + "'s Home"
	print(roamer.name, " has moved into ", shelter_type)
	# Let roamer_base.check_stage_progress() handle the stage transition and
	# XP award — calling it here prevents duplicate "roamer_resident" XP.
	roamer.check_stage_progress()

func unassign_roamer():
	if assigned_roamer:
		assigned_roamer.has_shelter = false
		assigned_roamer.shelter_node = null
	assigned_roamer = null
	is_occupied = false
	$ShelterLabel.text = "Shelter"
