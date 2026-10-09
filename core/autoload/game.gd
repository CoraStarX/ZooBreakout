extends Node
## Boot helpers, input map, run session flags (starter choice).

var debug_enabled: bool = false
## Test/debug knob: scales construction channel time (1.0 = shipped feel).
var work_time_scale: float = 1.0
## Set by start select before loading zoo. Default raccoon.
var selected_starter_id: StringName = &"raccoon"


func _ready() -> void:
	_ensure_input_map()


func _ensure_input_map() -> void:
	_bind_key("move_left", KEY_A, KEY_LEFT)
	_bind_key("move_right", KEY_D, KEY_RIGHT)
	_bind_key("move_forward", KEY_W, KEY_UP)
	_bind_key("move_back", KEY_S, KEY_DOWN)
	_bind_joy_axis("move_left", "move_right", JOY_AXIS_LEFT_X)
	_bind_joy_axis("move_forward", "move_back", JOY_AXIS_LEFT_Y)
	_bind_key("interact", KEY_E)
	_bind_joy_button("interact", JOY_BUTTON_A)
	_bind_key("switch_animal", KEY_TAB, KEY_Q)
	_bind_joy_button("switch_animal", JOY_BUTTON_Y)
	_bind_key("order_follow", KEY_F)
	_bind_joy_button("order_follow", JOY_BUTTON_LEFT_SHOULDER)
	_bind_key("pause", KEY_ESCAPE)
	_bind_joy_button("pause", JOY_BUTTON_START)
	_bind_key("order_hold", KEY_H)
	_bind_joy_button("order_hold", JOY_BUTTON_RIGHT_SHOULDER)
	## Debug-only shortcuts (gated in zoo_world when debug_enabled).
	_bind_key("debug_rescue_monkey", KEY_R)
	_bind_key("debug_advance_phase", KEY_T)


func _bind_key(action: StringName, primary: Key, secondary: Key = KEY_NONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev := InputEventKey.new()
		ev.physical_keycode = primary
		InputMap.action_add_event(action, ev)
		if secondary != KEY_NONE:
			var ev2 := InputEventKey.new()
			ev2.physical_keycode = secondary
			InputMap.action_add_event(action, ev2)


func _bind_joy_axis(neg_action: StringName, pos_action: StringName, axis: JoyAxis) -> void:
	_ensure_action(neg_action)
	_ensure_action(pos_action)
	var has_neg := false
	var has_pos := false
	for e in InputMap.action_get_events(neg_action):
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == axis:
			has_neg = true
	for e in InputMap.action_get_events(pos_action):
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == axis:
			has_pos = true
	if not has_neg:
		var n := InputEventJoypadMotion.new()
		n.axis = axis
		n.axis_value = -1.0
		InputMap.action_add_event(neg_action, n)
	if not has_pos:
		var p := InputEventJoypadMotion.new()
		p.axis = axis
		p.axis_value = 1.0
		InputMap.action_add_event(pos_action, p)


func _bind_joy_button(action: StringName, button: JoyButton) -> void:
	_ensure_action(action)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
