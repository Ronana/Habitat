extends Node3D

# All roamers currently living here
var assigned_roamers: Array = []

# Set on first resident; only roamers of this species can join after that
var resident_species: String = ""

var shelter_type: String = "Basic Shelter"
var max_residents: int = 4

# True when full (kept as a property for any code that still reads it)
var is_occupied: bool:
	get: return assigned_roamers.size() >= max_residents

func _ready():
	$ShelterArea.body_entered.connect(_on_body_entered)
	add_to_group("shelters")

# Whether this shelter will accept a given roamer
func can_accept(roamer) -> bool:
	if assigned_roamers.size() >= max_residents:
		return false  # full
	if roamer in assigned_roamers:
		return false  # already lives here
	if resident_species == "":
		return true   # empty — any species welcome
	return resident_species == roamer.species_id

func _on_body_entered(body):
	var node = body
	while node:
		if node.is_in_group("roamers"):
			if can_accept(node) and not node.has_shelter:
				offer_shelter(node)
			return
		node = node.get_parent()

func offer_shelter(roamer):
	# Only offer to roamers at Visit stage or higher
	if roamer.attraction_stage >= 1:
		assign_roamer(roamer)

func assign_roamer(roamer):
	if roamer in assigned_roamers:
		return
	# Claim species on first resident
	if resident_species == "":
		resident_species = roamer.species_id
	assigned_roamers.append(roamer)
	roamer.has_shelter = true
	roamer.shelter_node = self
	_update_label()
	print(roamer.name, " has moved into their ", resident_species, " Den")
	roamer.check_stage_progress()
	if assigned_roamers.size() >= max_residents:
		MilestoneManager.fire("first_full_den", "Full House! 🏠", resident_species + " Den is at full capacity.")

func unassign_roamer(roamer):
	assigned_roamers.erase(roamer)
	if roamer.has_shelter and roamer.shelter_node == self:
		roamer.has_shelter = false
		roamer.shelter_node = null
	# Release species lock when the last resident leaves
	if assigned_roamers.is_empty():
		resident_species = ""
	_update_label()

func get_display_name() -> String:
	if assigned_roamers.is_empty():
		return "Empty Shelter"
	var count := assigned_roamers.size()
	var den_name := resident_species + " Den" if resident_species != "" else "Den"
	if count > 1:
		den_name += " (" + str(count) + ")"
	return den_name

func _update_label():
	if assigned_roamers.is_empty():
		$ShelterLabel.text = "Shelter"
		return
	var count := assigned_roamers.size()
	var den_name := resident_species + " Den" if resident_species != "" else "Den"
	if count > 1:
		den_name += " (" + str(count) + ")"
	$ShelterLabel.text = den_name
