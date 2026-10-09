extends Node
## 被抓新规则：短押 + 笼内搜集 + 笼门加固 + 同伴营救 + 抓捕原因。
## godot --headless --path . res://prototypes/p2_capture.tscn

var _pass_n := 0
var _fail_n := 0
var _log: Array[String] = []


func _ready() -> void:
	print("=== P2 Capture ===")
	Bus.interact_feedback.connect(func(m: String) -> void: _log.append(m))
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var party: PartyController = world.get("party")
	var geo: ZooP0Geometry = world.get_node("Geometry")
	var starter := party.controlled()
	var door: Interactable = world.call("door_for_animal", starter)
	party.rescue(&"monkey")
	var monkey: AnimalActor = null
	for a in party.party():
		if a != starter:
			monkey = a

	## --- Capture: items confiscated, detained, door reinforced, reason shown ---
	starter.give_items([KitIds.WOOD, KitIds.METAL])
	var alert0 := Alert.level
	CaptureFlow.apply_capture(starter, "被视线发现")
	_check(starter.is_confined, "被抓后短押")
	_check(starter.material_count() == 0 and OfficeStorage.items.size() == 2, "物品被没收进办公室")
	_check(Alert.level == alert0 + 1, "警戒 +1")
	_check(door.reinforced, "笼门加固")
	_check(is_equal_approx(CaptureFlow.detention_left(starter), GameConst.DETENTION_SEC), "短押 %.0fs" % GameConst.DETENTION_SEC)
	_check(_log.any(func(m: String) -> bool: return m.contains("被视线发现")), "提示含抓捕原因")

	## --- Gathering while detained (in-cage point) ---
	var cage_point: GatherPoint = null
	for g in geo.gather_points:
		if g.required == CapabilityIds.Id.DEXTERITY and g.yield_rich == 2:
			cage_point = g
	starter.global_position = cage_point.global_position + Vector3(0.6, 0.05, 0)
	cage_point.try_use(starter)
	var t := 0.0
	while cage_point._busy and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(starter.item_count(KitIds.WOOD) == 2, "短押期间笼内可搜集原料（饲料柜木料×2）")

	## --- Timer release ---
	var t_before := CaptureFlow.detention_left(starter)
	await get_tree().create_timer(0.5).timeout
	_check(CaptureFlow.detention_left(starter) < t_before, "短押倒计时在走")
	CaptureFlow._detained[starter] = 0.05
	await get_tree().create_timer(0.3).timeout
	_check(not starter.is_confined, "时间到自动释放")
	_check(door.reinforced, "释放后笼门仍加固（到天亮）")

	## --- Reinforced door: costs a part; without parts takes double time ---
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	starter.global_position = door.global_position + Vector3(0, 0, -0.9)
	starter.inventory.clear()
	starter.give_items([KitIds.METAL])
	var t0 := Time.get_ticks_msec()
	door.try_use(starter)
	await _idle(door)
	_check(door._done, "加固门有原料可开")
	_check(starter.material_count() == 0, "开加固门额外消耗 1 原料")
	door.relock()
	door.reinforce()
	starter.inventory.clear()
	starter.global_position = door.global_position + Vector3(0, 0, -0.9)
	t0 = Time.get_ticks_msec()
	door.try_use(starter)
	await _idle(door)
	var slow_ms := Time.get_ticks_msec() - t0
	_check(door._done and slow_ms >= int(door.soft_seconds * GameConst.REINFORCE_TIME_MULT * 1000.0 * 0.8),
		"无原料耗时翻倍 %dms" % slow_ms)

	## --- Dawn clears reinforcement ---
	door.relock()
	door.reinforce()
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(not door.reinforced, "天亮后加固解除")

	## --- Teammate rescue before timer ends ---
	starter.is_controlled = false
	CaptureFlow.apply_capture(starter, "测试")
	var left := CaptureFlow.detention_left(starter)
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	## Guard stands at the door on purpose (rescuing under its nose = instant catch). Lure it away for the test.
	var staff: StaffActor = world.call("get_staff")
	staff.clear_guard()
	staff.global_position = Vector3(10, 0.05, 10)
	monkey.order_hold()
	monkey.global_position = door.global_position + Vector3(0, 0, -0.9)
	monkey._hold_position = monkey.global_position
	monkey.inventory.clear()
	door.try_use(monkey)
	await _idle(door)
	_check(not starter.is_confined and left > 5.0, "同伴撬门提前营救（剩余 %.1fs 时）" % left)
	_check(CaptureFlow.detention_left(starter) == 0.0, "营救后无短押计时")

	print("")
	print("=== P2 CAPTURE SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _idle(it: Interactable) -> void:
	await get_tree().process_frame
	var t := 0.0
	while it._busy and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
