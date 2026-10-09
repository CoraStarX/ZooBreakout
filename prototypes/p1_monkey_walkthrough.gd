extends Node
## Monkey-starter walkthrough: Soft cage → Soft climb → rescue raccoon → follow smoke.
## godot --headless --path . res://prototypes/p1_monkey_walkthrough.tscn

var _ok_n := 0
var _find_n := 0
var _log: PackedStringArray = []
var _world: Node3D
var _party: PartyController


func _ready() -> void:
	print("=== P1 Monkey Walkthrough ===")
	Bus.interact_feedback.connect(func(m: String): _log.append(m))
	Game.selected_starter_id = &"monkey"
	Game.debug_enabled = false
	Clock.auto_advance = false
	Alert.level = 0
	OfficeStorage.take_all()
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	if _party == null or _party.controlled() == null or _party.controlled().def.id != &"monkey":
		_finding("BOOT", "猴开局未生成受控猴")
		_finish()
		return
	_pass("猴开局出生于猴笼")
	await _beat_soft_escape()
	await _beat_soft_climb()
	await _beat_rescue_raccoon()
	await _beat_follow_smoke()
	_finish()


func _beat_soft_escape() -> void:
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	var actor := _party.controlled()
	var door: Interactable = _world.call("door_for_animal", actor)
	if door == null:
		_finding("Escape", "无猴笼门")
		return
	actor.global_position = door.global_position + Vector3(-1.1, 0, 0)
	actor.velocity = Vector3.ZERO
	door.try_use(actor)
	var t := 0.0
	while door._busy and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame
	if door._done and _world.get("exhibit_escaped"):
		_pass("猴 Soft 开笼逃出展区")
	else:
		_finding("Escape", "猴逃出失败 done=%s esc=%s" % [door._done, _world.get("exhibit_escaped")])


func _beat_soft_climb() -> void:
	var actor := _party.controlled()
	var climb := _search_interactable("攀爬")
	if climb == null:
		_finding("Climb", "无攀爬点")
		return
	## Outer south wall: approach from inside the zoo (north of the wall).
	actor.global_position = climb.global_position + Vector3(0, 0, 1.0)
	actor.velocity = Vector3.ZERO
	await RouteHelper.finish(get_tree(), climb, actor)
	var t := 0.0
	while climb._busy and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(0.35).timeout
	if climb._done and actor.global_position.z < -12.0:
		_pass("猴 Soft 攀爬翻出南外墙")
	elif climb._done:
		_finding("Climb", "攀爬完成但未过南外墙 pos=%s" % actor.global_position)
	else:
		_finding("Climb", "攀爬失败 log=%s" % ",".join(_log))


func _beat_rescue_raccoon() -> void:
	var actor := _party.controlled()
	var raccoon_door := _search_interactable("笼门锁")
	if raccoon_door == null:
		_finding("Rescue", "无浣熊笼门")
		return
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	actor.global_position = raccoon_door.global_position + Vector3(0, 0, 1.1)
	actor.velocity = Vector3.ZERO
	raccoon_door.try_use(actor)
	var t := 0.0
	while raccoon_door._busy and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame
	if _party.party().size() >= 2:
		_pass("猴开局解救浣熊入队")
	else:
		_finding("Rescue", "解救失败 party=%d" % _party.party().size())


func _beat_follow_smoke() -> void:
	if _party.party().size() < 2:
		_finding("Follow", "无队友跳过")
		return
	_party.order_all(AnimalActor.FollowMode.FOLLOW)
	var leader := _party.controlled()
	var follower: AnimalActor = null
	for a in _party.party():
		if not a.is_controlled:
			follower = a
	leader.global_position = Vector3(-2, 0.05, 4)
	follower.global_position = Vector3(2, 0.05, 4)
	follower.set_follow_target(leader)
	follower.order_follow()
	await get_tree().create_timer(1.2).timeout
	var d := follower.global_position.distance_to(leader.global_position)
	if d < 3.8:
		_pass("猴开局队友空地 Follow（%.1fm）" % d)
	else:
		_finding("Follow", "空地掉队 %.1fm" % d)


func _search_interactable(part: String) -> Interactable:
	if _world == null:
		return null
	for n in _world.find_children("*", "Area3D", true, false):
		if n is Interactable and part in (n as Interactable).display_name:
			return n as Interactable
	return null


func _pass(msg: String) -> void:
	_ok_n += 1
	print("PASS ", msg)


func _finding(tag: String, msg: String) -> void:
	_find_n += 1
	print("FINDING ", tag, ": ", msg)


func _finish() -> void:
	print("")
	print("=== MONKEY WALK SUMMARY OK=%d FINDINGS=%d ===" % [_ok_n, _find_n])
	print("=== END ===")
	get_tree().quit(0 if _find_n == 0 else 1)
