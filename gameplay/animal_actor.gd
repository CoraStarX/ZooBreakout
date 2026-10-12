class_name AnimalActor
extends CharacterBody3D
## Controllable zoo animal. Capabilities come from AnimalDef.

enum FollowMode { FOLLOW, HOLD, GOTO }

const ANIMAL_SCENE := preload("res://scenes/actors/animal.tscn")

@export var def: AnimalDef
@export var follow_params: CompanionFollowParams

var is_controlled: bool = false
var follow_mode: FollowMode = FollowMode.FOLLOW
var is_rescued: bool = false
## Back in exhibit after capture: free to move inside, cannot open locked door.
var is_confined: bool = false
var home_position: Vector3 = Vector3.ZERO
var inventory: Array[StringName] = []
## 隊長記錄的麵包屑（跟隨者讀取隊長的此物件）。
var follow_trail: FollowTrail = FollowTrail.new()

var _mesh: MeshInstance3D
var _follow_target: Node3D
var _hold_position: Vector3 = Vector3.ZERO
var _goto_target: Vector3 = Vector3.ZERO
var _interact_area: Area3D
var _facing: Vector3 = Vector3(0, 0, -1)
var _stuck_time: float = 0.0
var _stuck_phase: int = 0 ## 0 換目標 → 1 回退軌跡 → 2 可傳送
var _stuck_anchor: Vector3 = Vector3.ZERO
var _status_label: Label3D
var _shout_cooldown: float = 0.0
var _footstep_noise_acc: float = 0.0
var _fp: CompanionFollowParams


static func create(animal_def: AnimalDef) -> AnimalActor:
	var node: AnimalActor = ANIMAL_SCENE.instantiate() as AnimalActor
	node.def = animal_def
	return node


func _ready() -> void:
	home_position = global_position
	_hold_position = global_position
	collision_layer = 2
	collision_mask = 1
	_bootstrap_follow_params()
	_ensure_visual()
	_ensure_interact_sensor()
	_ensure_status_label()
	add_to_group("animals")


func _bootstrap_follow_params() -> void:
	if follow_params == null:
		var loaded := load("res://content/follow/default_companion_follow_params.tres")
		if loaded is CompanionFollowParams:
			follow_params = loaded
		else:
			follow_params = CompanionFollowParams.new()
	_fp = follow_params.duplicate(true) as CompanionFollowParams


func _physics_process(delta: float) -> void:
	if not is_rescued and not is_controlled:
		velocity = Vector3.ZERO
		return
	if _fp == null:
		_bootstrap_follow_params()
	var was_following := (
		(not is_controlled)
		and follow_mode == FollowMode.FOLLOW
		and not is_confined
	)
	var pos_before := global_position
	if is_controlled:
		_process_controlled()
	else:
		_process_ai(delta)
	_apply_gravity(delta)
	move_and_slide()
	if was_following and follow_mode == FollowMode.FOLLOW:
		_update_follow_stuck(delta, pos_before)
	_refresh_status_label()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= GameConst.GRAVITY * delta


