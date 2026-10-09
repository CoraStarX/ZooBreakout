class_name FollowCamera
extends Node3D
## HD2D-style 45° follow camera. Rig sits at look target; Camera3D is offset child.

@export var follow_distance: float = 22.0
@export var yaw_degrees: float = 45.0
@export var pitch_degrees: float = 45.0
@export var look_height: float = 0.55
@export var ortho_size: float = 14.0
@export var follow_smooth: float = 10.0 ## higher = snappier
@export var snap_on_switch: bool = true

@onready var _camera: Camera3D = $Camera3D

var _target: Node3D
var _look_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	_apply_camera_angle()
	if _camera:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = ortho_size
		_camera.current = true
		_camera.far = 200.0
	Bus.animal_switched.connect(_on_animal_switched)
	# Resolve initial target next frame after zoo_world spawns party.
	call_deferred("_bind_initial_target")


func _bind_initial_target() -> void:
	var world := get_tree().get_first_node_in_group("zoo_world")
	if world and world.has_method("controlled_animal"):
		var a: Node3D = world.call("controlled_animal") as Node3D
		if a:
			set_follow_target(a, true)


func _on_animal_switched(animal: Node3D) -> void:
	set_follow_target(animal, snap_on_switch)


func set_follow_target(target: Node3D, immediate: bool = false) -> void:
	_target = target
	if target == null:
		return
	var desired := _target_look_pos()
	if immediate:
		_look_pos = desired
		global_position = _look_pos
		_apply_camera_angle()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var desired := _target_look_pos()
	var t := 1.0 - exp(-follow_smooth * delta)
	_look_pos = _look_pos.lerp(desired, t)
	global_position = _look_pos
	_apply_camera_angle()


func _target_look_pos() -> Vector3:
	var p := _target.global_position
	p.y = look_height
	return p


func _apply_camera_angle() -> void:
	if _camera == null:
		_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		return
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	# Offset from look point: classic 45°/45° isometric-ish HD2D.
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * follow_distance
	_camera.position = offset
	_camera.look_at(global_position, Vector3.UP)
	_camera.size = ortho_size
