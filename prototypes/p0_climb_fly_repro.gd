extends Node
## Repro: after monkey climb, can Y keep rising unboundedly?
## godot --headless --path . res://prototypes/p0_climb_fly_repro.tscn

var _world: Node3D
var _party: PartyController


func _ready() -> void:
	print("=== Climb fly repro ===")
	Game.selected_starter_id = &"raccoon"
	Game.debug_enabled = false
	Clock.auto_advance = false
	Clock.set_phase(Clock.Phase.NIGHT_QUIET)
	_world = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_party = _world.get("party") as PartyController
	_party.rescue(&"monkey")
	await get_tree().process_frame
	_party.switch_next()
	await get_tree().process_frame
	var monkey := _party.controlled()
	if monkey == null or monkey.def.id != &"monkey":
		print("FAIL setup: not monkey")
		get_tree().quit(1)
		return
	var climb := _find("攀爬")
	if climb == null:
		print("FAIL setup: no climb")
		get_tree().quit(1)
		return
	monkey.global_position = climb.global_position + Vector3(0, 0, 1.1)
	monkey.velocity = Vector3.ZERO
	monkey._facing = Vector3(0, 0, -1)
	await RouteHelper.finish(get_tree(), climb, monkey)
	var t := 0.0
	while climb._busy and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		## Do not force-hold position: Soft climb teleports south outside on complete.
	await get_tree().physics_frame
	var y0 := monkey.global_position.y
	print("NOTE post-climb y=%.3f pos=%s" % [y0, monkey.global_position])
	if monkey.global_position.z >= climb.global_position.z:
		print("FINDING P1: [攀爬落点] Soft 完成后仍在门北/园内 z=%.2f（应更南）" % monkey.global_position.z)

	## Simulate holding W (camera-forward) for ~4s via direct velocity like controlled move
	var cam := get_viewport().get_camera_3d()
	var forward := Vector3(0, 0, -1)
	if cam:
		forward = -cam.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
	var max_y := y0
	var min_y := y0
	for _i in 240:
		await get_tree().physics_frame
		## Mimic _process_controlled + move_and_slide already in actor:
		## inject facing/input by setting velocity the same way, but actor reads Input.
		## So drive by temporarily writing velocity in a hook: use set_deferred pattern —
		## Force movement by placing desired velocity then calling move path:
		monkey.velocity = forward * monkey.def.move_speed
		monkey.velocity.y = 0.0
		## Actor also runs _physics_process same frame — order matters.
		## Safer: directly step along camera forward each frame after physics:
		pass
	## Better approach: manually walk along slope by moving into ramp/ledge repeatedly
	## Reset and walk in world +Z / -Z / +X for separate trials
	await _trial_walk(monkey, Vector3(0, 0, -1), "world-Z", y0)
	await _trial_walk(monkey, Vector3(0, 0, 1), "world+Z", y0)
	await _trial_walk(monkey, Vector3(1, 0, 0), "world+X", y0)
	await _trial_walk(monkey, Vector3(-1, 0, 0), "world-X", y0)
	await _trial_ramp_uphill(monkey)
	## Float check in open yard (away from climb platforms).
	monkey.global_position = Vector3(0, 3.0, 4)
	monkey.velocity = Vector3.ZERO
	monkey.set_physics_process(true)
	for _i in 90:
		await get_tree().physics_frame
	var y_air := monkey.global_position.y
	if y_air > 1.2:
		print("FINDING P0: [物理] 离地后无重力，悬空 y=%.2f（velocity.y 恒 0 且无下落）" % y_air)
	else:
		print("OK float check y=%.2f" % y_air)
	print("=== END ===")
	get_tree().quit(0)


