extends Node
## 夥伴麵包屑跟隨：軌跡、卡住恢復、傳送、換控待命、標記點。
## godot --headless --path . res://prototypes/p2_follow_trail.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Follow Trail ===")
	## 純函式：軌跡記錄。
	var trail := FollowTrail.new()
	var params := CompanionFollowParams.new()
	trail.record(Vector3.ZERO, params.trail_spacing, params.trail_max_points)
	trail.record(Vector3(0.3, 0, 0), params.trail_spacing, params.trail_max_points)
	_check(trail.points.size() == 1, "間距不足不記點")
	trail.record(Vector3(1.0, 0, 0), params.trail_spacing, params.trail_max_points)
	_check(trail.points.size() == 2, "達間距記第二點")
	for i in 80:
		trail.record(Vector3(float(i) * params.trail_spacing, 0, 0), params.trail_spacing, params.trail_max_points)
	_check(trail.points.size() <= params.trail_max_points, "軌跡上限 %d" % trail.points.size())

	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var party: PartyController = world.get("party")
	party.rescue(&"monkey", true)
	await get_tree().process_frame
	var leader := party.controlled()
	var follower: AnimalActor = null
	for a in party.party():
		if not a.is_controlled:
			follower = a
	_check(leader != null and follower != null, "雙人隊伍")

	## 換控 → 退下者待命。
	var prev_id := leader.def.id if leader.def else &""
	party.switch_next()
	await get_tree().process_frame
	var after_switch := party.controlled()
	var parked: AnimalActor = null
	for a in party.party():
		if a != after_switch:
			parked = a
	_check(parked != null and parked.follow_mode == AnimalActor.FollowMode.HOLD, "换控后退下者待命")
	_check(after_switch.def == null or after_switch.def.id != prev_id or party.party().size() == 2, "已换控")

	## 標記點指令。
	party.order_all(AnimalActor.FollowMode.FOLLOW)
	await get_tree().process_frame
	after_switch.global_position = Vector3(0, 0.05, 0)
	parked.global_position = Vector3(3, 0.05, 0)
	parked.set_follow_target(after_switch)
	party.order_goto_marker()
	_check(party.marker_valid, "标记点已放置")
	_check(parked.follow_mode == AnimalActor.FollowMode.GOTO, "同伴进入 GOTO")

	## 危險區不強制 HOLD。
	parked.order_follow()
	party.on_danger_entered(parked)
	_check(parked.follow_mode == AnimalActor.FollowMode.FOLLOW, "危险区仍跟随")

	## 傳送邏輯。
	parked.global_position = Vector3(11, 0.05, 11)
	after_switch.global_position = Vector3(-4, 0.05, -5)
	parked.set_follow_target(after_switch)
	parked.order_follow()
	var ok_tp := parked.try_teleport_near_leader()
	_check(ok_tp and parked.global_position.distance_to(after_switch.global_position) < 3.0, "传送到队长旁")

	## F 強制跟隨覆寫待命。
	parked.order_hold(false)
	party.order_all(AnimalActor.FollowMode.FOLLOW)
	_check(parked.follow_mode == AnimalActor.FollowMode.FOLLOW, "F 可强制跟随")

	print("")
	print("=== P2 FOLLOW TRAIL SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
