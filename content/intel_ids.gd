class_name IntelIds
extends RefCounted
## Intel the player can learn at observation points (persists across days).

const REST_TIME := &"rest_time" ## 歇岗时刻：解锁「距歇岗」倒计时
const PATROL_ROUTE := &"patrol_route" ## 巡逻路线：在地面画出职员路线


static func display_name(id: StringName) -> String:
	match id:
		REST_TIME:
			return "歇岗时刻"
		PATROL_ROUTE:
			return "巡逻路线"
		_:
			return String(id)
