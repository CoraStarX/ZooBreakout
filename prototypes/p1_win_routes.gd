extends Node
## P1 win/lose gate.
## godot --headless --path . res://prototypes/p1_win_routes.tscn

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _party: PartyController
var _session: RunSession
var _geometry: ZooP0Geometry


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== P1 Win Routes ===")
	Game.selected_starter_id = &"raccoon"
	Game.debug_enabled = false
	Clock.auto_advance = false
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Alert.level = 0
	OfficeStorage.take_all()
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	_session = _world.get("session") as RunSession
	_geometry = _world.get_node_or_null("Geometry") as ZooP0Geometry
	if _party == null or _session == null or _geometry == null:
		_fail("BOOT", "world/session/geometry missing")
		_finish()
		return
	await _test_dig_win()
	get_tree().paused = false
	## Fresh run for climb win
	_world.queue_free()
	await get_tree().process_frame
	Alert.level = 0
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	_session = _world.get("session") as RunSession
	_geometry = _world.get_node_or_null("Geometry") as ZooP0Geometry
	await _test_climb_win()
	get_tree().paused = false
	## Fresh run: Soft climb must land outside (south), not back into yard / void
	_world.queue_free()
	await get_tree().process_frame
	Alert.level = 0
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	_session = _world.get("session") as RunSession
	_geometry = _world.get_node_or_null("Geometry") as ZooP0Geometry
	await _test_soft_climb_lands_outside()
	get_tree().paused = false
	## Fresh run: raccoon Hard climb must not freeze on spawned ledge
	_world.queue_free()
	await get_tree().process_frame
	Alert.level = 0
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	_session = _world.get("session") as RunSession
	_geometry = _world.get_node_or_null("Geometry") as ZooP0Geometry
	await _test_hard_climb_raccoon_movable()
	get_tree().paused = false
	## Fresh run for lose path
	_world.queue_free()
	await get_tree().process_frame
	Alert.level = 0
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	_session = _world.get("session") as RunSession
	await _test_max_alert_lose()
	get_tree().paused = false
	_finish()


func _test_dig_win() -> void:
	_party.rescue(&"monkey", false)
	await get_tree().process_frame
	_session.mark_exhibit_escaped()
	_session.mark_companion_rescued()
	_session.mark_route_dig_ready()
	_geometry.open_west_exit_route()
	var zone := _geometry.exit_west
	if zone == null:
		_fail("M1-Exit", "ExitWest missing")
		return
	for a in _party.party():
		a.set_confined(false)
		a.global_position = zone.global_position
		a.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	_world.check_exit_win(RunSession.ExitRoute.DIG)
	await get_tree().process_frame
	if _session.outcome == RunSession.Outcome.WON:
		_ok("M0/M1-Win", "挖掘线全队进 ExitWest → WON")
	else:
		_fail("M0/M1-Win", "期望 WON 得到 %s reason=%s dig=%s" % [
			_session.outcome, _session.outcome_reason, _session.route_dig_ready
		])


func _test_climb_win() -> void:
	_party.rescue(&"monkey", false)
	await get_tree().process_frame
	_session.mark_exhibit_escaped()
	_session.mark_companion_rescued()
	_session.mark_route_climb_ready()
	_geometry.open_south_exit_route()
	var zone := _geometry.exit_south
	if zone == null:
		_fail("M1-ExitSouth", "ExitSouth missing")
		return
	for a in _party.party():
		a.set_confined(false)
		a.global_position = zone.global_position
		a.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	_world.check_exit_win(RunSession.ExitRoute.CLIMB)
	await get_tree().process_frame
	if _session.outcome == RunSession.Outcome.WON:
		_ok("M0/M1-ClimbWin", "攀爬线全队进 ExitSouth → WON")
	else:
		_fail("M0/M1-ClimbWin", "期望 WON 得到 %s reason=%s climb=%s" % [
			_session.outcome, _session.outcome_reason, _session.route_climb_ready
		])


