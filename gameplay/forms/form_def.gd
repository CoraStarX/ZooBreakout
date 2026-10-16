class_name FormDef
extends Resource
const DURATION_INFINITE: float = 0.0
@export var id: StringName
@export var display_name: String = "形態"
@export var abilities: Array[int] = []
## 完整碰撞尺寸（寬／高／深）；本切片使用等寬深膠囊。
@export var body_size := Vector3(0.3,0.3,0.3)
@export var move_speed: float = 4.0
@export var footstep_noise: float = 0.0
@export var visibility_mult: float = 0.6
@export var native_zones: Array[StringName] = []
@export var forbidden_terrain: Array[StringName] = []
@export var duration_sec: float = DURATION_INFINITE
@export var movement_profile: TraversalParams
@export var body_color := Color(0.65,0.42,0.85)
func collision_radius() -> float:
	# Vector3是單精度；資料尺寸未變時沿用凍結配置的精確半徑，不引入量化差。
	if movement_profile != null and is_equal_approx(body_size.x,movement_profile.radius*2): return movement_profile.radius
	return body_size.x*0.5
func movement_params() -> TraversalParams:
	# 新場景以FormDef為體型／速度唯一來源；不改共用的凍結移動資源。
	var result := movement_profile.duplicate(true) as TraversalParams
	result.radius = collision_radius()
	result.height = body_size.y
	result.speed = move_speed
	return result
