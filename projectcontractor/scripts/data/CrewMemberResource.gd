class_name CrewMemberResource
extends Resource

## Unique identifier (e.g. "labourer_1", "joiner_1").
@export var id: String = ""
## Name shown in the Crew hire screen.
@export var display_name: String = ""
## Flat gather/build speed multiplier added per level at Phase 3.
## E.g. 0.1 means +10% speed per level.
@export var base_speed_bonus: float = 0.1
## Cash cost to hire this crew member at level 1.
@export var hire_cost: int = 50
## Starting level (always 1 for a fresh hire; runtime level tracked in GameState).
@export var level: int = 1
## Which material type this crew member primarily generates when idle.
## Used by OfflineProgressCalculator. E.g. "timber", "stone".
@export var material_type: String = "timber"
## Which mining location this crew member is assigned to.
## Used by the mine tick to determine where HP damage is applied.
## E.g. "lumber_yard", "stone_quarry".
@export var location_id: String = "lumber_yard"
