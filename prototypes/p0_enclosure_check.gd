extends Node
## Starter enclosure leak check (no forced teleports through walls).
## godot --headless --path . res://prototypes/p0_enclosure_check.tscn

func _ready() -> void:
	print("=== Enclosure check ===")
	await _check_starter(&"raccoon")
	await _check_starter(&"monkey")
	print("=== END ===")
	get_tree().quit(0)


func _check_starter(starter: StringName) -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	Game.selected_starter_id = starter
	Clock.auto_advance = false
	Clock.set_phase(Clock.Phase.OPEN)
	var world: Node3D = (load("res://scenes/world/zoo_p0.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var party: PartyController = world.get("party")
	var actor: AnimalActor = party.controlled()
	var door: Interactable = world.call("door_for_animal", actor)
	var home := actor.global_position
	## Probe several directions with move_and_slide only (no global_position teleports).
	var goals: Array[Vector3] = [
		Vector3(0, 0.05, 2),
		Vector3(2, 0.05, 1),
		Vector3(-2, 0.05, 2),
		Vector3(0, 0.05, -12),
	]
	var escaped_without_door := false
	var hit_wall := false
	for goal in goals:
		actor.global_position = home
		actor.velocity = Vector3.ZERO
		await get_tree().physics_frame
		for _i in 90:
			var to := goal - actor.global_position
			to.y = 0.0
			if to.length() < 0.45:
				break
			actor.velocity.x = to.normalized().x * 6.0
			actor.velocity.z = to.normalized().z * 6.0
			actor.move_and_slide()
			if actor.is_on_wall():
				hit_wall = true
			await get_tree().physics_frame
		var outside := actor.global_position.distance_to(Vector3(0, 0.05, 2)) < 3.5
		if outside and not door._done:
			escaped_without_door = true
			break
	print("NOTE starter=%s door_done=%s end=%s hit_wall=%s" % [
		starter, door._done, actor.global_position, hit_wall
	])
	if escaped_without_door:
		print("FINDING P0: [关卡] %s 开局可不破笼门进入中庭（围栏未闭合）" % starter)
	else:
		print("OK starter=%s 绕行未能无破门进中庭" % starter)
	world.queue_free()
	await get_tree().process_frame
