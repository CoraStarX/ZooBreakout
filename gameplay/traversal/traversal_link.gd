class_name TraversalLink
extends Node3D
## 邊緣線段與平移落點由關卡配置，不要求踩中單一座標。
@export var edge_end: Vector3 = Vector3.ZERO
@export var landing: Vector3 = Vector3.ZERO
@export var required_capability: CapabilityIds.Id = CapabilityIds.Id.CLIMB

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_inside_tree() and not Engine.is_editor_hint():
			if enabled:
				add_to_group("traversal_links")
			else:
				remove_from_group("traversal_links")

func _ready() -> void:
	if enabled and not Engine.is_editor_hint():
		add_to_group("traversal_links")

func destination() -> Vector3:
	return to_global(landing)

func takeoff_near(point: Vector3) -> Vector3:
	return TraversalMath.closest_edge(point, global_position, to_global(edge_end))

func destination_near(point: Vector3) -> Vector3:
	return takeoff_near(point) + global_basis * landing
