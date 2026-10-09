extends Node
## Headless P0 playtest: instances zoo as child (keeps autoloads + this runner).
## Run: godot --headless --path . res://prototypes/p0_playtest.tscn

var _findings: Array[String] = []
var _ok: Array[String] = []
var _world: Node3D
var _party: PartyController
var _log: PackedStringArray = []


func _ready() -> void:
	print("=== Zoo Breakout P0 Playtest ===")
	Bus.interact_feedback.connect(func(m: String): _log.append(m))
	Game.selected_starter_id = &"raccoon"
	Clock.auto_advance = false
	Alert.level = 0
	OfficeStorage.take_all()

	var packed: PackedScene = load("res://scenes/world/zoo_p0.tscn")
	if packed == null:
		_find("CRITICAL", "无法 load zoo_p0.tscn")
		_finish(1)
		return
	_world = packed.instantiate() as Node3D
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_party = _world.get("party") as PartyController
	if _party == null:
		_find("CRITICAL", "PartyController 缺失")
		_finish(1)
		return

	await _run_suite()
	_finish(0)


func _run_suite() -> void:
	_check_boot()
	await _check_day_gate()
	await _check_soft_vs_hard()
	await _check_rescue_switch()
	await _check_follow_hold()
	await _check_capture_loop()
	await _check_office_chest()
	await _check_staff_fairness()
	_check_camera_and_ux()
	_check_level_readability()
	_check_timing_pace()


func _check_boot() -> void:
	var controlled := _party.controlled()
	if controlled == null or controlled.def == null:
		_find("P0", "开局无受控动物")
		return
	if controlled.def.id != &"raccoon":
		_find("P0", "开局物种与 selected_starter 不一致: %s" % controlled.def.id)
	else:
		_pass("开局浣熊受控")
	if controlled.global_position.y < -0.5:
		_find("P0", "开局角色掉出地面 y=%.2f" % controlled.global_position.y)
	var cam := _world.get_node_or_null("CameraRig")
	if cam == null:
		_find("P0", "FollowCamera/CameraRig 缺失")
	else:
		_pass("相机 Rig 存在")
	var hud := _world.get_node_or_null("DebugHUD")
	if hud:
		_pass("Debug HUD 挂载")
	else:
		_find("P0", "Debug HUD 未挂到关卡")


func _check_day_gate() -> void:
	Clock.set_phase(Clock.Phase.OPEN)
	await get_tree().process_frame
	var door: Interactable = _world.call("door_for_animal", _party.controlled())
	if door == null:
		_find("P0", "浣熊笼门 Interactable 缺失")
		return
	_log.clear()
	door.try_use(_party.controlled())
	await get_tree().create_timer(0.2).timeout
	var gated := false
	for m in _log:
		if "夜间" in m or "Open" in m or "参观" in m or "越狱" in m:
			gated = true
	await get_tree().create_timer(0.5).timeout
	if door._done:
		_find("P0", "白天仍可完成越狱破障（夜门控失效）")
	elif gated:
		_pass("白天破障被时段门控挡住")
	else:
		_find("P0", "白天破障未完成，但也没有夜门控提示: %s" % ",".join(_log))


func _check_soft_vs_hard() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	await get_tree().process_frame
	var actor := _party.controlled()
	var door: Interactable = _world.call("door_for_animal", actor)
	_log.clear()
	if door._done:
		door.relock()
	actor.global_position = door.global_position + Vector3(0, 0, 0.8)
	door.try_use(actor)
	await get_tree().create_timer(0.7).timeout
	var soft_msg := false
	for m in _log:
		if "稳" in m or "巧手" in m:
			soft_msg = true
	if soft_msg:
		_pass("有巧手时 Soft 反馈可读")
	else:
		_find("P0", "Soft 成功反馈不清晰: %s" % ",".join(_log))

	var dig: Interactable = _find_interactable("挖洞")
	if dig == null:
		_find("P0", "铁丝网挖洞交互点缺失")
		return
	_log.clear()
	if dig._done:
		_find("UX", "挖洞点已 one-shot，无法复测 Hard")
		return
	dig.try_use(actor)
	await get_tree().create_timer(0.25).timeout
	var hard_msg := false
	for m in _log:
		if "硬闯" in m:
			hard_msg = true
	if hard_msg:
		_pass("无挖掘时 Hard 反馈可读")
	else:
		_find("P0", "Hard 路径反馈缺失: %s" % ",".join(_log))
	await get_tree().create_timer(2.0).timeout
	if dig._done:
		_pass("Night-Quiet 下硬闯可完成")
	else:
		_find("P0", "硬闯挖洞在 Quiet 未完成")


