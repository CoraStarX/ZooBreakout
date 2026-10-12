class_name CageDependencyCheck
extends RefCounted
## Load-time guard for cage configs: every caged animal must be freeable by someone already outside.


## cages: animal id -> its cage door. defs: animal id -> AnimalDef. Returns readable errors (empty = OK).
static func validate(cages: Dictionary, defs: Dictionary, starter_id: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	var free := {}
	var starter_door := cages.get(starter_id) as Interactable
	if starter_door == null or starter_door.can_be_opened_by(defs.get(starter_id) as AnimalDef):
		free[starter_id] = true
	else:
		errors.append("开局动物 %s 打不开自己的笼门（需要 %s）" % [starter_id, starter_door.requirement_text()])
	for id in cages:
		if id == starter_id:
			continue
		var door := cages[id] as Interactable
		var openers := PackedStringArray()
		for other in defs:
			if door.can_be_opened_by(defs[other] as AnimalDef):
				openers.append(String(other))
		if openers.size() == 1 and openers[0] == String(id):
			errors.append("循环依赖：%s 的笼门只有 %s 自己能开（需要 %s），但它被关在门后" % [
				id, id, door.requirement_text()
			])
	## Fixpoint: free animals open cages of the rest.
	var changed := true
	while changed:
		changed = false
		for id in cages:
			if free.has(id):
				continue
			var door := cages[id] as Interactable
			for other in free:
				if door.can_be_opened_by(defs.get(other) as AnimalDef):
					free[id] = true
					changed = true
					break
	for id in cages:
		if not free.has(id):
			errors.append("无法解救：没有已出笼的动物能打开 %s 的笼门（需要 %s）" % [
				id, (cages[id] as Interactable).requirement_text()
			])
	return errors
