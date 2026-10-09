extends Node
## Staff alert tier. Higher = hear farther; Clock uses level to delay night rest.

var level: int = 0:
	set(value):
		var clamped := clampi(value, 0, GameConst.MAX_ALERT_LEVEL)
		if level == clamped:
			return
		level = clamped
		Bus.alert_changed.emit(level)


func bump(amount: int = 1) -> void:
	level += amount


func decay_one() -> void:
	if level > 0:
		level -= 1


func hearing_radius() -> float:
	return GameConst.BASE_HEARING_RADIUS + float(level) * GameConst.HEARING_PER_ALERT


func noise_threshold() -> float:
	return maxf(0.35, 1.0 - float(level) * 0.12)
