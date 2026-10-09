extends Node
## Capture: bump alert, confiscate gear, send home, short detention (cage gathering allowed),
## staff stands at the door, cage door is reinforced for the rest of the day.
## At max alert, another capture ends the run (LOST).

## AnimalActor -> seconds of detention left
var _detained: Dictionary = {}


func _process(delta: float) -> void:
	if _detained.is_empty():
		return
	for a in _detained.keys():
		if not is_instance_valid(a) or not (a as AnimalActor).is_confined:
			_detained.erase(a)
			continue
		_detained[a] = float(_detained[a]) - delta
		if float(_detained[a]) <= 0.0:
			release(a as AnimalActor, "%s 短押结束，可再尝试开笼门（门已加固）")
	if _detained.is_empty():
		_clear_staff_guard()


func detention_left(animal: AnimalActor) -> float:
	return float(_detained.get(animal, 0.0))


func apply_capture(animal: AnimalActor, reason: String = "") -> void:
	if animal == null:
		return
	var world := get_tree().get_first_node_in_group("zoo_world")
	if world and world.get("session") is RunSession:
		var session: RunSession = world.get("session")
		if session.is_finished():
			return
		## Capture while already at max alert →封园失败（before bump would clamp).
		if Alert.level >= GameConst.MAX_ALERT_LEVEL:
			if session.try_lose_on_max_alert_capture():
				return
	var taken: Array[StringName] = animal.take_inventory()
	if not taken.is_empty():
		OfficeStorage.deposit(taken)
		Bus.interact_feedback.emit("物品被没收进办公室：%s" % ", ".join(PackedStringArray(taken)))
	animal.global_position = animal.home_position
	animal.velocity = Vector3.ZERO
	animal.set_confined(true)
	_detained[animal] = GameConst.DETENTION_SEC
	Alert.bump(1)
	_reinforce_and_guard(animal)
	Bus.captured.emit(animal)
	Bus.detention_changed.emit(animal)
	var why := "（%s）" % reason if not reason.is_empty() else ""
	Bus.interact_feedback.emit(
		"%s 被抓%s！送回笼内短押 %.0f 秒（笼里可搜集；同伴可撬门营救）。警戒 %d"
		% [animal.display_name(), why, GameConst.DETENTION_SEC, Alert.level]
	)


## Free a detained animal early (teammate rescue) or when its time is up.
func release(animal: AnimalActor, message: String = "") -> void:
	if animal == null or not is_instance_valid(animal):
		return
	_detained.erase(animal)
	if not animal.is_confined:
		return
	animal.set_confined(false)
	if animal.is_rescued and not animal.is_controlled:
		animal.order_follow()
	Bus.detention_changed.emit(animal)
	if message.contains("%s"):
		message = message % animal.display_name()
	elif message.is_empty():
		message = "%s 获释" % animal.display_name()
	Bus.interact_feedback.emit(message)
	if _detained.is_empty():
		_clear_staff_guard()


func _reinforce_and_guard(animal: AnimalActor) -> void:
	var world := get_tree().get_first_node_in_group("zoo_world")
	if world == null:
		return
	var door: Interactable = null
	if world.has_method("door_for_animal"):
		door = world.call("door_for_animal", animal) as Interactable
	if door:
		door.relock()
		door.reinforce()
	var staff: StaffActor = null
	if world.has_method("get_staff"):
		staff = world.call("get_staff") as StaffActor
	elif world.get("staff") is StaffActor:
		staff = world.get("staff") as StaffActor
	if staff and door:
		staff.assign_door_guard(door, door.global_position + door.guard_offset)


func _clear_staff_guard() -> void:
	for s in get_tree().get_nodes_in_group("staff"):
		if s is StaffActor:
			(s as StaffActor).clear_guard()
