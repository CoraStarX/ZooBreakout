class_name StaffActor
extends CharacterBody3D
## 職員 AI 編排器：感知 → awareness → 狀態 → Motor。
## 階段 A：awareness 分層 + Search/Return；巡邏冊暫留，階段 B 換加權點網。

## WORK/SUSPICIOUS 為正式名；PATROL/SUSPECT 為舊測試相容別名（同值）。
enum State {
	WORK = 0,
	PATROL = 0,
	SUSPICIOUS = 1,
	SUSPECT = 1,
	INVESTIGATE = 2,
	SEARCH = 3,
	RETURN = 4,
	CHASE = 5,
	GUARD = 6,
	REST = 7,
}

enum LookPhase { CENTER_HOLD, TURN_LEFT, LEFT_HOLD, TURN_RIGHT, RIGHT_HOLD, TURN_CENTER }

@export var ai_params: StaffAiParams
## 相容舊 Inspector／測試的鏡像欄位（ready 時與 params 雙向同步）。
@export var move_speed: float = 2.8
@export var vision_range: float = 7.0
@export var vision_angle_deg: float = 55.0
@export var hear_walk_range: float = 2.15
@export var catch_range: float = 1.35
@export var reaction_time_sec: float = 0.55
@export var catch_windup_sec: float = 0.28
@export var catch_recovery_sec: float = 0.75
@export var lose_sight_grace_sec: float = 1.5
@export var chase_speed_mult: float = 1.32
@export var suspect_speed_mult: float = 0.45
@export var look_around_yaw_deg: float = 52.0
@export var look_turn_deg_per_sec: float = 48.0
@export var look_hold_sec: float = 0.70
@export var look_center_hold_sec: float = 0.45
@export var spur_every_laps: int = 2
@export var reverse_every_laps: int = 3
@export var announce_route_change: bool = true

## 個體警覺 0~100（與全域跑團 Alert 不同）。
var awareness: float = 0.0
var state: State = State.WORK
var waypoints: Array[Vector3] = []
var route_book: Dictionary = {}
var active_route_id: StringName = &""
var home_route_id: StringName = &""
var _wp_index: int = 0
var _patrol_dir: int = 1
var _lap_count: int = 0
var _spur_cursor: int = 0
var _on_spur: bool = false
var _look_phase: LookPhase = LookPhase.CENTER_HOLD
var _look_hold_left: float = 0.0
var _look_yaw: float = 0.0
var _investigate_glancing: bool = false
var _dwell_face0: Vector3 = Vector3(0, 0, 1)
var _facing: Vector3 = Vector3(0, 0, 1)
var _investigate_pos: Vector3 = Vector3.ZERO
var _investigate_timer: float = 0.0
var _guard_pos: Vector3 = Vector3.ZERO
var _guard_door: Interactable = null
var _base_vision: float = 0.0
var _base_speed: float = 0.0
var _dwell_left: float = 0.0
var _route_node: Node3D
var _route_preview_on: bool = false
var _detect_kind: String = ""
var _mesh: MeshInstance3D
var _vision_mesh: MeshInstance3D
var _vision_mat: StandardMaterial3D

var _params: StaffAiParams
var _motor: StaffMotor = StaffMotor.new()
var _last_known: Vector3 = Vector3.ZERO
var _last_known_valid: bool = false
var _seeing: bool = false
var _telegraph_left: float = 0.0
var _telegraph_shown: bool = false
var _lose_sight_left: float = 0.0
var _catch_hold: float = 0.0
var _recovery_left: float = 0.0
var _search_timer: float = 0.0
var _search_points: Array[Vector3] = []
var _search_checked: Array[Vector3] = []
var _search_index: int = 0
var _pending_noise_pos: Vector3 = Vector3.ZERO
var _pending_noise: bool = false
var _return_target: Vector3 = Vector3.ZERO
## 階段 B 會掛到巡邏點 heat；此處先記位置供 Debug／後續接線。
var pending_heat_pos: Vector3 = Vector3.ZERO
var pending_heat_amount: float = 0.0
var patrol_network: PatrolNetwork
var _patrol_point_id: StringName = &""
var _recent_point_ids: Array[StringName] = []
var _now_sec: float = 0.0
var _use_network: bool = false
var _debug_draw: StaffDebugDraw


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("staff")
	_bootstrap_params()
	_base_vision = vision_range
	_base_speed = move_speed
	_ensure_visual()
	_debug_draw = StaffDebugDraw.new()
	_debug_draw.name = "StaffDebugDraw"
	add_child(_debug_draw)
	_debug_draw.setup(self)
	Bus.day_changed.connect(apply_day_scaling)
	if not Bus.noise_made.is_connected(_on_bus_noise):
		Bus.noise_made.connect(_on_bus_noise)
	if waypoints.is_empty():
		waypoints = [global_position]


