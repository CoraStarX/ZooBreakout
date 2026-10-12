class_name GroundItem
extends Area3D
## One dropped inventory item lying on the ground. E picks it back up. Stays across days until taken.

const GROUP := &"ground_items"

var item_id: StringName = &""
var _label: ProximityLabel


static func spawn(parent: Node, id: StringName, pos: Vector3) -> GroundItem:
	var g := GroundItem.new()
	g.item_id = id
	g.name = "Ground_%s" % String(id)
	parent.add_child(g)
	g.global_position = pos
	return g


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.22, 0.35)
	mi.mesh = mesh
	mi.position = Vector3(0, 0.11, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.35) if KitIds.is_heavy(item_id) else Color(0.6, 0.6, 0.55)
	mi.material_override = mat
	add_child(mi)
	_label = ProximityLabel.new()
	_label.position = Vector3(0, 0.7, 0)
	_label.set_info("%s\n[E 拾取]" % KitIds.display_name(item_id))
	add_child(_label)


func try_use(user: AnimalActor) -> void:
	if user == null or not is_instance_valid(self):
		return
	if user.inventory_free_slots() <= 0:
		Bus.interact_feedback.emit("背包满了（%d/%d）— 拿不起%s" % [
			user.inventory.size(), user.inventory_capacity(), KitIds.display_name(item_id)
		])
		return
	user.give_items([item_id])
	Bus.interact_feedback.emit("捡起 %s — 背包 %d/%d" % [
		KitIds.display_name(item_id), user.inventory.size(), user.inventory_capacity()
	])
	remove_from_group(GROUP)
	collision_layer = 0
	queue_free()
