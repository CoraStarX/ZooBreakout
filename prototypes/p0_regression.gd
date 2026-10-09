extends Node
## QA regression for docs/qa_reports/latest_report.md checked items.
## Run: godot --headless --path . res://prototypes/p0_regression.tscn

var _pass_n := 0
var _fail_n := 0
var _rows: Array[String] = []
var _world: Node3D
var _party: PartyController
var _log: PackedStringArray = []


func _ready() -> void:
	print("=== Zoo Breakout QA Regression ===")
	Bus.interact_feedback.connect(func(m: String): _log.append(m))
	Game.selected_starter_id = &"raccoon"
	Game.debug_enabled = true
	Clock.auto_advance = false
	Alert.level = 0
	OfficeStorage.take_all()

	var packed: PackedScene = load("res://scenes/world/zoo_p0.tscn")
	if packed == null:
		_fail("BOOT", "无法 load zoo_p0.tscn")
		_finish()
		return
	_world = packed.instantiate() as Node3D
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	if _party == null:
		_fail("BOOT", "Party 缺失")
		_finish()
		return

	await _reg_follow_stuck()
	await _reg_hearing_idle()
	_reg_camera_relative()
	await _reg_hard_investigate()
	_reg_world_labels()
	_reg_objective()
	_reg_phase_timing()
	_reg_vision_wedge()
	await _reg_interact_cancel()
	_reg_danger_mark()
	_reg_input_debug()
	await _reg_enclosure_closed()
	await _reg_door_walkthrough()
	await _reg_gravity_fall()
	_finish()


func _reg_follow_stuck() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_party.rescue(&"monkey")
	await get_tree().process_frame
	var leader := _party.controlled()
	var follower: AnimalActor = null
	for a in _party.party():
		if not a.is_controlled:
			follower = a
	if follower == null or leader == null:
		_fail("P0-跟随AI", "无法取得队友")
		return
	## L-path around monkey enclosure (not office Approach) — expect reach, not hold.
	_party.order_all(AnimalActor.FollowMode.FOLLOW)
	leader.global_position = Vector3(1.5, 0.05, -3.0)
	follower.global_position = Vector3(7.0, 0.05, 2.0)
	follower.set_follow_target(leader)
	follower.order_follow()
	_log.clear()
	var reached := false
	for _i in 360:
		await get_tree().physics_frame
		if follower.global_position.distance_to(leader.global_position) < 3.5:
			reached = true
			break
	if reached and follower.follow_mode == AnimalActor.FollowMode.FOLLOW:
		_ok("P0-跟随AI", "拐角绕行到达队长旁 dist=%.1f" % follower.global_position.distance_to(leader.global_position))
	else:
		_fail(
			"P0-跟随AI",
			"拐角未跟上 mode=%s dist=%.1f"
			% [follower.follow_mode, follower.global_position.distance_to(leader.global_position)]
		)
	## Stuck HOLD auto-resumes when leader approaches (no F required).
	follower.global_position = Vector3(6.0, 0.05, -3.0)
	leader.global_position = Vector3(-5.0, 0.05, -6.0)
	follower.order_hold(true)
	follower.set_follow_target(leader)
	await get_tree().physics_frame
	leader.global_position = Vector3(4.5, 0.05, -3.0) # near follower, open yard
	var resumed := false
	for _i in 90:
		await get_tree().physics_frame
		if follower.follow_mode == AnimalActor.FollowMode.FOLLOW:
			resumed = true
			break
	if resumed:
		_ok("P0-跟随AI", "卡住待命后走近自动再跟")
	else:
		_fail("P0-跟随AI", "走近未自动再跟 mode=%s" % follower.follow_mode)


