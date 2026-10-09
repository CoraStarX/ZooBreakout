class_name CapabilityIds
extends RefCounted
## Capability pool verb ids. Routes check these, not species.

enum Id {
	NONE = 0,
	DEXTERITY = 1, ## 巧手
	CLIMB = 2, ## 攀爬
	DIG = 3, ## 挖掘
	RAM = 4, ## 冲撞
}


static func to_label(id: Id) -> String:
	match id:
		Id.DEXTERITY:
			return "巧手"
		Id.CLIMB:
			return "攀爬"
		Id.DIG:
			return "挖掘"
		Id.RAM:
			return "冲撞"
		_:
			return "—"