func _trial_ramp_uphill(actor: AnimalActor) -> void:
	## Start at foot of generated ramp (blocker origin ≈ climb gate) and walk uphill repeatedly.
	var climb := _find("攀爬")
	var origin := climb.global_position ## interact approx; ramp built from blocker at gate
	## Gate wall at (-4.5, -10); steps approach from -Z (inside).
	var foot := Vector3(-4.5, 0.2, -11.2)
	actor.global_position = foot
	actor.velocity = Vector3.ZERO
	actor.set_physics_process(false)
	await get_tree().physics_frame
	var y_start := actor.global_position.y
	var y_peak := y_start
	## Uphill roughly +Z toward ledge (ramp approaches from -Z)
	for _i in 300:
		actor.velocity = Vector3(0, 0, 1) * 5.5
		actor.velocity.y = 0.0
		actor.move_and_slide()
		y_peak = maxf(y_peak, actor.global_position.y)
		await get_tree().physics_frame
	## Second pass: keep walking +Z from atop
	for _i in 300:
		actor.velocity = Vector3(0, 0, 1) * 5.5
		actor.velocity.y = 0.0
		actor.move_and_slide()
		y_peak = maxf(y_peak, actor.global_position.y)
		await get_tree().physics_frame
	actor.set_physics_process(true)
	print("NOTE ramp-uphill y_start=%.2f y_peak=%.2f gained=%.2f final=%s"
		% [y_start, y_peak, y_peak - y_start, actor.global_position])
	if y_peak >= 5.0 or (y_peak - y_start) >= 3.0:
		print("FINDING P0: [攀爬/物理] 沿坡道可持续上行至 y=%.2f（截图像天飞）" % y_peak)
	## Third: walk along ramp local uphill forever from mid-ramp using floor normal
	actor.global_position = Vector3(-4.5, 0.5, -10.6)
	actor.set_physics_process(false)
	y_start = actor.global_position.y
	y_peak = y_start
	for _i in 400:
		var vel := Vector3(0, 0, -1) * 5.5
		vel.y = 0.0
		actor.velocity = vel
		actor.move_and_slide()
		## If on floor, also try sliding with a bit of upward intent like steep climb
		if actor.is_on_floor():
			var n := actor.get_floor_normal()
			## move along slope uphill
			var along := Vector3(0, 0, -1).slide(n).normalized() * 5.5
			actor.velocity = along
			actor.move_and_slide()
		y_peak = maxf(y_peak, actor.global_position.y)
		await get_tree().physics_frame
	actor.set_physics_process(true)
	print("NOTE slope-slide y_peak=%.2f gained=%.2f final=%s" % [y_peak, y_peak - y_start, actor.global_position])
	if y_peak >= 5.0:
		print("FINDING P0: [攀爬/物理] 贴坡 slide 可持续爬升至 y=%.2f" % y_peak)


func _trial_walk(actor: AnimalActor, dir: Vector3, label: String, y_ref: float) -> void:
	var climb := _find("攀爬")
	actor.global_position = climb.global_position + Vector3(0, 1.05, 0.25)
	actor.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var y_start := actor.global_position.y
	var y_peak := y_start
	## Take over physics to simulate sustained WASD on post-climb geometry.
	actor.set_physics_process(false)
	for _i in 180:
		actor.velocity = dir.normalized() * 5.5
		actor.velocity.y = 0.0
		actor.move_and_slide()
		y_peak = maxf(y_peak, actor.global_position.y)
		await get_tree().physics_frame
	actor.set_physics_process(true)
	var gained := y_peak - y_start
	print("NOTE trial %s y_start=%.2f y_peak=%.2f gained=%.2f final=%s"
		% [label, y_start, y_peak, gained, actor.global_position])
	if gained >= 3.0:
		print("FINDING P0: [攀爬/物理] 攀爬后沿 %s 可持续爬升 Δy=%.2f（可飞出地图）" % [label, gained])
	elif y_peak > 8.0:
		print("FINDING P0: [攀爬/物理] 攀爬后高度异常 y_peak=%.2f（%s）" % [y_peak, label])
	elif gained >= 1.5:
		print("FINDING P1: [攀爬/物理] 攀爬后沿 %s 异常抬升 Δy=%.2f" % [label, gained])
	else:
		print("OK trial %s modest gain %.2f" % [label, gained])


func _find(substr: String) -> Interactable:
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Interactable and (n as Interactable).display_name.contains(substr):
			return n as Interactable
		for c in n.get_children():
			stack.append(c)
	return null
