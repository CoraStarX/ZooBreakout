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

	## Wrong kit is not accepted.
	raccoon.give_items([KitIds.CLIMB])
	dig.try_use(raccoon)
	await get_tree().process_frame
	_check(dig.tier_done == 0, "错套件不能用")
	raccoon.inventory.clear()

	## Missing one ingredient → refused.
	raccoon.inventory.clear()
	raccoon.give_items([KitIds.WOOD, KitIds.WOOD])
	dig.try_use(raccoon)
	await get_tree().process_frame
	_check(dig.tier_done == 0 and not dig._busy, "缺金属（只有木料×2）不能开工")
	raccoon.inventory.clear()

	## Interrupted work costs nothing.
	raccoon.give_items([KitIds.WOOD, KitIds.METAL])
	dig.try_use(raccoon)
	await get_tree().create_timer(0.2).timeout
	raccoon.global_position += Vector3(6, 0, 0)
	await get_tree().create_timer(0.3).timeout
	_check(dig.tier_done == 0 and raccoon.material_count() == 2 and not dig._busy, "中途离开：不扣料、无进度")

	## Hard (raccoon has no DIG): one tier for 2 parts, slow.
	_stand(raccoon, dig)
	var t0 := Time.get_ticks_msec()
	dig.try_use(raccoon)
	await _idle(dig)
	var hard_ms := Time.get_ticks_msec() - t0
	_check(dig.tier_done == 1, "第 1 档完成")
	_check(raccoon.material_count() == 0, "每档消耗配方原料（木料+金属）")
	_check(hard_ms >= int(GameConst.TIER_HARD_SEC * Game.work_time_scale * 1000.0 * 0.8), "Hard 慢 %dms" % hard_ms)
	_check(session.route_tiers[RunSession.ExitRoute.DIG] == 1, "会话记录施工进度 1/3")
	_check(is_equal_approx(session.breach, 1.0 / float(GameConst.ROUTE_TIERS)), "Breach = 进度 %.2f" % session.breach)
	_check(not session.route_dig_ready, "未完工路线不开")

	## Progress persists across days.
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(dig.tier_done == 1, "施工进度跨天保留")
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)

	## Kit pays tier 2 and covers tier 3 for free.
	raccoon.give_items([KitIds.DIG])
	_stand(raccoon, dig)
	dig.try_use(raccoon)
	await _idle(dig)
	_check(dig.tier_done == 2 and not raccoon.has_item(KitIds.DIG), "套件付第 2 档并被消耗")
	dig.try_use(raccoon)
	await _idle(dig)
	_check(dig.tier_done == 3 and dig._done and raccoon.material_count() == 0, "套件余量免费付第 3 档（不耗原料）并完工")
	_check(session.route_dig_ready, "路线就绪")

	## Soft is faster (monkey climbs).
	var climb := geo.climb_interactable
	monkey.order_hold() ## followers walk away from the leader otherwise
	monkey.give_items([KitIds.CLIMB])
	_stand(monkey, climb)
	monkey._hold_position = monkey.global_position
	t0 = Time.get_ticks_msec()
	climb.try_use(monkey)
	await _idle(climb)
	var soft_ms := Time.get_ticks_msec() - t0
	_check(climb.tier_done == 1, "猴攀爬第 1 档")
	_check(soft_ms < hard_ms, "Soft 比 Hard 快 (%dms < %dms)" % [soft_ms, hard_ms])

	print("")
	print("=== P2 ROUTE WORK SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _stand(a: AnimalActor, it: Interactable) -> void:
	a.is_confined = false
	a.global_position = it.global_position + Vector3(0.9, 0.05, 0.4)
	a.velocity = Vector3.ZERO


func _idle(it: Interactable) -> void:
	await get_tree().process_frame
	var t := 0.0
	while it._busy and t < 10.0:
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
