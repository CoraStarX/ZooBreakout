extends CanvasLayer
## Debug HUD for P0/P1 systems. F3 開關；含職員 AI Debug 勾選。

@onready var label: Label = $Panel/Label

var _last_msg: String = "WASD相对相机 · E交互 · G叫嚷 · T投掷 · Tab换控 · F/H跟随待命 · V标记 · X放下/存料 · 夜间破障 · 躲开红扇形视线"
var _staff_ai_check: CheckButton
var readability_metrics: StaffReadabilityMetrics
var movement_metrics: TraversalMetrics
var movement_params: TraversalParams
var _export_stats_button: Button
var _copy_status: Label
var _metrics_since: float = 0.0


func _ready() -> void:
	visible = false ## the real HUD is GameHUD; F3 toggles this developer panel
	if movement_metrics != null:
		_ensure_movement_controls()
		_refresh()
		return
	_ensure_staff_ai_toggle()
	Bus.interact_feedback.connect(_on_feedback)
	Bus.animal_switched.connect(func(_a): _refresh())
	Bus.alert_changed.connect(func(_l): _refresh())
	Bus.breach_changed.connect(func(_v): _refresh())
	Bus.phase_changed.connect(func(_p): _refresh())
	Bus.captured.connect(func(_a): _refresh())
	Bus.office_items_changed.connect(func(_i): _refresh())
	Bus.animal_rescued.connect(func(_id): _refresh())
	Bus.run_outcome_changed.connect(func(_o): _refresh())
	_refresh()


func _ensure_staff_ai_toggle() -> void:
	var panel := $Panel as PanelContainer
	if panel == null:
		return
	## 把 Label 包進 VBox，底下加勾選。
	if panel.get_node_or_null("VBox") != null:
		_staff_ai_check = panel.get_node("VBox/StaffAiDebug") as CheckButton
		return
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	label.reparent(vbox)
	panel.add_child(vbox)
	_staff_ai_check = CheckButton.new()
	_staff_ai_check.name = "StaffAiDebug"
	_staff_ai_check.text = "职员 AI Debug（视锥/听觉/目标/awareness）"
	_staff_ai_check.button_pressed = Game.staff_ai_debug
	_staff_ai_check.toggled.connect(func(on: bool) -> void:
		Game.staff_ai_debug = on
	)
	vbox.add_child(_staff_ai_check)


func _process(delta: float) -> void:
	if not visible:
		return
	if movement_metrics != null:
		_metrics_since += delta
		if _metrics_since < movement_params.metrics_refresh_sec:
			return
		_metrics_since = 0.0
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible


func _inventory_text(a: AnimalActor) -> String:
	if a.inventory.is_empty():
		return "空"
	var counts := {}
	for id in a.inventory:
		counts[id] = int(counts.get(id, 0)) + 1
	var parts := PackedStringArray()
	for id in counts:
		parts.append("%s×%d" % [KitIds.display_name(id), counts[id]])
	return ", ".join(parts)


func _on_feedback(message: String) -> void:
	_last_msg = message
	_refresh()


