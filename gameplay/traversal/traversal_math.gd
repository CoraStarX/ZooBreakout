class_name TraversalMath
extends RefCounted
## 純函式：候選範圍、方向評分與鎖點遲滯，與輸入／物理查詢分離。

static func arc_point(start: Vector3, finish: Vector3, t: float, arc: float) -> Vector3:
	var u := clampf(t, 0.0, 1.0)
	return start.lerp(finish, u) + Vector3.UP * (4.0 * arc * u * (1.0 - u))


static func jump_score(origin: Vector3, direction: Vector3, takeoff: Vector3,
		landing: Vector3, params: TraversalParams) -> float:
	if not jump_rejection(origin, takeoff, landing, params).is_empty():
		return -INF
	var offset := landing - takeoff
	var planar := Vector3(offset.x, 0.0, offset.z)
	# 朝向只用來比較多個候選，不再成為「先轉身才准跳」的硬門檻。
	return direction_score(direction, planar)

static func direction_score(direction: Vector3, displacement: Vector3) -> float:
	var planar := Vector3(displacement.x, 0.0, displacement.z)
	var intent := Vector3(direction.x, 0.0, direction.z)
	return 0.0 if intent.is_zero_approx() or planar.is_zero_approx() else planar.normalized().dot(intent.normalized())

static func cross_context_valid(origin: Vector3, takeoff: Vector3, params: TraversalParams) -> bool:
	var offset := origin - takeoff
	var height_ok := absf(offset.y) <= params.cross_context_height_tolerance or is_equal_approx(absf(offset.y), params.cross_context_height_tolerance)
	var distance := Vector2(offset.x, offset.z).length()
	var limit := params.takeoff_range + params.cross_context_extra_range
	return height_ok and (distance <= limit or is_equal_approx(distance, limit))

static func wants_cross(across: float, along: float, gap_distance: float, side_distance: float, params: TraversalParams) -> bool:
	if across < cos(deg_to_rad(params.cross_intent_degrees)): return false
	if along <= params.input_deadzone or is_inf(side_distance): return true
	# 比較先接近哪條實際支撐邊界，而不是讓「往地面永遠同向」的分數勝出。
	return side_distance / along > gap_distance / across + params.edge_intent_tie_distance


static func jump_rejection(origin: Vector3, takeoff: Vector3, landing: Vector3, params: TraversalParams) -> String:
	if origin.distance_to(takeoff) > params.takeoff_range: return "未進入起跳吸附範圍"
	var offset := landing - takeoff
	if Vector2(offset.x, offset.z).length() > params.max_jump_distance: return "落點過遠"
	if absf(offset.y) > params.max_jump_height: return "落點高度超限"
	if Vector3(offset.x, 0, offset.z).is_zero_approx(): return "無水平跨越距離"
	return ""


static func choose(scores: Array[float], previous: int, hysteresis: float) -> int:
	var best := -1
	for i in scores.size():
		if is_finite(scores[i]) and (best < 0 or scores[i] > scores[best]):
			best = i
	## 小幅方向抖動不換落點；舊點失效時則立即釋放，避免黏住錯誤目標。
	if best >= 0 and previous >= 0 and previous < scores.size() and is_finite(scores[previous]):
		if scores[best] - scores[previous] <= hysteresis:
			return previous
	return best


static func safe_walk_velocity(requested: Vector3, full_safe: bool, x_safe: bool, z_safe: bool) -> Vector3:
	if full_safe:
		return requested
	# 保留沿邊方向，避免斜推懸崖時整個角色黏住；不自行添加玩家沒輸入的方向。
	if x_safe and (not z_safe or absf(requested.x) >= absf(requested.z)):
		return Vector3(requested.x, 0.0, 0.0)
	if z_safe:
		return Vector3(0.0, 0.0, requested.z)
	return Vector3.ZERO


static func intent_matches(direction: Vector3, toward: Vector3, degrees: float) -> bool:
	return not direction.is_zero_approx() and direction.normalized().dot(toward.normalized()) >= cos(deg_to_rad(degrees)) - 0.00001


static func intent_time(previous: float, matching: bool, delta: float) -> float:
	return previous + delta if matching else 0.0


static func closest_edge(point: Vector3, start: Vector3, end: Vector3) -> Vector3:
	var edge := end - start
	if edge.is_zero_approx():
		return start
	return start + edge * clampf((point - start).dot(edge) / edge.length_squared(), 0.0, 1.0)


static func window_valid(left: float) -> bool:
	return left > 0.0


static func landing_loudness(height: float, params: TraversalParams) -> float:
	return 0.0 if height < params.landing_noise_min_height else clampf(height * params.landing_noise_per_meter, 0.0, params.landing_noise_max)


static func polyline_point(points: PackedVector3Array, t: float) -> Vector3:
	if points.size() == 1:
		return points[0]
	var u := clampf(t, 0.0, 1.0) * (points.size() - 1)
	var index := mini(floori(u), points.size() - 2)
	var local := u - index
	return points[index].lerp(points[index + 1], smoothstep(0.0, 1.0, local))