func state_name() -> String:
	match state:
		State.WORK:
			return "WORK"
		State.SUSPICIOUS:
			return "SUSPICIOUS"
		State.INVESTIGATE:
			return "INVESTIGATE"
		State.SEARCH:
			return "SEARCH"
		State.RETURN:
			return "RETURN"
		State.CHASE:
			return "CHASE"
		State.GUARD:
			return "GUARD"
		State.REST:
			return "REST"
		_:
			return "?"


func _bootstrap_params() -> void:
	if ai_params == null:
		var loaded := load("res://content/staff/default_staff_ai_params.tres")
		if loaded is StaffAiParams:
			ai_params = loaded
		else:
			ai_params = StaffAiParams.new()
	_params = ai_params.duplicate(true) as StaffAiParams
	_apply_params_to_exports()
	_motor.speed = move_speed
	_motor.arrive_distance = 0.45


func _apply_params_to_exports() -> void:
	if _params == null:
		return
	move_speed = _params.move_speed
	vision_range = _params.vision_range
	vision_angle_deg = _params.vision_angle_deg
	hear_walk_range = _params.hear_walk_range
	catch_range = _params.catch_range
	catch_windup_sec = _params.catch_windup_sec
	catch_recovery_sec = _params.catch_recovery_sec
	lose_sight_grace_sec = _params.lose_target_grace_sec
	chase_speed_mult = _params.chase_speed_mult
	suspect_speed_mult = _params.suspect_speed_mult
	reaction_time_sec = _params.min_telegraph_sec
	look_around_yaw_deg = _params.look_around_yaw_deg
	look_turn_deg_per_sec = _params.look_turn_deg_per_sec
	look_hold_sec = _params.look_hold_sec
	look_center_hold_sec = _params.look_center_hold_sec


func _sync_exports_into_params() -> void:
	if _params == null:
		return
	_params.move_speed = move_speed
	_params.vision_range = vision_range
	_params.vision_angle_deg = vision_angle_deg
	_params.hear_walk_range = hear_walk_range
	_params.catch_range = catch_range
	_params.lose_target_grace_sec = lose_sight_grace_sec
	_params.chase_speed_mult = chase_speed_mult
	_params.min_telegraph_sec = maxf(0.5, reaction_time_sec)


func setup_patrol(points: Array[Vector3]) -> void:
	var net := PatrolNetwork.new()
	for i in points.size():
		net.add_point(
			PatrolPointData.new().configure(
				StringName("p_%d" % i),
				points[i],
				1.0,
				_params.dwell_sec_min if _params else 3.0,
				_params.dwell_sec_max if _params else 8.0
			)
		)
	setup_patrol_network(net)


## DEPRECATED 相容：路線冊展平為點網。
func setup_patrol_book(book: Dictionary, start_id: StringName) -> void:
	route_book = book.duplicate(true)
	home_route_id = start_id
	var net := PatrolNetwork.new()
	var i := 0
	for id in book.keys():
		var pts: Array = book[id]
		for p in pts:
			net.add_point(
				PatrolPointData.new().configure(
					StringName("%s_%d" % [String(id), i]),
					p as Vector3,
					1.1 if id != start_id else 1.0,
					_params.dwell_sec_min if _params else 3.0,
					_params.dwell_sec_max if _params else 8.0
				)
			)
			i += 1
	setup_patrol_network(net)


func setup_patrol_network(net: PatrolNetwork) -> void:
	patrol_network = net
	_use_network = net != null and not net.points.is_empty()
	waypoints = net.positions() if _use_network else [global_position]
	_wp_index = 0
	_patrol_point_id = &""
	_recent_point_ids.clear()
	if _use_network and not patrol_network.points.is_empty():
		var start_p: PatrolPointData = patrol_network.points[0]
		global_position = start_p.position
		patrol_network.reserve(start_p.id, get_instance_id())
		_patrol_point_id = start_p.id
		_motor.set_target(start_p.position)
		_arrive_network_point()


