extends Node
## 新控制規格：純判定＋物理＋輸入語意；正式解鎖流程仍不在移動 A。
const DT := 1.0 / 60.0
var passed := 0
var failed := 0
var lab: MovementLab
var actor: TraversalActor
var noises: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ", message)
	else:
		failed += 1
		print("FAIL ", message)

func run() -> void:
	await input_lifecycle_checks()
	pure_checks()
	lab = preload("res://scenes/traversal/movement_lab.tscn").instantiate() as MovementLab
	add_child(lab)
	actor = lab.actor
	lab.metrics.source = "自動回歸／故障注入（非手玩）"
	actor.input_enabled = false
	actor.set_physics_process(false)
	lab._landing_audio.volume_db = -80.0
	Bus.noise_made.connect(on_noise)
	await frames()
	var old_camera := FollowCamera.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	old_camera.add_child(cam)
	add_child(old_camera)
	old_camera.set_follow_target(actor, true)
	check(is_equal_approx(old_camera._target_look_pos().y, old_camera.look_height), "舊鏡頭預設維持地面高度")
	old_camera.queue_free()
	actor.camera.make_current()
	await final_scope_checks()
	await release_scope_checks()
	await intent_lock_checks()
	await usability_checks()
	await attachment_checks()
	await jump_checks()
	await safety_checks()
	await complete_loops()
	if DisplayServer.get_name() != "headless":
		lab.debug_hud.visible = true
		get_tree().root.size = Vector2i(1920,1080)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/borrowed_shapes_usability_f3_1920.png")
		get_tree().root.size = Vector2i(1280,720)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/borrowed_shapes_usability_f3_1280.png")
		var clipboard := DisplayServer.clipboard_get()
		lab.debug_hud.call("copy_movement_stats")
		check(DisplayServer.clipboard_get() == lab.metrics.report(), "非 headless 複製統計與純文字報告一致")
		DisplayServer.clipboard_set(clipboard)
	lab.queue_free()
	await frames()
	check(InputMap.has_action("traversal_jump"), "測試場景退出保留工程跳躍按鍵")
	print("=== P2 TRAVERSAL SUMMARY pass=%d fail=%d ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func pure_checks() -> void:
	var p := TraversalParams.new()
	check(TraversalMath.arc_point(Vector3.ZERO, Vector3.RIGHT, 0, 1) == Vector3.ZERO, "弧線起點")
	check(TraversalMath.arc_point(Vector3.ZERO, Vector3.RIGHT, 1, 1) == Vector3.RIGHT, "弧線終點")
	check(is_equal_approx(TraversalMath.arc_point(Vector3.ZERO, Vector3.RIGHT, 0.5, 1).y, 1), "弧線高度")
	check(TraversalMath.intent_matches(Vector3(1, 0, -1), Vector3.FORWARD, 45), "45 度意圖邊界接受")
	check(not TraversalMath.intent_matches(Vector3(1, 0, -0.9), Vector3.FORWARD, 45), "超過 45 度不附牆")
	check(not TraversalMath.intent_matches(Vector3.ZERO, Vector3.FORWARD, 45), "沒有方向不附牆")
	check(is_equal_approx(TraversalMath.intent_time(0.1, true, 0.05), p.attach_intent_sec), "連續意圖累積到 0.15 秒")
	check(TraversalMath.intent_time(0.1, false, 0.01) == 0, "轉向中斷清空意圖")
	check(TraversalMath.window_valid(0.01) and not TraversalMath.window_valid(0), "容錯窗嚴格過期")
	check(TraversalMath.closest_edge(Vector3(0, 0, 2), Vector3.ZERO, Vector3(0, 0, 3)) == Vector3(0, 0, 2), "線段吸附不是單點")
	check(TraversalMath.closest_edge(Vector3(0, 0, 4), Vector3.ZERO, Vector3(0, 0, 3)) == Vector3(0, 0, 3), "吸附有界")
	check(is_finite(TraversalMath.jump_score(Vector3.ZERO, Vector3.LEFT, Vector3.ZERO, Vector3.RIGHT * 3, p)), "不朝向對岸也可選到單一合法落點")
	check(TraversalMath.jump_score(Vector3.ZERO, Vector3.RIGHT, Vector3.ZERO, Vector3.RIGHT * 3, p) > TraversalMath.jump_score(Vector3.ZERO, Vector3.RIGHT, Vector3.ZERO, Vector3.LEFT * 3, p), "多候選按移動方向排序")
	check(not is_finite(TraversalMath.jump_score(Vector3.ZERO, Vector3.RIGHT, Vector3.ZERO, Vector3.RIGHT * 20, p)), "超遠落點拒絕")
	check(TraversalMath.choose([0.8, 0.9], 0, 0.18) == 0, "候選小幅抖動維持預覽")
	check(TraversalMath.choose([-INF, 0.9], 0, 0.18) == 1, "失效候選立即釋放")
	check(TraversalMath.landing_loudness(p.landing_noise_min_height - 0.01, p) == 0, "落地噪音最低門檻")
	check(TraversalMath.landing_loudness(2, p) > TraversalMath.landing_loudness(1, p), "落地噪音隨高度增加")
	check(TraversalMath.landing_loudness(100, p) == p.landing_noise_max, "落地噪音有上限")
	check(TraversalMath.safe_walk_velocity(Vector3(1, 0, 1), false, false, true) == Vector3(0, 0, 1), "沿邊保留安全分量")
	check(TraversalMath.safe_walk_velocity(Vector3(1, 0, 1), false, false, false) == Vector3.ZERO, "危險雙軸停止")
	var m := TraversalMetrics.new(p)
	m.event(&"attach_start")
	m.advance(2)
	m.event(&"roof")
	m.advance(3)
	m.event(&"gap")
	m.advance(4)
	m.finish_if_returned(false, true)
	check(m.rows.is_empty(), "未回起點不算完成")
	m.finish_if_returned(true, false)
	check(m.rows.is_empty(), "起點上空不算完成")
	m.event(&"return_wall")
	m.finish_if_returned(true, true)
	check(m.rows.size() == 1 and m.rows[0]["total"] == 9.0 and m.rows[0]["climb"] == 2.0 and m.rows[0]["gap"] == 3.0 and m.rows[0]["return"] == 4.0, "分段與總時間正確")
	check(m.rows[0]["route"] == "下牆", "返回方式分開標記")
	m.event(&"recovery")
	check(m.report().contains("BUG"), "恢復大於零明示 BUG")
	m.reset()
	check(m.rows.is_empty() and m.counts() == Vector4i.ZERO and m.phase == TraversalMetrics.Phase.IDLE, "重置清除統計與進行中狀態")
	var samples: Array[Dictionary] = [{"route":"下牆", "climb":2.0, "gap":3.0, "return":4.0}, {"route":"下牆", "climb":5.0, "gap":3.0, "return":4.0}]
	check(TraversalMetrics.slow_segments(samples, 1.5) == PackedStringArray(["climb"]), "偏長路段對照同路線中位數")

	# 總數三次，完成圈一次、進行中一次、圈外一次；不能用同一標頭混算。
	m.reset()
	m.event(&"invalid")
	m.event(&"attach_start")
	m.event(&"invalid")
	m.event(&"roof")
	m.event(&"gap")
	m.finish_if_returned(true, true)
	m.event(&"attach_start")
	m.event(&"invalid")
	m.event(&"recovery")
	check(m.counts().x == 3 and m.completed_counts.x == 1 and m.current_counts().x == 1 and m.outside_counts().x == 1, "完成／進行中／圈外計數互斥且總和守恆")
	check(m.report().contains("整次恢復檢查：BUG"), "進行中恢復不能被完成圈零恢復掩蓋")
	m.reset()
	for i in 10:
		m.event(&"attach_start")
		m.advance(2)
		m.event(&"roof")
		m.advance(1.75 if i == 7 else 1.0)
		m.event(&"gap")
		m.advance(3)
		if i >= 5: m.event(&"return_drop")
		m.finish_if_returned(true, true)
	check(m.report().contains("第 08 圈偏長：gap"), "第八圈偏長不被後續正常圈覆蓋")
	check(m.route_summary("斜坡").contains("5/5") and m.route_summary("跳下").contains("5/5"), "兩種返回分開顯示五圈與中位數")
	check(is_equal_approx(TraversalMetrics.median([1.0, 2.0, 3.0, 10.0]), 2.5), "偶數樣本中位數不受單次長時間扭曲")

	check(TraversalMath.jump_rejection(Vector3.LEFT * 5, Vector3.ZERO, Vector3.RIGHT * 3, p) == "未進入起跳吸附範圍", "拒絕診斷區分過早／離吸附範圍太遠")
	check(TraversalMath.jump_rejection(Vector3.ZERO, Vector3.ZERO, Vector3.RIGHT * 20, p) == "落點過遠", "拒絕診斷區分落點距離限制")

	var historical: Array[Dictionary] = []
	var gap_times := [1.0, 1.17, 1.02, 1.22, 1.13, 1.20, 1.05, 1.75, 1.22, 1.03]
	for i in 10:
		if i == 7: continue
		historical.append({"route": "跳下" if i == 6 else "斜坡", "climb": 2.2, "gap": gap_times[i], "return": 3.5})
	historical.append({"route":"斜坡", "climb":2.03, "gap":1.75, "return":3.57})
	check(TraversalMetrics.slow_segments(historical, p.metrics_segment_slow_ratio).has("gap"), "真實手玩第八圈 1.75s 相對其他斜坡圈中位數 1.15s 被標記")

	check(TraversalMath.direction_score(Vector3.BACK, Vector3(0, -3, 1)) > TraversalMath.direction_score(Vector3.BACK, Vector3.LEFT), "純方向評分忽略高度，朝外下行優於側面跨越")
	check(TraversalMetrics.return_route(1, PackedStringArray(["下牆"])) == "下牆", "一次返跳再下牆仍屬正常返回")
	check(TraversalMetrics.return_route(2, PackedStringArray(["跳下"])) == "混合", "來回跨越再跳下不污染單一路線統計")
	m.reset()
	m.event(&"attach_start")
	m.event(&"roof")
	m.event(&"gap")
	m.event(&"gap")
	m.event(&"gap")
	m.event(&"return_drop")
	m.finish_if_returned(true, true)
	check(m.rows[0]["route"] == "混合" and m.rows[0]["return_crossings"] == 2, "混合狀態不被最後跳下覆蓋，保留返跳次數")
	check(m.route_summary("跳下").contains("0 圈") and m.route_summary("混合").contains("不計入"), "混合路線排除跳下樣本與驗收")

	check(TraversalMath.wants_cross(0.707,0.707,0.15,0.45,p), "斜向移動但間隙邊緣較近，意圖為跨越")
	check(not TraversalMath.wants_cross(0.707,0.707,0.15,0.15,p), "前角同時接近兩邊，朝外意圖為下行")
	check(TraversalMath.wants_cross(1,0,0.15,0.15,p), "前角明確朝間隙仍為跨越")
	m.reset()
	m.event(&"attach_start")
	m.event(&"roof")
	m.event(&"return_drop")
	m.event(&"roof")
	m.event(&"gap")
	m.event(&"return_drop")
	m.finish_if_returned(true,true)
	check(m.rows[0]["route"] == "重試" and m.route_summary("跳下").contains("0 圈"), "首次跨越前跳下再爬回，標重試而非普通跳下圈")

	check(TraversalMath.wants_cross(0.707,0.707,INF,INF,p), "未找到邊界時不憑同向地面分數強制下行")

	check(TraversalMath.cross_context_valid(Vector3(0,0.18,0),Vector3.ZERO,p), "入口高度容差邊界接受")
	check(not TraversalMath.cross_context_valid(Vector3(0,0.19,0),Vector3.ZERO,p), "不同高度不參與跨越意圖")
	check(not TraversalMath.cross_context_valid(Vector3.RIGHT * (p.takeoff_range + p.cross_context_extra_range + 0.01),Vector3.ZERO,p), "遠處同高度跳點不參與跨越意圖")

	check(TraversalMetrics.return_route(0, PackedStringArray(["跳下"]), false, 2) == "重複返回", "相同下行做兩次歸類重複返回")
	m.reset()
	m.event(&"attach_start")
	m.advance(2)
	m.event(&"roof")
	m.advance(1)
	m.event(&"gap")
	m.event(&"return_drop")
	m.advance(3)
	m.event(&"return_drop")
	m.advance(20)
	m.finish_if_returned(true, true)
	check(m.rows[0]["route"] == "重複返回" and m.rows[0]["return_actions"] == 2, "多次跳下實際事件不污染單次耗時")
	check(m.route_summary("跳下").contains("0 圈") and m.report().contains("尚需 5 個有效單次圈"), "重複返回排除單次中位數與五圈驗收，總數仍保留")

func on_noise(position: Vector3, loudness: float, kind: StringName) -> void:
	noises.append({"position":position, "loudness":loudness, "kind":kind})

func frames() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func stand(point: Vector3) -> void:
	actor.global_position = point
	actor.velocity = Vector3.ZERO
	actor.state = TraversalActor.State.GROUNDED
	actor.surface = null
	actor._buffer_pending = false
	actor._release_pending = false
	actor._jump_request.clear()
	actor._buffer_kind = &""
	actor._preview_direction = Vector3.ZERO
	actor._coyote_left = 0
	actor._coyote_link = null
	actor._reattach_left = 0
	actor._needs_fresh_input = false
	actor._released_input_seen = false
	actor._intent_left = 0
	actor._intent_surface = null
	actor._blocked_time = 0
	actor._air_time = 0
	actor._intentional_fall = false
	actor._path_tag = &""
	actor._peak_height = point.y
	actor.selected_link = null
	actor.has_jump_preview = false

func step_world(direction: Vector3, delta: float = DT, space: bool = false) -> void:
	var right := actor.camera.global_basis.x
	right.y = 0
	var back := actor.camera.global_basis.z
	back.y = 0
	actor.step(delta, Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())), space)

