extends Node
## 潜行偷取：职员工具车（金属）+ 巡逻点停步。
## godot --headless --path . res://prototypes/p2_cart.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Cart ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var geo: ZooP0Geometry = world.get_node("Geometry")
	var staff: StaffActor = world.call("get_staff")
	var cart := geo.staff_cart
	var actor: AnimalActor = world.get("party").controlled()
	actor.inventory.clear()
	_check(cart != null and cart.staff == staff, "工具车跟随职员")

	## 加權點網巡邏。
	_check(staff.patrol_network != null and staff.patrol_network.points.size() >= 8, "巡逻点网已注入")
	_check(staff._use_network, "职员使用点网巡逻")

	## Dwell + 慢速掃視。
	staff.global_position = staff.waypoints[1] + Vector3(0.1, 0, 0)
	staff._motor.set_target(staff.waypoints[1])
	Clock.set_phase(Clock.Phase.OPEN)
	for _i in 8:
		await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout
	## 若尚未停步，強制進入停步以測掃視。
	if staff._dwell_left <= 0.0:
		staff._arrive_network_point()
	var still := staff.velocity.length() < 0.05
	_check(still and staff._dwell_left > 0.0, "到达巡逻点后停步 (%.1fs)" % staff._dwell_left)
	staff._dwell_left = maxf(staff._dwell_left, 3.0)
	staff._dwell_face0 = Vector3(0, 0, 1)
	staff._facing = Vector3(0, 0, 1)
	staff._reset_look_around()
	await get_tree().create_timer(staff.look_center_hold_sec + 1.2).timeout
	_check(
		absf(staff._look_yaw) > deg_to_rad(25.0) and staff._dwell_left > 0.0,
		"停步慢速扫视偏转（yaw=%.0f°）" % rad_to_deg(staff._look_yaw)
	)

	## 預約 API（單人流程）。
	var pid: StringName = staff.patrol_network.points[2].id
	staff.patrol_network.release(staff._patrol_point_id, staff.get_instance_id())
	_check(staff.patrol_network.reserve(pid, staff.get_instance_id()), "职员可预约巡逻点")
	_check(not staff.patrol_network.reserve(pid, 999001), "他人不可抢预约")
	staff.patrol_network.release(pid, staff.get_instance_id())

	## Cart sits behind the staff.
	staff.set_physics_process(false)
	staff._facing = Vector3(0, 0, 1)
	staff._look_yaw = 0.0
	staff.global_position = Vector3(3.0, 0.05, 7.0)
	for _i in 40:
		await get_tree().physics_frame
	var behind := cart.global_position.z < staff.global_position.z - 1.0
	_check(behind, "车在职员身后 %.1fm" % staff.global_position.distance_to(cart.global_position))

	## Interrupted: staff turns on you.
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	await get_tree().create_timer(0.4).timeout
	staff.state = StaffActor.State.CHASE
	await get_tree().create_timer(0.3).timeout
	_check(cart.loot_left == 1 and actor.item_count(KitIds.METAL) == 0, "职员察觉 → 偷取失败不得手")
	staff.state = StaffActor.State.PATROL

	## Interrupted: wandering off.
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	await get_tree().create_timer(0.3).timeout
	actor.global_position += Vector3(0, 0, -5)
	await get_tree().create_timer(0.3).timeout
	_check(cart.loot_left == 1 and not cart._busy, "离开范围偷取中断")

	## Night: cart packed away.
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	for _i in 3:
		await get_tree().physics_frame
	_check(not cart.visible, "夜里车收走")
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	await get_tree().process_frame
	_check(cart.loot_left == 1 and actor.item_count(KitIds.METAL) == 0, "夜里不能偷")

	Clock.set_phase(Clock.Phase.OPEN)
	for _i in 3:
		await get_tree().physics_frame
	## Steal from behind.
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	await get_tree().create_timer(GameConst.STEAL_SEC + 0.6).timeout
	_check(actor.item_count(KitIds.METAL) == 1 and cart.loot_left == 0, "从背后偷到金属 ×1")
	cart.try_use(actor)
	await get_tree().process_frame
	_check(actor.item_count(KitIds.METAL) == 1, "偷空后不能再偷")

	## Once per run: dawn does not restock.
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(cart.loot_left == 0 and GameConst.CART_LOOT_PER_RUN == 1, "工具车整局 1 件，天亮不补货")

	print("")
	print("=== P2 CART SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
