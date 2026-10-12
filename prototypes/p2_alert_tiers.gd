extends Node
## 刀 3：Alert 2–5 后果、头上三阶图示、Alert 4 预警、Alert 5 中止原因、噪音不升 Alert。
## 正式开局、无临时能力；原料只来自真实搜集点。Alert 档位直接设定（升档来源已由痕迹/被抓测试覆盖）。
## godot --headless --path . res://prototypes/p2_alert_tiers.tscn

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _party: PartyController
var _staff: StaffActor
var _msgs: Array[String] = []


func _ready() -> void:
	print("=== P2 Alert Tiers ===")
	Game.debug_enabled = false
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry")
	_party = _world.get("party")
	_staff = _world.call("get_staff")
	_staff.set_physics_process(false)
	_staff.global_position = Vector3(40, 0.05, 40)
	Bus.interact_feedback.connect(func(m: String) -> void: _msgs.append(m))
	Clock.set_phase(Clock.Phase.OPEN)
	var raccoon := _party.controlled()
	var own: Interactable = _world.call("door_for_animal", raccoon)
	await _stand(raccoon, own.global_position + Vector3(0, 0, -0.9))
	own.try_use(raccoon)
	await _idle(own)
	var mdoor: Interactable = _world.get("cage_doors")[&"monkey"]
	await _stand(raccoon, mdoor.global_position + Vector3(-1.1, 0, 0))
	mdoor.try_use(raccoon)
	await _idle(mdoor)
	_check(_party.party().size() == 2 and Alert.level == 0, "正式开局：浣熊出笼并救出猴，警戒 0")
	var monkey: AnimalActor = null
	for a in _party.party():
		if a != raccoon:
			monkey = a

	await _noise_never_raises_alert(raccoon)
	await _hearing_tiers(raccoon)
	await _head_icons()
	await _construction_noise(raccoon, monkey)
	await _ground_confiscation(raccoon)
	await _alert_4(raccoon)
	await _alert_5(raccoon)

	print("")
	print("=== P2 ALERT TIERS SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


## Noise only changes staff behaviour; with nobody in earshot (or even when heard) the level stays.
func _noise_never_raises_alert(raccoon: AnimalActor) -> void:
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	_staff.global_position = raccoon.global_position + Vector3(200, 0, 0)
	var stable := true
	for lvl in range(0, GameConst.MAX_ALERT_LEVEL):
		Alert.level = lvl
		for kind in [&"footstep", &"shout", &"interact_hard", &"construction"]:
			Bus.noise_made.emit(raccoon.global_position, 1.5, kind)
		await get_tree().process_frame
		await get_tree().process_frame
		if Alert.level != lvl or _staff.state != StaffActor.State.WORK:
			stable = false
	_check(stable, "无职员在听距内：警戒 0–4 各种噪音都不升警戒、职员不动")
	Alert.level = 1
	_staff.global_position = raccoon.global_position + Vector3(4, 0, 0)
	Bus.noise_made.emit(raccoon.global_position, 1.5, &"construction")
	await get_tree().process_frame
	_check(_staff.state == StaffActor.State.INVESTIGATE and Alert.level == 1, "职员听见噪音前去查看，但警戒仍为 1")
	_reset_staff()
	Alert.level = 0


## Alert 2: staff hear ×1.25 farther (noises and footsteps).
func _hearing_tiers(raccoon: AnimalActor) -> void:
	var p := _staff._params
	var origin := raccoon.global_position
	_staff.global_position = origin + Vector3(p.hear_noise_range * 1.12, 0, 0)
	Alert.level = 1
	Bus.noise_made.emit(origin, 1.0, &"shout")
	await get_tree().process_frame
	var heard_1 := _staff.state != StaffActor.State.WORK
	_reset_staff()
	Alert.level = 2
	Bus.noise_made.emit(origin, 1.0, &"shout")
	await get_tree().process_frame
	_check(not heard_1 and _staff.state == StaffActor.State.INVESTIGATE,
		"警戒 2 听距×%.2f：%.1fm 外的叫声 警戒1 听不到、警戒2 听到" % [Alert.hearing_mult(), p.hear_noise_range * 1.12])
	_reset_staff()
	_staff.global_position = origin + Vector3(p.hear_walk_range * 1.6 * 1.12, 0, 0)
	Alert.level = 1
	Bus.noise_made.emit(origin, 1.0, &"footstep")
	var foot_1 := _staff.state
	_reset_staff()
	Alert.level = 2
	Bus.noise_made.emit(origin, 1.0, &"footstep")
	_check(foot_1 == StaffActor.State.WORK and _staff.state == StaffActor.State.SUSPICIOUS, "警戒 2 脚步声起疑距离也变远")
	_check(is_equal_approx(Alert.hearing_radius(), (GameConst.BASE_HEARING_RADIUS + 2.0 * GameConst.HEARING_PER_ALERT) * 1.25),
		"警戒 2 hearing_radius 含×1.25")
	_check(_msgs.any(func(m: String) -> bool: return m.begins_with("警戒 2：")), "升到警戒 2 有后果提示")
	_reset_staff()
	Alert.level = 0


## ? suspicious · ! investigate/search · !! chase; nothing while working or resting.
func _head_icons() -> void:
	var want := {
		StaffActor.State.WORK: "", StaffActor.State.SUSPICIOUS: "?", StaffActor.State.INVESTIGATE: "!",
		StaffActor.State.SEARCH: "!", StaffActor.State.CHASE: "!!", StaffActor.State.REST: "",
	}
	var icon: Label3D = _staff.get_node("HeadIcon")
	var ok := true
	for s in want:
		_staff.state = s
		_staff._update_head_icon()
		if icon.text != want[s] or icon.visible != (want[s] != ""):
			ok = false
			print("  state %d -> '%s' visible=%s" % [s, icon.text, icon.visible])
	_check(ok, "头上三阶图示：起疑 ? / 调查·搜索 ! / 追捕 !!，平时无")
	_reset_staff()


## Alert 3: route construction noise carries ×1.3 farther. Real Hard climb work by the raccoon.
func _construction_noise(raccoon: AnimalActor, monkey: AnimalActor) -> void:
	Clock.set_phase(Clock.Phase.OPEN)
	await _gather(raccoon, "游客遗落的绳")
	await _gather(raccoon, "垃圾桶（铁罐）")
	await _gather(raccoon, "职员工具间")
	_party.switch_next()
	await get_tree().process_frame
	await _gather(monkey, "晾衣架")
	var climb := _geo.climb_interactable
	await _stand(monkey, climb.global_position + Vector3(0.6, 0.05, 0.9))
	monkey.try_drop()
	_party.switch_next()
	await get_tree().process_frame
	_check(raccoon.item_count(KitIds.ROPE) >= 1 and raccoon.item_count(KitIds.METAL) >= 2 and climb.stash.count(KitIds.ROPE) >= 1,
		"真实搜集：浣熊 %s，猴存进攀爬点 %s" % [raccoon.inventory, climb.stash])
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	var work_pos := climb.global_position + Vector3(0, 0.05, 1.0)
	await _stand(raccoon, work_pos)
	var rw := GameConst.route_work()
	var loud := clampf(clampf(climb.hard_noise * rw.hard_noise_mult, 0.1, 1.5), 0.15, 1.35)
	var r2 := _staff._params.hear_noise_range * loud * GameConst.alert_params().hearing_mult_at_alert_2
	var dist := r2 * 1.15
	_staff.global_position = raccoon.global_position + Vector3(dist, 0, 0)
	Alert.level = 2
	Game.work_time_scale = 0.05
	climb.try_use(raccoon)
	await _idle(climb)
	_check(climb.tier_done == 1 and _staff.state == StaffActor.State.WORK and Alert.level == 2,
		"警戒 2：强行施工第 1 档，%.1fm 外职员听不到（听距 %.1fm）" % [dist, r2])
	await _stand(raccoon, work_pos)
	_staff.global_position = raccoon.global_position + Vector3(dist, 0, 0)
	Alert.level = 3
	_check(_msgs.any(func(m: String) -> bool: return m.begins_with("警戒 3：")), "升到警戒 3 有后果提示")
	climb.try_use(raccoon)
	await _idle(climb)
	_check(climb.tier_done == 2 and _staff.state == StaffActor.State.INVESTIGATE,
		"警戒 3：施工声×%.1f，同距离职员听到前去查看" % Alert.construction_noise_mult())
	_check(_staff.head_icon() == "!", "被施工声引来的职员头上显示 !")
	_check(Alert.level == 3, "施工噪音不升警戒（仍为 3）")
	_reset_staff()
	_staff.global_position = Vector3(40, 0.05, 40)


## Alert 3+: a staff member who sees a dropped item takes it to the office; route-point stash stays.
func _ground_confiscation(raccoon: AnimalActor) -> void:
	Clock.set_phase(Clock.Phase.OPEN)
	await _gather(raccoon, "饲料柜")
	var dig := _geo.dig_interactable
	await _stand(raccoon, dig.global_position + Vector3(1.0, 0.05, 0))
	raccoon.try_drop()
	var stash_before := dig.stash.duplicate()
	_check(stash_before.has(KitIds.WOOD), "浣熊把木料存进挖洞点：%s" % [dig.stash])
	await _gather(raccoon, "南侧杂物堆")
	var drop_at := Vector3(2.0, 0.05, 6.0)
	await _stand(raccoon, drop_at)
	var before := raccoon.inventory.size()
	raccoon.try_drop()
	await get_tree().process_frame
	var items := get_tree().get_nodes_in_group(GroundItem.GROUP)
	_check(items.size() == 1 and raccoon.inventory.size() == before - 1, "浣熊把一件物品丢在地上：%s" % [
		(items[0] as GroundItem).item_id if items.size() > 0 else &"无"])
	if items.is_empty():
		return
	var item := items[0] as GroundItem
	var id := item.item_id
	await _stand(raccoon, Vector3(-8.0, 0.05, 6.0))
	_staff.global_position = item.global_position + Vector3(0, 0, -3.0)
	_staff._facing = Vector3(0, 0, 1)
	Alert.level = 2
	_staff._try_confiscate_ground_items()
	await get_tree().process_frame
	_check(is_instance_valid(item) and item.is_in_group(GroundItem.GROUP), "警戒 2：职员看到地上物品不收")
	OfficeStorage.items.clear()
	Alert.level = 3
	_staff._try_confiscate_ground_items()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(GroundItem.GROUP).is_empty() and OfficeStorage.items.size() == 1 and OfficeStorage.items[0] == id,
		"警戒 3：地上的%s被收进办公室（%s）" % [KitIds.display_name(id), OfficeStorage.summary()])
	_check(_msgs.any(func(m: String) -> bool: return m.contains("收走了地上")), "收缴有提示")
	_staff.global_position = dig.global_position + Vector3(3.0, 0, 0)
	_staff._facing = Vector3(-1, 0, 0)
	_staff._try_confiscate_ground_items()
	_check(dig.stash == stash_before, "施工点存料不被收缴：%s" % [dig.stash])
	_staff.global_position = Vector3(40, 0.05, 40)
	Alert.level = 0


