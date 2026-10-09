class_name ZooP0Geometry
extends Node3D
## Content: greybox walls, interactables, staff patrol, office danger, dual exit routes.

## animal def id -> home cage Interactable
var cage_doors: Dictionary = {}
var staff: StaffActor
var danger_approach: Area3D
var danger_zone: Area3D

const Intel := preload("res://content/levels/zoo_p0_intel.gd")
const Gather := preload("res://content/levels/zoo_p0_gather.gd")
const KitPickupScript := preload("res://content/interactables/kit_pickup.gd")

var gather_points: Array[GatherPoint] = []
var observe_points: Array[ObservePoint] = []
var staff_cart: StaffCart
var dig_interactable: Interactable
var climb_interactable: Interactable
var dig_kit_pickup: Area3D
var climb_kit_pickup: Area3D
var west_outer_gate: StaticBody3D
var south_outer_gate: StaticBody3D
var exit_west: Area3D
var exit_south: Area3D
var exit_west_label: ProximityLabel
var exit_south_label: ProximityLabel


func _ready() -> void:
	_build_level()


func _build_level() -> void:
	_add_ground()
	## Outer ring with dig/climb gates (not solid full walls).
	_wall(Vector3(0, 0.75, 12), Vector3(24, 1.5, 0.5)) # north outer
	_wall(Vector3(12, 0.75, 0), Vector3(0.5, 1.5, 24)) # east outer
	# West outer split — dig interactable IS the outer gate (P2-M0: no distant silent open).
	_wall(Vector3(-12, 0.75, -6.75), Vector3(0.5, 1.5, 10.5))
	_wall(Vector3(-12, 0.75, 7.5), Vector3(0.5, 1.5, 9.0))
	west_outer_gate = _wall(Vector3(-12, 0.75, 1.5), Vector3(0.5, 1.5, 3.2), Color(0.45, 0.48, 0.52))
	west_outer_gate.name = "WestOuterGate"
	# South outer split — climb interactable IS the outer gate.
	_wall(Vector3(-9.5, 0.75, -12), Vector3(5.0, 1.5, 0.5))
	_wall(Vector3(4.0, 0.75, -12), Vector3(16.0, 1.5, 0.5))
	south_outer_gate = _wall(Vector3(-4.5, 0.75, -12), Vector3(3.2, 1.5, 0.5), Color(0.35, 0.5, 0.32))
	south_outer_gate.name = "SouthOuterGate"

	# Raccoon yard — door on north wall, well west of the east wall so a 0.9 body clears.
	# Door x∈[-3.5, -1.5] at z=-2 (width 2.0).
	_wall(Vector3(-5.75, 0.75, -2), Vector3(4.5, 1.5, 0.4)) # north-west: x -8.0 → -3.5
	_wall(Vector3(-8, 0.75, -6), Vector3(0.4, 1.5, 8)) # west
	_wall(Vector3(0, 0.75, -6.0), Vector3(0.4, 1.5, 8.0)) # east: z -10 → -2 (meets north-east)
	_wall(Vector3(-7.35, 0.75, -10), Vector3(1.7, 1.5, 0.4)) # south-west seal
	_wall(Vector3(-1.15, 0.75, -10), Vector3(2.3, 1.5, 0.4)) # south-east seal
	var lock_blocker := _wall(Vector3(-2.5, 0.75, -2), Vector3(2.0, 1.5, 0.4), Color(0.45, 0.35, 0.2))
	lock_blocker.name = "LockDoor"
	var raccoon_door := _make_interactable(
		Vector3(-2.5, 0.5, -1.2), "笼门锁", CapabilityIds.Id.DEXTERITY, lock_blocker,
		0.0, true, true, Interactable.BreachStyle.DESTROY, Vector3(0, 0, 1.2)
	)
	cage_doors[&"raccoon"] = raccoon_door
	_wall(Vector3(-0.5, 0.75, -2), Vector3(2.0, 1.5, 0.4)) # north-east: x -1.5 → 0.5 (covers east corner)
	## Yard south fully sealed — Soft climb is the zoo's south OUTER wall (exit exhibit via cage door).
	_wall(Vector3(-4.5, 0.75, -10), Vector3(3.2, 1.5, 0.4))
	## Dig = west outer wall. Corridor from courtyard to the wall is open after exhibit escape.
	dig_interactable = _make_interactable(
		Vector3(-11.2, 0.5, 1.5), "外墙挖洞", CapabilityIds.Id.DIG, west_outer_gate,
		0.0, true, false, Interactable.BreachStyle.DIG_HOLE
	)
	dig_interactable.route_kit_id = KitIds.DIG
	dig_interactable.tiers = GameConst.ROUTE_TIERS
	dig_interactable.tier_cost = [KitIds.WOOD, KitIds.METAL]
	dig_interactable._refresh_label()
	## Climb = south outer wall (flip out of the zoo, not an inner yard shortcut).
	climb_interactable = _make_interactable(
		Vector3(-4.5, 0.5, -11.1), "外墙攀爬出园", CapabilityIds.Id.CLIMB, south_outer_gate,
		0.0, true, false, Interactable.BreachStyle.CLIMB_LEDGE
	)
	climb_interactable.route_kit_id = KitIds.CLIMB
	climb_interactable.tiers = GameConst.ROUTE_TIERS
	climb_interactable.tier_cost = [KitIds.ROPE, KitIds.METAL]
	climb_interactable._refresh_label()
	_build_kit_pickups()
	_build_gather_points()
	_build_observe_points()
	# Monkey enclosure — door opens WEST into open yard
	_wall(Vector3(8.4, 0.75, -3.0), Vector3(0.4, 1.5, 4.8)) # east
	_wall(Vector3(6.3, 0.75, -5.2), Vector3(4.4, 1.5, 0.4)) # south
	_wall(Vector3(6.3, 0.75, -0.8), Vector3(4.4, 1.5, 0.4)) # north
	_wall(Vector3(4.2, 0.75, -4.55), Vector3(0.4, 1.5, 1.2)) # west south pillar
	_wall(Vector3(4.2, 0.75, -1.45), Vector3(0.4, 1.5, 1.2)) # west north pillar
	var monkey_door_body := _wall(Vector3(4.2, 0.75, -3.0), Vector3(0.4, 1.5, 1.6), Color(0.6, 0.4, 0.25))
	monkey_door_body.name = "MonkeyDoor"
	var monkey_door := _make_interactable(
		Vector3(3.2, 0.5, -3.0), "猴笼门", CapabilityIds.Id.DEXTERITY, monkey_door_body,
		0.0, true, true, Interactable.BreachStyle.DESTROY, Vector3(-1.2, 0, 0)
	)
	cage_doors[&"monkey"] = monkey_door
	# Staff patrol NE loop
	staff = StaffActor.new()
	staff.name = "Staff"
	add_child(staff)
	var patrol: Array[Vector3] = [
		Vector3(5.5, 0.05, 5.5),
		Vector3(8.5, 0.05, 7.0),
		Vector3(7.0, 0.05, 9.0),
		Vector3(4.0, 0.05, 7.5),
	]
	staff.setup_patrol(patrol)
	staff_cart = StaffCart.new()
	staff_cart.name = "StaffCart"
	staff_cart.staff = staff
	add_child(staff_cart)
	staff_cart.global_position = patrol[0] - Vector3(0, 0, GameConst.CART_TRAIL_DIST)
	_build_office_danger()
	_build_exit_zones()


