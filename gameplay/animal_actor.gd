class_name AnimalActor
extends CharacterBody3D
## Controllable zoo animal. Capabilities come from AnimalDef.

enum FollowMode { FOLLOW, HOLD }

const ANIMAL_SCENE := preload("res://scenes/actors/animal.tscn")
const FOLLOW_STOP_DIST := 2.2
const FOLLOW_STUCK_DIST := 3.0
## Time with no progress before picking a new detour / soft-pull.
const FOLLOW_STUCK_RETRY_SEC := 0.85
## Cumulative stuck time before parking (then auto-resume when leader near/LOS).
const FOLLOW_STUCK_GIVE_UP_SEC := 5.0
const FOLLOW_SOFT_PULL_DIST := 6.0
const FOLLOW_RESUME_NEAR := 4.2
const FOLLOW_RESUME_LOS := 9.0

@export var def: AnimalDef

var is_controlled: bool = false
var follow_mode: FollowMode = FollowMode.FOLLOW
var is_rescued: bool = false
## Back in exhibit after capture: free to move inside, cannot open locked door.
var is_confined: bool = false
var home_position: Vector3 = Vector3.ZERO
var inventory: Array[StringName] = []

var _mesh: MeshInstance3D
var _follow_target: Node3D
var _hold_position: Vector3 = Vector3.ZERO
var _interact_area: Area3D
var _facing: Vector3 = Vector3(0, 0, -1)
var _stuck_time: float = 0.0
var _stuck_give_up: float = 0.0
var _auto_resume_follow: bool = false
var _has_detour: bool = false
var _detour_goal: Vector3 = Vector3.ZERO
var _last_progress_dist: float = 999.0


static func create(animal_def: AnimalDef) -> AnimalActor:
	var node: AnimalActor = ANIMAL_SCENE.instantiate() as AnimalActor
	node.def = animal_def
	return node


func _ready() -> void:
	home_position = global_position
	_hold_position = global_position
	collision_layer = 2
	collision_mask = 1
	_ensure_visual()
	_ensure_interact_sensor()
	add_to_group("animals")


func _physics_process(delta: float) -> void:
	if not is_rescued and not is_controlled:
		velocity = Vector3.ZERO
		return
	var was_following := (not is_controlled) and follow_mode == FollowMode.FOLLOW and not is_confined
	var follow_dist := 0.0
	if was_following and _follow_target and is_instance_valid(_follow_target):
		follow_dist = global_position.distance_to(_follow_target.global_position)
	if is_controlled:
		_process_controlled()
	else:
		_process_ai(delta)
	_apply_gravity(delta)
	move_and_slide()
	if was_following and follow_mode == FollowMode.FOLLOW:
		_update_follow_stuck(delta, follow_dist)


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


func _process_controlled() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := _camera_relative_dir(input)
	if dir.length() > 0.1:
		_facing = dir.normalized()
	var speed := def.move_speed if def else 5.0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	## Do not zero velocity.y — gravity / jumps own vertical.
	if Input.is_action_just_pressed("interact"):
		_try_interact()


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


func _process_ai(delta: float) -> void:
	## Confined companions stay put in the exhibit instead of following out.
	if is_confined:
		_move_toward(home_position if follow_mode != FollowMode.HOLD else _hold_position, 3.0)
		_stuck_time = 0.0
		_stuck_give_up = 0.0
		return
	match follow_mode:
		FollowMode.HOLD:
			if _auto_resume_follow:
				_try_auto_resume_follow()
			if follow_mode == FollowMode.HOLD:
				_move_toward(_hold_position, 3.5)
				_stuck_time = 0.0
		FollowMode.FOLLOW:
			_follow_leader(delta)


func _follow_leader(_delta: float) -> void:
	if _follow_target == null or not is_instance_valid(_follow_target):
		velocity.x = 0.0
		velocity.z = 0.0
		_stuck_time = 0.0
		return
	var goal := _follow_target.global_position
	var dist := global_position.distance_to(goal)
	if dist <= FOLLOW_STOP_DIST:
		velocity.x = 0.0
		velocity.z = 0.0
		_stuck_time = 0.0
		_stuck_give_up = 0.0
		_has_detour = false
		return
	var target := goal
	if _has_detour:
		var d_detour := global_position.distance_to(_detour_goal)
		if d_detour < 0.7 or _wall_between(global_position, _detour_goal):
			_has_detour = false
		else:
			target = _detour_goal
	var planar := _steer_toward(target, 4.5)
	velocity.x = planar.x
	velocity.z = planar.z


