class_name BuildingTierResource
extends Resource

## Unique identifier (e.g. "shed", "house_single", "house_double").
@export var id: String = ""
## Human-readable name (e.g. "Garden Shed").
@export var display_name: String = ""
## Ordered list of build stages for this tier.
@export var stages: Array[BuildStageResource] = []
## Minimum Build Power the player must have before this tier can be started.
## Tier 1 (shed) uses 0 -- no gate.
@export var build_power_required: int = 0
## String tag describing what else must be true to unlock this tier.
## "none"                  -- always available once build_power is met
## "inspection_pass"       -- Tier 3 Code Compliance gate (Phase 4)
## "permit_apartment"      -- Tier 4 Permit gate (Phase 4)
## Extend this enum-style string as new tiers are added.
@export var unlock_condition: String = "none"
