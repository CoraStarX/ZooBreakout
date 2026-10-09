extends Node
## P2-M0: dig/climb interactables sit on outer perimeter walls.
## godot --headless --path . res://prototypes/p2_outer_walls.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Outer Walls ===")
	Game.selected_starter_id = &"raccoon"
	Clock.auto_advance = false
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Alert.level = 0
	OfficeStorage.take_all()
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var geom: ZooP0Geometry = world.get_node_or_null("Geometry") as ZooP0Geometry
	if geom == null or geom.dig_interactable == null or geom.climb_interactable == null:
		_fail("BOOT", "geometry/dig/climb missing")
		_finish()
		return
	var dig_p := geom.dig_interactable.global_position
	var climb_p := geom.climb_interactable.global_position
	## West outer wall at x≈-12; dig must be on/near it (not old inner fence x≈-9.5).
	if dig_p.x <= -10.5 and absf(dig_p.z - 1.5) < 1.0:
		_ok("M0-Dig", "挖掘点在西外墙 dig=%s" % dig_p)
	else:
		_fail("M0-Dig", "挖掘点仍偏内 dig=%s" % dig_p)
	## South outer wall at z≈-12; climb must be on/near it (not old yard gate z≈-10).
	if climb_p.z <= -10.8 and absf(climb_p.x + 4.5) < 1.0:
		_ok("M0-Climb", "攀爬点在南外墙 climb=%s" % climb_p)
	else:
		_fail("M0-Climb", "攀爬点仍偏内 climb=%s" % climb_p)
	## Dig blocker should be the west outer gate body (or already bound).
	var dig_blocker: Node3D = geom.dig_interactable.get("_blocker") as Node3D
	if dig_blocker != null and dig_blocker.name == "WestOuterGate":
		_ok("M0-DigBlocker", "挖洞 blocker = WestOuterGate")
	elif dig_blocker != null and absf(dig_blocker.global_position.x + 12.0) < 0.2:
		_ok("M0-DigBlocker", "挖洞 blocker 在西外墙 x=%s" % dig_blocker.global_position.x)
	else:
		_fail("M0-DigBlocker", "挖洞 blocker 不是西外墙 name=%s" % [
			dig_blocker.name if dig_blocker else "null"
		])
	var climb_blocker: Node3D = geom.climb_interactable.get("_blocker") as Node3D
	if climb_blocker != null and climb_blocker.name == "SouthOuterGate":
		_ok("M0-ClimbBlocker", "攀爬 blocker = SouthOuterGate")
	elif climb_blocker != null and absf(climb_blocker.global_position.z + 12.0) < 0.2:
		_ok("M0-ClimbBlocker", "攀爬 blocker 在南外墙 z=%s" % climb_blocker.global_position.z)
	else:
		_fail("M0-ClimbBlocker", "攀爬 blocker 不是南外墙 name=%s" % [
			climb_blocker.name if climb_blocker else "null"
		])
	## Completing dig must not require a separate distant gate (already the outer wall).
	var session: RunSession = world.get("session")
	var party: PartyController = world.get("party")
	party.rescue(&"monkey", false)
	await get_tree().process_frame
	session.mark_exhibit_escaped()
	session.mark_companion_rescued()
	var actor := party.controlled()
	actor.global_position = dig_p + Vector3(0.8, 0, 0)
	actor.velocity = Vector3.ZERO
	await RouteHelper.finish(get_tree(), geom.dig_interactable, actor)
	var t := 0.0
	while geom.dig_interactable._busy and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame
	if session.route_dig_ready and geom.dig_interactable._done:
		_ok("M0-DigOpen", "挖通西外墙即就绪挖掘线（无内点假联动）")
	else:
		_fail("M0-DigOpen", "挖通后未就绪 dig_ready=%s done=%s" % [
			session.route_dig_ready, geom.dig_interactable._done
		])
	if session.outcome != RunSession.Outcome.NONE:
		_fail("M0-NoAutoWin", "挖通落点误触结算 outcome=%s" % session.outcome)
	else:
		_ok("M0-NoAutoWin", "挖通后未秒通关")
	_finish()


func _ok(tag: String, msg: String) -> void:
	_pass_n += 1
	print("PASS ", tag, ": ", msg)


func _fail(tag: String, msg: String) -> void:
	_fail_n += 1
	print("FAIL ", tag, ": ", msg)


func _finish() -> void:
	print("")
	print("=== P2 OUTER SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	print("=== END ===")
	get_tree().quit(0 if _fail_n == 0 else 1)
