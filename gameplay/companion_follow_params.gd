class_name CompanionFollowParams
extends Resource
## 夥伴跟隨可調參數（麵包屑／卡住／傳送）。

@export_group("Trail")
@export var trail_spacing: float = 0.8
@export var trail_max_points: int = 60

@export_group("Follow")
@export var follow_stop_dist: float = 2.2
@export var follow_speed: float = 4.5
@export var goto_arrive_dist: float = 1.1

@export_group("Stuck recovery")
## 想移動但實際位移過低，累積達此秒數觸發恢復。
@export var stuck_time_sec: float = 1.5
@export var stuck_speed_threshold: float = 0.35
@export var stuck_move_threshold: float = 0.12
## 卡住後先回退幾格軌跡點。
@export var stuck_trail_rewind: int = 6
## 卡住累積達此秒數且不在鏡頭內 → 傳送兜底。
@export var stuck_teleport_sec: float = 4.0
## 與隊長距離超過此值且不在鏡頭內 → 傳送。
@export var teleport_distance: float = 12.0
@export var teleport_behind_dist: float = 1.5
