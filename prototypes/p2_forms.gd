extends Node
## A原型路徑與單元故障注入分開；正式初始化提供形態，不臨時賦予能力。
var passed := 0
var failed := 0
var lab: FormLab
var noises: Array[Dictionary] = []
var messages: Array[String] = []
const DT := 1.0/60.0
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print(("PASS " if ok else "FAIL ")+message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	pure_checks()
	Bus.noise_made.connect(func(point: Vector3, volume: float, kind: StringName) -> void: noises.append({"point":point,"volume":volume,"kind":kind}))
	lab = preload("res://scenes/forms/form_lab.tscn").instantiate() as FormLab
	add_child(lab)
	lab.metrics.source = "原型自動回歸（非手玩）"
	lab.forms.feedback.connect(func(message: String) -> void: messages.append(message))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await guidance_checks()
	await prototype_path()
	lab.actor.set_physics_process(false)
	lab.forms.input_enabled = false
	await push_fixtures()
	await fixtures()
	lab.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await locked_start_check()
	print("=== P2 FORMS A SUMMARY pass=%d fail=%d ===" % [passed,failed])
	get_tree().quit(0 if failed == 0 else 1)

func guidance_checks() -> void:
	var body := lab.actor
	lab.set_guidance_enabled(false)
	lab._message_left = 0
	await get_tree().process_frame
	await get_tree().process_frame
	check(not lab._guidance_title.visible and not lab._hint.visible,"觀察模式隱藏任務與被動形態能力提示")
	var labels_hidden := true
	for node in lab.find_children("*","Label3D",true,false):
		if node is ProximityLabel and node.visible: labels_hidden = false
	check(labels_hidden,"觀察模式隱藏場景路線文字，不改幾何")
	check(lab.actor == body and lab.shadow.visible,"切換提示不換角色，接地陰影仍顯示")
	check(lab.data.jumps.size() == 2 and lab.get_node_or_null("Building") != null and lab.get_node_or_null("LandingPlatform") != null,"保留屋頂／對岸平台與雙向跨間隙連結")
	await capture("observation")
	lab._on_feedback("這裡太窄")
	await get_tree().process_frame
	await get_tree().process_frame
	check(lab._hint.visible and lab._hint.text == "這裡太窄","觀察模式仍保留操作拒絕原因")
	lab.set_guidance_enabled(true)
	check(lab._guidance_title.visible and lab._guidance_toggle.button_pressed,"F3開關同步恢復提示")
	lab.debug_hud.visible = true
	await capture("settings")
	lab.debug_hud.visible = false

func pure_checks() -> void:
	var setup := preload("res://content/forms/prototype_setup.tres")
	check(FormRules.validate_params(preload("res://content/forms/form_params.tres")).is_empty(),"變形參數有效，C前搖保留至少0.5秒約束")
	check(FormRules.validate_setup(setup).is_empty(),"正式原型開局配置有效")
	var base := setup.base_form
	var other: FormDef = setup.forms[1]
	check(base.abilities.has(CapabilityIds.Id.TINY_GAP) and base.abilities.has(CapabilityIds.Id.SQUEEZE),"本體同時有TINY_GAP與SQUEEZE")
	check(not other.abilities.has(CapabilityIds.Id.TINY_GAP) and not other.abilities.has(CapabilityIds.Id.SQUEEZE) and not other.abilities.has(CapabilityIds.Id.THROW),"猴形態兩種小通道能力與THROW皆無")
	check(base.duration_sec == FormDef.DURATION_INFINITE,"具名常數0表示無限；未實作倒數")
	var bad := base.duplicate(true) as FormDef
	bad.duration_sec = -1
	check(not FormRules.validate_form(bad).is_empty(),"載入檢查拒絕負持續時間")
	bad = base.duplicate(true) as FormDef
	bad.body_size.y = 0.1
	check(not FormRules.validate_form(bad).is_empty(),"不合法膠囊尺寸明確拒絕")
	check(FormRules.rejection(base,base,true,false,2,false).contains("太窄"),"回本體只受合法空間檢查，不受移動狀態或冷卻鎖定")
	check(FormRules.rejection(base,base,true,false,2,true).is_empty(),"任意移動狀態回本體不受冷卻")
	check(FormRules.rejection(other,base,true,false,0,true).contains("站穩"),"空中變成其他形態有可讀拒絕")
	check(FormRules.rejection(other,base,true,true,1,true).contains("冷卻"),"冷卻拒絕有原因")
	check(FormRules.rejection(other,base,false,true,0,true).contains("解鎖"),"未解鎖形態不可使用")
	var original := other.movement_profile
	var push_params := preload("res://content/forms/form_params.tres") as FormParams
	var push_dirs := FormRules.push_directions(push_params)
	check(push_dirs.size() == push_params.push_direction_count and push_dirs.all(func(d: Vector3) -> bool: return is_equal_approx(d.length(),1) and d.y == 0),"推開純函式方向數有界、同層、無隨機")
	check(FormRules.same_support_level(3,3.001,push_params) and not FormRules.same_support_level(0,3,push_params),"高度純函式只容忍誤差，不允許跨樓層")
	var footprint := FormRules.footprint_offsets(other)
	check(footprint.size() == maxi(original.edge_probe_count,4) and footprint.all(func(p: Vector3) -> bool: return is_equal_approx(p.length(),other.collision_radius()+original.edge_safety_margin)),"支撐純函式沿用目標體型半徑與原邊緣安全參數")
	var derived := other.movement_params()
	check(derived != original and derived.speed == original.speed and derived.height == original.height and derived.radius == original.radius,"猴配置派生但數值對齊凍結移動，不污染共用資源")

func release_inputs() -> void:
	for action in ["move_left","move_right","move_forward","move_back","traversal_jump","transform"]: Input.action_release(action)
func world_input(direction: Vector3) -> void:
	var right := lab.actor.camera.global_basis.x
	right.y = 0
	var back := lab.actor.camera.global_basis.z
	back.y = 0
	var axes := Vector2(direction.dot(right.normalized()),direction.dot(back.normalized()))
	Input.action_press("move_right",maxf(axes.x,0))
	Input.action_press("move_left",maxf(-axes.x,0))
	Input.action_press("move_back",maxf(axes.y,0))
	Input.action_press("move_forward",maxf(-axes.y,0))
func wait_until(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call(): return true
		await get_tree().physics_frame
	return false
func press_transform() -> void:
	Input.action_press("transform")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("transform")
	await get_tree().physics_frame

func prototype_path() -> void:
	var controller := lab.forms
	var base := lab.form_setup.base_form
	var other: FormDef = lab.form_setup.forms[1]
	check(controller.current_form == base and controller.unlocked_forms.has(other),"原型路徑：正式初始化為本體，猴由可配置初始解鎖提供")
	check(lab.actor is GroundFormActor and lab.actor.params.speed == 4 and lab.actor.params.height == base.body_size.y,"本體地面控制與完整小體型")
	await capture("base")
	noises.clear()
	Input.action_press("traversal_jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("traversal_jump")
	check(lab.actor.state == TraversalActor.State.GROUNDED and noises.is_empty(),"本體Space只提示，不跳躍、不發腳步或跳躍聲")
	var start := lab.actor.global_position
	await press_transform()
	check(controller.current_form == other and lab.actor.global_position.distance_to(start) < 0.1,"Q變形瞬間完成且腳底位置保持")
	check(controller.cooldown_remaining() > 0 and lab._effect_left > 0,"成功變形起算冷卻，光效不是輸入鎖")
	check(noises.any(func(n: Dictionary) -> bool: return n.kind == &"transform" and n.volume == 1),"成功主動變形發音量1的既有Bus事件")
	check(get_tree().get_nodes_in_group("controlled").size() == 1,"只有一個有效受控角色，沒有雙碰撞／雙輸入")
	await capture("monkey")
	var deadline := controller.cooldown_until
	await press_transform()
	check(controller.current_form == base and controller.cooldown_until == deadline,"主動回本體不受冷卻且不改截止時間")
	await press_transform()
	check(controller.current_form == base and messages.back().contains("冷卻"),"立即再次變猴明確拒絕，不重置冷卻")
	await capture("cooldown")
	check(await wait_until(func() -> bool: return controller.cooldown_remaining() == 0,240),"原型路徑自然等待冷卻，未手改時間")
	await press_transform()
	check(controller.current_form == other,"冷卻後可再次變猴")
	world_input((Vector3(-3,0,2)-lab.actor.global_position).normalized())
	check(await wait_until(func() -> bool: return Vector2(lab.actor.global_position.x+3,lab.actor.global_position.z-2).length() < 0.2,240),"原型路徑實際走到攀爬面前")
	release_inputs()
	world_input(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return lab.actor.state == TraversalActor.State.CLIMBING,180),"原型路徑沿用凍結自動附牆")
	release_inputs()
	Input.action_press("move_forward")
	check(await wait_until(func() -> bool: return lab.actor.global_position.y > 1.1,150),"原型路徑實際攀爬，沒有臨時賦予能力")
	release_inputs()
	await press_transform()
	check(controller.current_form == base and lab.actor.state == TraversalActor.State.AIRBORNE,"掛牆回本體立即自然下落")
	check(await wait_until(func() -> bool: return lab.actor.state == TraversalActor.State.GROUNDED,240),"本體下落後合法接地，不卡死")
	check(lab.metrics.accidental_falls == 0,"主動掛牆退回不誤報為意外墜落")
	check(noises.any(func(n: Dictionary) -> bool: return n.kind == &"landing" and n.volume > 0),"掛牆退回落地沿用有高度門檻的噪音")
	check(await wait_until(func() -> bool: return controller.cooldown_remaining() == 0,240),"冷卻自然結束")
	await press_transform()
	world_input(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return lab.actor.state == TraversalActor.State.CLIMBING,180),"再次附牆")
	release_inputs()
	Input.action_press("move_forward")
	check(await wait_until(func() -> bool: return lab.actor.state == TraversalActor.State.GROUNDED and lab.actor.global_position.y > 2.9,240),"原型路徑爬上屋頂")
	release_inputs()
	await press_transform()
	check(controller.current_form == base and lab.actor.global_position.y > 2.9,"屋頂上可回本體，保持腳底高度")
	check(await wait_until(func() -> bool: return controller.cooldown_remaining() == 0,240),"屋頂等待冷卻")
	await press_transform()
	check(controller.current_form == other and lab.actor.state == TraversalActor.State.GROUNDED,"接地包含屋頂頂面，可變猴")
	for point in [Vector3(-3,3.04,-2),Vector3(-3,3.04,-4.28),Vector3(-5.78,3.04,-2),Vector3(-0.22,3.04,-2),Vector3(-5.78,3.04,-4.28),Vector3(5,3.04,-2)]:
		check(controller.walkable_support(other,point) == lab.actor._walk_footprint(point),"變形支撐與凍結猴步行足跡一致：%s" % point)
	await capture("roof")
	release_inputs()
	await press_transform()
	check(await wait_until(func() -> bool: return controller.cooldown_remaining() == 0,240),"邊緣回歸沿正式路徑等待冷卻")
	world_input(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return lab.actor.global_position.z < -4.25,240),"本體實際走到屋頂後緣，持續按住方向")
	var edge_point := lab.actor.global_position
	var edge_noise_count := noises.size()
	print("FORM EDGE point=",edge_point," base_support=",controller.walkable_support(base,edge_point)," target_support=",controller.walkable_support(other,edge_point))
	await press_transform()
	check(controller.current_form == other and lab.actor.global_position.z > edge_point.z and controller.walkable_support(other,lab.actor.global_position),"邊緣Q自動推回最近合法位置並變猴")
	check(noises.size() == edge_noise_count+1 and noises.back().point.is_equal_approx(lab.actor.global_position),"推開後只在最終位置發一次變形聲")
	await capture("edge_push")
	release_inputs()
	world_input(Vector3.BACK)
	check(await wait_until(func() -> bool: return lab.actor.global_position.z > edge_point.z+0.6,90),"邊緣推開變猴後可直接往內走，不需Space脫困")
	var before_move := lab.actor.global_position
	for i in 8: await get_tree().physics_frame
	check(lab.actor.global_position.distance_to(before_move) > 0.2,"邊緣回退變猴後步行正常，不被邊緣保護鎖住")
	release_inputs()

