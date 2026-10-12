extends Node
## 正式开局 → 开自己笼 → 开锁救猴 → 猴自己走出笼与浣熊会合。不得临时赋予能力。
## 另含笼门循环依赖检查（正式关卡须无错误；刻意做坏的配置须报错）。
## godot --headless --path . res://prototypes/p2_rescue_rendezvous.tscn

const Spawns := preload("res://content/levels/zoo_p0_spawns.gd")
const RACCOON_PATH := "res://content/animals/raccoon.tres"
const MONKEY_PATH := "res://content/animals/monkey.tres"

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Rescue Rendezvous ===")
	Game.debug_enabled = false
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var party: PartyController = world.get("party")
	var session: RunSession = world.get("session")
	var raccoon := party.controlled()

	## --- Official start state ---
	_check(Game.selected_starter_id == &"raccoon" and raccoon.def.id == &"raccoon", "开局固定为浣熊")
	_check(raccoon.def.resource_path == RACCOON_PATH, "浣熊使用正式 AnimalDef（未替换）")
	_check(party.party().size() == 1, "开局队伍只有浣熊")
	_check(Spawns.resolve_starter(&"monkey") == &"raccoon", "选猴开局会被改回浣熊（monkey.can_start=false）")

	var staff: StaffActor = world.call("get_staff")
	staff.set_physics_process(false)
	staff.global_position = Vector3(40, 0.05, 40)
	Clock.set_phase(Clock.Phase.OPEN)

	## --- Raccoon picks its own lock ---
	var own: Interactable = world.call("door_for_animal", raccoon)
	_stand(raccoon, own.global_position + Vector3(0, 0, -0.9))
	own.try_use(raccoon)
	await _idle(own)
	_check(own._done and session.exhibit_escaped, "浣熊 Soft 开锁逃出展区")

	## --- Raccoon picks the monkey's lock from outside ---
	var mdoor: Interactable = world.get("cage_doors")[&"monkey"]
	_stand(raccoon, mdoor.global_position + Vector3(-1.1, 0, 0))
	mdoor.try_use(raccoon)
	await _idle(mdoor)
	_check(mdoor._done, "浣熊 Soft 开猴笼")
	_check(party.party().size() == 2 and session.companion_rescued, "猴入队")
	var monkey: AnimalActor = null
	for a in party.party():
		if a != raccoon:
			monkey = a
	_check(monkey != null and monkey.def.resource_path == MONKEY_PATH, "猴使用正式 AnimalDef（未替换）")

	## --- Rendezvous: rescue warps the monkey beside the raccoon; then it must walk to a far leader on its own ---
	_check(monkey.global_position.x < 4.2, "救出后猴在笼外（x=%.1f）" % monkey.global_position.x)
	_stand(raccoon, Vector3(1.5, 0.05, 3.5))
	raccoon.follow_trail.points.clear()
	monkey.order_follow()
	var start_d := monkey.global_position.distance_to(raccoon.global_position)
	var arrive := monkey.follow_params.follow_stop_dist + 0.5
	var t := 0.0
	while t < 8.0 and monkey.global_position.distance_to(raccoon.global_position) > arrive:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var end_d := monkey.global_position.distance_to(raccoon.global_position)
	_check(start_d >= 5.0, "会合起点距离 %.1fm（够远，非瞬移判定）" % start_d)
	_check(end_d <= arrive and t >= 0.5, "双动物会合：猴走 %.1fs 到 %.1fm（停步距 %.1fm）" % [t, end_d, arrive])

	## --- Cage dependency check ---
	var defs := {&"raccoon": load(RACCOON_PATH), &"monkey": load(MONKEY_PATH)}
	var ok_errors := CageDependencyCheck.validate(world.get("cage_doors"), defs, &"raccoon")
	_check(ok_errors.is_empty(), "正式关卡无笼门循环依赖 %s" % ",".join(ok_errors))

	var bad_raccoon := Interactable.new()
	bad_raccoon.required = CapabilityIds.Id.DEXTERITY
	bad_raccoon.allow_hard = false
	var bad_monkey := Interactable.new()
	bad_monkey.required = CapabilityIds.Id.CLIMB ## 只有猴会攀爬，而猴就在门后
	bad_monkey.allow_hard = false
	var bad := {&"raccoon": bad_raccoon, &"monkey": bad_monkey}
	var bad_text := "\n".join(CageDependencyCheck.validate(bad, defs, &"raccoon"))
	_check(bad_text.contains("循环依赖：monkey"), "猴笼要求攀爬 → 报循环依赖")
	_check(bad_text.contains("无法解救"), "猴笼要求攀爬 → 报无法解救")
	bad_monkey.allow_hard = true
	_check(CageDependencyCheck.validate(bad, defs, &"raccoon").is_empty(), "允许强行时不算循环依赖")
	bad_raccoon.free()
	bad_monkey.free()

	print("")
	print("=== P2 RESCUE RENDEZVOUS SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _stand(a: AnimalActor, pos: Vector3) -> void:
	a.global_position = pos
	a.velocity = Vector3.ZERO


func _idle(it: Interactable) -> void:
	await get_tree().process_frame
	var t := 0.0
	while it._busy and t < 5.0:
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
