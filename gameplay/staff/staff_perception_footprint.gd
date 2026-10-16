class_name StaffPerceptionFootprint
extends RefCounted
## 純幾何：網格與判定共用這份星形多邊形，不各自維護解析圓錐。
static func flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

static func projected(position: Vector3, climbing: bool, wall_origin: Vector3, wall_normal: Vector3, outside: float) -> Vector3:
	var p := position
	if climbing:
		var normal := Vector3(wall_normal.x, 0, wall_normal.z).normalized()
		p += normal * (outside - (p - wall_origin).dot(normal))
	p.y = 0
	return p

static func ray_rect(origin: Vector2, direction: Vector2, rect: Rect2) -> Dictionary:
	var near := -INF
	var far := INF
	var normal := Vector2.ZERO
	for axis in 2:
		if is_zero_approx(direction[axis]):
			if origin[axis] < rect.position[axis] or origin[axis] > rect.end[axis]: return {}
			continue
		var lo := (rect.position[axis] - origin[axis]) / direction[axis]
		var hi := (rect.end[axis] - origin[axis]) / direction[axis]
		var entry := minf(lo, hi)
		if entry > near:
			near = entry
			normal = Vector2.ZERO
			normal[axis] = -signf(direction[axis])
		far = minf(far, maxf(lo, hi))
		if near > far: return {}
	if far < 0: return {}
	return {"entry": maxf(near, 0), "exit": far, "normal": normal}

