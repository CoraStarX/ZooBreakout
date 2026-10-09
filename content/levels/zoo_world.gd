extends Node3D
## Level root: hosts RunSession + PartyController, wires geometry/danger/office/exits.

const Spawns := preload("res://content/levels/zoo_p0_spawns.gd")
const GEOMETRY_SCENE := preload("res://scenes/world/zoo_p0_geometry.tscn")
const DayBanner := preload("res://content/ui/day_banner.gd")
const RUN_RESULT_SCENE := preload("res://scenes/ui/run_result.tscn")

var session: RunSession
var party: PartyController
var staff: StaffActor
## animal def id -> home cage Interactable (from geometry)
var cage_doors: Dictionary = {}
var _geometry: ZooP0Geometry
var _result_ui: CanvasLayer
var _input_locked: bool = false
var _env: Environment
var _lighting_tween: Tween

## Per-phase look: sun energy/color, fill energy, sky, ambient (day/night must read at a glance).
const PHASE_LOOK := {
	Clock.Phase.OPEN: {
		"sun": 1.15, "sun_color": Color(1.0, 1.0, 1.0), "fill": 0.35,
		"sky": Color(0.45, 0.62, 0.85), "ambient": Color(0.55, 0.6, 0.65), "ambient_e": 0.55,
	},
	Clock.Phase.CLOSE: {
		"sun": 0.85, "sun_color": Color(1.0, 0.72, 0.5), "fill": 0.28,
		"sky": Color(0.82, 0.5, 0.38), "ambient": Color(0.6, 0.48, 0.45), "ambient_e": 0.48,
	},
	Clock.Phase.NIGHT_PATROL: {
		"sun": 0.38, "sun_color": Color(0.55, 0.65, 1.0), "fill": 0.18,
		"sky": Color(0.06, 0.08, 0.17), "ambient": Color(0.32, 0.38, 0.6), "ambient_e": 0.42,
	},
	Clock.Phase.NIGHT_QUIET: {
		"sun": 0.3, "sun_color": Color(0.5, 0.58, 0.95), "fill": 0.14,
		"sky": Color(0.04, 0.05, 0.12), "ambient": Color(0.28, 0.33, 0.55), "ambient_e": 0.38,
	},
}

## Proxies for prototypes / HUD that still read level-root fields.
var breach: float:
	get:
		return session.breach if session else 0.0
	set(value):
		if session:
			session.breach = value

var exhibit_escaped: bool:
	get:
		return session.exhibit_escaped if session else false
	set(value):
		if session:
			session.exhibit_escaped = value

var companion_rescued: bool:
	get:
		return session.companion_rescued if session else false
	set(value):
		if session:
			session.companion_rescued = value


func _ready() -> void:
	add_to_group("zoo_world")
	session = RunSession.new()
	session.name = "RunSession"
	add_child(session)
	party = PartyController.new()
	party.name = "Party"
	add_child(party)
	Bus.animal_rescued.connect(_on_animal_rescued)
	Bus.run_outcome_changed.connect(_on_run_outcome)
	Bus.intel_gained.connect(_on_intel_gained)
	Bus.phase_changed.connect(func(_p: int) -> void: _apply_phase_look(false))
	_setup_environment()
	_geometry = GEOMETRY_SCENE.instantiate() as ZooP0Geometry
	_geometry.name = "Geometry"
	add_child(_geometry)
	cage_doors = _geometry.cage_doors
	staff = _geometry.staff
	for animal_id in cage_doors.keys():
		_wire_cage_door(cage_doors[animal_id] as Interactable, animal_id as StringName)
	_wire_soft_escape_routes()
	_wire_exit_routes()
	if _geometry.danger_approach:
		_geometry.danger_approach.body_entered.connect(_on_danger_approach_entered)
	if _geometry.danger_zone:
		_geometry.danger_zone.body_entered.connect(func(b: Node3D): party.on_danger_entered(b))
	_spawn_party()
	var cam := get_node_or_null("CameraRig/Camera3D") as Camera3D
	if cam:
		cam.make_current()
	_result_ui = RUN_RESULT_SCENE.instantiate() as CanvasLayer
	add_child(_result_ui)
	add_child(DayBanner.new())
	var hud := GameHUD.new()
	hud.name = "GameHUD"
	add_child(hud)
	var hints := HintDirector.new()
	hints.name = "Hints"
	hints.hud = hud
	add_child(hints)
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.hint_director = hints
	add_child(pause_menu)
	Bus.interact_feedback.emit("白天：搜集蓝点原料/★套件、侦察紫点 → 夜间去外墙施工出园")


