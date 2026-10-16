class_name TraversalActor
extends CharacterBody3D
## 本地移動狀態；場景接收事件呈現與統計，不依賴具體關卡或物種。
signal diagnostic_recorded(record: Dictionary)

signal feedback(message: String)
signal movement_event(tag: StringName, amount: float)
signal stepped(delta: float)
signal landed(height: float, loudness: float)

enum State { GROUNDED, AIRBORNE, JUMPING, CLIMBING, MANTLING, ATTACHING }
@export var params: TraversalParams = preload("res://content/traversal/traversal_params.tres")
@export var capabilities: Array[int] = [CapabilityIds.Id.CLIMB]
@export var camera: Camera3D
@export var input_enabled: bool = true

var state: State = State.GROUNDED
var edge_blocked: bool = false
var selected_link: TraversalLink
var selected_destination := Vector3.ZERO
var has_jump_preview: bool = false
var preview_is_drop: bool = false
var jump_refusal: String = "靠近有效邊緣後按 Space"
var surface: ClimbSurface
var facing := Vector3.RIGHT
var _shape: CapsuleShape3D
var _collision: CollisionShape3D
var _move_dir := Vector3.ZERO
var _intent_surface: ClimbSurface
var _intent_roof: bool = false
var _intent_left: float = 0.0
var _reattach_left: float = 0.0
var _needs_fresh_input: bool = false
var _released_input_seen: bool = false
var _release_toward := Vector3.ZERO
var _coyote_left: float = 0.0
var _coyote_link: TraversalLink
var _buffer_left: float = 0.0
var _buffer_kind: StringName = &""
var _jump_request: Dictionary = {}
var _preview_direction := Vector3.ZERO
var _release_pending: bool = false
var _selected_drop_points := PackedVector3Array()
var _buffer_pending: bool = false
var _peak_height: float = 0.0
var _intentional_fall: bool = false
var _air_time: float = 0.0
var _climb_distance: float = 0.0
var _blocked_time: float = 0.0
var _safe_positions: Array[Vector3] = []
var _safe_camera_height: float = 0.0
var _path_start := Vector3.ZERO
var _path_end := Vector3.ZERO
var _takeoff := Vector3.ZERO
var _path_points := PackedVector3Array()
var _path_tag: StringName = &""
var _path_final: State = State.GROUNDED
var _elapsed: float = 0.0
var _duration: float = 1.0
var _snap_sec: float = 0.0
var _arc: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = params.world_mask
	floor_snap_length = params.floor_snap
	safe_margin = params.body_safe_margin
	add_to_group("controlled")
	_shape = CapsuleShape3D.new()
	_shape.radius = params.radius
	_shape.height = params.height
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	_collision.position.y = params.height * 0.5
	add_child(_collision)
	_peak_height = global_position.y
	_safe_camera_height = global_position.y

func camera_focus_height() -> float:
	return _safe_camera_height

func _physics_process(delta: float) -> void:
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	step(delta, axes, input_enabled and Input.is_action_just_pressed("traversal_jump"))
	# E 僅保留互動語意；試驗場沒有取物或對話，不再用它改變移動狀態。
	if input_enabled and Input.is_action_just_pressed("interact"):
		if not _input_history.is_empty(): _input_history[-1]["e"] = true
		record_diagnostic("invalid", "E：此處沒有互動物件")
		movement_event.emit(&"invalid", 1.0)
		feedback.emit("此處沒有互動物件；移動只需方向鍵與 Space")

var _last_path_collision: Dictionary = {}
var _selection_diagnostics: Array[Dictionary] = []
var _diagnostic_time: float = 0.0
var _input_history: Array[Dictionary] = []

func record_diagnostic(kind: String, reason: String = "") -> void:
	var points: Array[Dictionary] = []
	for point in _safe_positions:
		points.append({"position": str(point), "legal": _legal_recovery(point)})
	var record := {"kind": kind, "reason": reason, "time": _diagnostic_time,
		"position": str(global_position), "state": State.keys()[state],
		"direction": str(_move_dir), "surface": str(surface.get_path()) if is_instance_valid(surface) else "none",
		"target": str(selected_link.get_path()) if is_instance_valid(selected_link) else "none",
		"landing": str(selected_destination), "preview": has_jump_preview, "refusal": jump_refusal,
		"path_tag": str(_path_tag), "path_elapsed": _elapsed, "path_duration": _duration,
		"path_collision": _last_path_collision.duplicate(true), "takeoff": str(_takeoff), "snap_sec": _snap_sec,
		"path_start": str(_path_start), "path_end": str(_path_end), "path_points": str(_path_points),
		"candidates": _selection_diagnostics.duplicate(true),
		"request_kind": str(_buffer_kind), "request_landing": str(_jump_request.get("landing", "none")),
		"release_pending": _release_pending, "buffer": _buffer_left, "coyote": _coyote_left, "blocked_sec": _blocked_time,
		"inputs": _input_history.duplicate(true), "safe_candidates": points}
	diagnostic_recorded.emit(record)

