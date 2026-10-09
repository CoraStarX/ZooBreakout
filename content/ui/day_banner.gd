extends CanvasLayer
## Dawn summary toast (non-pausing) + persistent "Day N" chip handled by the HUD.

const SHOW_SEC := 7.0

var _panel: PanelContainer
var _title: Label
var _body: Label
var _tween: Tween


func _ready() -> void:
	layer = 15
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = 24
	_panel.modulate.a = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 17)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	box.add_child(_body)
	_panel.add_child(box)
	add_child(_panel)
	Bus.day_summary.connect(_on_summary)


func _on_summary(day: int, lines: PackedStringArray) -> void:
	_title.text = "第 %d 天结束 · 天亮了" % day
	_body.text = "\n".join(lines)
	_panel.reset_size()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.4)
	_tween.tween_interval(SHOW_SEC)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.8)
