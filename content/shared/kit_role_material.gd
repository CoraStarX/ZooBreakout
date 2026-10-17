@tool
class_name KitRoleMaterial
extends ShaderMaterial
## 共用角色材質；palette 選擇只來自 settings，不序列化顏色副本。
@export var settings: StyleSettings = preload("res://content/shared/style_settings.tres"):
	set(value):
		if settings != null and settings.changed.is_connected(refresh):
			settings.changed.disconnect(refresh)
		settings = value
		_bind_settings()
## 只供作者辨識／驗收；實際角色由各 Mesh 的 color_role instance uniform 指定。
@export_enum("building", "platform") var role: int = 0
var palette: StylePalette:
	get:
		return settings.palette if settings != null else null

func _init() -> void:
	call_deferred("_bind_settings")

func _bind_settings() -> void:
	if settings != null and not settings.changed.is_connected(refresh):
		settings.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if shader == null or palette == null:
		return
	set_shader_parameter("building_color", palette.building)
	set_shader_parameter("platform_color", palette.platform)
	set_shader_parameter("ground_color", palette.ground)
	set_shader_parameter("highlight_color", palette.highlight)
	set_shader_parameter("ink_color", palette.ink)
	set_shader_parameter("outline_enabled", settings.outline_enabled)
	set_shader_parameter("toon_enabled", settings.toon_enabled)
	set_shader_parameter("outline_pixels", settings.outline_pixels)
	set_shader_parameter("toon_steps", settings.toon_steps)
