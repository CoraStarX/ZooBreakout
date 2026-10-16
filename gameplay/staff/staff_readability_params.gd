class_name StaffReadabilityParams
extends Resource
## 僅移動沙盒讀取；不修改正式員工、Clock 或全域 Alert。
@export var ai: StaffAiParams = preload("res://content/staff/readability_staff_ai_params.tres")
@export_group("地面感知")
@export var grid_unit_m: float = 1.0
@export var roof_edge_cells: float = 0.5
@export var climb_visibility_mult: float = 1.5
@export_range(8, 180) var fan_segments: int = 64
@export var corner_angle_epsilon: float = 0.0001
@export var ground_height_tolerance: float = 0.15
@export var ground_y: float = 0.0
## 事件腳下支撐射線與接地殘高容差；需實際命中地面才成立。
@export var ground_probe_height: float = 0.25
@export var contact_height: float = 0.5
@export_group("聽覺增量")
## 只節流沙盒員工的接收；已驗收移動端發聲接口維持凍結。
@export var climb_noise_cooldown_sec: float = 1.5
@export_range(0.0, 1.0) var hearing_far_gain_mult: float = 0.2
@export_group("搜索／歇崗")
@export var search_sec: float = 8.0
@export_range(1.0, 2.0) var search_max_mult: float = 2.0
@export var search_cooldown_sec: float = 5.0
@export var same_source_radius: float = 0.75
@export var rest_sec: float = 6.0
@export_range(0.1, 1.0) var rest_hearing_mult: float = 0.6
## 即使來源資料誤設為零，歇崗也保留最低聽距。
@export_range(0.01, 1.0) var rest_hearing_floor: float = 0.1
## ? 最短停留；沿用現值，觀察值不是固定階段時長。
@export var warning_stage_sec: float = 0.15
## ! 與 !! 原先沒有獨立最短時長，預設0保留現行節奏，不改成觀察值。
@export var investigate_stage_min_sec: float = 0.0
@export var chase_stage_min_sec: float = 0.0
@export var arrival_distance: float = 0.45
@export var investigate_sec: float = 3.0
@export var arrival_cooldown_sec: float = 3.0
@export var arrival_pause_sec: float = 0.75
@export var navigation_retry_sec: float = 1.0
@export_group("統計／佔位呈現")
@export var metrics_interval_sec: float = 0.1
@export var metrics_limit: int = 1800
@export var event_limit: int = 200
@export var fan_lift: float = 0.035
@export var fan_color: Color = Color(1, 0.65, 0.12, 0.3)
@export var icon_height: float = 1.4
@export var body_radius: float = 0.4
@export var body_height: float = 0.8
@export var body_color: Color = Color(0.9, 0.2, 0.2)
@export var occlusion_alpha: float = 0.22
@export var occlusion_layers: int = 8
@export var border_width: float = 12.0
@export var feedback_sec: float = 0.65
@export var tone_hz: float = 440.0
@export var tone_sec: float = 0.12
@export var tone_mix_rate: int = 22050
@export var tone_db: float = -24.0

@export var status_width: float = 344.0
@export var status_margin: float = 16.0
@export var status_top: float = 80.0
@export var status_height: float = 70.0
@export var status_font_size: int = 18
@export var feedback_color: Color = Color(1,0.2,0.1,0.65)
@export var displayed_events: int = 12
@export var displayed_samples: int = 20

@export var movement_summary_lines: int = 8