func _build_kit_pickups() -> void:
	## Inside starting exhibits so Open-hour gather works before night breakouts.
	dig_kit_pickup = KitPickupScript.new() as Area3D
	dig_kit_pickup.name = "DigKitPickup"
	dig_kit_pickup.set("kit_id", &"dig_kit")
	dig_kit_pickup.position = Vector3(-5.5, 0.05, -7.2) # raccoon yard
	add_child(dig_kit_pickup)
	climb_kit_pickup = KitPickupScript.new() as Area3D
	climb_kit_pickup.name = "ClimbKitPickup"
	climb_kit_pickup.set("kit_id", &"climb_kit")
	climb_kit_pickup.position = Vector3(6.0, 0.05, -3.5) # monkey enclosure
	add_child(climb_kit_pickup)


func _build_gather_points() -> void:
	for d in Gather.POINTS:
		var gp := GatherPoint.new()
		gp.name = "Gather_%s" % String(d["name"])
		gp.display_name = d["name"]
		gp.required = d["cap"] as CapabilityIds.Id
		gp.material = d["mat"]
		gp.yield_rich = d["rich"]
		gp.yield_poor = d["poor"]
		gp.hint = d["hint"]
		gp.position = d["pos"]
		add_child(gp)
		gather_points.append(gp)


func _build_observe_points() -> void:
	for d in Intel.POINTS:
		var op := ObservePoint.new()
		op.name = "Observe_%s" % String(d["reward"])
		op.display_name = d["name"]
		op.reward = d["reward"]
		op.position = d["pos"]
		add_child(op)
		observe_points.append(op)


func _build_exit_zones() -> void:
	## Keep a short corridor between outer wall face and pad so dig/climb land ≠ instant WON.
	exit_west = _make_exit_zone(
		"ExitWest",
		Vector3(-14.2, 1.0, 1.5),
		Vector3(2.0, 2.0, 3.2),
		"出园口·挖掘线\n（挖通西外墙后启用）"
	)
	exit_west_label = exit_west.get_node("WorldLabel") as ProximityLabel
	exit_south = _make_exit_zone(
		"ExitSouth",
		Vector3(-4.5, 1.0, -14.4),
		Vector3(3.5, 2.0, 1.6),
		"出园口·攀爬线\n（翻过南外墙后启用）"
	)
	exit_south_label = exit_south.get_node("WorldLabel") as ProximityLabel
	_set_exit_ready_visual(exit_west_label, false)
	_set_exit_ready_visual(exit_south_label, false)