func step(delta: float, axes: Vector2, space_pressed: bool = false) -> void:
	_move_dir = camera_direction(axes)
	_diagnostic_time += delta
	_input_history.append({"time": _diagnostic_time, "axes": str(axes), "space": space_pressed, "e": false,
		"position": str(global_position), "state": State.keys()[state]})
	while not _input_history.is_empty() and (_input_history.size() > params.diagnostic_input_limit or _diagnostic_time - float(_input_history[0]["time"]) > params.diagnostic_input_sec):
		_input_history.pop_front()
	if space_pressed:
		record_diagnostic("space_pressed")
	collision_mask = params.world_mask
	floor_snap_length = params.floor_snap
	safe_margin = params.body_safe_margin
	if _move_dir.length() > params.input_deadzone:
		facing = _move_dir.normalized()
	_reattach_left = maxf(0.0, _reattach_left - delta)
	if _needs_fresh_input and (_move_dir.length() <= params.input_deadzone or not TraversalMath.intent_matches(_move_dir, _release_toward, params.attach_intent_degrees)):
		_released_input_seen = true
	edge_blocked = false
	if space_pressed:
		if state == State.CLIMBING:
			_release_wall()
			record_diagnostic("space_consumed", "掛牆放手")
		elif state == State.ATTACHING:
			# 放手不是跳躍緩衝：附牆過渡完成便執行，不受 0.1 秒落地窗限制。
			_release_pending = true
			record_diagnostic("release_queued", "附牆完成後放手")
		else:
			# 成功消耗前不記無效輸入；只有緩衝到期才結算一次。
			if _buffer_pending:
				record_diagnostic("invalid", "重複 Space 覆蓋尚未消耗的緩衝")
				movement_event.emit(&"invalid", 1.0)
			_jump_request = _capture_preview() if has_jump_preview and state in [State.GROUNDED, State.AIRBORNE] else {}
			_buffer_kind = (&"drop" if preview_is_drop else &"gap") if not _jump_request.is_empty() else _edge_intent(_move_dir)
			_buffer_pending = true
			_buffer_left = params.jump_buffer_sec
			record_diagnostic("action_locked" if not _jump_request.is_empty() else "action_buffered", str(_buffer_kind))
	# 已有預覽的請求先從當前位置起跳，避免斜坡上先走一幀使起點降高、舊路徑隨即失效。
	if _buffer_pending and not _jump_request.is_empty() and state in [State.GROUNDED, State.AIRBORNE]:
		_consume_buffered_jump()
	var before := global_position
	match state:
		State.JUMPING, State.MANTLING, State.ATTACHING:
			_step_path(delta)
		State.CLIMBING:
			_step_climb(delta, axes)
		State.GROUNDED, State.AIRBORNE:
			_step_ground(delta)
	if _release_pending and state == State.CLIMBING:
		_release_wall()
		record_diagnostic("space_consumed", "已執行過渡中放手請求")
	elif _release_pending and state != State.ATTACHING:
		_release_pending = false
	if state == State.GROUNDED:
		remember_safe_position()
	if state in [State.GROUNDED, State.AIRBORNE]:
		refresh_selection(_move_dir)
		if _buffer_pending: _consume_buffered_jump()
	# 明確的 Space 行動優先於自動掛牆，避免同一幀被掛牆過渡吃掉按鍵。
	if state == State.GROUNDED and not _buffer_pending:
		_auto_attach(delta)
	if _buffer_pending:
		_buffer_left -= delta
		if _buffer_left < 0.0:
			record_diagnostic("invalid", jump_refusal if state in [State.GROUNDED, State.AIRBORNE] else "過早按 Space：仍在過渡／離落地超過緩衝窗")
			_buffer_pending = false
			_jump_request.clear()
			_buffer_kind = &""
			movement_event.emit(&"invalid", 1.0)
			feedback.emit(jump_refusal if state in [State.GROUNDED, State.AIRBORNE] else "此時不能跳躍；接近落地時可提早按 Space")
	if state not in [State.JUMPING]:
		_safe_camera_height = global_position.y
	_watch_stuck(delta, before)
	stepped.emit(delta)

func _consume_buffered_jump() -> bool:
	if not try_jump(): return false
	record_diagnostic("space_consumed")
	_buffer_pending = false
	_buffer_left = 0.0
	_jump_request.clear()
	_buffer_kind = &""
	return true

