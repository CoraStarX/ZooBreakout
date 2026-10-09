extends Node
## 潜行偷取：职员工具车（金属）+ 巡逻点停步。
## godot --headless --path . res://prototypes/p2_cart.tscn

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Cart ===")
	Game.debug_enabled = false
	Game.selected_starter_id = &"raccoon"
	RunLifecycle.reset()
	Clock.auto_advance = false
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var geo: ZooP0Geometry = world.get_node("Geometry")
	var staff: StaffActor = world.call("get_staff")
	var cart := geo.staff_cart
	var actor: AnimalActor = world.get("party").controlled()
	actor.inventory.clear()
	_check(cart != null and cart.staff == staff, "工具车跟随职员")

	## Dwell: staff stands still for STAFF_DWELL_SEC at a stop.
	staff.global_position = staff.waypoints[1] + Vector3(0.1, 0, 0)
	staff._wp_index = 1
	Clock.set_phase(Clock.Phase.OPEN)
	var p0 := staff.global_position
	for _i in 8:
		await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout
	var still := staff.velocity.length() < 0.05
	_check(still and staff._dwell_left > 0.0, "到达巡逻点后停步 (%.1fs)" % staff._dwell_left)

	## Cart sits behind the staff.
	staff.set_physics_process(false)
	staff.global_position = Vector3(3.0, 0.05, 7.0)
	for _i in 40:
		await get_tree().physics_frame
	var behind := cart.global_position.z < staff.global_position.z - 1.0
	_check(behind, "车在职员身后 %.1fm" % staff.global_position.distance_to(cart.global_position))

	## Steal from behind.
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	await get_tree().create_timer(GameConst.STEAL_SEC + 0.6).timeout
	_check(actor.item_count(KitIds.METAL) == 1 and cart.loot_left == 0, "从背后偷到金属 ×1")
	cart.try_use(actor)
	await get_tree().process_frame
	_check(actor.item_count(KitIds.METAL) == 1, "偷空后不能再偷")

	## Dawn restocks.
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	Clock.advance()
	_check(cart.loot_left == GameConst.CART_LOOT_PER_DAY, "天亮补货")

	## Interrupted: staff turns on you.
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	await get_tree().create_timer(0.4).timeout
	staff.state = StaffActor.State.CHASE
	await get_tree().create_timer(0.3).timeout
	_check(cart.loot_left == 1 and actor.item_count(KitIds.METAL) == 1, "职员察觉 → 偷取失败不得手")
	staff.state = StaffActor.State.PATROL

	## Interrupted: wandering off.
	cart.try_use(actor)
	await get_tree().create_timer(0.3).timeout
	actor.global_position += Vector3(0, 0, -5)
	await get_tree().create_timer(0.3).timeout
	_check(cart.loot_left == 1 and not cart._busy, "离开范围偷取中断")

	## Night: cart packed away.
	Clock.set_phase(Clock.Phase.NIGHT_PATROL)
	for _i in 3:
		await get_tree().physics_frame
	_check(not cart.visible, "夜里车收走")
	actor.global_position = cart.global_position + Vector3(0, 0, -0.6)
	cart.try_use(actor)
	await get_tree().process_frame
	_check(cart.loot_left == 1, "夜里不能偷")

	print("")
	print("=== P2 CART SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
