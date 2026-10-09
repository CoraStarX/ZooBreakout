extends Node
## Run-state hygiene: clock must not tick outside a level; new run = full Open, alert 0, empty office.
## godot --headless --path . res://prototypes/p2_run_reset.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Run Reset ===")
	## 1) No level in tree (title screen): clock frozen.
	Clock.reset_for_new_run()
	var before := Clock.phase_remaining()
	for _i in 30:
		await get_tree().process_frame
	_check(is_equal_approx(Clock.phase_remaining(), before), "Clock 不在标题界面走时 remaining=%.2f" % Clock.phase_remaining())

	## 2) Dirty state from a finished run, then reset.
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	Clock.auto_advance = false
	Alert.level = 3
	OfficeStorage.deposit([&"dig_kit"])
	RunLifecycle.reset()
	_check(Clock.phase == Clock.Phase.OPEN, "新局时段 = Open")
	_check(Clock.auto_advance, "新局 auto_advance 恢复")
	_check(is_equal_approx(Clock.phase_remaining(), GameConst.OPEN_PHASE_SEC), "新局 Open 计时满额")
	_check(Alert.level == 0, "新局警戒归零")
	_check(not OfficeStorage.has_items(), "新局办公室清空")

	## 3) Already-OPEN with elapsed time still resets to full.
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	for _i in 20:
		await get_tree().process_frame
	_check(Clock.phase_remaining() < GameConst.OPEN_PHASE_SEC, "关卡内 Clock 正常走时")
	world.queue_free()
	await get_tree().process_frame
	RunLifecycle.reset()
	_check(is_equal_approx(Clock.phase_remaining(), GameConst.OPEN_PHASE_SEC), "Open→Open 重开计时满额")

	print("")
	print("=== P2 RESET SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
