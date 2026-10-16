class_name GameHUD
extends CanvasLayer
## In-game HUD: top bar (day / phase / clock / single objective), status column (right),
## message log + onboarding hint (bottom). Polls the level root at ~8 Hz — no per-frame text churn.

const LOG_LINES := 3
const LOG_SEC := 6.0

const PHASE_COLORS := {
	Clock.Phase.OPEN: Color(1.0, 0.82, 0.3),
	Clock.Phase.CLOSE: Color(1.0, 0.55, 0.3),
	Clock.Phase.NIGHT_PATROL: Color(0.45, 0.6, 1.0),
	Clock.Phase.NIGHT_QUIET: Color(0.55, 0.45, 0.9),
}
const ITEM_COLORS := {
	&"wood": Color(0.78, 0.55, 0.3),
	&"rope": Color(0.8, 0.75, 0.5),
	&"metal": Color(0.7, 0.78, 0.9),
	&"route_kit": Color(0.9, 0.65, 0.25),
}
const ITEM_ORDER: Array[StringName] = [&"wood", &"rope", &"metal", &"route_kit"]

@export var guidance_params: GuidanceParams = preload("res://content/ui/guidance_params.tres")
var _guidance_route: String = ""
var _objective_details: Label
var _details_button: Button

var _day_l: Label
var _phase_l: Label
var _phase_chip: ColorRect
var _time_l: Label
var _rest_l: Label
var _obj_l: Label
var _who_l: Label
var _item_rows: Dictionary = {}
## What X does right now (store at route point / drop on ground).
var _drop_l: Label
## What E does at the point in front (Soft/Hard, payment, traces left).
var _use_l: Label
## Shouts left today · throw ready / cooldown.
var _voice_l: Label
var _alert_pips: Array[ColorRect] = []
var _alert_fx_l: Label
var _alert_warn_l: Label
var _intel_l: Label
var _dig_bar: ProgressBar
var _climb_bar: ProgressBar
var _dig_l: Label
var _climb_l: Label
var _office_l: Label
var _log_l: Label
var _hint_panel: PanelContainer
var _hint_l: Label
var _hint_tween: Tween
var _keys_l: Label
var _since: float = 0.0
var _log: Array = [] ## [text, expire_msec]


func _ready() -> void:
	layer = 5
	_build()
	Bus.interact_feedback.connect(_push_log)
	_refresh()


func _process(delta: float) -> void:
	_since += delta
	if _since >= guidance_params.refresh_sec:
		_since = 0.0
		_refresh()
	_trim_log()


## Onboarding text shown bottom-left for a few seconds.
func show_hint(text: String, seconds: float = 10.0) -> void:
	_hint_l.text = text
	_hint_panel.visible = true
	_hint_panel.modulate.a = 1.0
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint_panel, "modulate:a", 0.0, 0.8)
	_hint_tween.tween_callback(func() -> void: _hint_panel.visible = false)


