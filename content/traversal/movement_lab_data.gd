class_name MovementLabData
extends Resource
## 灰盒配置：幾何、入口、落點與出生位置全部可由資料調整。
@export var spawn: Vector3 = Vector3(-3, 0.04, 2)
@export var blocks: Array[Dictionary] = []
@export var climb_position: Vector3 = Vector3(-3, 0, 0.5)
@export var climb_width: float = 3.0
@export var climb_height: float = 3.0
@export var jumps: Array[Dictionary] = []
@export var camera_size: float = 17.0
@export var labels: Array[Dictionary] = []

@export var loop_return_center: Vector3 = Vector3(-3, 0.04, 2)
@export var loop_return_radius: float = 1.4