func _try_auto_resume_follow() -> void:
	if _follow_target == null or not is_instance_valid(_follow_target):
		return
	var dist := global_position.distance_to(_follow_target.global_position)
	var los := not _wall_between(global_position, _follow_target.global_position)
	if dist <= FOLLOW_RESUME_NEAR or (los and dist <= FOLLOW_RESUME_LOS):
		order_follow()
		Bus.interact_feedback.emit("%s 重新跟上队伍" % display_name())


func _update_follow_stuck(delta: float, dist_before: float) -> void:
	if dist_before <= FOLLOW_STUCK_DIST:
		_stuck_time = 0.0
		_stuck_give_up = 0.0
		_last_progress_dist = dist_before
		return
	## Closing the gap counts as progress even at low speed (cornering).
	if dist_before < _last_progress_dist - 0.2:
		_stuck_time = 0.0
		_stuck_give_up = maxf(0.0, _stuck_give_up - delta * 2.0)
		_last_progress_dist = dist_before
		return
	_last_progress_dist = minf(_last_progress_dist, dist_before)
	if get_real_velocity().length() < 0.4:
		_stuck_time += delta
		_stuck_give_up += delta
	else:
		_stuck_time = 0.0
	if _stuck_time < FOLLOW_STUCK_RETRY_SEC:
		return
	_stuck_time = 0.0
	var goal := _follow_target.global_position if _follow_target else global_position
	if _pick_detour(goal):
		return
	if dist_before <= FOLLOW_SOFT_PULL_DIST and _try_soft_pull(goal):
		return
	if _stuck_give_up >= FOLLOW_STUCK_GIVE_UP_SEC:
		order_hold(true)
		_stuck_give_up = 0.0
		Bus.interact_feedback.emit(
			"%s 暂时卡住待命 — 走近或露脸会自动跟上（也可按 F）" % display_name()
		)


func _steer_toward(target: Vector3, speed: float) -> Vector3:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.35:
		return Vector3.ZERO
	var direct := to.normalized()
	if not _wall_between(global_position, target):
		return direct * speed
	## Prefer an active detour if still valid.
	if _has_detour and not _wall_between(global_position, _detour_goal):
		var via_dir := _detour_goal - global_position
		via_dir.y = 0.0
		if via_dir.length() > 0.1:
			return via_dir.normalized() * speed
	if _pick_detour(target):
		var side := _detour_goal - global_position
		side.y = 0.0
		if side.length() > 0.1:
			return side.normalized() * speed
	var perp := Vector3(-direct.z, 0.0, direct.x)
	## Last resort: nudge sideways while pressing into wall so player sees motion.
	return (direct + perp * 0.85).normalized() * speed


