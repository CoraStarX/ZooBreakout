class_name StaffReadabilityLab
extends MovementLab
## 只讀移動狀態的接線層；舊移動入口、控制、幾何與參數維持凍結。
@export var staff_params: StaffReadabilityParams = preload("res://content/staff/staff_readability_params.tres")
@export var staff_layout: StaffReadabilityLayout = preload("res://content/traversal/staff_readability_layout.tres")
var staff: ReadabilityStaff
var fan: MeshInstance3D
var head: ProximityLabel
var _regions: Array[Dictionary] = []
var _status: Label
var _border: Control
var _arrival_audio: AudioStreamPlayer
var _feedback_left: float = 0
var _sample_speed: float = 0
var _previous_position := Vector3.ZERO

func _ready() -> void:
	super._ready()
	# 沙盒沿用既有操作 HUD，世界標籤只保留短名，避免遮住高處角色。
	for child in get_children():
		if child is ProximityLabel: (child as ProximityLabel).set_info((child as ProximityLabel).short_text)
	actor.global_position = staff_layout.player_spawn
	_previous_position = actor.global_position
	actor.stepped.connect(_track_speed)
	staff = ReadabilityStaff.new()
	staff.name = "ReadabilityStaff"
	staff.params = staff_params
	staff.position = staff_layout.spawn
	staff.route = staff_layout.route.duplicate()
	staff.navigation_points = staff.route.duplicate()
	for entry in staff_layout.anchors: staff.navigation_points.append(entry.position)
	for block in data.blocks:
		var size: Vector3 = block.size
		var center: Vector3 = block.position
		if center.y + size.y * 0.5 <= staff_params.ground_height_tolerance: continue
		var region := {"id":str(block.name),"rect":Rect2(center.x-size.x*0.5,center.z-size.z*0.5,size.x,size.z),"roof":block.get("shape","box") == "box" and center.y + size.y * 0.5 >= data.climb_height}
		staff.obstacles.append(region)
		if region.roof: _regions.append(region)
	staff.sensor = _visual_sample
	staff.noise_sensor = _noise_sample
	add_child(staff)
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = staff_params.body_radius
	mesh.height = staff_params.body_height
	visual.mesh = mesh
	visual.position.y = staff_params.body_height * 0.5
	visual.material_override = material(staff_params.body_color)
	staff.add_child(visual)
	head = ProximityLabel.new()
	head.position.y = staff_params.icon_height
	staff.add_child(head)
	fan = MeshInstance3D.new()
	var fan_material := material(staff_params.fan_color)
	fan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fan_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fan_material.no_depth_test = true
	fan.material_override = fan_material
	add_child(fan)
	debug_hud.set("readability_metrics",staff.metrics)
	staff.arrival_feedback.connect(_arrival)
	_build_staff_hud()

func _track_speed(delta: float) -> void:
	_sample_speed = StaffPerceptionFootprint.flat(actor.global_position).distance_to(StaffPerceptionFootprint.flat(_previous_position)) / maxf(delta,0.000001)
	_previous_position = actor.global_position