func door_for_animal(animal: AnimalActor) -> Interactable:
	if animal == null or animal.def == null:
		return null
	return cage_doors.get(animal.def.id) as Interactable


func get_staff() -> StaffActor:
	return staff


func current_objective() -> String:
	if session == null:
		return ""
	var me := party.controlled() if party else null
	if me and me.is_confined and not session.is_finished():
		return "短押中（%.0fs）：笼内可搜集原料；或 Tab 换控让同伴来撬门" % CaptureFlow.detention_left(me)
	if me and not session.is_finished() and session.exhibit_escaped and not Clock.allows_escape_actions():
		return "%s｜背包：木%d 绳%d 金属%d%s" % [
			session.current_objective(), me.item_count(KitIds.WOOD), me.item_count(KitIds.ROPE), me.item_count(KitIds.METAL),
			"、挖掘套件" if me.has_item(KitIds.DIG) else ("、攀爬套件" if me.has_item(KitIds.CLIMB) else ""),
		]
	return session.current_objective()


func _on_intel_gained(id: StringName) -> void:
	if id == IntelIds.PATROL_ROUTE and staff:
		staff.set_route_visible(true)
	if id == IntelIds.REST_TIME:
		Bus.interact_feedback.emit("情报到手：现在界面会显示「距歇岗」倒计时")


func _on_animal_rescued(_id: StringName) -> void:
	if session and session.mark_companion_rescued():
		Bus.interact_feedback.emit("阶段完成：同伴已入队 — 打通挖掘或攀爬出园线")


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment = env
	add_child(we)
	_env = env
	_apply_phase_look(true)


func _apply_phase_look(instant: bool) -> void:
	if _env == null:
		return
	var look: Dictionary = PHASE_LOOK.get(Clock.phase, PHASE_LOOK[Clock.Phase.OPEN])
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	var fill := get_node_or_null("Fill") as DirectionalLight3D
	if _lighting_tween and _lighting_tween.is_valid():
		_lighting_tween.kill()
	if instant:
		_env.background_color = look["sky"]
		_env.ambient_light_color = look["ambient"]
		_env.ambient_light_energy = look["ambient_e"]
		if sun:
			sun.light_energy = look["sun"]
			sun.light_color = look["sun_color"]
		if fill:
			fill.light_energy = look["fill"]
		return
	_lighting_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	var t := 1.5
	_lighting_tween.tween_property(_env, "background_color", look["sky"], t)
	_lighting_tween.tween_property(_env, "ambient_light_color", look["ambient"], t)
	_lighting_tween.tween_property(_env, "ambient_light_energy", look["ambient_e"], t)
	if sun:
		_lighting_tween.tween_property(sun, "light_energy", look["sun"], t)
		_lighting_tween.tween_property(sun, "light_color", look["sun_color"], t)
	if fill:
		_lighting_tween.tween_property(fill, "light_energy", look["fill"], t)


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("switch_animal"):
		party.switch_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("order_follow"):
		party.order_all(AnimalActor.FollowMode.FOLLOW)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("order_hold"):
		party.order_all(AnimalActor.FollowMode.HOLD)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_rescue_monkey"):
		if Game.debug_enabled:
			_debug_rescue_other()
		else:
			Bus.interact_feedback.emit("正式模式请打开同伴笼门解救（无 Debug 跳过）")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_advance_phase"):
		if Game.debug_enabled:
			_debug_advance_phase()
		get_viewport().set_input_as_handled()


