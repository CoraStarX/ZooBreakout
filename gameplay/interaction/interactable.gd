class_name Interactable
extends Area3D
## Soft capability check: with verb = quiet/fast; without = loud/slow hard attempt.

enum BreachStyle { DESTROY, DIG_HOLE, CLIMB_LEDGE }

signal used(success: bool, soft: bool)
## Night construction progress on a tiered route point.
signal tier_completed(done: int, total: int)

@export var display_name: String = "交互点"
@export var required: CapabilityIds.Id = CapabilityIds.Id.NONE
@export var soft_seconds: float = -1.0
@export var hard_seconds: float = -1.0
@export var hard_noise: float = 1.0
@export var one_shot: bool = true
@export var grants_breach: float = 0.0
@export var opens_path: bool = false
@export var destroy_blocker: bool = false
@export var breach_style: BreachStyle = BreachStyle.DESTROY
## Escape breaches only at night unless false.
@export var requires_night: bool = true
## Route kit that pays for KIT_TIERS construction tiers at this point. Empty = parts only.
@export var route_kit_id: StringName = &""
## Construction tiers (1 = plain one-shot interaction, e.g. cage doors).
@export var tiers: int = 1
## Raw materials one construction tier consumes (e.g. [wood, metal]). A kit replaces the whole payment.
@export var tier_cost: Array[StringName] = []
## Max distance from user while channeling; leave = cancel.
@export var use_range: float = 1.85
## Cage door reinforced after a capture (until dawn): costs a part, or double time.
var reinforced: bool = false
## World-space offset from the interact point for staff door-guard stance (no species branching).
@export var guard_offset: Vector3 = Vector3(0, 0, 1.2)
var tier_done: int = 0
## Free tiers left from a consumed kit.
var _kit_credit: int = 0

var _done: bool = false
var _busy: bool = false
var _blocker: Node3D
var _blocker_layer: int = 1
var _label: ProximityLabel
var _progress_label: Label3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	if soft_seconds < 0.0:
		soft_seconds = GameConst.SOFT_INTERACT_SEC
	if hard_seconds < 0.0:
		hard_seconds = GameConst.HARD_INTERACT_SEC
	var has_shape := false
	for c in get_children():
		if c is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.0
		shape.shape = sphere
		add_child(shape)
	if _blocker == null:
		_blocker = get_node_or_null("Blocker") as Node3D
	_ensure_world_label()
	Bus.day_changed.connect(func(_d: int) -> void:
		if reinforced:
			reinforced = false
			_refresh_label()
	)


func bind_blocker(node: Node3D) -> void:
	_blocker = node
	if node is CollisionObject3D:
		_blocker_layer = (node as CollisionObject3D).collision_layer


func _ensure_world_label() -> void:
	_label = get_node_or_null("WorldLabel") as ProximityLabel
	if _label == null:
		_label = ProximityLabel.new()
		_label.name = "WorldLabel"
		_label.position = Vector3(0, 1.35, 0)
		_label.modulate = Color(1.0, 0.95, 0.55)
		add_child(_label)
	_progress_label = get_node_or_null("ProgressLabel") as Label3D
	if _progress_label == null:
		_progress_label = Label3D.new()
		ProximityLabel.style(_progress_label, 26)
		_progress_label.name = "ProgressLabel"
		_progress_label.position = Vector3(0, 1.05, 0)
		_progress_label.modulate = Color(0.7, 1.0, 0.75)
		_progress_label.visible = false
		add_child(_progress_label)
	_refresh_label()


func _refresh_label() -> void:
	if _label == null:
		return
	var cap := CapabilityIds.to_label(required)
	var line := display_name
	if required != CapabilityIds.Id.NONE:
		line = "%s\n[%s · Soft / 无则 Hard]" % [display_name, cap]
	if tiers > 1 and not _done:
		line += "\n[施工 %d/%d · 夜间 · 每档 %s 或 %s]" % [
			tier_done, tiers, _cost_text(), _kit_label(route_kit_id)
		]
		if _kit_credit > 0:
			line += "\n[套件余 %d 档免费]" % _kit_credit
	if reinforced and not _done:
		line += "\n[已加固：多耗原料×%d，没有则耗时×%.0f]" % [GameConst.REINFORCE_EXTRA_MATERIALS, GameConst.REINFORCE_TIME_MULT]
	_label.set_info(line)


