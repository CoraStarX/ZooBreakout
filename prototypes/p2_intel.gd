extends Node
## 昼夜 M4：情报观察点。
## godot --headless --path . res://prototypes/p2_intel.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Intel ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var geo: ZooP0Geometry = world.get_node("Geometry")
	var session: RunSession = world.get("session")
	var actor: AnimalActor = world.get("party").controlled()
	var staff: StaffActor = world.call("get_staff")
	staff.set_physics_process(false) ## freeze so positions are deterministic
	var rest_pt := _point(geo, IntelIds.REST_TIME)
	var route_pt := _point(geo, IntelIds.PATROL_ROUTE)
	_check(rest_pt != null and route_pt != null, "两个观察点已生成")
	_check_not_in_walls(world, geo)

	## 1) Staff out of range → no progress.
	staff.global_position = Vector3(10, 0.05, 10)
	_stand(actor, rest_pt)
	rest_pt.try_use(actor)
	await get_tree().create_timer(GameConst.OBSERVE_SEC * 0.5 + 0.5).timeout
	_check(rest_pt._busy and not session.has_intel(IntelIds.REST_TIME), "职员不在视野：进度暂停、无情报")
	actor.global_position = rest_pt.global_position + Vector3(5, 0, 0)
	await get_tree().create_timer(0.3).timeout
	_check(not rest_pt._busy, "离开观察点取消")

	## 2) Staff behind a wall → no progress.
	staff.global_position = Vector3(-2, 0.05, -4)
	_check(rest_pt.visible_staff() == null, "墙后职员不可见")

	## 3) Staff in clear view → completes.
	staff.global_position = Vector3(3.0, 0.05, 3.2)
	_check(rest_pt.visible_staff() == staff, "开阔处职员可见")
	_stand(actor, rest_pt)
	rest_pt.try_use(actor)
	await get_tree().create_timer(GameConst.OBSERVE_SEC + 0.8).timeout
	_check(session.has_intel(IntelIds.REST_TIME), "观察完成 → 获得歇岗时刻")
	_check(not rest_pt._busy, "观察结束释放")

	## 4) Chase interrupts.
	staff.global_position = Vector3(10.5 - 3.0, 0.05, 3.5)
	_stand(actor, route_pt)
	route_pt.try_use(actor)
	await get_tree().create_timer(0.5).timeout
	staff.state = StaffActor.State.CHASE
	await get_tree().create_timer(0.3).timeout
	_check(not route_pt._busy and not session.has_intel(IntelIds.PATROL_ROUTE), "被职员察觉 → 观察失败")
	staff.state = StaffActor.State.PATROL

	## 5) Route intel draws the loop.
	_check(staff._route_node == null, "未获情报时不画路线")
	session.learn_intel(IntelIds.PATROL_ROUTE)
	_check(staff._route_node != null and staff._route_node.visible, "获得路线情报后画出巡逻线")
	_check(staff._route_node.get_child_count() == staff.waypoints.size(), "路线段数 = 路点数")

	## 6) Clock helper.
	Clock.set_phase(Clock.Phase.OPEN)
	var expect := Clock.phase_remaining() + GameConst.CLOSE_PHASE_SEC + Clock.night_patrol_duration()
	_check(is_equal_approx(Clock.seconds_until_quiet(), expect), "Open 距歇岗 = 剩余+闭园+夜巡")
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	_check(is_equal_approx(Clock.seconds_until_quiet(), Clock.phase_remaining()), "夜巡中距歇岗 = 剩余")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_check(Clock.seconds_until_quiet() == 0.0, "歇岗中 = 0")

	## 7) Intel persists across days.
	Clock.advance()
	_check(session.has_intel(IntelIds.REST_TIME) and session.has_intel(IntelIds.PATROL_ROUTE), "情报跨天保留")

	print("")
	print("=== P2 INTEL SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _point(geo: ZooP0Geometry, reward: StringName) -> ObservePoint:
	for p in geo.observe_points:
		if p.reward == reward:
			return p
	return null


func _stand(actor: AnimalActor, pt: ObservePoint) -> void:
	actor.is_confined = false
	actor.global_position = pt.global_position + Vector3(0.5, 0.05, 0)
	actor.velocity = Vector3.ZERO


func _check_not_in_walls(world: Node3D, geo: ZooP0Geometry) -> void:
	var space := world.get_world_3d().direct_space_state
	var bad := PackedStringArray()
	for p in geo.observe_points:
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.5
		q.shape = s
		q.transform = Transform3D(Basis(), p.global_position + Vector3(0, 0.6, 0))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			bad.append(p.display_name)
	_check(bad.is_empty(), "观察点不嵌墙 %s" % ",".join(bad))


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