func idle(frames_count: int = 60) -> void:
	for i in frames_count:
		actor.step(DT, Vector2.ZERO)

func walk(target: Vector3, max_steps: int = 300) -> void:
	for i in max_steps:
		var offset := target - actor.global_position
		offset.y = 0
		if offset.length() < 0.08 or actor.state not in [TraversalActor.State.GROUNDED, TraversalActor.State.AIRBORNE]:
			break
		step_world(offset.normalized())

func attach_from_ground() -> bool:
	for i in 40:
		step_world(Vector3.FORWARD)
		if actor.state == TraversalActor.State.CLIMBING:
			return true
	return false

func climb_up() -> bool:
	for i in 180:
		actor.step(DT, Vector2.UP if actor.state == TraversalActor.State.CLIMBING else Vector2.ZERO)
		if actor.state == TraversalActor.State.GROUNDED and actor.global_position.y > 2.9:
			return true
	return false

func final_scope_checks() -> void:
	stand(lab.data.spawn)
	var contacts: Array[Dictionary] = []
	var observe := func(record: Dictionary) -> void:
		if record["kind"] == "contact_separated": contacts.append(record)
	actor.diagnostic_recorded.connect(observe)
	var heights: Array[float] = []
	for i in 240:
		await get_tree().physics_frame
		actor.step(DT, Vector2.ZERO)
		if i >= 60: heights.append(actor.global_position.y)
	actor.diagnostic_recorded.disconnect(observe)
	print("IDLE_CONTACT_REGRESSION frames=240 separations=", contacts.size(), " end=", actor.global_position)
	check(contacts.is_empty(), "出生點靜止四秒無向上分離校正循環")
	print("IDLE_SETTLED_HEIGHT range=", heights.min(), "..", heights.max())
	check(float(heights.max()) - float(heights.min()) < 0.0001 and not actor.deeply_embedded(actor.global_position), "靜止接地穩定且無深陷，不靠恢復隱藏循環")
	# 故障注入舊幾何：證明原失敗是第一段擦到斜坡，沒有放寬預檢。
	var old_ramp := lab.make_block({"name":"HistoricalRampRegression", "position":Vector3(5,1.525,3.45), "size":Vector3(3,3.05,6.1), "shape":"ramp"})
	await frames()
	stand(Vector3(3.518902,3.000835,0.204064))
	var blocked := actor._drop_candidate(Vector3(-1,0,1).normalized())
	var obstruction: Dictionary = blocked.get("obstruction", {})
	print("HISTORICAL_JUNCTION_BLOCK ", JSON.stringify(obstruction))
	check((blocked["points"] as PackedVector3Array).is_empty() and obstruction.get("segment",0) == 1 and str(obstruction.get("collider", "")).ends_with("HistoricalRampRegression"), "舊幾何阻擋回歸記錄實際碰撞體與第一段路徑")
	old_ramp.queue_free()
	await frames()
	var points: Array[Vector3] = [Vector3(3.778283,3.044020,0.460391), Vector3(3.518902,3.000835,0.204064), Vector3(3.520364,3.000835,0.216667)]
	for point in points:
		stand(point)
		var candidate := actor._drop_candidate(Vector3(-1,0,1).normalized())
		print("JUNCTION_REGRESSION ",point," ",candidate)
		check(not (candidate["points"] as PackedVector3Array).is_empty(), "手玩交界座標可朝外下行：" + str(point))
		var old_counts := lab.metrics.counts()
		actor._move_dir = Vector3(-1,0,1).normalized()
		var jumped := actor.try_jump()
		idle(45)
		check(jumped and actor.state == TraversalActor.State.GROUNDED and actor.global_position.y < 0.1 and lab.metrics.counts() == old_counts, "交界實際下行無中斷／恢復：" + str(point))
	stand(Vector3(3.518902,3.000835,0.204064))
	check(not (actor._drop_candidate(Vector3.BACK)["points"] as PackedVector3Array).is_empty(), "舊斜坡側緣支撐不足座標改為完整地面落點")

