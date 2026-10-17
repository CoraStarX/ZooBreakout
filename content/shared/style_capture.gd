extends Node
## 僅在 FormLab 帶 --style-capture=絕對輸出路徑 時啟用；不另建場景或測試入口。
## 輸出三張 A 比較圖、B 可讀性證據；不儲存 Resource、場景或玩家偏好。

func run(host: Node3D, foundation: StyleFoundation, output: String) -> void:
	if not output.is_absolute_path():
		_fail("截圖輸出必須是絕對路徑")
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(output)
	if directory_error != OK:
		_fail("無法建立截圖目錄：%s" % error_string(directory_error))
		return
	var first_physics_frame := Engine.get_physics_frames()
	for _frame in 150:
		await get_tree().physics_frame
	print("STYLE: FormLab settled for %d physics frames" % (Engine.get_physics_frames() - first_physics_frame))
	var original_palette := foundation.active_palette
	var before := _geometry_signature(host)
	var surface_id := foundation.surface_material.get_instance_id()
	var marker_id := foundation.mechanism_material.get_instance_id()
	var marker_parameters := _marker_parameters(foundation)
	var names: Array[String] = ["01_palette_light", "02_environment", "03_outline_toon"]
	for stage in 3:
		foundation.set_features(stage > 0, stage == 2, stage == 2)
		if not await _capture(host, output.path_join(names[stage] + ".png")):
			return
	# B 僅暫時替換記憶體中的色板；預設設定與場景始終指向 A。
	var alternate := preload("res://content/shared/palette_cool_architecture.tres") as StylePalette
	foundation.apply_palette(alternate)
	if foundation.surface_material.get_shader_parameter("building_color") != alternate.building:
		_fail("B 色板未更新建築材質")
		return
	for stage in [0, 2]:
		foundation.set_features(stage > 0, stage == 2, stage == 2)
		if not await _capture(host, output.path_join("verification_b_%d.png" % stage)):
			return
	if before != _geometry_signature(host):
		_fail("切換風格時幾何或靜態場景變動")
		return
	if surface_id != foundation.surface_material.get_instance_id() or marker_id != foundation.mechanism_material.get_instance_id():
		_fail("切換色板時共用材質被替換")
		return
	if marker_parameters != _marker_parameters(foundation):
		_fail("機制色彩隨風格切換改變")
		return
	foundation.apply_palette(original_palette)
	foundation.set_features(foundation.settings.post_enabled, foundation.settings.outline_enabled, foundation.settings.toon_enabled)
	print("STYLE PASS: A/B swap retains geometry, shared material identities and fixed marker parameters; A restored")
	print("STYLE PASS: camera=%s; viewport=%s; output=%s" % [host.get_viewport().get_camera_3d().global_transform, host.get_viewport().get_visible_rect().size, output])
	get_tree().quit(0)

func _capture(host: Node3D, path: String) -> bool:
	for _frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := host.get_viewport().get_texture().get_image()
	var result := screenshot.save_png(path)
	if result != OK:
		_fail("截圖失敗：%s" % error_string(result))
		return false
	print("STYLE CAPTURE: %s" % path)
	return true

func _marker_parameters(foundation: StyleFoundation) -> Array:
	var values: Array = []
	for parameter in ["climb_color", "jump_color", "ink_color", "outline_pixels"]:
		values.append(foundation.mechanism_material.get_shader_parameter(parameter))
	return values

func _geometry_signature(host: Node3D) -> String:
	var values: Array[String] = []
	for node in host.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		values.append(str(body.get_path(), body.transform))
		for child in body.get_children():
			if child is MeshInstance3D:
				var mesh_node := child as MeshInstance3D
				values.append(str(mesh_node.transform, mesh_node.mesh.get_rid(), mesh_node.mesh.get_aabb()))
			elif child is CollisionShape3D:
				var collision := child as CollisionShape3D
				values.append(str(collision.transform, collision.shape.get_rid(), collision.disabled))
	return "\n".join(values)

func _fail(message: String) -> void:
	push_error("STYLE: " + message)
	get_tree().quit(1)
