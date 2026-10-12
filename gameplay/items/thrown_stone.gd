class_name ThrownStone
extends Node3D
## Visual-only pebble: arcs to `land_at`, then makes a noise there (kind `throw`) and fades out.

const KIND := &"throw"
const ARC_HEIGHT := 1.6

var from: Vector3
var land_at: Vector3
var flight_sec: float = 0.45
var loudness: float = 0.7
var landed: bool = false
var _t: float = 0.0
var _mesh: MeshInstance3D


static func launch(parent: Node, p_from: Vector3, p_land: Vector3, p_flight: float, p_loudness: float) -> ThrownStone:
	var s := ThrownStone.new()
	s.name = "ThrownStone"
	s.from = p_from
	s.land_at = p_land
	s.flight_sec = maxf(0.05, p_flight)
	s.loudness = p_loudness
	parent.add_child(s)
	s.global_position = p_from
	return s


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.58, 0.52)
	_mesh.material_override = mat
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	if landed:
		return
	_t += delta
	var k := clampf(_t / flight_sec, 0.0, 1.0)
	var p := from.lerp(land_at, k)
	p.y += sin(k * PI) * ARC_HEIGHT
	global_position = p
	if k >= 1.0:
		_land()


func _land() -> void:
	landed = true
	Bus.noise_made.emit(land_at, loudness, KIND)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(queue_free)
