class_name PatrolPointData
extends RefCounted
## 單一巡邏點運行時資料（非 Resource，由關卡注入後可寫 last_visited/heat）。

var id: StringName = &""
var position: Vector3 = Vector3.ZERO
var importance: float = 1.0
var dwell_min: float = 3.0
var dwell_max: float = 8.0
var last_visited: float = -9999.0
var heat: float = 0.0
enum Shift { BOTH, DAY, NIGHT, ROUTE }
## Which part of the day the staff may pick this point (night = escape phases). ROUTE = never picked,
## only a hop for routing round walls.
var shift: Shift = Shift.BOTH
## Watch posts: face this way while dwelling (ZERO = keep the arrival heading).
var face_dir: Vector3 = Vector3.ZERO


func configure(
	p_id: StringName,
	pos: Vector3,
	p_importance: float = 1.0,
	p_dwell_min: float = 3.0,
	p_dwell_max: float = 8.0
) -> PatrolPointData:
	id = p_id
	position = pos
	importance = p_importance
	dwell_min = p_dwell_min
	dwell_max = p_dwell_max
	return self


func on_shift(night: bool) -> bool:
	if shift == Shift.ROUTE:
		return false
	return shift == Shift.BOTH or (shift == Shift.NIGHT) == night
