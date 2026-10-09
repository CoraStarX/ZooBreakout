extends Area3D
## Day-friendly named kit on the ground. E to pick up. Visually loud for Open discoverability.

const _KitIds := preload("res://content/kit_ids.gd")

@export var kit_id: StringName = &"dig_kit"
@export var display_name: String = ""

var _taken: bool = false
var _label: ProximityLabel
var _beacon: MeshInstance3D
var _bob_t: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	if display_name.is_empty():
		display_name = _KitIds.display_name(kit_id)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.05
	shape.shape = sphere
	add_child(shape)
	## Pedestal pad
	var pad := MeshInstance3D.new()
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.55
	pmesh.bottom_radius = 0.65
	pmesh.height = 0.08
	pad.mesh = pmesh
	pad.position = Vector3(0, 0.04, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.12, 0.08)
	pad.material_override = pmat
	add_child(pad)
	## Bright crate
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.5, 0.55)
	mi.mesh = mesh
	mi.position = Vector3(0, 0.35, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _crate_color()
	mat.emission_enabled = true
	mat.emission = _crate_color()
	mat.emission_energy_multiplier = 0.85
	mi.material_override = mat
	add_child(mi)
	## Star beacon above
	_beacon = MeshInstance3D.new()
	var bmesh := SphereMesh.new()
	bmesh.radius = 0.18
	bmesh.height = 0.36
	_beacon.mesh = bmesh
	_beacon.position = Vector3(0, 1.05, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.95, 0.35)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.9, 0.2)
	bmat.emission_energy_multiplier = 1.4
	_beacon.material_override = bmat
	add_child(_beacon)
	_label = ProximityLabel.new()
	_label.name = "WorldLabel"
	_label.set_info("★ %s\n[E 拾取] 夜间带到外墙，顶 %d 档施工" % [display_name, GameConst.KIT_TIERS])
	_label.position = Vector3(0, 1.55, 0)
	_label.modulate = Color(1.0, 0.95, 0.4)
	add_child(_label)


func _process(delta: float) -> void:
	if _taken or _beacon == null:
		return
	_bob_t += delta
	_beacon.position.y = 1.05 + sin(_bob_t * 3.0) * 0.12


func _crate_color() -> Color:
	match kit_id:
		&"dig_kit":
			return Color(0.85, 0.55, 0.2)
		&"climb_kit":
			return Color(0.35, 0.75, 0.4)
		_:
			return Color(0.9, 0.75, 0.25)


func try_use(user: AnimalActor) -> void:
	if _taken or user == null:
		return
	if user.has_item(kit_id):
		Bus.interact_feedback.emit("已有%s" % _KitIds.display_name(kit_id))
		return
	_taken = true
	user.give_items([kit_id])
	visible = false
	collision_layer = 0
	set_process(false)
	if _label:
		_label.visible = false
	var hint := "西外墙「外墙挖洞」" if kit_id == &"dig_kit" else "南外墙「外墙攀爬出园」"
	Bus.interact_feedback.emit("拾取：%s — 夜间带到%s 施工，可顶 %d 档（被抓会被没收）" % [
		_KitIds.display_name(kit_id), hint, GameConst.KIT_TIERS
	])
