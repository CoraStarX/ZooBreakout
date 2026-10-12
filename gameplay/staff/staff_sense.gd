class_name StaffSense
extends RefCounted
## 感知快照：只暴露強度與 last_known，不把玩家 Node 交給決策層。


class Snapshot:
	var visibility_mult: float = 0.0
	var heard_footstep: bool = false
	var planar_speed: float = 0.0
	var distance: float = INF
	var has_contact: bool = false
	## 僅在真正感知到時有效（看見或聽見）。
	var last_known: Vector3 = Vector3.ZERO
	var last_known_valid: bool = false
	var detect_kind: String = ""


static func in_vision_cone(
	origin: Vector3,
	facing: Vector3,
	target_pos: Vector3,
	vision_range: float,
	vision_angle_deg: float
) -> bool:
	var to := target_pos - origin
	to.y = 0.0
	var dist := to.length()
	if dist > vision_range or dist < 0.05:
		return false
	var face := Vector3(facing.x, 0.0, facing.z)
	if face.length() < 0.01:
		face = Vector3(0, 0, 1)
	face = face.normalized()
	var ang := rad_to_deg(acos(clampf(face.dot(to.normalized()), -1.0, 1.0)))
	return ang <= vision_angle_deg * 0.5


static func has_line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array = []) -> bool:
	if space == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(
		from + Vector3(0, 0.55, 0),
		to + Vector3(0, 0.55, 0)
	)
	query.collision_mask = 1
	query.exclude = exclude
	return space.intersect_ray(query).is_empty()


## 掃描 animals 群組，回傳最佳感知快照（不見得有目標）。
static func scan(
	params: StaffAiParams,
	space: PhysicsDirectSpaceState3D,
	origin: Vector3,
	facing: Vector3,
	exclude_rids: Array,
	animal_nodes: Array,
	extra_mults: Array = []
) -> Snapshot:
	var best := Snapshot.new()
	if params == null:
		return best
	var best_score := -1.0
	for node in animal_nodes:
		if not (node is AnimalActor):
			continue
		var animal := node as AnimalActor
		if not animal.is_rescued or animal.is_confined:
			continue
		var pos := animal.global_position
		var to := pos - origin
		to.y = 0.0
		var dist := to.length()
		var speed := Vector3(animal.velocity.x, 0.0, animal.velocity.z).length()
		var heard := dist <= params.hear_walk_range and speed > params.still_speed_threshold
		var in_cone := in_vision_cone(origin, facing, pos, params.vision_range, params.vision_angle_deg)
		var los := false
		if in_cone:
			los = has_line_of_sight(space, origin, pos, exclude_rids)
		var vis := StaffAwarenessMath.visibility_multiplier(params, dist, in_cone, los, speed, extra_mults)
		if vis <= 0.0 and not heard:
			continue
		## 視線優先於腳步；同分取近。
		var score := vis * 10.0 + (0.5 if heard and vis <= 0.0 else 0.0) - dist * 0.01
		if score > best_score:
			best_score = score
			best.visibility_mult = vis
			best.heard_footstep = heard and vis <= 0.0
			best.planar_speed = speed
			best.distance = dist
			best.has_contact = true
			best.last_known = pos
			best.last_known_valid = true
			if vis > 0.0:
				best.detect_kind = "被视线发现"
			else:
				best.detect_kind = "被脚步声引来"
	return best
