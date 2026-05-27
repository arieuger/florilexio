@tool
extends Node2D
class_name AreaCameraConfig

@export var bounds_size := Vector2(320, 180):
	set(value):
		bounds_size = value
		queue_redraw()

@export var zoom := Vector2(1.33, 1.33):
	set(value):
		zoom = value
		queue_redraw()

@export var preview_viewport_size := Vector2(320, 180):
	set(value):
		preview_viewport_size = value
		queue_redraw()

@export var position_smoothing_enabled := true
@export var drag_horizontal_enabled := true:
	set(value):
		drag_horizontal_enabled = value
		queue_redraw()
@export var drag_vertical_enabled := true:
	set(value):
		drag_vertical_enabled = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var drag_left_margin := 0.15:
	set(value):
		drag_left_margin = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var drag_top_margin := 0.15:
	set(value):
		drag_top_margin = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var drag_right_margin := 0.15:
	set(value):
		drag_right_margin = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var drag_bottom_margin := 0.15:
	set(value):
		drag_bottom_margin = value
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var rect := Rect2(Vector2.ZERO, bounds_size)
	draw_rect(rect, Color(0.3, 0.75, 1.0, 0.08), true)
	draw_rect(rect, Color(0.3, 0.75, 1.0, 0.9), false, 1.0)
	_draw_drag_preview()


func _draw_drag_preview() -> void:
	if not drag_horizontal_enabled and not drag_vertical_enabled:
		return
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		return

	var viewport_size := Vector2(
		preview_viewport_size.x / zoom.x,
		preview_viewport_size.y / zoom.y
	)
	var viewport_position := (bounds_size - viewport_size) * 0.5
	var viewport_rect := Rect2(viewport_position, viewport_size)
	draw_rect(viewport_rect, Color(1.0, 0.9, 0.25, 0.12), true)
	draw_rect(viewport_rect, Color(1.0, 0.9, 0.25, 0.9), false, 1.0)

	var drag_position := viewport_rect.position
	var drag_end := viewport_rect.end
	if drag_horizontal_enabled:
		drag_position.x = viewport_rect.position.x + viewport_rect.size.x * drag_left_margin
		drag_end.x = viewport_rect.end.x - viewport_rect.size.x * drag_right_margin
	if drag_vertical_enabled:
		drag_position.y = viewport_rect.position.y + viewport_rect.size.y * drag_top_margin
		drag_end.y = viewport_rect.end.y - viewport_rect.size.y * drag_bottom_margin

	var drag_rect := Rect2(drag_position, (drag_end - drag_position).max(Vector2.ZERO))
	draw_rect(drag_rect, Color(1.0, 0.45, 0.1, 0.16), true)
	draw_rect(drag_rect, Color(1.0, 0.45, 0.1, 0.95), false, 1.0)

	if drag_horizontal_enabled:
		_draw_vertical_line(drag_rect.position.x, viewport_rect.position.y, viewport_rect.end.y)
		_draw_vertical_line(drag_rect.end.x, viewport_rect.position.y, viewport_rect.end.y)
	if drag_vertical_enabled:
		_draw_horizontal_line(drag_rect.position.y, viewport_rect.position.x, viewport_rect.end.x)
		_draw_horizontal_line(drag_rect.end.y, viewport_rect.position.x, viewport_rect.end.x)


func _draw_vertical_line(x: float, y_start: float, y_end: float) -> void:
	draw_line(Vector2(x, y_start), Vector2(x, y_end), Color(1.0, 0.45, 0.1, 0.95), 1.0)


func _draw_horizontal_line(y: float, x_start: float, x_end: float) -> void:
	draw_line(Vector2(x_start, y), Vector2(x_end, y), Color(1.0, 0.45, 0.1, 0.95), 1.0)


func apply_to(camera: Camera2D) -> void:
	if not is_instance_valid(camera):
		return

	var rect := Rect2(global_position, bounds_size)
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.zoom = zoom
	camera.position_smoothing_enabled = position_smoothing_enabled
	camera.drag_horizontal_enabled = drag_horizontal_enabled
	camera.drag_vertical_enabled = drag_vertical_enabled
	camera.drag_left_margin = drag_left_margin
	camera.drag_top_margin = drag_top_margin
	camera.drag_right_margin = drag_right_margin
	camera.drag_bottom_margin = drag_bottom_margin
	camera.editor_draw_limits = true
	camera.editor_draw_drag_margin = true

	if camera.has_method("reset_smoothing"):
		camera.reset_smoothing()
