class_name StaffAwarenessMath
extends RefCounted
## 純函式：awareness 累積／衰減與可見度乘數。便於無頭測試，禁止讀取場景節點。


## 可見度乘數：0 = 完全看不見。之後蹲伏／陰影／掩體只需擴充乘法項。
static func visibility_multiplier(
	params: StaffAiParams,
	distance: float,
	in_cone: bool,
	has_los: bool,
	planar_speed: float,
	extra_mults: Array = []
) -> float:
	if params == null:
		return 0.0
	if not in_cone:
		return 0.0
	if not has_los:
		return params.mult_blocked_los
	var m := params.mult_in_cone
	var t := 0.0
	if params.distance_far > params.distance_near:
		t = clampf(
			(distance - params.distance_near) / (params.distance_far - params.distance_near),
			0.0,
			1.0
		)
	m *= lerpf(params.mult_distance_near, params.mult_distance_far, t)
	if planar_speed <= params.still_speed_threshold:
		m *= params.mult_still
	elif planar_speed <= params.slow_speed_threshold:
		m *= params.mult_slow
	for em in extra_mults:
		m *= float(em)
	return maxf(0.0, m)


## 單幀更新 awareness。visibility>0 累積，否則衰減；spike 用於聽覺／噪音一次性加成。
static func tick(
	current: float,
	delta: float,
	visibility_mult: float,
	params: StaffAiParams,
	awareness_spike: float = 0.0
) -> float:
	if params == null:
		return current
	var v := current
	if visibility_mult > 0.0:
		v += params.accumulate_per_sec * visibility_mult * delta
	else:
		v -= params.decay_per_sec * delta
	v += awareness_spike
	return clampf(v, 0.0, params.awareness_max)


## 由 awareness 得出應處的警覺帶（不含 Chase 鎖定／Search 等流程態）。
static func band_for(awareness: float, params: StaffAiParams) -> StringName:
	if params == null:
		return &"calm"
	if awareness >= params.chase_threshold:
		return &"chase"
	if awareness >= params.investigate_threshold:
		return &"investigate"
	if awareness >= params.suspicious_threshold:
		return &"suspicious"
	return &"calm"


## 有界隨機（含端點），供選點噪聲／停留時間使用。
static func bounded_rand(rng: RandomNumberGenerator, lo: float, hi: float) -> float:
	if hi < lo:
		var tmp := lo
		lo = hi
		hi = tmp
	if is_equal_approx(lo, hi):
		return lo
	return rng.randf_range(lo, hi)
