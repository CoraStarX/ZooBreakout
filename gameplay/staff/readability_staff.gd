class_name ReadabilityStaff
extends CharacterBody3D
## 沙盒局部編排。決策只讀感知結果／記憶；不接 Clock、Alert、拘留或玩家控制。
signal arrival_feedback
@export var params: StaffReadabilityParams
var sensor: Callable
var noise_sensor: Callable
var route: Array[Vector3] = []
var navigation_points: Array[Vector3] = []
var obstacles: Array[Dictionary] = []
var metrics: StaffReadabilityMetrics
var state: StringName = &"WORK"
var awareness: float = 0
var facing := Vector3.RIGHT
var polygon := PackedVector2Array()
var now: float = 0
var known: Dictionary = {}
var _route_index: int = 0
var _rest_pending: bool = false
var _rest_until: float = 0
var _warning_since: float = -INF
var _lost_since: float = -INF
var _search_start: float = -INF
var _search_deadline: float = -INF
var _search_extended: bool = false
var _search_memory: Dictionary = {}
var _cooldowns: Array[Dictionary] = []
var _arrival_until: float = 0
var _pause_until: float = 0
var _investigate_until: float = 0
var _motor := StaffMotor.new()
var _noise_contribution: float = 0
var _last_noise: Dictionary = {}
var _navigation_warning_until: float = 0
var _approach_source := Vector3.INF
var _approach_goal := Vector3.INF
var _state_since: float = 0
var _first_seen_at: float = -INF
var _last_seen_at: float = -INF
var _next_climb_noise_at: float = -INF

func _ready() -> void:
	metrics = StaffReadabilityMetrics.new(params)
	collision_layer = 4
	collision_mask = 1
	add_to_group("readability_staff")
	var shape := SphereShape3D.new()
	shape.radius = params.body_radius
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = params.body_radius
	add_child(col)
	_motor.arrive_distance = params.arrival_distance
	Bus.noise_made.connect(_on_noise)

func _physics_process(delta: float) -> void:
	step(delta)

func _change(next: StringName, cause: String) -> void:
	if state == next: return
	if state == &"REST": metrics.event(now,"rest_finished",{"cause":cause})
	if state == &"SEARCH" and next != &"RETURN": metrics.event(now,"search_interrupted",{"cause":cause})
	metrics.event(now,"state",{"from":str(state),"to":str(next),"cause":cause,"memory":known})
	state = next
	_state_since = now
	if next == &"CHASE": metrics.event(now,"chase_started",{"cause":cause,"memory":known,"first_seen":_first_seen_at if is_finite(_first_seen_at) else null})

func cooling(memory: Dictionary) -> bool:
	for entry in _cooldowns:
		if now < float(entry.until) and StaffPerceptionFootprint.same_source(memory.get("key",""),memory.get("projection",Vector3.ZERO),entry.key,entry.position,params): return true
	return false

