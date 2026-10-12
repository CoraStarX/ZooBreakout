class_name PartyController
extends Node
## GamePlay: switch control, follow/hold/goto orders, rescue into party.

signal party_changed
signal marker_changed(valid: bool, pos: Vector3)

var _animals: Array[AnimalActor] = []
var _controlled_index: int = 0
var _pending_rescues: Dictionary = {} ## StringName id -> AnimalActor not yet in party
var marker_valid: bool = false
var marker_position: Vector3 = Vector3.ZERO
var _marker_mesh: MeshInstance3D


func setup_starter(animal: AnimalActor) -> void:
	_animals.clear()
	_pending_rescues.clear()
	marker_valid = false
	animal.is_rescued = true
	_animals.append(animal)
	_set_controlled(0)
	party_changed.emit()


func register_caged(animal_id: StringName, animal: AnimalActor) -> void:
	animal.is_rescued = false
	_pending_rescues[animal_id] = animal


func rescue(animal_id: StringName, warp_near_leader: bool = true) -> bool:
	if not _pending_rescues.has(animal_id):
		return false
	var animal: AnimalActor = _pending_rescues[animal_id]
	_pending_rescues.erase(animal_id)
	if animal.is_rescued and _animals.has(animal):
		return false
	animal.is_rescued = true
	animal.set_confined(false)
	if warp_near_leader and not _animals.is_empty():
		animal.global_position = _animals[_controlled_index].global_position + Vector3(1.2, 0, 0)
	_animals.append(animal)
	animal.set_follow_target(_animals[_controlled_index])
	animal.order_follow()
	Bus.animal_rescued.emit(animal_id)
	party_changed.emit()
	return true


## Animals still caged (not yet in the party).
func pending_rescue_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _pending_rescues:
		out.append(id)
	return out


func controlled() -> AnimalActor:
	if _animals.is_empty():
		return null
	return _animals[_controlled_index]


func party() -> Array[AnimalActor]:
	return _animals


func switch_next() -> void:
	if _animals.size() < 2:
		Bus.interact_feedback.emit("还没有可换控的同伴")
		return
	_set_controlled(_controlled_index + 1)
	var a := controlled()
	if a and a.is_confined:
		Bus.interact_feedback.emit("%s 在本区关禁闭（可区内活动，门有人守）" % a.display_name())
	else:
		Bus.interact_feedback.emit("换控 — 刚退下的同伴已待命（按 F 再跟随）")


func order_all(mode: AnimalActor.FollowMode) -> void:
	for i in _animals.size():
		if i == _controlled_index:
			continue
		var a := _animals[i]
		if a.is_confined:
			continue
		if mode == AnimalActor.FollowMode.FOLLOW:
			a.order_follow()
		elif mode == AnimalActor.FollowMode.GOTO:
			if marker_valid:
				a.order_goto(marker_position)
		else:
			a.order_hold(false)
	var label := "跟随"
	if mode == AnimalActor.FollowMode.HOLD:
		label = "待命"
	elif mode == AnimalActor.FollowMode.GOTO:
		label = "前往标记点"
	Bus.interact_feedback.emit("队友：%s" % label)


## 在當前控制者位置放下標記，並命令同伴前往。
func order_goto_marker() -> void:
	var leader := controlled()
	if leader == null:
		return
	marker_position = leader.global_position
	marker_valid = true
	_ensure_marker_visual()
	_marker_mesh.global_position = marker_position + Vector3(0, 0.05, 0)
	_marker_mesh.visible = true
	marker_changed.emit(true, marker_position)
	order_all(AnimalActor.FollowMode.GOTO)


func on_danger_approach_leader() -> void:
	## 只提示，不強制隊友停止（玩家保有控制權）。
	Bus.interact_feedback.emit("前方是办公室危险区 — 队友仍跟随（H 待命 / F 跟上 / V 去标记）")


func on_danger_entered(body: Node3D) -> void:
	if body is AnimalActor:
		var actor := body as AnimalActor
		actor.enter_danger_auto_hold()
		if actor.is_controlled:
			on_danger_approach_leader()


func _set_controlled(index: int) -> void:
	if _animals.is_empty():
		return
	_controlled_index = wrapi(index, 0, _animals.size())
	for i in _animals.size():
		var a := _animals[i]
		var active := i == _controlled_index
		a.set_controlled(active)
		if not active and a.is_rescued and not a.is_confined:
			a.set_follow_target(_animals[_controlled_index])
	var cur := controlled()
	if cur:
		Bus.animal_switched.emit(cur)


func _ensure_marker_visual() -> void:
	if _marker_mesh != null and is_instance_valid(_marker_mesh):
		return
	_marker_mesh = MeshInstance3D.new()
	_marker_mesh.name = "PartyGotoMarker"
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.12, 0.55)
	_marker_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 0.9)
	mat.emission_energy_multiplier = 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mesh.material_override = mat
	var parent_n := get_parent()
	if parent_n:
		parent_n.add_child(_marker_mesh)
	else:
		add_child(_marker_mesh)
