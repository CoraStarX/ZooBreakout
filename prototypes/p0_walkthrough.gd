extends Node
## 人肉跟班：观察巡逻 → Soft 逃出 → 解救 → 攀爬 → Follow → 办公室 → Hard。
## godot --headless --path . res://prototypes/p0_walkthrough.tscn

var _notes: Array[String] = []
var _findings: Array[String] = []
var _ok: Array[String] = []
var _log: PackedStringArray = []
var _world: Node3D
var _party: PartyController
var _staff: StaffActor

var _hot_door_raccoon := Vector3(-2.5, 0.05, -1.2)
var _hot_dig := Vector3(-11.2, 0.05, 1.5)
var _hot_climb := Vector3(-4.5, 0.05, -11.1)
var _hot_monkey := Vector3(3.2, 0.05, -3.0)
var _hot_office := Vector3(-9, 0.05, 8)
var _hot_yard := Vector3(0, 0.05, 2)


func _ready() -> void:
	print("=== Zoo Breakout · 人肉跟班体验 ===")
	Bus.interact_feedback.connect(func(m: String): _log.append(m))
	Game.selected_starter_id = &"raccoon"
	Game.debug_enabled = false
	Clock.auto_advance = true
	Alert.level = 0
	OfficeStorage.take_all()

	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate() as Node3D
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	_staff = _world.call("get_staff") as StaffActor

	await _beat_observe_open()
	await _beat_channel_cancel_repro()
	await _beat_soft_escape()
	await _beat_rescue_companion()
	await _beat_soft_climb_as_monkey()
	await _beat_follow_across_yard()
	await _beat_office_approach()
	await _beat_hard_dig_risk()
	_finish()


func _beat_observe_open() -> void:
	_note("【Beat1】Open 跟班采样职员↔热点最小距离（20s）")
	Clock.set_phase(Clock.Phase.OPEN)
	await get_tree().process_frame
	var mins := {
		"浣熊笼门": 999.0, "挖洞": 999.0, "攀爬": 999.0,
		"猴笼门": 999.0, "办公室": 999.0, "中庭": 999.0,
	}
	var elapsed := 0.0
	while elapsed < 20.0 and Clock.phase == Clock.Phase.OPEN:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var sp := _staff.global_position
		mins["浣熊笼门"] = minf(mins["浣熊笼门"], sp.distance_to(_hot_door_raccoon))
		mins["挖洞"] = minf(mins["挖洞"], sp.distance_to(_hot_dig))
		mins["攀爬"] = minf(mins["攀爬"], sp.distance_to(_hot_climb))
		mins["猴笼门"] = minf(mins["猴笼门"], sp.distance_to(_hot_monkey))
		mins["办公室"] = minf(mins["办公室"], sp.distance_to(_hot_office))
		mins["中庭"] = minf(mins["中庭"], sp.distance_to(_hot_yard))
	_note("职员距热点 min: 笼门%.1f 挖洞%.1f 攀爬%.1f 猴门%.1f 办公%.1f 中庭%.1f"
		% [mins["浣熊笼门"], mins["挖洞"], mins["攀爬"], mins["猴笼门"], mins["办公室"], mins["中庭"]])
	if mins["浣熊笼门"] >= 6.0 and mins["攀爬"] >= 8.0 and mins["挖洞"] >= 8.0:
		_pass("巡逻与出笼/捷径空间余量足够")
	else:
		_find("P1", "[关卡] 巡逻贴近关键点 笼门%.1f 攀爬%.1f 挖洞%.1f"
			% [mins["浣熊笼门"], mins["攀爬"], mins["挖洞"]])
	if mins["猴笼门"] >= 5.0:
		_pass("猴笼门与巡逻间距可读（%.1fm）" % mins["猴笼门"])


## 专项：贴门站桩信道是否被碰撞顶出 use_range（真人会站黄柱旁）
func _beat_channel_cancel_repro() -> void:
	_note("【Beat1.5】贴门站桩 Soft — 复现「离开范围取消」")
	Clock.auto_advance = false
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	var actor := _party.controlled()
	var door: Interactable = _world.call("door_for_animal", actor)
	## 故意贴柱：真人常见站位
	actor.global_position = door.global_position + Vector3(0.15, 0, 0.55)
	actor.velocity = Vector3.ZERO
	_face_toward(actor, door.global_position)
	_log.clear()
	door.try_use(actor)
	await get_tree().create_timer(GameConst.SOFT_INTERACT_SEC + 0.5).timeout
	var cancelled := false
	for m in _log:
		if "取消" in m:
			cancelled = true
	if cancelled and not door._done:
		_find(
			"P0",
			"[交互手感] 贴门/黄柱站桩 Soft 会被顶出 use_range 并取消（真人站位必踩）— 信道中应忽略被墙轻推或放宽/锁位"
		)
	elif door._done:
		_pass("贴门站桩 Soft 可完成（未复现顶出取消）")
	else:
		_find("P1", "[交互] 贴门 Soft 既未完成也无取消日志: %s" % ",".join(_log))
	## 复位门状态以便后续正式路径
	if door._done:
		## 已打开则保持；跟班继续
		pass
	else:
		door._busy = false