func _step_ground(delta: float) -> void:
	var was_grounded := state == State.GROUNDED
	var before := global_position
	var protect := was_grounded and params.edge_guard_enabled and not _walk_floor(before, params.edge_ground_clearance).is_empty()
	var requested := _move_dir * params.speed
	var allowed := _guard_walk(requested, delta) if protect else requested
	edge_blocked = not allowed.is_equal_approx(requested)
	velocity.x = allowed.x
	velocity.z = allowed.z
	velocity.y = -params.gravity * delta if is_on_floor() else velocity.y - params.gravity * delta
	move_and_slide()
	if protect and not _walk_footprint(global_position):
		global_position = before
		velocity = Vector3.ZERO
		edge_blocked = not requested.is_zero_approx()
	var grounded := is_on_floor() or supported(global_position)
	if grounded:
		# 接地交由引擎安全邊距；逐幀抬升會與 floor snap 互相抵消。
		if not was_grounded:
			_finish_landing()
			if _intentional_fall and _needs_fresh_input:
				# 放手防吸回只限制空中；落地後持續朝牆也能重新累積意圖。
				_needs_fresh_input = false
				_released_input_seen = false
				_intent_left = 0.0
				_intent_surface = null
		state = State.GROUNDED
		_air_time = 0.0
		_intentional_fall = false
		_coyote_left = params.coyote_sec
		if is_instance_valid(selected_link):
			_coyote_link = selected_link
	else:
		if was_grounded:
			state = State.AIRBORNE
			_peak_height = before.y
		_peak_height = maxf(_peak_height, global_position.y)
		_coyote_left = maxf(0.0, _coyote_left - delta)
		_air_time += delta
		if _air_time >= params.recovery_timeout_sec:
			recover_to_safe("下落超時，已嘗試返回安全位置")

func _separate_ground_contact() -> bool:
	var space := get_world_3d().direct_space_state
	if space.intersect_shape(query_at(global_position), 1).is_empty(): return false
	if deeply_embedded(global_position) or not supported(global_position): return false
	var target := global_position + Vector3.UP * params.ground_contact_lift
	if not supported(target) or not space.intersect_shape(query_at(target), 1).is_empty(): return false
	# 只嘗試物理可走的短向上位移；頭頂障礙仍會擋住，深陷不走這條正常接觸修正。
	var before := global_position
	move_and_collide(target - global_position, false, safe_margin)
	var clear := space.intersect_shape(query_at(global_position), 1).is_empty()
	if clear: record_diagnostic("contact_separated", "微量接觸分離：%s → %s" % [before, global_position])
	return clear

func camera_direction(axes: Vector2) -> Vector3:
	if camera == null:
		return Vector3(axes.x, 0.0, axes.y)
	var right := camera.global_basis.x
	var back := camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	return (right.normalized() * axes.x + back.normalized() * axes.y).limit_length()

func _auto_attach(delta: float) -> void:
	if _reattach_left > 0.0 or (_needs_fresh_input and not _released_input_seen):
		_intent_left = 0.0
		return
	var best: ClimbSurface
	var roof := false
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("climb_surfaces"):
		var wall := node as ClimbSurface
		if not capabilities.has(wall.required_capability):
			continue
		var local := wall.to_local(global_position)
		if absf(local.x) > wall.width * 0.5 - params.radius:
			continue
		var is_roof := absf(local.y - wall.height) <= params.support_depth and local.z <= params.radius
		var toward := wall.global_basis.z if is_roof else -wall.global_basis.z
		if not TraversalMath.intent_matches(_move_dir, toward, params.attach_intent_degrees):
			continue
		var distance: float
		if is_roof:
			distance = absf(local.z)
			if distance > params.roof_attach_range:
				continue
		else:
			distance = global_position.distance_to(wall.anchor(global_position, params))
			if local.z <= 0.0 or distance > params.attach_range:
				continue
		if distance < best_distance:
			best_distance = distance
			best = wall
			roof = is_roof
	if best == null:
		_intent_surface = null
		_intent_left = 0.0
		return
	if best != _intent_surface or roof != _intent_roof:
		_intent_left = 0.0
	_intent_surface = best
	_intent_roof = roof
	_intent_left = TraversalMath.intent_time(_intent_left, true, delta)
	if _intent_left + 0.00001 < params.attach_intent_sec:
		return
	_separate_ground_contact()
	surface = best
	var destination := best.anchor(global_position, params)
	var points := PackedVector3Array([global_position, destination])
	if roof:
		var local := best.to_local(destination)
		local.y = best.height + params.landing_lift
		var outside_top := best.to_global(local)
		local.y -= params.roof_hang_depth
		destination = best.to_global(local)
		points = PackedVector3Array([global_position, outside_top, destination])
	if not polyline_clear(points):
		feedback.emit("掛牆通路受阻；可橫移或後退")
		return
	_needs_fresh_input = false
	_released_input_seen = false
	_intent_left = 0.0
	_begin_polyline(points, params.roof_transition_sec if roof else params.attach_transition_sec, State.CLIMBING, &"roof_down" if roof else &"attach", State.ATTACHING)
	movement_event.emit(&"return_wall" if roof else &"attach_start", 0.0)
	feedback.emit("正在下牆；W/S 上下、Space 放手" if roof else "正在附牆；W/S 上下、Space 放手")

