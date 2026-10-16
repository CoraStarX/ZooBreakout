class_name FormRules
extends RefCounted
static func validate_form(form: FormDef) -> PackedStringArray:
	var errors := PackedStringArray()
	if form == null: return PackedStringArray(["形態資料缺失"])
	if form.id.is_empty(): errors.append("形態id不能空白")
	if not is_finite(form.duration_sec) or form.duration_sec < FormDef.DURATION_INFINITE: errors.append("duration_sec不能為負值或非有限值")
	if not form.body_size.is_finite() or form.body_size.x <= 0 or not is_equal_approx(form.body_size.x,form.body_size.z) or form.body_size.y < form.body_size.x: errors.append("膠囊體型須寬深相等、高度不小於直徑且為正數")
	if not is_finite(form.move_speed) or form.move_speed <= 0: errors.append("移速須為正數")
	if not is_finite(form.visibility_mult) or form.visibility_mult < 0: errors.append("可見度倍率無效")
	if not is_finite(form.footstep_noise) or form.footstep_noise < 0: errors.append("腳步噪音無效")
	if form.movement_profile == null: errors.append("缺少移動配置")
	return errors

static func validate_setup(setup: FormSetup) -> PackedStringArray:
	if setup == null: return PackedStringArray(["缺少開局配置"])
	var errors := PackedStringArray()
	var ids: Array[StringName] = []
	for form in setup.forms:
		errors.append_array(validate_form(form))
		if form == null: continue
		if ids.has(form.id): errors.append("形態id重複："+str(form.id))
		ids.append(form.id)
	if setup.base_form == null or not setup.forms.has(setup.base_form): errors.append("本體不在形態目錄")
	if setup.starting_form == null or not setup.forms.has(setup.starting_form): errors.append("開局形態不在目錄")
	if not setup.initial_unlocked_forms.has(setup.base_form) or not setup.initial_unlocked_forms.has(setup.starting_form): errors.append("本體與開局形態必須初始解鎖")
	for form in setup.initial_unlocked_forms:
		if not setup.forms.has(form): errors.append("初始解鎖包含目錄外形態")
	if not setup.spawn.is_finite(): errors.append("出生點無效")
	return errors

static func rejection(target: FormDef, base: FormDef, unlocked: bool, grounded: bool, remaining: float, space_clear: bool) -> String:
	if not unlocked: return "尚未解鎖此形態"
	# 回本體不能被冷卻、掛牆、空中或特效鎖住；空間仍須驗證，必要時由控制器找合法位置。
	if target != base:
		if not grounded: return "需要先站穩地面、平台或屋頂，才能變成此形態"
		if remaining > 0: return "變形冷卻中，還需 %.1f 秒" % remaining
	if not space_clear: return "這裡太窄，無法容納此形態"
	return ""

static func capsule(form: FormDef) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = form.collision_radius()
	shape.height = form.body_size.y
	return shape

static func footprint_offsets(form: FormDef) -> Array[Vector3]:
	var profile := form.movement_profile
	var count := maxi(profile.edge_probe_count,4)
	var radius := form.collision_radius()+profile.edge_safety_margin
	var offsets: Array[Vector3] = []
	for i in count:
		var angle := TAU*float(i)/count
		offsets.append(Vector3(cos(angle),0,sin(angle))*radius)
	return offsets

static func validate_params(p: FormParams) -> PackedStringArray:
	if p == null: return PackedStringArray(["缺少變形參數"])
	var errors := PackedStringArray()
	if not is_finite(p.form_cooldown_sec) or p.form_cooldown_sec < 0: errors.append("冷卻必須有限且非負")
	if not is_finite(p.effect_sec) or p.effect_sec <= 0: errors.append("特效時間必須為正")
	if p.witness_windup_sec < FormParams.MIN_WITNESS_WINDUP_SEC or not is_finite(p.witness_windup_sec): errors.append("目擊前搖不得低於0.5秒")
	if p.safe_history_limit < 1 or p.safe_history_spacing <= 0: errors.append("安全歷史配置無效")
	if not is_finite(p.transform_hearing_radius) or p.transform_hearing_radius <= 0 or not is_finite(p.transform_noise) or p.transform_noise < 0: errors.append("變形聽距／音量無效")
	if not is_finite(p.push_max_distance) or p.push_max_distance < 0: errors.append("推開距離必須有限且非負")
	if p.push_direction_count < 4 or p.push_direction_count > 64 or p.push_radial_steps < 1 or p.push_radial_steps > 32 or p.push_refine_steps < 0 or p.push_refine_steps > 12: errors.append("推開取樣須在有界範圍內")
	if not is_finite(p.push_path_step) or p.push_path_step <= 0 or not is_finite(p.push_height_tolerance) or p.push_height_tolerance < 0: errors.append("推開路徑配置無效")
	return errors

static func push_directions(p: FormParams) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in p.push_direction_count:
		var angle := TAU*float(i)/p.push_direction_count
		result.append(Vector3(cos(angle),0,sin(angle)))
	return result

static func same_support_level(a: float, b: float, p: FormParams) -> bool:
	return is_finite(a) and is_finite(b) and absf(a-b) <= p.push_height_tolerance
