extends Node
## 昼夜 M5：夜间施工（分档、付费、打断、套件顶档、Soft/Hard 时长、跨天保留）。
## godot --headless --path . res://prototypes/p2_route_work.tscn

var _pass_n := 0
var _fail_n := 0


var _log: Array[String] = []


func _ready() -> void:
	print("=== P2 Route Work ===")
	Bus.interact_feedback.connect(func(m: String) -> void: _log.append(m))
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
	var party: PartyController = world.get("party")
	party.rescue(&"monkey", false)
	await get_tree().process_frame
	var raccoon: AnimalActor = party.controlled()
	var monkey: AnimalActor = null
	for a in party.party():
		if a != raccoon:
			monkey = a
	session.mark_exhibit_escaped()
	session.mark_companion_rescued()
	var dig := geo.dig_interactable
	Game.work_time_scale = 0.1
	_check(dig.tiers == GameConst.ROUTE_TIERS, "挖洞点分 %d 档" % dig.tiers)

	## Day: no construction.
	Clock.set_phase(Clock.Phase.OPEN)
	raccoon.give_items([KitIds.WOOD, KitIds.METAL])
	_stand(raccoon, dig)
	dig.try_use(raccoon)
	await get_tree().process_frame
	_check(dig.tier_done == 0 and raccoon.material_count() == 2, "白天拒绝施工且不扣料")

	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	## Park the guard far away so Hard noise cannot instantly catch us.
	var staff: StaffActor = world.call("get_staff")
	staff.set_physics_process(false)
	staff.global_position = Vector3(10, 0.05, 10)

	## No materials → refused.
	raccoon.inventory.clear()
	dig.try_use(raccoon)
	await get_tree().process_frame
	_check(dig.tier_done == 0 and not dig._busy, "没材料不能开工")

	## One generic kit for both lines.
	_check(dig.route_kit_id == KitIds.ROUTE and geo.climb_interactable.route_kit_id == KitIds.ROUTE,
		"挖洞线与攀爬线用同一种通用套件")

	## Missing one ingredient → refused.
	raccoon.inventory.clear()
	raccoon.give_items([KitIds.WOOD, KitIds.WOOD])
	dig.try_use(raccoon)
	await get_tree().process_frame
	_check(dig.tier_done == 0 and not dig._busy, "缺金属（只有木料×2）不能开工")
	raccoon.inventory.clear()

	## Leaving mid-tier keeps the progress and the payment; coming back resumes without paying again.
	raccoon.give_items([KitIds.WOOD, KitIds.METAL])
	dig.try_use(raccoon)
	await get_tree().create_timer(0.5).timeout
	raccoon.global_position += Vector3(6, 0, 0)
	await get_tree().create_timer(0.2).timeout
	var kept := dig.tier_progress
	_check(dig.tier_done == 0 and not dig._busy and kept > 0.1 and kept < 1.0 and raccoon.material_count() == 0,
		"中途离开：本档已付，进度 %d%% 保留" % int(kept * 100.0))
	_check(dig._label and dig._label.full_text.contains("本档 %d%%" % int(kept * 100.0)),
		"施工点标签显示本档进度百分比")
	_stand(raccoon, dig)
	var t0 := Time.get_ticks_msec()
	dig.try_use(raccoon)
	await _idle(dig)
	var resume_ms := Time.get_ticks_msec() - t0
	var soft_full_ms := int(GameConst.TIER_SOFT_SEC * Game.work_time_scale * 1000.0)
	_check(dig.tier_done == 1 and raccoon.material_count() == 0, "回来接着做：不再扣料，第 1 档完成")
	_check(resume_ms < soft_full_ms, "接续只做剩下的 (%dms < 整档 %dms)" % [resume_ms, soft_full_ms])
	_check(session.route_tiers[RunSession.ExitRoute.DIG] == 1, "会话记录施工进度 1/3")
	_check(is_equal_approx(session.breach, 1.0 / float(GameConst.ROUTE_TIERS)), "Breach = 进度 %.2f" % session.breach)
	_check(not session.route_dig_ready, "未完工路线不开")

	## Hard (monkey has neither squeeze nor lockpick): non-final tier costs no materials, time = soft base × mult.
	raccoon.global_position = dig.global_position + Vector3(8, 0.05, 0)
	monkey.order_hold() ## followers walk away from the leader otherwise
	monkey.give_items([KitIds.WOOD, KitIds.METAL])
	_stand(monkey, dig)
	monkey._hold_position = monkey.global_position
	_check(is_equal_approx(Interactable.tier_seconds(false), GameConst.TIER_SOFT_SEC * GameConst.route_work().hard_time_mult),
		"Hard 一档 = 擅长者基础 %.0fs × %.0f = %.0fs" % [
			GameConst.TIER_SOFT_SEC, GameConst.route_work().hard_time_mult, Interactable.tier_seconds(false)])
	t0 = Time.get_ticks_msec()
	dig.try_use(monkey)
	await _idle(dig)
	var hard_ms := Time.get_ticks_msec() - t0
	var hard_expect := int(Interactable.tier_seconds(false) * Game.work_time_scale * 1000.0 * 0.75)
	_check(dig.tier_done == 2, "Hard 完成第 2 档")
	_check(monkey.material_count() == 2, "Hard 档不扣料（猴的木料+金属还在）")
	_check(hard_ms >= hard_expect, "Hard 含时倍率 慢 %dms（≥%d）" % [hard_ms, hard_expect])

	## Progress persists across days (tier count).
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(dig.tier_done == 2, "施工档数跨天保留")
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)

	## Last tier: the monkey may not force it.
	dig.try_use(monkey)
	await get_tree().process_frame
	_check(dig.tier_done == 2 and not dig._busy, "最后一档：猴无钻缝/巧手禁止强行")

	## Soft last tier: raccoon's lockpick counts at the dig line; pays with materials.
	monkey.inventory.clear()
	raccoon.give_items([KitIds.WOOD, KitIds.METAL])
	_stand(raccoon, dig)
	dig.try_use(raccoon)
	await _idle(dig)
	_check(dig.tier_done == 3 and dig._done and raccoon.material_count() == 0, "浣熊（巧手）Soft 付料完成最后一档")
	_check(session.route_dig_ready, "路线就绪")

	## Soft is faster (monkey climbs).
	var climb := geo.climb_interactable
	monkey.give_items([KitIds.ROUTE])
	_stand(monkey, climb)
	monkey._hold_position = monkey.global_position
	t0 = Time.get_ticks_msec()
	climb.try_use(monkey)
	await _idle(climb)
	var soft_ms := Time.get_ticks_msec() - t0
	_check(climb.tier_done == 1, "猴攀爬第 1 档")
	_check(soft_ms < hard_ms, "Soft 比 Hard 快 (%dms < %dms)" % [soft_ms, hard_ms])

	## Dawn mid-tier: progress stays, the site is marked once overnight, the next night resumes.
	climb.try_use(monkey)
	await get_tree().create_timer(0.5).timeout
	var traces_before := _traces_near(climb)
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	await get_tree().process_frame
	await get_tree().process_frame
	var dawn_kept := climb.tier_progress
	_check(not climb._busy and climb.tier_done == 1 and dawn_kept > 0.1 and dawn_kept < 1.0,
		"天亮中断：第 2 档进度 %d%% 跨夜保留" % int(dawn_kept * 100.0))
	_check(_traces_near(climb) == traces_before + 1, "跨夜未完成留下 1 处施工痕迹")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(_traces_near(climb) == traces_before + 1, "同一档跨多夜只留一次痕迹（单次结算）")

	## Caught tonight: tonight's new progress is lost, earlier nights' stays.
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	_stand(monkey, climb)
	monkey._hold_position = monkey.global_position
	climb.try_use(monkey)
	await get_tree().create_timer(0.3).timeout
	_check(climb.tier_progress > dawn_kept, "接着昨夜进度继续")
	monkey.is_confined = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not climb._busy and is_equal_approx(climb.tier_progress, dawn_kept),
		"被抓：只扣当晚新增进度（回到 %d%%）" % int(dawn_kept * 100.0))
	monkey.is_confined = false
	_stand(monkey, climb)
	monkey._hold_position = monkey.global_position
	climb.try_use(monkey)
	await _idle(climb)
	_check(climb.tier_done == 2, "被抓后重来仍可完成该档")

	## Hard fits in 1–2 nights at every Alert level; nothing in the params makes a tier endless.
	var shortest_night := RouteWorkCheck.shortest_night()
	var hard_nights := int(RouteWorkCheck.min_nights(false))
	_check(hard_nights >= 1 and hard_nights <= 2, "Hard 一档 %.0fs，最短一夜 %.0fs → %d 夜内完成" % [
		Interactable.tier_seconds(false), shortest_night, hard_nights])
	_check(RouteWorkCheck.validate().is_empty(), "载入检查：任一档最短完成夜数有限 %s" % [RouteWorkCheck.validate()])

	print("")
	print("=== P2 ROUTE WORK SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _stand(a: AnimalActor, it: Interactable) -> void:
	a.is_confined = false
	a.global_position = it.global_position + Vector3(0.9, 0.05, 0.4)
	a.velocity = Vector3.ZERO


func _traces_near(it: Interactable) -> int:
	var n := 0
	for t in get_tree().get_nodes_in_group("traces"):
		if (t as Node3D).global_position.distance_to(it.global_position) < 1.0:
			n += 1
	return n


func _idle(it: Interactable) -> void:
	await get_tree().process_frame
	var t := 0.0
	while it._busy and t < 30.0:
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
