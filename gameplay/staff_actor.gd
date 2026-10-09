class_name StaffActor
extends CharacterBody3D
## Patrol staff: vision with wall LOS, hearing, chase, and door-guard duty.

enum State { PATROL, INVESTIGATE, CHASE, GUARD, REST }

@export var move_speed: float = 2.8
@export var vision_range: float = 7.0
@export var vision_angle_deg: float = 55.0
@export var hear_walk_range: float = 2.2
@export var catch_range: float = 1.35

var state: State = State.PATROL
var waypoints: Array[Vector3] = []
var _wp_index: int = 0
var _facing: Vector3 = Vector3(0, 0, 1)
var _investigate_pos: Vector3 = Vector3.ZERO
var _investigate_timer: float = 0.0
var _guard_pos: Vector3 = Vector3.ZERO
var _guard_door: Interactable = null
var _base_vision: float = 0.0
var _base_speed: float = 0.0
var _dwell_left: float = 0.0
var _route_node: Node3D
var _detect_kind: String = ""
var _mesh: MeshInstance3D
var _vision_mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("staff")
	_base_vision = vision_range
	_base_speed = move_speed
	_ensure_visual()
	Bus.day_changed.connect(apply_day_scaling)
	if waypoints.is_empty():
		waypoints = [global_position]


func setup_patrol(points: Array[Vector3]) -> void:
	waypoints = points
	_wp_index = 0
	if not points.is_empty():
		global_position = points[0]


## Staff grow warier each day (capped); rebuilds the visible vision wedge to match.
func apply_day_scaling(day: int) -> void:
	var d := clampi(day - 1, 0, GameConst.STAFF_SCALE_MAX_DAYS)
	vision_range = _base_vision + float(d) * GameConst.STAFF_VISION_PER_DAY
	move_speed = _base_speed + float(d) * GameConst.STAFF_SPEED_PER_DAY
	if _vision_mesh:
		_vision_mesh.mesh = _build_vision_wedge_mesh()


## Intel: draw the patrol loop on the ground (world space, so it does not move with the staff).
func set_route_visible(on: bool) -> void:
	if on and _route_node == null and waypoints.size() >= 2:
		_route_node = Node3D.new()
		_route_node.name = "PatrolRoute"
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for i in waypoints.size():
			var a := waypoints[i]
			var b := waypoints[(i + 1) % waypoints.size()]
			var seg := MeshInstance3D.new()
			var box := BoxMesh.new()
			var len := a.distance_to(b)
			box.size = Vector3(0.18, 0.03, len)
			seg.mesh = box
			seg.material_override = mat
			seg.position = (a + b) * 0.5 + Vector3(0, 0.05, 0)
			seg.look_at_from_position(seg.position, Vector3(b.x, seg.position.y, b.z), Vector3.UP)
			_route_node.add_child(seg)
		get_parent().add_child(_route_node)
	if _route_node:
		_route_node.visible = on


func assign_door_guard(door: Interactable, stand_pos: Vector3) -> void:
	_guard_door = door
	_guard_pos = stand_pos
	state = State.GUARD
	Bus.interact_feedback.emit("职员守在笼门前 — 靠近会被发现")


func clear_guard() -> void:
	_guard_door = null
	if state == State.GUARD:
		state = State.PATROL


func _physics_process(delta: float) -> void:
	if Clock.phase == Clock.Phase.NIGHT_QUIET and state != State.GUARD:
		state = State.REST
		velocity = Vector3.ZERO
		_set_vision_visible(false)
		return
	_set_vision_visible(state != State.REST)

	if state == State.GUARD:
		_guard_door_duty(delta)
		move_and_slide()
		_update_vision_mesh()
		return

	var spotted := _scan_animals()
	if spotted:
		state = State.CHASE
		_chase(spotted, delta)
	else:
		match state:
			State.CHASE:
				state = State.PATROL
			State.INVESTIGATE:
				_investigate(delta)
			State.REST:
				state = State.PATROL
			_:
				state = State.PATROL
				_patrol(delta)
	move_and_slide()
	if velocity.length() > 0.1:
		_facing = Vector3(velocity.x, 0.0, velocity.z).normalized()
	_update_vision_mesh()


func alert_to_noise(at: Vector3) -> void:
	if Clock.phase == Clock.Phase.NIGHT_QUIET:
		return
	if state == State.GUARD:
		return
	_investigate_pos = at
	_investigate_timer = 3.5
	state = State.INVESTIGATE


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


func facing_dir() -> Vector3:
	return _facing


func _patrol(delta: float) -> void:
	if waypoints.size() < 2:
		velocity = Vector3.ZERO
		return
	## Pause at each stop: predictable rhythm to read — and the window to rob the cart.
	if _dwell_left > 0.0:
		_dwell_left -= delta
		velocity = Vector3.ZERO
		return
	var target := waypoints[_wp_index]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.45:
		_wp_index = (_wp_index + 1) % waypoints.size()
		velocity = Vector3.ZERO
		_dwell_left = GameConst.STAFF_DWELL_SEC
		return
	velocity = to.normalized() * move_speed


func _investigate(delta: float) -> void:
	_investigate_timer -= delta
	var to := _investigate_pos - global_position
	to.y = 0.0
	if to.length() > 0.5:
		velocity = to.normalized() * move_speed * 1.15
	else:
		velocity = Vector3.ZERO
	if _investigate_timer <= 0.0:
		state = State.PATROL


func _chase(target: AnimalActor, _delta: float) -> void:
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= catch_range:
		Bus.interact_feedback.emit("工作人员抓住了 %s！" % target.display_name())
		target.capture_return_home(_detect_kind)
		state = State.PATROL
		velocity = Vector3.ZERO
		return
	velocity = to.normalized() * (move_speed * 1.45)


func _scan_animals() -> AnimalActor:
	var best: AnimalActor = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("animals"):
		if not (node is AnimalActor):
			continue
		var animal := node as AnimalActor
		if not animal.is_rescued or animal.is_confined:
			continue
		var to := animal.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		## Hearing: only moving animals (standing still is silent).
		if dist <= hear_walk_range * (1.0 + float(Alert.level) * 0.15):
			if animal.velocity.length() > 0.45:
				if dist < best_d:
					best = animal
					best_d = dist
					_detect_kind = "被脚步声引来"
				continue
		if dist > vision_range + float(Alert.level) * 0.6 or dist < 0.05:
			continue
		var dir := to.normalized()
		var ang := rad_to_deg(acos(clampf(_facing.dot(dir), -1.0, 1.0)))
		if ang > vision_angle_deg * 0.5:
			continue
		if not _has_line_of_sight(animal.global_position):
			continue
		if dist < best_d:
			best = animal
			best_d = dist
			_detect_kind = "被视线发现"
	return best


func _has_line_of_sight(target_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var from := global_position + Vector3(0, 0.55, 0)
	var to := target_pos + Vector3(0, 0.55, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.is_empty()


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
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(1.0, 0.2, 0.15, 0.28)
	vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vision_mesh.material_override = vmat
	add_child(_vision_mesh)


func _build_vision_wedge_mesh() -> ArrayMesh:
	## Flat sector matching vision_angle_deg / vision_range (local +Z forward).
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
	## Mesh forward is +Z; rotate to face _facing.
	var yaw := atan2(_facing.x, _facing.z)
	_vision_mesh.rotation = Vector3(0, yaw, 0)
	_vision_mesh.position = Vector3.ZERO


func _set_vision_visible(v: bool) -> void:
	if _vision_mesh:
		_vision_mesh.visible = v
