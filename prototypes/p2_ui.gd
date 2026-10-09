extends Node
## HUD / 引导提示 / 暂停菜单（无头可验证的部分）。
## godot --headless --path . res://prototypes/p2_ui.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 UI ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: GameHUD = world.get_node_or_null("GameHUD")
	var hints: HintDirector = world.get_node_or_null("Hints")
	var pause: PauseMenu = world.get_node_or_null("PauseMenu")
	var dbg := world.get_node_or_null("DebugHUD") as CanvasLayer
	_check(hud != null and hints != null and pause != null, "HUD / 引导 / 暂停菜单已挂载")
	_check(dbg != null and not dbg.visible, "调试面板默认隐藏（F3 开关）")
	_check(not UserPrefs.enabled(), "无头模式不写用户偏好文件")

	## HUD reflects state.
	await get_tree().create_timer(0.3).timeout
	_check(hud._day_l.text.contains("1") and hud._day_l.text.contains(str(GameConst.DEADLINE_DAY)), "顶栏显示天数 '%s'" % hud._day_l.text)
	_check(hud._obj_l.text != "", "目标栏有内容")
	var me: AnimalActor = world.call("controlled_animal")
	me.inventory.append(KitIds.WOOD)
	me.inventory.append(KitIds.WOOD)
	await get_tree().create_timer(0.3).timeout
	_check((hud._item_rows[KitIds.WOOD]["label"] as Label).text.ends_with("2"), "背包显示木料 ×2")
	Alert.level = 3
	await get_tree().create_timer(0.3).timeout
	var lit := 0
	for pip in hud._alert_pips:
		if pip.color.r > 0.8:
			lit += 1
	_check(lit == 3, "警戒条点亮 3 格")
	var session: RunSession = world.get("session")
	session.set_route_tiers(RunSession.ExitRoute.DIG, 2)
	await get_tree().create_timer(0.3).timeout
	_check(hud._dig_bar.value == 2 and hud._dig_l.text.contains("2/"), "施工进度条 2 档")

	## Message log keeps the latest lines only.
	for i in 5:
		Bus.interact_feedback.emit("消息 %d" % i)
	_check(hud._log.size() == GameHUD.LOG_LINES and hud._log_l.text.contains("消息 4") and not hud._log_l.text.contains("消息 0"), "消息栏只保留最近 %d 条" % GameHUD.LOG_LINES)

	## Hints fire once per id.
	hints.trigger(&"night")
	_check(hud._hint_panel.visible and hud._hint_l.text.contains("夜间"), "夜间提示出现")
	hud.hide_hint()
	hints.trigger(&"night")
	_check(not hud._hint_panel.visible, "同一提示只出现一次")
	hints.enabled = false
	hints.trigger(&"intel")
	_check(not hud._hint_panel.visible, "关闭引导后不再提示")

	## Pause toggles tree pause; blocked once the run is over.
	pause.toggle()
	_check(get_tree().paused and pause._root.visible, "暂停菜单打开并暂停游戏")
	pause.toggle()
	_check(not get_tree().paused and not pause._root.visible, "再次切换恢复")
	_check(InputMap.has_action("pause"), "pause 输入动作存在")

	print("")
	print("=== P2 UI SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
