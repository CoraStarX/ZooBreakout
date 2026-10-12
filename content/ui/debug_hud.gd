extends CanvasLayer
## Debug HUD for P0/P1 systems. F3 開關；含職員 AI Debug 勾選。

@onready var label: Label = $Panel/Label

var _last_msg: String = "WASD相对相机 · E交互 · G叫嚷 · Tab换控 · F/H跟随待命 · V标记 · X放下/存料 · 夜间破障 · 躲开红扇形视线"
var _staff_ai_check: CheckButton


func _ready() -> void:
	visible = false ## the real HUD is GameHUD; F3 toggles this developer panel
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


func _process(_delta: float) -> void:
	if visible:
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
			staff_line = "职员AI: %s  awareness:%.0f  Alert(跑团):%d  debug:%s" % [
				st.state_name(), st.awareness, Alert.level, "ON" if Game.staff_ai_debug else "off"
			]
	var debug_hint := " · Debug:R跳过解救 T推时段" if Game.debug_enabled else ""
	var rest_text := "歇岗:未知"
	var intel_line := "情报: —"
	if world and world.get("session") is RunSession:
		var sess: RunSession = world.get("session")
		intel_line = sess.intel_line()
		if sess.has_intel(IntelIds.REST_TIME):
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
