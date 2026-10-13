extends Node
## 两条出园线在「浣熊＋猴」下都能完整通关：每条线一局新档，从正式开局走到 WON。
## 不得临时赋予能力；原料/套件只经真实搜集点与拾取点获得（移动用传送代替走路）。
## 全程 Soft：完工后场上不应有任何施工痕迹。
## godot --headless --path . res://prototypes/p2_route_clear.tscn

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _session: RunSession
var _party: PartyController


func _ready() -> void:
	print("=== P2 Route Clear ===")
	Game.debug_enabled = false
	await _boot()
	await _dig_run()
	await _boot()
	await _climb_run()
	await _boot()
	await _kit_retrieved_run()
	await _boot()
	await _hard_no_kit_run()
	await _boot(false)
	await _solo_refused_run()
	print("")
	print("=== P2 ROUTE CLEAR SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


## Fresh official start, then raccoon opens its own cage (and the monkey's when rescue_monkey).
func _boot(rescue_monkey: bool = true) -> void:
	if _world:
		_world.queue_free()
		await get_tree().process_frame
	get_tree().paused = false ## WON pauses the tree
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry")
	_session = _world.get("session")
	_party = _world.get("party")
	var staff: StaffActor = _world.call("get_staff")
	staff.set_physics_process(false)
	staff.global_position = Vector3(40, 0.05, 40)
	Clock.set_phase(Clock.Phase.OPEN)
	var raccoon := _party.controlled()
	_check(raccoon.def.resource_path == "res://content/animals/raccoon.tres" and _party.party().size() == 1, "正式开局：只有浣熊")
	var own: Interactable = _world.call("door_for_animal", raccoon)
	_stand(raccoon, own.global_position + Vector3(0, 0, -0.9))
	own.try_use(raccoon)
	await _idle(own)
	if not rescue_monkey:
		_check(own._done and _party.party().size() == 1, "浣熊出笼（不救猴）")
		return
	await _rescue_monkey(raccoon)
	_check(own._done and _party.party().size() == 2, "浣熊出笼并救出猴")


func _rescue_monkey(raccoon: AnimalActor) -> void:
	var mdoor: Interactable = _world.get("cage_doors")[&"monkey"]
	_stand(raccoon, mdoor.global_position + Vector3(-1.1, 0, 0))
	mdoor.try_use(raccoon)
	await _idle(mdoor)


## Raccoon digs out alone: the exit must refuse until the monkey is rescued and present.
func _solo_refused_run() -> void:
	var msgs: Array[String] = []
	var on_msg := func(m: String) -> void: msgs.append(m)
	Bus.interact_feedback.connect(on_msg)
	var raccoon := _party.controlled()
	var dig := _geo.dig_interactable
	await _pick_kit(raccoon, _geo.route_kit_pickup)
	await _gather(raccoon, "职员工具间")
	await _gather(raccoon, "饲料柜")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_stand(raccoon, dig.global_position + Vector3(0.9, 0.05, 0.4))
	await RouteHelper.finish(get_tree(), dig, raccoon, false)
	_check(_session.route_dig_ready, "浣熊独自打通挖洞线")
	_stand(raccoon, _geo.exit_west.global_position + Vector3(0, -0.9, 0))
	for _i in 10:
		await get_tree().physics_frame
	_world.call("check_exit_win", RunSession.ExitRoute.DIG)
	await get_tree().process_frame
	var refusals := msgs.filter(func(m: String) -> bool: return m.contains("还关在笼里"))
	_check(_session.outcome == RunSession.Outcome.NONE, "未救猴：浣熊进出口不结算（outcome=%s）" % _session.outcome)
	_check(refusals.size() == 1 and String(refusals[0]).contains("猴"), "拒绝提示点名猴且不刷屏（%d 条）：%s" % [refusals.size(), refusals[0] if not refusals.is_empty() else "—"])
	Bus.interact_feedback.disconnect(on_msg)
	## Go back and rescue for real, then both leave.
	Clock.set_phase(Clock.Phase.OPEN)
	await _rescue_monkey(raccoon)
	_check(_party.party().size() == 2, "回头救出猴")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	await _exit_all(_geo.exit_west, RunSession.ExitRoute.DIG)


## Dig line: raccoon lockpicks every tier (Soft). Kit pays two tiers, wood+metal the last.
func _dig_run() -> void:
	var raccoon := _party.controlled()
	var dig := _geo.dig_interactable
	_check(not dig.accepted_caps().has(CapabilityIds.Id.DIG), "挖洞线不要求挖掘（要求：%s）" % dig.requirement_text())
	_check(dig._qualifies(raccoon, true), "浣熊可 Soft 施工挖洞线")
	await _pick_kit(raccoon, _geo.route_kit_pickup)
	await _gather(raccoon, "职员工具间")
	await _gather(raccoon, "饲料柜")
	_check(raccoon.has_item(KitIds.ROUTE) and raccoon.item_count(KitIds.METAL) == 1 and raccoon.item_count(KitIds.WOOD) == 2,
		"白天备齐：施工套件 + 金属 + 木料×2（饲料柜，全图仅此一处）%s" % [raccoon.inventory])

	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_stand(raccoon, dig.global_position + Vector3(0.9, 0.05, 0.4))
	await RouteHelper.finish(get_tree(), dig, raccoon, false)
	_check(dig._done and _session.route_dig_ready, "浣熊完成挖洞线 %d/%d" % [dig.tier_done, dig.tiers])
	_check(get_tree().get_nodes_in_group("traces").is_empty(), "全程 Soft（无施工痕迹）")
	var gate_x := dig.global_position.x - 0.8
	await _follower_walks_out(Vector3(-9.5, 0.05, 1.5), Vector3(-16.0, 0.05, 1.5),
		func(p: Vector3) -> bool: return p.x < gate_x - 0.6)
	await _exit_all(_geo.exit_west, RunSession.ExitRoute.DIG)


## Climb line: monkey climbs every tier (Soft). Backpack 2: rope+metal first, then fetch the kit at night.
func _climb_run() -> void:
	_party.switch_next()
	await get_tree().process_frame
	var monkey := _party.controlled()
	var climb := _geo.climb_interactable
	_check(monkey.def.id == &"monkey" and monkey.def.resource_path == "res://content/animals/monkey.tres", "切换操控猴（正式 AnimalDef）")
	await _gather(monkey, "游客遗落的绳")
	await _rummage_until_found(monkey, "垃圾桶（铁罐）")
	_check(monkey.item_count(KitIds.ROPE) == 1 and monkey.item_count(KitIds.METAL) == 1, "白天备齐：绳索 + 金属 %s" % [monkey.inventory])
	_check(not monkey.is_carrying_heavy() and monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "原料不是重物：仍可攀爬")

	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_stand(monkey, climb.global_position + Vector3(0, 0, 1.0))
	await RouteHelper.finish(get_tree(), climb, monkey, false)
	_check(climb.tier_done == 1, "绳索+金属完成第 1 档")
	await _pick_kit(monkey, _geo.route_kit_pickup)
	_check(monkey.is_carrying_heavy() and not monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "背着施工套件 = 重物")
	_stand(monkey, climb.global_position + Vector3(0, 0, 1.0))
	await RouteHelper.finish(get_tree(), climb, monkey, false)
	_check(climb._done and _session.route_climb_ready, "猴完成攀爬线 %d/%d" % [climb.tier_done, climb.tiers])
	_check(get_tree().get_nodes_in_group("traces").is_empty(), "全程 Soft（无施工痕迹）")
	var gate := _geo.south_outer_gate
	_check(not is_instance_valid(gate) or gate.collision_layer == 0, "南外墙已让出通道")
	var gate_z := climb.global_position.z - 0.9
	await _follower_walks_out(Vector3(-4.5, 0.05, -10.9), Vector3(-4.5, 0.05, -16.0),
		func(p: Vector3) -> bool: return p.z < gate_z - 0.6)
	await _exit_all(_geo.exit_south, RunSession.ExitRoute.CLIMB)


## The kit is the Soft line's must-have: a capture sends it to the office (never destroyed), the raccoon
## lockpicks the office chest (Soft, no trace) to get it back and still finishes the dig line.
func _kit_retrieved_run() -> void:
	var raccoon := _party.controlled()
	var dig := _geo.dig_interactable
	await _pick_kit(raccoon, _geo.route_kit_pickup)
	await _gather(raccoon, "职员工具间")
	await _gather(raccoon, "饲料柜")
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	CaptureFlow.apply_capture(raccoon, "测试：背着套件被抓")
	_check(not raccoon.has_item(KitIds.ROUTE) and OfficeStorage.items.has(KitIds.ROUTE),
		"被抓：套件收进办公室暂存，没有销毁（%s）" % OfficeStorage.summary())
	CaptureFlow.release(raccoon)
	var chest := _geo.find_child("OfficeChest", true, false) as OfficeChest
	_check(chest != null, "办公室储物柜存在")
	_stand(raccoon, chest.global_position + Vector3(2.0, 0.05, 0))
	await get_tree().physics_frame
	chest.try_use(raccoon)
	await _idle(chest)
	_check(raccoon.has_item(KitIds.ROUTE) and raccoon.item_count(KitIds.WOOD) == 2 and raccoon.has_item(KitIds.METAL),
		"巧手开柜取回套件和原料：%s" % [raccoon.inventory])
	_check(get_tree().get_nodes_in_group("traces").is_empty(), "取回走 Soft：不留痕迹")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_stand(raccoon, dig.global_position + Vector3(0.9, 0.05, 0.4))
	await RouteHelper.finish(get_tree(), dig, raccoon, false)
	_check(dig._done and _session.route_dig_ready, "取回套件后完成挖洞线 %d/%d" % [dig.tier_done, dig.tiers])
	await _exit_all(_geo.exit_west, RunSession.ExitRoute.DIG)


## No kit at all: the monkey forces the first two dig tiers (free, slow, loud, traces), the raccoon's
## lockpick does the last one with wood + metal. Still clears.
func _hard_no_kit_run() -> void:
	var raccoon := _party.controlled()
	var monkey: AnimalActor = null
	for a in _party.party():
		if a != raccoon:
			monkey = a
	var dig := _geo.dig_interactable
	await _gather(raccoon, "职员工具间")
	await _gather(raccoon, "饲料柜")
	_check(not raccoon.has_item(KitIds.ROUTE) and not monkey.has_item(KitIds.ROUTE), "不拿套件")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	monkey.order_hold()
	_stand(monkey, dig.global_position + Vector3(0.9, 0.05, 0.4))
	monkey._hold_position = monkey.global_position
	_check(not dig._qualifies(monkey, true), "猴对挖洞线没有钻缝/巧手 → 只能强行")
	await RouteHelper.finish(get_tree(), dig, monkey, false)
	_check(dig.tier_done == GameConst.ROUTE_TIERS - 1 and not dig._done, "猴强行做完前 %d 档（最后一档禁止强行）" % dig.tier_done)
	_check(raccoon.item_count(KitIds.WOOD) == 2 and raccoon.item_count(KitIds.METAL) == 1, "强行档不扣料：浣熊的原料原封不动")
	_check(get_tree().get_nodes_in_group("traces").size() >= 2, "强行留下施工痕迹（%d 处）" % get_tree().get_nodes_in_group("traces").size())
	_stand(raccoon, dig.global_position + Vector3(0.9, 0.05, 0.4))
	await RouteHelper.finish(get_tree(), dig, raccoon, false)
	_check(dig._done and _session.route_dig_ready and raccoon.item_count(KitIds.WOOD) == 1 and raccoon.item_count(KitIds.METAL) == 0,
		"浣熊 Soft 付木料+金属完成最后一档")
	await _exit_all(_geo.exit_west, RunSession.ExitRoute.DIG)


## Leader waits past the exit; the follower starts inside the wall and must walk out through the gap itself.
func _follower_walks_out(inside: Vector3, outside: Vector3, crossed: Callable) -> void:
	var leader := _party.controlled()
	var follower: AnimalActor = null
	for a in _party.party():
		if a != leader:
			follower = a
	_stand(leader, outside)
	_stand(follower, inside)
	leader.follow_trail.points.clear()
	follower.order_follow()
	var t := 0.0
	while t < 12.0 and not crossed.call(follower.global_position):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(crossed.call(follower.global_position), "%s 自己走出缺口（%.1fs，%s）" % [follower.def.display_name, t, follower.global_position])

func _exit_all(zone: Area3D, route: RunSession.ExitRoute) -> void:
	for a in _party.party():
		a.set_confined(false)
		_stand(a, zone.global_position + Vector3(0, -0.9, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_world.call("check_exit_win", route)
	await get_tree().process_frame
	_check(_session.outcome == RunSession.Outcome.WON and _party.party().size() == 2,
		"双动物出园 → WON（%s）" % _session.outcome_reason)


func _pick_kit(a: AnimalActor, pickup: Area3D) -> void:
	_stand(a, pickup.global_position + Vector3(0.5, 0.05, 0))
	pickup.call("try_use", a)
	await get_tree().process_frame


func _gather(a: AnimalActor, point_name: String) -> void:
	for g in _geo.gather_points:
		if g.display_name != point_name:
			continue
		_stand(a, g.global_position + Vector3(0.6, 0.05, 0))
		g.try_use(a)
		await get_tree().process_frame
		var t := 0.0
		while g._busy and t < 5.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		return
	_check(false, "找不到搜集点 %s" % point_name)


## Trash bin may come up empty; pity guarantees a find within gather_repeat_pity + 1 tries.
func _rummage_until_found(a: AnimalActor, point_name: String) -> void:
	var have := a.inventory.size()
	for _i in GameConst.action_cost().gather_repeat_pity + 1:
		await _gather(a, point_name)
		if a.inventory.size() > have:
			return


func _stand(a: AnimalActor, pos: Vector3) -> void:
	a.global_position = pos
	a.velocity = Vector3.ZERO


func _idle(it: Interactable) -> void:
	await get_tree().process_frame
	var t := 0.0
	while it._busy and t < 5.0:
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
