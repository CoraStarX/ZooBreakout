class_name GatherPoint
extends Area3D
## Daytime resource node: yields one raw material (rope / wood / metal).
## With the required verb the rich stash is taken fast; without it you take one, slowly, and the rest stays.
## How (and whether) the point refills is `refresh_mode`; see docs/COST_REFACTOR.md「采集点刷新模式」.

const _KitIds := preload("res://content/kit_ids.gd")

enum RefreshMode {
	## Whole run, no restock: `yield_rich` units sit here until taken.
	ONCE,
	## R6 (fields only, not implemented): each dawn spawn `pool_daily_count` stashes at random spots
	## from `pool_positions`; after `pool_pity_days` dry days in a row a spawn is guaranteed.
	DAILY_POOL,
	## Rummage again and again: low yield, loud, may come up empty, daily cap (ActionCostTable.gather_repeat_*).
	REPEATABLE,
}

@export var display_name: String = "搜集点"
@export var material: StringName = KitIds.WOOD
@export var required: CapabilityIds.Id = CapabilityIds.Id.NONE
@export var yield_rich: int = 1
@export var yield_poor: int = 1
@export var hint: String = ""
@export var use_range: float = 1.85
## Gather B (risky point): time / noise / trace from ActionCostTable.gather_risky_*. No P0 point uses it yet.
@export var risky: bool = false
@export var refresh_mode: RefreshMode = RefreshMode.ONCE
@export var pool_positions: Array[Vector3] = []
@export var pool_daily_count: int = 0
@export var pool_pity_days: int = 0

## ONCE: units left at the point.
var stock: int = 0
var stocked: bool:
	get:
		return _has_stock()
## DAILY_POOL bookkeeping (R6).
var pool_dry_days: int = 0
## REPEATABLE bookkeeping.
var repeat_found_today: int = 0
var repeat_found_total: int = 0
var repeat_empty_streak: int = 0
var rng := RandomNumberGenerator.new()

var _busy: bool = false
var _crate: MeshInstance3D
var _label: ProximityLabel
var _progress: Label3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	stock = yield_rich
	rng.randomize()
	if refresh_mode == RefreshMode.DAILY_POOL:
		push_warning("GatherPoint %s: DAILY_POOL 尚未实作（R6），按 ONCE 处理" % display_name)
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


func _on_day_changed(_day: int) -> void:
	if refresh_mode == RefreshMode.REPEATABLE:
		repeat_found_today = 0
		_refresh()


func _has_stock() -> bool:
	if refresh_mode == RefreshMode.REPEATABLE:
		return _repeat_block_reason().is_empty()
	return stock > 0


## Total units this point can ever give (ONCE / DAILY_POOL count as ONCE): used by the load-time budget check.
func once_supply() -> int:
	return 0 if refresh_mode == RefreshMode.REPEATABLE else yield_rich


func _repeat_block_reason() -> String:
	var cost := GameConst.action_cost()
	if cost.gather_repeat_run_cap > 0 and repeat_found_total >= cost.gather_repeat_run_cap:
		return "已翻空（整局只有这些）"
	if repeat_found_today >= cost.gather_repeat_daily_cap:
		return "今天翻过了 · 明早再来"
	return ""


func _refresh() -> void:
	var mat := StandardMaterial3D.new()
	if stocked:
		mat.albedo_color = Color(0.3, 0.7, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.55, 0.75)
		mat.emission_energy_multiplier = 0.7
		_label.modulate = Color(0.7, 0.92, 1.0)
		_label.set_info(_stocked_line())
	else:
		mat.albedo_color = Color(0.25, 0.25, 0.28)
		_label.modulate = Color(0.5, 0.5, 0.5)
		var why := _repeat_block_reason() if refresh_mode == RefreshMode.REPEATABLE else "已搜空"
		_label.set_info("%s\n[%s]" % [display_name, why])
	_crate.material_override = mat


func _stocked_line() -> String:
	var mat_name := _KitIds.display_name(material)
	if refresh_mode == RefreshMode.REPEATABLE:
		var cost := GameConst.action_cost()
		return "%s\n[%s · 可反复翻找：很吵、可能空手、每天最多 %d 次收获 · E]" % [
			display_name, mat_name, cost.gather_repeat_daily_cap
		]
	var line := "%s\n[%s 剩 ×%d" % [display_name, mat_name, stock]
	if required != CapabilityIds.Id.NONE:
		line = "%s\n[%s·%s · 剩 ×%d · %s 全拿 / 无则拿 %d 且慢" % [
			display_name, mat_name, hint, stock, CapabilityIds.to_label(required), yield_poor
		]
	if risky:
		line += " · 有风险"
	return line + " · E]"