func apply_day_scaling(day: int) -> void:
	var d := clampi(day - 1, 0, GameConst.STAFF_SCALE_MAX_DAYS)
	vision_range = _base_vision + float(d) * GameConst.STAFF_VISION_PER_DAY
	move_speed = _base_speed + float(d) * GameConst.STAFF_SPEED_PER_DAY
	_sync_exports_into_params()
	if _vision_mesh:
		_vision_mesh.mesh = _build_vision_wedge_mesh()


func set_route_visible(on: bool) -> void:
	_route_preview_on = on
	if on:
		_rebuild_route_preview()
	if _route_node:
		_route_node.visible = on


func route_preview_segment_count() -> int:
	if _use_network and patrol_network:
		## 點網預覽：每點一個標記。
		return patrol_network.points.size()
	var n := 0
	var book := route_book if not route_book.is_empty() else {active_route_id: waypoints}
	for id in book.keys():
		var pts: Array = book[id]
		if pts.size() >= 2:
			n += pts.size()
	return n


func assign_door_guard(door: Interactable, stand_pos: Vector3) -> void:
	_guard_door = door
	_guard_pos = stand_pos
	_clear_combat_memory()
	state = State.GUARD
	Bus.interact_feedback.emit("职员守在笼门前 — 靠近会被发现")


func clear_guard() -> void:
	_guard_door = null
	if state == State.GUARD:
		state = _resume_after_duty()


func is_hostile() -> bool:
	return state == State.SUSPICIOUS or state == State.CHASE or state == State.INVESTIGATE


func facing_dir() -> Vector3:
	return _facing


func _resume_after_duty() -> State:
	if Clock.phase == Clock.Phase.NIGHT_QUIET:
		return State.REST
	if _guard_door != null:
		return State.GUARD
	return State.WORK


func _physics_process(delta: float) -> void:
	_sync_exports_into_params()
	_now_sec += delta
	if patrol_network and _params:
		patrol_network.tick_heat(delta, _params)
	if _recovery_left > 0.0:
		_recovery_left -= delta
		velocity = Vector3.ZERO
		_set_vision_visible(false)
		move_and_slide()
		return

	if Clock.phase == Clock.Phase.NIGHT_QUIET and state != State.GUARD:
		state = State.REST
		_clear_combat_memory()
		velocity = Vector3.ZERO
		_set_vision_visible(false)
		return
	_set_vision_visible(state != State.REST)

	if state == State.GUARD:
		_guard_door_duty(delta)
		move_and_slide()
		_update_vision_mesh()
		return

	if state == State.REST:
		## 歇崗結束（上方已攔截 NIGHT_QUIET）→ 回到時段應有狀態。
		state = _resume_after_duty()

	var snap = _sense_now()
	_apply_sense_to_memory(snap)
	_try_discover_traces()
	var spike := 0.0
	## 腳步：每秒小幅抬升 awareness（非全知秒追）。
	if snap.heard_footstep:
		spike += _params.hearing_awareness_spike * delta
	if _pending_noise:
		spike += _params.noise_awareness_spike
		_last_known = _pending_noise_pos
		_last_known_valid = true
		_pending_noise = false

	awareness = StaffAwarenessMath.tick(awareness, delta, snap.visibility_mult, _params, spike)
	_tick_state(delta, snap)
	move_and_slide()
	if _dwell_left <= 0.0 and velocity.length() > 0.1:
		_facing = Vector3(velocity.x, 0.0, velocity.z).normalized()
	_update_vision_mesh()


func _sense_now():
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	return StaffSense.scan(
		_params,
		space,
		global_position,
		_facing,
		[get_rid()],
		get_tree().get_nodes_in_group("animals")
	)


func _apply_sense_to_memory(snap) -> void:
	_seeing = snap.visibility_mult > 0.0
	if snap.last_known_valid:
		## 只有感知能寫 last_known；看見時持續刷新，聽見也可更新。
		_last_known = snap.last_known
		_last_known_valid = true
		_detect_kind = snap.detect_kind


