class_name StaffCart
extends Area3D
## Tool cart trailing the patrolling staff. Sneak up from behind (while they dwell at a stop)
## and lift metal. Restocks at dawn; packed away at night.

var staff: StaffActor
var loot_left: int = GameConst.CART_LOOT_PER_DAY

var _busy: bool = false
var _label: ProximityLabel
var _progress: Label3D
var _body: Node3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	add_child(shape)
	_body = Node3D.new()
	add_child(_body)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.45, 0.6)
	box.mesh = bm
	box.position = Vector3(0, 0.4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.47, 0.52)
	mat.metallic = 0.6
	box.material_override = mat
	_body.add_child(box)
	_label = ProximityLabel.new()
	_label.position = Vector3(0, 1.2, 0)
	add_child(_label)
	_progress = Label3D.new()
	ProximityLabel.style(_progress, 26)
	_progress.position = Vector3(0, 0.9, 0)
	_progress.modulate = Color(0.8, 1.0, 0.8)
	_progress.visible = false
	add_child(_progress)
	Bus.day_changed.connect(func(_d: int) -> void:
		loot_left = GameConst.CART_LOOT_PER_DAY
		_refresh()
	)
	_refresh()


func _refresh() -> void:
	if loot_left > 0:
		_label.modulate = Color(0.85, 0.9, 1.0)
		_label.set_info("职员工具车\n[%s ×%d · 趁职员停步，从背后偷 · E]" % [KitIds.display_name(KitIds.METAL), loot_left])
	else:
		_label.modulate = Color(0.55, 0.55, 0.55)
		_label.set_info("职员工具车\n[已偷空 · 明早补货]")


func _physics_process(delta: float) -> void:
	if staff == null or not is_instance_valid(staff):
		return
	var behind := staff.global_position - staff.facing_dir() * GameConst.CART_TRAIL_DIST
	behind.y = staff.global_position.y
	global_position = global_position.move_toward(behind, 6.0 * delta)
	visible = not Clock.allows_escape_actions()
	monitorable = visible


func try_use(user: AnimalActor) -> void:
	if _busy or user == null or staff == null:
		return
	if Clock.allows_escape_actions():
		Bus.interact_feedback.emit("夜里工具车已收走")
		return
	if loot_left <= 0:
		Bus.interact_feedback.emit("工具车已经被你搜空了 — 明早补货")
		return
	_busy = true
	_progress.visible = true
	Bus.interact_feedback.emit("伸手摸工具车…（别被职员发现！）")
	var elapsed := 0.0
	while elapsed < GameConst.STEAL_SEC:
		await get_tree().process_frame
		if not is_instance_valid(user) or user.is_confined:
			_abort("偷取中断（被抓）")
			return
		if staff.state == StaffActor.State.CHASE:
			_abort("职员回头了！偷取失败")
			return
		if user.global_position.distance_to(global_position) > 1.9:
			_abort("工具车走远了，偷取中断（趁他停步再下手）")
			return
		elapsed += get_process_delta_time()
		_progress.text = "偷取 %d%%" % int(clampf(elapsed / GameConst.STEAL_SEC, 0.0, 1.0) * 100.0)
	_progress.visible = false
	_busy = false
	loot_left -= 1
	user.give_items([KitIds.METAL])
	_refresh()
	Bus.material_gathered.emit(KitIds.METAL, 1)
	Bus.interact_feedback.emit("得手！金属 ×1 — 背包共 %d" % user.item_count(KitIds.METAL))


func _abort(msg: String) -> void:
	_busy = false
	_progress.visible = false
	Bus.interact_feedback.emit(msg)
