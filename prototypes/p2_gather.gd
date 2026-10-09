extends Node
## 昼夜 M3：白天原料点（三种原料、动词门槛、补货、风险分布）。
## godot --headless --path . res://prototypes/p2_gather.tscn

const Gather := preload("res://content/levels/zoo_p0_gather.gd")

var _pass_n := 0
var _fail_n := 0
var _world: Node3D
var _geo: ZooP0Geometry
var _party: PartyController
var _session: RunSession


func _ready() -> void:
	print("=== P2 Gather ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_geo = _world.get_node("Geometry") as ZooP0Geometry
	_party = _world.get("party")
	_session = _world.get("session")
	var actor := _party.controlled()
	actor.inventory.clear()

	_check(_geo.gather_points.size() == Gather.POINTS.size(), "关卡生成 %d 个搜集点" % _geo.gather_points.size())
	_check_points_not_in_walls()
	_check_day_budget()

	var rich := _find_point(CapabilityIds.Id.DEXTERITY, 2)   ## 饲料柜 (raccoon has DEXTERITY)
	var climb := _find_point(CapabilityIds.Id.CLIMB, 2)      ## 高处树杈 (raccoon lacks CLIMB)
	_check(rich != null and climb != null, "找到动词点")

	## Rich: raccoon has verb → full haul.
	await _use(actor, rich)
	_check(actor.item_count(KitIds.WOOD) == 2, "有动词拿满 2 木料（实际 %d）" % actor.item_count(KitIds.WOOD))
	_check(not rich.stocked, "搜空后标记空")
	var before := actor.item_count(KitIds.WOOD)
	await _use(actor, rich)
	_check(actor.item_count(KitIds.WOOD) == before, "已搜空不能重复拿")

	## Poor: no verb → smaller haul, slower (measure frames of busy).
	var t0 := Time.get_ticks_msec()
	await _use(actor, climb)
	var poor_ms := Time.get_ticks_msec() - t0
	_check(actor.item_count(KitIds.WOOD) == before + 1, "无动词只拿 1 木料（实际 %d）" % (actor.item_count(KitIds.WOOD) - before))
	_check(poor_ms >= int(GameConst.GATHER_POOR_SEC * 1000.0 * 0.8), "无动词更慢 %dms" % poor_ms)

	## Restock at dawn.
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(rich.stocked and climb.stocked, "天亮补货")

	## Night blocks gathering.
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	var n0 := actor.item_count(KitIds.WOOD)
	await _use(actor, rich)
	_check(actor.item_count(KitIds.WOOD) == n0 and rich.stocked, "夜间不能搜集")
	Clock.set_phase(Clock.Phase.OPEN)

	## Day: route points refuse construction (night only), parts untouched.
	actor.inventory.clear()
	actor.give_items([KitIds.WOOD, KitIds.WOOD])
	var dig := _geo.dig_interactable
	actor.global_position = dig.global_position + Vector3(0.9, 0, 0)
	dig.try_use(actor)
	await get_tree().process_frame
	_check(dig.tier_done == 0 and actor.item_count(KitIds.WOOD) == 2, "白天不能在外墙施工")

	## Capture confiscates parts, chest returns them.
	actor.give_items([KitIds.WOOD, KitIds.WOOD])
	CaptureFlow.apply_capture(actor)
	_check(actor.item_count(KitIds.WOOD) == 0 and OfficeStorage.items.count(KitIds.WOOD) == 4, "被抓木料进办公室")

	print("")
	print("=== P2 GATHER SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _find_point(cap: CapabilityIds.Id, rich: int) -> GatherPoint:
	for g in _geo.gather_points:
		if g.required == cap and g.yield_rich == rich:
			return g
	return null


func _use(actor: AnimalActor, g: GatherPoint) -> void:
	actor.is_confined = false
	actor.global_position = g.global_position + Vector3(0.6, 0.05, 0)
	actor.velocity = Vector3.ZERO
	g.try_use(actor)
	var t := 0.0
	while g._busy and t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame


func _wait_idle(it: Interactable) -> void:
	var t := 0.0
	await get_tree().process_frame
	while it._busy and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame


func _check_points_not_in_walls() -> void:
	var space := _world.get_world_3d().direct_space_state
	var bad := PackedStringArray()
	for g in _geo.gather_points:
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.5
		q.shape = s
		q.transform = Transform3D(Basis(), g.global_position + Vector3(0, 0.6, 0))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			bad.append(g.display_name)
	_check(bad.is_empty(), "搜集点不嵌墙 %s" % ",".join(bad))


func _check_day_budget() -> void:
	## Per starter verb set: what one day's safe points (no staff-adjacent point) can supply.
	var routes := {
		"挖洞(木+金属)": [KitIds.WOOD, KitIds.METAL],
		"攀爬(绳+金属)": [KitIds.ROPE, KitIds.METAL],
	}
	for verbs in [[1], [2]]:
		var supply := {}
		var risky_metal := 0
		for d in Gather.POINTS:
			var amount: int = d["rich"] if (d["cap"] == 0 or verbs.has(d["cap"])) else d["poor"]
			if d["rich"] >= 3:
				risky_metal += amount
				continue ## the staff-side stash is the risky one
			supply[d["mat"]] = int(supply.get(d["mat"], 0)) + amount
		## Metal from safe points alone must NOT cover a whole route (forces risk: shed or cart).
		var safe_metal := int(supply.get(&"metal", 0))
		_check(safe_metal < GameConst.ROUTE_TIERS, "动词%s 安全点金属 %d < 一条路线需 %d（必须冒险/偷）" % [verbs, safe_metal, GameConst.ROUTE_TIERS])
		_check(safe_metal + risky_metal + GameConst.CART_LOOT_PER_DAY >= GameConst.ROUTE_TIERS, "动词%s 含冒险点+工具车金属够一条路线" % [verbs])
		## Every recipe material has a safe source.
		for name in routes:
			for m in routes[name]:
				_check(m == &"metal" or int(supply.get(m, 0)) >= 1, "动词%s %s 的 %s 有安全来源" % [verbs, name, KitIds.display_name(m)])


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
