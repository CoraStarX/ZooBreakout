class_name FormLab
extends MovementLab
## A只驗證形態操作；B才追加窄縫，C才接員工。原三個沙盒入口不變。
@export var form_setup: FormSetup = preload("res://content/forms/prototype_setup.tres")
@export var form_params: FormParams = preload("res://content/forms/form_params.tres")
var forms: FormController
var _action_added := false
var _effect: MeshInstance3D
var _effect_material: StandardMaterial3D
var _effect_left: float = 0
var _switch_audio: AudioStreamPlayer
var show_guidance: bool = true
var _guidance_title: Control
var _guidance_toggle: CheckButton

func _ready() -> void:
	super._ready()
	if not InputMap.has_action(form_params.switch_action):
		_action_added = true
		InputMap.add_action(form_params.switch_action)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_Q
		InputMap.action_add_event(form_params.switch_action,key)
	forms = FormController.new()
	forms.setup = form_setup
	forms.params = form_params
	forms.form_changed.connect(_form_changed)
	forms.transform_committed.connect(_transformed)
	forms.feedback.connect(_on_feedback)
	add_child(forms)
	_effect = disk(form_params.effect_color,form_params.effect_radius)
	_effect_material = _effect.material_override as StandardMaterial3D
	_effect_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_effect.visible = false
	add_child(_effect)
	_switch_audio = AudioStreamPlayer.new()
	_switch_audio.volume_db = form_params.switch_tone_db
	_switch_audio.stream = _switch_tone()
	add_child(_switch_audio)
	if not forms.initialize(self,actor.camera,actor):
		actor.input_enabled = false
		forms.input_enabled = false
		set_process(false)
		forms.set_physics_process(false)
		push_error("變形沙盒開局配置無效")
	_build_guidance_settings()
	set_guidance_enabled(bool(UserPrefs.get_value("form_lab","show_guidance",form_params.show_guidance_default)))

func _build_guidance_settings() -> void:
	_guidance_toggle = CheckButton.new()
	_guidance_toggle.name = "FormGuidance"
	_guidance_toggle.text = "顯示任務與形態能力提示（觀察測試時關閉）"
	_guidance_toggle.focus_mode = Control.FOCUS_NONE
	_guidance_toggle.toggled.connect(func(on: bool) -> void: set_guidance_enabled(on,true))
	debug_hud.get_node("Panel/MovementStats").add_child(_guidance_toggle)

func set_guidance_enabled(on: bool, persist: bool = false) -> void:
	show_guidance = on
	if _guidance_title:
		_guidance_title.visible = on
		# 重新顯示時明確失效文字繪製快取，避免僅恢復容器而字形仍空白。
		if on:
			for child in _guidance_title.get_children():
				if child is Control: (child as Control).queue_redraw()
	if _guidance_toggle: _guidance_toggle.set_pressed_no_signal(on)
	# 觀察模式隱藏被動解題資訊；碰撞、能力與輸入規則完全不變。
	for node in find_children("*","Label3D",true,false):
		if node is ProximityLabel: (node as ProximityLabel).visible = on
	if persist: UserPrefs.set_value("form_lab","show_guidance",on)

func _form_changed(_previous: FormDef, current: FormDef, body: TraversalActor) -> void:
	if _squash and _squash.is_valid(): _squash.kill()
	actor = body
	if body is GroundFormActor:
		for form in form_setup.forms:
			if form.abilities.has(CapabilityIds.Id.CLIMB) and forms.unlocked_forms.has(form):
				(body as GroundFormActor).jump_hint = "此形態不能跳躍；按 Q 切換"+form.display_name
				break
	params = actor.params
	var visual := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = params.radius
	capsule.height = params.height
	visual.mesh = capsule
	visual.position.y = params.height*0.5
	visual.material_override = material(current.body_color)
	actor.add_child(visual)
	_visual = visual
	actor.movement_event.connect(metrics.event)
	actor.diagnostic_recorded.connect(metrics.diagnostic)
	actor.stepped.connect(_on_step)
	actor.landed.connect(_on_landed)
	actor.feedback.connect(_on_feedback)
	_landing_audio = AudioStreamPlayer3D.new()
	_landing_audio.volume_db = params.landing_tone_db
	_landing_audio.stream = _placeholder_tone()
	actor.add_child(_landing_audio)
	var shadow_mesh := shadow.mesh as CylinderMesh
	shadow_mesh.top_radius = params.radius
	shadow_mesh.bottom_radius = params.radius
	rig.set_follow_target(actor,false)

func _transformed(_previous: FormDef, _current: FormDef, point: Vector3, forced: bool, _reason: String) -> void:
	if forced: return
	_effect.global_position = point+Vector3.UP*form_params.effect_lift
	_effect_left = form_params.effect_sec
	_effect.visible = true
	if DisplayServer.get_name() != "headless": _switch_audio.play()

func _process(delta: float) -> void:
	if forms == null or not is_instance_valid(forms.actor): return
	super._process(delta)
	_effect_left = maxf(0,_effect_left-delta)
	_effect.visible = _effect_left > 0
	var color := form_params.effect_color
	color.a *= _effect_left/maxf(form_params.effect_sec,0.000001)
	_effect_material.albedo_color = color
	var remaining := forms.cooldown_remaining()
	var command := "Q 變形" if remaining <= 0 else "變形冷卻 %.1fs" % remaining
	if forms.current_form != form_setup.base_form: command = "Q 回本體（不受冷卻限制）"
	var action_hint := _hint.text
	if not actor.capabilities.has(CapabilityIds.Id.CLIMB) and _message_left <= 0: action_hint = "貼地移動；此形態不能跳躍／攀爬"
	_hint.text = "%s｜%s\n%s" % [forms.current_form.display_name,command,action_hint]
	if not show_guidance:
		# 拒絕原因仍需可讀；不顯示平時的能力／路線建議。
		_hint.text = _message if _message_left > 0 else ""
		_hint.visible = _message_left > 0
	else:
		_hint.visible = true

func _build_hud() -> void:
	super._build_hud()
	for node in find_children("*","Label",true,false):
		var label := node as Label
		if label.text.begins_with("移動試玩"):
			label.text = "變形試玩｜Q 切換形態 · 探索高處"
			_guidance_title = label.get_parent() as Control
		elif label.text.begins_with("WASD"): label.text = "WASD 移動　Q 變形　Space 動作　E 互動　F3 設定／統計"

func _switch_tone() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = form_params.switch_tone_rate
	var count := int(form_params.switch_tone_sec*wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count: bytes.encode_s16(i*2,int(sin(TAU*form_params.switch_tone_hz*float(i)/wav.mix_rate)*(1.0-float(i)/count)*32767))
	wav.data = bytes
	return wav

func _exit_tree() -> void:
	if _action_added: InputMap.erase_action(form_params.switch_action)
	super._exit_tree()
