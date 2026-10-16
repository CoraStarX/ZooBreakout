extends Node
## R5.5 純函式與正式場景接線回歸；不賦予能力或修改玩法判定。
var _pass_n: int = 0
var _fail_n: int = 0

func _ready() -> void:
	var params := GuidanceParams.new()
	var a := {"id": "a", "name": "甲線", "progress": 0.2, "invested": true, "can_work": true, "soft_ready": true}
	var b := {"id": "b", "name": "乙線", "progress": 0.6, "invested": true, "can_work": false}
	var s := {"routes": [a, b], "detained": true, "full_search": true, "pending_rescue": true}
	_check(GuidanceModel.derive(s, "", params).stage == &"detained", "拘留優先於搜查與救援")
	s.detained = false
	_check(GuidanceModel.derive(s, "", params).stage == &"search", "搜查優先於救援")
	s.full_search = false
	_check(GuidanceModel.derive(s, "", params).stage == &"rescue", "救援優先於施工")
	s.pending_rescue = false
	_check(GuidanceModel.derive(s, "", params).route == "b", "首次推薦較高進度的路線")
	_check(GuidanceModel.derive(s, "a", params).route == "a", "已有投入的推薦保持穩定")
	var original := s.duplicate(true)
	for i in 20:
		s.routes.reverse()
		_check(GuidanceModel.derive(s, "a", params).route == "a", "順序波動不閃爍 %d" % i)
	_check(s == original, "純函式未改動輸入（偶數次反轉還原）")
	s.routes = [a]
	_check(GuidanceModel.derive(s, "", params).stage == &"wait", "已備料白天等待夜晚")
	a.deposit_useful = true
	_check(GuidanceModel.derive(s, "", params).stage == &"deposit", "白天可建議存料")
	s.night = true
	_check(GuidanceModel.derive(s, "", params).stage == &"work", "夜晚跳過存料直接施工")
	a.soft_ready = false
	_check(GuidanceModel.derive(s, "", params).detail.contains("Hard"), "僅可強行時明示成本")
	s.night = false
	a.deposit_useful = false
	_check(GuidanceModel.derive(s, "", params).stage == &"gather", "可強行不代表白天無須備料")
	a.can_work = false
	s.night = true
	_check(GuidanceModel.derive(s, "", params).stage == &"gather", "夜晚缺料指引隔日準備")
	a.ready = true
	_check(GuidanceModel.derive(s, "", params).stage == &"exit", "任一路線完工提示全員出口")
	s.pending_rescue = true
	_check(GuidanceModel.derive(s, "", params).stage == &"rescue", "完工仍需先救同伴")
	s.finished = true
	_check(GuidanceModel.derive(s, "", params).stage == &"finished", "結算不再顯示行動目標")
	_check(GuidanceModel.derive({}, "", params).title != "", "空快照仍有目標")
	var tied := [{"id": "z", "progress": 0.0}, {"id": "a", "progress": 0.0}]
	_check(GuidanceModel.choose_route(tied, "", params).id == "a", "同進度使用穩定識別排序")
	tied.reverse()
	_check(GuidanceModel.choose_route(tied, "", params).id == "a", "同進度不受列舉順序影響")
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world := (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	var hud := world.get_node("GameHUD") as GameHUD
	hud._refresh()
	_check(hud._obj_l.text == "救出同伴", "正式開局頂部目標救同伴")
	_check(not hud._objective_details.visible, "詳情預設收合")
	hud._details_button.button_pressed = true
	_check(hud._objective_details.visible and hud._objective_details.text.contains("籠門"), "按鈕展開對應詳情")
	hud._details_button.button_pressed = false
	_check(not hud._objective_details.visible, "按鈕可收合")
	hud._details_button.grab_focus()
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	get_viewport().push_input(accept)
	accept = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = false
	get_viewport().push_input(accept)
	_check(hud._objective_details.visible, "詳情按鈕支援鍵盤／手柄確認")
	hud._details_button.release_focus()
	var me: AnimalActor = world.call("controlled_animal")
	var before := me.inventory.duplicate()
	var snapshot: Dictionary = world.call("guidance_snapshot")
	_check(snapshot.pending_rescue and me.inventory == before, "快照不修改正式開局背包")
	var site: Interactable = world.get("_geometry").dig_interactable
	var row_id := str(site.breach_style)
	var inv_before := me.inventory.duplicate()
	me.inventory.clear()
	site._tier_pay = &"materials"
	site.tier_progress = 0.4
	snapshot = world.call("guidance_snapshot")
	for row: Dictionary in snapshot.routes:
		if row.id == row_id:
			_check(row.soft_ready and row.invested and not row.deposit_useful, "已付款跨夜檔不重複要求材料或存料")
	site._tier_pay = &""
	site._kit_credit = 1
	snapshot = world.call("guidance_snapshot")
	for row: Dictionary in snapshot.routes:
		if row.id == row_id:
			_check(row.soft_ready, "套件餘檔可直接施工")
	site._kit_credit = 0
	site.tier_progress = 0.0
	site.stash.assign(site.tier_cost)
	snapshot = world.call("guidance_snapshot")
	for row: Dictionary in snapshot.routes:
		if row.id == row_id:
			_check(row.soft_ready and row.invested, "存料足夠時不要求背包材料")
	me.inventory.assign(inv_before)
	_check(HintDirector.HINTS[&"night"].contains("Hard 仍可能被聽到"), "夜間教學移除歇崗免噪音說法")
	world.queue_free()
	await get_tree().process_frame
	print("=== P2 GUIDANCE SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", message)
	else:
		_fail_n += 1
		print("FAIL ", message)