func _check_rescue_switch() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	var ok := _party.rescue(&"monkey")
	await get_tree().process_frame
	if not ok and _party.party().size() < 2:
		_find("P0", "解救猴失败")
		return
	if _party.party().size() < 2:
		_find("P0", "解救后队伍人数仍 < 2")
		return
	_pass("解救入队成立")
	_party.switch_next()
	await get_tree().process_frame
	var c := _party.controlled()
	if c == null or c.def.id != &"monkey":
		_find("P0", "Tab 换控未切到猴")
	else:
		_pass("换控到猴")
	_party.switch_next()
	await get_tree().process_frame


func _check_follow_hold() -> void:
	_party.order_all(AnimalActor.FollowMode.HOLD)
	await get_tree().process_frame
	var held := 0
	for a in _party.party():
		if not a.is_controlled and a.follow_mode == AnimalActor.FollowMode.HOLD:
			held += 1
	if held >= 1:
		_pass("Hold 待命生效")
	else:
		_find("P0", "Hold 未改变队友状态")
	_party.order_all(AnimalActor.FollowMode.FOLLOW)
	await get_tree().process_frame
	var leader := _party.controlled()
	var follower: AnimalActor = null
	for a in _party.party():
		if not a.is_controlled:
			follower = a
	if follower and leader:
		# Open space follow test (no walls between)
		leader.global_position = Vector3(0, 0.05, 8)
		follower.global_position = Vector3(6, 0.05, 8)
		await get_tree().create_timer(1.4).timeout
		var d := follower.global_position.distance_to(leader.global_position)
		if d < 3.5:
			_pass("空地 Follow 会追近（距离 %.1f）" % d)
		else:
			_find("P0", "空地 Follow 仍远 %.1f" % d)
		# Wall-blocked follow: put wall between
		leader.global_position = Vector3(-5, 0.05, -6)
		follower.global_position = Vector3(6, 0.05, -3)
		follower.order_follow()
		follower.set_follow_target(leader)
		await get_tree().create_timer(2.0).timeout
		var d2 := follower.global_position.distance_to(leader.global_position)
		if d2 > 4.0:
			_find("P0", "Follow 无寻路，隔墙直线追会被卡住（距离 %.1f）——双动物核心循环会因此挫败" % d2)
		else:
			_pass("隔墙 Follow  somehow 到了（%.1f）" % d2)


func _check_capture_loop() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	Alert.level = 0
	var actor := _party.controlled()
	if actor.inventory.is_empty():
		actor.inventory.append(&"dig_kit")
	CaptureFlow.apply_capture(actor)
	await get_tree().process_frame
	if not actor.is_confined:
		_find("P0", "抓捕后未关禁闭")
	else:
		_pass("抓捕 → 禁闭")
	if Alert.level < 1:
		_find("P0", "抓捕未升警戒")
	else:
		_pass("抓捕升警戒")
	if OfficeStorage.has_items():
		_pass("抄包装进办公室")
	else:
		_find("P0", "抄包未进办公室储物")
	var door: Interactable = _world.call("door_for_animal", actor)
	if door and door.reinforced:
		_pass("笼门已加固")
	else:
		_find("P0", "抓捕后笼门未加固")
	CaptureFlow.release(actor)
	await get_tree().process_frame
	if actor.is_confined:
		_find("P0", "释放后仍在禁闭")
	else:
		_pass("释放解除禁闭")


func _check_office_chest() -> void:
	if not OfficeStorage.has_items():
		OfficeStorage.deposit([&"dig_kit"])
	var chest := _find_chest()
	if chest == null:
		_find("P0", "办公室金柜缺失")
		return
	var actor := _party.controlled()
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	# Switch to raccoon for dex soft steal if needed
	for i in _party.party().size():
		if _party.controlled().def.id == &"raccoon":
			break
		_party.switch_next()
		await get_tree().process_frame
	actor = _party.controlled()
	actor.set_confined(false)
	actor.global_position = chest.global_position + Vector3(0.5, 0, 0.5)
	var before := actor.inventory.size()
	chest.try_use(actor)
	await get_tree().create_timer(0.9).timeout
	if actor.inventory.size() > before or not OfficeStorage.has_items():
		_pass("办公室夺回可用")
	else:
		_find("P0", "办公室夺回未成功")
	if _party.party().size() >= 2:
		_party.order_all(AnimalActor.FollowMode.FOLLOW)
		var follower: AnimalActor = null
		for a in _party.party():
			if not a.is_controlled:
				follower = a
		_party.on_danger_entered(follower)
		_party.on_danger_entered(actor)
		await get_tree().process_frame
		if follower and follower.follow_mode == AnimalActor.FollowMode.HOLD:
			_pass("危险区自动待命")
		else:
			_find("P0", "危险区自动待命未触发")


