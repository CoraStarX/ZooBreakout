extends Node
## Staff alert tier. Higher = hear farther; Clock uses level to delay night rest.
## Tier consequences are read here (values in AlertParams); noise alone never raises the level.

var level: int = 0:
	set(value):
		var clamped := clampi(value, 0, GameConst.MAX_ALERT_LEVEL)
		if level == clamped:
			return
		var rising := clamped > level
		level = clamped
		Bus.alert_changed.emit(level)
		if rising and tier_change_text() != "":
			Bus.interact_feedback.emit(tier_change_text())


func bump(amount: int = 1) -> void:
	level += amount


func decay_one() -> void:
	if level > 0:
		level -= 1


func hearing_radius() -> float:
	return (GameConst.BASE_HEARING_RADIUS + float(level) * GameConst.HEARING_PER_ALERT) * hearing_mult()


func noise_threshold() -> float:
	return maxf(0.35, 1.0 - float(level) * 0.12)


func hearing_mult() -> float:
	return GameConst.alert_params().hearing_mult_at_alert_2 if level >= 2 else 1.0


func construction_noise_mult() -> float:
	return GameConst.alert_params().construction_noise_mult_from_alert_3 if level >= 3 else 1.0


func confiscates_ground_items() -> bool:
	return level >= GameConst.alert_params().ground_confiscate_from_alert


func awareness_gain_mult() -> float:
	return GameConst.alert_params().awareness_gain_mult_at_alert_4 if level >= 4 else 1.0


func quiet_window_mult() -> float:
	return GameConst.alert_params().quiet_window_mult_at_alert_4 if level >= 4 else 1.0


## Top tier: zoo-wide search, all route construction stops.
func is_full_search() -> bool:
	return level >= GameConst.MAX_ALERT_LEVEL


## Persistent HUD warning for the current tier ("" when none).
func warning_text() -> String:
	if is_full_search():
		return "全园搜查中：外墙施工全部中止"
	if level == GameConst.MAX_ALERT_LEVEL - 1:
		return "再升一档将全园搜查"
	return ""


## Active consequences at the current tier, cumulative ("" at 0–1).
func effects_text() -> String:
	var parts: PackedStringArray = []
	if level >= 2:
		parts.append("听觉×%.2f" % hearing_mult())
	if level >= 3:
		parts.append("施工声×%.1f" % construction_noise_mult())
	if confiscates_ground_items():
		parts.append("收走地上物品")
	if level >= 4:
		parts.append("起疑×%.2f" % awareness_gain_mult())
		parts.append("歇岗×%.2f" % quiet_window_mult())
	return " · ".join(parts)


## One-line summary of what the tier just reached changes (shown on the way up).
func tier_change_text() -> String:
	if is_full_search():
		return "警戒 %d：全园搜查 — 外墙施工被迫中止，进行中的施工已取消" % level
	match level:
		2:
			return "警戒 2：职员听觉变灵（×%.2f）" % hearing_mult()
		3:
			return "警戒 3：施工声传得更远（×%.1f），职员会收走看到的地上物品" % construction_noise_mult()
		4:
			return "警戒 4：职员更快起疑，歇岗缩短 — 再升一档将全园搜查！"
	return ""