func _tick_state(delta: float, snap) -> void:
	var band := StaffAwarenessMath.band_for(awareness, _params)
	## 預警：達 chase 帶後至少 min_telegraph_sec 才允許進 CHASE。
	if band == &"chase" and state != State.CHASE and state != State.GUARD:
		if _telegraph_left <= 0.0 and not _telegraph_shown:
			_telegraph_left = maxf(0.5, _params.min_telegraph_sec)
			_telegraph_shown = true
			if state == State.WORK or state == State.RETURN:
				state = State.SUSPICIOUS
			Bus.interact_feedback.emit("职员起疑了！快躲开视线！")
		_telegraph_left = maxf(0.0, _telegraph_left - delta)
		if _telegraph_left <= 0.0 and _seeing:
			state = State.CHASE
			_lose_sight_left = _params.lose_target_grace_sec
	elif band != &"chase":
		_telegraph_shown = false
		if state != State.CHASE:
			_telegraph_left = 0.0

	match state:
		State.CHASE:
			_tick_chase(delta, snap)
		State.SEARCH:
			_tick_search(delta)
		State.RETURN:
			_tick_return(delta)
		State.INVESTIGATE:
			_tick_investigate(delta, band)
		State.SUSPICIOUS:
			_tick_suspicious(delta, band)
		_:
			if band == &"investigate" and _last_known_valid:
				state = State.INVESTIGATE
				_investigate_pos = _last_known
				_investigate_timer = 3.0
			elif band == &"suspicious" and _last_known_valid:
				state = State.SUSPICIOUS
			else:
				state = State.WORK
				_patrol(delta)


func _tick_suspicious(delta: float, band: StringName) -> void:
	velocity = Vector3.ZERO
	if _last_known_valid:
		var to := _last_known - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_facing = to.normalized()
			velocity = _facing * move_speed * suspect_speed_mult
	if band == &"calm":
		state = State.WORK
	elif band == &"investigate":
		state = State.INVESTIGATE
		_investigate_pos = _last_known
		_investigate_timer = 3.0


func _tick_investigate(delta: float, band: StringName) -> void:
	_investigate_timer -= delta
	_investigate_pos = _last_known if _last_known_valid else _investigate_pos
	_motor.set_target(_investigate_pos)
	_motor.speed = move_speed * 1.1
	velocity = _motor.tick_velocity(global_position)
	if _motor.arrived(global_position):
		velocity = Vector3.ZERO
		if not _investigate_glancing:
			_investigate_glancing = true
			_reset_look_around()
			_dwell_face0 = _facing
		_tick_look_around(delta, 0.75)
	else:
		_investigate_glancing = false
	if band == &"calm" or _investigate_timer <= 0.0:
		if _last_known_valid:
			_begin_search()
		else:
			state = State.WORK
			_investigate_glancing = false


func _tick_chase(delta: float, snap) -> void:
	if _seeing and snap.last_known_valid:
		_lose_sight_left = _params.lose_target_grace_sec
		_chase_toward(_last_known, delta, true)
		return
	_lose_sight_left -= delta
	if _lose_sight_left > 0.0 and _last_known_valid:
		## 看不見：追凍結的 last_known。
		_chase_toward(_last_known, delta, false)
	else:
		_begin_search()


func _chase_toward(pos: Vector3, delta: float, _live: bool) -> void:
	var to := pos - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= catch_range:
		_catch_hold += delta
		velocity = to.normalized() * move_speed * 0.45 if dist > 0.05 else Vector3.ZERO
		if _catch_hold >= catch_windup_sec:
			var victim := _find_animal_near(pos, catch_range + 0.4)
			if victim:
				Bus.interact_feedback.emit("工作人员抓住了 %s！" % victim.display_name())
				victim.capture_return_home(_detect_kind)
				_begin_recovery()
			else:
				## 感知位置已空 → 搜索，不作弊抓人。
				_begin_search()
		return
	_catch_hold = 0.0
	_motor.set_target(pos)
	_motor.speed = move_speed * chase_speed_mult
	velocity = _motor.tick_velocity(global_position)


func _begin_search() -> void:
	state = State.SEARCH
	_search_timer = _params.search_duration_sec
	_search_checked.clear()
	_search_points = _sample_search_points(_last_known if _last_known_valid else global_position)
	_search_index = 0
	_catch_hold = 0.0
	_telegraph_shown = false
	if _search_points.is_empty():
		_begin_return()
		return
	_motor.set_target(_search_points[0])