func _pick_detour(goal: Vector3) -> bool:
	## Gateways: clear pads near the leader (for 2-corner routes around blocks).
	var gateways: Array[Vector3] = []
	for deg in range(0, 360, 45):
		var rad := deg_to_rad(float(deg))
		var dir := Vector3(cos(rad), 0.0, sin(rad))
		for r in [2.0, 3.5, 5.0]:
			var gw: Vector3 = goal + dir * r
			gw.y = global_position.y
			if not _wall_between(gw, goal):
				gateways.append(gw)
	var best_score := -INF
	var best := Vector3.ZERO
	var found := false
	var goal_dist := global_position.distance_to(goal)
	for deg in range(0, 360, 30):
		var rad := deg_to_rad(float(deg))
		var dir := Vector3(cos(rad), 0.0, sin(rad))
		for r in [1.6, 2.8, 4.2, 6.0, 8.0]:
			var via: Vector3 = global_position + dir * r
			via.y = global_position.y
			if _wall_between(global_position, via):
				continue
			var via_goal := via.distance_to(goal)
			var closer := via_goal < goal_dist - 0.25
			var los_goal := not _wall_between(via, goal)
			var gateway_d := INF
			for gw in gateways:
				if _wall_between(via, gw):
					continue
				gateway_d = minf(gateway_d, via.distance_to(gw))
			var reaches_gateway := gateway_d < INF
			if not closer and not los_goal and not reaches_gateway:
				continue
			var score := -via_goal
			if los_goal:
				score += 100.0
			elif reaches_gateway:
				score += 55.0 - gateway_d * 0.5
			if closer:
				score += 25.0
			## Prefer not reusing the same pad (forces side-swap when jammed).
			if _has_detour and via.distance_to(_detour_goal) < 1.2:
				score -= 40.0
			if score > best_score:
				best_score = score
				best = via
				found = true
	## Wall-normal slide: cast to goal, step off the hit face.
	if not found or best_score < 20.0:
		var hit := _ray_hit(global_position, goal)
		if not hit.is_empty():
			var hp: Vector3 = hit.position
			var n: Vector3 = hit.normal
			n.y = 0.0
			if n.length_squared() > 0.01:
				n = n.normalized()
			var perp := Vector3(-n.z, 0.0, n.x)
			for side in [1.0, -1.0]:
				for dist in [2.0, 3.5, 5.0]:
					var via2: Vector3 = hp + n * 0.55 + perp * side * dist
					via2.y = global_position.y
					if _wall_between(global_position, via2):
						continue
					var score2 := 40.0 - via2.distance_to(goal)
					if not _wall_between(via2, goal):
						score2 += 80.0
					if score2 > best_score:
						best_score = score2
						best = via2
						found = true
	if found:
		_detour_goal = best
		_has_detour = true
		return true
	return false


func _ray_hit(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		from + Vector3(0, 0.45, 0),
		to + Vector3(0, 0.45, 0)
	)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return space.intersect_ray(query)


func _try_soft_pull(goal: Vector3) -> bool:
	## Slide along clear space toward the leader — never through walls.
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 0.6:
		return false
	var dir := to.normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var best := global_position
	var best_goal_d := global_position.distance_to(goal)
	var improved := false
	for step in [0.9, 1.4, 2.0]:
		var cand: Vector3 = global_position + dir * step
		cand.y = global_position.y
		if _wall_between(global_position, cand):
			break
		var gd := cand.distance_to(goal)
		if gd < best_goal_d - 0.15:
			best = cand
			best_goal_d = gd
			improved = true
	for side in [1.2, -1.2, 2.4, -2.4]:
		var cand2: Vector3 = global_position + perp * side + dir * 0.7
		cand2.y = global_position.y
		if _wall_between(global_position, cand2):
			continue
		var gd2 := cand2.distance_to(goal)
		if gd2 < best_goal_d - 0.15:
			best = cand2
			best_goal_d = gd2
			improved = true
	if not improved:
		return false
	global_position = best
	velocity = Vector3.ZERO
	_has_detour = false
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


func set_controlled(active: bool) -> void:
	is_controlled = active
	if active:
		add_to_group("controlled")
	else:
		remove_from_group("controlled")
	if is_controlled:
		follow_mode = FollowMode.FOLLOW
		_stuck_time = 0.0
		_stuck_give_up = 0.0
		_auto_resume_follow = false
		_has_detour = false
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
	_stuck_give_up = 0.0
	_auto_resume_follow = false
	_has_detour = false
	_last_progress_dist = 999.0


func order_hold(allow_auto_resume: bool = false) -> void:
	follow_mode = FollowMode.HOLD
	_hold_position = global_position
	_stuck_time = 0.0
	_stuck_give_up = 0.0
	_auto_resume_follow = allow_auto_resume
	_has_detour = false


func enter_danger_auto_hold() -> void:
	if is_controlled or is_confined:
		return
	## Force hold even if already HOLD — ensures Approach reliably parks followers.
	var was_follow := follow_mode == FollowMode.FOLLOW
	order_hold(false)
	if was_follow:
		Bus.interact_feedback.emit("%s 在危险区入口待命" % display_name())


func has_capability(cap: CapabilityIds.Id) -> bool:
	return def != null and def.has_capability(cap)


func take_inventory() -> Array[StringName]:
	var out := inventory.duplicate()
	inventory.clear()
	return out


func give_items(item_ids: Array[StringName]) -> void:
	for id in item_ids:
		inventory.append(id)


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
		_stuck_give_up = 0.0
		_auto_resume_follow = false
		_has_detour = false


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