func _test_soft_climb_lands_outside() -> void:
	_party.rescue(&"monkey", false)
	await get_tree().process_frame
	_party.switch_next()
	await get_tree().process_frame
	var monkey := _party.controlled()
	var climb := _geometry.climb_interactable
	if monkey == null or climb == null or monkey.def.id != &"monkey":
		_fail("M1-ClimbLand", "monkey/climb missing")
		return
	var gate_z := climb.global_position.z
	monkey.global_position = climb.global_position + Vector3(0, 0, 1.0)
	monkey.velocity = Vector3.ZERO
	await RouteHelper.finish(get_tree(), climb, monkey)
	var t := 0.0
	while climb._busy and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pos := monkey.global_position
	## Outside = more negative Z than the south climb interact; near ground (capsule center ≈0.55–0.8).
	if pos.z < gate_z - 0.5 and pos.y < 1.15 and pos.y > -0.5:
		_ok("M1-ClimbLand", "Soft 攀爬落在园外走廊 pos=%s gate_z=%.1f" % [pos, gate_z])
	else:
		_fail("M1-ClimbLand", "落点异常 pos=%s gate_z=%.1f（应在园外地面）" % [pos, gate_z])
		return
	## Solo Soft climb must not instantly WON (landing outside ExitSouth).
	if _session.outcome != RunSession.Outcome.NONE:
		_fail("M1-ClimbLand", "攀爬落点误触结算 outcome=%s" % _session.outcome)
		return
	if not _session.route_climb_ready:
		_fail("M1-ClimbLand", "攀爬完成后 route_climb_ready 仍为 false")
		return
	## Party sync into ExitSouth → WON (followers may still be inside; move all).
	for a in _party.party():
		a.set_confined(false)
		a.global_position = _geometry.exit_south.global_position
		a.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _session.outcome == RunSession.Outcome.WON:
		_ok("M1-ClimbSoftWin", "Soft 攀爬后全队进南出口 → WON")
	else:
		_world.check_exit_win(RunSession.ExitRoute.CLIMB)
		await get_tree().process_frame
		if _session.outcome == RunSession.Outcome.WON:
			_ok("M1-ClimbSoftWin", "Soft 攀爬后全队进南出口 → WON")
		else:
			_fail("M1-ClimbSoftWin", "期望 WON 得到 %s" % _session.outcome)


func _test_hard_climb_raccoon_movable() -> void:
	## 浣熊强行中间两档（最后一档禁强行），猴 Soft 收尾翻出；之后浣熊须能从南外墙缺口走出去。
	_party.rescue(&"monkey", false)
	await get_tree().process_frame
	var raccoon := _party.controlled()
	var monkey: AnimalActor = null
	for a in _party.party():
		if a != raccoon:
			monkey = a
	var climb := _geometry.climb_interactable
	if raccoon == null or monkey == null or climb == null or raccoon.def.id != &"raccoon":
		_fail("M1-HardClimb", "raccoon/monkey/climb missing")
		return
	if raccoon.has_capability(CapabilityIds.Id.CLIMB):
		_fail("M1-HardClimb", "raccoon 不应有攀爬能力")
		return
	var gate_z := climb.global_position.z
	raccoon.global_position = climb.global_position + Vector3(0, 0, 1.0)
	raccoon.velocity = Vector3.ZERO
	await RouteHelper.finish(get_tree(), climb, raccoon) ## Hard mid-tiers; last forbids Hard
	if climb.tier_done != climb.tiers - 1 or climb._done:
		_fail("M1-HardClimb", "浣熊应停在最后一档前 tier=%d/%d" % [climb.tier_done, climb.tiers])
		return
	monkey.order_hold()
	monkey.global_position = climb.global_position + Vector3(0.6, 0, 1.0)
	monkey.velocity = Vector3.ZERO
	monkey._hold_position = monkey.global_position
	await RouteHelper.finish(get_tree(), climb, monkey) ## monkey Soft last → eject
	var t := 0.0
	while climb._busy and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _session.route_climb_ready or monkey.global_position.z >= gate_z - 0.5:
		_fail("M1-HardClimb", "猴收尾后未翻出 ready=%s monkey=%s" % [_session.route_climb_ready, monkey.global_position])
		return
	if _session.outcome != RunSession.Outcome.NONE:
		_fail("M1-HardClimb", "攀爬落点误触结算 outcome=%s" % _session.outcome)
		return
	## Raccoon still inside: walk through the opened gate (headless input is zero — probe with test_move).
	raccoon.global_position = Vector3(climb.global_position.x, 0.05, gate_z)
	raccoon.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var blocked := raccoon.test_move(raccoon.global_transform, Vector3(0, 0, -2.4))
	if not blocked:
		_ok("M1-HardClimb", "浣熊 Hard 两档 + 猴 Soft 收尾；浣熊可穿过南外墙缺口")
	else:
		_fail("M1-HardClimb", "南外墙缺口仍挡住浣熊 pos=%s" % raccoon.global_position)


func _test_max_alert_lose() -> void:
	Alert.level = GameConst.MAX_ALERT_LEVEL
	var actor := _party.controlled()
	if actor == null:
		_fail("M0-Lose", "无受控动物")
		return
	CaptureFlow.apply_capture(actor)
	await get_tree().process_frame
	if _session.outcome == RunSession.Outcome.LOST:
		_ok("M0-Lose", "满警再抓 → LOST")
	else:
		_fail("M0-Lose", "期望 LOST 得到 %s alert=%d" % [_session.outcome, Alert.level])


func _ok(tag: String, msg: String) -> void:
	_pass_n += 1
	print("PASS ", tag, ": ", msg)


func _fail(tag: String, msg: String) -> void:
	_fail_n += 1
	print("FAIL ", tag, ": ", msg)


func _finish() -> void:
	print("")
	print("=== P1 WIN SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	print("=== END ===")
	get_tree().quit(0 if _fail_n == 0 else 1)