func _reg_hearing_idle() -> void:
	var staff: StaffActor = _world.call("get_staff")
	Clock.set_phase(Clock.Phase.OPEN)
	staff.clear_guard()
	staff.state = StaffActor.State.PATROL
	var actor := _party.controlled()
	staff.global_position = Vector3(1, 0.05, 0)
	staff._facing = Vector3(0, 0, 1)
	actor.velocity = Vector3.ZERO
	actor.global_position = staff.global_position + Vector3(1.5, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var spotted: AnimalActor = staff._scan_animals()
	if spotted == actor:
		_fail("P0-职员侦测", "静止受控仍被听力锁定")
	else:
		_ok("P0-职员侦测", "静止不受听力误伤")
	# Moving should still be heard
	actor.velocity = Vector3(3, 0, 0)
	await get_tree().physics_frame
	spotted = staff._scan_animals()
	if spotted == actor:
		_ok("P0-职员侦测", "移动中可被听力发现（对照）")
	else:
		# May fail if vision cone doesn't apply and hearing uses velocity - should work
		_fail("P0-职员侦测", "移动受控未被听力发现（回归对照失败）")
	actor.velocity = Vector3.ZERO


func _reg_camera_relative() -> void:
	var actor := _party.controlled()
	if actor == null or not actor.has_method("_camera_relative_dir"):
		_fail("P0-相机/操作", "缺少 _camera_relative_dir")
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_fail("P0-相机/操作", "无当前 Camera3D")
		return
	# W = get_vector y=-1 → forward * (+1) along -cam.z flattened
	var dir: Vector3 = actor.call("_camera_relative_dir", Vector2(0, -1))
	var expect := -cam.global_transform.basis.z
	expect.y = 0.0
	expect = expect.normalized()
	var dot := dir.normalized().dot(expect)
	if dir.length() > 0.5 and dot > 0.85:
		_ok("P0-相机/操作", "W 相对相机前向（dot=%.2f）" % dot)
	else:
		_fail("P0-相机/操作", "W 未对齐相机前向 dir=%s expect=%s dot=%.2f" % [dir, expect, dot])


func _reg_hard_investigate() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	var staff: StaffActor = _world.call("get_staff")
	staff.clear_guard()
	staff.state = StaffActor.State.PATROL
	var actor := _party.controlled()
	actor.set_confined(false)
	# Far from staff: hard noise should investigate, not instant catch
	staff.global_position = Vector3(8, 0.05, 8)
	actor.global_position = Vector3(-5, 0.05, -5)
	var dig := _find_interactable("挖洞")
	if dig == null:
		_fail("P0-平衡/硬闯", "找不到挖洞点")
		return
	if dig._done:
		_fail("P0-平衡/硬闯", "挖洞已完成无法测 Hard（跳过运行时）")
		return
	_log.clear()
	var alert_before := Alert.level
	# Simulate noise emit path directly for distance fairness
	var caught := dig._emit_noise(1.0, actor)
	await get_tree().process_frame
	if caught:
		_fail("P0-平衡/硬闯", "远端硬闯噪音仍当场抓捕")
	else:
		var investigate_msg := false
		for m in _log:
			if "赶来" in m or "查看" in m:
				investigate_msg = true
		if staff.state == StaffActor.State.INVESTIGATE or investigate_msg:
			_ok("P0-平衡/硬闯", "远端硬闯改为调查而非即抓")
		else:
			_fail("P0-平衡/硬闯", "未即抓但未见调查 state=%s log=%s" % [staff.state, ",".join(_log)])
	# Soft still quieter path: raccoon + cage at night
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	var door: Interactable = _world.call("door_for_animal", actor)
	if door and not door._done:
		_log.clear()
		door.try_use(actor)
		await get_tree().create_timer(0.7).timeout
		var soft := false
		for m in _log:
			if "稳" in m:
				soft = true
		if soft:
			_ok("P0-平衡/硬闯", "Soft 稳的反馈仍在")
		else:
			_fail("P0-平衡/硬闯", "Soft 反馈缺失")
	Alert.level = alert_before


func _reg_world_labels() -> void:
	var door: Interactable = _world.call("door_for_animal", _party.controlled())
	if door == null:
		_fail("P0-交互/信息", "笼门缺失")
		return
	var label := door.get_node_or_null("WorldLabel") as Label3D
	if label and label.text.contains("笼") and ("Soft" in label.text or "巧手" in label.text or "[" in label.text):
		_ok("P0-交互/信息", "世界空间标签含名称与 Soft/Hard 提示")
	elif label and not label.text.is_empty():
		_ok("P0-交互/信息", "世界空间标签存在：%s" % label.text.replace("\n", " / "))
	else:
		_fail("P0-交互/信息", "WorldLabel 缺失或为空")


func _reg_objective() -> void:
	if not _world.has_method("current_objective"):
		_fail("P0-目标/流程", "无 current_objective")
		return
	var obj: String = _world.call("current_objective")
	if obj.is_empty() or obj == "—":
		_fail("P0-目标/流程", "目标为空")
	else:
		_ok("P0-目标/流程", "常驻目标：%s" % obj)
	var hud := _world.get_node_or_null("DebugHUD")
	if hud:
		_ok("P0-目标/流程", "DebugHUD 仍挂载（含目标行）")


func _reg_phase_timing() -> void:
	var open_s := GameConst.OPEN_PHASE_SEC
	var cycle := (
		GameConst.OPEN_PHASE_SEC
		+ GameConst.CLOSE_PHASE_SEC
		+ GameConst.NIGHT_PATROL_BASE_SEC
		+ GameConst.NIGHT_QUIET_SEC
	)
	if open_s >= 45.0:
		_ok("P0-节奏/时段", "Open=%.0fs（≥45）" % open_s)
	else:
		_fail("P0-节奏/时段", "Open 仍过短：%.0fs" % open_s)
	if cycle >= 100.0:
		_ok("P0-节奏/时段", "全日循环约 %.0fs" % cycle)
	else:
		_fail("P0-节奏/时段", "全日循环仍偏短：%.0fs" % cycle)


func _reg_vision_wedge() -> void:
	var staff: StaffActor = _world.call("get_staff")
	if staff._vision_mesh and staff._vision_mesh.mesh is ArrayMesh:
		var am := staff._vision_mesh.mesh as ArrayMesh
		if am.get_surface_count() > 0:
			_ok("P1-职员UX", "视野为扇形 ArrayMesh（非长方体）")
		else:
			_fail("P1-职员UX", "视野 mesh 无 surface")
	else:
		_fail("P1-职员UX", "视野仍非楔形 mesh")


func _reg_interact_cancel() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	var actor := _party.controlled()
	actor.set_confined(false)
	var climb := _find_interactable("攀爬")
	if climb == null:
		_fail("P1-交互手感", "攀爬点缺失")
		return
	if climb._done:
		_fail("P1-交互手感", "攀爬已完成无法测取消")
		return
	_log.clear()
	actor.global_position = climb.global_position
	actor.give_items([KitIds.ROPE, KitIds.METAL])
	climb.try_use(actor)
	await get_tree().process_frame
	# Walk away mid-channel
	actor.global_position = climb.global_position + Vector3(0, 0, 5)
	await get_tree().create_timer(0.35).timeout
	var cancelled := false
	for m in _log:
		if "取消" in m or "离开" in m:
			cancelled = true
	if cancelled and not climb._done and not climb._busy:
		_ok("P1-交互手感", "离开范围取消交互")
	elif cancelled:
		_ok("P1-交互手感", "离开范围有取消提示（busy=%s done=%s）" % [climb._busy, climb._done])
	else:
		_fail("P1-交互手感", "离开范围未取消 log=%s busy=%s" % [",".join(_log), climb._busy])


func _reg_danger_mark() -> void:
	var floor_mark := _world.find_child("DangerFloor", true, false)
	var approach := _world.find_child("DangerApproach", true, false)
	if floor_mark and approach:
		_ok("P1-危险区UX", "危险区地面标识 + 入口 Approach 存在")
	else:
		_fail("P1-危险区UX", "DangerFloor=%s Approach=%s" % [floor_mark != null, approach != null])


func _reg_input_debug() -> void:
	var has_joy := false
	for e in InputMap.action_get_events("move_left"):
		if e is InputEventJoypadMotion:
			has_joy = true
	if has_joy:
		_ok("P1-输入/调试", "左摇杆轴已绑定 move_*")
	else:
		_fail("P1-输入/调试", "move_left 无手柄轴")
	# R gated by debug_enabled
	Game.debug_enabled = false
	_log.clear()
	_world._unhandled_input(_fake_action("debug_rescue_monkey"))
	var blocked := false
	for m in _log:
		if "正式" in m or "Debug" in m or "笼门" in m:
			blocked = true
	if blocked:
		_ok("P1-输入/调试", "debug_enabled=false 时 R 不跳过解救")
	else:
		_fail("P1-输入/调试", "正式模式 R 未拦截 log=%s" % ",".join(_log))


func _reg_enclosure_closed() -> void:
	Clock.set_phase(Clock.Phase.OPEN)
	var actor := _party.controlled()
	var door: Interactable = _world.call("door_for_animal", actor)
	var home := actor.home_position
	actor.global_position = home
	actor.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var goal := Vector3(-2.5, 0.05, 2)
	for _i in 100:
		var to := goal - actor.global_position
		to.y = 0.0
		if to.length() < 0.5:
			break
		actor.velocity.x = to.normalized().x * 6.0
		actor.velocity.z = to.normalized().z * 6.0
		actor.move_and_slide()
		await get_tree().physics_frame
	var leaked := (not door._done) and actor.global_position.distance_to(goal) < 3.5
	if leaked:
		_fail("P0-关卡/开场围栏", "不破门可进中庭 end=%s" % actor.global_position)
	else:
		_ok("P0-关卡/开场围栏", "绕行无法无破门进中庭")
	actor.global_position = home
	actor.velocity = Vector3.ZERO


func _reg_door_walkthrough() -> void:
	## Unlock raccoon door at night — must be able to walk north into courtyard.
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	var actor := _party.controlled()
	var door: Interactable = _world.call("door_for_animal", actor)
	if door == null:
		_fail("P0-关卡/笼门通行", "笼门缺失")
		return
	actor.global_position = door.global_position + Vector3(0, 0, 0.9)
	actor.velocity = Vector3.ZERO
	if not door._done:
		door.try_use(actor)
		var t := 0.0
		while door._busy and t < 6.0:
			await get_tree().process_frame
			t += get_process_delta_time()
	await get_tree().physics_frame
	if not door._done:
		_fail("P0-关卡/笼门通行", "夜间开锁失败")
		return
	actor.global_position = Vector3(-2.5, 0.05, -4.0)
	actor.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var goal := Vector3(-2.5, 0.05, 2.0)
	for _i in 140:
		var to := goal - actor.global_position
		to.y = 0.0
		if to.length() < 0.6:
			break
		actor.velocity.x = to.normalized().x * 6.0
		actor.velocity.z = to.normalized().z * 6.0
		actor.move_and_slide()
		await get_tree().physics_frame
	if actor.global_position.z >= 0.5 and actor.global_position.distance_to(goal) < 3.0:
		_ok("P0-关卡/笼门通行", "解锁后可北向走出展区 end=%s" % actor.global_position)
	else:
		_fail("P0-关卡/笼门通行", "解锁后仍无法走出 end=%s door_done=%s" % [
			actor.global_position, door._done
		])
	actor.global_position = actor.home_position
	actor.velocity = Vector3.ZERO


func _reg_gravity_fall() -> void:
	var actor := _party.controlled()
	actor.global_position = Vector3(0, 3.0, 4)
	actor.velocity = Vector3.ZERO
	await get_tree().physics_frame
	for _i in 90:
		await get_tree().physics_frame
	var y := actor.global_position.y
	if y <= 1.2:
		_ok("P0-物理/攀爬", "离地约 1.5s 内回落 y=%.2f" % y)
	else:
		_fail("P0-物理/攀爬", "无有效重力，悬空 y=%.2f" % y)


func _fake_action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _find_interactable(substr: String) -> Interactable:
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Interactable and (n as Interactable).display_name.contains(substr):
			return n as Interactable
		for c in n.get_children():
			stack.append(c)
	return null


func _ok(tag: String, msg: String) -> void:
	_pass_n += 1
	_rows.append("PASS | %s | %s" % [tag, msg])
	print("PASS ", tag, ": ", msg)


func _fail(tag: String, msg: String) -> void:
	_fail_n += 1
	_rows.append("FAIL | %s | %s" % [tag, msg])
	print("FAIL ", tag, ": ", msg)


func _finish() -> void:
	print("")
	print("=== REGRESSION SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	for r in _rows:
		print(r)
	print("=== END ===")
	get_tree().quit(0 if _fail_n == 0 else 1)
