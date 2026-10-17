extends Node
## 静态卫生门禁：分层依赖、遗留目录、EventNames 与 Bus 信号同步。
## godot --headless --path . res://prototypes/p2_hygiene.tscn

## Core 不得认识的玩法/内容符号。
const CORE_BANNED := [
	"TraversalActor", "FormController", "FormDef", "StaffReadabilityMetrics", "ReadabilityStaff",
	"MovementLab", "FormLab", "res://gameplay", "res://content",
]
## GamePlay不得依賴具體宿主、UI或關卡；共享資料型別與Resource可用。
const GAMEPLAY_BANNED := [
	"MovementLab", "FormLab", "StaffReadabilityLab", "UIKit",
	"res://content/levels", "res://content/ui", "res://content/interactables",
]

var _pass_n := 0
var _fail_n := 0


func _ready() -> void:
	print("=== P2 Hygiene ===")
	_scan("res://core", CORE_BANNED, "Core")
	_scan("res://gameplay", GAMEPLAY_BANNED, "GamePlay")
	_check(not DirAccess.dir_exists_absolute("res://scripts"), "遗留 scripts/ 目录已清除")
	_check(not DirAccess.dir_exists_absolute("res://resources"), "遗留 resources/ 目录已清除")
	_check_event_names()
	print("")
	print("=== P2 HYGIENE SUMMARY pass=%d fail=%d ===" % [_pass_n, _fail_n])
	get_tree().quit(0 if _fail_n == 0 else 1)


func _scan(dir: String, banned: Array, layer: String) -> void:
	var bad := PackedStringArray()
	var count := 0
	for path in _gd_files(dir):
		count += 1
		var code := _strip_comments(FileAccess.get_file_as_string(path))
		for token in banned:
			var re := RegEx.new()
			re.compile("\\b%s\\b" % token if not token.begins_with("res://") else token)
			if re.search(code):
				bad.append("%s ← %s" % [path.get_file(), token])
	_check(bad.is_empty(), "%s 层依赖干净（扫描 %d 个脚本）%s" % [layer, count, (" 违规: " + "; ".join(bad)) if not bad.is_empty() else ""])


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in da.get_directories():
		out.append_array(_gd_files(dir.path_join(d)))
	return out


func _strip_comments(src: String) -> String:
	var lines := PackedStringArray()
	for line in src.split("\n"):
		var i := line.find("#")
		lines.append(line if i < 0 else line.substr(0, i))
	return "\n".join(lines)


func _check_event_names() -> void:
	var names := FileAccess.get_file_as_string("res://content/event_names.gd")
	var missing := PackedStringArray()
	for sig in (Bus.get_script() as Script).get_script_signal_list():
		var n: String = sig["name"]
		if not names.contains('&"%s"' % n):
			missing.append(n)
	_check(missing.is_empty(), "EventNames 覆盖全部 Bus 信号 %s" % ("缺: " + ",".join(missing) if not missing.is_empty() else ""))


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass_n += 1
		print("PASS ", msg)
	else:
		_fail_n += 1
		print("FAIL ", msg)