func step(delta: float, supplied: Dictionary = {}) -> void:
	now += delta
	_cooldowns = _cooldowns.filter(func(entry: Dictionary) -> bool: return now < float(entry.until))
	polygon = StaffPerceptionFootprint.build(global_position,facing,obstacles,params)
	var sample: Dictionary = supplied if not supplied.is_empty() else (sensor.call() if sensor.is_valid() and state != &"REST" else {})
	var seeing := state != &"REST" and not sample.is_empty() and StaffPerceptionFootprint.contains(polygon,sample.projection)
	var visibility := 0.0
	var before := awareness
	var visual_kind := "無視覺接觸"
	var reason := "沒有目標快照"
	if state == &"REST": reason = "歇崗視覺關閉"
	elif not sample.is_empty():
		var full := StaffPerceptionFootprint.build(global_position,facing,[],params)
		reason = "視錐外" if not StaffPerceptionFootprint.contains(full,sample.projection) else ("可見" if seeing else "被建築遮擋")
	if seeing:
		if not is_finite(_first_seen_at) or now-_last_seen_at > params.ai.lose_target_grace_sec: _first_seen_at = now
		_last_seen_at = now
		visibility = StaffAwarenessMath.visibility_multiplier(params.ai,StaffPerceptionFootprint.flat(global_position).distance_to(StaffPerceptionFootprint.flat(sample.projection)),true,true,sample.speed,[params.climb_visibility_mult] if sample.climbing else [])
		visual_kind = "視覺＋攀爬暴露" if sample.climbing else "視覺"
		known = sample.duplicate(true)
		known["source"] = visual_kind
	awareness = StaffAwarenessMath.tick(awareness,delta,visibility,params.ai,_noise_contribution)
	var heard := _noise_contribution
	_noise_contribution = 0
	if state == &"REST":
		if now >= _rest_until: _change(&"WORK","歇崗結束")
	else:
		# 新的地面視覺立即中斷舊點掃視，但重新起算預警，不能靠舊警覺瞬間追捕。
		if StaffPerceptionFootprint.reacquire_ground(state,seeing,bool(sample.get("reachable",false))) and now >= _pause_until:
			# 重新給預警，但不能把持續視覺接觸的首次時間改成冷卻結束。
			_warning_since = now
			_investigate_until = now + params.investigate_sec
			_change(&"INVESTIGATE","重新看見地面目標")
		if awareness >= params.ai.suspicious_threshold and (seeing or not known.is_empty()) and _warning_since == -INF and not (not known.is_empty() and not bool(known.reachable) and cooling(known)):
			_warning_since = now
			if state in [&"WORK",&"RETURN"]: _change(&"SUSPICIOUS",visual_kind)
		# 高處搜索／同源冷卻不因同一輪廓重追；地面重新接觸仍需預警。
		var high_locked := seeing and not bool(sample.reachable) and (state == &"SEARCH" or cooling(sample))
		if seeing and not high_locked and awareness >= params.ai.chase_threshold and now - _warning_since >= maxf(0.5,params.ai.min_telegraph_sec) and now >= _pause_until and (state != &"INVESTIGATE" or now-_state_since >= params.investigate_stage_min_sec):
			_change(&"CHASE",visual_kind)
		if not seeing and awareness < params.ai.suspicious_threshold: _warning_since = -INF
	velocity = Vector3.ZERO
	if now >= _pause_until:
		match state:
			&"WORK": _patrol()
			&"REST": pass
			&"SUSPICIOUS":
				if awareness < params.ai.suspicious_threshold: _change(&"RETURN","警覺消退")
				elif awareness >= params.ai.investigate_threshold and not known.is_empty() and now - _warning_since >= params.warning_stage_sec:
					_investigate_until = now + params.investigate_sec
					_change(&"INVESTIGATE","確認最後感知位置")
			&"INVESTIGATE":
				if not known.is_empty():
					var target: Vector3 = known.projection if known.reachable else known.approach
					var arrived := _go(target)
					if seeing and bool(known.reachable):
						_investigate_until = now + params.investigate_sec
						if arrived:
							var offset: Vector3 = known.projection - global_position
							if not StaffPerceptionFootprint.flat(offset).is_zero_approx():
								var yaw := atan2(facing.x,facing.z)
								yaw = rotate_toward(yaw,atan2(offset.x,offset.z),deg_to_rad(params.ai.look_turn_deg_per_sec)*delta)
								facing = Vector3(sin(yaw),0,cos(yaw))
					elif arrived or (bool(known.reachable) and now >= _investigate_until):
						if not cooling(known): begin_search(known)
						else: _change(&"RETURN","同源搜索冷卻")
			&"CHASE": _chase(seeing)
			&"SEARCH":
				if now >= _search_deadline: abandon_search()
				elif not _search_memory.is_empty():
					_go(_search_memory.projection if _search_memory.reachable else _search_memory.approach)
					_turn_search(delta)
			&"RETURN":
				if not route.is_empty() and _go(route[_route_index]):
					awareness = minf(awareness,params.ai.suspicious_threshold)
					_warning_since = -INF
					_change(&"WORK","返回巡邏")
	move_and_slide()
	if velocity.length() > 0: facing = Vector3(velocity.x,0,velocity.z).normalized()
	metrics.sample(now,{"state":str(state),"before":before,"awareness":awareness,"visual":visual_kind,"reason":reason,"visibility_mult":visibility,"hearing_spike":heard,"last_noise":_last_noise,"projection":str(sample.get("projection","無")),"actual":str(sample.get("actual","無")),"memory_source":known.get("source","無"),"search_remaining":maxf(0,_search_deadline-now) if state == &"SEARCH" else 0.0,"cooling":cooling(known) if not known.is_empty() else false})

func _go(target: Vector3, chase: bool = false) -> bool:
	if StaffPerceptionFootprint.flat(global_position).distance_to(StaffPerceptionFootprint.flat(target)) <= params.arrival_distance: return true
	var hop := StaffPerceptionFootprint.approach_hop(global_position,target,navigation_points,obstacles,params.body_radius)
	if not hop.ok:
		if now >= _navigation_warning_until:
			metrics.event(now,"unreachable",{"target":str(target)})
			_navigation_warning_until = now + params.navigation_retry_sec
		return false
	if hop.goal != target and (_approach_source != target or _approach_goal != hop.goal):
		metrics.event(now,"approach_selected",{"target":str(target),"approach":str(hop.goal)})
	_approach_source = target
	_approach_goal = hop.goal
	if StaffPerceptionFootprint.flat(global_position).distance_to(StaffPerceptionFootprint.flat(hop.goal)) <= params.arrival_distance: return true
	_motor.set_target(hop.point)
	velocity = _motor.tick_velocity(global_position,params.ai.move_speed * (params.ai.chase_speed_mult if chase else 1.0))
	return false