func _step_climb(delta: float, axes: Vector2) -> void:
	if not is_instance_valid(surface):
		recover_to_safe("攀爬面失效，返回安全位置")
		return
	var right := camera.global_basis.x if camera else Vector3.RIGHT
	var screen_sign := 1.0 if surface.global_basis.x.dot(right) >= 0.0 else -1.0
	var local := surface.to_local(global_position)
	local.x += axes.x * screen_sign * params.climb_speed * delta
	local.y -= axes.y * params.climb_speed * delta
	var before := global_position
	move_and_collide(surface.anchor(surface.to_global(local), params) - global_position)
	_climb_distance += before.distance_to(global_position)
	if _climb_distance >= params.climb_noise_interval_m:
		_climb_distance = 0.0
		Bus.noise_made.emit(global_position, params.climb_noise, &"climb")
	var current := surface.to_local(global_position)
	if axes.y < -params.input_deadzone and current.y >= surface.height + params.landing_lift - params.arrival_tolerance:
		current.y = surface.height + params.landing_lift
		current.z = -params.mantle_depth
		var destination := surface.to_global(current)
		if supported(destination) and path_clear(global_position, destination, params.mantle_arc):
			_begin_arc(destination, params.mantle_duration, params.mantle_arc, State.MANTLING, &"roof")
		else:
			feedback.emit("平台受阻；請橫移或下降")
	elif axes.y > params.input_deadzone and current.y <= params.landing_lift + params.arrival_tolerance and supported(global_position):
		state = State.GROUNDED
		surface = null
		_reattach_left = params.reattach_delay
		movement_event.emit(&"climb_bottom", 0.0)
		feedback.emit("已到達地面")

func _release_wall() -> void:
	_jump_request.clear()
	_buffer_kind = &""
	_release_pending = false
	_intentional_fall = true
	_peak_height = global_position.y
	_coyote_left = 0.0
	_coyote_link = null
	_buffer_pending = false
	_needs_fresh_input = true
	_released_input_seen = false
	_reattach_left = params.reattach_delay
	_intent_left = 0.0
	if is_instance_valid(surface):
		_release_toward = -surface.global_basis.z
		var pushed := global_position + surface.global_basis.z * params.release_push_distance
		if segment_clear(global_position, pushed):
			global_position = pushed
	surface = null
	state = State.AIRBORNE
	velocity = Vector3.ZERO
	_air_time = 0.0
	movement_event.emit(&"return_release", 0.0)
	feedback.emit("已放手；落地並結束冷卻後，持續朝牆即可再攀爬")

func locked_landing() -> Vector3:
	return _path_end

func refresh_selection(direction: Vector3) -> void:
	if _buffer_pending and not _jump_request.is_empty():
		# 緩衝期間顯示的也是同一份請求；不讓畫面換點、執行卻走舊點。
		selected_link = _jump_request["link"] as TraversalLink if is_instance_valid(_jump_request["link"]) else null
		selected_destination = _jump_request["landing"]
		preview_is_drop = _jump_request["kind"] == &"drop"
		_selected_drop_points = _jump_request["points"]
		has_jump_preview = true
		return
	_selection_diagnostics.clear()
	_selected_drop_points.clear()
	var previous_drop := preview_is_drop
	var previous := selected_link
	selected_link = null
	selected_destination = Vector3.ZERO
	has_jump_preview = false
	preview_is_drop = false
	jump_refusal = "靠近有效邊緣後按 Space"
	var coyote := state == State.AIRBORNE and not _intentional_fall and TraversalMath.window_valid(_coyote_left)
	if state != State.GROUNDED and not coyote:
		return
	var links := get_tree().get_nodes_in_group("traversal_links")
	var scores: Array[float] = []
	var destinations: Array[Vector3] = []
	var old := -1
	for i in links.size():
		var link := links[i] as TraversalLink
		var takeoff := link.takeoff_near(global_position)
		var destination := link.destination_near(global_position)
		var rejection := TraversalMath.jump_rejection(global_position, takeoff, destination, params)
		var score := TraversalMath.jump_score(global_position, direction, takeoff, destination, params)
		if coyote and link != _coyote_link:
			rejection = "非土狼時間快取目標"
			score = -INF
		if link == previous:
			old = i
		var start := global_position if coyote else takeoff
		if not capabilities.has(link.required_capability):
			rejection = "缺少能力"
			score = -INF
		elif is_finite(score):
			if not supported(destination) or not path_clear(start, destination, params.jump_arc):
				score = -INF
				jump_refusal = "跳躍路徑或落點受阻"
				rejection = jump_refusal
			elif not coyote and (not segment_clear(global_position, takeoff) or not _walk_path_safe(global_position, takeoff - global_position)):
				score = -INF
				jump_refusal = "無法安全靠近起跳邊緣"
				rejection = jump_refusal
		_selection_diagnostics.append({"target": str(link.get_path()), "takeoff": str(takeoff), "landing": str(destination), "distance": global_position.distance_to(takeoff), "range": params.takeoff_range, "reason": rejection})
		scores.append(score)
		destinations.append(destination)
	var intent := _buffer_kind if _buffer_pending else _edge_intent(direction, previous_drop and not _preview_direction.is_zero_approx())
	var intent_direction := _preview_direction if direction.is_zero_approx() and previous_drop else direction
	var drop := _drop_candidate(intent_direction)
	_selection_diagnostics.append({"kind": "drop", "intent": str(intent), "reason": drop["reason"], "probe": drop.get("probe", "none"), "landing": drop.get("landing", "none"), "obstruction": drop.get("obstruction", {})})
	# 先決定動作種類，合法性失敗只能拒絕，絕不能退而選另一種動作。
	if intent == &"drop":
		var points: PackedVector3Array = drop["points"]
		if not points.is_empty():
			_selected_drop_points = points
			selected_destination = points[-1]
			has_jump_preview = true
			preview_is_drop = true
			_preview_direction = intent_direction
		else:
			jump_refusal = "無法下行：" + str(drop["reason"])
	else:
		var chosen := TraversalMath.choose(scores, old, params.selection_hysteresis)
		if chosen >= 0:
			selected_link = links[chosen] as TraversalLink
			selected_destination = destinations[chosen]
			has_jump_preview = true
			_preview_direction = direction
		else:
			jump_refusal = "無法跨越：靠近黃色邊緣；若已靠近，請確認路徑與落點未受阻"

