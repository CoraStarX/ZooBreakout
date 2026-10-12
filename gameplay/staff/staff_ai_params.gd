class_name StaffAiParams
extends Resource
## 職員 AI 可調參數集中處。試玩只改此 Resource（或其實例），勿散落魔術數。

@export_group("Vision / Hearing")
@export var vision_range: float = 7.0
@export var vision_angle_deg: float = 55.0
@export var hear_walk_range: float = 2.15
## Bus noise hearing range at loudness 1 (Alert multipliers stack on this).
@export var hear_noise_range: float = 13.0
@export var catch_range: float = 1.35

@export_group("Awareness (0~100)")
@export var awareness_max: float = 100.0
@export var accumulate_per_sec: float = 42.0
@export var decay_per_sec: float = 20.0
@export var suspicious_threshold: float = 22.0
@export var investigate_threshold: float = 48.0
@export var chase_threshold: float = 78.0
## 進入追擊前最短預警秒數（公平性底線，勿低於 0.5）。
@export var min_telegraph_sec: float = 0.55
@export var lose_target_grace_sec: float = 1.5
@export var search_duration_sec: float = 6.0
@export var search_radius: float = 4.0
@export var return_heat_bonus: float = 35.0

@export_group("Visibility multipliers（可擴充：蹲伏／陰影／掩體）")
@export var mult_in_cone: float = 1.0
@export var mult_blocked_los: float = 0.0
@export var distance_near: float = 2.5
@export var distance_far: float = 7.0
@export var mult_distance_near: float = 1.15
@export var mult_distance_far: float = 0.40
## 靜止／低速近似「蹲伏／潛行」可見度折扣（暫無蹲伏輸入）。
@export var still_speed_threshold: float = 0.45
@export var slow_speed_threshold: float = 1.25
@export var mult_still: float = 0.50
@export var mult_slow: float = 0.75
@export var hearing_awareness_spike: float = 18.0
@export var noise_awareness_spike: float = 28.0

@export_group("Combat / Chase")
@export var move_speed: float = 2.8
@export var chase_speed_mult: float = 1.32
@export var catch_windup_sec: float = 0.28
@export var catch_recovery_sec: float = 0.75
@export var suspect_speed_mult: float = 0.45

@export_group("Look-around（停步微行為）")
@export var look_around_yaw_deg: float = 52.0
@export var look_turn_deg_per_sec: float = 48.0
@export var look_hold_sec: float = 0.70
@export var look_center_hold_sec: float = 0.45

@export_group("Patrol weights（階段 B）")
@export var weight_staleness: float = 1.0
@export var weight_importance: float = 1.2
@export var weight_heat: float = 1.4
@export var weight_distance_penalty: float = 0.08
@export var weight_recent_penalty: float = 2.0
@export var score_noise_min: float = -0.15
@export var score_noise_max: float = 0.15
@export var dwell_sec_min: float = 3.0
@export var dwell_sec_max: float = 8.0
@export var heat_decay_per_sec: float = 4.0
@export var reserve_radius: float = 1.25

@export_group("Player noise tool（階段 B）")
@export var shout_cooldown_sec: float = 6.0
@export var shout_loudness: float = 0.85
@export var footstep_loudness: float = 0.25
@export var run_speed_for_noise: float = 2.4
