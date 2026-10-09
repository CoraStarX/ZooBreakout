class_name ProximityLabel
extends Label3D
## World label that stays readable: constant on-screen size, drawn over walls, and level-of-detail by
## distance — far away only the first line (the name), near the controlled animal the full text.

const NEAR_DIST := 5.5
const CHECK_SEC := 0.15

var full_text: String = ""
var short_text: String = ""
var _since: float = 0.0
var _near: bool = true


static func style(label: Label3D, size: int = 30) -> void:
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0016
	label.font_size = size
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.no_depth_test = true
	label.render_priority = 10


func _init() -> void:
	style(self)


func _ready() -> void:
	_apply()


## Full text may be multi-line; the short form defaults to its first line.
func set_info(full: String, short: String = "") -> void:
	full_text = full
	short_text = short if not short.is_empty() else full.split("\n")[0]
	_apply()


func _process(delta: float) -> void:
	_since += delta
	if _since < CHECK_SEC:
		return
	_since = 0.0
	var near := _is_near_controlled()
	if near != _near:
		_near = near
		_apply()


## Distance to whatever the player currently controls (group "controlled", kept by the actor).
func _is_near_controlled() -> bool:
	var focus := get_tree().get_first_node_in_group("controlled") as Node3D
	if focus == null:
		return true
	return focus.global_position.distance_to(global_position) <= NEAR_DIST


func _apply() -> void:
	text = full_text if _near else short_text