func _edge_distance(direction: Vector3, origin: Vector3) -> float:
	var steps := maxi(1, ceili(params.edge_intent_probe_distance / params.edge_path_step))
	for i in range(1, steps + 1):
		var distance := minf(float(i) * params.edge_path_step, params.edge_intent_probe_distance)
		if not _walk_footprint(origin + direction * distance): return distance
	return INF

func _edge_intent(direction: Vector3, keep_drop: bool = false) -> StringName:
	if state == State.AIRBORNE and not _intentional_fall and TraversalMath.window_valid(_coyote_left) and is_instance_valid(_coyote_link): return &"gap"
	if direction.length() <= params.input_deadzone: return &"drop" if keep_drop else &"gap"
	var origin := _path_end if state in [State.JUMPING, State.MANTLING] else global_position
	var nearest: TraversalLink
	var distance := INF
	for node in get_tree().get_nodes_in_group("traversal_links"):
		var link := node as TraversalLink
		var takeoff := link.takeoff_near(origin)
		# 先排除不同高度／遠處入口，避免斜坡側緣被屋頂跳點誤認成跨越。
		if not TraversalMath.cross_context_valid(origin, takeoff, params): continue
		var candidate_distance := origin.distance_to(takeoff)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = link
	if not is_instance_valid(nearest): return &"drop"
	var across_direction := nearest.destination_near(origin) - nearest.takeoff_near(origin)
	across_direction.y = 0
	across_direction = across_direction.normalized()
	var tangent := Vector3(-across_direction.z, 0, across_direction.x)
	var across := direction.normalized().dot(across_direction)
	var along := direction.normalized().dot(tangent)
	var side_direction := tangent if along >= 0 else -tangent
	var cross_intent: bool
	if across < cos(deg_to_rad(params.cross_intent_degrees)) or absf(along) <= params.input_deadzone:
		cross_intent = TraversalMath.wants_cross(across, absf(along), INF, INF, params)
	else:
		cross_intent = TraversalMath.wants_cross(across, absf(along), _edge_distance(across_direction, origin), _edge_distance(side_direction, origin), params)
	return &"gap" if cross_intent else &"drop"