func release_scope_checks() -> void:
	stand(Vector3(-3,0.04,0.94))
	attach_from_ground()
	actor.step(DT,Vector2.ZERO,true)
	for i in 60: step_world(Vector3.FORWARD)
	check(actor.state == TraversalActor.State.CLIMBING, "牆底 Space 放手後持續朝牆，落地冷卻後可再附著")
	stand(Vector3(-2.929289,-0.000684,0.820943))
	actor._move_dir = Vector3.FORWARD
	actor._intent_surface = get_tree().get_first_node_in_group("climb_surfaces") as ClimbSurface
	actor._intent_left = actor.params.attach_intent_sec
	actor._auto_attach(DT)
	print("SHALLOW_ATTACH_CONTEXT ", actor.global_position," ",actor.state," ",actor._intent_left," ",actor.supported(actor.global_position)," ",actor.deeply_embedded(actor.global_position)," ", actor._intent_roof)
	check(actor.state == TraversalActor.State.ATTACHING, "原生第三次重附的微量腳底交疊不阻斷附牆")
	stand(Vector3(-3,1,-2))
	var unchanged := actor.global_position
	check(not actor._separate_ground_contact() and actor.global_position == unchanged, "深陷不走微量接觸分離，不掩蓋恢復 BUG")
	var ceiling := lab.make_block({"position":Vector3(-3,1.055,2),"size":Vector3(2,0.1,2)})
	await frames()
	stand(Vector3(-3,-0.000684,2))
	unchanged = actor.global_position
	check(not actor._separate_ground_contact() and actor.global_position == unchanged, "微量接觸分離受頭頂碰撞限制，不穿過天花板")
	ceiling.queue_free()
	await frames()
	var ramp_positions: Array[Vector3] = [Vector3(3.927703,2.66501,1.246915), Vector3(3.927703,2.2464,2.084538), Vector3(3.907894,2.413728,1.745954), Vector3(3.907894,2.323924,1.927716), Vector3(3.907894,2.201716,2.173738), Vector3(3.907894,2.646426,1.284366), Vector3(3.907894,1.667501,3.240531)]
	# 斜坡已向右縮窄；舊座標平移至同一相對側緣，舊屋頂交界另有精確回歸。
	var local_intent := true
	for old_point in ramp_positions:
		var point := old_point + Vector3.RIGHT
		stand(point)
		local_intent = local_intent and actor._edge_intent(Vector3.LEFT) == &"drop"
	check(local_intent, "調整後斜坡七個相對位置不受不同高度屋頂跨越點干擾")
	stand(Vector3(4.907894,1.667501,3.240531))
	step_world(Vector3(-1,0,1).normalized())
	var extras := lab.metrics.extra_inputs
	step_world(Vector3(-1,0,1).normalized(),DT,true)
	print("RAMP_RELEASE_CONTEXT ", actor.state, " ", actor.global_position, " ", actor.jump_refusal, " ", JSON.stringify(actor._selection_diagnostics))
	idle(45)
	check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y < 0.1 and lab.metrics.extra_inputs == extras, "斜坡朝外 Space 可下行，不被誤鎖成跨越")

