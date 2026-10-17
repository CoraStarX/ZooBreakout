class_name TraversalMetrics
extends RefCounted
## 場景級記錄，不寫入偏好；時間由角色物理步更新，F3 隱藏時仍持續記錄。
enum Phase { IDLE, CLIMB, GAP, RETURN }
var params: TraversalParams
var source: String = "手玩"
var rows: Array[Dictionary] = []
var phase: Phase = Phase.IDLE
var elapsed: float = 0.0
var extra_inputs: int = 0
var accidental_falls: int = 0
var interrupted_jumps: int = 0
var recoveries: int = 0
var _start: float = 0.0
var _climb_end: float = 0.0
var _gap_end: float = 0.0
var _route: String = "斜坡"
var _attempt_retried: bool = false
var _return_crossings: int = 0
var _return_actions: int = 0
var _return_modes := PackedStringArray()
var _start_counts := Vector4i.ZERO
var session: String = Time.get_datetime_string_from_system() + "-" + str(Time.get_ticks_usec())
var completed_count: int = 0
var completed_counts := Vector4i.ZERO
var current_events: Array[Dictionary] = []
var outside_events: Array[Dictionary] = []
var recovery_records: Array[Dictionary] = []

func diagnostic(record: Dictionary) -> void:
	var entry := record.duplicate(true)
	entry["source"] = source
	entry["session"] = session
	entry["loop"] = completed_count + 1 if phase != Phase.IDLE else 0
	entry["phase"] = ["未開始", "爬牆", "跨間隙", "返回"][phase]
	entry["scope"] = "圈內" if phase != Phase.IDLE else "圈外"
	var events: Array[Dictionary] = current_events if phase != Phase.IDLE else outside_events
	events.append(entry)
	while events.size() > params.diagnostic_event_limit:
		events.pop_front()
	if entry["kind"] == "recovery":
		recovery_records.append(entry)
		while recovery_records.size() > params.diagnostic_recovery_limit:
			recovery_records.pop_front()
		print("MOVEMENT_DIAGNOSTIC ", JSON.stringify(entry))
	# 無頭測試不污染玩家日誌；原生手玩的每個離散輸入與恢復事件立即追加落盤。
	if DisplayServer.get_name() != "headless":
		var log_file := FileAccess.open(params.diagnostic_log_path, FileAccess.READ_WRITE if FileAccess.file_exists(params.diagnostic_log_path) else FileAccess.WRITE)
		if log_file:
			log_file.seek_end()
			log_file.store_line(JSON.stringify(entry))
		else:
			push_warning("移動診斷日誌無法寫入：" + params.diagnostic_log_path)

func current_counts() -> Vector4i:
	return counts() - _start_counts if phase != Phase.IDLE else Vector4i.ZERO

func outside_counts() -> Vector4i:
	return counts() - completed_counts - current_counts()

static func median(values: Array[float]) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	return sorted[middle] if sorted.size() % 2 else (sorted[middle - 1] + sorted[middle]) * 0.5

static func count_text(value: Vector4i) -> String:
	return "%d／%d／%d／%d" % [value.x, value.y, value.z, value.w]

func route_summary(route: String) -> String:
	var matching: Array[Dictionary] = []
	for row in rows:
		if row["route"] == route: matching.append(row)
	if route in ["混合", "重試", "重複返回"]: return "%s：%d 圈，不計入返回方式驗收" % [route, matching.size()]
	if matching.is_empty(): return route + "：0 圈，尚未驗證"
	var medians: Array[float] = []
	for key in ["total", "climb", "gap", "return"]:
		var values: Array[float] = []
		for row in matching: values.append(float(row[key]))
		medians.append(median(values))
	return "%s：%d/%d 圈｜中位數 %.2f（%.2f／%.2f／%.2f）秒｜%s" % [route, matching.size(), params.metrics_route_target, medians[0], medians[1], medians[2], medians[3], "樣本足夠" if matching.size() >= params.metrics_route_target else "樣本不足"]


func _init(settings: TraversalParams = null) -> void:
	params = settings if settings else TraversalParams.new()

func advance(delta: float) -> void:
	elapsed += delta