func _check_staff_fairness() -> void:
	var staff: StaffActor = _world.call("get_staff")
	if staff == null:
		_find("P0", "职员缺失")
		return
	Clock.set_phase(Clock.Phase.OPEN)
	staff.clear_guard()
	staff.state = StaffActor.State.PATROL
	var actor := _party.controlled()
	staff.global_position = Vector3(1, 0.05, 0)
	staff._facing = Vector3(0, 0, 1)
	actor.velocity = Vector3.ZERO
	actor.global_position = staff.global_position + Vector3(1.5, 0, 0)
	await get_tree().process_frame
	var spotted: AnimalActor = staff._scan_animals()
	if spotted == actor:
		_find(
			"P0",
			"职员近距听力把站着不动的受控角色也当发现目标（hear_walk + is_controlled）——站着也会被追，观感极不公平"
		)
	else:
		_pass("近距听力未误伤静止受控者")
	_find("UX", "职员视野可视化是长方体，与真实 55° 锥角不符，易误导走位")


func _check_camera_and_ux() -> void:
	_find(
		"P0",
		"移动按世界坐标 WASD，相机 yaw=45°：按 W 不是朝屏幕上方，斜俯视方向感很容易拧"
	)
	_find(
		"P0",
		"交互物只有黄柱，无世界空间名称/图标；场景本身读不出笼门锁/挖洞/攀爬差异"
	)
	_find(
		"P0",
		"没有明确目标与胜利条件；「这局要干什么」只靠 Debug HUD 一行字"
	)
	_find(
		"UX",
		"破障 await 期间角色仍可自由移动；离开交互点后动作仍完成——缺进度条/取消条件"
	)
	_find(
		"设计",
		"R 一键解救跳过开门入队，验证「解救即成长」时会污染试玩结论"
	)


func _check_level_readability() -> void:
	_find(
		"关卡",
		"出笼即进入职员巡逻环，新手第一眼高概率撞巡线"
	)
	_find(
		"关卡",
		"攀爬/挖洞捷径与巡逻带高度重叠，「有动词更稳」的空间优势不够明显"
	)
	_find(
		"UX",
		"办公室=危险区+金柜同位，无危险区地面标识；Follow 队友会一起冲入再被 auto-hold"
	)


func _check_timing_pace() -> void:
	var open_s := GameConst.OPEN_PHASE_SEC
	var close_s := GameConst.CLOSE_PHASE_SEC
	var patrol_s := GameConst.NIGHT_PATROL_BASE_SEC
	var quiet_s := GameConst.NIGHT_QUIET_SEC
	var cycle := open_s + close_s + patrol_s + quiet_s
	if open_s < 30.0:
		_find(
			"节奏",
			"Open 仅 %.0fs，来不及观察巡逻/摸清布局；「白天观察」支柱落空" % open_s
		)
	if cycle < 90.0:
		_find(
			"节奏",
			"完整昼夜约 %.0fs，越狱窗（巡+静=%.0fs）偏短，计划感被赶进度感取代" % [cycle, patrol_s + quiet_s]
		)
	_find(
		"平衡",
		"硬闯 1.6s + 听力半径内即抓；P0 地图职员几乎总在半径内 → 「无动词可硬闯」实战接近不可行"
	)


func _find_interactable(name_substr: String) -> Interactable:
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Interactable:
			var area := n as Interactable
			if area.display_name.contains(name_substr):
				return area
		for c in n.get_children():
			stack.append(c)
	return null


func _find_chest() -> OfficeChest:
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is OfficeChest:
			return n as OfficeChest
		for c in n.get_children():
			stack.append(c)
	return null


func _find(sev: String, msg: String) -> void:
	_findings.append("[%s] %s" % [sev, msg])
	print("FINDING ", sev, ": ", msg)


func _pass(msg: String) -> void:
	_ok.append(msg)
	print("OK: ", msg)


func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for c in node.get_children():
		_walk(c, fn)


func _finish(code: int) -> void:
	print("")
	print("=== SUMMARY ===")
	print("OK count: ", _ok.size())
	print("Findings: ", _findings.size())
	for f in _findings:
		print(" - ", f)
	print("=== END ===")
	get_tree().quit(code)