func add_breach(amount: float) -> void:
	if session:
		session.add_breach(amount)


func controlled_animal() -> AnimalActor:
	return party.controlled() if party else null


func party_animals() -> Array[AnimalActor]:
	return party.party() if party else []


func _debug_rescue_other() -> void:
	var other: StringName = Spawns.companion_id(Game.selected_starter_id)
	if party.rescue(other):
		Bus.interact_feedback.emit("【Debug】跳过解救过程 — 同伴已入队，可 Tab 换控")
	else:
		Bus.interact_feedback.emit("【Debug】同伴已在队伍中或不可用")


func _debug_advance_phase() -> void:
	Clock.advance()
	Bus.interact_feedback.emit("时段 → %s（剩余可等自动，或再按 T）" % Clock.phase_name())


func _spawn_party() -> void:
	var starter_id: StringName = Spawns.resolve_starter(Game.selected_starter_id)
	Game.selected_starter_id = starter_id
	var other_id: StringName = Spawns.companion_id(starter_id)
	var starter_def: AnimalDef = Spawns.def_for(starter_id)
	var other_def: AnimalDef = Spawns.def_for(other_id)

	var starter := AnimalActor.create(starter_def)
	starter.position = Spawns.home_for(starter_id)
	starter.home_position = starter.position
	add_child(starter)
	party.setup_starter(starter)

	var caged := AnimalActor.create(other_def)
	caged.position = Spawns.home_for(other_id)
	caged.home_position = caged.position
	add_child(caged)
	party.register_caged(other_id, caged)


func _wire_cage_door(door: Interactable, animal_id: StringName) -> void:
	door.used.connect(func(success: bool, soft: bool) -> void:
		_on_cage_door_used(animal_id, success, soft)
	)


func _wire_soft_escape_routes() -> void:
	if _geometry == null:
		return
	for child in _geometry.get_children():
		if not (child is Interactable):
			continue
		var it := child as Interactable
		if not it.opens_path:
			continue
		if it.breach_style == Interactable.BreachStyle.DESTROY:
			continue
		it.used.connect(func(_success: bool, _soft: bool) -> void:
			if session and session.mark_exhibit_escaped():
				Bus.interact_feedback.emit("阶段完成：经 %s 逃出展区 — 下一步解救同伴" % it.display_name)
		)


func _wire_exit_routes() -> void:
	if _geometry == null:
		return
	if _geometry.dig_interactable:
		_geometry.dig_interactable.tier_completed.connect(func(done: int, _t: int) -> void:
			session.set_route_tiers(RunSession.ExitRoute.DIG, done)
		)
		_geometry.dig_interactable.used.connect(func(_s: bool, _soft: bool) -> void:
			_on_dig_route_ready()
		)
	if _geometry.climb_interactable:
		_geometry.climb_interactable.tier_completed.connect(func(done: int, _t: int) -> void:
			session.set_route_tiers(RunSession.ExitRoute.CLIMB, done)
		)
		_geometry.climb_interactable.used.connect(func(_s: bool, _soft: bool) -> void:
			_on_climb_route_ready()
		)
	if _geometry.exit_west:
		_geometry.exit_west.body_entered.connect(func(_b: Node3D): _check_exit_win(RunSession.ExitRoute.DIG))
		_geometry.exit_west.body_exited.connect(func(_b: Node3D): _check_exit_win(RunSession.ExitRoute.DIG))
	if _geometry.exit_south:
		_geometry.exit_south.body_entered.connect(func(_b: Node3D): _check_exit_win(RunSession.ExitRoute.CLIMB))
		_geometry.exit_south.body_exited.connect(func(_b: Node3D): _check_exit_win(RunSession.ExitRoute.CLIMB))


func _on_dig_route_ready() -> void:
	if session and session.mark_route_dig_ready():
		_geometry.open_west_exit_route()
		Bus.interact_feedback.emit("挖掘出园线已打通 — 西外墙已破，全队进入蓝区")
		_check_exit_win(RunSession.ExitRoute.DIG)


