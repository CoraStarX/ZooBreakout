class_name FormController
extends Node
signal form_changed(previous: FormDef, current: FormDef, body: TraversalActor)
signal transform_committed(previous: FormDef, current: FormDef, position: Vector3, forced: bool, reason: String)
signal feedback(message: String)
@export var setup: FormSetup
@export var params: FormParams
@export var input_enabled: bool = true
var current_form: FormDef
var actor: TraversalActor
var now: float = 0
var cooldown_until: float = 0
var unlocked_forms: Array[FormDef] = []
var _host: Node3D
var _camera: Camera3D
var _safe_positions: Array[Vector3] = []

func initialize(host: Node3D, camera: Camera3D, old_body: TraversalActor = null) -> bool:
	var errors := FormRules.validate_setup(setup)
	errors.append_array(FormRules.validate_params(params))
	if not errors.is_empty():
		feedback.emit("開局資料錯誤："+"；".join(errors))
		return false
	_host = host
	_camera = camera
	actor = old_body
	unlocked_forms = setup.initial_unlocked_forms.duplicate()
	if not space_clear(setup.starting_form,setup.spawn):
		feedback.emit("出生點無法容納開局形態")
		return false
	_replace_body(setup.starting_form,setup.spawn,false)
	return true

func _physics_process(delta: float) -> void:
	now += delta
	if input_enabled and is_instance_valid(actor) and Input.is_action_just_pressed(params.switch_action):
		request_cycle()

func cooldown_remaining() -> float:
	return maxf(0,cooldown_until-now)

func request_cycle() -> bool:
	if current_form != setup.base_form: return request_form(setup.base_form)
	for form in setup.forms:
		if form != setup.base_form and unlocked_forms.has(form): return request_form(form)
	feedback.emit("尚未解鎖其他形態")
	return false

func space_clear(form: FormDef, point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = FormRules.capsule(form)
	query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*form.body_size.y*0.5)
	query.collision_mask = form.movement_profile.world_mask
	if is_instance_valid(actor): query.exclude = [actor.get_rid()]
	return _host.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _supported(form: FormDef, point: Vector3) -> bool:
	var profile := form.movement_profile
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*profile.landing_lift,point-Vector3.UP*profile.support_depth,profile.world_mask)
	if is_instance_valid(actor): query.exclude = [actor.get_rid()]
	var hit := _host.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.normal as Vector3).y >= profile.support_normal_min

func _remember_safe(_delta: float) -> void:
	if actor.state != TraversalActor.State.GROUNDED or not space_clear(setup.base_form,actor.global_position): return
	if _safe_positions.is_empty() or actor.global_position.distance_to(_safe_positions.back()) >= params.safe_history_spacing:
		_safe_positions.append(actor.global_position)
		while _safe_positions.size() > params.safe_history_limit: _safe_positions.pop_front()

func _support_floor(form: FormDef, point: Vector3, extra_drop: float) -> Dictionary:
	var profile := form.movement_profile
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*profile.edge_probe_up,
		point-Vector3.UP*(profile.edge_max_drop+extra_drop),profile.world_mask,[actor.get_rid()])
	var hit := _host.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < profile.support_normal_min: return {}
	return hit

func walkable_support(form: FormDef, point: Vector3) -> bool:
	var profile := form.movement_profile
	if not profile.edge_guard_enabled: return _supported(form,point)
	var center := _support_floor(form,point,profile.edge_ground_clearance)
	if center.is_empty(): return false
	var clearance := maxf(0,point.y-(center.position as Vector3).y)
	# 與凍結移動的_walk_footprint使用相同射線範圍／採樣與安全邊距；不新增調參來源。
	for offset in FormRules.footprint_offsets(form):
		if _support_floor(form,point+offset,clearance).is_empty(): return false
	return true

func push_path_clear(origin: Vector3, destination: Vector3) -> bool:
	var base := setup.base_form
	if not FormRules.same_support_level(origin.y,destination.y,params) or not space_clear(base,origin): return false
	var motion := destination-origin
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = FormRules.capsule(base)
	query.transform = Transform3D(Basis.IDENTITY,origin+Vector3.UP*base.body_size.y*0.5)
	query.collision_mask = base.movement_profile.world_mask
	query.exclude = [actor.get_rid()]
	query.motion = motion
	# 連續形狀掃掠，不能靠稀疏位置檢查穿過薄牆；先排除起點重疊。
	var fractions := _host.get_world_3d().direct_space_state.cast_motion(query)
	if fractions.is_empty() or fractions[0] < 1.0 or not space_clear(base,destination): return false
	var floor_start := _support_floor(base,origin,base.movement_profile.edge_ground_clearance)
	if floor_start.is_empty(): return false
	var count := maxi(1,ceili(motion.length()/params.push_path_step))
	for i in range(count+1):
		var point := origin.lerp(destination,float(i)/count)
		var floor_hit := _support_floor(base,point,base.movement_profile.edge_ground_clearance)
		if floor_hit.is_empty() or not FormRules.same_support_level((floor_start.position as Vector3).y,(floor_hit.position as Vector3).y,params): return false
	return true

