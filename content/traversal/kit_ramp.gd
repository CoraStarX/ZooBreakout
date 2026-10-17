@tool
extends Node3D
## 件庫斜坡：XZ 格點錨點、Y 底部（偶數格置中，奇數格向正軸補半格）；只產生資產幾何，不接入移動規則。
const GRID_UNIT: float = 0.5

@export_range(0.5, 32.0, 0.5) var width: float = 2.0:
	set(value):
		width = maxf(GRID_UNIT, snappedf(value, GRID_UNIT))
		_schedule_rebuild()
@export_range(0.5, 32.0, 0.5) var height: float = 3.0:
	set(value):
		height = maxf(GRID_UNIT, snappedf(value, GRID_UNIT))
		_schedule_rebuild()
## 水平投影長度，不是斜面長。
@export_range(0.5, 64.0, 0.5) var length: float = 6.0:
	set(value):
		length = maxf(GRID_UNIT, snappedf(value, GRID_UNIT))
		_schedule_rebuild()
## 正式 Mesh 替換槽；非空時只使用該 Mesh，尺寸與碰撞仍由上述參數決定。
@export var visual_mesh: Mesh:
	set(value):
		visual_mesh = value
		_schedule_rebuild()
var _rebuild_pending: bool = false

func _ready() -> void:
	_rebuild()

func _schedule_rebuild() -> void:
	if not is_node_ready() or _rebuild_pending:
		return
	_rebuild_pending = true
	call_deferred("_rebuild")

func _rebuild() -> void:
	_rebuild_pending = false
	var half := Vector3(width, height, length) * 0.5
	var points := PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
	])
	var collision := $Body/CollisionShape3D as CollisionShape3D
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = points
	collision.shape = wedge
	# 根固定在0.5m格點；奇數格寬／長的中心向正軸偏移0.25m，兩側邊界皆落格線。
	var center_offset := Vector3(
		float(roundi(width / GRID_UNIT) % 2) * GRID_UNIT * 0.5,
		half.y,
		float(roundi(length / GRID_UNIT) % 2) * GRID_UNIT * 0.5)
	collision.position = center_offset
	var visual := $Visual/MeshInstance3D as MeshInstance3D
	visual.position = collision.position
	visual.set_instance_shader_parameter("color_role", 1)
	visual.set_instance_shader_parameter("shape_size", Vector3(width, height, length))
	visual.set_instance_shader_parameter("ramp_shape", true)
	if visual_mesh != null:
		visual.mesh = visual_mesh
	else:
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in [[2, 4, 5], [2, 5, 3], [0, 1, 5], [0, 5, 4],
				[0, 2, 3], [0, 3, 1], [0, 4, 2], [1, 3, 5]]:
			var normal := (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).normalized()
			# Godot 正面採順時針繞序；法線維持朝外。
			for index in [face[2], face[1], face[0]]:
				builder.set_normal(normal)
				builder.add_vertex(points[index])
		visual.mesh = builder.commit()
	set_meta("size_cells", Vector3i(roundi(width / GRID_UNIT), roundi(height / GRID_UNIT), roundi(length / GRID_UNIT)))