func hide_hint() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_panel.visible = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	## --- top bar ---
	var top := UIKit.panel(Vector2(0, 0), 8)
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 10
	root.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	var top_rows := VBoxContainer.new()
	top.add_child(top_rows)
	top_rows.add_child(th)
	_day_l = UIKit.label("", 20, UIKit.ACCENT)
	th.add_child(_day_l)
	_phase_chip = UIKit.swatch(Color.WHITE, Vector2(14, 14))
	th.add_child(_phase_chip)
	_phase_l = UIKit.label("", 18)
	th.add_child(_phase_l)
	_time_l = UIKit.label("", 18, UIKit.TEXT_DIM)
	th.add_child(_time_l)
	_rest_l = UIKit.label("", 16, UIKit.TEXT_DIM)
	th.add_child(_rest_l)

	## 頂部單行目標；詳情預設收合，保留世界畫面的空間。
	var objective_row := HBoxContainer.new()
	top_rows.add_child(objective_row)
	_obj_l = UIKit.label("", guidance_params.objective_font_size, UIKit.ACCENT)
	_obj_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_row.add_child(_obj_l)
	_details_button = Button.new()
	_details_button.text = "詳情"
	_details_button.toggle_mode = true
	_details_button.button_pressed = guidance_params.details_initially_open
	objective_row.add_child(_details_button)
	_objective_details = UIKit.label("", 15, UIKit.TEXT_DIM)
	_objective_details.custom_minimum_size.x = guidance_params.details_width
	_objective_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_details.visible = guidance_params.details_initially_open
	top_rows.add_child(_objective_details)
	_details_button.toggled.connect(func(open: bool) -> void:
		_objective_details.visible = open
		_details_button.text = "收合" if open else "詳情"
	)

	## --- status (right) ---
	var right := UIKit.panel(Vector2(250, 0))
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -12.0
	right.offset_right = -12.0
	right.offset_top = 12.0
	right.offset_bottom = 12.0
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)
	_who_l = UIKit.label("", 18, UIKit.ACCENT)
	rv.add_child(_who_l)
	rv.add_child(UIKit.label("背包", 13, UIKit.TEXT_DIM))
	var inv := HFlowContainer.new()
	inv.add_theme_constant_override("h_separation", 12)
	inv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(inv)
	for id in ITEM_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(UIKit.swatch(ITEM_COLORS[id]))
		var l := UIKit.label("", 15)
		row.add_child(l)
		inv.add_child(row)
		_item_rows[id] = {"row": row, "label": l}
	_use_l = UIKit.label("", 14, UIKit.ACCENT)
	_use_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_use_l.custom_minimum_size = Vector2(230, 0)
	rv.add_child(_use_l)
	_drop_l = UIKit.label("", 14, UIKit.ACCENT)
	_drop_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drop_l.custom_minimum_size = Vector2(230, 0)
	rv.add_child(_drop_l)
	_voice_l = UIKit.label("", 13, UIKit.TEXT_DIM)
	rv.add_child(_voice_l)
	rv.add_child(UIKit.label("警戒", 13, UIKit.TEXT_DIM))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	rv.add_child(pips)
	for i in GameConst.MAX_ALERT_LEVEL:
		var pip := UIKit.swatch(Color(0.3, 0.3, 0.3), Vector2(26, 10))
		pips.add_child(pip)
		_alert_pips.append(pip)
	_alert_fx_l = UIKit.label("", 13, UIKit.TEXT_DIM)
	_alert_fx_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert_fx_l.custom_minimum_size = Vector2(230, 0)
	rv.add_child(_alert_fx_l)
	_alert_warn_l = UIKit.label("", 15, Color(1.0, 0.35, 0.3))
	_alert_warn_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert_warn_l.custom_minimum_size = Vector2(230, 0)
	rv.add_child(_alert_warn_l)
	rv.add_child(UIKit.label("施工进度", 13, UIKit.TEXT_DIM))
	var dig_row := HBoxContainer.new()
	_dig_l = UIKit.label("挖洞", 15)
	_dig_l.custom_minimum_size = Vector2(80, 0)
	dig_row.add_child(_dig_l)
	_dig_bar = _bar()
	dig_row.add_child(_dig_bar)
	rv.add_child(dig_row)
	var climb_row := HBoxContainer.new()
	_climb_l = UIKit.label("攀爬", 15)
	_climb_l.custom_minimum_size = Vector2(80, 0)
	climb_row.add_child(_climb_l)
	_climb_bar = _bar()
	climb_row.add_child(_climb_bar)
	rv.add_child(climb_row)
	_intel_l = UIKit.label("", 15)
	rv.add_child(_intel_l)
	_office_l = UIKit.label("", 14, UIKit.TEXT_DIM)
	rv.add_child(_office_l)

	## --- message log (bottom center) ---
	_log_l = UIKit.label("", 17)
	_log_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_log_l.add_theme_constant_override("outline_size", 6)
	_log_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_log_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_log_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log_l.offset_top = -40.0
	_log_l.offset_bottom = -40.0
	root.add_child(_log_l)

	## --- onboarding hint (bottom left) ---
	_hint_panel = UIKit.panel(Vector2(360, 0))
	_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_left = 12.0
	_hint_panel.offset_right = 12.0
	_hint_panel.offset_top = -52.0
	_hint_panel.offset_bottom = -52.0
	_hint_panel.visible = false
	root.add_child(_hint_panel)
	var hv := VBoxContainer.new()
	_hint_panel.add_child(hv)
	hv.add_child(UIKit.label("提示", 13, UIKit.ACCENT))
	_hint_l = UIKit.label("", 16)
	_hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_l.custom_minimum_size = Vector2(340, 0)
	hv.add_child(_hint_l)

	## --- key legend (bottom right) ---
	_keys_l = UIKit.label("WASD 移动 · E 交互 · X 放下/存料 · G 叫嚷 · T 投掷 · Tab 换控 · F/H 跟随/待命 · Esc 暂停", 13, UIKit.TEXT_DIM)
	_keys_l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_keys_l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_keys_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keys_l.offset_left = -12.0
	_keys_l.offset_right = -12.0
	_keys_l.offset_top = -8.0
	_keys_l.offset_bottom = -8.0
	root.add_child(_keys_l)


