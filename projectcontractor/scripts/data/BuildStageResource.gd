class_name BuildStageResource
extends Resource

## Unique identifier for this stage (e.g. "shed_foundations").
@export var id: String = ""
## Human-readable name shown in the build progress UI.
@export var display_name: String = ""
## Keys: material id (String) -> amount required (int).
## E.g. { "timber": 20, "fixings": 5 }
@export var required_materials: Dictionary = {}
## Zero-based position of this stage in its parent BuildingTierResource.stages array.
@export var stage_order: int = 0
