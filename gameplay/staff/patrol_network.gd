class_name PatrolNetwork
extends RefCounted
## 加權巡邏點網 + 極簡預約（reserve/release）。單職員也走同一流程。

var points: Array[PatrolPointData] = []
## Temporary extra points (full search): scored like any other point, heat pinned by the caller.
var focus_points: Array[PatrolPointData] = []
## point_id -> staff get_instance_id()
var _reserved: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func set_seed(seed: int) -> void:
	_rng.seed = seed


func add_point(p: PatrolPointData) -> void:
	points.append(p)


func clear() -> void:
	points.clear()
	_reserved.clear()


## Replaces focus points (ids focus_0..n keep their visit history), each with `heat`. Empty clears.
func set_focus(positions: Array[Vector3], heat: float, dwell_min: float, dwell_max: float) -> void:
	while focus_points.size() > positions.size():
		var gone: PatrolPointData = focus_points.pop_back()
		_reserved.erase(gone.id)
	for i in positions.size():
		if i >= focus_points.size():
			focus_points.append(PatrolPointData.new().configure(StringName("focus_%d" % i), positions[i], 1.0, dwell_min, dwell_max))
		focus_points[i].position = positions[i]
		focus_points[i].heat = heat


func find(point_id: StringName) -> PatrolPointData:
	for p in points:
		if p.id == point_id:
			return p
	for p in focus_points:
		if p.id == point_id:
			return p
	return null


func is_focus_id(point_id: StringName) -> bool:
	return String(point_id).begins_with("focus_")


func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in points:
		out.append(p.position)
	return out


func tick_heat(delta: float, params: StaffAiParams) -> void:
	if params == null:
		return
	for p in points:
		p.heat = maxf(0.0, p.heat - params.heat_decay_per_sec * delta)


func reserve(point_id: StringName, staff_id: int) -> bool:
	if point_id == &"":
		return false
	if _reserved.has(point_id) and int(_reserved[point_id]) != staff_id:
		return false
	_reserved[point_id] = staff_id
	return true


func release(point_id: StringName, staff_id: int) -> void:
	if not _reserved.has(point_id):
		return
	if int(_reserved[point_id]) == staff_id:
		_reserved.erase(point_id)


func is_reserved_by_other(point_id: StringName, staff_id: int) -> bool:
	return _reserved.has(point_id) and int(_reserved[point_id]) != staff_id


func apply_heat_near(pos: Vector3, amount: float, radius: float = 3.0) -> void:
	for p in points:
		if p.position.distance_to(pos) <= radius:
			p.heat = minf(100.0, p.heat + amount)


func pick_next(
	from_pos: Vector3,
	staff_id: int,
	params: StaffAiParams,
	now_sec: float,
	recent_ids: Array,
	current_id: StringName = &""
) -> PatrolPointData:
	if points.is_empty() or params == null:
		return null
	var scores: Array = []
	var candidates: Array[PatrolPointData] = []
	var night := Clock.allows_escape_actions()
	var all: Array[PatrolPointData] = focus_points.duplicate()
	for p in points:
		if p.on_shift(night):
			all.append(p)
	for p in all:
		if p.id == current_id:
			continue
		if is_reserved_by_other(p.id, staff_id):
			continue
		candidates.append(p)
		scores.append(PatrolScoreMath.score_point(p, now_sec, from_pos, params, recent_ids, _rng))
	if candidates.is_empty():
		## 全被預約時放寬：允許選分最高者（仍跳過當前點）。
		for p in all:
			if p.id == current_id:
				continue
			candidates.append(p)
			scores.append(PatrolScoreMath.score_point(p, now_sec, from_pos, params, recent_ids, _rng))
	var best_i := PatrolScoreMath.pick_best_index(scores)
	if best_i < 0 or best_i >= candidates.size():
		return null
	return candidates[best_i]


func closest_to(pos: Vector3) -> PatrolPointData:
	var best: PatrolPointData = null
	var best_d := INF
	for p in points:
		var d := pos.distance_squared_to(p.position)
		if d < best_d:
			best_d = d
			best = p
	return best