func _make_exit_zone(node_name: String, pos: Vector3, size: Vector3, label_text: String) -> Area3D:
	var zone := Area3D.new()
	zone.name = node_name
	zone.monitoring = true
	zone.monitorable = false
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	var pad := MeshInstance3D.new()
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(size.x, 0.05, size.z)
	pad.mesh = pmesh
	pad.position = Vector3(0, -0.95, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.25, 0.55, 0.85, 0.4)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = pmat
	zone.add_child(pad)
	var label := ProximityLabel.new()
	label.name = "WorldLabel"
	label.position = Vector3(0, 1.2, 0)
	label.set_info(label_text)
	zone.add_child(label)
	add_child(zone)
	return zone


func _set_exit_ready_visual(label: Label3D, ready: bool) -> void:
	if label == null:
		return
	if ready:
		label.modulate = Color(0.45, 1.0, 0.55)
	else:
		label.modulate = Color(0.55, 0.55, 0.55)


func open_west_exit_route() -> void:
	## Dig hole may have already freed WestOuterGate — only update label / disable if alive.
	if is_instance_valid(west_outer_gate):
		_disable_gate(west_outer_gate)
	if exit_west_label:
		exit_west_label.set_info("出园口·挖掘线\n（全队进入）")
		_set_exit_ready_visual(exit_west_label, true)


func open_south_exit_route() -> void:
	if is_instance_valid(south_outer_gate):
		_disable_gate(south_outer_gate)
	if exit_south_label:
		exit_south_label.set_info("出园口·攀爬线\n（全队进入）")
		_set_exit_ready_visual(exit_south_label, true)


func _disable_gate(gate: StaticBody3D) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	gate.collision_layer = 0
	gate.collision_mask = 0
	gate.visible = false


func _build_office_danger() -> void:
	_wall(Vector3(-9, 0.75, 8), Vector3(3, 1.5, 3), Color(0.25, 0.3, 0.45))
	var floor_mark := MeshInstance3D.new()
	floor_mark.name = "DangerFloor"
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(5.2, 0.04, 5.2)
	floor_mark.mesh = fmesh
	floor_mark.position = Vector3(-9, 0.02, 8)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.85, 0.15, 0.1, 0.45)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mark.material_override = fmat
	add_child(floor_mark)
	var warn := Label3D.new()
	warn.text = "危险区 · 办公室"
	warn.position = Vector3(-9, 1.8, 8)
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.font_size = 48
	warn.modulate = Color(1.0, 0.35, 0.25)
	add_child(warn)
	danger_approach = Area3D.new()
	danger_approach.name = "DangerApproach"
	danger_approach.monitoring = true
	danger_approach.monitorable = false
	danger_approach.collision_layer = 0
	danger_approach.collision_mask = 2
	var ashape := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(8.5, 2.5, 8.5)
	ashape.shape = abox
	danger_approach.position = Vector3(-9, 1, 8)
	danger_approach.add_child(ashape)
	add_child(danger_approach)
	danger_zone = Area3D.new()
	danger_zone.name = "DangerZone"
	danger_zone.monitoring = true
	danger_zone.monitorable = false
	danger_zone.collision_layer = 0
	danger_zone.collision_mask = 2
	var ds := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 2, 5)
	ds.shape = box
	danger_zone.position = Vector3(-9, 1, 8)
	danger_zone.add_child(ds)
	add_child(danger_zone)
	var chest := OfficeChest.new()
	chest.name = "OfficeChest"
	chest.position = Vector3(-9, 0.05, 8)
	add_child(chest)


func _add_ground() -> void:
	## Cover outer ExitZones (west ≈-13.2, south ≈-13.2) with margin so players don't void.
	var extent := Vector3(40, 0.2, 40)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = extent
	mi.mesh = mesh
	mi.position = Vector3(0, -0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.42, 0.28)
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	col.shape = shape
	body.position = Vector3(0, -0.1, 0)
	body.collision_layer = 1
	body.add_child(col)
	add_child(body)


func _wall(pos: Vector3, size: Vector3, color: Color = Color(0.55, 0.55, 0.5)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	return body


func _make_interactable(
	pos: Vector3,
	label: String,
	cap: CapabilityIds.Id,
	blocker: Node3D,
	breach_amount: float,
	opens: bool,
	destroy_blocker: bool = false,
	style: Interactable.BreachStyle = Interactable.BreachStyle.DESTROY,
	guard_offset: Vector3 = Vector3(0, 0, 1.2)
) -> Interactable:
	var area := Interactable.new()
	area.position = pos
	area.display_name = label
	area.required = cap
	area.grants_breach = breach_amount
	area.opens_path = opens
	area.destroy_blocker = destroy_blocker
	area.breach_style = style
	area.guard_offset = guard_offset
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.15
	mesh.height = 0.8
	mi.mesh = mesh
	mi.position = Vector3(0, 0.4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.2)
	mi.material_override = mat
	area.add_child(mi)
	add_child(area)
	area.bind_blocker(blocker)
	return area
