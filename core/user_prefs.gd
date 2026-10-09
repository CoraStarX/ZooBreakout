class_name UserPrefs
extends RefCounted
## Tiny persistent player preferences (user://prefs.cfg). Disabled in headless runs so tests never write it.

const PATH := "user://prefs.cfg"

static var _cfg: ConfigFile
static var _loaded: bool = false


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_cfg = ConfigFile.new()
	if enabled():
		_cfg.load(PATH)


static func get_value(section: String, key: String, default: Variant = null) -> Variant:
	_ensure()
	return _cfg.get_value(section, key, default)


static func set_value(section: String, key: String, value: Variant) -> void:
	_ensure()
	_cfg.set_value(section, key, value)
	if enabled():
		_cfg.save(PATH)


static func clear_section(section: String) -> void:
	_ensure()
	if _cfg.has_section(section):
		_cfg.erase_section(section)
		if enabled():
			_cfg.save(PATH)