func try_use(user: AnimalActor) -> void:
	if _busy or user == null:
		return
	if not stocked:
		if refresh_mode == RefreshMode.REPEATABLE:
			Bus.interact_feedback.emit("%s %s" % [display_name, _repeat_block_reason()])
		else:
			Bus.interact_feedback.emit("%s 已搜空（不会补货）" % display_name)
		return
	if Clock.allows_escape_actions():
		Bus.interact_feedback.emit("夜里看不清 — 搜集请等白天（夜间专心施工）")
		return
	if user.inventory_free_slots() <= 0:
		Bus.interact_feedback.emit("背包满了（%d/%d）— 按 X 放下或存到施工点" % [user.inventory.size(), user.inventory_capacity()])
		return
	if refresh_mode == RefreshMode.REPEATABLE:
		_rummage(user)
		return
	var rich := required == CapabilityIds.Id.NONE or user.effective_has_capability(required)
	var amount := mini(stock if rich else yield_poor, stock)
	amount = mini(amount, user.inventory_free_slots())
	var cost := GameConst.action_cost()
	var wait := cost.gather_seconds(rich)
	if risky and rich:
		wait = cost.gather_risky_sec
	if rich:
		Bus.interact_feedback.emit("搜集 %s…" % display_name)
	elif user.has_capability(required):
		Bus.interact_feedback.emit("背着重物（套件）用不了%s，只能慢慢扒拉 %s…" % [CapabilityIds.to_label(required), display_name])
	else:
		Bus.interact_feedback.emit("缺%s，只能慢慢扒拉 %s…" % [CapabilityIds.to_label(required), display_name])
	if not await _channel(user, wait):
		return
	stock -= amount
	_give(user, amount)
	if risky:
		_risky_aftermath(cost)
	var note := ""
	if stock > 0:
		note = "（%s剩 %d 留在原处）" % ["" if rich else "没有%s，只拿到一部分；" % CapabilityIds.to_label(required), stock]
	Bus.interact_feedback.emit("获得 %s ×%d%s — 背包共 %d" % [_KitIds.display_name(material), amount, note, user.item_count(material)])


func _rummage(user: AnimalActor) -> void:
	var cost := GameConst.action_cost()
	Bus.interact_feedback.emit("翻找 %s…（动静很大）" % display_name)
	if not await _channel(user, cost.gather_repeat_sec):
		return
	if cost.gather_repeat_noise > 0.0 and Clock.phase != Clock.Phase.NIGHT_QUIET:
		Bus.noise_made.emit(global_position, cost.gather_repeat_noise, &"gather")
	var pity := repeat_empty_streak >= cost.gather_repeat_pity
	if not pity and rng.randf() < cost.gather_repeat_empty_chance:
		repeat_empty_streak += 1
		_refresh()
		Bus.interact_feedback.emit("翻了半天，什么都没有（连续空手 %d 次；再空 %d 次后必有）" % [
			repeat_empty_streak, maxi(cost.gather_repeat_pity - repeat_empty_streak, 0)
		])
		return
	repeat_empty_streak = 0
	repeat_found_today += 1
	repeat_found_total += 1
	var amount := mini(cost.gather_repeat_yield, user.inventory_free_slots())
	_give(user, amount)
	Bus.interact_feedback.emit("翻到 %s ×%d — 背包共 %d（今天这里翻不出更多了）" % [
		_KitIds.display_name(material), amount, user.item_count(material)
	])


## Hold-to-gather; false when aborted (left range / user gone).
func _channel(user: AnimalActor, wait: float) -> bool:
	_busy = true
	_progress.visible = true
	var elapsed := 0.0
	while elapsed < wait:
		await get_tree().process_frame
		if not is_instance_valid(user):
			_abort("搜集中断")
			return false
		if user.global_position.distance_to(global_position) > use_range:
			_abort("离开范围，搜集取消")
			return false
		elapsed += get_process_delta_time()
		_progress.text = "搜集 %d%%" % int(clampf(elapsed / wait, 0.0, 1.0) * 100.0)
	_progress.visible = false
	_busy = false
	return true


func _give(user: AnimalActor, amount: int) -> void:
	var parts: Array[StringName] = []
	for _i in amount:
		parts.append(material)
	user.give_items(parts)
	_refresh()
	Bus.material_gathered.emit(material, amount)


## B points: optional noise (kind `gather`) and trace at the point. Noise never raises Alert by itself.
func _risky_aftermath(cost: ActionCostTable) -> void:
	if cost.gather_risky_noise > 0.0 and Clock.phase != Clock.Phase.NIGHT_QUIET:
		Bus.noise_made.emit(global_position, cost.gather_risky_noise, &"gather")
	if cost.gather_risky_trace > 0.0:
		TraceService.spawn_at(get_tree(), global_position, cost.gather_risky_trace, &"gather")


func _abort(msg: String) -> void:
	_busy = false
	_progress.visible = false
	Bus.interact_feedback.emit(msg)
