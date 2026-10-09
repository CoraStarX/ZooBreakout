class_name KitIds
extends RefCounted
## Items: named route kits + raw materials. Not a deep crafting tree.

const DIG := &"dig_kit"
const CLIMB := &"climb_kit"
## 原料：不同区域/动词/风险产出不同原料；路线每档要求两种搭配。
const ROPE := &"rope"
const WOOD := &"wood"
const METAL := &"metal"

const MATERIALS: Array[StringName] = [ROPE, WOOD, METAL]


static func is_material(id: StringName) -> bool:
	return MATERIALS.has(id)


static func display_name(id: StringName) -> String:
	match id:
		DIG:
			return "挖掘套件"
		CLIMB:
			return "攀爬套件"
		ROPE:
			return "绳索"
		WOOD:
			return "木料"
		METAL:
			return "金属"
		_:
			return String(id)

