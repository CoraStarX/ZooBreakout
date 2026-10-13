extends Node
## 昼夜 M3：白天原料点（三种原料、动词门槛、整局一次 / 可重复翻找）。预算断言在 p2_full_loop。
## godot --headless --path . res://prototypes/p2_gather.tscn

const Gather := preload("res://content/levels/zoo_p0_gather.gd")

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _party: PartyController
var _session: RunSession


func _ready() -> void:
	print("=== P2 Gather ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry") as ZooP0Geometry
	_party = _world.get("party")
	_session = _world.get("session")
	var actor := _party.controlled()
	actor.inventory.clear()

	_check(_geo.gather_points.size() == Gather.POINTS.size(), "关卡生成 %d 个搜集点" % _geo.gather_points.size())
	_check_points_not_in_walls()

	var cabinet := _find_point("饲料柜")   ## raccoon has DEXTERITY, the monkey does not
	var trash := _find_point("垃圾桶（铁罐）")
	_check(cabinet != null and trash != null, "找到动词点与垃圾桶")
	for g in _geo.gather_points:
		var want := GatherPoint.RefreshMode.REPEATABLE if g == trash else GatherPoint.RefreshMode.ONCE
		_check(g.refresh_mode == want, "%s 刷新模式 %s" % [g.display_name, GatherPoint.RefreshMode.keys()[g.refresh_mode]])
	_check(_find_point("职员工具间").yield_rich == 1, "职员工具间金属 ×1")
	_party.rescue(&"monkey", false)
	await get_tree().process_frame
	var monkey: AnimalActor = null
	for a in _party.party():
		if a != actor:
			monkey = a
	monkey.order_hold()

	## Poor: no verb → takes one, slower; the rest stays at the point.
	var t0 := Time.get_ticks_msec()
	await _use(monkey, cabinet)
	var poor_ms := Time.get_ticks_msec() - t0
	_check(monkey.item_count(KitIds.WOOD) == 1, "无动词只拿 1 木料（实际 %d）" % monkey.item_count(KitIds.WOOD))
	_check(poor_ms >= int(GameConst.GATHER_POOR_SEC * 1000.0 * 0.8), "无动词更慢 %dms" % poor_ms)
	_check(cabinet.stocked and cabinet.stock == 1, "没拿走的 1 件留在原处（剩 %d）" % cabinet.stock)

	## Dawn: once points never restock; what was left stays.
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(cabinet.stock == 1, "天亮不补货，剩下的仍在（剩 %d）" % cabinet.stock)

	## Night blocks gathering.
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	await _use(actor, cabinet)
	_check(actor.item_count(KitIds.WOOD) == 0 and cabinet.stock == 1, "夜间不能搜集")
	Clock.set_phase(Clock.Phase.OPEN)

	## Rich: the raccoon has the verb, but only what is left can be taken; then the point is empty for good.
	await _use(actor, cabinet)
	_check(actor.item_count(KitIds.WOOD) == 1, "有动词也只能拿剩下的 1 木料（实际 %d）" % actor.item_count(KitIds.WOOD))
	_check(not cabinet.stocked and cabinet._label.text.contains("已搜空"), "搜空后标记「已搜空」：%s" % cabinet._label.text)
	await _use(actor, cabinet)
	_check(actor.item_count(KitIds.WOOD) == 1, "已搜空不能重复拿")
	var wood_total := 0
	var rope_total := 0
	for g in _geo.gather_points:
		if g.material == KitIds.WOOD:
			wood_total += g.once_supply()
		elif g.material == KitIds.ROPE:
			rope_total += g.once_supply()
	_check(wood_total == 2 and rope_total == 2, "全图木料 %d、绳索 %d（各 2）" % [wood_total, rope_total])

	## Repeatable trash bin: loud every time, may be empty, pity bounds bad luck, one find per day.
	await _check_trash(actor, trash)

	## Day: route points refuse construction (night only), parts untouched.
	actor.inventory.clear()
	actor.give_items([KitIds.WOOD, KitIds.WOOD])
	var dig := _geo.dig_interactable
	actor.global_position = dig.global_position + Vector3(0.9, 0, 0)
	dig.try_use(actor)
	await get_tree().process_frame
	_check(dig.tier_done == 0 and actor.item_count(KitIds.WOOD) == 2, "白天不能在外墙施工")

	## Capture confiscates parts, chest returns them.
	actor.give_items([KitIds.WOOD, KitIds.WOOD])
	CaptureFlow.apply_capture(actor)
	_check(actor.item_count(KitIds.WOOD) == 0 and OfficeStorage.items.count(KitIds.WOOD) == 4, "被抓木料进办公室（背包 %s 办公室 %s）" % [actor.inventory, OfficeStorage.summary()])

	print("")
	print("=== P2 GATHER SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _find_point(point_name: String) -> GatherPoint:
	for g in _geo.gather_points:
		if g.display_name == point_name:
			return g
	return null


func _check_trash(actor: AnimalActor, trash: GatherPoint) -> void:
	var cost := GameConst.action_cost()
	## The rummage is loud on purpose; keep the patrol away so this checks only the point's rules.
	var staff: StaffActor = _world.call("get_staff")
	staff.set_physics_process(false)
	staff.global_position = Vector3(40, 0.05, 40)
	actor.inventory.clear()
	var noises: Array = []
	var on_noise := func(_p: Vector3, amt: float, kind: StringName) -> void:
		if kind == &"gather":
			noises.append(amt)
	Bus.noise_made.connect(on_noise)
	for seed_try in 3:
		trash.rng.seed = 7 + seed_try
		var tries := 0
		while trash.stocked and tries < cost.gather_repeat_pity + 2:
			await _use(actor, trash, cost.gather_repeat_sec + 2.0)
			tries += 1
		_check(actor.item_count(KitIds.METAL) == seed_try + 1, "第 %d 天翻到金属（翻了 %d 次）" % [seed_try + 1, tries])
		_check(tries <= cost.gather_repeat_pity + 1, "连续空手 %d 次后必有：%d 次内翻到" % [cost.gather_repeat_pity, tries])
		_check(noises.size() >= tries, "每次翻找都有噪音（%d 次）" % noises.size())
		var have := actor.item_count(KitIds.METAL)
		await _use(actor, trash, cost.gather_repeat_sec + 2.0)
		_check(actor.item_count(KitIds.METAL) == have and trash._label.text.contains("明早"), "当天上限 %d：%s" % [
			cost.gather_repeat_daily_cap, trash._label.text
		])
		noises.clear()
		Clock.set_phase(Clock.Phase.NIGHT_QUIET)
		Clock.advance()
		Clock.set_phase(Clock.Phase.OPEN)
		_check(trash.stocked, "第 %d 天天亮可再翻" % (seed_try + 2))
	Bus.noise_made.disconnect(on_noise)


func _use(actor: AnimalActor, g: GatherPoint, limit: float = 6.0) -> void:
	actor.is_confined = false
	actor.global_position = g.global_position + Vector3(0.6, 0.05, 0)
	actor.velocity = Vector3.ZERO
	actor._hold_position = actor.global_position ## a held follower would walk back out of range
	g.try_use(actor)
	var t := 0.0
	while g._busy and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame


func _wait_idle(it: Interactable) -> void:
	var t := 0.0
	await get_tree().process_frame
	while it._busy and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame


func _check_points_not_in_walls() -> void:
	var space := _world.get_world_3d().direct_space_state
	var bad := PackedStringArray()
	for g in _geo.gather_points:
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.5
		q.shape = s
		q.transform = Transform3D(Basis(), g.global_position + Vector3(0, 0.6, 0))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			bad.append(g.display_name)
	_check(bad.is_empty(), "搜集点不嵌墙 %s" % ",".join(bad))


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
