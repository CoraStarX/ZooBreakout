extends RefCounted
## Content: animal defs + home spawns for zoo_p0 (keeps zoo_world free of species coords).

const RACCOON := preload("res://content/animals/raccoon.tres")
const MONKEY := preload("res://content/animals/monkey.tres")


static func def_for(animal_id: StringName) -> AnimalDef:
	match animal_id:
		&"raccoon":
			return RACCOON
		&"monkey":
			return MONKEY
		_:
			return null


static func home_for(animal_id: StringName) -> Vector3:
	match animal_id:
		&"raccoon":
			return Vector3(-5, 0.05, -6)
		&"monkey":
			return Vector3(6.2, 0.05, -3.0)
		_:
			return Vector3.ZERO


static func companion_id(starter_id: StringName) -> StringName:
	return &"monkey" if starter_id == &"raccoon" else &"raccoon"


static func resolve_starter(starter_id: StringName) -> StringName:
	if def_for(starter_id) != null:
		return starter_id
	return &"raccoon"