func _ensure_visual() -> void:
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		_mesh.position = Vector3(0, 0.55, 0)
		add_child(_mesh)
	if _mesh.mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 1.1, 0.9)
		_mesh.mesh = box
	_mesh.position = Vector3(0, 0.55, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.body_color if def else Color(0.9, 0.7, 0.3)
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.35
	_mesh.material_override = mat
	_ensure_marker()


func _ensure_marker() -> void:
	var marker := get_node_or_null("ControlMarker") as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = "ControlMarker"
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.25
		cone.height = 0.45
		marker.mesh = cone
		marker.position = Vector3(0, 1.45, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.95, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.9, 0.1)
		mat.emission_energy_multiplier = 1.2
		marker.material_override = mat
		add_child(marker)
	marker.visible = is_controlled


func _ensure_interact_sensor() -> void:
	_interact_area = get_node_or_null("InteractSensor") as Area3D
	if _interact_area == null:
		_interact_area = Area3D.new()
		_interact_area.name = "InteractSensor"
		_interact_area.collision_layer = 0
		_interact_area.collision_mask = 8
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.05
		shape.shape = sphere
		_interact_area.add_child(shape)
		add_child(_interact_area)


func inventory_capacity() -> int:
	if def == null:
		return 4
	return maxi(0, def.inventory_capacity)


func inventory_free_slots() -> int:
	return maxi(0, inventory_capacity() - inventory.size())


func is_carrying_heavy() -> bool:
	for id in inventory:
		if KitIds.is_heavy(id):
			return true
	return false


## Soft checks and climb should use this (heavy cargo disables climb).
func effective_has_capability(cap: CapabilityIds.Id) -> bool:
	if cap == CapabilityIds.Id.CLIMB and is_carrying_heavy():
		return false
	return has_capability(cap)


func current_move_speed() -> float:
	var speed := def.move_speed if def else 5.0
	if is_carrying_heavy():
		speed *= GameConst.action_cost().heavy_speed_mult
	return speed


func _process_controlled() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := _camera_relative_dir(input)
	if dir.length() > 0.1:
		_facing = dir.normalized()
	var speed := current_move_speed()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	## Do not zero velocity.y — gravity / jumps own vertical.
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	_tick_footstep_noise(planar, get_physics_process_delta_time())
	if _shout_cooldown > 0.0:
		_shout_cooldown = maxf(0.0, _shout_cooldown - get_physics_process_delta_time())
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("make_noise"):
		try_make_noise()
	if Input.is_action_just_pressed("drop_item"):
		try_drop()
	## 隊長留下麵包屑供夥伴跟隨。
	follow_trail.record(global_position, _fp.trail_spacing, _fp.trail_max_points)


## 主動叫嚷／砸地：發 Bus.noise_made，供職員感知（有冷卻，防濫用）。
func try_make_noise() -> bool:
	if not is_controlled or is_confined:
		return false
	if _shout_cooldown > 0.0:
		Bus.interact_feedback.emit("还在喘口气…（噪音冷却 %.0fs）" % ceilf(_shout_cooldown))
		return false
	_shout_cooldown = GameConst.SHOUT_COOLDOWN_SEC
	Bus.noise_made.emit(global_position, GameConst.SHOUT_LOUDNESS, &"shout")
	Bus.interact_feedback.emit("你发出响动想引开职员！")
	return true


## 擴充點：奔跑自動產生輕腳步噪音（職員可聽，但不保證調查）。
func _tick_footstep_noise(planar_speed: float, delta: float) -> void:
	if planar_speed < GameConst.RUN_SPEED_FOR_FOOTSTEP_NOISE:
		_footstep_noise_acc = 0.0
		return
	_footstep_noise_acc += delta
	if _footstep_noise_acc >= GameConst.FOOTSTEP_NOISE_INTERVAL_SEC:
		_footstep_noise_acc = 0.0
		Bus.noise_made.emit(global_position, GameConst.FOOTSTEP_NOISE_LOUDNESS, &"footstep")


func _camera_relative_dir(input: Vector2) -> Vector3:
	if input.length_squared() < 0.0001:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var forward := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	if cam:
		forward = -cam.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3(0, 0, -1)
		else:
			forward = forward.normalized()
		right = cam.global_transform.basis.x
		right.y = 0.0
		if right.length_squared() < 0.0001:
			right = Vector3(1, 0, 0)
		else:
			right = right.normalized()
	## get_vector: W => y=-1, so -input.y pushes along camera forward.
	var dir := right * input.x + forward * (-input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _process_ai(_delta: float) -> void:
	## Confined companions stay put in the exhibit instead of following out.
	if is_confined:
		_move_toward(home_position if follow_mode != FollowMode.HOLD else _hold_position, 3.0)
		_stuck_time = 0.0
		return
	match follow_mode:
		FollowMode.HOLD:
			_move_toward(_hold_position, 3.5)
			_stuck_time = 0.0
		FollowMode.GOTO:
			_goto_marker()
		FollowMode.FOLLOW:
			_follow_leader_trail()


func _follow_leader_trail() -> void:
	if _follow_target == null or not is_instance_valid(_follow_target):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var leader_pos := _follow_target.global_position
	var dist := global_position.distance_to(leader_pos)
	if dist <= _fp.follow_stop_dist:
		velocity.x = 0.0
		velocity.z = 0.0
		_stuck_time = 0.0
		_stuck_phase = 0
		return
	var trail: FollowTrail = null
	if _follow_target is AnimalActor:
		trail = (_follow_target as AnimalActor).follow_trail
	var goal := leader_pos
	if trail != null and not trail.points.is_empty():
		if _stuck_phase >= 1:
			goal = trail.rewind_target(global_position, _fp.stuck_trail_rewind * _stuck_phase)
		else:
			goal = trail.target_for(global_position, 4)
		## 已接近軌跡末端或隊長時，直接朝隊長收隊。
		if global_position.distance_to(trail.latest()) < _fp.follow_stop_dist * 1.5:
			goal = leader_pos
	_move_toward_avoid_wall(goal, _fp.follow_speed)


func _goto_marker() -> void:
	var dist := global_position.distance_to(_goto_target)
	if dist <= _fp.goto_arrive_dist:
		order_hold(false)
		Bus.interact_feedback.emit("%s 已到达标记点，待命中" % display_name())
		return
	_move_toward_avoid_wall(_goto_target, _fp.follow_speed)


func _move_toward_avoid_wall(target: Vector3, speed: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.35:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var direct := to.normalized()
	if not _wall_between(global_position, target):
		velocity.x = direct.x * speed
		velocity.z = direct.z * speed
		return
	## 無 NavMesh：貼牆側向滑，目標仍是麵包屑點。
	var perp := Vector3(-direct.z, 0.0, direct.x)
	var best_dir := direct
	var best_clear := false
	for side in [1.0, -1.0]:
		var cand: Vector3 = (direct + perp * side * 0.9).normalized()
		var probe: Vector3 = global_position + cand * 1.4
		probe.y = global_position.y
		if not _wall_between(global_position, probe):
			best_dir = cand
			best_clear = true
			break
	if not best_clear:
		best_dir = (direct + perp * 0.8).normalized()
	velocity.x = best_dir.x * speed
	velocity.z = best_dir.z * speed


func _update_follow_stuck(delta: float, pos_before: Vector3) -> void:
	if _follow_target == null or not is_instance_valid(_follow_target):
		return
	var dist := global_position.distance_to(_follow_target.global_position)
	if dist <= _fp.follow_stop_dist:
		_stuck_time = 0.0
		_stuck_phase = 0
		return
	var moved := Vector3(global_position.x - pos_before.x, 0.0, global_position.z - pos_before.z).length()
	var slow := get_real_velocity().length() < _fp.stuck_speed_threshold
	var wanting := Vector3(velocity.x, 0.0, velocity.z).length() > 0.2
	if wanting and slow and moved < _fp.stuck_move_threshold:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 1.5)
		if _stuck_time <= 0.0:
			_stuck_phase = 0
		return
	if _stuck_time < _fp.stuck_time_sec:
		return
	## 恢復階梯：換目標 → 回退軌跡 → 傳送兜底。
	_stuck_time = 0.0
	_stuck_phase = mini(_stuck_phase + 1, 3)
	if _stuck_phase == 1:
		Bus.interact_feedback.emit("%s 卡住了，改抄近路…" % display_name())
		return
	if _stuck_phase == 2:
		Bus.interact_feedback.emit("%s 卡住了，沿旧脚印回退…" % display_name())
		return
	## phase >= 3：距離或持續卡住 + 不在鏡頭 → 傳送。
	var far := dist > _fp.teleport_distance
	var long_stuck := _stuck_phase >= 3
	if (far or long_stuck) and not _is_on_camera():
		if try_teleport_near_leader():
			Bus.interact_feedback.emit("%s 被传送到你身边（卡住恢复）" % display_name())
			_stuck_phase = 0


func try_teleport_near_leader() -> bool:
	if _follow_target == null or not is_instance_valid(_follow_target):
		return false
	var face := Vector3(0, 0, -1)
	if _follow_target is AnimalActor:
		face = (_follow_target as AnimalActor).facing_dir()
	if face.length() < 0.1:
		face = Vector3(0, 0, -1)
	face = face.normalized()
	var base := _follow_target.global_position - face * _fp.teleport_behind_dist
	base.y = _follow_target.global_position.y
	var candidates: Array[Vector3] = [
		base,
		base + Vector3(1.0, 0, 0),
		base + Vector3(-1.0, 0, 0),
		base + Vector3(0, 0, 1.0),
		base + Vector3(0, 0, -1.0),
		_follow_target.global_position + Vector3(1.2, 0, 0),
	]
	for c in candidates:
		c.y = _follow_target.global_position.y
		if _is_spawn_clear(c):
			global_position = c
			velocity = Vector3.ZERO
			_stuck_time = 0.0
			_stuck_phase = 0
			return true
	return false


func _is_on_camera() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	return cam.is_position_in_frustum(global_position + Vector3(0, 0.5, 0))


func _is_spawn_clear(pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	## 點位本身不在牆內：向上短射線 + 四周探測。
	if _wall_between(pos + Vector3(0, 0.1, 0), pos + Vector3(0, 1.2, 0)):
		return false
	for o in [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(0, 0, -0.4)]:
		if _wall_between(pos + Vector3(0, 0.45, 0), pos + o + Vector3(0, 0.45, 0)):
			return false
	return true


func _wall_between(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		from + Vector3(0, 0.45, 0),
		to + Vector3(0, 0.45, 0)
	)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _move_toward(target: Vector3, speed: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.35:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var planar := to.normalized() * speed
	velocity.x = planar.x
	velocity.z = planar.z


func facing_dir() -> Vector3:
	return _facing


func _ensure_status_label() -> void:
	_status_label = get_node_or_null("FollowStatus") as Label3D
	if _status_label == null:
		_status_label = Label3D.new()
		_status_label.name = "FollowStatus"
		_status_label.position = Vector3(0, 1.55, 0)
		_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_status_label.font_size = 22
		_status_label.no_depth_test = true
		add_child(_status_label)


func _refresh_status_label() -> void:
	if _status_label == null:
		return
	if is_controlled or not is_rescued or is_confined:
		_status_label.visible = false
		return
	_status_label.visible = true
	match follow_mode:
		FollowMode.HOLD:
			_status_label.text = "待命"
			_status_label.modulate = Color(1.0, 0.85, 0.3)
		FollowMode.GOTO:
			_status_label.text = "前往标记"
			_status_label.modulate = Color(0.45, 0.9, 1.0)
		FollowMode.FOLLOW:
			if _stuck_phase > 0:
				_status_label.text = "卡住恢复中…"
				_status_label.modulate = Color(1.0, 0.45, 0.35)
			else:
				_status_label.text = "跟随"
				_status_label.modulate = Color(0.7, 1.0, 0.7)


func set_controlled(active: bool) -> void:
	var was := is_controlled
	is_controlled = active
	if active:
		add_to_group("controlled")
		follow_trail.clear()
		var spacing := 0.8
		var max_n := 60
		if _fp:
			spacing = _fp.trail_spacing
			max_n = _fp.trail_max_points
		follow_trail.record(global_position, spacing, max_n)
		_stuck_time = 0.0
		_stuck_phase = 0
	else:
		remove_from_group("controlled")
		## 被切換控制的動物預設進入待命。
		if was and is_rescued and not is_confined:
			order_hold(false)
	var marker := get_node_or_null("ControlMarker") as MeshInstance3D
	if marker:
		marker.visible = is_controlled


func set_follow_target(target: Node3D) -> void:
	_follow_target = target


func order_follow() -> void:
	if is_confined:
		return
	follow_mode = FollowMode.FOLLOW
	_stuck_time = 0.0
	_stuck_phase = 0


func order_hold(_allow_auto_resume: bool = false) -> void:
	follow_mode = FollowMode.HOLD
	_hold_position = global_position
	_stuck_time = 0.0
	_stuck_phase = 0


func order_goto(pos: Vector3) -> void:
	if is_confined or is_controlled:
		return
	follow_mode = FollowMode.GOTO
	_goto_target = pos
	_stuck_time = 0.0
	_stuck_phase = 0


## 危險區：不再自動停止；僅提示，玩家可 F 強制跟上 / H 待命。
func enter_danger_auto_hold() -> void:
	if is_controlled or is_confined:
		return
	Bus.interact_feedback.emit(
		"%s：前方危险区 — 仍跟随中（H 待命 / F 强制跟上 / V 去标记点）" % display_name()
	)
	if _status_label:
		_status_label.text = "危险区!"
		_status_label.modulate = Color(1.0, 0.35, 0.25)


func has_capability(cap: CapabilityIds.Id) -> bool:
	return def != null and def.has_capability(cap)


func take_inventory() -> Array[StringName]:
	var out := inventory.duplicate()
	inventory.clear()
	return out


## Returns how many items were actually stored (respects inventory_capacity).
func give_items(item_ids: Array[StringName]) -> int:
	var accepted := 0
	for id in item_ids:
		if inventory.size() >= inventory_capacity():
			break
		inventory.append(id)
		accepted += 1
	if accepted < item_ids.size():
		Bus.interact_feedback.emit("背包满了（%d/%d）— 多出的拿不动" % [inventory.size(), inventory_capacity()])
	return accepted


func has_item(item_id: StringName) -> bool:
	return inventory.has(item_id)


func item_count(item_id: StringName) -> int:
	var n := 0
	for i in inventory:
		if i == item_id:
			n += 1
	return n


func material_count() -> int:
	var n := 0
	for i in inventory:
		if KitIds.is_material(i):
			n += 1
	return n


## Spend `count` raw materials of any kind (most plentiful first, so rare ones are kept).
func consume_any_material(count: int) -> bool:
	if material_count() < count:
		return false
	for _i in count:
		var best: StringName = &""
		var best_n := 0
		for m in KitIds.MATERIALS:
			var c := item_count(m)
			if c > best_n:
				best = m
				best_n = c
		inventory.remove_at(inventory.find(best))
	return true


func consume_items(item_id: StringName, count: int) -> bool:
	if item_count(item_id) < count:
		return false
	for _i in count:
		inventory.remove_at(inventory.find(item_id))
	return true


func consume_item(item_id: StringName) -> bool:
	var idx := inventory.find(item_id)
	if idx < 0:
		return false
	inventory.remove_at(idx)
	return true


func set_confined(value: bool) -> void:
	is_confined = value
	if value:
		follow_mode = FollowMode.HOLD
		_hold_position = home_position
		velocity = Vector3.ZERO
		_stuck_time = 0.0
		_stuck_phase = 0


func display_name() -> String:
	return def.display_name if def else name


func capture_return_home(reason: String = "") -> void:
	## Prefer CaptureFlow when available (confiscate + confine to exhibit).
	if CaptureFlow:
		CaptureFlow.apply_capture(self, reason)
		return
	global_position = home_position
	velocity = Vector3.ZERO
	set_confined(true)
	Alert.bump(1)
	Bus.captured.emit(self)
	Bus.interact_feedback.emit("%s 被抓送回！警戒 %d" % [display_name(), Alert.level])


## X: next to a route point → store every usable item there; elsewhere → drop one item (heavy first).
func try_drop() -> bool:
	if is_confined or inventory.is_empty():
		if inventory.is_empty():
			Bus.interact_feedback.emit("背包是空的")
		return false
	var point := _nearby_stash_point()
	if point:
		var moved := point.deposit_from(self)
		Bus.interact_feedback.emit("存入%s ×%d — 施工时先用这里的料（背包 %d/%d）" % [
			point.display_name, moved, inventory.size(), inventory_capacity()
		])
		return true
	var idx := inventory.size() - 1
	for i in inventory.size():
		if KitIds.is_heavy(inventory[i]):
			idx = i
			break
	var id: StringName = inventory[idx]
	inventory.remove_at(idx)
	var parent_n := get_parent() if get_parent() else get_tree().current_scene
	GroundItem.spawn(parent_n, id, global_position + _facing * 0.6 + Vector3(0, 0.02, 0))
	Bus.interact_feedback.emit("放下 %s（E 可捡回）" % KitIds.display_name(id))
	return true


func _nearby_stash_point() -> Interactable:
	if _interact_area == null:
		return null
	for area in _interact_area.get_overlapping_areas():
		var it := area as Interactable
		if it == null or global_position.distance_to(it.global_position) > it.use_range:
			continue
		for id in inventory:
			if it.accepts_stash(id):
				return it
	return null


func _try_interact() -> void:
	if _interact_area == null:
		return
	var best: Node = null
	var best_score := -INF
	for area in _interact_area.get_overlapping_areas():
		var target: Node = null
		if area.has_method("try_use"):
			target = area
		elif area.get_parent() and area.get_parent().has_method("try_use"):
			target = area.get_parent()
		if target == null:
			continue
		var to := (area as Node3D).global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < 0.01:
			dist = 0.01
		var facing_dot := _facing.dot(to.normalized())
		# Must be roughly in front; ignore things behind the animal.
		if facing_dot < 0.15 and dist > 0.6:
			continue
		var score := facing_dot * 2.0 - dist
		if score > best_score:
			best_score = score
			best = target
	if best:
		best.call("try_use", self)
	else:
		Bus.interact_feedback.emit("附近没有可交互物（对准黄柱再按 E）")
