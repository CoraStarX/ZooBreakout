@tool
extends ClimbSurface
## TriggerZone 是幾何參照；附牆／屋頂下牆仍由 TraversalActor 精確判定。
@export var params: TraversalParams = preload("res://content/traversal/traversal_params.tres")
var _configuration: Array = []

func _ready() -> void:
	super._ready()
	_refresh()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if _configuration != [width, height, enabled, params.attach_range, params.roof_attach_range]:
		_refresh()

func _refresh() -> void:
	_configuration = [width, height, enabled, params.attach_range, params.roof_attach_range]
	var visual := $VisualMarker as MeshInstance3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, 0.025)
	visual.mesh = mesh
	visual.position = Vector3(0, height * 0.5, 0.025)
	visual.visible = enabled
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, params.attach_range + params.roof_attach_range)
	$TriggerZone/CollisionShape3D.shape = shape
	$TriggerZone.position = Vector3(0, height * 0.5, (params.attach_range - params.roof_attach_range) * 0.5)
