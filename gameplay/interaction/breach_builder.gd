class_name BreachBuilder
extends RefCounted
## Builds the world-side result of a night breach (dig tunnel / climb ledge). Pure scene construction.


static func dig_hole(blocker: Node3D, user: AnimalActor) -> void:
	## West fence is thin on X / long on Z — leave Z-side remnants and a through-gap
	## whose collision-free band matches the dark tunnel mesh (verb-readable).
	var origin := blocker.global_position
	var parent := blocker.get_parent()
	if blocker is CollisionObject3D:
		(blocker as CollisionObject3D).collision_layer = 0
	blocker.visible = false
	## Remnant posts north/south of the dig gap (Z axis).
	for side in [-1.35, 1.35]:
		var stump := StaticBody3D.new()
		stump.collision_layer = 1
		stump.position = origin + Vector3(0, 0.75, side)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.4, 1.5, 0.8)
		col.shape = shape
		stump.add_child(col)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.4, 1.5, 0.8)
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.45, 0.48)
		mi.material_override = mat
		stump.add_child(mi)
		parent.add_child(stump)
	## Through-wall tunnel visual (aligned with walkable gap |z| < ~0.95).
	var tunnel := MeshInstance3D.new()
	var tmesh := BoxMesh.new()
	tmesh.size = Vector3(0.55, 1.1, 1.7)
	tunnel.mesh = tmesh
	tunnel.position = origin + Vector3(0, 0.55, 0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.06, 0.04, 0.03)
	tmat.emission_enabled = true
	tmat.emission = Color(0.08, 0.04, 0.02)
	tmat.emission_energy_multiplier = 0.25
	tunnel.material_override = tmat
	parent.add_child(tunnel)
	## East-face rim so the hole reads as a cut in the wall, not a floor decal.
	var rim := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(0.08, 1.15, 1.85)
	rim.mesh = rmesh
	rim.position = origin + Vector3(0.28, 0.55, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.22, 0.18, 0.14)
	rim.material_override = rmat
	parent.add_child(rim)
	## Stand just inside the opened outer wall (east of west wall) — walk west into ExitWest.
	if user and is_instance_valid(user):
		user.global_position = origin + Vector3(0.75, 0.05, 0)
		user.velocity = Vector3.ZERO
	Bus.interact_feedback.emit("挖通西侧外墙缺口 — 再往西进蓝区出口！")
	blocker.queue_free()


static func climb_ledge(blocker: Node3D, user: AnimalActor, tree: SceneTree) -> void:
	## Open south climb gap + low pads. Soft climb shows a brief vault over the wall.
	var origin := blocker.global_position
	var parent := blocker.get_parent()
	if blocker is CollisionObject3D:
		(blocker as CollisionObject3D).collision_layer = 0
	blocker.visible = false
	var approach := StaticBody3D.new()
	approach.collision_layer = 1
	approach.position = origin + Vector3(0, 0.12, 0.7)
	var acol := CollisionShape3D.new()
	var ashape := BoxShape3D.new()
	ashape.size = Vector3(2.4, 0.24, 0.9)
	acol.shape = ashape
	approach.add_child(acol)
	var ami := MeshInstance3D.new()
	var amesh := BoxMesh.new()
	amesh.size = Vector3(2.4, 0.24, 0.9)
	ami.mesh = amesh
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.48, 0.52, 0.36)
	ami.material_override = amat
	approach.add_child(ami)
	parent.add_child(approach)
	var ledge := StaticBody3D.new()
	ledge.collision_layer = 1
	ledge.position = origin + Vector3(0, 0.55, 0.0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 0.28, 1.0)
	col.shape = shape
	ledge.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.8, 0.28, 1.0)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.55, 0.32)
	mi.material_override = mat
	ledge.add_child(mi)
	parent.add_child(ledge)
	var land := StaticBody3D.new()
	land.collision_layer = 1
	land.position = origin + Vector3(0, 0.12, -0.7)
	var lcol := CollisionShape3D.new()
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(2.6, 0.24, 0.7)
	lcol.shape = lshape
	land.add_child(lcol)
	var lmi := MeshInstance3D.new()
	var lmesh := BoxMesh.new()
	lmesh.size = Vector3(2.6, 0.24, 0.7)
	lmi.mesh = lmesh
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.42, 0.5, 0.34)
	lmi.material_override = lmat
	land.add_child(lmi)
	parent.add_child(land)
	var world := tree.get_first_node_in_group("zoo_world")
	if world and world.has_method("open_climb_exit_route"):
		world.call("open_climb_exit_route")
	## Just south of outer wall, north of ExitSouth pad (never land in blue win zone).
	var land_pos := origin + Vector3(0, 0.05, -0.65)
	if user and is_instance_valid(user):
		if user.has_capability(CapabilityIds.Id.CLIMB):
			## Readable vault: crest the outer wall, then drop outside the zoo.
			user.global_position = origin + Vector3(0, 1.15, 0.0)
			user.velocity = Vector3.ZERO
			Bus.interact_feedback.emit("翻过园墙…")
			await tree.create_timer(0.28).timeout
			if is_instance_valid(user):
				user.global_position = land_pos
				user.velocity = Vector3.ZERO
			Bus.interact_feedback.emit("翻出南侧外墙 — 已落到园外走廊，再往南进蓝区出口")
		else:
			user.global_position = land_pos
			user.velocity = Vector3.ZERO
			Bus.interact_feedback.emit("硬闯翻出园墙 — 已落到园外走廊，再往南进蓝区出口")
	blocker.queue_free()
