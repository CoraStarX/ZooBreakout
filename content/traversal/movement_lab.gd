class_name MovementLab
extends Node3D
## 獨立移動驗證入口；不建立 zoo_world，因此不推進舊日程，也不讀寫 UserPrefs。
@export var data: MovementLabData = preload("res://content/traversal/movement_lab_data.tres")
@export var params: TraversalParams = preload("res://content/traversal/traversal_params.tres")
var actor: TraversalActor
var rig: FollowCamera
var marker: MeshInstance3D
var shadow: MeshInstance3D
var metrics: TraversalMetrics
var debug_hud: CanvasLayer
var _visual: MeshInstance3D
var _landing_audio: AudioStreamPlayer3D
var _squash: Tween
var _hint: Label
var _message: String = ""
var _message_left: float = 0.0
var _jump_action_added := false
var _block_materials: Dictionary = {}

func _ready() -> void:
	if not InputMap.has_action("traversal_jump"):
		_jump_action_added = true
		InputMap.add_action("traversal_jump")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("traversal_jump", key)
	for block in data.blocks:
		make_block(block)
	var wall := ClimbSurface.new()
	wall.position = data.climb_position
	wall.width = data.climb_width
	wall.height = data.climb_height
	add_child(wall)
	var wall_marker := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(data.climb_width, data.climb_height, 0.025)
	wall_marker.mesh = wall_mesh
	wall_marker.position = data.climb_position + Vector3(0, data.climb_height * 0.5, 0.025)
	wall_marker.material_override = material(Color(0.21, 0.75, 0.72))
	add_child(wall_marker)
	for entry in data.jumps:
		var link := TraversalLink.new()
		link.position = entry["from"]
		link.landing = (entry["to"] as Vector3) - link.position
		link.edge_end = (entry.get("edge_end", entry["from"]) as Vector3) - link.position
		add_child(link)
		var edge := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(params.marker_radius * 0.3, 0.012, maxf(link.edge_end.length(), params.marker_radius))
		edge.mesh = line
		edge.position = link.position + link.edge_end * 0.5
		edge.material_override = material(Color(1.0, 0.78, 0.24))
		add_child(edge)
	for entry in data.labels:
		var label := ProximityLabel.new()
		label.position = entry["position"]
		label.set_info(entry["text"])
		add_child(label)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.13, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.85, 1.0)
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	rig = FollowCamera.new()
	rig.follow_target_height = true
	rig.height_provider_method = &"camera_focus_height"
	rig.ortho_size = data.camera_size
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	rig.add_child(camera)
	add_child(rig)
	actor = TraversalActor.new()
	actor.params = params
	actor.camera = camera
	actor.position = data.spawn
	add_child(actor)
	var visual := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = params.radius
	capsule.height = params.height
	visual.mesh = capsule
	visual.position.y = params.height * 0.5
	visual.material_override = material(Color(1.0, 0.63, 0.22))
	actor.add_child(visual)
	_visual = visual
	metrics = TraversalMetrics.new(params)
	actor.movement_event.connect(metrics.event)
	actor.diagnostic_recorded.connect(metrics.diagnostic)
	actor.stepped.connect(_on_step)
	actor.landed.connect(_on_landed)
	_landing_audio = AudioStreamPlayer3D.new()
	_landing_audio.volume_db = params.landing_tone_db
	_landing_audio.stream = _placeholder_tone()
	actor.add_child(_landing_audio)
	debug_hud = preload("res://scenes/ui/debug_hud.tscn").instantiate() as CanvasLayer
	debug_hud.set("movement_metrics", metrics)
	debug_hud.set("movement_params", params)
	add_child(debug_hud)
	actor.feedback.connect(_on_feedback)
	rig.set_follow_target(actor, true)
	marker = disk(Color(0.3, 1.0, 0.75), params.marker_radius)
	add_child(marker)
	shadow = disk(Color(0.04, 0.07, 0.08, 0.65), params.radius)
	add_child(shadow)
	_build_hud()

func make_block(block: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = block.get("name", "Block")
	body.position = block["position"]
	body.rotation_degrees.x = block.get("rotation_x", 0.0)
	if block.get("shape", "box") == "ramp":
		_build_ramp(body, block)
		add_child(body)
		return body
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = block["size"]
	collision.shape = box
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	visual.mesh = mesh
	visual.material_override = material(block.get("color", Color.GRAY))
	_block_materials[body] = visual.material_override
	body.add_child(visual)
	add_child(body)
	return body


func _build_ramp(body: StaticBody3D, block: Dictionary) -> void:
	# 真正楔形的上表面接上平台；避免旋轉薄盒的端面留下阻擋上坡的小台階。
	var half: Vector3 = (block["size"] as Vector3) * 0.5
	var points := PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
	])
	var collision := CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = points
	collision.shape = wedge
	body.add_child(collision)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[2, 4, 5], [2, 5, 3], [0, 1, 5], [0, 5, 4],
			[0, 2, 3], [0, 3, 1], [0, 4, 2], [1, 3, 5]]:
		var normal := (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).normalized()
		for index in face:
			builder.set_normal(normal)
			builder.add_vertex(points[index])
	var visual := MeshInstance3D.new()
	visual.mesh = builder.commit()
	var mat := material(block.get("color", Color.GRAY))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = mat
	body.add_child(visual)
	_block_materials[body] = mat

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var top := UIKit.panel()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	root.add_child(top)
	var title := UIKit.label("移動試玩｜爬牆 → 跨間隙 → 返回起點　F3 統計", 20, UIKit.ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)
	var bottom := UIKit.panel()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -108
	bottom.offset_bottom = -12
	root.add_child(bottom)
	var stack := VBoxContainer.new()
	bottom.add_child(stack)
	var keys := UIKit.label("WASD 移動／攀爬　Space 跳躍／放手　E 互動　F3 統計", 17)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(keys)
	_hint = UIKit.label("", 18, UIKit.ACCENT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_hint)