func _tick_search(delta: float) -> void:
	_search_timer -= delta
	if _seeing and awareness >= _params.chase_threshold and _telegraph_left <= 0.0:
		state = State.CHASE
		_lose_sight_left = _params.lose_target_grace_sec
		return
	if _search_timer <= 0.0 or _search_index >= _search_points.size():
		_begin_return()
		return
	_motor.speed = move_speed
	_motor.set_target(_search_points[_search_index])
	velocity = _motor.tick_velocity(global_position)
	if _motor.arrived(global_position):
		_search_checked.append(_search_points[_search_index])
		_search_index += 1
		velocity = Vector3.ZERO
		_reset_look_around()
		_dwell_face0 = _facing


func _begin_return() -> void:
	state = State.RETURN
	pending_heat_pos = _last_known if _last_known_valid else global_position
	pending_heat_amount = _params.return_heat_bonus
	if patrol_network:
		patrol_network.apply_heat_near(pending_heat_pos, pending_heat_amount)
	_return_target = _closest_patrol_point()
	_motor.set_target(_return_target)
	Bus.interact_feedback.emit("职员放弃搜索，回到岗位…")


func _tick_return(delta: float) -> void:
	_motor.speed = move_speed
	_motor.set_target(_return_target)
	velocity = _motor.tick_velocity(global_position)
	if _motor.arrived(global_position):
		awareness = maxf(0.0, awareness * 0.35)
		state = _resume_after_duty()
		if state == State.WORK:
			_pick_next_patrol_point(false)
			_patrol(delta)


func _sample_search_points(center: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	var r := _params.search_radius
	var offsets: Array[Vector3] = [
		Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r),
		Vector3(r * 0.7, 0, r * 0.7), Vector3(-r * 0.7, 0, r * 0.7),
		Vector3(r * 0.7, 0, -r * 0.7), Vector3(-r * 0.7, 0, -r * 0.7),
	]
	for o in offsets:
		var p := center + o
		p.y = center.y
		## 射線檢查：與中心之間無牆，避免搜進牆體另一側。
		if StaffSense.has_line_of_sight(space, center, p, [get_rid()]):
			var already := false
			for c in _search_checked:
				if c.distance_to(p) < 0.75:
					already = true
					break
			if not already:
				out.append(p)
	return out


func _closest_patrol_point() -> Vector3:
	if waypoints.is_empty():
		return global_position
	var best := waypoints[0]
	var best_d := INF
	for p in waypoints:
		var d := global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


func _find_animal_near(pos: Vector3, radius: float) -> AnimalActor:
	var best: AnimalActor = null
	var best_d := radius
	for node in get_tree().get_nodes_in_group("animals"):
		if not (node is AnimalActor):
			continue
		var a := node as AnimalActor
		if not a.is_rescued or a.is_confined:
			continue
		var d := a.global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = a
	return best


func _begin_recovery() -> void:
	_recovery_left = catch_recovery_sec
	_clear_combat_memory()
	awareness = 0.0
	state = _resume_after_duty()
	velocity = Vector3.ZERO


func _clear_combat_memory() -> void:
	_catch_hold = 0.0
	_lose_sight_left = 0.0
	_telegraph_shown = false
	_telegraph_left = 0.0
	_seeing = false
	_investigate_glancing = false
	_search_points.clear()
	_search_checked.clear()


func _try_discover_traces() -> void:
	## Only while actively looking around or investigating — not omniscient radar.
	if state != State.WORK and state != State.INVESTIGATE and state != State.SEARCH and state != State.SUSPICIOUS:
		return
	var found := TraceService.try_discover_near(get_tree(), global_position)
	if found:
		_last_known = found.global_position
		_last_known_valid = true
		_investigate_pos = found.global_position
		_investigate_timer = 3.0
		if state != State.CHASE and state != State.GUARD:
			state = State.INVESTIGATE
			awareness = maxf(awareness, _params.investigate_threshold if _params else 48.0)


func _on_bus_noise(position: Vector3, loudness: float, kind: StringName) -> void:
	if Clock.phase == Clock.Phase.NIGHT_QUIET:
		return
	if state == State.GUARD or state == State.REST or _recovery_left > 0.0:
		return
	if _params == null:
		return
	var max_r := _params.hear_noise_range * clampf(loudness, 0.15, 1.35)
	var dist := global_position.distance_to(position)
	if dist > max_r:
		return
	var falloff := 1.0 - dist / max_r
	## 腳步：只抬 awareness，近距才起疑；叫嚷／硬闖才強制調查。
	## 噪音本身永不 Alert.bump — 只改變職員行為。
	if kind == &"footstep":
		awareness = minf(
			_params.awareness_max,
			awareness + _params.hearing_awareness_spike * falloff * 0.4
		)
		if dist <= _params.hear_walk_range * 1.6 and state == State.WORK:
			state = State.SUSPICIOUS
			_last_known = position
			_last_known_valid = true
		return
	if state == State.CHASE:
		return
	alert_to_noise(position)


