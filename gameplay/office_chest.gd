class_name OfficeChest
extends Interactable
## Steal confiscated items back from the office. Same rules as every Interactable:
## Soft with a lockpick or climb; otherwise Hard (RouteWorkParams time/noise multipliers, leaves a trace),
## the noise only reaches staff through their own hearing, and any capture goes through the staff chase.


func _init() -> void:
	display_name = "办公室储物柜（取回没收物品）"
	required = CapabilityIds.Id.DEXTERITY
	also_accepts = [CapabilityIds.Id.CLIMB]
	one_shot = false
	opens_path = false
	requires_night = false
	## The chest sits inside the solid 3×3 office block: you work it from the wall, ~2 m from its centre.
	use_range = 2.4


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	shape.shape = sphere
	add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.5, 0.6)
	mi.mesh = mesh
	mi.position = Vector3(0, 0.25, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.55, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	add_child(mi)
	super._ready()


func try_use(user: AnimalActor) -> void:
	if user == null or _busy:
		return
	if not OfficeStorage.has_items():
		Bus.interact_feedback.emit("办公室储物柜是空的")
		return
	if user.inventory_free_slots() <= 0:
		Bus.interact_feedback.emit("背包满了 — 先放下东西再来取")
		return
	super.try_use(user)


func cost_preview(user: AnimalActor) -> String:
	if not OfficeStorage.has_items():
		return "E %s：空的" % display_name
	return super.cost_preview(user)


func _complete(soft: bool, user: AnimalActor) -> void:
	var got := OfficeStorage.take(user.inventory_free_slots())
	user.give_items(got)
	used.emit(true, soft)
	var names := PackedStringArray()
	for id in got:
		names.append(KitIds.display_name(id))
	var left := "（柜里还剩 %d 件，背包满了下次再来）" % OfficeStorage.items.size() if OfficeStorage.has_items() else ""
	Bus.interact_feedback.emit("夺回：%s%s" % ["、".join(names), left])
