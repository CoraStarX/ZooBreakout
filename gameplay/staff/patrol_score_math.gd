class_name PatrolScoreMath
extends RefCounted
## 巡邏選點評分純函式（有界隨機、可單測）。


static func score_point(
	point: PatrolPointData,
	now_sec: float,
	from_pos: Vector3,
	params: StaffAiParams,
	recent_ids: Array,
	rng: RandomNumberGenerator
) -> float:
	if point == null or params == null:
		return -INF
	var staleness := maxf(0.0, now_sec - point.last_visited)
	var dist := from_pos.distance_to(point.position)
	var recent_pen := 0.0
	for rid in recent_ids:
		if rid == point.id:
			recent_pen = params.weight_recent_penalty
			break
	var noise := StaffAwarenessMath.bounded_rand(rng, params.score_noise_min, params.score_noise_max)
	return (
		staleness * params.weight_staleness
		+ point.importance * params.weight_importance
		+ point.heat * params.weight_heat
		- dist * params.weight_distance_penalty
		- recent_pen
		+ noise
	)


static func pick_best_index(scores: Array) -> int:
	var best_i := -1
	var best_s := -INF
	for i in scores.size():
		var s := float(scores[i])
		if s > best_s:
			best_s = s
			best_i = i
	return best_i