func _drop_candidate(direction: Vector3) -> Dictionary:
	var result := {"points": PackedVector3Array(), "reason": ""}
	if not capabilities.has(CapabilityIds.Id.CLIMB):
		result["reason"] = "缺少攀爬才能"
		return result
	if state != State.GROUNDED or direction.length() <= params.input_deadzone:
		result["reason"] = "請站穩並朝平台外側移動"
		return result
	if not edge_blocked and _walk_path_safe(global_position, direction.normalized() * params.drop_preview_distance):
		result["reason"] = "尚未接近可下行邊緣"
		return result
	var outside := global_position + direction.normalized() * params.drop_forward_distance
	result["probe"] = str(outside)
	var query := PhysicsRayQueryParameters3D.create(outside + Vector3.UP * params.landing_lift,
		outside + Vector3.DOWN * params.drop_max_height, params.world_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		result["reason"] = "允許落差內沒有下方地面"
		return result
	if (hit["normal"] as Vector3).y < params.support_normal_min:
		result["reason"] = "下方表面太陡，不能站立"
		return result
	var destination: Vector3 = hit["position"] + Vector3.UP * params.landing_lift
	result["landing"] = str(destination)
	if global_position.y - destination.y <= params.edge_max_drop:
		result["reason"] = "前方仍是可步行地面，請直接走下"
		return result
	if not supported(destination):
		result["reason"] = "下方落點支撐不足"
		return result
	outside.y = global_position.y + params.drop_lift
	var points := PackedVector3Array([global_position, outside, destination])
	var obstruction := polyline_obstruction(points)
	if not obstruction.is_empty():
		result["obstruction"] = obstruction
		result["reason"] = "下行通路受牆面或斜坡阻擋；請沿邊橫移"
		return result
	result["points"] = points
	return result

func _drop_points() -> PackedVector3Array:
	return _drop_candidate(_move_dir)["points"]

func _capture_preview() -> Dictionary:
	return {"kind": &"drop" if preview_is_drop else &"gap", "landing": selected_destination,
		"link": selected_link, "points": _selected_drop_points.duplicate(),
		"takeoff": selected_link.takeoff_near(global_position) if is_instance_valid(selected_link) else global_position}

func try_jump() -> bool:
	var coyote := state == State.AIRBORNE and not _intentional_fall and TraversalMath.window_valid(_coyote_left)
	if state != State.GROUNDED and not coyote: return false
	var request := _jump_request
	if request.is_empty():
		refresh_selection(_move_dir)
		if not has_jump_preview: return false
		request = _capture_preview()
		if _buffer_pending: _jump_request = request
	# 執行只重新驗證鎖定的路徑與落點；Space 後不再重選動作或移動落點。
	var destination: Vector3 = request["landing"]
	if request["kind"] == &"drop":
		var points: PackedVector3Array = request["points"].duplicate()
		points[0] = global_position
		if state != State.GROUNDED or not capabilities.has(CapabilityIds.Id.CLIMB) or global_position.y - destination.y > params.drop_max_height or global_position.y - destination.y <= params.edge_max_drop or not supported(destination) or not polyline_clear(points):
			jump_refusal = "下行預覽已受阻；請沿邊橫移後重新按 Space"
			has_jump_preview = false
			return false
		_intentional_fall = true
		_peak_height = global_position.y
		_begin_polyline(points, params.drop_duration, State.GROUNDED, &"drop", State.JUMPING)
		movement_event.emit(&"return_drop", 0.0)
	else:
		var link := request["link"] as TraversalLink if is_instance_valid(request["link"]) else null
		var takeoff: Vector3 = global_position if coyote else request["takeoff"]
		if not is_instance_valid(link) or not capabilities.has(link.required_capability) or (coyote and link != _coyote_link):
			jump_refusal = "跨越目標已失效；請重新選擇"
			has_jump_preview = false
			return false
		if not TraversalMath.jump_rejection(global_position, takeoff, destination, params).is_empty() or not supported(destination) or not path_clear(takeoff, destination, params.jump_arc) or (not coyote and (global_position.distance_to(takeoff) > params.takeoff_range or not segment_clear(global_position, takeoff) or not _walk_path_safe(global_position, takeoff - global_position))):
			jump_refusal = "跨越預覽已受阻或超出範圍；請靠近後重新按 Space"
			has_jump_preview = false
			return false
		_intentional_fall = false
		_peak_height = global_position.y
		_begin_arc(destination, params.jump_duration, params.jump_arc, State.JUMPING, &"gap")
		_takeoff = takeoff
		_snap_sec = params.jump_snap_sec if global_position.distance_to(takeoff) > params.jump_snap_min_distance else 0.0
		_duration += _snap_sec
	_coyote_left = 0.0
	_coyote_link = null
	_reattach_left = params.reattach_delay
	Bus.noise_made.emit(global_position, params.jump_noise, &"jump")
	has_jump_preview = false
	selected_link = null
	return true

func _begin_arc(destination: Vector3, seconds: float, arc: float, next_state: State, tag: StringName) -> void:
	_last_path_collision.clear()
	_path_start = global_position
	_takeoff = global_position
	_path_end = destination
	_path_points = PackedVector3Array()
	_elapsed = 0.0
	_duration = maxf(seconds, 0.001)
	_snap_sec = 0.0
	_arc = arc
	_path_final = State.GROUNDED
	_path_tag = tag
	_safe_camera_height = global_position.y
	velocity = Vector3.ZERO
	state = next_state

func _begin_polyline(points: PackedVector3Array, seconds: float, final_state: State, tag: StringName, next_state: State) -> void:
	_begin_arc(points[-1], seconds, 0.0, next_state, tag)
	_path_points = points
	_path_final = final_state

func _motion_point(time: float) -> Vector3:
	if not _path_points.is_empty():
		return TraversalMath.polyline_point(_path_points, time / _duration)
	if _snap_sec > 0.0 and time < _snap_sec:
		return _path_start.lerp(_takeoff, smoothstep(0.0, _snap_sec, time))
	return TraversalMath.arc_point(_takeoff, _path_end, (time - _snap_sec) / (_duration - _snap_sec), _arc)

func _step_path(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, _duration)
	var next := _motion_point(_elapsed)
	var hit := move_and_collide(next - global_position)
	_peak_height = maxf(_peak_height, global_position.y)
	if hit:
		var collider := hit.get_collider() as Node
		_last_path_collision = {"collider": str(collider.get_path()) if is_instance_valid(collider) else "unknown", "position": str(hit.get_position()), "normal": str(hit.get_normal()), "travel": str(hit.get_travel()), "remainder": str(hit.get_remainder())}
		if _path_tag == &"gap" or _path_tag == &"drop":
			movement_event.emit(&"jump_interrupted", 1.0)
		recover_to_safe("移動路徑被擋，返回安全位置")
		return
	if _elapsed >= _duration:
		state = _path_final
		if state == State.GROUNDED:
			if _path_tag in [&"gap", &"drop"]:
				_finish_landing()
			elif _path_tag == &"roof":
				movement_event.emit(&"roof", 0.0)
			_reattach_left = params.reattach_delay
			surface = null
			remember_safe_position()
		else:
			_climb_distance = 0.0
		_safe_camera_height = global_position.y

func _finish_landing() -> void:
	var height := maxf(0.0, _peak_height - global_position.y)
	var loudness := TraversalMath.landing_loudness(height, params)
	if loudness > 0.0:
		Bus.noise_made.emit(global_position, loudness, &"landing")
	landed.emit(height, loudness)
	if state == State.AIRBORNE and not _intentional_fall and height >= params.accidental_fall_height:
		movement_event.emit(&"accidental_fall", 1.0)
	if _path_tag == &"gap" and state != State.AIRBORNE:
		movement_event.emit(&"gap", 0.0)
	_peak_height = global_position.y
	_air_time = 0.0

func polyline_clear(points: PackedVector3Array) -> bool:
	return polyline_obstruction(points).is_empty()

func remember_safe_position() -> void:
	if not supported(global_position) or not get_world_3d().direct_space_state.intersect_shape(query_at(global_position), 1).is_empty():
		return
	if _safe_positions.is_empty() or global_position.distance_to(_safe_positions[-1]) >= params.safe_history_spacing:
		_safe_positions.append(global_position)
		if _safe_positions.size() > params.safe_history_limit:
			_safe_positions.pop_front()

func recover_to_safe(reason: String) -> bool:
	record_diagnostic("recovery", reason)
	movement_event.emit(&"recovery", 1.0)
	var candidates := _safe_positions.duplicate()
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(global_position) < b.distance_squared_to(global_position))
	for candidate in candidates:
		if _legal_recovery(candidate):
			_finish_recovery(candidate, reason)
			return true
	for i in maxi(params.recovery_sample_count, 1):
		var angle := TAU * float(i) / maxi(params.recovery_sample_count, 1)
		var point := global_position + Vector3(cos(angle), 0.0, sin(angle)) * params.recovery_sample_radius
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * params.height, point + Vector3.DOWN * params.recovery_probe_depth, params.world_mask, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var target: Vector3 = hit["position"] + Vector3.UP * params.landing_lift
			if _legal_recovery(target):
				_finish_recovery(target, reason)
				return true
	record_diagnostic("recovery_failed", "無合法歷史點或採樣點")
	feedback.emit("沒有合法恢復位置；請重新啟動測試場景")
	return false

