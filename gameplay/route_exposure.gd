class_name RouteExposure
extends Node
## Live measurement of how often each work site sits in some staff member's vision during NIGHT_PATROL.
## Windows = unbroken unseen stretches (the seconds a builder can work without being spotted).
## Vision only: hearing reaches most of the yard at night, so it is reported separately (docs/COST_REFACTOR.md).

class Site:
	var label: String
	var spot: Vector3
	var patrol_sec: float = 0.0
	var seen_sec: float = 0.0
	var seen_now: bool = false
	var run_sec: float = 0.0
	var safe_windows: Array[float] = []
	var longest_seen: float = 0.0

	func ratio() -> float:
		return seen_sec / patrol_sec if patrol_sec > 0.0 else 0.0

	func mean_window() -> float:
		if safe_windows.is_empty():
			return run_sec if not seen_now else 0.0
		var t := 0.0
		for w in safe_windows:
			t += w
		return t / float(safe_windows.size())

	func longest_window() -> float:
		var best := 0.0 if seen_now else run_sec
		for w in safe_windows:
			best = maxf(best, w)
		return best


var sites: Array[Site] = []


## Analytic model for budgets/docs: the night posts are walked in list order (cyclic); a post "covers" the
## spot when its stare (face_dir) has the spot in cone, in range and in line of sight.
## Returns {cycle, seen, ratio, window, posts}. Look-around posts (no face_dir) are not counted.
static func estimate(net: PatrolNetwork, spot: Vector3, space: PhysicsDirectSpaceState3D,
		vision_range: float, vision_angle_deg: float, speed: float) -> Dictionary:
	var posts: Array[PatrolPointData] = []
	for p in net.points:
		if p.on_shift(true):
			posts.append(p)
	var cycle := 0.0
	var seen := 0.0
	var covering := PackedStringArray()
	for i in posts.size():
		var p := posts[i]
		var dwell := (p.dwell_min + p.dwell_max) * 0.5
		cycle += dwell + p.position.distance_to(posts[(i + 1) % posts.size()].position) / maxf(speed, 0.01)
		if p.face_dir.length() > 0.1 \
				and StaffSense.in_vision_cone(p.position, p.face_dir, spot, vision_range, vision_angle_deg) \
				and StaffSense.has_line_of_sight(space, p.position, spot):
			seen += dwell
			covering.append(String(p.id))
	var ratio := seen / cycle if cycle > 0.0 else 0.0
	return {"cycle": cycle, "seen": seen, "ratio": ratio, "window": cycle - seen, "posts": covering}


func add_site(label: String, spot: Vector3) -> Site:
	var s := Site.new()
	s.label = label
	s.spot = spot
	sites.append(s)
	return s


func reset() -> void:
	for s in sites:
		s.patrol_sec = 0.0
		s.seen_sec = 0.0
		s.seen_now = false
		s.run_sec = 0.0
		s.safe_windows.clear()
		s.longest_seen = 0.0


func _physics_process(delta: float) -> void:
	if Clock.phase != Clock.Phase.NIGHT_PATROL:
		for s in sites:
			_close_run(s)
			s.seen_now = false
		return
	var staff := get_tree().get_nodes_in_group("staff")
	for s in sites:
		var seen := false
		for n in staff:
			if n is StaffActor and (n as StaffActor).sees_point(s.spot):
				seen = true
				break
		if seen != s.seen_now:
			_close_run(s)
			s.seen_now = seen
		s.run_sec += delta
		s.patrol_sec += delta
		if seen:
			s.seen_sec += delta
			s.longest_seen = maxf(s.longest_seen, s.run_sec)


func _close_run(s: Site) -> void:
	if s.run_sec > 0.0 and not s.seen_now:
		s.safe_windows.append(s.run_sec)
	s.run_sec = 0.0


func debug_text() -> String:
	var rw := GameConst.route_work()
	var parts := PackedStringArray()
	for s in sites:
		parts.append("%s 视野暴露%.0f%%(目标%.0f–%.0f%%) %s 窗口:平均%.1fs 最长%.1fs 次数%d 最长被看%.1fs" % [
			s.label, s.ratio() * 100.0, rw.exposure_target_min * 100.0, rw.exposure_target_max * 100.0,
			"被看中" if s.seen_now else "安全%.1fs" % s.run_sec,
			s.mean_window(), s.longest_window(), s.safe_windows.size(), s.longest_seen,
		])
	return "\n  ".join(parts)
