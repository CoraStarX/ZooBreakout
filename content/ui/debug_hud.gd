extends CanvasLayer
## Debug HUD for P0/P1 systems.

@onready var label: Label = $Panel/Label

var _last_msg: String = "WASD相对相机 · E交互 · Tab换控 · F/H跟随待命 · 夜间破障 · 躲开红扇形视线"


func _ready() -> void:
	visible = false ## the real HUD is GameHUD; F3 toggles this developer panel
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
	var world := get_tree().get_first_node_in_group("zoo_world")
	var controlled := "?"
	var caps := "—"
	var inv := "—"
	var party_n := 0
	var breach := 0.0
	var detained := ""
	var objective := "—"
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
		intel_line,
		"办公室: %s" % OfficeStorage.summary(),
		_last_msg + debug_hint,
	])
