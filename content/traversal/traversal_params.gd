class_name TraversalParams
extends Resource
## 移動、碰撞與呈現參數；共用於角色與驗證宿主。

@export_group("角色")
@export var speed: float = 5.5
@export var gravity: float = 22.0
@export var radius: float = 0.32
@export var height: float = 1.0
@export var floor_snap: float = 0.2
@export var collision_margin: float = 0.0
## 引擎移動的接觸安全邊距；與完整膠囊預檢相容，避免預設 0.001 留下微量交疊。
@export_range(0.001, 0.02) var body_safe_margin: float = 0.005
@export_flags_3d_physics var world_mask: int = 1
@export_group("邊緣保護")
@export var edge_guard_enabled: bool = true
## 超過此落差視為懸崖；低台階與斜坡仍可走下。
@export_range(0.05, 0.6) var edge_max_drop: float = 0.35
@export_range(0.01, 0.4) var edge_safety_margin: float = 0.05
@export_range(0.05, 0.5) var edge_probe_up: float = 0.25
@export_range(0.05, 0.3) var edge_path_step: float = 0.15
@export_range(4, 16) var edge_probe_count: int = 8
## 膠囊在斜坡接縫的腳底懸空量；不計入允許下落的地面落差。
@export var edge_ground_clearance: float = 0.12
@export_group("跳躍")
@export var max_jump_distance: float = 4.8
@export var max_jump_height: float = 1.2
@export var takeoff_range: float = 1.4
@export var selection_hysteresis: float = 0.18
@export var jump_duration: float = 0.5
@export var jump_arc: float = 0.65
@export_range(4, 64) var path_samples: int = 24
@export var landing_lift: float = 0.04
@export var support_depth: float = 0.18
@export var support_normal_min: float = 0.7
@export_group("攀爬")
@export var climb_speed: float = 2.0
@export var attach_range: float = 0.65
@export var wall_clearance: float = 0.08
@export var mantle_depth: float = 0.65
@export var mantle_duration: float = 0.38
@export var mantle_arc: float = 0.12
@export var arrival_tolerance: float = 0.06
@export_group("提示")
@export var feedback_sec: float = 2.2
@export var marker_radius: float = 0.42
@export var shadow_range: float = 15.0
@export var shadow_lift: float = 0.015
@export_range(0.05, 0.9) var occluder_alpha: float = 0.22
@export_range(1, 8) var occluder_layers: int = 4
@export var input_deadzone: float = 0.15

@export_group("意圖與容錯")
@export_range(0, 89) var attach_intent_degrees: float = 45.0
@export var attach_intent_sec: float = 0.15
@export var reattach_delay: float = 0.3
@export var attach_transition_sec: float = 0.16
@export var roof_attach_range: float = 0.85
@export var roof_hang_depth: float = 0.4
@export var roof_transition_sec: float = 0.28
@export var coyote_sec: float = 0.1
@export var jump_buffer_sec: float = 0.1
@export var jump_snap_sec: float = 0.1
@export var jump_snap_min_distance: float = 0.18
@export_group("主動下行")
@export var drop_forward_distance: float = 1.2
@export var drop_max_height: float = 4.0
@export var drop_lift: float = 0.12
@export var drop_duration: float = 0.55
@export var release_push_distance: float = 0.1
@export_group("噪音與落地")
@export var landing_noise_min_height: float = 0.8
@export var landing_noise_per_meter: float = 0.25
@export var landing_noise_max: float = 1.25
@export var jump_noise: float = 0.12
@export var climb_noise: float = 0.08
@export var climb_noise_interval_m: float = 0.9
@export var landing_feedback_min_height: float = 0.1
@export var landing_squash_sec: float = 0.14
@export var landing_squash_y: float = 0.85
@export var landing_tone_mix_rate: int = 22050
@export var landing_tone_hz: float = 160.0
@export var landing_tone_sec: float = 0.06
@export var landing_tone_db: float = -24.0
@export_group("恢復與統計")
@export var stuck_sec: float = 1.5
@export var recovery_timeout_sec: float = 3.0
@export var stuck_speed: float = 0.06
@export var safe_history_spacing: float = 0.4
@export var safe_history_limit: int = 32
@export var recovery_sample_radius: float = 3.0
@export var recovery_sample_count: int = 16
@export var recovery_probe_depth: float = 12.0
@export var accidental_fall_height: float = 0.6
@export var metrics_history_limit: int = 20
@export var metrics_refresh_sec: float = 0.1
@export var metrics_panel_width: float = 600.0
@export var metrics_panel_height: float = 440.0
@export var metrics_panel_top: float = 80.0
@export var metrics_target_loops: int = 5
@export var metrics_max_extra_inputs: int = 2
@export var metrics_max_accidents: int = 1
@export var metrics_segment_slow_ratio: float = 1.5

@export var metrics_faster_epsilon_sec: float = 0.01

@export var metrics_background_alpha: float = 0.94
@export var metrics_panel_margin: int = 10
@export var metrics_button_min_size: Vector2 = Vector2(110, 32)

@export_group("移動診斷")
## 僅卡住偵測縮小查詢體積，排除碰撞求解器的表面微量接觸；實際碰撞不縮小。
@export var stuck_penetration_tolerance: float = 0.02
@export var diagnostic_input_sec: float = 1.0
@export var diagnostic_input_limit: int = 240
@export var diagnostic_event_limit: int = 64
@export var diagnostic_recovery_limit: int = 5
@export var diagnostic_log_path: String = "user://movement_diagnostics.jsonl"
@export var metrics_route_target: int = 5

## 在邊緣保護生效前提供下行預覽，避免合法按鍵區只剩貼邊瞬間。
@export var drop_preview_distance: float = 0.35

@export_group("邊緣意圖")
## 移動方向的容錯，不讀精靈朝向；斜向接近間隙仍可跨越。
@export_range(1, 89) var cross_intent_degrees: float = 65.0
@export var edge_intent_probe_distance: float = 1.4
## 兩條邊緣同時接近時優先外緣下行；離開轉角後間隙仍優先。
@export var edge_intent_tie_distance: float = 0.05

## 僅用於入口情境辨識；真正起跳仍受 takeoff_range 與路徑檢查約束。
@export var cross_context_height_tolerance: float = 0.18
@export var cross_context_extra_range: float = 0.6

## 僅在附牆意圖成立後處理微量接觸；一般接地不呼叫，避免貼地／抬升循環。
@export_range(0.001, 0.05) var ground_contact_lift: float = 0.02