func event(tag: StringName, _amount: float = 0.0) -> void:
	match tag:
		&"invalid": extra_inputs += 1
		&"accidental_fall": accidental_falls += 1
		&"jump_interrupted": interrupted_jumps += 1
		&"recovery": recoveries += 1
		&"attach_start":
			if phase == Phase.IDLE:
				_start = elapsed
				_start_counts = counts()
				current_events.clear()
				phase = Phase.CLIMB
				_route = "斜坡"
				_attempt_retried = false
				_return_crossings = 0
				_return_actions = 0
				_return_modes.clear()
		&"roof":
			if phase == Phase.CLIMB:
				_climb_end = elapsed
				phase = Phase.GAP
		&"gap":
			if phase == Phase.GAP:
				_gap_end = elapsed
				phase = Phase.RETURN
			elif phase == Phase.RETURN:
				_return_crossings += 1
				_route = return_route(_return_crossings, _return_modes, _attempt_retried, _return_actions)
		&"return_wall":
			if phase == Phase.RETURN: _record_return_mode("下牆")
		&"return_drop":
			if phase == Phase.RETURN: _record_return_mode("跳下")
			elif phase in [Phase.CLIMB, Phase.GAP]: _attempt_retried = true
		&"return_release":
			if phase == Phase.RETURN: _record_return_mode("放手")
			elif phase in [Phase.CLIMB, Phase.GAP]: _attempt_retried = true

func _record_return_mode(mode: String) -> void:
	_return_actions += 1
	if not _return_modes.has(mode): _return_modes.append(mode)
	_route = return_route(_return_crossings, _return_modes, _attempt_retried, _return_actions)

static func return_route(crossings: int, modes: PackedStringArray, retried: bool = false, actions: int = 0) -> String:
	if retried: return "重試"
	if actions > 1 and modes.size() == 1: return "重複返回"
	# 一次返跳再下牆是正常返回；反覆跨越或多種下行方式不可混入單一路線中位數。
	if crossings > 1 or modes.size() > 1: return "混合"
	return modes[0] if not modes.is_empty() else "斜坡"

func counts() -> Vector4i:
	return Vector4i(extra_inputs, accidental_falls, interrupted_jumps, recoveries)

func finish_if_returned(in_start_zone: bool, grounded: bool) -> void:
	if phase != Phase.RETURN or not grounded or not in_start_zone:
		return
	_route = return_route(_return_crossings, _return_modes, _attempt_retried, _return_actions)
	completed_count += 1
	var delta := counts() - _start_counts
	completed_counts += delta
	rows.append({"index": completed_count, "route": _route, "total": elapsed - _start,
		"climb": _climb_end - _start, "gap": _gap_end - _climb_end, "return": elapsed - _gap_end,
		"extra": delta.x, "falls": delta.y, "interrupts": delta.z, "recoveries": delta.w, "events": current_events.duplicate(true), "retried": _attempt_retried, "return_crossings": _return_crossings, "return_actions": _return_actions, "return_modes": _return_modes.duplicate()})
	while rows.size() > params.metrics_history_limit:
		rows.pop_front()
	phase = Phase.IDLE
	current_events.clear()

func reset() -> void:
	session = Time.get_datetime_string_from_system() + "-" + str(Time.get_ticks_usec())
	rows.clear()
	_attempt_retried = false
	_return_crossings = 0
	_return_actions = 0
	_return_modes.clear()
	completed_counts = Vector4i.ZERO
	current_events.clear()
	outside_events.clear()
	recovery_records.clear()
	phase = Phase.IDLE
	elapsed = 0.0
	completed_count = 0
	extra_inputs = 0
	accidental_falls = 0
	interrupted_jumps = 0
	recoveries = 0
	_start = 0.0
	_climb_end = 0.0
	_gap_end = 0.0
	_start_counts = Vector4i.ZERO

static func slow_segments(samples: Array[Dictionary], ratio: float) -> PackedStringArray:
	var result := PackedStringArray()
	if samples.size() < 2:
		return result
	var latest := samples[-1]
	if latest["route"] in ["混合", "重試", "重複返回"]: return result
	for key in ["climb", "gap", "return"]:
		var times: Array[float] = []
		for row in samples.slice(0, samples.size() - 1):
			if row["route"] == latest["route"]:
				times.append(float(row[key]))
		if times.is_empty():
			continue
		times.sort()
		var middle := times.size() / 2
		var median := times[middle] if times.size() % 2 != 0 else (times[middle - 1] + times[middle]) * 0.5
		if float(latest[key]) > median * ratio:
			result.append(str(key))
	return result

