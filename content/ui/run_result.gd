extends CanvasLayer
## End-of-run overlay: win / lose → back to start select.

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _reason: Label = $Center/Panel/VBox/Reason
@onready var _button: Button = $Center/Panel/VBox/BackBtn


func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _button and not _button.pressed.is_connected(_on_back):
		_button.pressed.connect(_on_back)
	Bus.run_outcome_changed.connect(_on_bus_outcome)


func _on_bus_outcome(outcome: int) -> void:
	var reason := ""
	var world := get_tree().get_first_node_in_group("zoo_world")
	if world and world.get("session") is RunSession:
		reason = (world.get("session") as RunSession).outcome_reason
	show_outcome(outcome, reason)


func show_outcome(outcome: int, reason: String) -> void:
	visible = true
	get_tree().paused = true
	if outcome == RunSession.Outcome.WON:
		_title.text = "逃脱成功"
		_title.modulate = Color(0.55, 1.0, 0.65)
	elif outcome == RunSession.Outcome.LOST:
		_title.text = "封园失败"
		_title.modulate = Color(1.0, 0.45, 0.4)
	else:
		_title.text = "本局结束"
		_title.modulate = Color.WHITE
	_reason.text = reason if not reason.is_empty() else "—"
	_button.grab_focus()


func _on_back() -> void:
	get_tree().paused = false
	RunLifecycle.reset()
	var err := get_tree().change_scene_to_file("res://scenes/boot/start_select.tscn")
	if err != OK:
		push_error("RunResult: failed to return to start_select (%s)" % err)