func _patrol() -> void:
	if route.is_empty(): return
	if _rest_pending:
		_rest_pending = false
		_rest_until = now + params.rest_sec
		_change(&"REST","每圈歇崗")
		metrics.event(now,"rest_started",{"until":_rest_until})
		return
	if _go(route[_route_index]):
		_route_index = (_route_index + 1) % route.size()
		if _route_index == 0: _rest_pending = true

func _chase(seeing: bool) -> void:
	if now-_state_since < params.chase_stage_min_sec: return
	if known.is_empty(): _change(&"RETURN","無感知記憶"); return
	if seeing: _lost_since = -INF
	elif _lost_since == -INF: _lost_since = now
	if not seeing and now - _lost_since >= params.ai.lose_target_grace_sec:
		if cooling(known): _change(&"RETURN","同源搜索冷卻")
		elif known.reachable: begin_search(known)
		else:
			# 高處目標先接近合法牆下點；八秒搜索不能被路程吃掉。
			_change(&"INVESTIGATE","先接近牆下搜索點")
		return
	var target: Vector3 = known.projection if known.reachable else known.approach
	var arrived := _go(target,true)
	if not known.reachable and arrived:
		begin_search(known)
	elif known.reachable and seeing and global_position.distance_to(target) <= params.ai.catch_range and now >= _arrival_until:
		_arrival_until = now + params.arrival_cooldown_sec
		_pause_until = now + params.arrival_pause_sec
		metrics.event(now,"arrival",{"memory":known})
		arrival_feedback.emit()
		begin_search(known)

func begin_search(memory: Dictionary) -> void:
	if cooling(memory): _change(&"RETURN","同源搜索冷卻"); return
	_search_memory = memory.duplicate(true)
	_search_start = now
	_search_deadline = now + params.search_sec
	_search_extended = false
	_change(&"SEARCH","搜索最後感知位置")
	metrics.event(now,"search_started",{"deadline":_search_deadline,"memory":_search_memory})

func abandon_search() -> void:
	metrics.event(now,"search_abandoned",{"memory":_search_memory})
	_cooldowns.append({"until":now+params.search_cooldown_sec,"key":_search_memory.get("key",""),"position":_search_memory.get("projection",Vector3.ZERO)})
	_warning_since = -INF
	_change(&"RETURN","搜索到時放棄")

func _turn_search(delta: float) -> void:
	facing = facing.rotated(Vector3.UP,deg_to_rad(params.ai.look_turn_deg_per_sec) * delta)

func _on_noise(position: Vector3, loudness: float, kind: StringName) -> void:
	var resting := state == &"REST"
	if not StaffPerceptionFootprint.heard(global_position,position,loudness,resting,params): return
	if kind == &"climb":
		if not StaffPerceptionFootprint.noise_ready(now,_next_climb_noise_at): return
		_next_climb_noise_at = now + params.climb_noise_cooldown_sec
	var gain := StaffPerceptionFootprint.hearing_gain(global_position,position,loudness,resting,params)
	var memory: Dictionary = noise_sensor.call(position) if noise_sensor.is_valid() else {"projection":Vector3(position.x,params.ground_y,position.z),"reachable":position.y <= params.ground_height_tolerance,"approach":global_position,"key":""}
	memory["source"] = "聽覺：" + str(kind)
	_last_noise = {"position":str(position),"kind":str(kind),"during_rest":resting,"time":now,"reachable":memory.reachable,"key":memory.get("key",""),"support_y":memory.get("support_y","未提供"),"awareness_gain":gain}
	metrics.event(now,"heard",_last_noise)
	if resting: metrics.event(now,"rest_heard",_last_noise)
	_noise_contribution += gain
	# 搜索期間聽見高處聲音只延長一次，不能反覆重設起算時間。
	if state == &"SEARCH" and StaffPerceptionFootprint.can_extend_search(_search_memory,memory,params):
		if not _search_extended:
			_search_deadline = StaffPerceptionFootprint.extend_deadline(_search_start,_search_deadline,false,params)
			_search_extended = true
			metrics.event(now,"search_extended",{"deadline":_search_deadline,"source":memory.source})
		return
	if cooling(memory) or state == &"CHASE": return
	known = memory
	_warning_since = now if _warning_since == -INF else _warning_since
	_investigate_until = now + params.investigate_sec
	_change(&"INVESTIGATE",memory.source)

func icon() -> String:
	match state:
		&"REST": return "Zz\n休息（仍能聽見）"
		&"SUSPICIOUS": return "?"
		&"INVESTIGATE", &"SEARCH": return "!"
		&"CHASE": return "!!"
	return ""
