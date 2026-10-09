extends Node
## Day phases. Escape breaches only at night; Open is visitor hours.

enum Phase { OPEN, CLOSE, NIGHT_PATROL, NIGHT_QUIET }

var phase: Phase = Phase.OPEN:
	set(value):
		if phase == value:
			return
		phase = value
		_phase_elapsed = 0.0
		Bus.phase_changed.emit(phase as int)
		_announce_phase()

var auto_advance: bool = true
## 1-based day counter; ticks at each dawn (NIGHT_QUIET → OPEN).
var day: int = 1
var _phase_elapsed: float = 0.0


func _process(delta: float) -> void:
	if not auto_advance:
		return
	## Only tick while a level is live — title / result screens must not eat the Open window.
	if get_tree().get_first_node_in_group("zoo_world") == null:
		return
	_phase_elapsed += delta
	if _phase_elapsed >= _phase_duration():
		advance()


func phase_name() -> String:
	match phase:
		Phase.OPEN:
			return "Open-参观"
		Phase.CLOSE:
			return "Close-闭园"
		Phase.NIGHT_PATROL:
			return "Night-Patrol"
		Phase.NIGHT_QUIET:
			return "Night-Quiet"
		_:
			return "?"


func set_phase(p: Phase) -> void:
	phase = p


## Fresh run: Open with a full timer (setter alone skips reset when already OPEN).
func reset_for_new_run() -> void:
	auto_advance = true
	day = 1
	phase = Phase.OPEN
	_phase_elapsed = 0.0
	Bus.day_changed.emit(day)


func phase_remaining() -> float:
	return maxf(0.0, _phase_duration() - _phase_elapsed)


func night_patrol_duration() -> float:
	return GameConst.NIGHT_PATROL_BASE_SEC + float(Alert.level) * GameConst.NIGHT_PATROL_PER_ALERT_SEC


## Dig / climb / cage breakouts only during night.
func allows_escape_actions() -> bool:
	return phase == Phase.NIGHT_PATROL or phase == Phase.NIGHT_QUIET


func is_visitor_hours() -> bool:
	return phase == Phase.OPEN


func _phase_duration() -> float:
	match phase:
		Phase.OPEN:
			return GameConst.OPEN_PHASE_SEC
		Phase.CLOSE:
			return GameConst.CLOSE_PHASE_SEC
		Phase.NIGHT_PATROL:
			return night_patrol_duration()
		Phase.NIGHT_QUIET:
			return GameConst.NIGHT_QUIET_SEC
		_:
			return 10.0


func advance() -> void:
	match phase:
		Phase.OPEN:
			phase = Phase.CLOSE
		Phase.CLOSE:
			phase = Phase.NIGHT_PATROL
		Phase.NIGHT_PATROL:
			phase = Phase.NIGHT_QUIET
		Phase.NIGHT_QUIET:
			_new_day()


func _new_day() -> void:
	## Day bumps before the Open phase signal so listeners see the new day number.
	day += 1
	Bus.day_changed.emit(day)
	phase = Phase.OPEN


## Seconds until Night-Quiet starts (0 while it is on). Assumes current alert for the night length.
func seconds_until_quiet() -> float:
	match phase:
		Phase.OPEN:
			return phase_remaining() + GameConst.CLOSE_PHASE_SEC + night_patrol_duration()
		Phase.CLOSE:
			return phase_remaining() + night_patrol_duration()
		Phase.NIGHT_PATROL:
			return phase_remaining()
		_:
			return 0.0


func days_left() -> int:
	return maxi(0, GameConst.DEADLINE_DAY - day)


func _announce_phase() -> void:
	match phase:
		Phase.OPEN:
			Bus.interact_feedback.emit("参观时段：捡★套件 → Soft 溜出 → 外墙准备；打通外墙请等到夜间")
		Phase.CLOSE:
			Bus.interact_feedback.emit("闭园过渡：清场中，短窗口")
		Phase.NIGHT_PATROL:
			Bus.interact_feedback.emit("夜间巡逻：可以开始越狱，注意职员视线")
		Phase.NIGHT_QUIET:
			Bus.interact_feedback.emit("夜巡歇岗 — 安全窗打开（警戒越高巡逻越久）")