func _refresh() -> void:
	if movement_metrics != null:
		if _export_stats_button: _export_stats_button.visible = readability_metrics != null
		label.text = movement_report(true)
		return
	if label == null:
		return
	if _staff_ai_check and _staff_ai_check.button_pressed != Game.staff_ai_debug:
		_staff_ai_check.set_pressed_no_signal(Game.staff_ai_debug)
	var world := get_tree().get_first_node_in_group("zoo_world")
	var controlled := "?"
	var caps := "—"
	var inv := "—"
	var party_n := 0
	var breach := 0.0
	var detained := ""
	var objective := "—"
	var staff_line := "职员AI: —"
	if world and world.has_method("controlled_animal"):
		var a: AnimalActor = world.call("controlled_animal")
		if a and a.def:
			controlled = a.def.display_name
			caps = a.def.capability_labels()
			inv = _inventory_text(a)
			if a.is_confined:
				detained = " [短押 %.0fs]" % CaptureFlow.detention_left(a)
		if world.has_method("party_animals"):
			party_n = (world.call("party_animals") as Array).size()
		elif world.has_method("party"):
			var p = world.get("party")
			if p and p.has_method("party"):
				party_n = p.party().size()
		breach = world.get("breach")
		if world.has_method("current_objective"):
			objective = str(world.call("current_objective"))
	if world and world.has_method("get_staff"):
		var st: StaffActor = world.call("get_staff")
		if st:
			staff_line = "职员AI: %s  awareness:%.0f  Alert(跑团):%d  debug:%s\n  %s" % [
				st.state_name(), st.awareness, Alert.level, "ON" if Game.staff_ai_debug else "off", st.nav_debug_text()
			]
	var debug_hint := " · Debug:R跳过解救 N推时段" if Game.debug_enabled else ""
	var rest_text := "歇岗:未知"
	var intel_line := "情报: —"
	if world and world.get("session") is RunSession:
		var sess: RunSession = world.get("session")
		intel_line = sess.intel_line()
		if Alert.quiet_cancelled():
			rest_text = "歇岗:取消(全园搜查)"
		elif sess.has_intel(IntelIds.REST_TIME):
			rest_text = "歇岗中" if Clock.phase == Clock.Phase.NIGHT_QUIET else "距歇岗 %.0fs" % Clock.seconds_until_quiet()
	var route_line := ""
	var prep_line := ""
	if world and world.get("session") is RunSession:
		var s: RunSession = world.get("session")
		route_line = "出园线: 挖%s 爬%s" % [
			"✓" if s.route_dig_ready else "…",
			"✓" if s.route_climb_ready else "…",
		]
		prep_line = s.tiers_line()
		var ex: RouteExposure = world.get("exposure")
		if ex:
			prep_line += "\n施工点(夜巡):\n  " + ex.debug_text()
		if s.outcome == RunSession.Outcome.WON:
			route_line += "  | 已逃脱"
		elif s.outcome == RunSession.Outcome.LOST:
			route_line += "  | 封园失败"
	label.text = "\n".join([
		"Zoo Breakout P2 · 第 %d/%d 天" % [Clock.day, GameConst.DEADLINE_DAY],
		"目标: %s" % objective,
		prep_line if not prep_line.is_empty() else "施工: —",
		route_line if not route_line.is_empty() else "出园线: —",
		"控制: %s%s [%s]  队伍:%d  背包:%s" % [controlled, detained, caps, party_n, inv],
		"警戒:%d  时段:%s (剩%.0fs)  %s  Breach:%.0f%%" % [
			Alert.level, Clock.phase_name(), Clock.phase_remaining(), rest_text, breach * 100.0
		],
		staff_line,
		intel_line,
		"办公室: %s" % OfficeStorage.summary(),
		_last_msg + debug_hint,
	])


func _ensure_movement_controls() -> void:
	var panel := $Panel as PanelContainer
	panel.offset_top = movement_params.metrics_panel_top
	panel.offset_right = panel.offset_left + movement_params.metrics_panel_width
	panel.offset_bottom = panel.offset_top + movement_params.metrics_panel_height
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.BG
	style.bg_color.a = movement_params.metrics_background_alpha
	style.set_content_margin_all(movement_params.metrics_panel_margin)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.name = "MovementStats"
	label.reparent(box)
	panel.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = movement_params.metrics_panel_height
	box.add_child(scroll)
	label.reparent(scroll)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	box.add_child(buttons)
	var reset := Button.new()
	reset.name = "ResetStats"
	reset.custom_minimum_size = movement_params.metrics_button_min_size
	reset.text = "重置統計"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		movement_metrics.reset()
		if readability_metrics: readability_metrics.reset()
		_copy_status.text = "已重置；下一次爬牆開始計時"
		_refresh()
	)
	buttons.add_child(reset)
	var copy := Button.new()
	copy.name = "CopyStats"
	copy.custom_minimum_size = movement_params.metrics_button_min_size
	copy.text = "複製統計"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(copy_movement_stats)
	buttons.add_child(copy)
	_export_stats_button = Button.new()
	_export_stats_button.name = "ExportTimeline"
	_export_stats_button.text = "複製完整診斷"
	_export_stats_button.focus_mode = Control.FOCUS_NONE
	_export_stats_button.visible = readability_metrics != null
	_export_stats_button.pressed.connect(copy_detailed_stats)
	buttons.add_child(_export_stats_button)
	_copy_status = Label.new()
	buttons.add_child(_copy_status)

func copy_movement_stats() -> String:
	var text := movement_report()
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)
	if _copy_status:
		_copy_status.text = "已複製純文字"
	return text

func copy_detailed_stats() -> String:
	var text := (readability_metrics.report(false,true) + "\n\n" if readability_metrics else "") + movement_metrics.report()
	if DisplayServer.get_name() != "headless": DisplayServer.clipboard_set(text)
	if _copy_status: _copy_status.text = "已複製完整時間線"
	return text

func movement_report(compact: bool = false) -> String:
	if not readability_metrics: return movement_metrics.report()
	# 員工試玩預設不附上數千行移動輸入；凍結移動原型的複製行為維持原樣。
	var movement_summary := "\n".join(movement_metrics.report().split("\n").slice(0,readability_metrics.params.movement_summary_lines))
	return readability_metrics.report(compact) + "\n\n" + movement_summary
