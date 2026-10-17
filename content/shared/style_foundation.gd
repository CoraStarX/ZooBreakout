class_name StyleFoundation
extends Node3D
## 可重用環境 preset；所有建築共用一個材質，所有機制標記共用另一個。
@export var settings: StyleSettings = preload("res://content/shared/style_settings.tres")
var surface_material: ShaderMaterial
var mechanism_material: ShaderMaterial
var active_palette: StylePalette
var _environment: Environment

func _init() -> void:
	surface_material = preload("res://content/shared/architecture_material.tres").duplicate() as ShaderMaterial
	mechanism_material = preload("res://content/shared/mechanism_material.tres").duplicate() as ShaderMaterial

func _ready() -> void:
	var world := get_node("WorldEnvironment") as WorldEnvironment
	_environment = world.environment.duplicate() as Environment
	world.environment = _environment
	apply_palette(settings.palette)
	mechanism_material.set_shader_parameter("climb_color", settings.climb_color)
	mechanism_material.set_shader_parameter("jump_color", settings.jump_color)
	mechanism_material.set_shader_parameter("ink_color", settings.marker_ink)
	mechanism_material.set_shader_parameter("outline_pixels", settings.marker_outline_pixels)
	surface_material.set_shader_parameter("outline_pixels", settings.outline_pixels)
	surface_material.set_shader_parameter("toon_steps", settings.toon_steps)
	set_features(settings.post_enabled, settings.outline_enabled, settings.toon_enabled)

func apply_palette(palette: StylePalette) -> void:
	active_palette = palette
	surface_material.set_shader_parameter("building_color", palette.building)
	surface_material.set_shader_parameter("platform_color", palette.platform)
	surface_material.set_shader_parameter("ground_color", palette.ground)
	surface_material.set_shader_parameter("highlight_color", palette.highlight)
	surface_material.set_shader_parameter("ink_color", palette.ink)
	if _environment:
		_environment.background_color = palette.ink
		_environment.ambient_light_color = palette.highlight
		_environment.fog_light_color = palette.highlight
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_color = palette.highlight

func set_features(post: bool, outline: bool, toon: bool) -> void:
	_environment.fog_enabled = post
	_environment.ssao_enabled = post
	_environment.glow_enabled = post
	surface_material.set_shader_parameter("outline_enabled", outline)
	surface_material.set_shader_parameter("toon_enabled", toon)

func configure_block(visual: MeshInstance3D, block: Dictionary) -> void:
	visual.material_override = surface_material
	visual.set_instance_shader_parameter("color_role", settings.block_roles.get(StringName(block.get("name", "")), 0))
	visual.set_instance_shader_parameter("shape_size", block["size"])
	visual.set_instance_shader_parameter("ramp_shape", block.get("shape", "box") == "ramp")

func configure_marker(visual: MeshInstance3D, climb: bool) -> void:
	visual.material_override = mechanism_material
	visual.set_instance_shader_parameter("climb_marker", climb)
	visual.set_instance_shader_parameter("shape_size", (visual.mesh as BoxMesh).size)
