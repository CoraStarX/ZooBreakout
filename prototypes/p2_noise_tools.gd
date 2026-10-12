extends Node
## 刀 4：叫嚷每日上限、猴投掷（T、冷却 8s、落点发声）、Gather B 接口。正式开局、无临时能力。
## godot --headless --path . res://prototypes/p2_noise_tools.tscn

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _party: PartyController
var _staff: StaffActor
var _session: RunSession
var _msgs: Array[String] = []
var _noises: Array = []


func _ready() -> void:
	print("=== P2 Noise Tools ===")
	Game.debug_enabled = false
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry")
	_party = _world.get("party")
	_session = _world.get("session")
	_staff = _world.call("get_staff")
	_staff.set_physics_process(false)
	_staff.global_position = Vector3(40, 0.05, 40)
	Bus.interact_feedback.connect(func(m: String) -> void: _msgs.append(m))
	Bus.noise_made.connect(func(p: Vector3, l: float, k: StringName) -> void: _noises.append([p, l, k]))
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

	await _shout_budget(raccoon, monkey)
	await _throw(raccoon, monkey)
	await _gather_b(raccoon)

	print("")
	print("=== P2 NOISE TOOLS SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


## 4 shouts a day for the whole party; cooldown refusals do not spend one; dawn refills.
func _shout_budget(raccoon: AnimalActor, monkey: AnimalActor) -> void:
	var limit := GameConst.day_cycle().shout_daily_limit
	_check(limit == 4 and _session.shouts_left() == 4, "每日叫嚷上限 4（DayCycleParams）")
	await _stand(raccoon, Vector3(-3.0, 0.05, 3.0))
	_noises.clear()
	var ok := raccoon.try_make_noise()
	var again := raccoon.try_make_noise()
	_check(ok and not again and _session.shouts_left() == 3, "冷却中再按被拒且不扣次数（剩 %d）" % _session.shouts_left())
	## Skip the 6 s cooldown between presses (timing only; the budget is what is under test).
	for i in 2:
		raccoon._shout_cooldown = 0.0
		raccoon.try_make_noise()
	_party.switch_next()
	await get_tree().process_frame
	monkey._shout_cooldown = 0.0
	_check(monkey.try_make_noise() and _session.shouts_left() == 0, "次数全队共用：猴叫第 4 次后剩 0")
	monkey._shout_cooldown = 0.0
	_msgs.clear()
	_check(not monkey.try_make_noise(), "第 5 次叫不出来")
	_check(_msgs.any(func(m: String) -> bool: return m.contains("嗓子哑了")), "提示「嗓子哑了」：%s" % [_msgs])
	var shouts := _noises.filter(func(n: Array) -> bool: return n[2] == &"shout").size()
	_check(shouts == 4, "实际只发出 4 次叫声（%d）" % shouts)
	_check(monkey.noise_tools_line().contains("0/4") and monkey.noise_tools_line().contains("嗓子哑了"), "HUD 行：%s" % monkey.noise_tools_line())
	_check(Alert.level == 0, "叫嚷不计警戒")
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(Clock.day == 2 and _session.shouts_left() == 4, "天亮恢复 4 次")
	Clock.set_phase(Clock.Phase.OPEN)


## Monkey throws; the noise is at the landing spot; staff investigate there; raccoon cannot throw.
func _throw(raccoon: AnimalActor, monkey: AnimalActor) -> void:
	_check(monkey.def.has_capability(CapabilityIds.Id.THROW) and not raccoon.def.has_capability(CapabilityIds.Id.THROW),
		"投掷＝猴（正式 AnimalDef），浣熊没有")
	while _party.controlled() != raccoon:
		_party.switch_next()
	await get_tree().process_frame
	_msgs.clear()
	_check(not raccoon.try_throw() and _msgs.any(func(m: String) -> bool: return m.contains("不会投掷")), "浣熊按 T：不会投掷")
	_party.switch_next()
	await get_tree().process_frame
	_check(_party.controlled() == monkey, "换控到猴")
	await _stand(monkey, Vector3(2.0, 0.05, 6.0))
	monkey._facing = Vector3(1, 0, 0)
	var land := monkey.throw_landing_point()
	var reach := Vector2(land.x - monkey.global_position.x, land.z - monkey.global_position.z).length()
	_check(absf(reach - GameConst.action_cost().throw_range) < 0.05, "空旷处落点 = 前方 %.1fm" % reach)
	## Staff out of earshot of the monkey but near the landing spot.
	_staff.global_position = land + Vector3(4.0, 0, 0)
	var hear := _staff._params.hear_noise_range * GameConst.action_cost().throw_loudness
	_check(monkey.global_position.distance_to(_staff.global_position) > hear, "职员离猴 %.1fm（> 听距 %.1fm）" % [monkey.global_position.distance_to(_staff.global_position), hear])
	_noises.clear()
	_check(monkey.try_throw(), "猴按 T 投掷")
	_check(not monkey.try_throw(), "投掷冷却中不能连丢")
	_check(_noises.is_empty(), "飞行中还没有声响")
	await get_tree().create_timer(GameConst.action_cost().throw_flight_sec + 0.2).timeout
	var throws := _noises.filter(func(n: Array) -> bool: return n[2] == ThrownStone.KIND)
	_check(throws.size() == 1 and (throws[0][0] as Vector3).distance_to(land) < 0.01, "落地在落点发出声响（kind=throw）")
	_check(_staff.state == StaffActor.State.INVESTIGATE and _staff._investigate_pos.distance_to(land) < 0.01, "职员去查看落点，而不是猴的位置")
	_check(Alert.level == 0, "投掷不计警戒")
	_reset_staff()
	_staff.global_position = Vector3(40, 0.05, 40)
	var cd := monkey.throw_cooldown_left()
	_check(cd > 7.0 and cd <= 8.0, "冷却 8 秒（剩 %.1fs）" % cd)
	await get_tree().create_timer(cd + 0.1).timeout
	_check(monkey.throw_cooldown_left() == 0.0 and monkey.noise_tools_line().contains("就绪"), "8 秒后恢复：%s" % monkey.noise_tools_line())
	## Into a wall: lands short of it.
	await _stand(monkey, _geo.dig_interactable.global_position + Vector3(3.0, 0.05, 0))
	monkey._facing = Vector3(-1, 0, 0)
	var wall_land := monkey.throw_landing_point()
	var wall_reach := absf(wall_land.x - monkey.global_position.x)
	var space := monkey.get_world_3d().direct_space_state
	_check(wall_reach < GameConst.action_cost().throw_range - 0.5 and StaffSense.has_line_of_sight(space, monkey.global_position, wall_land, [monkey.get_rid()]),
		"对着外墙丢：被墙挡下，落在墙内侧（%.1fm）" % wall_reach)
	_party.switch_next()
	await get_tree().process_frame


## Gather B: a point flagged risky reads gather_risky_* (defaults add nothing; non-zero → noise + trace).
func _gather_b(raccoon: AnimalActor) -> void:
	var risky_n := 0
	for g in _geo.gather_points:
		if g.risky:
			risky_n += 1
	_check(risky_n == 0, "现有搜集点都不是 B 类（接口预留）")
	var cost := GameConst.action_cost()
	var gp: GatherPoint = null
	for g in _geo.gather_points:
		if g.display_name == "南侧杂物堆":
			gp = g
	gp.risky = true
	_noises.clear()
	await _gather(raccoon, gp)
	_check(raccoon.has_item(KitIds.WOOD) and _noises.is_empty() and get_tree().get_nodes_in_group("traces").is_empty(),
		"B 类 + 默认参数：照常拿到，不发声、不留痕")
	var saved := [cost.gather_risky_noise, cost.gather_risky_trace]
	cost.gather_risky_noise = 1.0
	cost.gather_risky_trace = 1.0
	gp.risky = false
	for g in _geo.gather_points:
		if g.display_name == "游客遗落的绳":
			gp = g
	gp.risky = true
	await _gather(raccoon, gp)
	var gather_noise := _noises.filter(func(n: Array) -> bool: return n[2] == &"gather")
	var traces := get_tree().get_nodes_in_group("traces")
	_check(gather_noise.size() == 1 and traces.size() == 1 and (traces[0] as TraceMarker).kind == &"gather",
		"B 类 + 参数非零：发出 gather 噪音并留下痕迹")
	_check(Alert.level == 0, "B 类噪音本身不升警戒")
	cost.gather_risky_noise = saved[0]
	cost.gather_risky_trace = saved[1]
	gp.risky = false


func _gather(a: AnimalActor, g: GatherPoint) -> void:
	await _stand(a, g.global_position + Vector3(0.6, 0.05, 0))
	g.try_use(a)
	await get_tree().process_frame
	var t := 0.0
	while g._busy and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()


func _reset_staff() -> void:
	_staff.state = StaffActor.State.WORK
	_staff.awareness = 0.0
	_staff._clear_combat_memory()


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
