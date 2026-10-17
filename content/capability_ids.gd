class_name CapabilityIds
extends RefCounted
## Capability pool verb ids. Routes check these, not species.

enum Id {
	NONE = 0,
	DEXTERITY = 1, ## 巧手
	CLIMB = 2, ## 攀爬
	DIG = 3, ## 挖掘（預留能力）
	RAM = 4, ## 冲撞
	SQUEEZE = 5, ## 钻缝
	THROW = 6, ## 投擲（預留能力）
	TINY_GAP = 7, ## 極小通道；與一般鑽縫能力區分
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
		Id.SQUEEZE:
			return "钻缝"
		Id.TINY_GAP:
			return "極小通道"
		Id.THROW:
			return "投掷"
		_:
			return "—"
