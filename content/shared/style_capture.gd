extends Node
## FormLab 唯一驗收入口；A/B 只改 settings.palette，來源不寫回。
var _section: SubViewport
var _section_style: StyleFoundation

func run(host: Node3D, foundation: StyleFoundation, output: String) -> void:
	if not output.is_absolute_path():
		_fail("截圖輸出必須是絕對路徑")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("無法建立截圖目錄")
		return
	for _frame in 150:
		await get_tree().physics_frame
	var original := foundation.settings.palette
	var geometry := _geometry_signature(host)
	var markers := _marker_parameters(foundation)
	var features := _feature_parameters(foundation)
	var ids := [foundation.surface_material.get_instance_id(), foundation.mechanism_material.get_instance_id(),
		foundation.kit_building_material.get_instance_id(), foundation.kit_platform_material.get_instance_id()]
	_build_section(host, foundation)
	if not await _check_kit_assets(foundation):
		return
	var palettes: Array[StylePalette] = [preload("res://content/shared/palette_warm_courtyard.tres"),
		preload("res://content/shared/palette_cool_architecture.tres"), original]
	var names: Array[String] = ["a", "b", "restored"]
	for index in palettes.size():
		foundation.settings.palette = palettes[index]
		if not _check_colors(foundation, palettes[index]) or not _check_colors(_section_style, palettes[index]):
			return
		if not _require(markers == _marker_parameters(foundation) and markers == _marker_parameters(_section_style), "機制色值改變"):
			return
		if not _require(features == _feature_parameters(foundation) and features == _feature_parameters(_section_style), "後製／描邊／toon 參數改變"):
			return
		if DisplayServer.get_name() != "headless" and index < 2:
			if not await _capture(host.get_viewport(), output.path_join("form_lab_" + names[index] + ".png")):
				return
			if not await _capture(_section, output.path_join("section_" + names[index] + ".png")):
				return
		print("STYLE PASS: %s palette reference, building/platform/ground, kit roles, fixed mechanism colors/features" % names[index])
	if not _require(geometry == _geometry_signature(host), "FormLab 幾何變動"):
		return
	if not _require(ids == [foundation.surface_material.get_instance_id(), foundation.mechanism_material.get_instance_id(),
		foundation.kit_building_material.get_instance_id(), foundation.kit_platform_material.get_instance_id()], "共用材質身分變動"):
		return
	print("STYLE PASS: A/B/A through settings.palette; geometry and material identities retained; original restored")
	print("STYLE: section is memory-only; camera=%s; no scene/resource saves" % _section.get_camera_3d().global_transform)
	get_tree().quit(0)

func _build_section(host: Node3D, foundation: StyleFoundation) -> void:
	_section = SubViewport.new()
	_section.size = Vector2i(1000, 900)
	_section.own_world_3d = true
	_section.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_section)
	var root := Node3D.new()
	_section.add_child(root)
	_section_style = preload("res://content/shared/environment_preset.tscn").instantiate() as StyleFoundation
	_section_style.settings = foundation.settings
	root.add_child(_section_style)
	var paths: Array[String] = ["floor_w4_h1_d4", "wall_straight_w4_h5_d1", "floor_w4_h1_d4"]
	var positions: Array[Vector3] = [Vector3(0, 0, 0.5), Vector3(0, 0.5, 0), Vector3(0, 3, -0.5)]
	for index in paths.size():
		var piece := (load("res://art/kit/" + paths[index] + ".tscn") as PackedScene).instantiate() as Node3D
		piece.position = positions[index]
		root.add_child(piece)
		_section_style.configure_kit(piece.get_node("Visual/MeshInstance3D") as MeshInstance3D, 0 if index == 1 else 1)
	# 既有攀爬標記跨牆與樓板側面；只作材質辨識截圖，不驗證玩法。
	var climb := preload("res://scenes/traversal/climb_surface.tscn").instantiate() as ClimbSurface
	climb.width = 0.8
	climb.height = 3.0
	climb.enabled = false
	climb.position = Vector3(-0.5, 0.5, 0.5)
	root.add_child(climb)
	var visual := climb.get_node("VisualMarker") as MeshInstance3D
	visual.visible = true
	_section_style.configure_marker(visual, true)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.5
	camera.position = Vector3(5, 4.5, 8)
	root.add_child(camera)
	camera.look_at(Vector3(0, 1.65, 0))
	camera.current = true
	print("STYLE: memory section floor/wall/slab; cyan marker extends to slab top; host=%s" % host.name)

