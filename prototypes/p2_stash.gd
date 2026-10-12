extends Node
## 刀 2b：放下物品 + 施工点存料。正式开局、无临时能力；原料只来自真实搜集点/拾取点。
## godot --headless --path . res://prototypes/p2_stash.tscn

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _party: PartyController


func _ready() -> void:
	print("=== P2 Stash ===")
	Game.debug_enabled = false
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry")
	_party = _world.get("party")
	var staff: StaffActor = _world.call("get_staff")
	staff.set_physics_process(false)
	staff.global_position = Vector3(40, 0.05, 40)
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
	_check(_party.party().size() == 2, "正式开局：浣熊出笼并救出猴")
	var monkey: AnimalActor = null
	for a in _party.party():
		if a != raccoon:
			monkey = a

	## --- Drop: heavy kit goes first, speed/climb come back, E picks it up again ---
	await _stand(raccoon, _geo.route_kit_pickup.global_position + Vector3(0.5, 0.05, 0))
	_geo.route_kit_pickup.call("try_use", raccoon)
	await _gather(raccoon, "职员工具间")
	_check(raccoon.is_carrying_heavy() and raccoon.has_item(KitIds.METAL), "背着施工套件 + 金属")
	await _stand(raccoon, Vector3(-3.0, 0.05, 3.0))
	raccoon.try_drop()
	await get_tree().process_frame
	var ground := get_tree().get_nodes_in_group(GroundItem.GROUP)
	_check(ground.size() == 1 and (ground[0] as GroundItem).item_id == KitIds.ROUTE, "X 先放下重物（施工套件）到地上")
	_check(not raccoon.is_carrying_heavy() and is_equal_approx(raccoon.current_move_speed(), raccoon.def.move_speed), "放下后移速恢复")
	await get_tree().physics_frame
	(ground[0] as GroundItem).try_use(raccoon)
	await get_tree().process_frame
	_check(raccoon.has_item(KitIds.ROUTE) and get_tree().get_nodes_in_group(GroundItem.GROUP).is_empty(), "E 捡回套件，地上清空")
	raccoon.try_drop()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(GroundItem.GROUP).size() == 1, "再次放下套件（留在地上过夜）")

	## Monkey: the one generic kit — pick up what the raccoon left, drop it to climb again.
	_party.switch_next()
	await get_tree().process_frame
	_check(_party.controlled() == monkey, "换控到猴")
	var left_kit := get_tree().get_nodes_in_group(GroundItem.GROUP)[0] as GroundItem
	await _stand(monkey, left_kit.global_position + Vector3(0.3, 0.05, 0))
	left_kit.try_use(monkey)
	await get_tree().process_frame
	_check(monkey.has_item(KitIds.ROUTE), "猴捡起浣熊放下的同一个套件（挖洞/攀爬通用）")
	_check(not monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "猴背套件不能攀爬")
	monkey.try_drop()
	await get_tree().process_frame
	_check(monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "猴放下套件后可攀爬")
	await get_tree().physics_frame
	for g in get_tree().get_nodes_in_group(GroundItem.GROUP):
		if (g as GroundItem).item_id == KitIds.ROUTE:
			(g as GroundItem).try_use(monkey)
	await get_tree().process_frame
	_check(monkey.has_item(KitIds.ROUTE), "猴捡回套件")

	## --- Stash: raccoon (4 slots) hauls rope + metal to the climb point for the monkey ---
	_party.switch_next()
	await get_tree().process_frame
	await _gather(raccoon, "游客遗落的绳")
	await _gather(raccoon, "南侧杂物堆")
	_check(raccoon.item_count(KitIds.ROPE) == 1 and raccoon.item_count(KitIds.METAL) == 1 and raccoon.item_count(KitIds.WOOD) == 1,
		"浣熊背绳 + 金属 + 木料 %s" % [raccoon.inventory])
	var climb := _geo.climb_interactable
	## Edge of the point: preview must already say what X will do, and match the action.
	var away := climb.global_position + Vector3(climb.use_range + 0.4, 0.05, 0.9)
	await _stand(raccoon, away)
	var far_hint := raccoon.drop_preview()
	_check(far_hint.begins_with("X 丢在地上"), "施工点范围外提示「丢在地上」：%s" % far_hint)
	await _stand(raccoon, climb.global_position + Vector3(0.6, 0.05, 0.9))
	var near_hint := raccoon.drop_preview()
	_check(near_hint.begins_with("X 存入") and near_hint.contains("绳索") and near_hint.contains("金属") and not near_hint.contains("木料"),
		"施工点旁提示「存入」且只列配方用得到的：%s" % near_hint)
	raccoon.try_drop()
	_check(climb.stash.count(KitIds.ROPE) == 1 and climb.stash.count(KitIds.METAL) == 1, "白天存料到攀爬点：%s" % [climb.stash])
	_check(raccoon.item_count(KitIds.WOOD) == 1 and raccoon.inventory.size() == 1, "不在配方的木料留在背包")
	_check(climb.tier_done == 0, "存料不是施工（白天可做）")

	## Stash survives capture and dawn.
	CaptureFlow.apply_capture(raccoon, "测试")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(climb.stash.size() == 2, "被抓、天亮后存料仍在")
	_check(monkey.has_item(KitIds.ROUTE), "猴没被抓，套件还在猴身上")

	## --- Night: monkey builds from the stash; cancel refunds back into the stash ---
	while _party.controlled() != monkey:
		_party.switch_next()
	await get_tree().process_frame
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	await _stand(monkey, Vector3(2.0, 0.05, 6.0))
	monkey.try_drop()
	_check(not monkey.has_item(KitIds.ROUTE) and get_tree().get_nodes_in_group(GroundItem.GROUP).size() == 1, "离点位远：套件放到地上")
	await _stand(monkey, climb.global_position + Vector3(0, 0, 1.0))
	Game.work_time_scale = 0.2
	var msgs: Array[String] = []
	var on_msg := func(m: String) -> void: msgs.append(m)
	Bus.interact_feedback.connect(on_msg)
	climb.try_use(monkey)
	await get_tree().create_timer(0.15).timeout
	var mid_stash := climb.stash.size()
	monkey.global_position += Vector3(6, 0, 0)
	await _idle(climb)
	Bus.interact_feedback.disconnect(on_msg)
	_check(mid_stash == 0 and msgs.any(func(m: String) -> bool: return m.contains("退回原处")), "施工中扣了存料（中途存料 %d）后被取消" % mid_stash)
	_check(climb.tier_done == 0 and climb.stash.size() == 2 and monkey.inventory.is_empty(), "施工中断：原料退回存料而不是猴背包")
	await _stand(monkey, climb.global_position + Vector3(0, 0, 1.0))
	climb.try_use(monkey)
	await _idle(climb)
	_check(climb.tier_done == 1 and climb.stash.is_empty(), "猴空手用存料完成第 1 档")
	_check(get_tree().get_nodes_in_group("traces").is_empty(), "Soft（无痕迹）")

	## --- Next day: stash rope ×2 (monkey climbs the drying rack) + the kit; the kit pays the rest, ropes are left over ---
	Clock.advance()
	Clock.set_phase(Clock.Phase.OPEN)
	await _gather(monkey, "晾衣架")
	_check(monkey.item_count(KitIds.ROPE) == 2, "猴攀爬拿满晾衣架绳索 ×2")
	await _stand(monkey, climb.global_position + Vector3(0, 0, 1.0))
	monkey.try_drop()
	monkey.try_drop()
	_check(climb.stash.count(KitIds.ROPE) == 2, "绳索存进攀爬点：%s" % [climb.stash])
	for g in get_tree().get_nodes_in_group(GroundItem.GROUP):
		if (g as GroundItem).item_id == KitIds.ROUTE:
			await _stand(monkey, (g as GroundItem).global_position + Vector3(0.3, 0.05, 0))
			(g as GroundItem).try_use(monkey)
	await _stand(monkey, climb.global_position + Vector3(0, 0, 1.0))
	monkey.try_drop()
	_check(climb.stash.has(KitIds.ROUTE), "套件也可存进施工点：%s" % [climb.stash])
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	msgs.clear()
	Bus.interact_feedback.connect(on_msg)
	await RouteHelper.finish(get_tree(), climb, monkey, false)
	Bus.interact_feedback.disconnect(on_msg)
	_check(climb._done and climb.stash.is_empty(), "存的套件付完剩下两档，路线完工")
	var left_msg := msgs.filter(func(m: String) -> bool: return m.contains("剩余存料已用尽"))
	_check(left_msg.size() == 1 and String(left_msg[0]).contains("绳索×2"), "完工提示剩余存料：%s" % [left_msg])

	print("")
	print("=== P2 STASH SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


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


## Teleport, then let the interact area refresh its overlaps.
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
