class_name OfficeChest
extends Area3D
## Content/GamePlay glue: steal confiscated items back from the office.

## Verbs that open the chest quietly (Soft); without one it is a loud Hard attempt.
@export var soft_caps: Array[CapabilityIds.Id] = [CapabilityIds.Id.DEXTERITY, CapabilityIds.Id.CLIMB]

var _busy: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	shape.shape = sphere
	add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.5, 0.6)
	mi.mesh = mesh
	mi.position = Vector3(0, 0.25, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.55, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	add_child(mi)


func _is_soft(user: AnimalActor) -> bool:
	for c in soft_caps:
		if user.has_capability(c):
			return true
	return false


func try_use(user: AnimalActor) -> void:
	if _busy:
		return
	_busy = true
	await _loot(user)
	_busy = false


func _loot(user: AnimalActor) -> void:
	if not OfficeStorage.has_items():
		Bus.interact_feedback.emit("办公室储物柜是空的")
		return
	var soft := _is_soft(user)
	var wait := 0.5 if soft else 1.8
	if soft:
		Bus.interact_feedback.emit("潜入办公室取回物品（稳）…")
	else:
		Bus.interact_feedback.emit("硬闯办公室柜子（吵）…")
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(user) or user.is_confined:
		return
	if not soft:
		if Clock.phase == Clock.Phase.NIGHT_QUIET:
			Bus.interact_feedback.emit("噪音很大，但夜巡已歇岗…")
		else:
			var staffs := get_tree().get_nodes_in_group("staff")
			for s in staffs:
				if s is Node3D and user.global_position.distance_to((s as Node3D).global_position) <= Alert.hearing_radius():
					Bus.interact_feedback.emit("硬闯噪音惊动了工作人员！")
					user.capture_return_home("硬闯办公室")
					return
	if user.is_confined:
		return
	var got := OfficeStorage.take_all()
	user.give_items(got)
	Bus.interact_feedback.emit("夺回：%s" % ", ".join(PackedStringArray(got)))
