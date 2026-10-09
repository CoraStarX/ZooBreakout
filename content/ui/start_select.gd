extends Control
## Content: choose starter animal before loading the zoo.

@onready var _hint: Label = %Hint
@onready var _raccoon_btn: Button = %RaccoonBtn
@onready var _monkey_btn: Button = %MonkeyBtn


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _hint:
		_hint.text = "选择开局动物：浣熊（巧手：开锁、搜柜更稳）或 猴（攀爬：翻墙、够高处更稳）。\n另一只关在笼里，稍后解救。白天搜集、夜里施工，5 天内逃出动物园。"
	# Connect in code so instance/main wrapping never drops .tscn connections.
	if _raccoon_btn and not _raccoon_btn.pressed.is_connected(_on_raccoon_pressed):
		_raccoon_btn.pressed.connect(_on_raccoon_pressed)
	if _monkey_btn and not _monkey_btn.pressed.is_connected(_on_monkey_pressed):
		_monkey_btn.pressed.connect(_on_monkey_pressed)


func _on_raccoon_pressed() -> void:
	_begin(&"raccoon")


func _on_monkey_pressed() -> void:
	_begin(&"monkey")


func _begin(starter_id: StringName) -> void:
	Game.selected_starter_id = starter_id
	RunLifecycle.reset()
	if _hint:
		_hint.text = "正在进入动物园…"
	# Disable double-clicks while loading.
	if _raccoon_btn:
		_raccoon_btn.disabled = true
	if _monkey_btn:
		_monkey_btn.disabled = true
	call_deferred("_load_zoo")


func _load_zoo() -> void:
	var path := "res://scenes/world/zoo_p0.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Zoo Breakout: failed to change scene to %s (error %s)" % [path, err])
		if _hint:
			_hint.text = "进入失败（错误 %s），请查看调试器输出" % err
		if _raccoon_btn:
			_raccoon_btn.disabled = false
		if _monkey_btn:
			_monkey_btn.disabled = false
