class_name GatherPoint
extends Area3D
## Daytime resource node: yields one raw material (rope / wood / metal). Restocks every dawn.
## With the required verb the rich stash is taken fast; without it you scrape out a smaller haul, slowly.

const _KitIds := preload("res://content/kit_ids.gd")

@export var display_name: String = "搜集点"
@export var material: StringName = KitIds.WOOD
@export var required: CapabilityIds.Id = CapabilityIds.Id.NONE
@export var yield_rich: int = 1
@export var yield_poor: int = 1
@export var hint: String = ""
@export var use_range: float = 1.85

var stocked: bool = true
var _busy: bool = false
var _crate: MeshInstance3D
var _label: ProximityLabel
var _progress: Label3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.05
	shape.shape = sphere
	add_child(shape)
	_crate = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.38
	mesh.height = 0.45
	_crate.mesh = mesh
	_crate.position = Vector3(0, 0.25, 0)
	add_child(_crate)
	_label = ProximityLabel.new()
	_label.position = Vector3(0, 1.0, 0)
	add_child(_label)
	_progress = Label3D.new()
	ProximityLabel.style(_progress, 26)
	_progress.position = Vector3(0, 0.7, 0)
	_progress.modulate = Color(0.7, 1.0, 0.75)
	_progress.visible = false
	add_child(_progress)
	Bus.day_changed.connect(_on_day_changed)
	_refresh()


func restock() -> void:
	stocked = true
	_refresh()


func _on_day_changed(_day: int) -> void:
	restock()


func _refresh() -> void:
	var mat := StandardMaterial3D.new()
	if stocked:
		mat.albedo_color = Color(0.3, 0.7, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.55, 0.75)
		mat.emission_energy_multiplier = 0.7
		_label.modulate = Color(0.7, 0.92, 1.0)
		var line := "%s\n[%s ×%d" % [display_name, _KitIds.display_name(material), yield_rich]
		if required != CapabilityIds.Id.NONE:
			line = "%s\n[%s·%s · %s ×%d / 无则 ×%d 且慢" % [
				display_name, _KitIds.display_name(material), hint, CapabilityIds.to_label(required), yield_rich, yield_poor
			]
		_label.set_info(line + " · E]")
	else:
		mat.albedo_color = Color(0.25, 0.25, 0.28)
		_label.modulate = Color(0.5, 0.5, 0.5)
		_label.set_info("%s\n[已搜空 · 明早补货]" % display_name)
	_crate.material_override = mat


func try_use(user: AnimalActor) -> void:
	if _busy or user == null:
		return
	if not stocked:
		Bus.interact_feedback.emit("%s 已搜空 — 明天天亮补货" % display_name)
		return
	if Clock.allows_escape_actions():
		Bus.interact_feedback.emit("夜里看不清 — 搜集请等白天（夜间专心施工）")
		return
	var rich := required == CapabilityIds.Id.NONE or user.has_capability(required)
	var amount := yield_rich if rich else yield_poor
	var wait := GameConst.GATHER_SEC if rich else GameConst.GATHER_POOR_SEC
	_busy = true
	_progress.visible = true
	if rich:
		Bus.interact_feedback.emit("搜集 %s…" % display_name)
	else:
		Bus.interact_feedback.emit("缺%s，只能慢慢扒拉 %s…" % [CapabilityIds.to_label(required), display_name])
	var elapsed := 0.0
	while elapsed < wait:
		await get_tree().process_frame
		if not is_instance_valid(user):
			_abort("搜集中断")
			return
		if user.global_position.distance_to(global_position) > use_range:
			_abort("离开范围，搜集取消")
			return
		elapsed += get_process_delta_time()
		_progress.text = "搜集 %d%%" % int(clampf(elapsed / wait, 0.0, 1.0) * 100.0)
	_progress.visible = false
	stocked = false
	_busy = false
	var parts: Array[StringName] = []
	for _i in amount:
		parts.append(material)
	user.give_items(parts)
	_refresh()
	Bus.material_gathered.emit(material, amount)
	var rich_note := "" if rich else "（没有%s，只拿到一部分）" % CapabilityIds.to_label(required)
	Bus.interact_feedback.emit("获得 %s ×%d%s — 背包共 %d" % [_KitIds.display_name(material), amount, rich_note, user.item_count(material)])


func _abort(msg: String) -> void:
	_busy = false
	_progress.visible = false
	Bus.interact_feedback.emit(msg)
