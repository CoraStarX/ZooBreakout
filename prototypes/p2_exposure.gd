extends Node
## Night patrol vs work sites (docs/COST_REFACTOR.md「施工点暴露」), from an official start:
## the real patrol covers each site for exposure_target_min..max of NIGHT_PATROL (vision), no site is ever
## safe or watched for a whole night, quiet / a thrown lure opens a window, and a passing staff member
## reacts through awareness (? → telegraph → chase, ≥0.5 s) — never an instant capture.
## godot --headless --path . res://prototypes/p2_exposure.tscn

const SAMPLE_SEC := 300.0

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _party: PartyController
var _staff: StaffActor
var _raccoon: AnimalActor
var _monkey: AnimalActor


func _ready() -> void:
	print("=== P2 Exposure ===")
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
	_check(RouteWorkCheck.validate().is_empty(), "载入检查：每档有限夜数、存在安全窗口 %s" % [RouteWorkCheck.validate()])
	await _official_start()
	await _measure()
	await _quiet_build()
	await _lure_build()
	await _patrol_spots_builder()
	print("")
	print("=== P2 EXPOSURE SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


## Raccoon opens its cage and the monkey's, then gathers by day: kit, wood ×2 (feed cabinet), metal (tool shed).
func _official_start() -> void:
	var staff_home := _staff.global_position
	_staff.set_physics_process(false)
	_staff.global_position = Vector3(40, 0.05, 40)
	Clock.set_phase(Clock.Phase.OPEN)
	_raccoon = _party.controlled()
	var own: Interactable = _world.call("door_for_animal", _raccoon)
	_stand(_raccoon, own.global_position + Vector3(0, 0, -0.9))
	own.try_use(_raccoon)
	await _idle(own)
	var mdoor: Interactable = _world.get("cage_doors")[&"monkey"]
	_stand(_raccoon, mdoor.global_position + Vector3(-1.1, 0, 0))
	mdoor.try_use(_raccoon)
	await _idle(mdoor)
	for a in _party.party():
		if a != _raccoon:
			_monkey = a
	_check(_monkey != null, "正式开局：浣熊出笼并救出猴")
	_monkey.order_hold()
	_stand(_raccoon, _geo.route_kit_pickup.global_position + Vector3(0.5, 0.05, 0))
	_geo.route_kit_pickup.call("try_use", _raccoon)
	await get_tree().process_frame
	await _gather(_raccoon, "饲料柜")
	await _gather(_raccoon, "职员工具间")
	_check(_raccoon.has_item(KitIds.ROUTE) and _raccoon.item_count(KitIds.WOOD) == 2 and _raccoon.has_item(KitIds.METAL),
		"白天备齐：套件 + 木料×2 + 金属 %s" % [_raccoon.inventory])
	_park(_raccoon)
	_park(_monkey)
	_staff.global_position = staff_home
	_staff.set_physics_process(true)


## Real patrol, nobody around: how much of NIGHT_PATROL each work spot spends in the staff's vision.
func _measure() -> void:
	var ex: RouteExposure = _world.get("exposure")
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	Engine.time_scale = 6.0
	## Steady state: start once the staff has walked from its day spot to the first night post.
	var warm := 0.0
	while warm < 60.0 and not (_staff._dwell_left > 0.0 and _is_night_post(_staff._patrol_point_id)):
		await get_tree().physics_frame
		warm += get_physics_process_delta_time()
	ex.reset()
	var t := 0.0
	var visits: Array[StringName] = []
	while t < SAMPLE_SEC:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if visits.is_empty() or visits.back() != _staff._patrol_point_id:
			visits.append(_staff._patrol_point_id)
	Engine.time_scale = 1.0
	print("  巡逻点序列（%.0fs）：%s" % [SAMPLE_SEC, visits])
	print("  ", ex.debug_text())
	var rw := GameConst.route_work()
	var night := GameConst.NIGHT_PATROL_BASE_SEC
	for s in ex.sites:
		_check(s.ratio() >= rw.exposure_target_min and s.ratio() <= rw.exposure_target_max,
			"%s 视野暴露 %.0f%%（目标 %.0f–%.0f%%）" % [s.label, s.ratio() * 100.0, rw.exposure_target_min * 100.0, rw.exposure_target_max * 100.0])
		_check(s.longest_seen < night and s.longest_window() < night,
			"%s 不会整段夜巡都被盯或都没人看（最长被看 %.1fs、最长窗口 %.1fs < 夜巡 %.0fs）" % [s.label, s.longest_seen, s.longest_window(), night])
		_check(s.mean_window() >= GameConst.TIER_SOFT_SEC,
			"%s 平均窗口 %.1fs ≥ 一档 Soft %.0fs（窗口内做得完一档）" % [s.label, s.mean_window(), GameConst.TIER_SOFT_SEC])
	var dig := ex.sites[0]
	var climb := ex.sites[1]
	_check(absf(dig.ratio() - climb.ratio()) >= 0.02, "两条线暴露不同（挖 %.0f%% / 爬 %.0f%%）" % [dig.ratio() * 100.0, climb.ratio() * 100.0])


## Quiet window: the staff rests, a whole Soft tier goes through unseen.
func _quiet_build() -> void:
	var dig := _geo.dig_interactable
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	await get_tree().physics_frame
	Game.work_time_scale = 0.3
	_stand(_raccoon, dig.work_spot())
	dig.try_use(_raccoon)
	var worst := 0.0
	while dig._busy:
		await get_tree().physics_frame
		worst = maxf(worst, _staff.awareness)
	_check(dig.tier_done == 1 and _staff.state == StaffActor.State.REST and worst == 0.0,
		"歇岗中施工：第 1 档做完，职员一直在歇（awareness 峰值 %.0f）" % worst)
	_park(_raccoon)
	Game.work_time_scale = 1.0


## The staff stares at the dig; the monkey's stone lands behind it, it goes to look → the raccoon builds.
func _lure_build() -> void:
	var dig := _geo.dig_interactable
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	await _wait_dwell_at(&"dig_post", 6.0)
	_check(_staff._patrol_point_id == &"dig_post" and _staff.sees_point(dig.work_spot()), "职员在挖洞岗盯着施工点")
	while _party.controlled() != _monkey:
		_party.switch_next()
	await get_tree().process_frame
	_stand(_monkey, _geo.climb_interactable.work_spot())
	_monkey._facing = Vector3(-1, 0, 0)
	_check(_monkey.try_throw(), "猴在攀爬点往西丢石子（落点 %s）" % _monkey.throw_landing_point())
	await get_tree().create_timer(GameConst.action_cost().throw_flight_sec + 0.1).timeout
	_park(_monkey)
	_check(_staff.state == StaffActor.State.INVESTIGATE and not _staff.sees_point(dig.work_spot()),
		"职员被声响引去西南角查看，背对挖洞点")
	Game.work_time_scale = 0.3
	_stand(_raccoon, dig.work_spot())
	dig.try_use(_raccoon)
	var chased := false
	while dig._busy:
		await get_tree().physics_frame
		chased = chased or _staff.state == StaffActor.State.CHASE
	_check(dig.tier_done == 2 and not chased and not _raccoon.is_confined, "引开后施工：第 2 档做完、没被追")
	_park(_raccoon)
	Game.work_time_scale = 1.0


## Real patrol walks to the dig post while the raccoon works: it notices, but only through awareness.
func _patrol_spots_builder() -> void:
	var dig := _geo.dig_interactable
	await _wait_dwell_at(&"climb_post", 0.0)
	while _staff._patrol_point_id == &"climb_post" and _staff._dwell_left > 2.0:
		await get_tree().physics_frame
	_stand(_raccoon, dig.work_spot())
	dig.try_use(_raccoon)
	var t := 0.0
	var first_seen := -1.0
	var states: Array[String] = []
	var icons: Array[String] = []
	var caught_at := -1.0
	var chase_at := -1.0
	while t < 25.0 and caught_at < 0.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if first_seen < 0.0 and _staff._seeing:
			first_seen = t
		if states.is_empty() or states.back() != _staff.state_name():
			states.append(_staff.state_name())
		var icon := _staff.head_icon()
		if icon != "" and (icons.is_empty() or icons.back() != icon):
			icons.append(icon)
		if chase_at < 0.0 and _staff.state == StaffActor.State.CHASE:
			chase_at = t
		if _raccoon.is_confined:
			caught_at = t
	print("  状态序列：%s  头标：%s  首次看见 %.2fs  追捕 %.2fs  被抓 %.2fs" % [states, icons, first_seen, chase_at, caught_at])
	_check(first_seen >= 0.0, "巡逻实际走到挖洞岗时看见施工中的浣熊")
	_check(icons.size() >= 1 and icons[0] == "?", "先起疑（头上 ?）：%s" % [icons])
	_check(chase_at < 0.0 or chase_at - first_seen >= 0.5, "看见到追捕 ≥0.5s（%.2fs）" % (chase_at - first_seen if chase_at >= 0.0 else INF))
	_check(caught_at < 0.0 or caught_at - first_seen >= 0.5, "没有看见即抓（被抓 %.2fs 后）" % (caught_at - first_seen if caught_at >= 0.0 else INF))


func _wait_dwell_at(id: StringName, min_left: float) -> void:
	var t := 0.0
	while t < 120.0 and not (_staff._patrol_point_id == id and _staff._dwell_left > min_left and _staff.state == StaffActor.State.WORK):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _is_night_post(id: StringName) -> bool:
	var p := _staff.patrol_network.find(id)
	return p != null and p.shift == PatrolPointData.Shift.NIGHT


## Out of the yard and out of everyone's sight.
func _park(a: AnimalActor) -> void:
	_stand(a, Vector3(40, 0.05, 40))


func _stand(a: AnimalActor, pos: Vector3) -> void:
	a.is_confined = false
	a.global_position = pos
	a.velocity = Vector3.ZERO
	a._hold_position = pos


func _gather(a: AnimalActor, point_name: String) -> void:
	for g in _geo.gather_points:
		if g.display_name != point_name:
			continue
		_stand(a, g.global_position + Vector3(0.6, 0.05, 0))
		g.try_use(a)
		await get_tree().process_frame
		var t := 0.0
		while g._busy and t < 6.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		return
	_check(false, "找不到搜集点 %s" % point_name)


func _idle(it: Interactable) -> void:
	await get_tree().process_frame
	var t := 0.0
	while it._busy and t < 6.0:
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