func alert_to_noise(at: Vector3) -> void:
	if Clock.phase == Clock.Phase.NIGHT_QUIET:
		return
	if state == State.GUARD or state == State.CHASE:
		return
	if _recovery_left > 0.0:
		return
	## 噪音只提供位置假設，不直接讀玩家 Node；立即進入調查以利可讀與測試。
	_last_known = at
	_last_known_valid = true
	_investigate_pos = at
	_investigate_timer = 3.5
	awareness = maxf(awareness, _params.investigate_threshold if _params else 48.0)
	state = State.INVESTIGATE
	if patrol_network:
		patrol_network.apply_heat_near(at, _params.return_heat_bonus * 0.5)
	Bus.interact_feedback.emit("职员听见异常声响，前去查看…")


## 舊測試相容：回傳當前感知到的動物（若有）。
func _scan_animals() -> AnimalActor:
	var snap = _sense_now()
	if not snap.last_known_valid:
		return null
	_detect_kind = snap.detect_kind
	return _find_animal_near(snap.last_known, 0.85)


func _guard_door_duty(_delta: float) -> void:
	var to := _guard_pos - global_position
	to.y = 0.0
	if to.length() > 0.4:
		velocity = to.normalized() * move_speed
	else:
		velocity = Vector3.ZERO
		if _guard_door:
			var face := _guard_door.global_position - global_position
			face.y = 0.0
			if face.length() > 0.1:
				_facing = face.normalized()


func _patrol(delta: float) -> void:
	if _use_network:
		_patrol_network(delta)
		return
	if waypoints.size() < 2:
		velocity = Vector3.ZERO
		return
	if _dwell_left > 0.0:
		_dwell_left -= delta
		velocity = Vector3.ZERO
		_tick_look_around(delta)
		return
	var target := waypoints[_wp_index]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.45:
		_arrive_waypoint_legacy()
		return
	velocity = to.normalized() * _patrol_move_speed()


func _patrol_network(delta: float) -> void:
	if patrol_network == null or patrol_network.points.is_empty():
		velocity = Vector3.ZERO
		return
	if _dwell_left > 0.0:
		_dwell_left -= delta
		velocity = Vector3.ZERO
		_tick_look_around(delta)
		if _dwell_left <= 0.0:
			_finish_patrol_dwell()
		return
	if not _motor.has_target():
		_pick_next_patrol_point(false)
	_motor.speed = _patrol_move_speed()
	velocity = _motor.tick_velocity(global_position)
	if _motor.arrived(global_position):
		_arrive_network_point()


func _pick_next_patrol_point(snap_pos: bool) -> void:
	if patrol_network == null or _params == null:
		return
	var sid := get_instance_id()
	if _patrol_point_id != &"":
		patrol_network.release(_patrol_point_id, sid)
	var pick := patrol_network.pick_next(
		global_position, sid, _params, _now_sec, _recent_point_ids, _patrol_point_id
	)
	if pick == null:
		return
	if not patrol_network.reserve(pick.id, sid):
		return
	_patrol_point_id = pick.id
	_motor.set_target(pick.position)
	if snap_pos:
		global_position = pick.position
		_arrive_network_point()


func _arrive_network_point() -> void:
	velocity = Vector3.ZERO
	var dwell_lo := _params.dwell_sec_min if _params else 3.0
	var dwell_hi := _params.dwell_sec_max if _params else 8.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_dwell_left = StaffAwarenessMath.bounded_rand(rng, dwell_lo, dwell_hi)
	_reset_look_around()
	_dwell_face0 = _facing if _facing.length() > 0.1 else Vector3(0, 0, 1)
	if patrol_network:
		for p in patrol_network.points:
			if p.id == _patrol_point_id:
				p.last_visited = _now_sec
				break
	_recent_point_ids.append(_patrol_point_id)
	while _recent_point_ids.size() > 3:
		_recent_point_ids.pop_front()


func _finish_patrol_dwell() -> void:
	if patrol_network:
		patrol_network.release(_patrol_point_id, get_instance_id())
	_pick_next_patrol_point(false)


