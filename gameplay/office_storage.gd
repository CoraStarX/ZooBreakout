extends Node
## Confiscated items live here until stolen back from the office.

signal items_changed

var items: Array[StringName] = []


func deposit(item_ids: Array[StringName]) -> void:
	for id in item_ids:
		if id != &"":
			items.append(id)
	items_changed.emit()
	Bus.office_items_changed.emit(items.duplicate())


func take_all() -> Array[StringName]:
	var out := items.duplicate()
	items.clear()
	items_changed.emit()
	Bus.office_items_changed.emit(items.duplicate())
	return out


func has_items() -> bool:
	return not items.is_empty()


func summary() -> String:
	if items.is_empty():
		return "空"
	return ", ".join(PackedStringArray(items))