func intent_lock_checks() -> void:
	stand(Vector3(-0.392138,3.04,-3.719604))
	step_world(Vector3(1,0,-1).normalized())
	check(actor.has_jump_preview and not actor.preview_is_drop, "重現尾端斜向返跳：間隙近於外緣，不選地面")
	stand(Vector3(3.390728,3.04,0.120393))
	step_world(Vector3(-1,0,1).normalized())
	var expected := actor.selected_destination
	step_world(Vector3.LEFT, DT, true)
	check(actor.state == TraversalActor.State.JUMPING and actor._path_tag == &"drop" and actor.locked_landing().is_equal_approx(expected), "Space 同幀轉向不把已顯示下行換成返跳")
	idle(45)
	stand(Vector3(3.65,3.04,-2))
	step_world(Vector3.LEFT)
	expected = actor.selected_destination
	step_world(Vector3(-1,0,1).normalized(), DT, true)
	check(actor._path_tag == &"gap" and actor.locked_landing().is_equal_approx(expected), "返跳預覽按下後鎖定屋頂落點，不偷換地面")
	idle(45)

	# 已顯示的跨越被新障礙擋住：即使地面可下行，也只能拒絕。
	stand(Vector3(3.65,3.04,-2))
	step_world(Vector3.LEFT)
	var extras := lab.metrics.extra_inputs
	var block := lab.make_block({"position":Vector3(1.5,4,-2), "size":Vector3(0.15,4,2)})
	await frames()
	step_world(Vector3.LEFT, DT, true)
	idle(15)
	check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y > 2.9 and lab.metrics.extra_inputs == extras + 1, "鎖定跨越受阻只拒絕，不改成跳下")
	block.queue_free()
	await frames()
	stand(Vector3(3.390728,3.04,0.120393))
	step_world(Vector3(-1,0,1).normalized())
	block = lab.make_block({"position":Vector3(2.54,1.5,0.97), "size":Vector3(0.25,3,0.25)})
	await frames()
	extras = lab.metrics.extra_inputs
	step_world(Vector3.LEFT, DT, true)
	idle(15)
	check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y > 2.9 and lab.metrics.extra_inputs == extras + 1, "鎖定下行受阻只拒絕，不改成返跳")
	block.queue_free()
	await frames()
	# 正常連續操作從爬牆進入；預覽與執行落點一致。
	lab.metrics.reset()
	stand(lab.data.spawn)
	walk(Vector3(-3,0.04,0.94))
	attach_from_ground()
	climb_up()
	walk(Vector3(-0.7,3.04,-2))
	step_world(Vector3.RIGHT, DT, true)
	idle(40)
	var reached_opposite := actor.global_position.x > 3.2
	walk(Vector3(3.390728,3.04,0.12))
	step_world(Vector3(-1,0,1).normalized())
	expected = actor.selected_destination
	step_world(Vector3(-1,0,1).normalized(), DT, true)
	idle(45)
	check(reached_opposite and actor.global_position.distance_to(expected) < actor.params.landing_lift * 2, "爬牆跨到對岸後跳下：確實到達預覽地面")
	walk(lab.data.spawn)
	check(lab.metrics.completed_count == 1 and lab.metrics.rows[0]["route"] == "跳下" and lab.metrics.counts() == Vector4i.ZERO, "完整跨越後下行一圈零錯誤，不返跳到另一屋頂")

	stand(Vector3(-0.65,3.04,-2))
	step_world(Vector3.ZERO)
	step_world(Vector3.RIGHT, DT, true)
	while actor.state == TraversalActor.State.JUMPING and actor._duration - actor._elapsed > DT * 2:
		idle(1)
	extras = lab.metrics.extra_inputs
	step_world(Vector3(-1,0,1).normalized(), DT, true)
	idle(45)
	check(actor.global_position.x < 0 and lab.metrics.extra_inputs == extras, "斜向落地前緩衝以即將到達的平台辨識返跳，不誤認地面下行")