func _arrive_waypoint_legacy() -> void:
	velocity = Vector3.ZERO
	_dwell_left = GameConst.STAFF_DWELL_SEC
	_reset_look_around()
	var next_i := _next_wp_index()
	var ahead := waypoints[next_i] - global_position
	ahead.y = 0.0
	if ahead.length() > 0.1:
		_dwell_face0 = ahead.normalized()
		_facing = _dwell_face0
	else:
		_dwell_face0 = _facing
	_wp_index = _next_wp_index()


func _reset_look_around() -> void:
	_look_phase = LookPhase.CENTER_HOLD
	_look_hold_left = look_center_hold_sec
	_look_yaw = 0.0


func _tick_look_around(delta: float, yaw_scale: float = 1.0) -> void:
	var max_yaw := deg_to_rad(look_around_yaw_deg * yaw_scale)
	var turn_step := deg_to_rad(look_turn_deg_per_sec) * delta
	match _look_phase:
		LookPhase.CENTER_HOLD:
			_look_hold_left -= delta
			if _look_hold_left <= 0.0:
				_look_phase = LookPhase.TURN_LEFT
		LookPhase.TURN_LEFT:
			_look_yaw = move_toward(_look_yaw, max_yaw, turn_step)
			if is_equal_approx(_look_yaw, max_yaw):
				_look_phase = LookPhase.LEFT_HOLD
				_look_hold_left = look_hold_sec
		LookPhase.LEFT_HOLD:
			_look_hold_left -= delta
			if _look_hold_left <= 0.0:
				_look_phase = LookPhase.TURN_RIGHT
		LookPhase.TURN_RIGHT:
			_look_yaw = move_toward(_look_yaw, -max_yaw, turn_step)
			if is_equal_approx(_look_yaw, -max_yaw):
				_look_phase = LookPhase.RIGHT_HOLD
				_look_hold_left = look_hold_sec
		LookPhase.RIGHT_HOLD:
			_look_hold_left -= delta
			if _look_hold_left <= 0.0:
				_look_phase = LookPhase.TURN_CENTER
		LookPhase.TURN_CENTER:
			_look_yaw = move_toward(_look_yaw, 0.0, turn_step)
			if is_equal_approx(_look_yaw, 0.0):
				_look_phase = LookPhase.CENTER_HOLD
				_look_hold_left = look_center_hold_sec * 0.6
	_facing = _dwell_face0.rotated(Vector3.UP, _look_yaw).normalized()


func _next_wp_index() -> int:
	return (_wp_index + _patrol_dir + waypoints.size()) % waypoints.size()


func _advance_waypoint() -> bool:
	var before := _wp_index
	_wp_index = _next_wp_index()
	if _patrol_dir > 0:
		return before > _wp_index
	return before < _wp_index


func _on_lap_complete() -> void:
	_lap_count += 1
	if _on_spur:
		_on_spur = false
		_switch_route(home_route_id, false)
		return
	var spur_every := _effective_spur_every()
	if spur_every > 0 and _lap_count % spur_every == 0:
		_take_next_spur()
		return
	if reverse_every_laps > 0 and _lap_count % reverse_every_laps == 0:
		_patrol_dir *= -1
		if announce_route_change:
			Bus.interact_feedback.emit("职员调头沿原路返回…")


func _effective_spur_every() -> int:
	var every := spur_every_laps
	every = maxi(1, every - Alert.level / 2)
	if Clock.phase == Clock.Phase.CLOSE or Clock.phase == Clock.Phase.NIGHT_PATROL:
		every = maxi(1, every - 1)
	return every


func _take_next_spur() -> void:
	var candidates: Array = []
	for id in route_book.keys():
		if id == home_route_id:
			continue
		candidates.append(id)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b): return String(a) < String(b))
	var pick: StringName = candidates[_spur_cursor % candidates.size()]
	_spur_cursor += 1
	_on_spur = true
	_switch_route(pick, false)
	if announce_route_change:
		Bus.interact_feedback.emit("职员改去巡查另一条路线…")


func _switch_route(id: StringName, snap_to_start: bool) -> void:
	if not route_book.has(id):
		return
	active_route_id = id
	var pts: Array = route_book[id]
	waypoints.clear()
	for p in pts:
		waypoints.append(p as Vector3)
	if waypoints.is_empty():
		return
	if snap_to_start:
		_wp_index = 0
		global_position = waypoints[0]
	else:
		_wp_index = _closest_wp_index()
	if _route_preview_on:
		_rebuild_route_preview()


