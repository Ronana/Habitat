extends Node3D

## If set, this shelter is permanently reserved for one species.
## Generic shelters leave this blank and auto-lock on first resident.
@export var locked_species: String = ""

# All roamers currently living here
var assigned_roamers: Array = []

# Active species lock — equals locked_species for species-specific dens,
# or auto-set on first resident for generic shelters.
var resident_species: String = ""

var shelter_type: String = "Basic Shelter"
var max_residents: int = 4

# True when full (kept as a property for any code that still reads it)
var is_occupied: bool:
	get: return assigned_roamers.size() >= max_residents

func _ready():
	# Pre-lock species-specific dens immediately
	if locked_species != "":
		resident_species = locked_species
		shelter_type     = locked_species + " Den"
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
	roamer.check_stage_progress()
	if assigned_roamers.size() >= max_residents:
		MilestoneManager.fire("first_full_den", "Full House! 🏠", resident_species + " Den is at full capacity.")

func unassign_roamer(roamer):
	assigned_roamers.erase(roamer)
	if roamer.has_shelter and roamer.shelter_node == self:
		roamer.has_shelter = false
		roamer.shelter_node = null
	# Only release the species lock for generic shelters (locked_species == "")
	if assigned_roamers.is_empty() and locked_species == "":
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
		$ShelterLabel.text = (locked_species + " Den" if locked_species != "" else "Shelter")
		return
	var count := assigned_roamers.size()
	var den_name := resident_species + " Den" if resident_species != "" else "Den"
	if count > 1:
		den_name += " (" + str(count) + ")"
	$ShelterLabel.text = den_name
