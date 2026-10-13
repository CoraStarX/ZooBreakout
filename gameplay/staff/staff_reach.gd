class_name StaffReach
extends RefCounted
## Straight-line reachability for the staff motor (no NavMesh): a body-sized sphere swept against walls,
## plus a shortest hop path over patrol points when the goal is not directly walkable.

## Staff collider: sphere r 0.4 centred 0.4 above the feet.
const BODY_RADIUS := 0.4
const BODY_HEIGHT := 0.4
## Slightly thinner than the body so sliding along a wall face does not count as blocked.
const SWEEP_MARGIN := 0.05
## A node this close to `from` is where we already stand: route on from it instead of hopping to it again.
const AT_NODE := 0.75
const ORIGIN := -2


## True if the staff can walk straight from `from` to `to` (planar, walls on layer 1).
static func clear_line(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array = []) -> bool:
	if space == null:
		return true
	var a := Vector3(from.x, BODY_HEIGHT + 0.05, from.z)
	var b := Vector3(to.x, BODY_HEIGHT + 0.05, to.z)
	var motion := b - a
	if motion.length() < 0.01:
		return true
	var sphere := SphereShape3D.new()
	sphere.radius = BODY_RADIUS - SWEEP_MARGIN
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, a)
	q.motion = motion
	q.collision_mask = 1
	q.exclude = exclude
	var res := space.cast_motion(q)
	return res.size() >= 1 and res[0] >= 0.999


## Where to walk next to approach `goal`. Keys:
##   pos         next motor target
##   final       pos is the end of the trip (goal, or its substitute)
##   substitute  goal itself is unreachable; the trip ends at the reachable patrol point nearest to it
##   ok          false = nothing reachable at all (caller walks straight; wall fallback will catch it)
static func next_hop(
	space: PhysicsDirectSpaceState3D, from: Vector3, goal: Vector3, nodes: Array[Vector3], exclude: Array = []
) -> Dictionary:
	if clear_line(space, from, goal, exclude):
		return {"pos": goal, "final": true, "substitute": false, "ok": true}
	var n := nodes.size()
	## Dijkstra from `from` over nodes; edges = clear straight lines.
	var dist: Array[float] = []
	var first: Array[int] = []
	var done: Array[bool] = []
	for i in n:
		dist.append(INF)
		first.append(-1)
		done.append(false)
		if _flat(from).distance_to(_flat(nodes[i])) <= AT_NODE:
			dist[i] = 0.0
			first[i] = ORIGIN
		elif clear_line(space, from, nodes[i], exclude):
			dist[i] = _flat(from).distance_to(_flat(nodes[i]))
			first[i] = i
	while true:
		var u := -1
		for i in n:
			if not done[i] and dist[i] < INF and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0:
			break
		done[u] = true
		for v in n:
			if done[v] or v == u:
				continue
			var d := dist[u] + _flat(nodes[u]).distance_to(_flat(nodes[v]))
			if d < dist[v] and clear_line(space, nodes[u], nodes[v], exclude):
				dist[v] = d
				first[v] = v if first[u] == ORIGIN else first[u]
	## Best reachable node that sees the goal (shortest total trip).
	var best := -1
	var best_cost := INF
	for i in n:
		if dist[i] == INF:
			continue
		if clear_line(space, nodes[i], goal, exclude):
			var c := dist[i] + _flat(nodes[i]).distance_to(_flat(goal))
			if c < best_cost:
				best_cost = c
				best = i
	if best >= 0:
		if first[best] == ORIGIN: ## standing on the node that sees the goal: last stretch
			return {"pos": goal, "final": true, "substitute": false, "ok": true}
		return {"pos": nodes[first[best]], "final": false, "substitute": false, "ok": true}
	## Goal unreachable: substitute the reachable node nearest to it.
	var sub := -1
	for i in n:
		if dist[i] < INF and (sub < 0 or _flat(nodes[i]).distance_to(_flat(goal)) < _flat(nodes[sub]).distance_to(_flat(goal))):
			sub = i
	if sub >= 0:
		if first[sub] == ORIGIN:
			return {"pos": nodes[sub], "final": true, "substitute": true, "sub_pos": nodes[sub], "ok": true}
		var hop := nodes[first[sub]]
		return {"pos": hop, "final": first[sub] == sub, "substitute": true, "sub_pos": nodes[sub], "ok": true}
	return {"pos": goal, "final": true, "substitute": false, "ok": false}


static func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)
