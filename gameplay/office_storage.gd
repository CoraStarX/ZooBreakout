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
	return take(items.size())


## Oldest first; whatever is not taken stays in the office.
func take(count: int) -> Array[StringName]:
	var out: Array[StringName] = items.slice(0, maxi(count, 0))
	items = items.slice(out.size())
	items_changed.emit()
	Bus.office_items_changed.emit(items.duplicate())
	return out


func has_items() -> bool:
	return not items.is_empty()


func summary() -> String:
	if items.is_empty():
		return "空"
	return ", ".join(PackedStringArray(items))