## Alert 4: awareness ×1.35, quiet window ×0.75, HUD warning.
func _alert_4(raccoon: AnimalActor) -> void:
	var p := _staff._params
	var origin := raccoon.global_position
	_staff.global_position = origin + Vector3(p.hear_noise_range * 0.5, 0, 0)
	Alert.level = 3
	Bus.noise_made.emit(origin, 1.0, &"footstep")
	var gain_3 := _staff.awareness
	_reset_staff()
	_msgs.clear()
	Alert.level = 4
	Bus.noise_made.emit(origin, 1.0, &"footstep")
	var gain_4 := _staff.awareness
	_check(gain_3 > 0.0 and absf(gain_4 / gain_3 - 1.35) < 0.01, "警戒 4 起疑×1.35（%.2f → %.2f）" % [gain_3, gain_4])
	_reset_staff()
	_staff.global_position = Vector3(40, 0.05, 40)
	_check(is_equal_approx(Clock.quiet_duration(), GameConst.NIGHT_QUIET_SEC * 0.75), "警戒 4 歇岗缩为×0.75（%.1fs）" % Clock.quiet_duration())
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_check(absf(Clock.phase_remaining() - GameConst.NIGHT_QUIET_SEC * 0.75) < 0.1, "进入歇岗时计时同样缩短（%.1fs）" % Clock.phase_remaining())
	Alert.level = 3
	_check(is_equal_approx(Clock.quiet_duration(), GameConst.NIGHT_QUIET_SEC), "警戒 3 歇岗不变")
	Alert.level = 4
	_check(_msgs.any(func(m: String) -> bool: return m.contains("再升一档将全园搜查")), "升到警戒 4 提示「再升一档将全园搜查」")
	await get_tree().create_timer(0.3).timeout
	var hud := _world.get_node("GameHUD")
	var warn: Label = hud.get("_alert_warn_l")
	_check(warn.visible and warn.text == "再升一档将全园搜查", "HUD 常驻红字预警：%s" % warn.text)
	var fx: Label = hud.get("_alert_fx_l")
	_check(fx.text.contains("起疑") and fx.text.contains("收走地上物品"), "HUD 列出当前后果：%s" % fx.text)
	Alert.level = 3
	await get_tree().create_timer(0.3).timeout
	_check(not warn.visible, "警戒 3 无预警")
	Clock.set_phase(Clock.Phase.OPEN)


