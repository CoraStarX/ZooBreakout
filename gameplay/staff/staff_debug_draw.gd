class_name StaffDebugDraw
extends Node3D
## 職員 AI Debug 疊加（掛在 StaffActor 下，本地座標）。
## 開關：Game.staff_ai_debug（F3 面板勾選）。

var staff: StaffActor

var _hear_mesh: MeshInstance3D
var _target_mesh: MeshInstance3D
var _path_mesh: MeshInstance3D
var _label: Label3D
var _point_root: Node3D


func setup(owner_staff: StaffActor) -> void:
	staff = owner_staff
	var hear_mat := StandardMaterial3D.new()
	hear_mat.albedo_color = Color(0.2, 0.7, 1.0, 0.18)
	hear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hear_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hear_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hear_mesh = MeshInstance3D.new()
	_hear_mesh.material_override = hear_mat
	add_child(_hear_mesh)
	var target_mat := StandardMaterial3D.new()
	target_mat.albedo_color = Color(1.0, 0.9, 0.2, 0.9)
	target_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	_target_mesh.mesh = sphere
	_target_mesh.material_override = target_mat
	add_child(_target_mesh)
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.3, 1.0, 0.5, 0.7)
	path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_path_mesh = MeshInstance3D.new()
	_path_mesh.material_override = path_mat
	add_child(_path_mesh)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.modulate = Color(1, 1, 1, 0.95)
	_label.position = Vector3(0, 1.6, 0)
	_label.no_depth_test = true
	add_child(_label)
	_point_root = Node3D.new()
	add_child(_point_root)
	visible = false


func _process(_delta: float) -> void:
	if staff == null or not is_instance_valid(staff):
		return
	var on: bool = Game.staff_ai_debug
	visible = on
	## 視錐 mesh 已由 StaffActor 維護且跟 _facing；Debug 開啟時強制可見。
	if staff._vision_mesh:
		if on:
			staff._vision_mesh.visible = staff.state != StaffActor.State.REST
	if not on:
		return
	_update_hear_ring()
	_update_target_and_path()
	_update_label()
	_update_patrol_points()


func _update_hear_ring() -> void:
	var r := 2.0
	if staff._params:
		r = staff._params.hear_noise_range
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.04
	cyl.radial_segments = 32
	_hear_mesh.mesh = cyl
	_hear_mesh.position = Vector3(0, 0.04, 0)


func _update_target_and_path() -> void:
	var target := staff.global_position
	var has := false
	if staff._motor and staff._motor.has_target():
		target = staff._motor.target()
		has = true
	elif staff._last_known_valid:
		target = staff._last_known
		has = true
	_target_mesh.visible = has
	if has:
		_target_mesh.position = staff.to_local(target + Vector3(0, 0.25, 0))
	var local_to := staff.to_local(target)
	local_to.y = 0.08
	var len := Vector3(local_to.x, 0.0, local_to.z).length()
	if has and len > 0.1:
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.04, len)
		_path_mesh.mesh = box
		_path_mesh.visible = true
		_path_mesh.position = local_to * 0.5 + Vector3(0, 0.08, 0)
		_path_mesh.look_at(staff.to_global(Vector3(local_to.x, 0.08, local_to.z)), Vector3.UP)
	else:
		_path_mesh.visible = false


func _update_label() -> void:
	var st := staff.state_name()
	var band := &"calm"
	if staff._params:
		band = StaffAwarenessMath.band_for(staff.awareness, staff._params)
	_label.text = "state:%s\nawareness:%.0f (%s)" % [st, staff.awareness, String(band)]


func _update_patrol_points() -> void:
	if staff.patrol_network == null:
		return
	if _point_root.get_child_count() != staff.patrol_network.points.size():
		for c in _point_root.get_children():
			c.queue_free()
		for _p in staff.patrol_network.points:
			var lb := Label3D.new()
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.font_size = 18
			lb.no_depth_test = true
			lb.modulate = Color(1.0, 0.8, 0.3, 0.85)
			_point_root.add_child(lb)
	var i := 0
	for p in staff.patrol_network.points:
		if i >= _point_root.get_child_count():
			break
		var lb := _point_root.get_child(i) as Label3D
		var age := staff._now_sec - p.last_visited
		lb.position = staff.to_local(p.position + Vector3(0, 0.9, 0))
		lb.text = "%s\nheat:%.0f age:%.0fs" % [String(p.id), p.heat, maxf(0.0, age)]
		i += 1