func _process(delta: float) -> void:
	_update_occlusion()
	_message_left = maxf(0.0, _message_left - delta)
	marker.visible = actor.has_jump_preview or actor.state == TraversalActor.State.JUMPING
	if marker.visible:
		marker.global_position = actor.locked_landing() if actor.state == TraversalActor.State.JUMPING else actor.selected_destination
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * params.landing_lift,
		actor.global_position + Vector3.DOWN * params.shadow_range, params.world_mask, [actor.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	shadow.visible = not hit.is_empty()
	if shadow.visible:
		shadow.global_position = hit["position"] + Vector3.UP * params.shadow_lift
	var hint := "朝青色牆持續走即可附牆；屋頂朝牆外緣走可下牆"
	if actor.state == TraversalActor.State.CLIMBING:
		hint = "W/S 上下 · A/D 橫移 · 到頂翻上／到底落地 · Space 放手"
	elif actor.state == TraversalActor.State.ATTACHING:
		hint = "正在附牆；Space 可要求放手"
	elif actor.state in [TraversalActor.State.JUMPING, TraversalActor.State.MANTLING]:
		hint = "正在通過安全路徑"
	elif marker.visible:
		hint = "Space 跳下低處｜前往下方落點" if actor.preview_is_drop else "Space 跨越間隙｜前往對岸落點"
	elif actor.global_position.y > data.climb_height - params.arrival_tolerance:
		hint = "靠近邊緣按 Space 跨越；朝青色牆外緣走可下牆"
	if actor.edge_blocked:
		if marker.visible:
			hint = "Space 跳下低處" if actor.preview_is_drop else "Space 跨越間隙"
		else:
			hint = actor.jump_refusal
	# 有合法預覽時優先顯示其動作，避免舊提示蓋住現在 Space 將執行的內容。
	_hint.text = hint if actor.has_jump_preview else (_message if _message_left > 0.0 else hint)

func _update_occlusion() -> void:
	# 只淡出擋住鏡頭的灰盒材質；碰撞不變，不新增 Shader 或影響員工感知。
	for body in _block_materials.keys():
		if not is_instance_valid(body):
			_block_materials.erase(body)
			continue
		var mat: StandardMaterial3D = _block_materials[body]
		mat.albedo_color.a = 1.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var excluded: Array[RID] = [actor.get_rid()]
	for i in params.occluder_layers:
		var query := PhysicsRayQueryParameters3D.create(actor.camera.global_position,
			actor.global_position + Vector3.UP * params.height * 0.5, params.world_mask, excluded)
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			break
		var body := result["collider"] as CollisionObject3D
		excluded.append(body.get_rid())
		if _block_materials.has(body):
			var mat: StandardMaterial3D = _block_materials[body]
			mat.albedo_color.a = params.occluder_alpha
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _on_feedback(message: String) -> void:
	_message = message
	_message_left = params.feedback_sec

func _exit_tree() -> void:
	if _squash and _squash.is_valid():
		_squash.kill()
	if is_instance_valid(_landing_audio):
		_landing_audio.stop()
		_landing_audio.stream = null
	if _jump_action_added:
		InputMap.erase_action("traversal_jump")

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

static func disk(color: Color, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.012
	node.mesh = mesh
	node.material_override = material(color)
	return node


func _on_step(delta: float) -> void:
	metrics.advance(delta)
	metrics.finish_if_returned(actor.global_position.distance_to(data.loop_return_center) <= data.loop_return_radius,
		actor.state == TraversalActor.State.GROUNDED)

func _on_landed(height: float, _loudness: float) -> void:
	if height < params.landing_feedback_min_height:
		return
	if _squash and _squash.is_valid():
		_squash.kill()
	_visual.scale = Vector3.ONE
	_visual.position.y = params.height * 0.5
	_squash = create_tween().set_parallel(true)
	var wide := 1.0 / sqrt(params.landing_squash_y)
	_squash.tween_property(_visual, "scale", Vector3(wide, params.landing_squash_y, wide), params.landing_squash_sec * 0.5)
	_squash.tween_property(_visual, "position:y", params.height * params.landing_squash_y * 0.5, params.landing_squash_sec * 0.5)
	_squash.chain().tween_property(_visual, "scale", Vector3.ONE, params.landing_squash_sec * 0.5)
	_squash.parallel().tween_property(_visual, "position:y", params.height * 0.5, params.landing_squash_sec * 0.5)
	if DisplayServer.get_name() != "headless":
		_landing_audio.play()

func _placeholder_tone() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = params.landing_tone_mix_rate
	var count := int(params.landing_tone_sec * wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var value := sin(TAU * params.landing_tone_hz * float(i) / wav.mix_rate) * (1.0 - float(i) / count)
		bytes.encode_s16(i * 2, int(value * 32767))
	wav.data = bytes
	return wav