## Alert 5: full search — route work refused, and work in progress is cancelled with the reason (refunded).
func _alert_5(raccoon: AnimalActor) -> void:
	var dig := _geo.dig_interactable
	_check(dig._missing(raccoon).is_empty(), "挖洞一档原料齐（存料 %s + 背包 %s）" % [dig.stash, raccoon.inventory])
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	await _stand(raccoon, dig.global_position + Vector3(1.0, 0.05, 0))
	Alert.level = 5
	_msgs.clear()
	var inv := raccoon.inventory.duplicate()
	var stash := dig.stash.duplicate()
	dig.try_use(raccoon)
	await _idle(dig)
	_check(dig.tier_done == 0 and raccoon.inventory == inv and dig.stash == stash and _msgs.any(func(m: String) -> bool: return m.contains("全园搜查")),
		"警戒 5：拒绝开工并说明原因：%s" % [_msgs])
	Alert.level = 4
	Game.work_time_scale = 0.3
	dig.try_use(raccoon)
	await get_tree().create_timer(0.1).timeout
	var mid_busy := dig._busy
	var mid_total := raccoon.inventory.size() + dig.stash.size()
	_msgs.clear()
	Alert.level = 5
	await _idle(dig)
	_check(mid_busy and mid_total < inv.size() + stash.size(), "警戒 4 开工（已扣料）")
	_check(dig.tier_done == 0 and raccoon.inventory.size() == inv.size() and dig.stash.size() == stash.size(),
		"升到警戒 5：施工中止、原料退回原处（背包 %s 存料 %s）" % [raccoon.inventory, dig.stash])
	_check(_msgs.any(func(m: String) -> bool: return m.contains("全园搜查") and m.contains("中止")), "中止原因明确：%s" % [_msgs])
	await get_tree().create_timer(0.3).timeout
	var warn: Label = _world.get_node("GameHUD").get("_alert_warn_l")
	_check(warn.visible and warn.text.contains("全园搜查"), "HUD 警戒 5 红字：%s" % warn.text)


func _reset_staff() -> void:
	_staff.state = StaffActor.State.WORK
	_staff.awareness = 0.0
	_staff._clear_combat_memory()


func _gather(a: AnimalActor, point_name: String) -> void:
	for g in _geo.gather_points:
		if g.display_name != point_name:
			continue
		await _stand(a, g.global_position + Vector3(0.6, 0.05, 0))
		g.try_use(a)
		await get_tree().process_frame
		var t := 0.0
		while g._busy and t < 5.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		return
	_check(false, "找不到搜集点 %s" % point_name)


func _stand(a: AnimalActor, pos: Vector3) -> void:
	a.global_position = pos
	a.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame


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
