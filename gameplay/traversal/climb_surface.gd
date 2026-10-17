class_name ClimbSurface
extends Node3D
## 局部 +Z 為牆外、X 為橫向、Y 為向上。只允許直立矩形攀爬面。
@export var width: float = 3.0
@export var height: float = 3.0
@export var required_capability: CapabilityIds.Id = CapabilityIds.Id.CLIMB

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_inside_tree() and not Engine.is_editor_hint():
			if enabled:
				add_to_group("climb_surfaces")
			else:
				remove_from_group("climb_surfaces")

func _ready() -> void:
	if enabled and not Engine.is_editor_hint():
		add_to_group("climb_surfaces")

func anchor(point: Vector3, params: TraversalParams) -> Vector3:
	var local := to_local(point)
	local.x = clampf(local.x, -width * 0.5 + params.radius, width * 0.5 - params.radius)
	local.y = clampf(local.y, params.landing_lift, height + params.landing_lift)
	local.z = params.radius + params.wall_clearance
	return to_global(local)
