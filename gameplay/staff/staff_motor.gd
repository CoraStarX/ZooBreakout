class_name StaffMotor
extends RefCounted
## 可替換移動介面：上層只呼叫 set_target / tick。本階段直線行走；日後可換 NavigationAgent。

var speed: float = 2.8
var arrive_distance: float = 0.45
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false


func set_target(pos: Vector3) -> void:
	_target = pos
	_has_target = true


func clear_target() -> void:
	_has_target = false


func has_target() -> bool:
	return _has_target


func target() -> Vector3:
	return _target


func arrived(from: Vector3) -> bool:
	if not _has_target:
		return true
	var d := from.distance_to(_target)
	d = Vector3(from.x, 0.0, from.z).distance_to(Vector3(_target.x, 0.0, _target.z))
	return d <= arrive_distance


## 回傳建議平面速度（不含 y）。呼叫端寫入 CharacterBody3D.velocity。
func tick_velocity(from: Vector3, current_speed: float = -1.0) -> Vector3:
	if not _has_target:
		return Vector3.ZERO
	var sp := current_speed if current_speed > 0.0 else speed
	var to := _target - from
	to.y = 0.0
	if to.length() <= arrive_distance:
		return Vector3.ZERO
	return to.normalized() * sp
