extends Node
## 昼夜循环端到端：第 1 天白天搜集+侦察 → 夜间施工 → 出园通关；并核对时间预算。
## 不按 T / 不开 Debug；只有施工读条按 Game.work_time_scale 加速。
## godot --headless --path . res://prototypes/p2_full_loop.tscn

const Gather := preload("res://content/levels/zoo_p0_gather.gd")

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _session: RunSession
var _log: Array[String] = []


func _ready() -> void:
	print("=== P2 Full Loop ===")
	Bus.interact_feedback.connect(func(m: String) -> void: _log.append(m))
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry")
	_session = _world.get("session")
	var actor: AnimalActor = _world.get("party").controlled()
	var staff: StaffActor = _world.call("get_staff")
	staff.set_physics_process(false)
	staff.global_position = Vector3(10, 0.05, 10)

	_budget_check()

	## --- Day 1 ---
	_check(Clock.phase == Clock.Phase.OPEN and Clock.day == 1, "第 1 天白天开局")
	var door: Interactable = _world.call("door_for_animal", actor)
	actor.global_position = door.global_position + Vector3(0, 0, -0.9)
	door.try_use(actor)
	await _idle(door)
	_check(door._done and _session.exhibit_escaped, "白天溜出笼门")

	await _gather_day(actor)
	var metal := actor.item_count(KitIds.METAL)
	_check(metal < GameConst.ROUTE_TIERS, "第 1 天稳妥玩法金属不够整条路线（金属 %d < %d）" % [metal, GameConst.ROUTE_TIERS])
	var tiers_affordable := mini(metal, actor.item_count(KitIds.WOOD))

	var rest_pt: ObservePoint = _geo.observe_points[0]
	staff.global_position = rest_pt.global_position + Vector3(5, 0, 0)
	actor.global_position = rest_pt.global_position + Vector3(0.5, 0.05, 0)
	rest_pt.try_use(actor)
	await get_tree().create_timer(GameConst.OBSERVE_SEC + 0.8).timeout
	_check(_session.has_intel(IntelIds.REST_TIME), "白天侦察得到歇岗情报")
	staff.global_position = Vector3(10, 0.05, 10)

	## --- Night 1: build as far as the materials go ---
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	var dig := _geo.dig_interactable
	actor.global_position = dig.global_position + Vector3(0.9, 0.05, 0.4) ## the walk over, abbreviated
	await RouteHelper.finish(get_tree(), dig, actor, false)
	_check(dig.tier_done == tiers_affordable and not _session.route_dig_ready,
		"第 1 夜只能做 %d/%d 档，路线未通" % [dig.tier_done, GameConst.ROUTE_TIERS])
	var vision0 := staff.vision_range

	## --- Day 2 ---
	Clock.advance()
	_check(Clock.day == 2 and Clock.phase == Clock.Phase.OPEN, "进入第 2 天")
	_check(staff.vision_range > vision0 - 0.001 and staff.vision_range >= 7.0 + GameConst.STAFF_VISION_PER_DAY - 0.001, "职员视野随天数增长 %.1fm" % staff.vision_range)
	_check(dig.tier_done > 0, "施工进度保留")
	await _gather_day(actor)
	var left := GameConst.ROUTE_TIERS - dig.tier_done
	_check(actor.item_count(KitIds.METAL) >= left and actor.item_count(KitIds.WOOD) >= left, "第 2 天补够剩余 %d 档的原料" % left)

	## --- Night 2: finish ---
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	actor.global_position = dig.global_position + Vector3(0.9, 0.05, 0.4)
	await RouteHelper.finish(get_tree(), dig, actor, false)
	_check(dig.tier_done == GameConst.ROUTE_TIERS and _session.route_dig_ready, "第 2 夜完工，挖掘线打通")
	_check(Clock.day == 2, "第 2 天通关")

	## --- Exit ---
	var zone: Area3D = _geo.exit_west
	actor.global_position = zone.global_position + Vector3(0, -0.9, 0)
	_world.call("check_exit_win", RunSession.ExitRoute.DIG)
	_check(_session.outcome == RunSession.Outcome.WON, "进入出口 → 通关（%s）" % _session.outcome_reason)

	print("")
	print("=== P2 FULL LOOP SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _steal_cart(actor: AnimalActor, staff: StaffActor) -> void:
	var cart := _geo.staff_cart
	staff.global_position = Vector3(3.0, 0.05, 7.0)
	for _i in 40: ## let the cart settle behind the (frozen) staff
		await get_tree().physics_frame
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	var t := 0.0
	await get_tree().process_frame
	while cart._busy and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	staff.global_position = Vector3(10, 0.05, 10)


func _gather_day(actor: AnimalActor) -> void:
	var staff: StaffActor = _world.call("get_staff")
	await _steal_cart(actor, staff)
	for g in _geo.gather_points:
		if g.yield_rich >= 3:
			continue ## risky tool shed skipped
		actor.global_position = g.global_position + Vector3(0.6, 0.05, 0)
		g.try_use(actor)
		var t := 0.0
		await get_tree().process_frame
		while g._busy and t < 5.0:
			await get_tree().process_frame
			t += get_process_delta_time()


## 时间预算：最慢动词（全 Hard）一条路线的施工总时长必须塞得进一个夜晚（巡逻+歇岗）。
func _budget_check() -> void:
	var night := GameConst.NIGHT_PATROL_BASE_SEC + GameConst.NIGHT_QUIET_SEC
	var hard_route := GameConst.TIER_HARD_SEC * GameConst.ROUTE_TIERS
	var soft_route := GameConst.TIER_SOFT_SEC * GameConst.ROUTE_TIERS
	print("NOTE 夜长 %.0fs · 全 Hard 一条路线 %.0fs · 全 Soft %.0fs" % [night, hard_route, soft_route])
	_check(hard_route < night and hard_route >= night * 0.6, "全 Hard 路线 %.0fs：一夜能打通但占去大半（一夜 %.0fs）" % [hard_route, night])
	_check(soft_route < night, "全 Soft 路线 %.0fs < 一夜 %.0fs" % [soft_route, night])


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
