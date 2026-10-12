extends Node
## 刀 2：allow_hard、Hard 倍率、痕迹单次结算、背包/重物、无职员噪音不升 Alert。
## godot --headless --path . res://prototypes/p2_action_cost.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Action Cost ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var geo: ZooP0Geometry = world.get_node("Geometry")
	var party: PartyController = world.get("party")
	party.rescue(&"monkey", false)
	await get_tree().process_frame
	var raccoon: AnimalActor = party.controlled()
	var monkey: AnimalActor = null
	for a in party.party():
		if a != raccoon:
			monkey = a
	var dig := geo.dig_interactable
	var door: Interactable = geo.cage_doors[&"raccoon"]
	var staff: StaffActor = world.call("get_staff")
	staff.set_physics_process(false)
	staff.global_position = Vector3(40, 0.05, 40) ## far — out of all hear ranges

	_check(raccoon.inventory_capacity() == 4, "浣熊背包容量 4")
	_check(monkey.inventory_capacity() == 2, "猴子背包容量 2")
	_check(not door.allow_hard, "笼门锁 allow_hard=false")

	## Capacity refuse.
	raccoon.inventory.clear()
	raccoon.give_items([KitIds.WOOD, KitIds.WOOD, KitIds.WOOD, KitIds.ROPE])
	_check(raccoon.inventory.size() == 4, "装满 4 格")
	var got := raccoon.give_items([KitIds.METAL])
	_check(got == 0 and raccoon.item_count(KitIds.METAL) == 0, "满包拒收金属")

	## Heavy comes from ItemDef data: only kits; raw materials are light.
	for id in [KitIds.ROPE, KitIds.WOOD, KitIds.METAL]:
		_check(KitIds.def_for(id) != null and not KitIds.is_heavy(id), "%s 有 ItemDef 且不是重物" % KitIds.display_name(id))
		monkey.inventory.clear()
		monkey.give_items([id])
		_check(is_equal_approx(monkey.current_move_speed(), monkey.def.move_speed)
			and monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "带%s：移速与攀爬不受影响" % KitIds.display_name(id))
	for id in [KitIds.ROUTE, KitIds.ROUTE]:
		_check(KitIds.is_heavy(id), "%s 标记为重物" % KitIds.display_name(id))
		monkey.inventory.clear()
		monkey.give_items([id])
		_check(is_equal_approx(monkey.current_move_speed(), monkey.def.move_speed * GameConst.action_cost().heavy_speed_mult)
			and not monkey.effective_has_capability(CapabilityIds.Id.CLIMB), "带%s：移速 ×0.6 且禁用攀爬" % KitIds.display_name(id))
	_check(monkey.has_capability(CapabilityIds.Id.CLIMB), "猴本身仍有攀爬动词")
	monkey.inventory.clear()

	## Cage lock: no Hard. The monkey has no lockpick.
	monkey.order_hold()
	door.relock()
	door._done = false
	_stand(monkey, door)
	monkey._hold_position = monkey.global_position
	Clock.set_phase(Clock.Phase.OPEN)
	door.try_use(monkey)
	await get_tree().process_frame
	_check(not door._done and not door._busy, "猴无巧手且 allow_hard=false → 拒绝开浣熊笼")

	## Monkey cage needs the rescuer's lockpick, not the monkey's climb.
	var mdoor: Interactable = geo.cage_doors[&"monkey"]
	_check(mdoor.required == CapabilityIds.Id.DEXTERITY and not mdoor.allow_hard, "猴笼 = 开锁（巧手）且禁止强行")
	_check(mdoor._qualifies(raccoon, true), "浣熊（巧手）可 Soft 开猴笼")
	_check(not mdoor.can_be_opened_by(monkey.def) and not mdoor._qualifies(monkey, true), "猴自己打不开猴笼")

	## Noise with no staff nearby must not raise Alert.
	Alert.level = 0
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	Bus.noise_made.emit(dig.global_position, 1.5, &"interact_hard")
	await get_tree().process_frame
	_check(Alert.level == 0, "无员工在场：噪音不升 Alert")

	## Hard mid-tier (raccoon has no climb): time mult, trace spawn, still no Alert from noise alone.
	var climb := geo.climb_interactable
	Game.work_time_scale = 0.08
	raccoon.inventory.clear()
	raccoon.give_items([KitIds.ROPE, KitIds.METAL])
	_stand(raccoon, climb)
	var alert_before := Alert.level
	var t0 := Time.get_ticks_msec()
	climb.try_use(raccoon)
	await _idle(climb)
	var hard_ms := Time.get_ticks_msec() - t0
	var expect_ms := int(GameConst.TIER_HARD_SEC * GameConst.route_work().hard_time_mult * Game.work_time_scale * 1000.0 * 0.75)
	_check(climb.tier_done == 1, "Hard 完成第 1 档")
	_check(hard_ms >= expect_ms, "Hard 含时×3（%dms ≥ %dms）" % [hard_ms, expect_ms])
	_check(Alert.level == alert_before, "Hard 噪音/完工不直接升 Alert（%d）" % Alert.level)
	var traces := get_tree().get_nodes_in_group("traces")
	_check(traces.size() >= 1, "Hard 留下痕迹")
	var tr: TraceMarker = traces[0] as TraceMarker
	_check(tr != null and not tr.settled and tr.intensity >= 2.0 - 0.01, "痕迹未结算且强度含×2")

	## Same trace settles Alert once.
	staff.global_position = tr.global_position
	staff.set_physics_process(true)
	staff.state = StaffActor.State.WORK
	for _i in 30:
		await get_tree().physics_frame
	_check(tr.settled, "职员靠近后痕迹已结算")
	_check(Alert.level == alert_before + 1, "发现痕迹 Alert +1 → %d" % Alert.level)
	var lvl := Alert.level
	staff.global_position = tr.global_position
	for _i in 20:
		await get_tree().physics_frame
	_check(Alert.level == lvl, "同一痕迹不再重复升 Alert")
	staff.set_physics_process(false)
	staff.global_position = Vector3(40, 0.05, 40)

	## Last tier forbids Hard: raccoon (no climb) is refused at the climb line.
	climb.tier_done = GameConst.ROUTE_TIERS - 1
	raccoon.inventory.clear()
	raccoon.give_items([KitIds.ROPE, KitIds.METAL])
	_stand(raccoon, climb)
	climb.try_use(raccoon)
	await get_tree().process_frame
	_check(climb.tier_done == GameConst.ROUTE_TIERS - 1 and not climb._busy, "攀爬线最后一档：浣熊无攀爬 → 拒绝强行")

	## Dig line takes squeeze or lockpick; DIG stays reserved for the badger.
	for it in [dig, climb]:
		_check(not (it as Interactable).accepted_caps().has(CapabilityIds.Id.DIG), "%s 不要求挖掘" % (it as Interactable).display_name)
	_check(dig.accepted_caps().has(CapabilityIds.Id.SQUEEZE) and dig.accepted_caps().has(CapabilityIds.Id.DEXTERITY), "挖洞线 = 钻缝或巧手")
	_check(not dig._qualifies(monkey, true), "猴（只有攀爬）在挖洞线不算 Soft")
	monkey.order_hold()
	monkey.inventory.clear()
	monkey.give_items([KitIds.WOOD, KitIds.METAL])
	dig.tier_done = GameConst.ROUTE_TIERS - 1
	_stand(monkey, dig)
	monkey._hold_position = monkey.global_position
	dig.try_use(monkey)
	await get_tree().process_frame
	_check(dig.tier_done == GameConst.ROUTE_TIERS - 1 and not dig._busy, "挖洞线最后一档：猴无钻缝/巧手 → 拒绝强行")
	monkey.inventory.clear()
	raccoon.inventory.clear()
	raccoon.give_items([KitIds.WOOD, KitIds.METAL])
	_stand(raccoon, dig)
	var traces_before := get_tree().get_nodes_in_group("traces").size()
	dig.try_use(raccoon)
	await _idle(dig)
	_check(dig.tier_done == GameConst.ROUTE_TIERS and dig._done, "浣熊（巧手）Soft 完成挖洞线最后一档")
	_check(get_tree().get_nodes_in_group("traces").size() == traces_before, "Soft 不留痕迹")

	print("")
	print("=== P2 ACTION COST SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _stand(a: AnimalActor, it: Node3D) -> void:
	a.is_confined = false
	a.global_position = it.global_position + Vector3(0.9, 0.05, 0.4)
	a.velocity = Vector3.ZERO


func _idle(it: Interactable) -> void:
	await get_tree().process_frame
	var t := 0.0
	while it._busy and t < 12.0:
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
