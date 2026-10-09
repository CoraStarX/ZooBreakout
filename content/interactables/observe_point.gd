class_name ObservePoint
extends Area3D
## Daytime/night recon spot: stand still while a staff member is in clear view to learn intel.
## Progress only advances while a staff member is within VIEW_RANGE with line of sight.

@export var display_name: String = "观察点"
@export var reward: StringName = IntelIds.REST_TIME
@export var use_range: float = 1.85

var _busy: bool = false
var _label: ProximityLabel
var _progress: Label3D
var _mark: MeshInstance3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.05
	shape.shape = sphere
	add_child(shape)
	_mark = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.1
	mesh.height = 1.0
	_mark.mesh = mesh
	_mark.position = Vector3(0, 0.5, 0)
	add_child(_mark)
	_label = ProximityLabel.new()
	_label.position = Vector3(0, 1.4, 0)
	add_child(_label)
	_progress = Label3D.new()
	ProximityLabel.style(_progress, 26)
	_progress.position = Vector3(0, 1.05, 0)
	_progress.modulate = Color(0.8, 0.8, 1.0)
	_progress.visible = false
	add_child(_progress)
	Bus.intel_gained.connect(func(_id: StringName) -> void: _refresh())
	_refresh()


func _known() -> bool:
	var world := get_tree().get_first_node_in_group("zoo_world")
	if world and world.get("session") is RunSession:
		return (world.get("session") as RunSession).has_intel(reward)
	return false


func _refresh() -> void:
	var mat := StandardMaterial3D.new()
	if _known():
		mat.albedo_color = Color(0.4, 0.4, 0.45)
		_label.modulate = Color(0.6, 0.6, 0.65)
		_label.set_info("%s\n[已掌握：%s]" % [display_name, IntelIds.display_name(reward)])
	else:
		mat.albedo_color = Color(0.7, 0.5, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.35, 0.9)
		mat.emission_energy_multiplier = 0.8
		_label.modulate = Color(0.85, 0.75, 1.0)
		_label.set_info("%s\n[E 观察 %.0fs · 须看得见职员]" % [display_name, GameConst.OBSERVE_SEC])
	_mark.material_override = mat


## Nearest staff that can currently be watched from here, or null.
func visible_staff() -> StaffActor:
	var best: StaffActor = null
	var best_d := INF
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("staff"):
		var s := node as StaffActor
		if s == null or s.state == StaffActor.State.REST:
			continue
		var d := global_position.distance_to(s.global_position)
		if d > GameConst.OBSERVE_VIEW_RANGE or d >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 0.8, 0), s.global_position + Vector3(0, 0.55, 0)
		)
		q.collision_mask = 1
		if space.intersect_ray(q).is_empty():
			best = s
			best_d = d
	return best


func try_use(user: AnimalActor) -> void:
	if _busy or user == null:
		return
	if _known():
		Bus.interact_feedback.emit("已掌握「%s」" % IntelIds.display_name(reward))
		return
	_busy = true
	_progress.visible = true
	Bus.interact_feedback.emit("开始观察职员…（站在原地，需要看得见他）")
	var progress := 0.0
	var waiting_note := false
	while progress < GameConst.OBSERVE_SEC:
		await get_tree().process_frame
		if not is_instance_valid(user) or user.is_confined:
			_abort("观察中断（被抓）")
			return
		if user.global_position.distance_to(global_position) > use_range:
			_abort("离开观察点，观察取消")
			return
		var s := visible_staff()
		if s == null:
			if not waiting_note:
				Bus.interact_feedback.emit("看不到职员 — 等他巡逻进视野（进度暂停）")
				waiting_note = true
			_progress.text = "等待职员入镜…"
			continue
		waiting_note = false
		if s.state == StaffActor.State.CHASE:
			_abort("职员察觉了你，观察失败！")
			return
		progress += get_process_delta_time()
		_progress.text = "观察 %d%%" % int(clampf(progress / GameConst.OBSERVE_SEC, 0.0, 1.0) * 100.0)
	_progress.visible = false
	_busy = false
	var world := get_tree().get_first_node_in_group("zoo_world")
	if world and world.get("session") is RunSession:
		(world.get("session") as RunSession).learn_intel(reward)
	Bus.interact_feedback.emit("情报到手：%s" % IntelIds.display_name(reward))


func _abort(msg: String) -> void:
	_busy = false
	_progress.visible = false
	Bus.interact_feedback.emit(msg)
