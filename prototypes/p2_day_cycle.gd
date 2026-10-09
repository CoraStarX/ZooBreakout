extends Node
## 昼夜循环 M2：天数、跨天进度保留、安分降警戒、期限失败。
## godot --headless --path . res://prototypes/p2_day_cycle.tscn

var _pass_n := 0
var _fail_n := 0
var _summaries: Array = []


func _ready() -> void:
	print("=== P2 Day Cycle ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	Bus.day_summary.connect(func(d: int, l: PackedStringArray) -> void: _summaries.append([d, l]))
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var session: RunSession = world.get("session")

	_check(Clock.day == 1, "开局第 1 天")
	_check(is_equal_approx(Clock.phase_remaining(), GameConst.OPEN_PHASE_SEC), "Open 时长 = %.0fs" % GameConst.OPEN_PHASE_SEC)

	## Day 1: quiet (no capture) with alert 2 + some breach → dawn cools alert, keeps breach.
	Alert.level = 2
	session.add_breach(0.4)
	_run_night_to_dawn()
	_check(Clock.day == 2 and Clock.phase == Clock.Phase.OPEN, "跑完一夜进入第 2 天 Open")
	_check(is_equal_approx(session.breach, 0.4), "Breach 跨天保留 %.2f" % session.breach)
	_check(Alert.level == 1, "安分一天警戒 2→1（实际 %d）" % Alert.level)
	_check(_summaries.size() == 1 and _summaries[0][0] == 1, "发出第 1 天结算")

	## Day 2: captured → no cooldown.
	var actor: AnimalActor = world.get("party").controlled()
	CaptureFlow.apply_capture(actor)
	var alert_after_capture := Alert.level
	_run_night_to_dawn()
	_check(Clock.day == 3, "进入第 3 天")
	_check(Alert.level == alert_after_capture, "被抓当天警戒不冷却（%d）" % Alert.level)
	_check(not session.is_finished(), "第 3 天仍在进行")

	## Deadline: finishing the last day without escaping loses.
	Clock.day = GameConst.DEADLINE_DAY
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(session.outcome == RunSession.Outcome.LOST, "期限日结束未出园 → LOST")
	_check(session.outcome_reason.contains("封园检修"), "失败原因含封园检修")

	## New run resets day.
	RunLifecycle.reset()
	_check(Clock.day == 1, "新局天数回到 1")

	print("")
	print("=== P2 DAY SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _run_night_to_dawn() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