func test_box(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = point
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = lab.material(Color(0.5,0.53,0.58))
	body.add_child(visual)
	lab._block_materials[body] = visual.material_override
	lab.add_child(body)
	return body

func fixture_base(point: Vector3) -> void:
	lab.forms.force_return("推開單元情境")
	lab.actor.set_physics_process(false)
	lab.actor.global_position = point
	lab.actor.state = TraversalActor.State.GROUNDED
	lab.forms.now = lab.forms.cooldown_until+DT

func push_fixtures() -> void:
	var controller := lab.forms
	var base := lab.form_setup.base_form
	var target: FormDef = lab.form_setup.forms[1]
	var origin := lab.form_setup.spawn
	fixture_base(origin)
	var wall := test_box(Vector3(origin.x+0.18,1,origin.z),Vector3(0.02,2,4))
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(controller.space_clear(base,origin) and not controller.space_clear(target,origin),"靠牆開闊地面：本體站得下，猴原位放不下")
	var placements: Array[Dictionary] = []
	var listener := func(_old: FormDef, _new: FormDef, point: Vector3, _forced: bool, _reason: String) -> void:
		placements.append({"event":point,"actor":lab.actor.global_position,"form":controller.current_form})
	controller.transform_committed.connect(listener)
	var before_noise := noises.size()
	check(controller.request_form(target),"開闊地面靠牆可自動推開變猴")
	var placed := lab.actor.global_position
	check(placed.distance_to(origin) <= controller.params.push_max_distance and placed.y == origin.y and controller.space_clear(target,placed) and controller.walkable_support(target,placed),"推開有界、同高度、同份完整碰撞與支撐預檢")
	check(placements.size() == 1 and placements[0].event == placed and placements[0].actor == placed and placements[0].form == target,"事件觀察到的已是最終形態與最終位置，無中間狀態")
	check(noises.size() == before_noise+1 and noises.back().point == placed and lab._effect.global_position.is_equal_approx(placed+Vector3.UP*lab.form_params.effect_lift),"變形聲與0.3秒光效使用推開後最終位置")
	var wall_surface := origin.x+0.17
	var lower := target.collision_radius()
	var upper := target.collision_radius()+target.movement_profile.edge_safety_margin*2
	for i in 20:
		var middle := (lower+upper)*0.5
		var probe := Vector3(wall_surface-middle,origin.y,origin.z)
		if controller.space_clear(target,probe) and controller.walkable_support(target,probe): upper = middle
		else: lower = middle
	print("FORM WALL minimum_center_clearance=",upper," pushed_distance=",placed.distance_to(origin)," max=",controller.params.push_max_distance)
	check(absf((wall_surface-placed.x)-upper) < 0.002 and absf(placed.z-origin.z) < 0.002,"直牆找到最短方向與邊界附近合法位置，無多餘遠移")
	lab.actor.set_physics_process(false)
	await capture("wall_push")
	controller.transform_committed.disconnect(listener)
	wall.queue_free()
	await get_tree().physics_frame
	fixture_base(origin)
	var left := test_box(Vector3(origin.x-0.235,1,origin.z),Vector3(0.02,2,4))
	var right := test_box(Vector3(origin.x+0.235,1,origin.z),Vector3(0.02,2,4))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var old := lab.actor
	before_noise = noises.size()
	check(not controller.request_form(target) and messages.back() == "這裡太窄","0.45公尺窄縫內仍拒絕，不靠推開繞過空間門檻")
	check(lab.actor == old and lab.actor.global_position == origin and controller.cooldown_remaining() == 0 and noises.size() == before_noise,"找不到位置時原子拒絕，不移位、不扣冷卻、不發聲")
	left.queue_free()
	right.queue_free()
	await get_tree().physics_frame
	fixture_base(origin)
	wall = test_box(Vector3(origin.x+0.18,1,origin.z),Vector3(0.02,2,4))
	var low_roof := test_box(Vector3(origin.x-0.415,0.6,origin.z),Vector3(1.17,0.1,4))
	var old_params := controller.params
	controller.params = old_params.duplicate(true) as FormParams
	controller.params.push_max_distance = 0.8
	await get_tree().physics_frame
	await get_tree().physics_frame
	var across := origin+Vector3.RIGHT*0.6
	check(controller.space_clear(target,across) and controller.walkable_support(target,across) and not controller.push_path_clear(origin,across),"薄牆對面雖合法，本體連續掃掠仍擋下穿牆")
	check(not controller.request_form(target) and lab.actor.global_position == origin,"即使放大測試上限也不推到薄牆另一側")
	controller.params = old_params
	wall.queue_free()
	low_roof.queue_free()
	await get_tree().physics_frame
	check(not controller.push_path_clear(origin,origin+Vector3(0.1,1,0)),"推開路徑不得改變高度層")
	check(not controller.push_path_clear(Vector3(-0.4,3.04,-2),Vector3(0.1,3.04,-2)),"推開路徑不得停在屋頂外無支撐位置")
	# 正式開局沿用的同一攀爬面，從一般地面靠近變形，持續朝牆即可附著。
	fixture_base(Vector3(-3,0.04,0.7))
	check(controller.request_form(target),"攀爬面前普通地面可自動推開變形")
	world_input(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return lab.actor.state == TraversalActor.State.CLIMBING,180),"推開變猴後直接朝攀爬面走即可附著，不需特殊站位")
	release_inputs()
	controller.force_return("結束推開回歸")
	lab.actor.set_physics_process(false)

