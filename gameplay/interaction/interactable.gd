class_name Interactable
extends Area3D
## Soft capability check: with verb = quiet/fast; without = loud/slow hard attempt.

enum BreachStyle { DESTROY, DIG_HOLE, CLIMB_LEDGE }

signal used(success: bool, soft: bool)
## Night construction progress on a tiered route point.
signal tier_completed(done: int, total: int)

@export var display_name: String = "交互点"
@export var required: CapabilityIds.Id = CapabilityIds.Id.NONE
## Other capabilities that also count as Soft (any one is enough). Only meaningful with `required` set.
@export var also_accepts: Array[int] = []
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
## When false, interactions without the required verb are refused (no Hard). Default true.
@export var allow_hard: bool = true
## Cage door reinforced after a capture (until dawn): costs a part, or double time.
var reinforced: bool = false
## World-space offset from the interact point for staff door-guard stance (no species branching).
@export var guard_offset: Vector3 = Vector3(0, 0, 1.2)
var tier_done: int = 0
## Free tiers left from a consumed kit.
var _kit_credit: int = 0
## Recipe materials / this route's kit left here by any animal. Construction pays from here first.
var stash: Array[StringName] = []
## What the running tier took, as [item_id, from_stash] pairs — refunded to the same place on cancel.
var _paid: Array = []

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


func _hard_allowed_now() -> bool:
	if not allow_hard:
		return false
	## Final construction tier cannot be forced.
	if tiers > 1 and tier_done >= tiers - 1:
		return false
	return true


## Every capability that counts as Soft here: `required` plus `also_accepts`.
func accepted_caps() -> Array[int]:
	var out: Array[int] = []
	if required != CapabilityIds.Id.NONE:
		out.append(required)
	for c in also_accepts:
		if not out.has(c):
			out.append(c)
	return out


func requirement_text() -> String:
	var parts := PackedStringArray()
	for c in accepted_caps():
		parts.append(CapabilityIds.to_label(c as CapabilityIds.Id))
	return "或".join(parts) if not parts.is_empty() else "—"


func _cap_text() -> String:
	return requirement_text()


## Whether this animal could ever open it (talent, or Hard allowed). Ignores phase, cargo and payment.
func can_be_opened_by(def: AnimalDef) -> bool:
	if required == CapabilityIds.Id.NONE or allow_hard:
		return true
	if def == null:
		return false
	for c in accepted_caps():
		if def.has_capability(c as CapabilityIds.Id):
			return true
	return false


## ignore_heavy = true: has the talent at all; false: can use it right now (heavy cargo blocks climb).
func _qualifies(user: AnimalActor, ignore_heavy: bool) -> bool:
	if required == CapabilityIds.Id.NONE:
		return true
	for c in accepted_caps():
		var cap := c as CapabilityIds.Id
		var ok := user.has_capability(cap) if ignore_heavy else user.effective_has_capability(cap)
		if ok:
			return true
	return false


func _refresh_label() -> void:
	if _label == null:
		return
	var cap := _cap_text()
	var line := display_name
	if required != CapabilityIds.Id.NONE:
		if _hard_allowed_now():
			line = "%s\n[%s · Soft / 可强行(慢吵留痕)]" % [display_name, cap]
		else:
			line = "%s\n[%s · 须 Soft · 禁止强行]" % [display_name, cap]
	if tiers > 1 and not _done:
		line += "\n[施工 %d/%d · 夜间 · 每档 %s 或 %s]" % [
			tier_done, tiers, _cost_text(), _kit_label(route_kit_id)
		]
		if _kit_credit > 0:
			line += "\n[套件余 %d 档免费]" % _kit_credit
		line += "\n[存料：%s · X 放入]" % _stash_text()
		if not _hard_allowed_now():
			line += "\n[本档禁止强行]"
	if reinforced and not _done:
		line += "\n[已加固：多耗原料×%d，没有则耗时×%.0f]" % [GameConst.REINFORCE_EXTRA_MATERIALS, GameConst.REINFORCE_TIME_MULT]
	_label.set_info(line)


