class_name StaffReadabilityMetrics
extends RefCounted
var params: StaffReadabilityParams
var source: String = "手玩"
var counters: Dictionary = {}
var events: Array[Dictionary] = []
var timeline: Array[Dictionary] = []
## 摘要事件保留至重置，不被高頻診斷環淘汰。
var discoveries: Array[Dictionary] = []
var milestones: Array[Dictionary] = []
var latest: Dictionary = {}
var _next_sample: float = 0.0
func _init(p: StaffReadabilityParams = null) -> void:
	params = p if p else StaffReadabilityParams.new()
	reset()
func reset() -> void:
	counters = {"chase_started":0,"rest_started":0,"rest_heard":0,"arrival":0,"search_abandoned":0,"search_extended":0,"search_started":0}
	events.clear()
	timeline.clear()
	discoveries.clear()
	milestones.clear()
	latest.clear()
	_next_sample = 0
func event(time: float, kind: String, data: Dictionary = {}) -> void:
	if counters.has(kind): counters[kind] += 1
	var entry := {"time":time,"kind":kind,"data":data.duplicate(true)}
	events.append(entry)
	if kind == "chase_started": discoveries.append(entry)
	if kind in ["search_started","search_extended","search_abandoned","search_interrupted","rest_started","rest_heard","rest_finished"]: milestones.append(entry)
	while events.size() > params.event_limit: events.pop_front()
func sample(time: float, data: Dictionary) -> void:
	latest = data.duplicate(true)
	if time < _next_sample: return
	_next_sample = time + params.metrics_interval_sec
	timeline.append({"time":time,"data":latest.duplicate(true)})
	while timeline.size() > params.metrics_limit: timeline.pop_front()

## 預設只給可讀摘要；完整事件 JSON／0.1秒時間線由明確的匯出操作取得。
func report(compact: bool = false, include_timeline: bool = false) -> String:
	var lines := PackedStringArray(["員工可讀性統計｜來源：" + source,
		"追捕開始 %d｜追捕到達 %d｜搜索放棄 %d｜搜索延長 %d" % [counters.chase_started,counters.arrival,counters.search_abandoned,counters.search_extended],
		"歇崗 %d 次｜歇崗聽見 %d 次（離散聲音事件）" % [counters.rest_started,counters.rest_heard]])
	if not latest.is_empty():
		lines.append("目前 %s｜awareness %.1f → %.1f" % [latest.state,latest.before,latest.awareness])
		lines.append("來源 %s｜視覺倍率 ×%.2f｜聽覺貢獻 +%.1f" % [latest.visual,latest.visibility_mult,latest.hearing_spike])
		lines.append("原因 %s｜感知投影 %s" % [latest.get("reason",""),latest.projection])
		lines.append("搜索剩餘 %.1fs｜同源冷卻 %s｜記憶來源 %s" % [latest.search_remaining,"是" if latest.cooling else "否",latest.memory_source])
	lines.append("追捕摘要（開始時間／來源／首次看見至追捕）")
	for discovery in (discoveries.slice(maxi(0,discoveries.size()-params.displayed_events)) if compact else discoveries):
		var memory: Dictionary = discovery.data.get("memory",{})
		var first: Variant = discovery.data.get("first_seen")
		var elapsed := "未有視覺記錄" if first == null else "%.2fs（首次看見 %.2fs）" % [discovery.time-float(first),float(first)]
		lines.append("%.2fs｜%s｜%s" % [discovery.time,discovery.data.get("cause",memory.get("source","")),elapsed])
	lines.append("搜索摘要（開始／延長／放棄或中斷）")
	var names := {"search_started":"開始","search_extended":"延長","search_abandoned":"放棄","search_interrupted":"中斷"}
	var searches := milestones.filter(func(e: Dictionary) -> bool: return names.has(e.kind))
	for entry in (searches.slice(maxi(0,searches.size()-params.displayed_events)) if compact else searches):
		var memory: Dictionary = entry.data.get("memory",{})
		var detail: String = str(entry.data.get("cause",entry.data.get("source",memory.get("source",""))))
		if entry.data.has("deadline"): detail += "｜截止 %.2fs" % entry.data.deadline
		lines.append("%.2fs %s｜%s" % [entry.time,names[entry.kind],detail])
	lines.append("歇崗摘要（起訖／期間是否聽見）")
	var rests := milestones.filter(func(e: Dictionary) -> bool: return e.kind == "rest_started")
	for rest in (rests.slice(maxi(0,rests.size()-params.displayed_events)) if compact else rests):
		var finish := INF
		var count := 0
		for entry in milestones:
			if entry.time < rest.time: continue
			if entry.kind == "rest_finished": finish = entry.time; break
			if entry.kind == "rest_heard": count += 1
		lines.append("%.2fs–%s｜%s" % [rest.time,"進行中" if not is_finite(finish) else "%.2fs" % finish,"聽見 %d 次" % count if count > 0 else "未聽見"])
	# 重置發生於休息中時仍保留聲音證據，不把它算成新一次歇崗。
	if rests.is_empty() and counters.rest_heard > 0: lines.append("重置時已在歇崗｜聽見 %d 次" % counters.rest_heard)
	if include_timeline:
		lines.append("完整事件（保留最近 %d 筆）" % params.event_limit)
		for entry in events: lines.append("%.2fs %s %s" % [entry.time,entry.kind,JSON.stringify(entry.data)])
		lines.append("awareness 時間線（取樣 %.2fs；保留最近 %d 筆）" % [params.metrics_interval_sec,params.metrics_limit])
		for entry in timeline: lines.append("%.2fs %s" % [entry.time,JSON.stringify(entry.data)])
	return "\n".join(lines)