func usability_checks() -> void:
	stand(Vector3(-3, 0.04, 0.94))
	for i in 40:
		step_world(Vector3.FORWARD)
		if actor.state == TraversalActor.State.ATTACHING: break
	var extras := lab.metrics.extra_inputs
	actor.step(DT, Vector2.ZERO, true)
	idle(30)
	check(actor.state != TraversalActor.State.CLIMBING and lab.metrics.extra_inputs == extras, "附牆過渡的 Space 銜接放手，不吃鍵或記無效")
	var transition_sec := actor.params.attach_transition_sec
	actor.params.attach_transition_sec = 0.4
	stand(Vector3(-3, 0.04, 0.94))
	for i in 40:
		step_world(Vector3.FORWARD)
		if actor.state == TraversalActor.State.ATTACHING: break
	actor.step(DT, Vector2.ZERO, true)
	idle(40)
	check(actor.state != TraversalActor.State.CLIMBING and lab.metrics.extra_inputs == extras, "長附牆過渡放手請求不受跳躍緩衝到期影響")
	actor.params.attach_transition_sec = transition_sec
	stand(Vector3(3.390726, 3.04, 0.113879))
	step_world(Vector3(-1, 0, 1).normalized())
	check(actor.has_jump_preview and actor.preview_is_drop, "重現屋頂前角：朝外下行不被返跳點搶走")
	var recoveries := lab.metrics.recoveries
	step_world(Vector3(-1, 0, 1).normalized(), DT, true)
	idle(45)
	check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y < 0.1 and lab.metrics.recoveries == recoveries, "前角朝外一次 Space 合法下行，沒有返跳或恢復")
	stand(Vector3(6.494857, 3.002949, 0.233101))
	step_world(Vector3(1, 0, 1).normalized())
	actor.refresh_selection(actor._move_dir)
	check(actor.has_jump_preview or not actor.jump_refusal.begins_with("靠近有效"), "斜坡角落合法則預覽，受阻則有具體原因")
	print("CORNER_DIAGNOSTIC ", actor.jump_refusal, " ", JSON.stringify(actor._selection_diagnostics))
	check(actor._selection_diagnostics[-1]["kind"] == "drop" and (actor.has_jump_preview or not str(actor._selection_diagnostics[-1]["reason"]).is_empty()), "拒絕記錄包含下行候選，非只有遠處跨越點")
	if actor.has_jump_preview:
		actor.try_jump()
		idle(45)
		check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y < 0.1 and lab.metrics.recoveries == recoveries, "斜坡角落微接觸解除後，合法下行能實際落地")
	stand(Vector3(6.494857,3.002949,0.233101))
	walk(Vector3(6.62,3.04,-0.48))
	step_world(Vector3(1,0,-1).normalized(), DT, true)
	idle(45)
	check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y < 0.1 and lab.metrics.recoveries == recoveries, "受阻角落可沿邊橫移後合法跳下，不需恢復或繞斜坡")
	stand(Vector3(3.390726, 3.04, 0.113879))
	step_world(Vector3.LEFT)
	check(actor.has_jump_preview and not actor.preview_is_drop, "同一前角改朝間隙，仍選返跳而非一律下行")
	stand(Vector3(-3,3.04,-3.8))
	step_world(Vector3.FORWARD)
	check(not actor.edge_blocked and actor.preview_is_drop, "尚未貼住保護邊界即有下行預覽")

