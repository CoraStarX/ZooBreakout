class_name ZooP0Patrol
extends RefCounted
## Content: staff patrol data for zoo_p0.
## 階段 B：加權點網為正式來源；route_book 僅對照／廢棄保留，下一階段再刪。

const LOOP_NE := &"loop_ne"
const LOOP_WIDE := &"loop_wide"
const SPUR_SHED := &"spur_shed"
const SPUR_PLAZA := &"spur_plaza"
const START := LOOP_NE


## DEPRECATED：固定路線冊。請改用 make_patrol_network()。
static func route_book() -> Dictionary:
	return {
		LOOP_NE: [
			Vector3(5.5, 0.05, 5.5),
			Vector3(8.5, 0.05, 7.0),
			Vector3(7.0, 0.05, 9.0),
			Vector3(4.0, 0.05, 7.5),
		],
		LOOP_WIDE: [
			Vector3(5.5, 0.05, 5.5),
			Vector3(9.0, 0.05, 6.5),
			Vector3(8.0, 0.05, 9.5),
			Vector3(3.0, 0.05, 8.5),
			Vector3(-1.0, 0.05, 6.0),
			Vector3(2.0, 0.05, 4.0),
		],
		SPUR_SHED: [
			Vector3(5.5, 0.05, 5.5),
			Vector3(6.6, 0.05, 3.8),
			Vector3(7.8, 0.05, 4.8),
			Vector3(6.2, 0.05, 6.2),
		],
		SPUR_PLAZA: [
			Vector3(4.0, 0.05, 7.5),
			Vector3(1.0, 0.05, 5.5),
			Vector3(-2.5, 0.05, 5.2),
			Vector3(0.5, 0.05, 3.5),
			Vector3(3.5, 0.05, 5.0),
		],
	}


## 由舊路點去重生成加權點網（保留關卡覆蓋，行為改為選點）。
static func make_patrol_network() -> PatrolNetwork:
	var net := PatrolNetwork.new()
	var specs: Array[Dictionary] = [
		{"id": &"ne_a", "pos": Vector3(5.5, 0.05, 5.5), "imp": 1.0},
		{"id": &"ne_b", "pos": Vector3(8.5, 0.05, 7.0), "imp": 1.0},
		{"id": &"ne_c", "pos": Vector3(7.0, 0.05, 9.0), "imp": 1.05},
		{"id": &"ne_d", "pos": Vector3(4.0, 0.05, 7.5), "imp": 1.0},
		{"id": &"wide_e", "pos": Vector3(9.0, 0.05, 6.5), "imp": 1.1},
		{"id": &"wide_n", "pos": Vector3(8.0, 0.05, 9.5), "imp": 1.1},
		{"id": &"wide_w", "pos": Vector3(3.0, 0.05, 8.5), "imp": 1.15},
		{"id": &"plaza_gate", "pos": Vector3(-1.0, 0.05, 6.0), "imp": 1.25},
		{"id": &"plaza_mid", "pos": Vector3(2.0, 0.05, 4.0), "imp": 1.2},
		{"id": &"shed", "pos": Vector3(6.6, 0.05, 3.8), "imp": 1.45},
		{"id": &"shed_east", "pos": Vector3(7.8, 0.05, 4.8), "imp": 1.3},
		{"id": &"trash", "pos": Vector3(-2.5, 0.05, 5.2), "imp": 1.2},
		{"id": &"visitor_rope", "pos": Vector3(0.5, 0.05, 3.5), "imp": 1.15},
	]
	var params := StaffAiParams.new()
	for s in specs:
		var p := PatrolPointData.new().configure(
			s["id"],
			s["pos"],
			float(s["imp"]),
			params.dwell_sec_min,
			params.dwell_sec_max
		)
		net.add_point(p)
	return net


static func spur_order() -> Array[StringName]:
	return [SPUR_SHED, SPUR_PLAZA, LOOP_WIDE]


static func display_name(id: StringName) -> String:
	match id:
		LOOP_NE:
			return "东北主环"
		LOOP_WIDE:
			return "外围宽环"
		SPUR_SHED:
			return "工具间支线"
		SPUR_PLAZA:
			return "广场支线"
		_:
			return String(id)
