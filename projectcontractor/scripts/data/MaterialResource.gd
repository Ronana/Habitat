class_name MaterialResource
extends Resource

## Unique identifier used as dictionary key everywhere (e.g. "timber", "stone").
@export var id: String = ""
## Human-readable name shown in the HUD.
@export var display_name: String = ""
## Icon shown in the material count bar (optional at Phase 1, required by Phase 2).
@export var icon: Texture2D
## Base cash value when a stage that uses this material is completed.
@export var base_value: int = 1