func _check_kit_assets(foundation: StyleFoundation) -> bool:
	var directory := DirAccess.open("res://art/kit")
	for filename in directory.get_files():
		if not filename.ends_with(".tscn"):
			continue
		var piece := (load("res://art/kit/" + filename) as PackedScene).instantiate() as Node3D
		_section.add_child(piece)
		var visual := piece.get_node("Visual/MeshInstance3D") as MeshInstance3D
		var material := visual.material_override as KitRoleMaterial
		var role := 1 if filename.begins_with("floor_") or filename.begins_with("ramp_") else 0
		if not _require(material != null and material.role == role and material.palette == foundation.settings.palette, filename + ": resource role/palette"):
			piece.free()
			return false
		if not _require(material.shader == foundation.surface_material.shader and int(visual.get_instance_shader_parameter("color_role")) == role, filename + ": shared shader/instance role"):
			piece.free()
			return false
		if filename.begins_with("ramp_"):
			var original_points: PackedVector3Array = (piece.get_node("Body/CollisionShape3D").shape as ConvexPolygonShape3D).points
			for size in [Vector3(1.5, 2.5, 5.5), Vector3(2, 3, 6)]:
				piece.set("width", size.x)
				piece.set("height", size.y)
				piece.set("length", size.z)
				await get_tree().process_frame
				await get_tree().process_frame
				if not _require(visual.get_instance_shader_parameter("shape_size") == size and visual.get_instance_shader_parameter("ramp_shape") == true, "斜坡尺寸／shader 不同步"):
					piece.free()
					return false
				if not _require(visual.mesh.get_aabb().size.is_equal_approx(size), "斜坡 Mesh 尺寸不符"):
					piece.free()
					return false
			if not _require(original_points == (piece.get_node("Body/CollisionShape3D").shape as ConvexPolygonShape3D).points, "斜坡恢復後碰撞改變"):
				piece.free()
				return false
		else:
			if not _require(visual.get_instance_shader_parameter("shape_size") == visual.mesh.get_aabb().size and visual.get_instance_shader_parameter("ramp_shape") == false, filename + ": shape uniforms"):
				piece.free()
				return false
		print("STYLE PASS: kit resource %s role=%d; shared shader and independent shape uniforms" % [filename, role])
		piece.free()
	return true

func _check_colors(foundation: StyleFoundation, palette: StylePalette) -> bool:
	if not _require(foundation.active_palette == palette, "Foundation 未讀取設定色板"):
		return false
	for material in [foundation.surface_material, foundation.kit_building_material, foundation.kit_platform_material]:
		for role in ["building", "platform", "ground", "highlight", "ink"]:
			if not _require(material.get_shader_parameter(role + "_color") == palette.get(role), "材質色值未更新：" + role):
				return false
	for material in [foundation.kit_building_material, foundation.kit_platform_material]:
		if not _require(material.palette == palette, "kit 未引用同一 palette Resource"):
			return false
	return true

func _capture(viewport: Viewport, path: String) -> bool:
	for _frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not _require(viewport.get_texture().get_image().save_png(path) == OK, "截圖失敗：" + path):
		return false
	print("STYLE CAPTURE: " + path)
	return true

func _marker_parameters(foundation: StyleFoundation) -> Array:
	var values: Array = []
	for parameter in ["climb_color", "jump_color", "ink_color", "outline_pixels"]:
		values.append(foundation.mechanism_material.get_shader_parameter(parameter))
	return values

func _feature_parameters(foundation: StyleFoundation) -> Array:
	var values: Array = []
	for parameter in ["outline_enabled", "toon_enabled", "outline_pixels", "toon_steps"]:
		values.append(foundation.surface_material.get_shader_parameter(parameter))
	var environment := (foundation.get_node("WorldEnvironment") as WorldEnvironment).environment
	values.append([environment.fog_enabled, environment.ssao_enabled, environment.glow_enabled])
	return values

func _geometry_signature(host: Node3D) -> String:
	var values: Array[String] = []
	for node in host.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.get_viewport() != host.get_viewport():
			continue
		values.append(str(body.get_path(), body.transform))
		for child in body.get_children():
			if child is MeshInstance3D:
				var mesh_node := child as MeshInstance3D
				values.append(str(mesh_node.transform, mesh_node.mesh.get_rid(), mesh_node.mesh.get_aabb()))
			elif child is CollisionShape3D:
				var collision := child as CollisionShape3D
				values.append(str(collision.transform, collision.shape.get_rid(), collision.disabled))
	return "\n".join(values)

func _require(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
	return condition

func _fail(message: String) -> void:
	push_error("STYLE: " + message)
	get_tree().quit(1)