func _beat_soft_escape() -> void:
	_note("【Beat2】安全站位 Soft 开本区门（正式路径）")
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	var actor := _party.controlled()
	var door: Interactable = _world.call("door_for_animal", actor)
	if door._done:
		_world.set("exhibit_escaped", true)
		_pass("本区门已在 Beat1.5 打开，阶段继续")
		return
	## 门外开阔点，避免穿模
	await _use_at(actor, door, door.global_position + Vector3(0, 0, 1.1))
	if door._done and _world.get("exhibit_escaped"):
		_pass("Soft 逃出展区 + 阶段目标推进")
		_note("标签可见 / 目标: %s" % _world.call("current_objective"))
	else:
		_find("P0", "[流程] 安全站位仍无法 Soft 开门 log=%s" % ",".join(_log))


func _beat_rescue_companion() -> void:
	_note("【Beat3】Soft 开猴笼解救（无 Debug R）")
	var actor := _party.controlled()
	var monkey_door := _find_interactable("猴笼")
	if monkey_door == null:
		_find("P0", "[流程] 无猴笼门")
		return
	await _use_at(actor, monkey_door, monkey_door.global_position + Vector3(-1.1, 0, 0))
	var d_staff := actor.global_position.distance_to(_staff.global_position)
	_note("解救时距职员 %.1fm" % d_staff)
	if _party.party().size() >= 2:
		_pass("正式路径解救入队")
	else:
		_find("P0", "[流程] 解救失败 party=%d log=%s" % [_party.party().size(), ",".join(_log)])
	if d_staff >= 5.0:
		_pass("解救窗口距职员舒适")
	elif d_staff < 3.5:
		_find("P1", "[关卡] 解救时职员过近 %.1fm" % d_staff)


func _beat_soft_climb_as_monkey() -> void:
	_note("【Beat4】换控猴 → Soft 攀爬捷径")
	if _party.party().size() < 2:
		_find("P0", "[换控] 无队友可换，跳过攀爬")
		return
	_party.switch_next()
	await get_tree().process_frame
	var actor := _party.controlled()
	if actor == null or actor.def.id != &"monkey":
		_find("P0", "[换控] 未切到猴")
		return
	_pass("换控到猴")
	var climb := _find_interactable("攀爬")
	if climb == null:
		_find("P0", "[关卡] 无攀爬点")
		return
	await _use_at(actor, climb, climb.global_position + Vector3(0, 0, 1.1))
	var d := actor.global_position.distance_to(_staff.global_position)
	_note("攀爬点距职员 %.1fm" % d)
	if climb._done and d >= 8.0:
		_pass("攀爬 Soft 完成且远离巡线 — 有动词更稳成立")
	elif climb._done:
		_find("P1", "[关卡] 攀爬可完成但距职员仅 %.1fm" % d)
	else:
		_find("P0", "[交互] 攀爬 Soft 失败 log=%s" % ",".join(_log))


func _beat_follow_across_yard() -> void:
	_note("【Beat5】空地 Follow + 隔墙退出策略")
	if _party.party().size() < 2:
		_find("P1", "[跟随] 无队友，跳过")
		return
	_party.order_all(AnimalActor.FollowMode.FOLLOW)
	var leader := _party.controlled()
	var follower: AnimalActor = null
	for a in _party.party():
		if not a.is_controlled:
			follower = a
	leader.global_position = Vector3(-2, 0.05, 4)
	follower.global_position = Vector3(2, 0.05, 4)
	follower.set_follow_target(leader)
	follower.order_follow()
	await get_tree().create_timer(1.5).timeout
	var d_open := follower.global_position.distance_to(leader.global_position)
	if d_open < 3.5:
		_pass("空地 Follow 跟上（%.1fm）" % d_open)
	else:
		_find("P0", "[跟随AI] 空地掉队 %.1fm" % d_open)
	## L-path around monkey enclosure (avoid office Approach): expect catch-up.
	leader.global_position = Vector3(1.5, 0.05, -3.0)
	follower.global_position = Vector3(7.0, 0.05, 2.0)
	follower.order_follow()
	follower.set_follow_target(leader)
	_log.clear()
	var reached := false
	for _i in 360:
		await get_tree().physics_frame
		if follower.global_position.distance_to(leader.global_position) < 3.5 \
				and follower.follow_mode == AnimalActor.FollowMode.FOLLOW:
			reached = true
			break
	if reached:
		_pass("拐角 Follow 绕到队长旁（%.1fm）" % follower.global_position.distance_to(leader.global_position))
	else:
		_find("P0", "[跟随AI] 拐角掉队 mode=%s dist=%.1f" % [
			follower.follow_mode, follower.global_position.distance_to(leader.global_position)
		])
	follower.order_hold(true)
	leader.global_position = follower.global_position + Vector3(2.0, 0, 0)
	var resumed := false
	for _i in 60:
		await get_tree().physics_frame
		if follower.follow_mode == AnimalActor.FollowMode.FOLLOW:
			resumed = true
			break
	if resumed:
		_pass("卡住待命后走近自动再跟")
	else:
		_find("P0", "[跟随AI] 走近未自动再跟")


