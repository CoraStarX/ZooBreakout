@tool
class_name StyleSettings
extends Resource
## 共用風格的唯一選擇與參數入口。機制色獨立於建築色板。
@export var palette: StylePalette:
	set(value):
		palette = value
		emit_changed()
@export var outline_enabled: bool = false
@export var toon_enabled: bool = false
@export var post_enabled: bool = true
@export_range(0.5, 4.0, 0.1) var outline_pixels: float = 1.3
@export_range(2, 6, 1) var toon_steps: int = 3
@export var climb_color: Color = Color("36bfb8")
@export var jump_color: Color = Color("ffc73d")
@export var marker_ink: Color = Color("26343a")
@export_range(0.5, 3.0, 0.1) var marker_outline_pixels: float = 1.0
## 只記視覺角色，無位置、大小、碰撞或機制資料。
@export var block_roles: Dictionary[StringName, int] = {
	&"Ground": 2, &"Building": 0, &"LandingPlatform": 1, &"ReturnRamp": 1,
	&"NorthBoundary": 0, &"SouthBoundary": 0, &"WestBoundary": 0, &"EastBoundary": 0,
}
