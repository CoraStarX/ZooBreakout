class_name FollowTrail
extends RefCounted
## 玩家麵包屑軌跡：間隔記錄，供夥伴沿路徑跟隨（無 NavMesh）。

var points: Array[Vector3] = []


func clear() -> void:
	points.clear()


func record(pos: Vector3, spacing: float, max_points: int) -> void:
	if max_points < 2:
		return
	if points.is_empty():
		points.append(pos)
		return
	var last: Vector3 = points[points.size() - 1]
	var d := Vector3(pos.x - last.x, 0.0, pos.z - last.z).length()
	if d < spacing:
		return
	points.append(Vector3(pos.x, pos.y, pos.z))
	while points.size() > max_points:
		points.pop_front()


## 跟隨目標：找最近軌跡點，再往「較新」方向超前若干點（朝向隊長）。
func target_for(follower_pos: Vector3, look_ahead: int = 4) -> Vector3:
	if points.is_empty():
		return follower_pos
	var nearest_i := 0
	var nearest_d := INF
	for i in points.size():
		var d := follower_pos.distance_to(points[i])
		if d < nearest_d:
			nearest_d = d
			nearest_i = i
	var ahead := clampi(nearest_i + maxi(1, look_ahead), 0, points.size() - 1)
	return points[ahead]


func rewind_target(follower_pos: Vector3, steps_back: int) -> Vector3:
	if points.is_empty():
		return follower_pos
	var nearest_i := points.size() - 1
	var nearest_d := INF
	for i in points.size():
		var d := follower_pos.distance_to(points[i])
		if d < nearest_d:
			nearest_d = d
			nearest_i = i
	var idx := clampi(nearest_i - maxi(1, steps_back), 0, points.size() - 1)
	return points[idx]


func latest() -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	return points[points.size() - 1]
