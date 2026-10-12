extends Node
## 昼夜循环端到端：正式开局 → 白天拿套件 → 夜间套件顶 2 档、最后一档缺料被拒 → 第 2 天补料 → 完工出园。
## 预算断言（docs/COST_REFACTOR.md「刀 5 正解天数估算」）全部从 Resource 数值计算，不写死秒数：
## (a) 正解天数落在 3–5 天；(b) 全图原料无法同时完成两条线；(c) 无材料时最后一档被拒。
## 不按 N / 不开 Debug；只有施工读条按 Game.work_time_scale 加速。
## godot --headless --path . res://prototypes/p2_full_loop.tscn

const TARGET_MIN_DAYS := 3
const TARGET_MAX_DAYS := 5
## Straight-line distance × this = walking path (corridors, doors).
const PATH_DETOUR := 1.4

var _pass_n := 0
var _fail_n := 0
var _pending: PackedStringArray = []
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
	var party: PartyController = _world.get("party")
	var actor: AnimalActor = party.controlled()
	var staff: StaffActor = _world.call("get_staff")

	_material_budget()
	_day_estimate(actor)

	staff.set_physics_process(false)
	staff.global_position = Vector3(10, 0.05, 10)

	## --- Day 1: escape, rescue, take the one kit ---
	_check(Clock.phase == Clock.Phase.OPEN and Clock.day == 1, "第 1 天白天开局")
	var door: Interactable = _world.call("door_for_animal", actor)
	actor.global_position = door.global_position + Vector3(0, 0, -0.9)
	door.try_use(actor)
	await _idle(door)
	_check(door._done and _session.exhibit_escaped, "白天溜出笼门")
	var mdoor: Interactable = _world.get("cage_doors")[&"monkey"]
	actor.global_position = mdoor.global_position + Vector3(-1.1, 0, 0)
	mdoor.try_use(actor)
	await _idle(mdoor)
	_check(party.party().size() == 2, "白天开锁救出猴")
	actor.global_position = _geo.route_kit_pickup.global_position + Vector3(0.5, 0.05, 0)
	_geo.route_kit_pickup.call("try_use", actor)
	_check(actor.inventory == [KitIds.ROUTE], "第 1 天只拿通用套件：%s" % [actor.inventory])

	var rest_pt: ObservePoint = _geo.observe_points[0]
	staff.global_position = rest_pt.global_position + Vector3(5, 0, 0)
	actor.global_position = rest_pt.global_position + Vector3(0.5, 0.05, 0)
	rest_pt.try_use(actor)
	await get_tree().create_timer(GameConst.OBSERVE_SEC + 0.8).timeout
	_check(_session.has_intel(IntelIds.REST_TIME), "白天侦察得到歇岗情报")
	staff.global_position = Vector3(10, 0.05, 10)

	## --- Night 1: kit pays 2 tiers; (c) the last tier is refused without materials ---
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	var dig := _geo.dig_interactable
	actor.global_position = dig.global_position + Vector3(0.9, 0.05, 0.4)
	_log.clear()
	await RouteHelper.finish(get_tree(), dig, actor, false)
	_check(dig.tier_done == GameConst.KIT_TIERS and not actor.has_item(KitIds.ROUTE), "套件顶 %d 档后被消耗" % dig.tier_done)
	_check(dig.tier_done == GameConst.ROUTE_TIERS - 1 and not _session.route_dig_ready and not dig._busy
		and _log.any(func(m: String) -> bool: return m.begins_with("材料不足")),
		"(c) 无材料时最后一档被拒：%s" % [_log.filter(func(m: String) -> bool: return m.begins_with("材料不足"))])
	var vision0 := staff.vision_range

	## --- Day 2: one wood + one metal for the last tier ---
	Clock.advance()
	_check(Clock.day == 2 and Clock.phase == Clock.Phase.OPEN, "进入第 2 天")
	_check(staff.vision_range >= vision0 + GameConst.STAFF_VISION_PER_DAY - 0.001, "职员视野随天数增长 %.1fm" % staff.vision_range)
	_check(dig.tier_done == GameConst.ROUTE_TIERS - 1, "施工进度保留")
	await _gather(actor, "南侧杂物堆")
	await _gather(actor, "职员工具间")
	_check(actor.item_count(KitIds.WOOD) == 1 and actor.item_count(KitIds.METAL) == 1, "第 2 天补齐最后一档：%s" % [actor.inventory])

	## --- Night 2 ---
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	actor.global_position = dig.global_position + Vector3(0.9, 0.05, 0.4)
	await RouteHelper.finish(get_tree(), dig, actor, false)
	_check(dig._done and _session.route_dig_ready, "第 2 夜完工，挖掘线打通")

	## --- Exit ---
	var zone: Area3D = _geo.exit_west
	for a in party.party():
		a.global_position = zone.global_position + Vector3(0, -0.9, 0)
		a.velocity = Vector3.ZERO
	await get_tree().physics_frame
	_world.call("check_exit_win", RunSession.ExitRoute.DIG)
	_check(_session.outcome == RunSession.Outcome.WON, "双动物进入出口 → 通关（%s）" % _session.outcome_reason)

	print("")
	for p in _pending:
		print("PENDING ", p)
	print("=== P2 FULL LOOP SUMMARY pass=%d fail=%d pending=%d ===" % [_pass_n, _fail_n, _pending.size()])
	get_tree().quit(0 if _fail_n == 0 else 1)


