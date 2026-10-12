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
	await _stand(raccoon, _geo.dig_kit_pickup.global_position + Vector3(0.5, 0.05, 0))
	_geo.dig_kit_pickup.call("try_use", raccoon)
	await _gather(raccoon, "垃圾桶（铁罐）")
	_check(raccoon.is_carrying_heavy() and raccoon.has_item(KitIds.METAL), "背着挖掘套件 + 金属")
	await _stand(raccoon, Vector3(-3.0, 0.05, 3.0))
	raccoon.try_drop()
	await get_tree().process_frame
	var ground := get_tree().get_nodes_in_group(GroundItem.GROUP)
	_check(ground.size() == 1 and (ground[0] as GroundItem).item_id == KitIds.DIG, "X 先放下重物（挖掘套件）到地上")
	_check(not raccoon.is_carrying_heavy() and is_equal_approx(raccoon.current_move_speed(), raccoon.def.move_speed), "放下后移速恢复")
	await get_tree().physics_frame
	(ground[0] as GroundItem).try_use(raccoon)
	await get_tree().process_frame
	_check(raccoon.has_item(KitIds.DIG) and get_tree().get_nodes_in_group(GroundItem.GROUP).is_empty(), "E 捡回套件，地上清空")
	raccoon.try_drop()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(GroundItem.GROUP).size() == 1, "再次放下套件（留在地上过夜）")

	## Monkey: drop the climb kit to climb again.
	_party.switch_next()
	await get_tree().process_frame
	_check(_party.controlled() == monkey, "换控到猴")
	await _stand(monkey, _geo.climb_kit_pickup.global_position + Vector3(0.5, 0.05, 0))
	_geo.climb_kit_pickup.call("try_use", monkey)
	_check(not monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "猴背攀爬套件不能攀爬")
	monkey.try_drop()
	await get_tree().process_frame
	_check(monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "猴放下套件后可攀爬")
	await get_tree().physics_frame
	for g in get_tree().get_nodes_in_group(GroundItem.GROUP):
		if (g as GroundItem).item_id == KitIds.CLIMB:
			(g as GroundItem).try_use(monkey)
	await get_tree().process_frame
	_check(monkey.has_item(KitIds.CLIMB), "猴捡回攀爬套件")

	## --- Stash: raccoon (4 slots) hauls rope + metal to the climb point for the monkey ---
	_party.switch_next()
	await get_tree().process_frame
	await _gather(raccoon, "游客遗落的绳")
	await _gather(raccoon, "南侧杂物堆")
	_check(raccoon.item_count(KitIds.ROPE) == 1 and raccoon.item_count(KitIds.METAL) == 1 and raccoon.item_count(KitIds.WOOD) == 1,
		"浣熊背绳 + 金属 + 木料 %s" % [raccoon.inventory])
	var climb := _geo.climb_interactable
	await _stand(raccoon, climb.global_position + Vector3(0.6, 0.05, 0.9))
	raccoon.try_drop()
	_check(climb.stash.count(KitIds.ROPE) == 1 and climb.stash.count(KitIds.METAL) == 1, "白天存料到攀爬点：%s" % [climb.stash])
	_check(raccoon.item_count(KitIds.WOOD) == 1 and raccoon.inventory.size() == 1, "不在配方的木料留在背包")
	_check(climb.tier_done == 0, "存料不是施工（白天可做）")

	## Stash survives capture and dawn.
	CaptureFlow.apply_capture(raccoon, "测试")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(climb.stash.size() == 2, "被抓、天亮后存料仍在")
	_check(get_tree().get_nodes_in_group(GroundItem.GROUP).size() == 1, "地上的挖掘套件仍在")

	## --- Night: monkey builds from the stash; cancel refunds back into the stash ---
	while _party.controlled() != monkey:
		_party.switch_next()
	await get_tree().process_frame
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	await _stand(monkey, Vector3(2.0, 0.05, 6.0))
	monkey.try_drop()
	_check(not monkey.has_item(KitIds.CLIMB) and get_tree().get_nodes_in_group(GroundItem.GROUP).size() == 2, "离点位远：攀爬套件放到地上")
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