func report() -> String:
	var lines := PackedStringArray([
		"移動統計｜來源：" + source,
		"完成 %d 圈｜進行中：%s" % [completed_count, ["未開始", "爬牆", "跨間隙", "返回"][phase]],
		"多餘輸入 %d｜意外墜落 %d｜跳躍中斷 %d｜卡住恢復 %d%s" % [extra_inputs, accidental_falls, interrupted_jumps, recoveries, "（BUG）" if recoveries > 0 else ""],
	])
	lines.append("計數順序：多餘／墜落／中斷／恢復")
	lines.append("已完成累計：" + count_text(completed_counts))
	lines.append("進行中本圈：" + count_text(current_counts()))
	lines.append("圈外累計：" + count_text(outside_counts()))
	lines.append("整次恢復檢查：" + ("BUG（任何圈內外恢復皆不通過）" if recoveries > 0 else "通過"))
	lines.append(route_summary("斜坡"))
	lines.append(route_summary("跳下"))
	lines.append(route_summary("下牆"))
	lines.append(route_summary("重複返回") + "（同圈多次下行，不計單次耗時）")
	lines.append(route_summary("混合") + "（不與單一路線比較）")
	lines.append(route_summary("重試") + "（首次跨越前曾放手／下行）")
	var target := params.metrics_target_loops
	var eligible: Array[Dictionary] = []
	for row in rows:
		if row["route"] not in ["混合", "重試", "重複返回"]: eligible.append(row)
	if eligible.size() >= target:
		var samples: Array[Dictionary] = eligible.slice(eligible.size() - target)
		var same_route := true
		var sample_counts := Vector4i.ZERO
		for row in samples:
			sample_counts += Vector4i(row["extra"], row["falls"], row["interrupts"], row["recoveries"])
			same_route = same_route and row["route"] == samples[0]["route"] and row["route"] not in ["混合", "重試", "重複返回"]
		lines.append("最近 %d 個有效單次圈：輸入%s／失誤%s／恢復%s" % [target,
			"通過" if sample_counts.x <= params.metrics_max_extra_inputs else "超標",
			"通過" if sample_counts.y + sample_counts.z <= params.metrics_max_accidents else "超標",
			"通過" if sample_counts.w == 0 and recoveries == 0 else "BUG"])
		lines.append("同路線末圈比首圈快：%s" % (("是" if samples[-1]["total"] < samples[0]["total"] - params.metrics_faster_epsilon_sec else "否") if same_route else "混合路線，不比較"))
		lines.append("末圈偏長路段：%s" % (", ".join(slow_segments(samples, params.metrics_segment_slow_ratio)) if not slow_segments(samples, params.metrics_segment_slow_ratio).is_empty() else "無（對照同路線歷次中位數）"))
	else:
		lines.append("尚需 %d 個有效單次圈（混合／重試／重複返回不計入）" % (target - eligible.size()))
	lines.append("圈數／返回方式：總計（爬牆／跨間隙／返回）秒；多餘／墜落／中斷／恢復")
	for row in rows:
		lines.append("%02d %s：%.2f（%.2f／%.2f／%.2f）；%d／%d／%d／%d" % [row["index"], row["route"], row["total"], row["climb"], row["gap"], row["return"], row["extra"], row["falls"], row["interrupts"], row["recoveries"]])
		if row["route"] == "重複返回":
			lines.append("  同圈下行 %d 次；不計單次下行耗時與驗收" % row.get("return_actions", 0))
		if row["route"] == "混合":
			lines.append("  返回段跨間隙 %d 次／下行方式：%s" % [row.get("return_crossings", 0), "、".join(row.get("return_modes", PackedStringArray()))])
	# 每一圈都檢查，避免第八圈異常被第十圈的正常數字掩蓋。
	for row in rows:
		var peers: Array[Dictionary] = []
		for other in rows:
			if other["index"] != row["index"]: peers.append(other)
		peers.append(row)
		var slow := slow_segments(peers, params.metrics_segment_slow_ratio)
		if not slow.is_empty(): lines.append("第 %02d 圈偏長：%s" % [row["index"], ", ".join(slow)])
		for entry in row.get("events", []):
			lines.append(event_text(entry))
	for entry in current_events:
		lines.append("進行中 " + event_text(entry))
	for entry in outside_events:
		lines.append("圈外 " + event_text(entry))
	for entry in recovery_records:
		lines.append("恢復快照：" + JSON.stringify(entry))
	lines.append("完整診斷日誌：" + ProjectSettings.globalize_path(params.diagnostic_log_path))
	return "\n".join(lines)

static func event_text(entry: Dictionary) -> String:
	var text := "#%02d %.2fs %s/%s %s pos=%s target=%s landing=%s %s" % [entry["loop"], entry["time"], entry["phase"], entry["state"], entry["kind"], entry["position"], entry["target"], entry["landing"], entry["reason"]]

	if entry.get("request_kind", "") != "":
		text += " 行動=%s 鎖定落點=%s" % [entry["request_kind"], entry.get("request_landing", "none")]
	if entry["kind"] == "invalid":
		text += "\n  候選：" + JSON.stringify(entry.get("candidates", []))
	var sequence := PackedStringArray()
	var previous := ""
	for frame in entry["inputs"]:
		var signature := "%s/%s Space=%s E=%s" % [frame["axes"], frame["state"], frame["space"], frame.get("e", false)]
		if signature != previous:
			sequence.append("%.2f:%s" % [frame["time"], signature])
			previous = signature
	text += "\n  前一秒輸入（變化點）：" + " → ".join(sequence)
	return text