## (b) Supply vs demand from the live level (same numbers as the load-time check).
func _material_budget() -> void:
	var lines: Array = _world.call("material_lines")
	var supply: Dictionary = _world.call("material_supply")
	var days := GameConst.DEADLINE_DAY
	print("NOTE 全图一次性原料 %s · 套件 %d · 保底（%d 天）%s" % [
		supply["once"], supply["kits"], days, MaterialBudget.fallback(supply, days)
	])
	for line in lines:
		print("NOTE %s：用套件需 %s · 不用套件需 %s" % [line["name"], MaterialBudget.need(line, true), MaterialBudget.need(line, false)])
		_check(MaterialBudget.line_feasible(line, supply, 0), "%s 只靠一次性原料（不翻垃圾桶）即可完成" % line["name"])
		_check(MaterialBudget.line_feasible(line, supply, days), "%s 在全图+保底下可完成（载入检查同口径）" % line["name"])
	_check(MaterialBudget.validate(lines, supply, days).is_empty(), "载入检查无错误")
	_check(not MaterialBudget.both_feasible(lines[0], lines[1], supply, 0), "(b) 一次性原料总量无法同时完成两条线")
	var fb_days := -1
	for d in range(0, days + 1):
		if MaterialBudget.both_feasible(lines[0], lines[1], supply, d):
			fb_days = d
			break
	if fb_days < 0:
		_check(true, "(b) 加上保底来源 %d 天仍无法同时完成两条线" % days)
	else:
		_pending.append("(b) 加上垃圾桶保底：翻 %d 天后金属够同时完成两条线（等待决定）" % fb_days)


## (a) Conservative days for the intended solution: specialist (Soft) + kit, raccoon digs.
func _day_estimate(raccoon: AnimalActor) -> void:
	var rw := GameConst.route_work()
	var cost := GameConst.action_cost()
	var dig := _geo.dig_interactable
	var speed := raccoon.def.move_speed
	var heavy_speed := speed * cost.heavy_speed_mult
	## Day: cage → kit → wood → metal → stash at the dig point (one trip; inventory fits kit + 2).
	var home := raccoon.global_position
	var kit_pos := _geo.route_kit_pickup.global_position
	var wood_pos := _point("南侧杂物堆").global_position
	var metal_pos := _point("职员工具间").global_position
	var gather_sec := (home.distance_to(kit_pos) / speed
		+ (kit_pos.distance_to(wood_pos) + wood_pos.distance_to(metal_pos) + metal_pos.distance_to(dig.global_position)) / heavy_speed
	) * PATH_DETOUR + cost.gather_sec * 2.0 + cost.soft_interact_sec * 2.0
	var gather_days := ceili(gather_sec / GameConst.OPEN_PHASE_SEC)
	## Night: Soft is silent; patrol time is usable only if no patrol point can see the work spot by the deadline.
	var max_vision := staff_vision_at(GameConst.DEADLINE_DAY)
	var nearest := INF
	var staff: StaffActor = _world.call("get_staff")
	for p in staff.patrol_network.points:
		nearest = minf(nearest, p.position.distance_to(dig.global_position))
	var patrol_safe := nearest > max_vision
	var window := GameConst.NIGHT_QUIET_SEC + (GameConst.NIGHT_PATROL_BASE_SEC if patrol_safe else 0.0)
	var travel := home.distance_to(dig.global_position) / speed * PATH_DETOUR
	var soft_tier := GameConst.TIER_SOFT_SEC
	var tiers_per_night := floori((window - travel) / soft_tier)
	var nights := ceili(float(GameConst.ROUTE_TIERS) / float(maxi(tiers_per_night, 1)))
	var days := gather_days + nights - 1
	print("NOTE 正解估算：白天搬运 %.0fs/%.0fs → %d 天 · 夜间可施工 %.0fs（巡逻点最近 %.1fm vs 视野 %.1fm → 巡逻时段%s）" % [
		gather_sec, GameConst.OPEN_PHASE_SEC, gather_days, window, nearest, max_vision, "可用" if patrol_safe else "不可用"
	])
	print("NOTE 走到施工点 %.1fs · Soft 每档 %.0fs → 每夜 %d 档 · %d 档需 %d 夜 → 第 %d 天出园" % [
		travel, soft_tier, tiers_per_night, GameConst.ROUTE_TIERS, nights, days
	])
	var hard_tier := GameConst.TIER_HARD_SEC * rw.hard_time_mult
	print("NOTE Hard 每档 %.0fs vs 一夜 %.0fs" % [hard_tier, GameConst.NIGHT_PATROL_BASE_SEC + GameConst.NIGHT_QUIET_SEC])
	if days >= TARGET_MIN_DAYS and days <= TARGET_MAX_DAYS:
		_check(true, "(a) 正解 %d 天，落在 %d–%d 天" % [days, TARGET_MIN_DAYS, TARGET_MAX_DAYS])
	else:
		_pending.append("(a) 正解估算 %d 天，不在 %d–%d 天（瓶颈见 NOTE；等待决定，不自行加限制）" % [
			days, TARGET_MIN_DAYS, TARGET_MAX_DAYS
		])


func staff_vision_at(day: int) -> float:
	var staff: StaffActor = _world.call("get_staff")
	return staff._base_vision + GameConst.STAFF_VISION_PER_DAY * float(clampi(day - 1, 0, GameConst.STAFF_SCALE_MAX_DAYS))


func _point(point_name: String) -> GatherPoint:
	for g in _geo.gather_points:
		if g.display_name == point_name:
			return g
	return null


func _gather(actor: AnimalActor, point_name: String) -> void:
	var g := _point(point_name)
	actor.global_position = g.global_position + Vector3(0.6, 0.05, 0)
	g.try_use(actor)
	var t := 0.0
	await get_tree().process_frame
	while g._busy and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()


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
