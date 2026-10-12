extends Node
## 階段 A：awareness 純函式門禁（累積／衰減／可見度／閾值帶）。
## godot --headless --path . res://prototypes/p2_staff_awareness.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Staff Awareness ===")
	var p := StaffAiParams.new()
	_check(p.min_telegraph_sec >= 0.5, "預警下限 ≥ 0.5s（%.2f）" % p.min_telegraph_sec)

	## 靜止比奔跑更難被看見。
	var vis_run := StaffAwarenessMath.visibility_multiplier(p, 3.0, true, true, 2.5)
	var vis_still := StaffAwarenessMath.visibility_multiplier(p, 3.0, true, true, 0.0)
	_check(vis_still < vis_run, "靜止可見度 < 奔跑（%.2f < %.2f）" % [vis_still, vis_run])

	## 錐外／遮擋 = 0。
	_check(
		is_zero_approx(StaffAwarenessMath.visibility_multiplier(p, 3.0, false, true, 1.0)),
		"錐外可見度 = 0"
	)
	_check(
		is_zero_approx(StaffAwarenessMath.visibility_multiplier(p, 3.0, true, false, 1.0)),
		"無 LOS 可見度 = 0"
	)

	## 累積：在視野中持續上升。
	var a := 0.0
	for _i in 20:
		a = StaffAwarenessMath.tick(a, 0.1, 1.0, p)
	_check(a > p.suspicious_threshold, "持續暴露可超過起疑閾值（%.1f）" % a)

	## 衰減：離開視野下降。
	var high := 60.0
	var after := StaffAwarenessMath.tick(high, 1.0, 0.0, p)
	_check(after < high, "離開視野後衰減（%.1f → %.1f）" % [high, after])

	## 閾值帶。
	_check(StaffAwarenessMath.band_for(0.0, p) == &"calm", "0 → calm")
	_check(
		StaffAwarenessMath.band_for(p.suspicious_threshold, p) == &"suspicious",
		"suspicious 帶"
	)
	_check(
		StaffAwarenessMath.band_for(p.investigate_threshold, p) == &"investigate",
		"investigate 帶"
	)
	_check(StaffAwarenessMath.band_for(p.chase_threshold, p) == &"chase", "chase 帶")

	## 有界隨機不越界。
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in 30:
		var r := StaffAwarenessMath.bounded_rand(rng, p.score_noise_min, p.score_noise_max)
		if r < p.score_noise_min - 0.0001 or r > p.score_noise_max + 0.0001:
			_check(false, "有界隨機越界 %s" % r)
			break
	_check(true, "有界隨機 30 次皆在 [%s, %s]" % [p.score_noise_min, p.score_noise_max])

	## 預留擴充乘數列表。
	var with_cover := StaffAwarenessMath.visibility_multiplier(p, 3.0, true, true, 2.5, [0.5])
	_check(is_equal_approx(with_cover, vis_run * 0.5), "extra_mults 可疊乘（掩體預留）")

	print("")
	print("=== P2 STAFF AWARENESS SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