func try_use(user: AnimalActor) -> void:
	if _done or _busy:
		return
	if tiers > 1 and Alert.is_full_search():
		Bus.interact_feedback.emit("%s：全园搜查中（警戒 %d）— 外墙施工全部中止，等警戒降下来" % [display_name, Alert.level])
		return
	## Tiered work: plan payment first (a carried kit is spent up-front, so it does not block climb Soft).
	var pay := &""
	if tiers > 1:
		pay = _plan_payment(user)
		if pay == &"":
			Bus.interact_feedback.emit("材料不足：每档需 %s 或 %s（缺：%s）" % [
				_cost_text(), _kit_label(route_kit_id), _missing_text(user)
			])
			return
	## After hypothetical pay, climb Soft must not be blocked by a kit that is about to be spent.
	var soft := _qualifies(user, true)
	## One-shot gates: heavy cargo blocks climb right now. Construction pays up-front below.
	if soft and tiers <= 1 and not _qualifies(user, false):
		Bus.interact_feedback.emit("%s：背着重物（套件）无法攀爬 — 先用掉或按 X 放下" % display_name)
		return
	if not soft and not _hard_allowed_now():
		var why := "最后一档须具备才能，禁止强行" if (tiers > 1 and tier_done >= tiers - 1) else "此处禁止强行"
		Bus.interact_feedback.emit("%s：%s（需要 %s）" % [display_name, why, _cap_text()])
		return
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
	_busy = true
	## Pay construction costs up-front so Soft climb is not blocked mid-channel; refund on cancel.
	var paid_upfront := false
	if tiers > 1:
		_pay_tier(user, pay)
		paid_upfront = true
	var rw := GameConst.route_work()
	var wait := soft_seconds if soft else hard_seconds
	if tiers > 1:
		wait = (GameConst.TIER_SOFT_SEC if soft else GameConst.TIER_HARD_SEC) * Game.work_time_scale
		if not soft:
			wait *= rw.hard_time_mult
	elif not soft:
		wait *= rw.hard_time_mult
	var pay_part := false
	if reinforced:
		pay_part = user.material_count() >= GameConst.REINFORCE_EXTRA_MATERIALS
		if pay_part:
			Bus.interact_feedback.emit("笼门已加固：完成时额外消耗原料 ×%d" % GameConst.REINFORCE_EXTRA_MATERIALS)
		else:
			wait *= GameConst.REINFORCE_TIME_MULT
			Bus.interact_feedback.emit("笼门已加固且没有原料 — 耗时 ×%.0f" % GameConst.REINFORCE_TIME_MULT)
	var label := _cap_text()
	var step := "（第 %d/%d 档）" % [tier_done + 1, tiers] if tiers > 1 else ""
	if soft:
		Bus.interact_feedback.emit("使用%s：%s%s（稳）" % [label if required != CapabilityIds.Id.NONE else "通用", display_name, step])
	else:
		Bus.interact_feedback.emit("强行%s%s（无%s · 时×%.0f 噪×%.0f 痕×%.0f）…" % [
			display_name, step, label, rw.hard_time_mult, rw.hard_noise_mult, rw.hard_trace_mult
		])
	if not await _channel(user, wait):
		if paid_upfront:
			_refund_tier(user, pay)
		return
	if not soft:
		var noise_amt := hard_noise * rw.hard_noise_mult
		if _emit_noise(noise_amt, user):
			if paid_upfront:
				_refund_tier(user, pay)
			_busy = false
			return
		## Traces only — never Alert.bump here. Staff discovery settles once.
		TraceService.spawn_at(get_tree(), global_position, rw.hard_trace_mult, &"construction")
	if pay_part:
		user.consume_any_material(GameConst.REINFORCE_EXTRA_MATERIALS)
	if tiers > 1:
		tier_done += 1
		_refresh_label()
		tier_completed.emit(tier_done, tiers)
		if tier_done < tiers:
			Bus.interact_feedback.emit("%s 施工 %d/%d 完成" % [display_name, tier_done, tiers])
			_busy = false
			return
		if not stash.is_empty():
			Bus.interact_feedback.emit("%s 完工：剩余存料已用尽（%s）" % [display_name, _stash_text()])
			stash.clear()
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
		if tiers > 1 and Alert.is_full_search():
			_cancel_use("警戒升至 %d，全园搜查 — %s 施工被迫中止" % [Alert.level, display_name])
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
	if route_kit_id != &"" and _available(user, route_kit_id) > 0:
		return &"kit"
	if _has_materials(user):
		return &"materials"
	return &""


func _has_materials(user: AnimalActor) -> bool:
	return not tier_cost.is_empty() and _missing(user).is_empty()


## Stash + what the user carries.
func _available(user: AnimalActor, id: StringName) -> int:
	return stash.count(id) + user.item_count(id)


## Materials still lacking for one tier (counts duplicates in the recipe).
func _missing(user: AnimalActor) -> Array[StringName]:
	var out: Array[StringName] = []
	var need := {}
	for m in tier_cost:
		need[m] = int(need.get(m, 0)) + 1
	for m in need:
		if _available(user, m) < int(need[m]):
			out.append(m)
	return out


func accepts_stash(id: StringName) -> bool:
	if tiers <= 1 or _done:
		return false
	return tier_cost.has(id) or (route_kit_id != &"" and id == route_kit_id)


## Moves every carried item this point can use into its stash. Returns how many moved.
func deposit_from(user: AnimalActor) -> int:
	var moved := 0
	for id in user.inventory.duplicate():
		if accepts_stash(id):
			user.consume_item(id)
			stash.append(id)
			moved += 1
	if moved > 0:
		_refresh_label()
	return moved


func _stash_text() -> String:
	if stash.is_empty():
		return "空"
	var counts := {}
	for id in stash:
		counts[id] = int(counts.get(id, 0)) + 1
	var parts := PackedStringArray()
	for id in counts:
		parts.append("%s×%d" % [KitIds.display_name(id), counts[id]])
	return " ".join(parts)


func _take(user: AnimalActor, id: StringName) -> void:
	if stash.has(id):
		stash.erase(id)
		_paid.append([id, true])
	else:
		user.consume_item(id)
		_paid.append([id, false])


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
	_paid.clear()
	match pay:
		&"credit":
			_kit_credit -= 1
		&"kit":
			_take(user, route_kit_id)
			_kit_credit = GameConst.KIT_TIERS - 1
		&"materials":
			for m in tier_cost:
				_take(user, m)
	_refresh_label()


func _refund_tier(user: AnimalActor, pay: StringName) -> void:
	match pay:
		&"credit":
			_kit_credit += 1
		&"kit":
			## Undo kit consume: clear the free credit it granted.
			_kit_credit = 0
	for p in _paid:
		if p[1]:
			stash.append(p[0])
		else:
			user.give_items([p[0]])
	_paid.clear()
	_refresh_label()
	Bus.interact_feedback.emit("施工取消，原料已退回原处")


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
	## 統一走 Bus.noise_made；職員自行按聽距判定（不直接點名呼叫）。
	## Route work is its own kind so staff can scale how far it carries (Alert 3+).
	var kind := &"construction" if tiers > 1 else &"interact_hard"
	Bus.noise_made.emit(user.global_position, clampf(amount, 0.1, 1.5), kind)
	var instant := false
	for s in get_tree().get_nodes_in_group("staff"):
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
