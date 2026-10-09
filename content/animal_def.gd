class_name AnimalDef
extends Resource
## Data-driven animal identity. Starter choice must not hardcode species in code.

@export var id: StringName = &""
@export var display_name: String = ""
@export var capabilities: Array[CapabilityIds.Id] = []
@export var body_color: Color = Color.WHITE
@export var move_speed: float = 5.0
@export var can_start: bool = true


func has_capability(cap: CapabilityIds.Id) -> bool:
	return capabilities.has(cap)


func capability_labels() -> String:
	var parts: PackedStringArray = []
	for c in capabilities:
		parts.append(CapabilityIds.to_label(c))
	return ", ".join(parts)
