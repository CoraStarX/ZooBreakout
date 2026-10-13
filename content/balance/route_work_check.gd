class_name RouteWorkCheck
extends RefCounted
## Load-time guard for construction timing (docs/COST_REFACTOR.md「施工时间」): progress carries across
## nights, so a tier is never endless as long as every workable night has working seconds and a safe window.


## Seconds of night (patrol + quiet) at an Alert level below full search.
static func night_sec(level: int) -> float:
	var quiet_mult := GameConst.alert_params().quiet_window_mult_at_alert_4 if level >= 4 else 1.0
	return night_patrol_sec(level) + GameConst.NIGHT_QUIET_SEC * quiet_mult


static func night_patrol_sec(level: int) -> float:
	return GameConst.NIGHT_PATROL_BASE_SEC + float(level) * GameConst.NIGHT_PATROL_PER_ALERT_SEC


static func quiet_sec(level: int) -> float:
	return GameConst.NIGHT_QUIET_SEC * (GameConst.alert_params().quiet_window_mult_at_alert_4 if level >= 4 else 1.0)


## Shortest night over every level construction is allowed at.
static func shortest_night() -> float:
	var best := INF
	for lv in range(0, GameConst.MAX_ALERT_LEVEL):
		best = minf(best, night_sec(lv))
	return best


## Nights one tier needs at worst (shortest night, working the whole night). INF = never finishes.
static func min_nights(soft: bool) -> float:
	var sec := Interactable.tier_seconds(soft)
	var night := shortest_night()
	if sec <= 0.0 or night <= 0.0 or is_inf(night):
		return INF
	return ceilf(sec / night)


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var rw := GameConst.route_work()
	if rw.tier_soft_sec <= 0.0 or rw.hard_time_mult <= 0.0:
		errors.append("施工时长非正（tier_soft_sec=%.1f hard_time_mult=%.1f）" % [rw.tier_soft_sec, rw.hard_time_mult])
	for soft in [true, false]:
		if is_inf(min_nights(soft)):
			errors.append("%s 施工一档永远做不完（最短一夜 %.0fs）" % ["Soft" if soft else "Hard", shortest_night()])
	for lv in range(0, GameConst.MAX_ALERT_LEVEL):
		if quiet_sec(lv) <= 0.0 and rw.exposure_target_max >= 1.0:
			errors.append("警戒 %d 无歇岗且暴露目标 100%%：施工没有安全窗口" % lv)
	if rw.exposure_target_min > rw.exposure_target_max:
		errors.append("暴露目标区间颠倒（%.2f > %.2f）" % [rw.exposure_target_min, rw.exposure_target_max])
	return errors
