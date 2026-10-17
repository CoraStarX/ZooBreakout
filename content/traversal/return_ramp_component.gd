@tool
class_name ReturnRampComponent
extends StaticBody3D
## 幾何中心為原點，局部 -Z 為高端，+Z 為低端；楔形碰撞沿用現有頂點。
@export var width: float = 2.0
@export var height: float = 3.05
@export var depth: float = 6.1
@export var enabled: bool = true
var _configuration: Array = []

func _ready() -> void:
	_refresh()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if _configuration != [width, height, depth, enabled]:
		_refresh()

func _refresh() -> void:
	_configuration = [width, height, depth, enabled]
	var half := Vector3(width, height, depth) * 0.5
	var points := PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
	])
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = points
	$CollisionShape3D.shape = wedge
	$CollisionShape3D.disabled = not enabled
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[2, 4, 5], [2, 5, 3], [0, 1, 5], [0, 5, 4],
			[0, 2, 3], [0, 3, 1], [0, 4, 2], [1, 3, 5]]:
		var normal := (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).normalized()
		for index in face:
			builder.set_normal(normal)
			builder.add_vertex(points[index])
	$VisualMarker.mesh = builder.commit()
	$VisualMarker.visible = enabled
	var zone_shape := ConvexPolygonShape3D.new()
	zone_shape.points = points
	$TriggerZone/CollisionShape3D.shape = zone_shape