func attachment_checks() -> void:
	stand(Vector3(-3, 0.04, 0.94))
	idle(20)
	check(actor.state == TraversalActor.State.GROUNDED, "站在牆邊不會被吸走")
	for i in 5:
		step_world(Vector3.FORWARD)
	check(actor.state == TraversalActor.State.GROUNDED, "不足 0.15 秒不附牆")
	step_world(Vector3.RIGHT)
	check(actor._intent_left == 0, "路過或轉向中斷附牆")
	check(attach_from_ground(), "持續朝牆自動附著，不需 E")
	var hung := actor.global_position
	idle(30)
	check(actor.state == TraversalActor.State.CLIMBING and actor.global_position == hung, "放開方向仍掛牆")
	for i in 30:
		actor.step(DT, Vector2.UP)
	var screen_before := actor.camera.unproject_position(actor.global_position)
	for i in 10:
		actor.step(DT, Vector2.RIGHT)
	check(actor.camera.unproject_position(actor.global_position).x > screen_before.x, "沿牆向螢幕右側移動")
	check(climb_up(), "頂緣自動翻上屋頂")
	check(actor.supported(actor.global_position), "翻上後有站立支撐")
	walk(Vector3(-3, 3.04, -0.65))
	for i in 45:
		step_world(Vector3.BACK)
		if actor.state == TraversalActor.State.CLIMBING: break
	check(actor.state == TraversalActor.State.CLIMBING and actor.global_position.y > 2.4, "屋頂朝外持續走自動掛牆下降入口")
	for i in 150:
		actor.step(DT, Vector2.DOWN if actor.state == TraversalActor.State.CLIMBING else Vector2.ZERO)
	check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y < 0.1, "底緣自動落地，不需 E")
	stand(Vector3(-3, 0.04, 0.94))
	attach_from_ground()
	for i in 35: actor.step(DT, Vector2.UP)
	actor.step(DT, Vector2.ZERO, true)
	check(actor.state == TraversalActor.State.AIRBORNE and actor._coyote_left == 0, "Space 放手且不提供土狼時間")
	var no_air_attach := true
	for i in 180:
		if actor.state != TraversalActor.State.AIRBORNE: break
		step_world(Vector3.FORWARD)
		no_air_attach = no_air_attach and actor.state not in [TraversalActor.State.ATTACHING, TraversalActor.State.CLIMBING]
	check(no_air_attach, "放手持續朝牆，在空中仍不重附")
	check(attach_from_ground(), "落地後持續朝牆可再附著，不必鬆開方向")
	var before_e := actor.global_position
	actor.input_enabled = true
	Input.action_press("interact")
	actor._physics_process(DT)
	Input.action_release("interact")
	actor.input_enabled = false
	check(actor.state == TraversalActor.State.CLIMBING and actor.global_position == before_e, "E 不附牆也不落地")
	actor.step(DT, Vector2.ZERO, true)
	idle(10)
	check(actor._reattach_left > 0 and actor.state != TraversalActor.State.CLIMBING, "放手後 0.3 秒內禁止重附")
	idle(1)
	for i in 5: step_world(Vector3.FORWARD)
	check(actor.state != TraversalActor.State.CLIMBING, "重新輸入也不能繞過 0.3 秒冷卻")

func jump_checks() -> void:
	for z in [-3.2, -2.0, -0.8]:
		stand(Vector3(-1.5, 3.04, z))
		step_world(Vector3.ZERO)
		check(actor.has_jump_preview, "偏離舊黃點仍自動預覽 z=%.1f" % z)
		actor.facing = Vector3.LEFT
		check(actor.try_jump(), "無須刻意轉向即可 Space 跳躍")
		idle(45)
		check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.x > 3.2, "邊緣吸附與跳躍著陸")
	# 按鍵緩衝：在第一跳落地前兩幀按 Space，自動接續合法返跳。
	stand(Vector3(-0.65, 3.04, -2))
	step_world(Vector3.ZERO)
	var extra := lab.metrics.extra_inputs
	actor.step(DT, Vector2.ZERO, true)
	while actor.state == TraversalActor.State.JUMPING and actor._duration - actor._elapsed > DT * 2:
		actor.step(DT, Vector2.ZERO)
	actor.step(DT, Vector2.ZERO, true)
	idle(40)
	check(actor.global_position.x < 0 and lab.metrics.extra_inputs == extra, "落地前緩衝成功生效且不算多餘輸入")
	stand(Vector3(-0.65, 3.04, -2))
	step_world(Vector3.ZERO)
	actor.step(DT, Vector2.ZERO, true)
	actor.step(DT, Vector2.ZERO, true)
	idle(50)
	check(lab.metrics.extra_inputs == extra + 1, "過早按鍵緩衝到期只記一次")
	# 土狼：保留最近合法邊緣資訊，但不沿用舊路徑的碰撞結果。
	stand(Vector3(-0.65, 3.04, -2))
	step_world(Vector3.ZERO)
	actor._coyote_link = actor.selected_link
	actor._coyote_left = actor.params.coyote_sec
	actor.state = TraversalActor.State.AIRBORNE
	actor.global_position = Vector3(0.4, 2.98, -2)
	check(actor.try_jump(), "失去支撐後容錯窗內仍可跳躍")
	idle(40)
	stand(Vector3(-0.65, 3.04, -2))
	step_world(Vector3.ZERO)
	actor._coyote_link = actor.selected_link
	actor.state = TraversalActor.State.AIRBORNE
	actor._coyote_left = 0.0
	check(not actor.try_jump(), "土狼窗過期不能跳")
	stand(Vector3(-0.65,3.04,-2))
	step_world(Vector3.ZERO)
	var cached := actor.selected_link
	var coyote_block := lab.make_block({"position":Vector3(1.5,4,-2), "size":Vector3(0.15,4,2)})
	await frames()
	actor.state = TraversalActor.State.AIRBORNE
	actor._coyote_left = actor.params.coyote_sec
	actor._coyote_link = cached
	check(not actor.try_jump(), "土狼起跳重驗碰撞，不沿用已失效預覽")
	coyote_block.queue_free()
	await frames()
	# 其他屋頂邊緣保護保留；朝外按 Space 可主動落至下面的地面。
	stand(Vector3(-3, 3.04, -3.8))
	for i in 40: step_world(Vector3.FORWARD)
	check(actor.edge_blocked and actor.preview_is_drop and actor.global_position.y > 2.9, "無攀爬面的邊緣停住並提供低處落點")
	step_world(Vector3.FORWARD, DT, true)
	idle(45)
	check(actor.state == TraversalActor.State.GROUNDED and actor.global_position.y < 0.1, "Space 主動跳下地面")
	var landing_events := 0
	for event in noises:
		if event["kind"] == &"landing": landing_events += 1
	check(landing_events > 0, "高處落地發出既有噪音事件")
	noises.clear()
	stand(Vector3(-0.65, 3.04, -2))
	step_world(Vector3.ZERO)
	actor.try_jump()
	idle(45)
	var quiet := true
	for event in noises:
		quiet = quiet and event["kind"] != &"landing"
	check(quiet, "小幅同層跳躍不發落地噪音")