func _legal_recovery(point: Vector3) -> bool:
	return supported(point) and get_world_3d().direct_space_state.intersect_shape(query_at(point), 1).is_empty()

func _finish_recovery(point: Vector3, reason: String) -> void:
	_jump_request.clear()
	_buffer_kind = &""
	_release_pending = false
	record_diagnostic("recovery_selected", str(point))
	global_position = point
	velocity = Vector3.ZERO
	state = State.GROUNDED
	surface = null
	_buffer_pending = false
	_blocked_time = 0.0
	_air_time = 0.0
	_needs_fresh_input = true
	_released_input_seen = false
	_reattach_left = params.reattach_delay
	feedback.emit(reason)

func _watch_stuck(delta: float, before: Vector3) -> void:
	# 在安全邊緣等候、掛牆不動、牆頂受阻可下降，都不是「卡住」。
	# 表面微量接觸不等於陷入牆內；否則正常滑動也會被誤判並強制傳送。
	var embedded := deeply_embedded(global_position)
	var wanted := embedded or state in [State.JUMPING, State.MANTLING, State.ATTACHING] or (state == State.AIRBORNE and _move_dir.length() > params.input_deadzone)
	var slow := embedded or before.distance_to(global_position) < params.stuck_speed * delta
	_blocked_time = _blocked_time + delta if wanted and slow and not edge_blocked else 0.0
	if _blocked_time >= params.stuck_sec:
		recover_to_safe("移動停滯，返回安全位置")
