class_name TraceService
extends Node
## Spawns / decays construction traces. Prefer one instance under the level root.


const DISCOVER_RANGE := 2.2


func _ready() -> void:
	add_to_group("trace_service")
	if not Bus.day_changed.is_connected(_on_day_changed):
		Bus.day_changed.connect(_on_day_changed)


func _on_day_changed(_day: int) -> void:
	var retain := GameConst.route_work().trace_dawn_retain
	for n in get_tree().get_nodes_in_group("traces"):
		if n is TraceMarker:
			(n as TraceMarker).apply_dawn_decay(retain)


static func find_in_tree(tree: SceneTree) -> TraceService:
	if tree == null:
		return null
	var n := tree.get_first_node_in_group("trace_service")
	return n as TraceService


static func spawn_at(tree: SceneTree, pos: Vector3, intensity: float, kind: StringName = &"construction") -> TraceMarker:
	var svc := find_in_tree(tree)
	var parent: Node = svc if svc else tree.get_first_node_in_group("zoo_world")
	if parent == null:
		parent = tree.current_scene
	var marker := TraceMarker.new()
	marker.name = "Trace_%d" % Time.get_ticks_msec()
	marker.intensity = intensity
	marker.kind = kind
	parent.add_child(marker)
	marker.global_position = Vector3(pos.x, 0.05, pos.z)
	return marker


## Staff helper: settle nearest unsettled trace in range. Returns the marker if settled now.
static func try_discover_near(tree: SceneTree, origin: Vector3, range_m: float = DISCOVER_RANGE) -> TraceMarker:
	var best: TraceMarker = null
	var best_d := range_m
	for n in tree.get_nodes_in_group("traces"):
		if not (n is TraceMarker):
			continue
		var tr := n as TraceMarker
		if tr.settled:
			continue
		var d := origin.distance_to(tr.global_position)
		if d <= best_d:
			best_d = d
			best = tr
	if best and best.try_settle_alert(1):
		return best
	return null