func safety_checks() -> void:
	stand(Vector3(-0.65, 3.04, -2))
	actor.remember_safe_position()
	var block := lab.make_block({"position":Vector3(1.5, 4, -2), "size":Vector3(0.15, 4, 2)})
	await frames()
	actor.refresh_selection(Vector3.ZERO)
	check(not actor.has_jump_preview, "薄牆阻擋完整弧線，不顯示假落點")
	block.queue_free()
	await frames()
	block = lab.make_block({"position":Vector3(-0.65, 4.25, -2), "size":Vector3(1, 0.2, 1)})
	await frames()
	check(not actor.path_clear(actor.global_position, Vector3(3.65,3.04,-2), actor.params.jump_arc), "頭頂受阻拒絕跳躍")
	block.queue_free()
	await frames()
	check(not actor.supported(Vector3(3.02,3.04,-2)), "平台窄邊不足支撐拒絕")
	stand(Vector3(-0.65, 3.04, -2))
	step_world(Vector3.ZERO)
	actor.try_jump()
	block = lab.make_block({"position":Vector3(1.5, 4, -2), "size":Vector3(0.15, 4, 2)})
	await frames()
	var recoveries := lab.metrics.recoveries
	idle(50)
	check(actor.state == TraversalActor.State.GROUNDED and actor.supported(actor.global_position) and lab.metrics.recoveries == recoveries + 1, "動態路徑故障返回合法安全位置，恢復明確計數")
	block.queue_free()
	await frames()
	stand(Vector3(-3,3.04,-2))
	actor.remember_safe_position()
	actor.global_position = Vector3(-3,1,-2)
	idle(110)
	check(actor.global_position.y > 2.9 and actor.supported(actor.global_position), "注入卡牆可自動恢復")
	check(not lab.metrics.recovery_records.is_empty(), "卡住觸發保留診斷快照")
	var diagnostic: Dictionary = lab.metrics.recovery_records[-1]
	check(diagnostic.has("position") and diagnostic.has("inputs") and diagnostic.has("landing") and diagnostic.has("safe_candidates") and diagnostic.has("path_tag"), "恢復前記錄位置、輸入、落點、歷史安全點與路徑")
	check(not diagnostic["inputs"].is_empty() and float(diagnostic["inputs"][-1]["time"]) - float(diagnostic["inputs"][0]["time"]) <= actor.params.diagnostic_input_sec, "輸入回看有界且保留最近一秒")
	# 重現舊偵測誤判：膠囊只陷入地面 5mm，角色每幀仍有 5cm 位移。
	stand(Vector3(-3, -0.005, 5))
	var old_overlap := not actor.get_world_3d().direct_space_state.intersect_shape(actor.query_at(actor.global_position), 1).is_empty()
	check(old_overlap and not actor.deeply_embedded(actor.global_position), "重現表面微接觸：舊偵測當嵌入，新偵測排除")
	recoveries = lab.metrics.recoveries
	for i in 110:
		actor.global_position.x += 0.005
		actor._watch_stuck(DT, actor.global_position - Vector3.RIGHT * 0.005)
	check(lab.metrics.recoveries == recoveries and actor._blocked_time == 0, "持續移動的淺接觸超過卡住門檻不誤傳送")
	var tolerance := actor.params.stuck_penetration_tolerance
	actor.params.stuck_penetration_tolerance = 0
	stand(Vector3(-3, -0.005, 5))
	for i in 110:
		actor.global_position.x += 0.005
		actor._watch_stuck(DT, actor.global_position - Vector3.RIGHT * 0.005)
	check(lab.metrics.recoveries == recoveries + 1, "對照舊零容差判定：相同淺接觸持續位移仍會誤恢復")
	actor.params.stuck_penetration_tolerance = tolerance
	check(actor.deeply_embedded(Vector3(-3,1,-2)), "真正深陷牆內仍被偵測，未隱藏恢復 bug")
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		stand(Vector3(-3,3.04,-2))
		for i in 100: step_world(direction)
		check(actor.global_position.y > 2.9 or actor.state in [TraversalActor.State.ATTACHING, TraversalActor.State.CLIMBING], "一般步行不跌落屋頂")
	stand(Vector3(-3,3.04,-3.8))
	for i in 45: step_world(Vector3.FORWARD)
	recoveries = lab.metrics.recoveries
	idle(150)
	check(lab.metrics.recoveries == recoveries, "安全邊緣等候不誤算卡住")
	var ramp_data: Dictionary = {}
	for entry in lab.data.blocks:
		if entry.get("shape", "") == "ramp": ramp_data = entry
	var center: Vector3 = ramp_data["position"]
	var size: Vector3 = ramp_data["size"]
	var inset := maxf(actor.params.radius + actor.params.edge_safety_margin, size.x * 0.25)
	for x in [center.x - size.x * 0.5 + inset, center.x, center.x + size.x * 0.5 - inset]:
		stand(Vector3(x,0.04,6.8))
		walk(Vector3(x,3.04,-1))
		var up := actor.global_position.y > 2.9
		walk(Vector3(x,0.04,6.8))
		check(up and actor.global_position.y < 0.1, "斜坡目前左／中／右步行帶上下通行 x=%.2f" % x)
	var original := actor.capabilities.duplicate()
	actor.capabilities.clear()
	stand(Vector3(-0.65,3.04,-2))
	actor.refresh_selection(Vector3.ZERO)
	check(not actor.has_jump_preview, "無才能不跳躍")
	actor.capabilities = original