func _push_candidate_legal(target: FormDef, origin: Vector3, point: Vector3) -> bool:
	# Vector3量化後仍不可超過資源上限，不能只檢查生成候選前的半徑。
	if origin.distance_to(point) > params.push_max_distance: return false
	return space_clear(target,point) and walkable_support(target,point) and push_path_clear(origin,point)

func find_form_position(target: FormDef, origin: Vector3) -> Dictionary:
	if space_clear(target,origin) and walkable_support(target,origin): return {"valid":true,"position":origin}
	var best := INF
	var result := {"valid":false,"position":origin}
	# 固定方向／半徑有界取樣；同距離保持固定順序，無隨機瞬移與歷史點兜底。
	for direction in FormRules.push_directions(params):
		var lower := 0.0
		for step in range(1,params.push_radial_steps+1):
			var distance := minf(params.push_max_distance*float(step)/params.push_radial_steps,best)
			if distance <= lower or distance <= 0: break
			var point := origin+direction*distance
			if not _push_candidate_legal(target,origin,point):
				lower = distance
				continue
			var upper := distance
			for refine in params.push_refine_steps:
				var middle := (lower+upper)*0.5
				if _push_candidate_legal(target,origin,origin+direction*middle): upper = middle
				else: lower = middle
			if upper < best:
				best = upper
				result = {"valid":true,"position":origin+direction*upper}
			break
	return result

func request_form(target: FormDef, forced: bool = false, reason: String = "") -> bool:
	if not is_instance_valid(actor) or not setup.forms.has(target): return false
	if target == current_form: return true
	if forced and target != setup.base_form:
		feedback.emit("強制退回只能指定本體")
		return false
	var point := actor.global_position
	var grounded := actor.state == TraversalActor.State.GROUNDED and _supported(current_form,point)
	var clear := space_clear(target,point)
	if target == setup.base_form and not clear:
		var candidates := _safe_positions.duplicate()
		candidates.reverse()
		candidates.append(setup.spawn)
		for candidate in candidates:
			if space_clear(target,candidate) and _supported(target,candidate):
				point = candidate
				clear = true
				grounded = true
				break
	# 先檢查解鎖／冷卻／接地，再做有限的空間搜尋，避免拒絕時浪費查詢。
	var refusal := FormRules.rejection(target,setup.base_form,unlocked_forms.has(target),grounded,cooldown_remaining(),clear if target == setup.base_form else true)
	if not refusal.is_empty():
		feedback.emit(target.display_name+"："+refusal)
		return false
	if target != setup.base_form:
		var placement := find_form_position(target,point)
		if not placement.valid:
			feedback.emit("這裡太窄")
			return false
		point = placement.position
	var previous := current_form
	_replace_body(target,point,not grounded)
	# 只有成功變成非本體才寫入截止時間；退回本體完全不碰原有冷卻。
	if target != setup.base_form: cooldown_until = now+params.form_cooldown_sec
	feedback.emit(("強制退回本體："+reason) if forced else ("已變成"+target.display_name))
	# 同步訊號先讓Content更新外觀／C的目擊判定，再發聲，保證看到優先。
	transform_committed.emit(previous,target,point,forced,reason)
	if not forced: Bus.noise_made.emit(point,params.transform_noise,&"transform")
	return true

func force_return(reason: String) -> bool:
	return request_form(setup.base_form,true,reason)

func _replace_body(target: FormDef, point: Vector3, airborne: bool) -> void:
	var old := actor
	var old_facing := old.facing if is_instance_valid(old) else Vector3.RIGHT
	var fall_velocity := Vector3.ZERO
	var peak := point.y
	if is_instance_valid(old):
		fall_velocity = Vector3(old.velocity.x,minf(old.velocity.y,0),old.velocity.z)
		peak = maxf(peak,old._peak_height)
		old.input_enabled = false
		old.set_physics_process(false)
		old.collision_layer = 0
		old.collision_mask = 0
		old.remove_from_group("controlled")
		old.get_parent().remove_child(old)
		old.queue_free()
	actor = TraversalActor.new() if target.abilities.has(CapabilityIds.Id.CLIMB) else GroundFormActor.new()
	actor.params = target.movement_params()
	actor.capabilities = target.abilities.duplicate()
	actor.camera = _camera
	actor.position = _host.to_local(point)
	actor.state = TraversalActor.State.AIRBORNE if airborne else TraversalActor.State.GROUNDED
	actor.facing = old_facing
	_host.add_child(actor)
	actor.velocity = fall_velocity if airborne else Vector3.ZERO
	actor._peak_height = peak
	# 主動／強制退回造成的下落不是操作失誤；保留峰值計算落地噪音。
	actor._intentional_fall = airborne
	actor.stepped.connect(_remember_safe)
	var previous := current_form
	current_form = target
	form_changed.emit(previous,target,actor)