func _beat_office_approach() -> void:
	_note("【Beat6】接近办公室危险区")
	var leader := _party.controlled()
	_party.order_all(AnimalActor.FollowMode.FOLLOW)
	leader.global_position = Vector3(-9, 0.05, 4.2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	## 推进入 Approach 盒
	leader.global_position = Vector3(-9, 0.05, 5.8)
	for _i in 8:
		await get_tree().physics_frame
	var floor_ok := _world.find_child("DangerFloor", true, false) != null
	var warn_seen := false
	for c in _world.find_children("*", "Label3D", true, false):
		if c is Label3D and "危险" in (c as Label3D).text:
			warn_seen = true
			break
	var follower_held := false
	for a in _party.party():
		if not a.is_controlled and a.follow_mode == AnimalActor.FollowMode.HOLD:
			follower_held = true
	if floor_ok and warn_seen:
		_pass("危险区地面+标签可读")
	else:
		_find("P1", "[危险区UX] 标识不完整")
	if follower_held:
		_pass("Approach 触发队友入口待命")
	else:
		_find(
			"P1",
			"[危险区UX] 队长进入 Approach 后队友未 Hold — 重叠检测不可靠或需更大 Approach"
		)


func _beat_hard_dig_risk() -> void:
	_note("【Beat7】浣熊硬闯挖洞（职员在 NE）")
	for _i in 3:
		if _party.controlled() and _party.controlled().def.id == &"raccoon":
			break
		_party.switch_next()
		await get_tree().process_frame
	var actor := _party.controlled()
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	_staff.clear_guard()
	_staff.state = StaffActor.State.PATROL
	_staff.global_position = Vector3(7, 0.05, 7)
	var dig := _find_interactable("挖洞")
	if dig == null or dig._done:
		_note("挖洞不可用，跳过")
		return
	_log.clear()
	await _use_at(actor, dig, dig.global_position + Vector3(1.1, 0, 0), true)
	var dist := actor.global_position.distance_to(_staff.global_position)
	_note("硬闯点距职员 %.1fm" % dist)
	var instant := false
	var investigate := false
	for m in _log:
		if "当场" in m:
			instant = true
		if "赶来" in m or "查看" in m:
			investigate = true
	if instant:
		_find("P0", "[平衡] 远端硬闯仍当场抓")
	elif dig._done or investigate:
		_pass("远端硬闯：完成或调查窗（非即抓）")
	else:
		_find("P1", "[平衡] 硬闯结果不明 log=%s" % ",".join(_log))


## 安全站位交互：锁位直到信道结束，避免穿模顶出污染主路径
func _use_at(actor: AnimalActor, area: Interactable, stand: Vector3, hard_wait: bool = false) -> void:
	actor.set_controlled(true)
	actor.global_position = stand
	actor.velocity = Vector3.ZERO
	_face_toward(actor, area.global_position)
	await get_tree().physics_frame
	_log.clear()
	if area.tiers > 1:
		await RouteHelper.finish(get_tree(), area, actor)
		return
	area.try_use(actor)
	var wait := GameConst.HARD_INTERACT_SEC if hard_wait else GameConst.SOFT_INTERACT_SEC
	var t := 0.0
	while t < wait + 0.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		## 锁平面位置，模拟玩家按住方向键贴住交互（不因墙体弹开）
		var p := actor.global_position
		p.x = stand.x
		p.z = stand.z
		actor.global_position = p
		actor.velocity = Vector3.ZERO
		if not area._busy:
			break


func _face_toward(actor: AnimalActor, target: Vector3) -> void:
	var to := target - actor.global_position
	to.y = 0.0
	if to.length() > 0.05:
		actor._facing = to.normalized()


func _find_interactable(substr: String) -> Interactable:
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Interactable and (n as Interactable).display_name.contains(substr):
			return n as Interactable
		for c in n.get_children():
			stack.append(c)
	return null


func _note(msg: String) -> void:
	_notes.append(msg)
	print("NOTE ", msg)


func _pass(msg: String) -> void:
	_ok.append(msg)
	print("PASS ", msg)


func _find(sev: String, msg: String) -> void:
	_findings.append("[%s] %s" % [sev, msg])
	print("FINDING ", sev, ": ", msg)


func _finish() -> void:
	print("")
	print("=== 跟班摘要 OK=%d FINDINGS=%d ===" % [_ok.size(), _findings.size()])
	for f in _findings:
		print(" - ", f)
	print("=== END ===")
	get_tree().quit(0 if _findings.is_empty() else 1)
