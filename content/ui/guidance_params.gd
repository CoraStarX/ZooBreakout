class_name GuidanceParams
extends Resource
## R5.5 呈現設定；不影響任何玩法判定。
@export_range(0.05, 1.0, 0.01) var refresh_sec: float = 0.12
@export var priority: Array[StringName] = [&"finished", &"detained", &"search", &"rescue", &"exit", &"route"]
@export var retain_invested_route: bool = true
@export var suggest_day_deposit: bool = true
@export var details_initially_open: bool = false
@export var objective_font_size: int = 17
@export var details_width: float = 320.0
