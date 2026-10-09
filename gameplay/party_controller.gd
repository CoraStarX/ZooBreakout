class_name PartyController
extends Node
## GamePlay: switch control, follow/hold orders, rescue into party.

signal party_changed

var _animals: Array[AnimalActor] = []
var _controlled_index: int = 0
var _pending_rescues: Dictionary = {} ## StringName id -> AnimalActor not yet in party


func setup_starter(animal: AnimalActor) -> void:
	_animals.clear()
	_pending_rescues.clear()
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


func order_all(mode: AnimalActor.FollowMode) -> void:
	for i in _animals.size():
		if i == _controlled_index:
			continue
		var a := _animals[i]
		if a.is_confined:
			continue
		if mode == AnimalActor.FollowMode.FOLLOW:
			a.order_follow()
		else:
			a.order_hold(false) # player H — do not auto-resume
	Bus.interact_feedback.emit("队友：%s" % ("跟随" if mode == AnimalActor.FollowMode.FOLLOW else "待命"))


func on_danger_approach_leader() -> void:
	## Leader nearing office: park all free followers outside core.
	var any := false
	for a in _animals:
		if a.is_controlled or a.is_confined:
			continue
		var was_follow := a.follow_mode == AnimalActor.FollowMode.FOLLOW
		a.order_hold(false)
		if was_follow:
			any = true
	if any:
		Bus.interact_feedback.emit("前方是办公室危险区 — 队友已在入口外待命")
	else:
		Bus.interact_feedback.emit("前方是办公室危险区")


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