func fixtures() -> void:
	var controller := lab.forms
	var base := lab.form_setup.base_form
	var other: FormDef = lab.form_setup.forms[1]
	controller.force_return("測試故障注入")
	lab.actor.set_physics_process(false)
	lab.actor.global_position = lab.form_setup.spawn
	lab.actor.state = TraversalActor.State.GROUNDED
	controller.now = controller.cooldown_until+DT
	var ceiling := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,0.3,2)
	col.shape = box
	ceiling.position = lab.form_setup.spawn+Vector3.UP*0.65
	ceiling.add_child(col)
	lab.add_child(ceiling)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var old := lab.actor
	var prior := noises.size()
	check(controller.space_clear(base,lab.actor.global_position) and not controller.space_clear(other,lab.actor.global_position),"低頂故障注入：完整本體可容納、完整猴體不可容納")
	check(not controller.request_form(other) and messages.back().contains("太窄"),"空間拒絕明確提示")
	check(lab.actor == old and noises.size() == prior and controller.cooldown_remaining() == 0,"拒絕原子性：不換角色、不發聲、不扣冷卻")
	ceiling.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	for state in [TraversalActor.State.AIRBORNE,TraversalActor.State.JUMPING,TraversalActor.State.CLIMBING,TraversalActor.State.MANTLING,TraversalActor.State.ATTACHING]:
		controller.now = controller.cooldown_until+DT
		lab.actor.state = TraversalActor.State.GROUNDED
		check(controller.request_form(other),"狀態矩陣準備：變猴")
		lab.actor.set_physics_process(false)
		lab.actor.state = state
		var deadline := controller.cooldown_until
		var before := noises.size()
		check(controller.force_return("變形時被看見") and controller.current_form == base and controller.cooldown_until == deadline,"強制退回不被狀態%d或特效鎖住、不重置冷卻" % state)
		lab.actor.set_physics_process(false)
		check(noises.size() == before,"強制退回不再發變形聲，避免目擊連鎖")
		check(not controller.request_form(other) and messages.back().contains("站穩"),"空中／掛牆／過渡後變猴有站穩提示")
	for state in [TraversalActor.State.AIRBORNE,TraversalActor.State.JUMPING,TraversalActor.State.CLIMBING,TraversalActor.State.MANTLING,TraversalActor.State.ATTACHING]:
		controller.now = controller.cooldown_until+DT
		lab.actor.state = TraversalActor.State.GROUNDED
		controller.request_form(other)
		lab.actor.set_physics_process(false)
		lab.actor.state = state
		var deadline := controller.cooldown_until
		check(controller.request_form(base) and controller.cooldown_until == deadline,"主動回本體不被狀態%d或特效鎖住、不重置冷卻" % state)
		lab.actor.set_physics_process(false)
	controller.now = controller.cooldown_until+DT
	lab.actor.global_position = Vector3(5,3.04,-2)
	lab.actor.state = TraversalActor.State.GROUNDED
	check(controller.request_form(other),"實體平台頂面也屬接地，可變猴")
	lab.actor.set_physics_process(false)
	var blocked := lab.actor.global_position
	var blocker := StaticBody3D.new()
	var blocked_col := CollisionShape3D.new()
	var blocked_box := BoxShape3D.new()
	blocked_box.size = Vector3.ONE
	blocked_col.shape = blocked_box
	blocker.position = blocked+Vector3.UP*0.5
	blocker.add_child(blocked_col)
	lab.add_child(blocker)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before_recovery := controller.cooldown_until
	check(controller.force_return("重疊故障注入") and controller.current_form == base and lab.actor.global_position.distance_to(blocked) > 0.5 and controller.space_clear(base,lab.actor.global_position),"故障注入：退回目標重疊時只使用碰撞／支撐驗證過的合法恢復點")
	lab.actor.set_physics_process(false)
	check(controller.cooldown_until == before_recovery,"合法恢復也不改冷卻截止時間")
	blocker.queue_free()
	await get_tree().physics_frame
	var count := noises.size()
	check(controller.force_return("已是本體") and noises.size() == count,"已是本體時強制退回冪等")

func capture(tag: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/forms_a_%s_%d.png" % [tag,size.x])

func locked_start_check() -> void:
	var alternate := preload("res://content/forms/prototype_setup.tres").duplicate(true) as FormSetup
	alternate.initial_unlocked_forms.clear()
	alternate.initial_unlocked_forms.append(alternate.base_form)
	var other_lab := preload("res://scenes/forms/form_lab.tscn").instantiate() as FormLab
	other_lab.form_setup = alternate
	add_child(other_lab)
	await get_tree().physics_frame
	check(other_lab.forms.current_form == alternate.base_form and other_lab.forms.unlocked_forms.size() == 1,"可配置未解鎖開局：正式初始化只提供本體")
	check(not other_lab.forms.request_cycle(),"未解鎖時Q不會臨時賦予猴能力")
	other_lab.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
