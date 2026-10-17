extends CanvasLayer
## F3 移動診斷面板；接受注入的移動與可選員工統計。

@onready var label: Label = $Panel/Label

var readability_metrics: StaffReadabilityMetrics
var movement_metrics: TraversalMetrics
var movement_params: TraversalParams
var _export_stats_button: Button
var _copy_status: Label
var _metrics_since: float = 0.0


func _ready() -> void:
	visible = false
	if movement_metrics != null:
		_ensure_movement_controls()
		_refresh()


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


func _refresh() -> void:
	if movement_metrics == null or label == null:
		return
	if _export_stats_button:
		_export_stats_button.visible = readability_metrics != null
	label.text = movement_report(true)


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