func _bar() -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = GameConst.ROUTE_TIERS
	b.show_percentage = false
	b.custom_minimum_size = Vector2(130, 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _push_log(message: String) -> void:
	_log.append([message, Time.get_ticks_msec() + int(LOG_SEC * 1000.0)])
	while _log.size() > LOG_LINES:
		_log.pop_front()
	_render_log()


func _trim_log() -> void:
	var now := Time.get_ticks_msec()
	var changed := false
	while not _log.is_empty() and int(_log[0][1]) < now:
		_log.pop_front()
		changed = true
	if changed:
		_render_log()


func _render_log() -> void:
	var lines := PackedStringArray()
	for e in _log:
		lines.append(String(e[0]))
	_log_l.text = "\n".join(lines)


func _refresh() -> void:
	var world := get_tree().get_first_node_in_group("zoo_world")
	var session: RunSession = null
	if world and world.get("session") is RunSession:
		session = world.get("session")

	_day_l.text = "第 %d / %d 天" % [Clock.day, GameConst.DEADLINE_DAY]
	_phase_l.text = Clock.phase_name()
	_phase_chip.color = PHASE_COLORS.get(Clock.phase, Color.WHITE)
	_time_l.text = "剩 %d 秒" % int(ceil(Clock.phase_remaining()))
	_rest_l.text = "歇岗：未知"
	if Alert.quiet_cancelled():
		_rest_l.text = "歇岗：取消（全园搜查）"
	elif session and session.has_intel(IntelIds.REST_TIME):
		_rest_l.text = "歇岗中" if Clock.phase == Clock.Phase.NIGHT_QUIET else "距歇岗 %d 秒" % int(Clock.seconds_until_quiet())

	if world and world.has_method("guidance_snapshot"):
		var snapshot: Dictionary = world.call("guidance_snapshot")
		var objective := GuidanceModel.derive(snapshot, _guidance_route, guidance_params)
		_guidance_route = String(objective.route)
		_obj_l.text = String(objective.title)
		_objective_details.text = String(objective.detail)

	var me: AnimalActor = null
	if world and world.has_method("controlled_animal"):
		me = world.call("controlled_animal")
	if me and me.def:
		var detained := ""
		if me.is_confined:
			detained = "  [短押 %d 秒]" % int(ceil(CaptureFlow.detention_left(me)))
		_who_l.text = "%s · %s%s" % [me.def.display_name, me.def.capability_labels(), detained]
		for id in ITEM_ORDER:
			var n := me.item_count(id)
			var entry: Dictionary = _item_rows[id]
			(entry["row"] as Control).visible = n > 0 or KitIds.is_material(id)
			(entry["label"] as Label).text = "%s %d" % [KitIds.display_name(id), n]
			(entry["label"] as Label).modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.4)
		_drop_l.text = me.drop_preview() if me.is_controlled else ""
		_drop_l.visible = _drop_l.text != ""
		_use_l.text = me.interact_preview() if me.is_controlled else ""
		_use_l.visible = _use_l.text != ""
		_voice_l.text = me.noise_tools_line()
	for i in _alert_pips.size():
		_alert_pips[i].color = Color(0.9, 0.25, 0.2) if i < Alert.level else Color(0.3, 0.3, 0.3)
	_alert_fx_l.text = Alert.effects_text()
	_alert_fx_l.visible = _alert_fx_l.text != ""
	_alert_warn_l.text = Alert.warning_text()
	_alert_warn_l.visible = _alert_warn_l.text != ""

	if session:
		var dig: int = session.route_tiers[RunSession.ExitRoute.DIG]
		var climb: int = session.route_tiers[RunSession.ExitRoute.CLIMB]
		_dig_bar.value = dig
		_climb_bar.value = climb
		_dig_l.text = "挖洞 ✓" if session.route_dig_ready else "挖洞 %d/%d" % [dig, GameConst.ROUTE_TIERS]
		_climb_l.text = "攀爬 ✓" if session.route_climb_ready else "攀爬 %d/%d" % [climb, GameConst.ROUTE_TIERS]
		_intel_l.text = session.intel_line()
	_office_l.text = "办公室：%s" % OfficeStorage.summary()