func deeply_embedded(point: Vector3) -> bool:
	var query := query_at(point)
	var inner := CapsuleShape3D.new()
	var tolerance := clampf(params.stuck_penetration_tolerance, 0.0, params.radius * 0.5)
	inner.radius = params.radius - tolerance
	inner.height = params.height - tolerance * 2.0
	query.shape = inner
	query.margin = 0.0
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func query_at(point: Vector3) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * params.height * 0.5)
	query.collision_mask = params.world_mask
	query.margin = params.collision_margin
	query.exclude = [get_rid()]
	return query

func segment_clear(start: Vector3, finish: Vector3) -> bool:
	return segment_obstruction(start, finish).is_empty()

func segment_obstruction(start: Vector3, finish: Vector3) -> Dictionary:
	var query := query_at(start)
	var space := get_world_3d().direct_space_state
	var hits := space.intersect_shape(query, 1)
	var stage := "start_overlap"
	var fraction := 0.0
	if hits.is_empty():
		query.motion = finish - start
		var fractions := space.cast_motion(query)
		fraction = fractions[0]
		if fraction < 1.0:
			stage = "sweep"
			query = query_at(start.lerp(finish, fractions[1]))
			hits = space.intersect_shape(query, 1)
		else:
			stage = "end_overlap"
			hits = space.intersect_shape(query_at(finish), 1)
			if hits.is_empty(): return {}
	var collider: Object = hits[0]["collider"] if not hits.is_empty() else null
	return {"stage": stage, "collider": str((collider as Node).get_path()) if collider is Node else "unknown",
		"from": str(start), "to": str(finish), "safe_fraction": fraction}

func polyline_obstruction(points: PackedVector3Array) -> Dictionary:
	for i in range(1, points.size()):
		var hit := segment_obstruction(points[i - 1], points[i])
		if not hit.is_empty():
			hit["segment"] = i
			return hit
	return {}

func path_clear(start: Vector3, finish: Vector3, arc: float) -> bool:
	var previous := start
	for i in range(1, maxi(params.path_samples, 4) + 1):
		var next := TraversalMath.arc_point(start, finish, float(i) / maxi(params.path_samples, 4), arc)
		if not segment_clear(previous, next):
			return false
		previous = next
	return true

func supported(point: Vector3) -> bool:
	## 五點支撐檢查，避免膠囊中心有地板、身體卻懸在窄邊緣的假落點。
	for offset in [Vector3.ZERO, Vector3.RIGHT * params.radius, Vector3.LEFT * params.radius,
			Vector3.FORWARD * params.radius, Vector3.BACK * params.radius]:
		var start: Vector3 = point + offset + Vector3.UP * params.landing_lift
		var query := PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * (params.support_depth + params.landing_lift), params.world_mask, [get_rid()])
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty() or (result["normal"] as Vector3).y < params.support_normal_min:
			return false
	return true


func _guard_walk(requested: Vector3, delta: float) -> Vector3:
	if requested.is_zero_approx():
		return requested
	var motion := requested * delta
	if _walk_path_safe(global_position, motion):
		return requested
	var x_safe := _walk_path_safe(global_position, Vector3(motion.x, 0.0, 0.0))
	var z_safe := _walk_path_safe(global_position, Vector3(0.0, 0.0, motion.z))
	return TraversalMath.safe_walk_velocity(requested, false, x_safe, z_safe)


func _walk_path_safe(origin: Vector3, motion: Vector3) -> bool:
	# 依真正地面高度判斷落差，不把膠囊擦過斜坡側緣的抬升誤當成懸崖。
	var initial := _walk_floor(origin, params.edge_ground_clearance)
	if initial.is_empty():
		return false
	var steps := maxi(1, ceili(motion.length() / maxf(params.edge_path_step, 0.01)))
	var height: float = (initial["position"] as Vector3).y
	for i in range(1, steps + 1):
		var point := origin + motion * (float(i) / steps)
		point.y = height + params.landing_lift
		var floor_hit := _walk_floor(point, params.edge_ground_clearance)
		if floor_hit.is_empty() or height - (floor_hit["position"] as Vector3).y > params.edge_max_drop:
			return false
		if not _walk_footprint(point):
			return false
		height = (floor_hit["position"] as Vector3).y
	return true

func _walk_footprint(point: Vector3) -> bool:
	var center := _walk_floor(point, params.edge_ground_clearance)
	if center.is_empty():
		return false
	var clearance := maxf(0.0, point.y - (center["position"] as Vector3).y)
	var count := maxi(params.edge_probe_count, 4)
	var radius := params.radius + params.edge_safety_margin
	for i in count:
		var angle := TAU * float(i) / count
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
		if _walk_floor(point + offset, clearance).is_empty():
			return false
	return true

func _walk_floor(point: Vector3, extra_drop: float = 0.0) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * params.edge_probe_up,
		point + Vector3.DOWN * (params.edge_max_drop + extra_drop), params.world_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).y < params.support_normal_min:
		return {}
	return hit
