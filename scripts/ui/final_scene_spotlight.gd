extends CanvasLayer
class_name FinalSceneSpotlight

const SPOTLIGHT_SHADER_CODE := """
shader_type canvas_item;

uniform vec2 center_uv = vec2(0.5, 0.5);
uniform vec2 viewport_size = vec2(320.0, 180.0);
uniform float radius_pixels = 72.0;
uniform float softness_pixels = 10.0;
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 screen_pixels = SCREEN_UV * viewport_size;
	vec2 center_pixels = center_uv * viewport_size;
	float distance_to_center = distance(screen_pixels, center_pixels);
	float visible_mask = smoothstep(radius_pixels, radius_pixels + softness_pixels, distance_to_center);
	COLOR = vec4(dim_color.rgb, dim_color.a * visible_mask);
}
"""

@export var radius_pixels := 72.0
@export var softness_pixels := 10.0
@export var dim_color := Color.BLACK

var focus_node: Node2D
var focus_world_position := Vector2.ZERO

var _material: ShaderMaterial


func _ready() -> void:
	layer = 80

	var shader := Shader.new()
	shader.code = SPOTLIGHT_SHADER_CODE

	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("radius_pixels", radius_pixels)
	_material.set_shader_parameter("softness_pixels", softness_pixels)
	_material.set_shader_parameter("dim_color", dim_color)

	var overlay := ColorRect.new()
	overlay.color = Color.WHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.material = _material
	add_child(overlay)

	_update_center()


func _process(_delta: float) -> void:
	_update_center()


func set_focus_node(node: Node2D) -> void:
	focus_node = node
	if is_instance_valid(focus_node):
		focus_world_position = focus_node.global_position
	_update_center()


func set_focus_world_position(world_position: Vector2) -> void:
	focus_node = null
	focus_world_position = world_position
	_update_center()


func _update_center() -> void:
	if not is_instance_valid(_material):
		return

	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_material.set_shader_parameter("viewport_size", viewport_size)

	if is_instance_valid(focus_node):
		var screen_position := focus_node.get_global_transform_with_canvas().origin
		_material.set_shader_parameter("center_uv", screen_position / viewport_size)
		return

	var world_position := focus_world_position
	var screen_position := get_viewport().get_canvas_transform() * world_position
	_material.set_shader_parameter("center_uv", screen_position / viewport_size)