func try_use(user: AnimalActor) -> void:
	if _done or _busy:
		return
	var soft := required == CapabilityIds.Id.NONE or user.has_capability(required)
	if opens_path and requires_night and not Clock.allows_escape_actions():
		## Cage doors may be opened by day so animals can go out gathering; routes may not.
		var day_cage_outing := breach_style == BreachStyle.DESTROY and Clock.is_visitor_hours()
		if day_cage_outing:
			Bus.interact_feedback.emit("参观时段溜出展区 — 去搜集原料/侦察；外墙施工须等夜间")
		elif tiers > 1:
			Bus.interact_feedback.emit("现在是%s — 外墙施工要等夜间。白天先搜集原料/套件、侦察职员" % Clock.phase_name())
			return
		else:
			Bus.interact_feedback.emit("现在是%s — 越狱破障请等到夜间（笼门可在参观时段溜出搜集）" % Clock.phase_name())
			return
	## Tiered work: figure out how this tier is paid before committing time.
	var pay := &""
	if tiers > 1:
		pay = _plan_payment(user)
		if pay == &"":
			Bus.interact_feedback.emit("材料不足：每档需 %s 或 %s（缺：%s）" % [
				_cost_text(), _kit_label(route_kit_id), _missing_text(user)
			])
			return
	_busy = true
	var wait := soft_seconds if soft else hard_seconds
	if tiers > 1:
		wait = (GameConst.TIER_SOFT_SEC if soft else GameConst.TIER_HARD_SEC) * Game.work_time_scale
	var pay_part := false
	if reinforced:
		pay_part = user.material_count() >= GameConst.REINFORCE_EXTRA_MATERIALS
		if pay_part:
			Bus.interact_feedback.emit("笼门已加固：完成时额外消耗原料 ×%d" % GameConst.REINFORCE_EXTRA_MATERIALS)
		else:
			wait *= GameConst.REINFORCE_TIME_MULT
			Bus.interact_feedback.emit("笼门已加固且没有原料 — 耗时 ×%.0f" % GameConst.REINFORCE_TIME_MULT)
	var label := CapabilityIds.to_label(required)
	var step := "（第 %d/%d 档）" % [tier_done + 1, tiers] if tiers > 1 else ""
	if soft:
		Bus.interact_feedback.emit("使用%s：%s%s（稳）" % [label if required != CapabilityIds.Id.NONE else "通用", display_name, step])
	else:
		Bus.interact_feedback.emit("硬闯%s%s（无%s，吵且慢）…" % [display_name, step, label])
	if not await _channel(user, wait):
		return
	if not soft:
		if _emit_noise(hard_noise, user):
			_busy = false
			return
	if pay_part:
		user.consume_any_material(GameConst.REINFORCE_EXTRA_MATERIALS)
	if tiers > 1:
		_pay_tier(user, pay)
		tier_done += 1
		_refresh_label()
		tier_completed.emit(tier_done, tiers)
		if tier_done < tiers:
			Bus.interact_feedback.emit("%s 施工 %d/%d 完成" % [display_name, tier_done, tiers])
			_busy = false
			return
	await _complete(soft, user)
	_busy = false


## Progress channel shared by every interaction. Returns false if cancelled.
func _channel(user: AnimalActor, wait: float) -> bool:
	var elapsed := 0.0
	if _progress_label:
		_progress_label.visible = true
	while elapsed < wait:
		await get_tree().process_frame
		if not is_instance_valid(user) or user.is_confined:
			_cancel_use("交互中断（被抓/禁闭）")
			return false
		if user.global_position.distance_to(global_position) > use_range:
			_cancel_use("离开范围，交互取消")
			return false
		elapsed += get_process_delta_time()
		if _progress_label:
			_progress_label.text = "进度 %d%%" % int(clampf(elapsed / maxf(wait, 0.001), 0.0, 1.0) * 100.0)
	if _progress_label:
		_progress_label.visible = false
		_progress_label.text = ""
	return true


## How the next tier will be paid: &"credit" (free from earlier kit), &"kit", &"materials", or &"" (can't).
func _plan_payment(user: AnimalActor) -> StringName:
	if _kit_credit > 0:
		return &"credit"
	if route_kit_id != &"" and user.has_item(route_kit_id):
		return &"kit"
	if _has_materials(user):
		return &"materials"
	return &""