func complete_loops() -> void:
	lab.metrics.reset()
	lab.metrics.source = "自動路徑回歸（非手玩）"
	var good := true
	for round_index in 10:
		if round_index == 0: stand(lab.data.spawn)
		walk(Vector3(-3,0.04,0.94))
		if actor.state == TraversalActor.State.GROUNDED: attach_from_ground()
		good = climb_up() and good
		walk(Vector3(-0.7,3.04,-2))
		step_world(Vector3.RIGHT, DT, true)
		idle(45)
		walk(Vector3(5,3.04,-1))
		walk(Vector3(5,0.04,6.8))
		walk(Vector3(-3,0.04,2), 600)
		good = good and lab.metrics.completed_count == round_index + 1
	check(good and lab.metrics.rows.size() == 10, "十圈爬牆／跨間隙／斜坡返回完整記錄")
	check(lab.metrics.counts() == Vector4i.ZERO, "正常十圈無多餘輸入、意外墜落、中斷或卡住恢復")
	if DisplayServer.get_name() == "headless":
		check(lab.debug_hud.call("copy_movement_stats") == lab.metrics.report(), "F3 複製輸出純文字統計")
	FileAccess.open("/tmp/borrowed_shapes_traversal_metrics_ramp.txt", FileAccess.WRITE).store_string(lab.metrics.report())
	lab.metrics.reset()
	good = true
	stand(lab.data.spawn)
	for round_index in 10:
		walk(Vector3(-3,0.04,0.94))
		if actor.state == TraversalActor.State.GROUNDED: attach_from_ground()
		good = climb_up() and good
		walk(Vector3(-0.7,3.04,-2))
		step_world(Vector3.RIGHT, DT, true)
		idle(40)
		step_world(Vector3.LEFT, DT, true)
		idle(40)
		walk(Vector3(-3,3.04,-0.65))
		for i in 45:
			step_world(Vector3.BACK)
			if actor.state == TraversalActor.State.CLIMBING: break
		for i in 150:
			actor.step(DT, Vector2.DOWN if actor.state == TraversalActor.State.CLIMBING else Vector2.ZERO)
		walk(lab.data.spawn)
		good = good and lab.metrics.completed_count == round_index + 1
	check(good and lab.metrics.rows.size() == 10, "十圈跨間隙後原路返跳／下牆完整流程")
	check(lab.metrics.counts() == Vector4i.ZERO, "主要下牆返回十圈沒有無效輸入與失誤／恢復")
	check(lab.metrics.rows[0]["route"] == "下牆" and lab.metrics.rows[-1]["route"] == "下牆", "F3 主要返回路線一致")
	check(lab.metrics.report().contains("同路線末圈比首圈快：否"), "相同自動操作的浮點誤差不誤判為手感進步")
	FileAccess.open("/tmp/borrowed_shapes_traversal_metrics.txt", FileAccess.WRITE).store_string(lab.metrics.report())
	print(lab.metrics.report())

func input_lifecycle_checks() -> void:
	var action: StringName = &"traversal_jump"
	var existed := InputMap.has_action(action)
	var original_deadzone := InputMap.action_get_deadzone(action) if existed else 0.5
	var original_events: Array[InputEvent] = InputMap.action_get_events(action) if existed else []
	# 用自訂鍵位與 deadzone 證明場景不會覆寫工程設定。
	if existed:
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.37)
	var custom_key := InputEventKey.new()
	custom_key.physical_keycode = KEY_F8
	InputMap.action_add_event(action, custom_key)
	var existing_lab := preload("res://scenes/traversal/movement_lab.tscn").instantiate() as MovementLab
	add_child(existing_lab)
	check(is_equal_approx(InputMap.action_get_deadzone(action), 0.37) and InputMap.action_get_events(action).size() == 1 and InputMap.action_get_events(action)[0] == custom_key, "traversal_jump：載入保留既有鍵位與 deadzone")
	existing_lab.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(InputMap.has_action(action), "traversal_jump：退出保留既有 action")
	if InputMap.has_action(action):
		check(is_equal_approx(InputMap.action_get_deadzone(action), 0.37) and InputMap.action_get_events(action).size() == 1 and InputMap.action_get_events(action)[0] == custom_key, "traversal_jump：退出不改既有鍵位與 deadzone")
		InputMap.erase_action(action)
	var temporary_lab := preload("res://scenes/traversal/movement_lab.tscn").instantiate() as MovementLab
	add_child(temporary_lab)
	check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "traversal_jump：缺少 action 時建立預設鍵位")
	temporary_lab.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not InputMap.has_action(action), "traversal_jump：退出清除場景自行建立的 action")
	# 無論斷言結果，恢復本測試進入前的 InputMap。
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	if existed:
		InputMap.add_action(action, original_deadzone)
		for event in original_events:
			InputMap.action_add_event(action, event)
	check(InputMap.has_action(action) == existed, "traversal_jump：恢復測試前 action 存在狀態")
	if existed:
		check(InputMap.action_get_deadzone(action) == original_deadzone and InputMap.action_get_events(action) == original_events, "traversal_jump：恢復測試前所有鍵位與 deadzone")