func _on_climb_route_ready() -> void:
	## Idempotent — may already be opened from climb ledge placement.
	open_climb_exit_route()
	_check_exit_win(RunSession.ExitRoute.CLIMB)


func open_climb_exit_route() -> void:
	## Called before Soft/Hard climb eject so the user never spawns inside the gate.
	if session and session.mark_route_climb_ready():
		Bus.interact_feedback.emit("攀爬出园线已打通 — 南外墙已翻过，全队进入蓝区")
	if _geometry:
		_geometry.open_south_exit_route()


func check_exit_win(route: RunSession.ExitRoute) -> void:
	## Public for prototypes / QA harness.
	_check_exit_win(route)


func _physics_process(_delta: float) -> void:
	if session == null or session.is_finished() or _geometry == null:
		return
	if session.route_dig_ready:
		_check_exit_win(RunSession.ExitRoute.DIG)
	if session.route_climb_ready:
		_check_exit_win(RunSession.ExitRoute.CLIMB)


func _check_exit_win(route: RunSession.ExitRoute) -> void:
	if session == null or session.is_finished():
		return
	if not session.is_route_ready(route):
		return
	var zone: Area3D = _geometry.exit_west if route == RunSession.ExitRoute.DIG else _geometry.exit_south
	if zone == null or party == null:
		return
	var members: Array[AnimalActor] = party.party()
	if members.is_empty():
		return
	var free: Array[AnimalActor] = []
	var confined_n := 0
	for a in members:
		if a.is_confined:
			confined_n += 1
		else:
			free.append(a)
	if free.is_empty():
		return
	for a in free:
		if not _is_in_exit_zone(a, zone):
			return
	var reason := "挖掘线出园" if route == RunSession.ExitRoute.DIG else "攀爬线出园"
	if confined_n > 0:
		Bus.interact_feedback.emit("禁闭同伴未同行（%d）— 其余队员已出园" % confined_n)
	session.try_win(reason)


func _is_in_exit_zone(body: Node3D, zone: Area3D) -> bool:
	## Distance + planar pad check (zone.y is center; animals sit near ground).
	var delta := body.global_position - zone.global_position
	var col: CollisionShape3D = null
	for c in zone.get_children():
		if c is CollisionShape3D:
			col = c as CollisionShape3D
			break
	var half := Vector3(1.2, 2.0, 1.8)
	if col and col.shape is BoxShape3D:
		half = (col.shape as BoxShape3D).size * 0.5
	## Generous vertical slack: animals y≈0–1 while zone center may be at y=1.
	return absf(delta.x) <= half.x and absf(delta.z) <= half.z and absf(delta.y) <= half.y + 2.0


func _on_run_outcome(outcome: int) -> void:
	_input_locked = true
	Clock.auto_advance = false
	if _result_ui and _result_ui.has_method("show_outcome"):
		_result_ui.call("show_outcome", outcome, session.outcome_reason if session else "")


func _on_cage_door_used(animal_id: StringName, _success: bool, _soft: bool) -> void:
	## A free teammate opened the cage of a detained animal → early release.
	for node in get_tree().get_nodes_in_group("animals"):
		var a := node as AnimalActor
		if a and a.is_confined and a.def and a.def.id == animal_id:
			CaptureFlow.release(a, "同伴撬开笼门，%s 被救出！")
	if animal_id == Game.selected_starter_id:
		if session and session.mark_exhibit_escaped():
			Bus.interact_feedback.emit("阶段完成：已逃出展区 — 下一步解救同伴")
		return
	if party and party.rescue(animal_id):
		Bus.interact_feedback.emit("打开笼门解救成功！可 Tab 换控")


func _on_danger_approach_entered(body: Node3D) -> void:
	if not (body is AnimalActor):
		return
	var actor := body as AnimalActor
	if actor.is_controlled:
		party.on_danger_approach_leader()
	else:
		actor.enter_danger_auto_hold()
