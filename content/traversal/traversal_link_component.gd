@tool
extends TraversalLink
## 線段與平移落點沿用原規則；TriggerZone 不取代距離、路徑或支撐查詢。
@export var params: TraversalParams = preload("res://content/traversal/traversal_params.tres")
var _configuration: Array = []

func _ready() -> void:
	super._ready()
	_refresh()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if _configuration != [edge_end, landing, enabled, params.marker_radius, params.takeoff_range]:
		_refresh()

func _refresh() -> void:
	_configuration = [edge_end, landing, enabled, params.marker_radius, params.takeoff_range]
	var visual := $VisualMarker as MeshInstance3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(params.marker_radius * 0.3, 0.012, maxf(edge_end.length(), params.marker_radius))
	visual.mesh = mesh
	visual.position = edge_end * 0.5
	visual.rotation = Vector3.ZERO
	if edge_end.length_squared() > 0.000001:
		var up := Vector3.RIGHT if absf(edge_end.normalized().dot(Vector3.UP)) > 0.999 else Vector3.UP
		visual.basis = Basis.looking_at(edge_end.normalized(), up)
	visual.visible = enabled
	var shape := CapsuleShape3D.new()
	shape.radius = params.takeoff_range
	shape.height = edge_end.length() + params.takeoff_range * 2.0
	var zone := $TriggerZone as Area3D
	zone.position = edge_end * 0.5
	zone.basis = Basis.IDENTITY
	if edge_end.length_squared() > 0.000001:
		zone.basis = visual.basis * Basis(Vector3.RIGHT, PI * 0.5)
	$TriggerZone/CollisionShape3D.shape = shape
