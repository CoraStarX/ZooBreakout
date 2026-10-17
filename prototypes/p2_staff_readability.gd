extends Node
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print(("PASS " if ok else "FAIL ") + message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var p := StaffReadabilityParams.new()
	check(p.ai.resource_path != "res://content/staff/default_staff_ai_params.tres", "沙盒 AI 資源獨立，調參不改正式員工")
	var obstacles: Array[Dictionary] = [{"rect":Rect2(-2,-4,4,4), "roof":true}]
	var polygon := StaffPerceptionFootprint.build(Vector3(0,0,3),Vector3.FORWARD,obstacles,p)
	check(StaffPerceptionFootprint.contains(polygon,Vector3(0,3,-0.49)), "屋頂近側內緣 0.49 格可見")
	check(not StaffPerceptionFootprint.contains(polygon,Vector3(0,3,-0.51)), "屋頂內緣超過 0.5 格遮擋")
	check(not StaffPerceptionFootprint.contains(polygon,Vector3(0,3,-4.1)), "不可穿過建築看另一側")
	var projection := StaffPerceptionFootprint.projected(Vector3(0,2,0),true,Vector3.ZERO,Vector3.BACK,0.4)
	check(projection == Vector3(0,0,0.4) and StaffPerceptionFootprint.contains(polygon,projection), "攀爬投影牆外落點可見")
	var normal := StaffAwarenessMath.visibility_multiplier(p.ai,3,true,true,2)
	check(is_equal_approx(StaffAwarenessMath.visibility_multiplier(p.ai,3,true,true,2,[p.climb_visibility_mult]),normal * 1.5), "貼牆暴露倍率 1.5")
	check(StaffPerceptionFootprint.contains(polygon,StaffPerceptionFootprint.projected(Vector3(0,4,1),false,Vector3.ZERO,Vector3.ZERO,0)), "空中建築外投影按一般地面判定")
	var triangles := StaffPerceptionFootprint.mesh(polygon,p.fan_lift).get_faces()
	var consistent := true
	for x in range(-7,8):
		for z in range(-5,8):
			var point := Vector3(x * 0.4,0,z * 0.4)
			var drawn := false
			for i in range(0, triangles.size(),3):
				var triangle := PackedVector2Array([StaffPerceptionFootprint.flat(triangles[i]),StaffPerceptionFootprint.flat(triangles[i+1]),StaffPerceptionFootprint.flat(triangles[i+2])])
				if Geometry2D.is_point_in_polygon(StaffPerceptionFootprint.flat(point),triangle): drawn = true
			consistent = consistent and drawn == StaffPerceptionFootprint.contains(polygon,point)
	check(not StaffPerceptionFootprint.walkable_line(Vector3(0,0,-2),Vector3(0,0,-2),obstacles,p.body_radius), "禁止範圍內零距離目標也不能視為合法")
	check(consistent,"195 個取樣位置的顯示三角網格與判定一致")
	check(p.ai.min_telegraph_sec >= 0.5,"預警參數不低於 0.5 秒")
	check(StaffPerceptionFootprint.heard(Vector3.ZERO,Vector3(4,3,0),1,true,p),"歇崗仍可聽到高處聲音")
	check(not StaffPerceptionFootprint.heard(Vector3.ZERO,Vector3(9,0,0),1,true,p),"歇崗聽距縮小")
	p.rest_hearing_mult = 0
	check(StaffPerceptionFootprint.heard(Vector3.ZERO,Vector3(0.5,0,0),1,true,p),"歇崗聽覺資料誤設零仍保留最低聽距")
	p.rest_hearing_mult = 0.6
	check(StaffPerceptionFootprint.extend_deadline(0,8,false,p) == 16 and StaffPerceptionFootprint.extend_deadline(0,16,true,p) == 16,"搜索延長一次且最多兩倍")
	var archive := StaffReadabilityMetrics.new(p)
	p.event_limit = 1
	archive.event(0,"chase_started",{"cause":"原始攀爬來源"})
	for i in 3: archive.event(float(i+1),"heard",{"kind":"climb"})
	check(archive.report().contains("原始攀爬來源"), "追捕來源不被聲音事件淘汰，始終可複製追溯")
	check(StaffPerceptionFootprint.ground_supported(Vector3(0,0.158888,0),0,p), "純函式：地面支撐容許落地殘高")
	check(not StaffPerceptionFootprint.ground_supported(Vector3(0,3.04,0),3,p) and not StaffPerceptionFootprint.ground_supported(Vector3(0,0.158888,0),INF,p), "純函式：屋頂支撐與無支撐不算地面")
	noise_and_stage_pure_checks()
	await integration_checks()
	print("=== P2 STAFF READABILITY SUMMARY pass=%d fail=%d ===" % [passed,failed])
	get_tree().quit(0 if failed == 0 else 1)

var lab: StaffReadabilityLab
var staff: ReadabilityStaff
const DT := 1.0 / 60.0

func reset_staff(position: Vector3 = Vector3(-3,0,1.7)) -> void:
	staff.params = lab.staff_params.duplicate(true) as StaffReadabilityParams
	# 外部 AI .tres 必須明確複製，快累積的故障注入不得污染後續正式數值驗證。
	staff.params.ai = lab.staff_params.ai.duplicate(true) as StaffAiParams
	staff.global_position = position
	staff.velocity = Vector3.ZERO
	staff.facing = Vector3.FORWARD
	staff.state = &"WORK"
	staff.awareness = 0
	staff.known = {}
	staff.now = 0
	staff.sensor = Callable()
	staff._cooldowns.clear()
	staff._state_since = 0
	staff._first_seen_at = -INF
	staff._last_seen_at = -INF
	staff._next_climb_noise_at = -INF
	staff._warning_since = -INF
	staff._lost_since = -INF
	staff._pause_until = 0
	staff._arrival_until = 0
	staff._rest_pending = false
	staff._route_index = 0
	staff._noise_contribution = 0
	staff._last_noise = {}
	staff._search_memory = {}
	staff._search_start = -INF
	staff._search_deadline = -INF
	staff._search_extended = false
	staff.route = [position]
	staff.metrics.reset()

func observation(position: Vector3, reachable: bool, key: String = "Building") -> Dictionary:
	return {"projection":position,"actual":str(position+Vector3.UP*3),"reachable":reachable,"approach":staff.global_position,"key":key,"speed":2.5,"climbing":false}

func integration_checks() -> void:
	lab = preload("res://scenes/traversal/staff_readability_lab.tscn").instantiate() as StaffReadabilityLab
	add_child(lab)
	lab.actor.set_physics_process(false)
	lab.actor.input_enabled = false
	staff = lab.staff
	staff.set_physics_process(false)
	staff.metrics.source = "自動回歸（非手玩）"
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(get_tree().get_nodes_in_group("readability_staff").size() == 1,"沙盒只有一名員工")
	await readability_revision_checks()
	await rest_player_noise_check()
	if "--readability-focused" in OS.get_cmdline_user_args():
		lab.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
		return
	await handplay_regressions()
	reset_staff()
	var high := observation(Vector3(-3,0,0.1),false)
	staff.state = &"REST"
	staff._rest_until = 6
	staff.step(DT,high)
	check(staff.awareness == 0 and staff.icon().begins_with("Zz"),"歇崗關閉視覺且顯示休息圖示")
	Bus.noise_made.emit(Vector3(-3,3,0.1),1.0,&"climb")
	check(staff.metrics.counters.rest_heard == 1 and staff.state == &"INVESTIGATE","歇崗聽見事件一次並中斷休息去調查")
	reset_staff()
	for lap in 3:
		staff._route_index = 0
		staff.state = &"WORK"
		staff.step(DT)
		staff.step(DT)
		check(staff.state == &"REST" and staff.metrics.counters.rest_started == lap+1,"每圈都安排一次歇崗：%d" % (lap+1))
		staff.now = staff._rest_until
		staff.step(DT)
	reset_staff()
	staff._rest_pending = true
	staff.state = &"INVESTIGATE"
	staff.known = high
	staff._investigate_until = 3
	staff.step(DT)
	check(staff.metrics.counters.rest_started == 0 and staff._rest_pending,"調查期間保留待歇崗，不強制中斷")

	reset_staff(Vector3(10,0,6))
	staff.facing = Vector3.LEFT
	var original_gain := lab.staff_params.ai.accumulate_per_sec
	staff.params.ai.accumulate_per_sec = 10000
	check(lab.staff_params.ai.accumulate_per_sec == original_gain,"故障注入的快累積參數不污染沙盒原始 Resource")
	var ground := observation(Vector3(7,0,6),true,"")
	staff.step(DT,ground)
	var warning_time := staff._warning_since
	check(staff.icon() == "?" and staff.metrics.counters.chase_started == 0,"高累積速度仍先顯示起疑預警")
	for i in 28: staff.step(DT,ground)
	check(staff.metrics.counters.chase_started == 0,"預警未達 0.5 秒不能追捕")
	for i in 8: staff.step(DT,ground)
	var chase_events := staff.metrics.events.filter(func(e: Dictionary) -> bool: return e.kind == "chase_started")
	check(not chase_events.is_empty() and float(chase_events[0].time)-warning_time >= 0.5,"實際追捕事件距預警至少 0.5 秒")

	reset_staff(Vector3(-8,0,5))
	staff.state = &"CHASE"
	staff.awareness = 100
	staff.known = high.duplicate(true)
	staff._lost_since = -2
	staff.step(DT)
	check(staff.metrics.counters.search_started == 0, "遠處丟失高處目標，先到牆下而非提早開始八秒計時")
	for i in 300:
		staff.step(DT)
		if staff.state == &"SEARCH": break
	check(staff.state == &"SEARCH" and staff.global_position.distance_to(high.approach) <= staff.params.arrival_distance and is_equal_approx(staff._search_deadline-staff._search_start,8), "抵達牆下後才獲得完整八秒搜索")
	reset_staff()
	staff.state = &"CHASE"
	staff.awareness = 100
	staff.step(DT,high)
	check(staff.state == &"SEARCH" and is_equal_approx(staff._search_deadline-staff._search_start,8),"已追捕後高處目標到牆下開始八秒搜索")
	Bus.noise_made.emit(Vector3(-3,3,0.1),1.0,&"jump")
	for i in 20: Bus.noise_made.emit(Vector3(-3,3,0.1),1.0,&"climb")
	check(staff.metrics.counters.search_extended == 1 and is_equal_approx(staff._search_deadline-staff._search_start,16),"高處噪音只延長一次，反覆噪音不超過十六秒")
	staff.now = staff._search_deadline - DT
	staff.step(DT,high)
	check(staff.metrics.counters.search_abandoned == 1 and staff.state == &"RETURN" and staff.cooling(high),"到時放棄搜索並進入同源冷卻")
	var starts: int = staff.metrics.counters.search_started
	for i in 240:
		staff.step(DT,high)
		Bus.noise_made.emit(Vector3(-3,3,0.1),1.0,&"climb")
	check(staff.metrics.counters.search_started == starts and staff.metrics.counters.chase_started == 0,"五秒冷卻內同源視覺／噪音不無限重追")
	staff.now += 1.1
	check(not staff.cooling(high),"同源冷卻五秒後解除")
	reset_staff()
	staff.known = high.duplicate(true)
	var memory: Dictionary = staff.known.duplicate(true)
	staff.step(DT,observation(Vector3(12,0,11),false,"Hidden"))
	check(staff.known == memory,"看不見的玩家位置不能更新最後已知記憶")

	reset_staff(Vector3(10,0,6))
	staff.facing = Vector3.LEFT
	ground = observation(Vector3(9.5,0,6),true,"")
	staff.known = ground
	staff.state = &"CHASE"
	staff.awareness = 100
	staff._warning_since = -1
	staff.step(DT,ground)
	check(staff.metrics.counters.arrival == 1 and lab._feedback_left > 0,"追捕到達計數並觸發畫面／短音回饋")
	for i in 100:
		staff.now += DT
		staff._chase(true)
	check(staff.metrics.counters.arrival == 1,"三秒冷卻內反覆接觸不重複計數")
	staff.now += 3
	staff._chase(true)
	check(staff.metrics.counters.arrival == 2,"到達冷卻結束可記錄下一次")
	check(staff.metrics.timeline.size() > 0 and staff.metrics.report(false,true).contains("visibility_mult") and staff.metrics.report(false,true).contains("hearing_spike"),"F3 時間線含視覺倍率與聽覺貢獻")
	var stats := lab.debug_hud.call("movement_report") as String
	check(stats.contains("員工可讀性統計") and stats.contains("移動統計｜來源："),"F3 合併員工與凍結移動統計")
	var clipboard := DisplayServer.clipboard_get() if DisplayServer.get_name() != "headless" else ""
	check(lab.debug_hud.call("copy_movement_stats") == stats,"複製統計輸出合併純文字")
	var detailed := lab.debug_hud.call("copy_detailed_stats") as String
	check(detailed.contains("awareness 時間線") and detailed.contains("完整事件"), "F3明確完整診斷按鈕可另行複製時間線與JSON")
	if DisplayServer.get_name() != "headless": DisplayServer.clipboard_set(clipboard)

	# 可達性依場景平面障礙檢查；斜坡也視為禁止通行，不能爬到高處。
	check(not StaffPerceptionFootprint.walkable_line(Vector3(5.5,0,8),Vector3(5.5,0,-2),staff.obstacles,staff.params.body_radius),"員工地面路徑不能走上斜坡")
	var hop := StaffPerceptionFootprint.next_hop(Vector3(-3,0,2),Vector3(-3,0,-6),staff.navigation_points,staff.obstacles,staff.params.body_radius)
	check(hop.ok and StaffPerceptionFootprint.walkable_line(Vector3(-3,0,2),hop.point,staff.obstacles,staff.params.body_radius),"牆下路徑沿既有地面點網繞行")
	reset_staff(lab.staff_layout.spawn)
	staff.route = lab.staff_layout.route.duplicate()
	staff.sensor = lab._visual_sample
	lab.actor.global_position = Vector3(-3,3.04,-2)
	lab.actor._safe_camera_height = 3.04
	staff.set_physics_process(true)
	var maximum_height := 0.0
	for i in 2400:
		await get_tree().physics_frame
		maximum_height = maxf(maximum_height,absf(staff.global_position.y))
		if staff.metrics.counters.rest_started >= 2: break
	staff.set_physics_process(false)
	check(staff.metrics.counters.rest_started == 2 and maximum_height <= staff.params.ground_height_tolerance, "真實物理巡邏兩圈各歇崗一次，員工全程地面")
	check(staff.metrics.counters.chase_started == 0 and staff.awareness == 0, "屋頂深處玩家不因正式巡邏被隔牆發現")
	await pursuit_climb_check()
	await visual_checks()
	lab.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

func visual_checks() -> void:
	reset_staff()
	staff.sensor = lab._visual_sample
	staff.metrics.source = "非 headless 視覺／感知回歸（非手玩）"
	lab.actor.global_position = Vector3(-3,3.04,0.1)
	lab.actor.state = TraversalActor.State.GROUNDED
	lab.actor._safe_camera_height = 3.04
	staff.awareness = 30
	staff.step(DT)
	check(float(staff.metrics.latest.visibility_mult) > 0, "真實角色屋頂內緣可見")
	await capture("roof")
	lab.actor.global_position = Vector3(-3,0.05,0.9)
	lab.actor.state = TraversalActor.State.GROUNDED
	check(bool(lab._visual_sample().reachable), "地面貼牆玩家仍按地面追捕，不因員工碰撞半徑誤判高處")
	lab.actor.state = TraversalActor.State.CLIMBING
	lab.actor.surface = get_tree().get_first_node_in_group("climb_surfaces") as ClimbSurface
	var low_key: String = lab._visual_sample().key
	lab.actor.global_position = Vector3(-3,1.5,0.9)
	check(not low_key.is_empty() and lab._visual_sample().key == low_key, "同一攀爬面從剛附著到高處維持同源冷卻識別")
	lab.actor._safe_camera_height = 1.5
	staff.step(DT)
	check(str(staff.metrics.latest.visual) == "視覺＋攀爬暴露", "真實攀爬來源記錄在時間線")
	await capture("climb")
	lab.actor.global_position = Vector3(1.5,4,-2)
	lab.actor.state = TraversalActor.State.JUMPING
	staff.global_position = Vector3(1.5,0,1)
	staff.facing = Vector3.FORWARD
	staff.step(DT)
	check(str(staff.metrics.latest.visual) == "視覺" and float(staff.metrics.latest.visibility_mult) > 0, "真實空中跨間隙投影按一般視覺，不誤套攀爬")
	await capture("air")
	lab.actor.global_position = Vector3(-3,3.04,-2)
	lab.actor.state = TraversalActor.State.GROUNDED
	lab.actor._safe_camera_height = 3.04
	staff.global_position = Vector3(-3,0,-5.3)
	staff.facing = Vector3.BACK
	staff.step(DT)
	lab._update_occlusion()
	var building := lab.get_node("Building")
	check((lab._block_materials[building] as StandardMaterial3D).albedo_color.a < 1, "員工在牆後也參與淡出，碰撞未改")
	await capture("occlusion")
	if DisplayServer.get_name() != "headless":
		lab.debug_hud.visible = true
		await capture("f3")
	FileAccess.open("/tmp/staff_readability_stats.txt",FileAccess.WRITE).store_string(staff.metrics.report())
	lab.debug_hud.get_node("Panel/MovementStats/Buttons/ResetStats").emit_signal("pressed")
	check(staff.metrics.events.is_empty() and staff.metrics.timeline.is_empty() and staff.metrics.milestones.is_empty() and staff.metrics.discoveries.is_empty(), "F3 重置同步清除員工統計")

func capture(tag: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.05 if tag == "arrival" else 0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/staff_readability_%s_%d.png" % [tag,size.x])

func release_inputs() -> void:
	for action in ["move_left","move_right","move_forward","move_back","traversal_jump"]: Input.action_release(action)

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

func wait_until(condition: Callable, limit: int) -> bool:
	for i in limit:
		if condition.call(): return true
		await get_tree().physics_frame
	return false

func pursuit_climb_check() -> void:
	reset_staff(Vector3(-3,0,5))
	staff.route.clear()
	staff.sensor = lab._visual_sample
	check(staff.params.ai != lab.staff_params.ai and staff.params.ai.accumulate_per_sec == lab.staff_params.ai.accumulate_per_sec, "真實輸入流程使用原始累積速度，參數實例獨立")
	print("REAL_INPUT_PARAMS accumulate_per_sec=",staff.params.ai.accumulate_per_sec)
	staff.metrics.source = "真實 InputMap 追捕→攀爬→牆下搜索→放棄（非手玩）"
	var actor := lab.actor
	actor.global_position = lab.staff_layout.player_spawn
	actor.state = TraversalActor.State.GROUNDED
	actor.surface = null
	actor.velocity = Vector3.ZERO
	actor._safe_camera_height = actor.global_position.y
	actor.input_enabled = true
	actor.set_physics_process(true)
	staff.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(staff.awareness == 0 and not is_finite(staff._first_seen_at), "真實輸入流程從安全出生點開始，0.02秒不產生視覺接觸")
	await capture("spawn_revision")
	world_input((lab.data.spawn-actor.global_position).normalized())
	check(await wait_until(func() -> bool: return StaffPerceptionFootprint.flat(actor.global_position).distance_to(StaffPerceptionFootprint.flat(lab.data.spawn)) <= 0.15,240), "真實輸入從安全位置自然走入員工視野")
	release_inputs()
	check(await wait_until(func() -> bool: return staff.state == &"CHASE",600),"正常視覺累積觸發追捕，未人工設定警覺度")
	world_input(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return actor.state == TraversalActor.State.CLIMBING,240),"真實輸入：被追捕後自動附牆")
	release_inputs()
	Input.action_press("move_forward")
	check(await wait_until(func() -> bool: return actor.state == TraversalActor.State.GROUNDED and actor.global_position.y > 2.9,240),"真實輸入：追捕中爬上屋頂，不摔落")
	release_inputs()
	check(await wait_until(func() -> bool: return staff.state == &"SEARCH",180),"員工到牆下改為搜索")
	check(await wait_until(func() -> bool: return staff.metrics.counters.search_abandoned > 0,1200),"高處搜索到時放棄，不永遠追逐")
	check(absf(staff.global_position.y) <= staff.params.ground_height_tolerance and actor.global_position.y > 2.9,"完整追捕中員工留地面，玩家留屋頂")
	FileAccess.open("/tmp/staff_readability_chase_loop.txt",FileAccess.WRITE).store_string(staff.metrics.report())
	actor.input_enabled = false
	actor.set_physics_process(false)
	staff.set_physics_process(false)

func handplay_regressions() -> void:
	reset_staff(Vector3(-3,0,2.6))
	var landing := Vector3(-1.103727,0.158888,3.029696)
	var landing_memory := lab._noise_sample(landing)
	check(bool(landing_memory.reachable), "手玩 62.95s：地面落地殘高 0.158888 不誤判為高處")
	staff.begin_search(observation(Vector3(4.556193,0,6.572217),true,""))
	Bus.noise_made.emit(landing,1.0,&"landing")
	check(staff.metrics.counters.search_extended == 0 and staff.state == &"INVESTIGATE", "地面搜索聽見地面落地聲改為調查，不延長為十六秒")
	reset_staff()
	staff.begin_search(observation(Vector3(-3,0,2),true,""))
	Bus.noise_made.emit(Vector3(-3,3,0.1),1.0,&"jump")
	check(staff.metrics.counters.search_extended == 0, "地面搜索不因高處新聲音延長舊計時")
	reset_staff()
	staff.begin_search(observation(Vector3(-3,0,0.1),false))
	Bus.noise_made.emit(Vector3(5,3,-2),1.0,&"jump")
	check(staff.metrics.counters.search_extended == 0, "不同建築的高處聲音不延長舊來源搜索")
	reset_staff()
	staff.begin_search(observation(Vector3(-3,0,0.1),false))
	Bus.noise_made.emit(landing,1.0,&"landing")
	check(staff.metrics.counters.search_extended == 0 and staff.state == &"INVESTIGATE", "高處搜索聽到新地面落地聲可轉調查，但不延長舊搜索")
	reset_staff(Vector3(1.3,0,7.5))
	staff._navigation_warning_until = 0
	staff._go(Vector3(4.556193,0,6.572217))
	check(staff.velocity.length() > 0 and not staff.metrics.events.any(func(e: Dictionary) -> bool: return e.kind == "unreachable"), "手玩斜坡末端目標使用可達接近點，不反覆 unreachable")
	var original := observation(Vector3(4.556193,0,6.572217),true,"")
	staff.known = original.duplicate(true)
	staff.begin_search(original)
	for i in 420: staff.step(DT)
	check(staff.known == original and not staff.metrics.events.any(func(e: Dictionary) -> bool: return e.kind == "unreachable"), "持續搜索七秒仍保留原始感知記憶，合法接近點無 unreachable 循環")
	var approach := StaffPerceptionFootprint.approach_hop(Vector3(1.3,0,7.5),original.projection,staff.navigation_points,staff.obstacles,staff.params.body_radius)
	check(approach.ok and approach.goal != original.projection and StaffPerceptionFootprint.walkable_line(approach.goal,approach.goal+Vector3.UP,staff.obstacles,staff.params.body_radius), "純函式：禁止範圍內的目標改用既有可達路點")
	var all_handplay_targets := true
	for target in [Vector3(-2.639818,0,0.870364),Vector3(-3.806544,0,0.825946),Vector3(4.232174,0,6.894767),Vector3(4.158918,0,5.280692)]:
		var resolved := StaffPerceptionFootprint.approach_hop(lab.staff_layout.spawn,target,staff.navigation_points,staff.obstacles,staff.params.body_radius)
		all_handplay_targets = all_handplay_targets and resolved.ok and StaffPerceptionFootprint.walkable_line(resolved.goal,resolved.goal,staff.obstacles,staff.params.body_radius)
	check(all_handplay_targets, "手玩全部不可達目標皆可由既有點網選出合法接近點")
	var no_nodes: Array[Vector3] = []
	check(not StaffPerceptionFootprint.approach_hop(Vector3(1.3,0,7.5),original.projection,no_nodes,staff.obstacles,staff.params.body_radius).ok, "無合法候選時明確回報不可達，不偽造路徑")
	reset_staff()
	lab.actor.global_position = Vector3(-2.510181,0.022196,0.953885)
	lab.actor.state = TraversalActor.State.CLIMBING
	lab.actor.surface = get_tree().get_first_node_in_group("climb_surfaces") as ClimbSurface
	var climbing := lab._visual_sample()
	check(not climbing.reachable and climbing.approach != climbing.projection and StaffPerceptionFootprint.next_hop(staff.global_position,climbing.approach,staff.navigation_points,staff.obstacles,staff.params.body_radius).ok, "剛附牆的低高度仍選合法牆下點，不追入牆面碰撞半徑")
	lab.actor.surface = null
	lab.actor.state = TraversalActor.State.GROUNDED

func readability_revision_checks() -> void:
	var initial := lab.actor.global_position
	for i in 60: staff.step(DT,lab._visual_sample())
	check(not StaffPerceptionFootprint.contains(staff.polygon,initial) and staff.awareness == 0 and not is_finite(staff._first_seen_at), "新出生點位於初始視錐外，不污染第一次接觸")
	reset_staff()
	for i in 12:
		staff.now = float(i) * 0.47
		Bus.noise_made.emit(Vector3(-3,1,0.9),0.08,&"climb")
	check(staff.metrics.events.filter(func(e: Dictionary) -> bool: return e.kind == "heard").size() <= 4 and staff._noise_contribution < 28, "攀爬噪音接收冷卻1.5秒，微音不反覆全額+28")
	reset_staff()
	var peak := 0.0
	for i in 360:
		staff.step(DT)
		if i % 28 == 0: Bus.noise_made.emit(Vector3(-3,1,0.9),0.08,&"climb")
		peak = maxf(peak,staff.awareness)
	check(peak < staff.params.ai.suspicious_threshold, "六秒連續微弱攀爬聲不會把警覺釘在100")
	reset_staff(Vector3(10,0,6))
	Bus.noise_made.emit(Vector3(11,0,6),1.0,&"landing")
	var near_gain := staff._noise_contribution
	reset_staff(Vector3(10,0,6))
	Bus.noise_made.emit(Vector3(20,0,6),1.0,&"landing")
	check(staff._noise_contribution > 0 and staff._noise_contribution < near_gain, "同音量遠處聲音的警覺增量小於近處")
	reset_staff(Vector3(10,0,6))
	staff.facing = Vector3.LEFT
	staff.awareness = 56.5
	staff.begin_search(observation(Vector3(7,0,6),true,""))
	staff.step(DT,observation(Vector3(8,0,6),true,""))
	check(staff.state == &"INVESTIGATE" and staff._search_memory.projection == Vector3(7,0,6), "搜索看見地面玩家立即轉調查，舊搜索記憶不冒充新視覺")
	check(staff.metrics.counters.chase_started == 0, "重新接觸仍先預警，不直接追捕")
	for i in 29: staff.step(DT,observation(Vector3(8,0,6),true,""))
	check(staff.metrics.counters.chase_started == 0, "重新接觸未滿0.5秒不得追捕")
	for i in 30: staff.step(DT,observation(Vector3(8,0,6),true,""))
	check(staff.metrics.counters.chase_started >= 1, "持續看見地面玩家會正常追捕，不繼續掃視舊點")
	reset_staff(Vector3(10,0,6))
	staff.facing = Vector3.LEFT
	staff.awareness = 100
	staff._pause_until = 1.0
	staff.begin_search(observation(Vector3(7,0,6),true,""))
	for i in 120: staff.step(DT,observation(Vector3(8,0,6),true,""))
	check(not staff.metrics.discoveries.is_empty() and float(staff.metrics.discoveries[0].data.first_seen) <= DT*2 and staff.metrics.discoveries[0].time-float(staff.metrics.discoveries[0].data.first_seen) >= 1.5, "追捕到達停步期間已看見的玩家，摘要保留真正首次視覺時間而非冷卻結束")
	var summary := staff.metrics.report()
	check(not staff.metrics.discoveries.is_empty() and staff.metrics.discoveries[0].data.first_seen != null and staff.metrics.discoveries[0].time-float(staff.metrics.discoveries[0].data.first_seen) >= 0.5, "每次追捕摘要保存真正首次視覺接觸與至少0.5秒預警")
	check(staff.metrics.report(false,true).contains("awareness 時間線"), "時間線只在明確完整匯出時提供")
	var copied := lab.debug_hud.call("movement_report") as String
	check(not copied.contains("awareness 時間線") and not copied.contains("完整診斷日誌"), "預設複製僅摘要，不夾帶移動原型的長輸入日誌")
	var archive := StaffReadabilityMetrics.new(staff.params)
	archive.params = staff.params.duplicate(true)
	archive.params.event_limit = 1
	archive.event(1,"search_started",{"deadline":9.0})
	archive.event(2,"search_extended",{"deadline":17.0})
	archive.event(17,"search_abandoned")
	for i in 5: archive.event(18.0+i,"heard")
	check(archive.report().contains("1.00s 開始") and archive.report().contains("2.00s 延長") and archive.report().contains("17.00s 放棄"), "搜索摘要不被診斷事件環淘汰")
	check(not summary.contains("awareness 時間線") and summary.contains("首次看見"), "預設員工摘要含首次看見至追捕秒數，不含0.1秒時間線")

func rest_player_noise_check() -> void:
	reset_staff(Vector3(-3,0,1.4))
	staff.state = &"REST"
	staff._rest_until = staff.params.rest_sec
	staff.metrics.event(0,"rest_started",{"until":staff._rest_until})
	staff.sensor = lab._visual_sample
	lab.actor.global_position = Vector3(-3,0.04,1.25)
	lab.actor.state = TraversalActor.State.GROUNDED
	lab.actor.surface = null
	lab.actor.velocity = Vector3.ZERO
	lab.actor.input_enabled = true
	lab.actor.set_physics_process(true)
	world_input(Vector3.FORWARD)
	check(await wait_until(func() -> bool: return lab.actor.state == TraversalActor.State.CLIMBING,180), "歇崗回歸：真實玩家輸入自動附牆")
	release_inputs()
	lab.actor.set_physics_process(false)
	staff.step(DT)
	check(staff.awareness == 0 and staff.metrics.latest.reason == "歇崗視覺關閉", "歇崗看得見玩家位置仍關閉視覺，不累積警覺")
	await capture("rest_revision")
	lab.actor.set_physics_process(true)
	Input.action_press("move_forward")
	for i in 180:
		staff.step(DT)
		await get_tree().physics_frame
		if staff.metrics.counters.rest_heard > 0: break
	release_inputs()
	lab.actor.set_physics_process(false)
	lab.actor.input_enabled = false
	check(staff.metrics.counters.rest_heard == 1 and staff.state == &"INVESTIGATE" and staff._last_noise.during_rest, "真實攀爬聲打斷歇崗：視覺關閉而聽覺保留")
	check(staff.metrics.report().contains("聽見 1 次") and staff.metrics.milestones.any(func(e: Dictionary) -> bool: return e.kind == "rest_finished"), "F3歇崗摘要保留聽見次數與中斷時間")
	staff.step(DT) # 消化同幀聲音貢獻，再保存與目前狀態一致的摘要。
	FileAccess.open("/tmp/staff_revision_rest_summary.txt",FileAccess.WRITE).store_string(staff.metrics.report())
	await capture("rest_heard_revision")


func noise_and_stage_pure_checks() -> void:
	var p := StaffReadabilityParams.new()
	check(StaffPerceptionFootprint.hearing_gain(Vector3.ZERO,Vector3.RIGHT,1,false,p) > StaffPerceptionFootprint.hearing_gain(Vector3.ZERO,Vector3.RIGHT*10,1,false,p), "純函式：聽覺增量隨距離單調下降")
	check(StaffPerceptionFootprint.hearing_gain(Vector3.ZERO,Vector3.RIGHT*20,1,false,p) == 0, "純函式：聽距外無警覺增量")
	check(not StaffPerceptionFootprint.noise_ready(1.49,1.5) and StaffPerceptionFootprint.noise_ready(1.5,1.5), "純函式：攀爬冷卻邊界1.5秒")
	check(StaffPerceptionFootprint.reacquire_ground(&"SEARCH",true,true) and not StaffPerceptionFootprint.reacquire_ground(&"SEARCH",true,false), "純函式：只有新的地面視覺中斷搜索，高處同源搜索仍保留")
	check(p.warning_stage_sec == 0.15 and p.investigate_stage_min_sec == 0 and p.chase_stage_min_sec == 0 and p.ai.min_telegraph_sec >= 0.5, "三階段可調下限保留原值，不將觀察時間直接套成新平衡")
