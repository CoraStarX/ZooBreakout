class_name TraceMarker
extends Area3D
## World evidence left by Hard construction. Alert bumps only when discovered (once).


var intensity: float = 1.0
var kind: StringName = &"construction"
## True after Alert has been applied for this marker — never bump again.
var settled: bool = false
var _mesh: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	add_to_group("traces")
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.45
	cyl.height = 0.08
	_mesh.mesh = cyl
	_mesh.position = Vector3(0, 0.04, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.25, 0.15, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.3, 0.1)
	mat.emission_energy_multiplier = 0.35
	_mesh.material_override = mat
	add_child(_mesh)
	_label = Label3D.new()
	ProximityLabel.style(_label, 22)
	_label.position = Vector3(0, 0.55, 0)
	_label.modulate = Color(1.0, 0.7, 0.45)
	_label.text = "痕迹"
	add_child(_label)
	_refresh_visual()


func _refresh_visual() -> void:
	if _label:
		if settled:
			_label.text = "痕迹（已查）"
			_label.modulate = Color(0.55, 0.55, 0.55)
		else:
			_label.text = "痕迹 ×%.1f" % intensity
	if _mesh and _mesh.material_override is StandardMaterial3D:
		var mat := _mesh.material_override as StandardMaterial3D
		mat.albedo_color.a = clampf(0.35 + intensity * 0.25, 0.35, 0.9)


## Apply Alert once. Returns true if this call actually bumped.
func try_settle_alert(amount: int = 1) -> bool:
	if settled or intensity <= 0.05:
		return false
	settled = true
	Alert.bump(amount)
	_refresh_visual()
	Bus.interact_feedback.emit("职员发现施工痕迹 — 警戒升至 %d" % Alert.level)
	return true


func apply_dawn_decay(retain: float) -> void:
	if settled:
		queue_free()
		return
	intensity *= clampf(retain, 0.0, 1.0)
	if intensity <= 0.05:
		queue_free()
	else:
		_refresh_visual()
