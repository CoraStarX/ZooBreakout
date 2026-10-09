class_name RunSession
extends Node
## Scene-scoped run progress — not an Autoload. Hosted by level root.

enum Outcome { NONE, WON, LOST }
enum ExitRoute { DIG, CLIMB }

var breach: float = 0.0
var exhibit_escaped: bool = false
var companion_rescued: bool = false
var route_dig_ready: bool = false
var route_climb_ready: bool = false
## Night construction: tiers completed per route.
var route_tiers: Dictionary = {ExitRoute.DIG: 0, ExitRoute.CLIMB: 0}
var outcome: Outcome = Outcome.NONE
## Learned intel ids (IntelIds), kept across days.
var intel: Dictionary = {}
## Per-day stats for the dawn summary (reset every dawn).
var _captures_today: int = 0
var _breach_at_day_start: float = 0.0
var _rescued_today: int = 0
var outcome_reason: String = ""


func _ready() -> void:
	Bus.day_changed.connect(_on_day_changed)
	Bus.captured.connect(func(_a: Node3D) -> void: _captures_today += 1)
	Bus.animal_rescued.connect(func(_id: StringName) -> void: _rescued_today += 1)


func _on_day_changed(new_day: int) -> void:
	if new_day <= 1 or is_finished():
		return
	var ended := new_day - 1
	var lines := PackedStringArray()
	lines.append("被抓 %d 次" % _captures_today)
	if _rescued_today > 0:
		lines.append("解救同伴 %d" % _rescued_today)
	lines.append("Breach %+.0f%%（累计 %.0f%%）" % [(breach - _breach_at_day_start) * 100.0, breach * 100.0])
	## Quiet day (no capture) cools alert by one tier.
	if _captures_today == 0 and Alert.level > 0:
		Alert.decay_one()
		lines.append("安分一天，警戒降至 %d" % Alert.level)
	else:
		lines.append("警戒 %d" % Alert.level)
	_captures_today = 0
	_rescued_today = 0
	_breach_at_day_start = breach
	if ended >= GameConst.DEADLINE_DAY:
		try_lose_deadline()
		return
	lines.append("距封园检修还剩 %d 天" % (GameConst.DEADLINE_DAY - ended))
	Bus.day_summary.emit(ended, lines)


func try_lose_deadline() -> bool:
	if outcome != Outcome.NONE:
		return false
	outcome = Outcome.LOST
	outcome_reason = "第 %d 天封园检修，仍未出园" % GameConst.DEADLINE_DAY
	Bus.run_outcome_changed.emit(outcome as int)
	Bus.interact_feedback.emit("封园失败：%s" % outcome_reason)
	return true


func add_breach(amount: float) -> void:
	breach = clampf(breach + amount, 0.0, 1.0)
	Bus.breach_changed.emit(breach)


func mark_exhibit_escaped() -> bool:
	if exhibit_escaped:
		return false
	exhibit_escaped = true
	return true


func mark_companion_rescued() -> bool:
	if companion_rescued:
		return false
	companion_rescued = true
	return true


func mark_route_dig_ready() -> bool:
	if route_dig_ready:
		return false
	route_dig_ready = true
	return true


func mark_route_climb_ready() -> bool:
	if route_climb_ready:
		return false
	route_climb_ready = true
	return true


func has_intel(id: StringName) -> bool:
	return intel.has(id)


func learn_intel(id: StringName) -> bool:
	if intel.has(id):
		return false
	intel[id] = true
	Bus.intel_gained.emit(id)
	return true


func intel_line() -> String:
	return "情报: 歇岗%s 路线%s" % [
		"✓" if has_intel(IntelIds.REST_TIME) else "…",
		"✓" if has_intel(IntelIds.PATROL_ROUTE) else "…",
	]


## Night construction progress per route (tiers done). Breach = furthest route.
func set_route_tiers(route: ExitRoute, done: int) -> void:
	route_tiers[route] = done
	var best := 0.0
	for r in route_tiers:
		best = maxf(best, float(route_tiers[r]) / float(GameConst.ROUTE_TIERS))
	if best > breach:
		breach = best
		Bus.breach_changed.emit(breach)


func tiers_line() -> String:
	return "施工: 挖 %d/%d  爬 %d/%d" % [
		route_tiers[ExitRoute.DIG], GameConst.ROUTE_TIERS,
		route_tiers[ExitRoute.CLIMB], GameConst.ROUTE_TIERS,
	]


func is_route_ready(route: ExitRoute) -> bool:
	match route:
		ExitRoute.DIG:
			return route_dig_ready
		ExitRoute.CLIMB:
			return route_climb_ready
		_:
			return false


func is_finished() -> bool:
	return outcome != Outcome.NONE


func try_win(reason: String = "全队同步出园") -> bool:
	if outcome != Outcome.NONE:
		return false
	outcome = Outcome.WON
	outcome_reason = reason
	Bus.run_outcome_changed.emit(outcome as int)
	Bus.interact_feedback.emit("逃脱成功！%s" % reason)
	return true


func try_lose_on_max_alert_capture() -> bool:
	## Fail only when alert already at cap and player is captured again.
	if outcome != Outcome.NONE:
		return false
	if Alert.level < GameConst.MAX_ALERT_LEVEL:
		return false
	outcome = Outcome.LOST
	outcome_reason = "警戒满档再被抓 — 园区封园"
	Bus.run_outcome_changed.emit(outcome as int)
	Bus.interact_feedback.emit("封园失败：%s" % outcome_reason)
	return true


func current_objective() -> String:
	if outcome == Outcome.WON:
		return "已逃脱 — 查看结算"
	if outcome == Outcome.LOST:
		return "封园失败 — 查看结算"
	if not exhibit_escaped:
		if Clock.is_visitor_hours():
			return "白天：搜集原料（木/绳/金属）、侦察职员；可先溜出笼门（夜间再施工）"
		return "夜间打开笼门逃出展区"
	if not companion_rescued:
		return "打开同伴笼门解救入队（可 Tab 换控）"
	if Clock.allows_escape_actions():
		return "夜间施工：挖洞每档 木料+金属，攀爬每档 绳索+金属，或用套件 [%s]" % tiers_line()
	return "白天搜集原料/套件、侦察；夜里去外墙施工 [%s]" % tiers_line()