func _noise_sample(position: Vector3, force_high: bool = false) -> Dictionary:
	var projection := Vector3(position.x,staff_params.ground_y,position.z)
	# 只查事件位置下的場景碰撞；不讀取聲音發出者現在的位置或移動狀態。
	var probe := Vector3.UP * staff_params.ground_probe_height
	var query := PhysicsRayQueryParameters3D.create(position+probe,position-probe,params.world_mask,[actor.get_rid(),staff.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var support_y: float = (hit.position as Vector3).y if not hit.is_empty() else INF
	var on_ground := not force_high and StaffPerceptionFootprint.ground_supported(position,support_y,staff_params)
	var key := ""
	if not on_ground:
		for region in _regions:
			var rect: Rect2 = region.rect
			if rect.grow(staff_params.same_source_radius).has_point(StaffPerceptionFootprint.flat(position)):
				key = region.id
				break
	var approach := projection
	var closest := INF
	for entry in staff_layout.anchors:
		if not key.is_empty() and entry.region != key: continue
		var distance := projection.distance_to(entry.position)
		if distance < closest:
			closest = distance
			approach = entry.position
	var reachable := on_ground
	for obstacle in staff.obstacles:
		var rect: Rect2 = obstacle.rect
		# 地面／高處分類用真正的實體輪廓；員工半徑只交給尋路，不把貼牆玩家誤當高處。
		if rect.has_point(StaffPerceptionFootprint.flat(projection)): reachable = false
	return {"projection":projection,"reachable":reachable,"approach":approach if not reachable else projection,"key":key,"ground_supported":on_ground,"support_y":str(support_y)}

func _visual_sample() -> Dictionary:
	var climbing := actor.state in [TraversalActor.State.CLIMBING,TraversalActor.State.ATTACHING] and is_instance_valid(actor.surface)
	var projection := actor.global_position
	if climbing:
		projection = StaffPerceptionFootprint.projected(projection,true,actor.surface.global_position,actor.surface.global_basis.z,actor.params.radius + actor.params.wall_clearance)
	var result := _noise_sample(actor.global_position,actor.state != TraversalActor.State.GROUNDED)
	result.projection = Vector3(projection.x,staff_params.ground_y,projection.z)
	result["actual"] = str(actor.global_position)
	result["climbing"] = climbing
	if climbing:
		# 來源依攀爬面固定；剛附著尚未升高也不能換成另一個「地面來源」繞過冷卻。
		for region in _regions:
			var rect: Rect2 = region.rect
			if rect.grow(staff_params.same_source_radius).has_point(StaffPerceptionFootprint.flat(actor.surface.global_position)):
				result.key = region.id
				break
	result["speed"] = _sample_speed
	result.reachable = result.reachable and actor.state == TraversalActor.State.GROUNDED
	return result

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(staff): return
	_feedback_left = maxf(0,_feedback_left-delta)
	fan.visible = staff.state != &"REST"
	if fan.visible and staff.polygon.size() >= 3: fan.mesh = StaffPerceptionFootprint.mesh(staff.polygon,staff_params.fan_lift)
	var icon := staff.icon()
	head.visible = true
	head.set_info((icon + " · 地面員工") if not icon.is_empty() else "地面員工")
	var status := {"WORK":"員工巡邏中：留意地面視野","REST":"員工正在休息：仍聽得到聲音","SUSPICIOUS":"員工起疑：離開視野可降低警覺","INVESTIGATE":"員工正在調查最後感知位置","CHASE":"員工追逐中：可利用遮擋與高處","SEARCH":"員工正在搜索，稍後會放棄","RETURN":"員工正返回巡邏路線"}
	_status.text = "被員工追上了；仍可繼續移動" if _feedback_left > 0 else str(status.get(str(staff.state),""))
	_border.visible = _feedback_left > 0

func _update_occlusion() -> void:
	super._update_occlusion()
	if not is_instance_valid(staff): return
	# 與玩家共用材質淡出結果，只再加入鏡頭→員工射線，不改感知或碰撞。
	var excluded: Array[RID] = [actor.get_rid(),staff.get_rid()]
	for _i in staff_params.occlusion_layers:
		var query := PhysicsRayQueryParameters3D.create(actor.camera.global_position,staff.global_position + Vector3.UP * staff_params.contact_height,params.world_mask,excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		var body := hit.collider as CollisionObject3D
		excluded.append(body.get_rid())
		if _block_materials.has(body):
			var mat: StandardMaterial3D = _block_materials[body]
			mat.albedo_color.a = staff_params.occlusion_alpha
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _build_staff_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := UIKit.panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -staff_params.status_width-staff_params.status_margin
	panel.offset_right = -staff_params.status_margin
	panel.offset_top = staff_params.status_top
	panel.offset_bottom = staff_params.status_top+staff_params.status_height
	canvas.add_child(panel)
	_status = UIKit.label("",staff_params.status_font_size,UIKit.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_status)
	_border = Control.new()
	_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_border)
	for side in range(4):
		var edge := ColorRect.new()
		edge.color = staff_params.feedback_color
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		match side:
			0: edge.anchor_bottom = 0; edge.offset_bottom = staff_params.border_width
			1: edge.anchor_top = 1; edge.offset_top = -staff_params.border_width
			2: edge.anchor_right = 0; edge.offset_right = staff_params.border_width
			3: edge.anchor_left = 1; edge.offset_left = -staff_params.border_width
		_border.add_child(edge)
	_border.visible = false
	_arrival_audio = AudioStreamPlayer.new()
	_arrival_audio.volume_db = staff_params.tone_db
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = staff_params.tone_mix_rate
	var count := int(staff_params.tone_sec * wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		bytes.encode_s16(i*2,int(sin(TAU*staff_params.tone_hz*float(i)/wav.mix_rate)*(1.0-float(i)/count)*32767))
	wav.data = bytes
	_arrival_audio.stream = wav
	add_child(_arrival_audio)

func _arrival() -> void:
	_feedback_left = staff_params.feedback_sec
	if DisplayServer.get_name() != "headless": _arrival_audio.play()

func _build_hud() -> void:
	super._build_hud()
	for node in find_children("*","Label",true,false):
		var label := node as Label
		if label.text.begins_with("移動試玩"):
			label.text = "員工可讀性試玩｜地面視野與遮擋 · F3 複製統計"
