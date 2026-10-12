extends Node
## 刀 5：职员真实巡逻看到地上物品而收缴 → 办公室柜取回（被收缴≠永久损失）；
## 强行噪音近在职员身边：不当场抓，走起疑 → 预警 → 追捕。正式开局、无临时能力。
## godot --headless --path . res://prototypes/p2_confiscate.tscn

const PATROL_TIMEOUT_SEC := 120.0

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _party: PartyController
var _staff: StaffActor
var _msgs: Array[String] = []


func _ready() -> void:
	print("=== P2 Confiscate ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry")
	_party = _world.get("party")
	_staff = _world.call("get_staff")
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
	_check(_party.party().size() == 2, "正式开局：浣熊出笼并救出猴")
	for a in _party.party():
		if a != raccoon:
			a.order_hold()

	await _patrol_confiscates(raccoon)
	await _chest_retrieval(raccoon)
	await _close_hard_noise(raccoon)

	print("")
	print("=== P2 CONFISCATE SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


## Alert 3: the staff walks its normal patrol, sees the rope on the ground and takes it to the office.
func _patrol_confiscates(raccoon: AnimalActor) -> void:
	await _gather(raccoon, "游客遗落的绳")
	var drop_at := Vector3(-2.0, 0.05, 5.6)
	await _stand(raccoon, drop_at)
	raccoon.try_drop()
	await get_tree().process_frame
	var items := get_tree().get_nodes_in_group(GroundItem.GROUP)
	_check(items.size() == 1 and (items[0] as GroundItem).item_id == KitIds.ROPE, "绳索丢在巡逻路线旁")
	if items.is_empty():
		return
	var item := items[0] as GroundItem
	var start_d := _staff.global_position.distance_to(item.global_position)
	_check(start_d > _staff.vision_range, "职员起点看不到（%.1fm > 视野 %.1fm），要靠巡逻走过去" % [start_d, _staff.vision_range])
	## Both animals wait inside the closed raccoon yard, out of sight.
	for a in _party.party():
		await _stand(a, Vector3(-5.0, 0.05, -7.5) + Vector3(0.8 * float(_party.party().find(a)), 0, 0))
		if a != raccoon:
			a.order_hold()
	Alert.level = 3
	OfficeStorage.items.clear()
	_msgs.clear()
	var path := 0.0
	var last := _staff.global_position
	var t := 0.0
	Engine.time_scale = 4.0
	while is_instance_valid(item) and item.is_in_group(GroundItem.GROUP) and t < PATROL_TIMEOUT_SEC:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		path += _staff.global_position.distance_to(last)
		last = _staff.global_position
	Engine.time_scale = 1.0
	_check(get_tree().get_nodes_in_group(GroundItem.GROUP).is_empty() and OfficeStorage.items == [KitIds.ROPE],
		"职员巡逻 %.0fs（走了 %.1fm）后看到并收走绳索：办公室 %s" % [t, path, OfficeStorage.summary()])
	_check(path >= start_d - _staff.vision_range, "是真的走过去看到的，不是原地")
	_check(_msgs.any(func(m: String) -> bool: return m.contains("收走了地上")), "收缴有提示")
	_check(not _party.party().any(func(a: AnimalActor) -> bool: return a.is_confined), "两只动物都没被发现")
	Alert.level = 0


## Office chest = Interactable rules: raccoon's lockpick is Soft (no noise / trace); takes only what fits.
func _chest_retrieval(raccoon: AnimalActor) -> void:
	var chest := _find_chest()
	_check(chest != null and chest is Interactable and chest.accepted_caps().has(CapabilityIds.Id.DEXTERITY), "办公室柜走 Interactable 规则")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	await _stand(raccoon, chest.global_position + Vector3(2.0, 0.05, 0)) ## at the office wall
	var preview := chest.cost_preview(raccoon)
	_check(preview.contains("Soft") and preview.contains("不留痕迹"), "巧手开柜预览：%s" % preview)
	OfficeStorage.deposit([KitIds.ROUTE, KitIds.WOOD, KitIds.METAL, KitIds.METAL])
	raccoon.inventory.clear()
	raccoon.give_items([KitIds.WOOD])
	_msgs.clear()
	chest.try_use(raccoon)
	await _idle(chest)
	_check(raccoon.inventory.size() == raccoon.inventory_capacity() and raccoon.has_item(KitIds.ROPE) and raccoon.has_item(KitIds.ROUTE),
		"取回被收缴的绳索和套件（背包 %s）" % [raccoon.inventory])
	_check(OfficeStorage.items.size() == 2, "背包满了：剩下的留在柜里，不会消失（%s）" % OfficeStorage.summary())
	_check(get_tree().get_nodes_in_group("traces").is_empty(), "Soft 开柜不留痕迹")
	raccoon.inventory.clear()
	chest.try_use(raccoon)
	await _idle(chest)
	_check(not OfficeStorage.has_items() and raccoon.inventory.size() == 2, "再开一次取走剩下的")
	Clock.set_phase(Clock.Phase.OPEN)


## A Hard tier right next to the staff: no instant capture — suspicion, telegraph, then the normal chase.
func _close_hard_noise(raccoon: AnimalActor) -> void:
	var climb := _geo.climb_interactable
	await _gather(raccoon, "职员工具间")
	await _gather(raccoon, "晾衣架")
	_check(raccoon.has_item(KitIds.METAL) and raccoon.has_item(KitIds.ROPE), "浣熊凑齐攀爬一档（无攀爬才能 → 强行）：%s" % [raccoon.inventory])
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	var work := climb.global_position + Vector3(0, 0.05, 1.0)
	await _stand(raccoon, work)
	_staff.set_physics_process(false)
	_staff.state = StaffActor.State.WORK
	_staff.awareness = 0.0
	_staff.global_position = raccoon.global_position + Vector3(1.2, 0.05, 0)
	_staff._facing = Vector3(1, 0, 0) ## back turned
	Game.work_time_scale = 0.02
	_msgs.clear()
	climb.try_use(raccoon)
	await _idle(climb)
	_check(climb.tier_done == 1 and not raccoon.is_confined, "强行一档完成，没有当场被抓")
	_check(_staff.state == StaffActor.State.SUSPICIOUS and _staff.awareness >= _staff._params.chase_threshold,
		"%.1fm 内的强行噪音：职员直接起疑（追捕带）" % _staff._params.close_noise_chase_range)
	_check(_msgs.any(func(m: String) -> bool: return m.contains("职员转身了")), "提示快跑：%s" % [_msgs])
	_staff.set_physics_process(true)
	var tele := 0.0
	while _staff.state != StaffActor.State.CHASE and tele < 3.0:
		await get_tree().physics_frame
		tele += get_physics_process_delta_time()
	_check(_staff.state == StaffActor.State.CHASE and tele >= _staff._params.min_telegraph_sec - 0.05,
		"预警 %.2fs 后才进入追捕（≥ %.2fs）" % [tele, _staff._params.min_telegraph_sec])


func _find_chest() -> OfficeChest:
	for n in _geo.get_children():
		if n is OfficeChest:
			return n as OfficeChest
	return null


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