func _closest_wp_index() -> int:
	var best_i := 0
	var best_d := INF
	for i in waypoints.size():
		var d := global_position.distance_squared_to(waypoints[i])
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _patrol_move_speed() -> float:
	var s := move_speed
	if Clock.phase == Clock.Phase.CLOSE:
		s *= 1.12
	elif Clock.phase == Clock.Phase.NIGHT_PATROL:
		s *= 1.06
	return s


func _rebuild_route_preview() -> void:
	if _route_node:
		_route_node.queue_free()
		_route_node = null
	_route_node = Node3D.new()
	_route_node.name = "PatrolRoute"
	var parent_n := get_parent()
	if parent_n:
		parent_n.add_child(_route_node)
	else:
		add_child(_route_node)
	if _use_network and patrol_network:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for p in patrol_network.points:
			var marker := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.45, 0.08, 0.45)
			marker.mesh = box
			marker.material_override = mat
			marker.position = p.position + Vector3(0, 0.06, 0)
			_route_node.add_child(marker)
		return
	var book := route_book if not route_book.is_empty() else {active_route_id: waypoints}
	if book.is_empty():
		return
	for id in book.keys():
		var route_id := StringName(id)
		var pts: Array = book[id]
		if pts.size() < 2:
			continue
		var is_active: bool = route_id == active_route_id
		var col := Color(1.0, 0.55, 0.15, 0.85) if is_active else Color(1.0, 0.75, 0.35, 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for i in pts.size():
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % pts.size()]
			var seg := MeshInstance3D.new()
			var box := BoxMesh.new()
			var len := a.distance_to(b)
			box.size = Vector3(0.14 if is_active else 0.10, 0.03, len)
			seg.mesh = box
			seg.material_override = mat
			seg.position = (a + b) * 0.5 + Vector3(0, 0.05 if is_active else 0.03, 0)
			seg.look_at_from_position(seg.position, Vector3(b.x, seg.position.y, b.z), Vector3.UP)
			_route_node.add_child(seg)


func _ensure_visual() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	_mesh.mesh = sphere
	_mesh.position = Vector3(0, 0.4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.15, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.1, 0.08)
	mat.emission_energy_multiplier = 0.45
	_mesh.material_override = mat
	add_child(_mesh)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	col.position = Vector3(0, 0.4, 0)
	add_child(col)
	_vision_mesh = MeshInstance3D.new()
	_vision_mesh.mesh = _build_vision_wedge_mesh()
	_vision_mat = StandardMaterial3D.new()
	_vision_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.28)
	_vision_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vision_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_vision_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vision_mesh.material_override = _vision_mat
	add_child(_vision_mesh)


func _build_vision_wedge_mesh() -> ArrayMesh:
	var half := deg_to_rad(vision_angle_deg * 0.5)
	var steps := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := Vector3(0, 0.06, 0)
	for i in steps:
		var a0 := -half + (2.0 * half) * (float(i) / float(steps))
		var a1 := -half + (2.0 * half) * (float(i + 1) / float(steps))
		var p0 := Vector3(sin(a0), 0.06, cos(a0)) * vision_range
		var p1 := Vector3(sin(a1), 0.06, cos(a1)) * vision_range
		st.add_vertex(origin)
		st.add_vertex(p0)
		st.add_vertex(p1)
	return st.commit()


func _update_vision_mesh() -> void:
	if _vision_mesh == null:
		return
	## 視錐嚴格跟 _facing（日後精靈也只讀此來源）。
	var yaw := atan2(_facing.x, _facing.z)
	_vision_mesh.rotation = Vector3(0, yaw, 0)
	_vision_mesh.position = Vector3.ZERO
	if _vision_mat == null:
		return
	match state:
		State.SUSPICIOUS:
			_vision_mat.albedo_color = Color(1.0, 0.85, 0.15, 0.42)
		State.CHASE:
			_vision_mat.albedo_color = Color(1.0, 0.12, 0.08, 0.48)
		State.INVESTIGATE, State.SEARCH:
			_vision_mat.albedo_color = Color(1.0, 0.55, 0.12, 0.34)
		State.RETURN:
			_vision_mat.albedo_color = Color(0.7, 0.7, 0.75, 0.25)
		_:
			_vision_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.28)


func _set_vision_visible(v: bool) -> void:
	if _vision_mesh:
		_vision_mesh.visible = v