func _has_materials(user: AnimalActor) -> bool:
	return not tier_cost.is_empty() and _missing(user).is_empty()


## Materials still lacking for one tier (counts duplicates in the recipe).
func _missing(user: AnimalActor) -> Array[StringName]:
	var out: Array[StringName] = []
	var need := {}
	for m in tier_cost:
		need[m] = int(need.get(m, 0)) + 1
	for m in need:
		if user.item_count(m) < int(need[m]):
			out.append(m)
	return out


func _cost_text() -> String:
	if tier_cost.is_empty():
		return "—"
	var parts := PackedStringArray()
	for m in tier_cost:
		parts.append(KitIds.display_name(m))
	return "+".join(parts)


func _missing_text(user: AnimalActor) -> String:
	var parts := PackedStringArray()
	for m in _missing(user):
		parts.append(KitIds.display_name(m))
	return "、".join(parts) if not parts.is_empty() else "—"


func _pay_tier(user: AnimalActor, pay: StringName) -> void:
	match pay:
		&"credit":
			_kit_credit -= 1
		&"kit":
			user.consume_item(route_kit_id)
			_kit_credit = GameConst.KIT_TIERS - 1
		&"materials":
			for m in tier_cost:
				user.consume_item(m)


func _kit_label(id: StringName) -> String:
	match id:
		&"dig_kit":
			return "挖掘套件"
		&"climb_kit":
			return "攀爬套件"
		_:
			return String(id) if id != &"" else "（无专用套件）"


func _cancel_use(reason: String) -> void:
	_busy = false
	if _progress_label:
		_progress_label.visible = false
		_progress_label.text = ""
	Bus.interact_feedback.emit(reason)


func _emit_noise(amount: float, user: AnimalActor) -> bool:
	if amount < Alert.noise_threshold():
		return false
	if Clock.phase == Clock.Phase.NIGHT_QUIET:
		Bus.interact_feedback.emit("噪音很大，但夜巡已歇岗…")
		return false
	var instant := false
	for s in get_tree().get_nodes_in_group("staff"):
		if s.has_method("alert_to_noise"):
			s.call("alert_to_noise", user.global_position)
		if s is Node3D:
			var d := user.global_position.distance_to((s as Node3D).global_position)
			## Only instant-catch when staff is already on top of the noise.
			if d <= GameConst.HARD_INSTANT_CATCH_RANGE:
				instant = true
	if instant:
		Bus.interact_feedback.emit("硬闯噪音就在职员耳边，当场被抓！")
		user.capture_return_home("硬闯噪音")
		return true
	Bus.interact_feedback.emit("噪音惊动了职员，正在赶来查看 — 快离开！")
	return false


func _complete(soft: bool, user: AnimalActor) -> void:
	if grants_breach > 0.0:
		var world := get_tree().get_first_node_in_group("zoo_world")
		if world and world.has_method("add_breach"):
			world.call("add_breach", grants_breach)
	if opens_path and _blocker:
		await _open_blocker(user)
	used.emit(true, soft)
	Bus.interact_feedback.emit("完成：%s" % display_name)
	if one_shot:
		_done = true
		if _label:
			_label.modulate = Color(0.55, 0.55, 0.55)


func _open_blocker(user: AnimalActor) -> void:
	match breach_style:
		BreachStyle.DIG_HOLE:
			BreachBuilder.dig_hole(_blocker, user)
			_blocker = null
		BreachStyle.CLIMB_LEDGE:
			var blocker := _blocker
			_blocker = null
			await BreachBuilder.climb_ledge(blocker, user, get_tree())
		_:
			_disable_blocker_keep_node()


func _disable_blocker_keep_node() -> void:
	if _blocker == null:
		return
	if _blocker is CollisionObject3D:
		(_blocker as CollisionObject3D).collision_layer = 0
		(_blocker as CollisionObject3D).collision_mask = 0
	_blocker.visible = false


func reinforce() -> void:
	reinforced = true
	_refresh_label()


func relock() -> void:
	_done = false
	_busy = false
	if _label:
		_label.modulate = Color(1.0, 0.95, 0.55)
	if _blocker == null:
		return
	_blocker.visible = true
	if _blocker is CollisionObject3D:
		(_blocker as CollisionObject3D).collision_layer = _blocker_layer
		(_blocker as CollisionObject3D).collision_mask = 0
	Bus.interact_feedback.emit("%s 已重新上锁" % display_name)
