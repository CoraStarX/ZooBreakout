class_name PauseMenu
extends CanvasLayer
## Esc pause menu: resume, controls, onboarding toggle/reset, volume, back to title.

var hint_director: HintDirector

var _root: Control
var _help: Label
var _resume: Button
var _slider: HSlider


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	_apply_volume(float(UserPrefs.get_value("prefs", "master_linear", 0.8)))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _run_finished():
		return
	toggle()
	get_viewport().set_input_as_handled()


func toggle() -> void:
	var show := not _root.visible
	_root.visible = show
	get_tree().paused = show
	if show:
		_help.visible = false
		_resume.grab_focus()


func _run_finished() -> bool:
	var world := get_tree().get_first_node_in_group("zoo_world")
	return world != null and world.get("session") is RunSession and (world.get("session") as RunSession).is_finished()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.7)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := UIKit.panel(Vector2(420, 0), 20)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := UIKit.label("已暂停", 28, UIKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_resume = Button.new()
	_resume.text = "继续"
	_resume.pressed.connect(toggle)
	v.add_child(_resume)
	var help_btn := Button.new()
	help_btn.text = "操作说明"
	help_btn.pressed.connect(func() -> void: _help.visible = not _help.visible)
	v.add_child(help_btn)
	_help = UIKit.label(
		"WASD / 左摇杆  移动（相对相机）\nE / 手柄 A  交互：搜集、观察、施工、开笼门\nTab / 手柄 Y  换控\nF · H / LB · RB  队友跟随 · 待命\nEsc  暂停\n\n红色扇形 = 职员视线。夜间施工，白天搜集。",
		15, UIKit.TEXT_DIM)
	_help.visible = false
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(380, 0)
	v.add_child(_help)
	var hints := CheckButton.new()
	hints.text = "新手引导提示"
	hints.button_pressed = bool(UserPrefs.get_value("prefs", "hints_enabled", true))
	hints.toggled.connect(func(on: bool) -> void:
		HintDirector.set_enabled(on)
		if hint_director:
			hint_director.enabled = on
	)
	v.add_child(hints)
	var reset_btn := Button.new()
	reset_btn.text = "重置引导（再次显示全部提示）"
	reset_btn.pressed.connect(func() -> void:
		HintDirector.reset_seen()
		Bus.interact_feedback.emit("引导已重置")
	)
	v.add_child(reset_btn)
	var vol_row := HBoxContainer.new()
	vol_row.add_child(UIKit.label("音量", 16))
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.05
	_slider.value = float(UserPrefs.get_value("prefs", "master_linear", 0.8))
	_slider.custom_minimum_size = Vector2(250, 20)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(func(val: float) -> void:
		_apply_volume(val)
		UserPrefs.set_value("prefs", "master_linear", val)
	)
	vol_row.add_child(_slider)
	v.add_child(vol_row)
	var quit_btn := Button.new()
	quit_btn.text = "回标题（放弃本局）"
	quit_btn.pressed.connect(_to_title)
	v.add_child(quit_btn)


func _apply_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.0001)))


func _to_title() -> void:
	get_tree().paused = false
	RunLifecycle.reset()
	get_tree().change_scene_to_file("res://scenes/boot/start_select.tscn")
