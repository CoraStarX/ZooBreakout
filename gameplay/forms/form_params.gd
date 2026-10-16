class_name FormParams
extends Resource
const MIN_WITNESS_WINDUP_SEC: float = 0.5
@export var switch_action: StringName = &"transform"
@export var show_guidance_default: bool = true
@export var form_cooldown_sec: float = 2.5
@export var effect_sec: float = 0.3
@export_group("變形推開")
@export var push_max_distance: float = 0.32
@export_range(4,64) var push_direction_count: int = 32
@export_range(1,32) var push_radial_steps: int = 16
@export_range(0,12) var push_refine_steps: int = 6
@export var push_path_step: float = 0.04
## 僅容忍支撐射線的數值誤差；候選位置本身不改Y，不能換高度層。
@export var push_height_tolerance: float = 0.02
@export_group("變形回饋")
@export var transform_noise: float = 1.0
## 與StaffAiParams.hear_noise_range同為XZ世界距離；C接收端才啟用此上限。
@export var transform_hearing_radius: float = 3.0
@export var witness_windup_sec: float = 0.5
@export var safe_history_limit: int = 32
@export var safe_history_spacing: float = 0.4
@export var effect_radius: float = 0.65
@export var effect_lift: float = 0.03
@export var effect_color := Color(0.75,0.65,1,0.65)
@export var switch_tone_hz: float = 480.0
@export var switch_tone_sec: float = 0.06
@export var switch_tone_rate: int = 22050
@export var switch_tone_db: float = -28.0