static func build(origin: Vector3, facing: Vector3, obstacles: Array[Dictionary], p: StaffReadabilityParams) -> PackedVector2Array:
	var center := flat(origin)
	var yaw := atan2(facing.x, facing.z)
	var half := deg_to_rad(p.ai.vision_angle_deg * 0.5)
	var angles: Array[float] = []
	for i in range(p.fan_segments + 1): angles.append(lerpf(-half, half, float(i) / p.fan_segments))
	# 在遮擋角點兩側補射線，避免固定低分段把牆後空間誤畫成可見。
	for obstacle in obstacles:
		var rect: Rect2 = obstacle["rect"]
		for corner in [rect.position, rect.end, Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
			var offset: Vector2 = corner - center
			var angle := wrapf(atan2(offset.x, offset.y) - yaw, -PI, PI)
			for epsilon in [-p.corner_angle_epsilon, 0.0, p.corner_angle_epsilon]:
				if absf(angle + epsilon) < half: angles.append(angle + epsilon)
	angles.sort()
	var result := PackedVector2Array([center])
	for angle in angles:
		var direction := Vector2(sin(yaw + angle), cos(yaw + angle))
		var limit := p.ai.vision_range
		var first := INF
		for obstacle in obstacles:
			var hit := ray_rect(center, direction, obstacle["rect"])
			if hit.is_empty() or float(hit["entry"]) >= first: continue
			first = hit["entry"]
			# 只延伸進第一個遮擋的近側屋頂邊帶，不穿透建築看遠側。
			var band := p.roof_edge_cells * p.grid_unit_m if obstacle.get("roof", false) else 0.0
			var incidence := absf(direction.dot(hit["normal"]))
			var depth := band / incidence if incidence > 0 else 0.0
			limit = minf(p.ai.vision_range, minf(float(hit["exit"]), first + depth))
		result.append(center + direction * limit)
	return result

static func contains(polygon: PackedVector2Array, point: Vector3) -> bool:
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(flat(point), polygon)

static func mesh(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, polygon.size() - 1):
		for point in [polygon[0], polygon[i], polygon[i + 1]]:
			builder.add_vertex(Vector3(point.x, height, point.y))
	return builder.commit()

static func heard(origin: Vector3, position: Vector3, loudness: float, resting: bool, p: StaffReadabilityParams) -> bool:
	var radius := p.ai.hear_noise_range * maxf(0, loudness) * (maxf(p.rest_hearing_floor,p.rest_hearing_mult) if resting else 1.0)
	return loudness > 0 and flat(origin).distance_to(flat(position)) <= radius

static func extend_deadline(start: float, deadline: float, already_extended: bool, p: StaffReadabilityParams) -> float:
	return deadline if already_extended else minf(start + p.search_sec * p.search_max_mult, deadline + p.search_sec)

static func same_source(key: String, position: Vector3, previous_key: String, previous_position: Vector3, p: StaffReadabilityParams) -> bool:
	return key == previous_key if not key.is_empty() else previous_key.is_empty() and flat(position).distance_to(flat(previous_position)) <= p.same_source_radius

static func walkable_line(from: Vector3, to: Vector3, obstacles: Array[Dictionary], radius: float) -> bool:
	var origin := flat(from)
	var motion := flat(to) - origin
	for obstacle in obstacles:
		var rect: Rect2 = (obstacle["rect"] as Rect2).grow(radius)
		if rect.has_point(origin) or rect.has_point(flat(to)): return false
		if motion.is_zero_approx(): continue
		var hit := ray_rect(origin, motion.normalized(), rect)
		if not hit.is_empty() and float(hit["entry"]) < motion.length(): return false
	return true

static func next_hop(from: Vector3, goal: Vector3, nodes: Array[Vector3], obstacles: Array[Dictionary], radius: float) -> Dictionary:
	if walkable_line(from,goal,obstacles,radius): return {"ok":true,"point":goal}
	var costs: Array[float] = []
	var first: Array[int] = []
	var visited: Array[bool] = []
	for i in nodes.size():
		var direct := walkable_line(from,nodes[i],obstacles,radius)
		costs.append(flat(from).distance_to(flat(nodes[i])) if direct else INF)
		first.append(i)
		visited.append(false)
	for _i in nodes.size():
		var u := -1
		for j in nodes.size():
			if not visited[j] and costs[j] < INF and (u < 0 or costs[j] < costs[u]): u = j
		if u < 0: break
		visited[u] = true
		for v in nodes.size():
			var distance := costs[u] + flat(nodes[u]).distance_to(flat(nodes[v]))
			if not visited[v] and distance < costs[v] and walkable_line(nodes[u],nodes[v],obstacles,radius):
				costs[v] = distance
				first[v] = first[u]
	var best := -1
	var total := INF
	for i in nodes.size():
		var distance := costs[i] + flat(nodes[i]).distance_to(flat(goal))
		if distance < total and walkable_line(nodes[i],goal,obstacles,radius):
			total = distance
			best = i
	return {"ok":best >= 0,"point":nodes[first[best]] if best >= 0 else from}

## 落地事件以腳下實際支撐面確認地面，容許物理分離殘高；不是放寬屋頂可達性。
static func ground_supported(position: Vector3, support_y: float, p: StaffReadabilityParams) -> bool:
	return is_finite(support_y) and absf(support_y-p.ground_y) <= p.ground_height_tolerance and absf(position.y-support_y) <= p.ground_probe_height

static func can_extend_search(search_memory: Dictionary, noise_memory: Dictionary, p: StaffReadabilityParams) -> bool:
	return not search_memory.is_empty() and not bool(search_memory.reachable) and not bool(noise_memory.reachable) and same_source(noise_memory.get("key",""),noise_memory.projection,search_memory.get("key",""),search_memory.projection,p)

## 原始記憶不變；只替員工選擇既有點網中最近且真正走得到的接近點。
static func approach_hop(from: Vector3, goal: Vector3, nodes: Array[Vector3], obstacles: Array[Dictionary], radius: float) -> Dictionary:
	var direct := next_hop(from,goal,nodes,obstacles,radius)
	if direct.ok:
		direct["goal"] = goal
		return direct
	var best := INF
	var result := {"ok":false,"point":from,"goal":goal}
	for node in nodes:
		var distance := flat(node).distance_squared_to(flat(goal))
		if distance >= best: continue
		var hop := next_hop(from,node,nodes,obstacles,radius)
		if hop.ok:
			best = distance
			result = {"ok":true,"point":hop.point,"goal":node}
	return result

## 聽距與增量共用半徑；小聲攀爬不再等同全音量+28，遠處只留下較弱注意。
static func hearing_gain(origin: Vector3, position: Vector3, loudness: float, resting: bool, p: StaffReadabilityParams) -> float:
	if not heard(origin,position,loudness,resting,p): return 0.0
	var radius := p.ai.hear_noise_range * loudness * (maxf(p.rest_hearing_floor,p.rest_hearing_mult) if resting else 1.0)
	if radius <= 0: return 0.0
	var distance_ratio := clampf(flat(origin).distance_to(flat(position))/radius,0,1)
	return p.ai.noise_awareness_spike * clampf(loudness,0,1) * lerpf(1.0,p.hearing_far_gain_mult,distance_ratio)

static func noise_ready(time: float, next_allowed: float) -> bool:
	return time >= next_allowed

static func reacquire_ground(state: StringName, seeing: bool, reachable: bool) -> bool:
	return state == &"SEARCH" and seeing and reachable
