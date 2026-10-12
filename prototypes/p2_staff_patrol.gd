extends Node
## 階段 B：巡邏選點評分、預約、Bus.noise_made 聽覺。
## godot --headless --path . res://prototypes/p2_staff_patrol.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Staff Patrol ===")
	var params := StaffAiParams.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	## 評分：陳舊點應高於剛去過的點。
	var fresh := PatrolPointData.new().configure(&"a", Vector3.ZERO, 1.0)
	fresh.last_visited = 100.0
	var stale := PatrolPointData.new().configure(&"b", Vector3(1, 0, 0), 1.0)
	stale.last_visited = 0.0
	var s_fresh := PatrolScoreMath.score_point(fresh, 100.0, Vector3.ZERO, params, [], rng)
	var s_stale := PatrolScoreMath.score_point(stale, 100.0, Vector3.ZERO, params, [], rng)
	_check(s_stale > s_fresh, "陳舊點分數更高（%.2f > %.2f）" % [s_stale, s_fresh])

	## 近期重複懲罰。
	var s_recent := PatrolScoreMath.score_point(stale, 100.0, Vector3.ZERO, params, [&"b"], rng)
	_check(s_recent < s_stale, "近期重複有懲罰")

	## 預約：他人佔用則跳過。
	var net := PatrolNetwork.new()
	net.set_seed(3)
	net.add_point(PatrolPointData.new().configure(&"p0", Vector3(0, 0, 0), 1.0))
	net.add_point(PatrolPointData.new().configure(&"p1", Vector3(5, 0, 0), 1.2))
	_check(net.reserve(&"p0", 101), "職員 A 預約 p0")
	_check(not net.reserve(&"p0", 202), "職員 B 無法搶 p0")
	var pick := net.pick_next(Vector3.ZERO, 202, params, 10.0, [], &"")
	_check(pick != null and pick.id == &"p1", "B 選到未預約的 p1")
	net.release(&"p0", 101)
	_check(net.reserve(&"p0", 202), "釋放後 B 可預約 p0")

	## 實際關卡：點網 + 叫嚷噪音。
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var staff: StaffActor = world.call("get_staff")
	_check(staff.patrol_network != null and staff.patrol_network.points.size() >= 8, "關卡使用加權點網")
	_check(staff._use_network, "職員啟用點網巡邏")

	Clock.set_phase(Clock.Phase.OPEN)
	staff.global_position = Vector3(5, 0.05, 5)
	staff.state = StaffActor.State.WORK
	staff.awareness = 0.0
	var actor: AnimalActor = world.get("party").controlled()
	actor.global_position = Vector3(6, 0.05, 5)
	Bus.noise_made.emit(actor.global_position, GameConst.SHOUT_LOUDNESS, &"shout")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(staff.state == StaffActor.State.INVESTIGATE, "叫嚷噪音 → INVESTIGATE")

	## 冷卻中的主動噪音。
	_check(actor.try_make_noise(), "首次叫嚷成功")
	_check(not actor.try_make_noise(), "冷卻中不可連按")

	## 選點分數：同一時刻，更陳舊者分數更高（不依賴隨機噪聲方向）。
	var p0: PatrolPointData = staff.patrol_network.points[0]
	var p1: PatrolPointData = staff.patrol_network.points[1]
	p0.last_visited = 0.0
	p1.last_visited = 50.0
	p0.heat = 0.0
	p1.heat = 0.0
	p0.importance = 1.0
	p1.importance = 1.0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	## 用零噪聲參數避免隨機蓋過陳舊度。
	var p_score := staff._params.duplicate() as StaffAiParams
	p_score.score_noise_min = 0.0
	p_score.score_noise_max = 0.0
	var sc0 := PatrolScoreMath.score_point(p0, 50.0, Vector3.ZERO, p_score, [], rng2)
	var sc1 := PatrolScoreMath.score_point(p1, 50.0, Vector3.ZERO, p_score, [], rng2)
	_check(sc0 > sc1, "更陳舊點分數更高（%.2f > %.2f）" % [sc0, sc1])

	print("")
	print("=== P2 STAFF PATROL SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
