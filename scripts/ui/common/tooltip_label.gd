extends Label
class_name TooltipLabel

enum TooltipPlacement { ABOVE, RIGHT }

@export var custom_tooltip_text := ""
@export var tooltip_font_color := Color(1.0, 0.45, 0.0, 1.0)
@export_range(1, 32, 1) var tooltip_font_size := 6
@export var tooltip_offset := Vector2(0, -2)
@export_enum("Above", "Right") var tooltip_placement: int = TooltipPlacement.RIGHT
@export var use_label_font := true

var _tooltip_label: Label


func _ready() -> void:
	if custom_tooltip_text.is_empty():
		custom_tooltip_text = tooltip_text

	tooltip_text = ""
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_show_custom_tooltip)
	mouse_exited.connect(_hide_custom_tooltip)
	visibility_changed.connect(_on_visibility_changed)
	tree_exiting.connect(_hide_custom_tooltip)


func set_custom_tooltip_text(new_tooltip_text: String) -> void:
	custom_tooltip_text = new_tooltip_text
	tooltip_text = ""

	if _tooltip_label:
		_tooltip_label.text = custom_tooltip_text
		_position_tooltip()


func _show_custom_tooltip() -> void:
	if custom_tooltip_text.is_empty() or _tooltip_label:
		return

	_tooltip_label = Label.new()
	_tooltip_label.top_level = true
	_tooltip_label.z_index = 4096
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.text = custom_tooltip_text
	_tooltip_label.add_theme_color_override("font_color", tooltip_font_color)
	_tooltip_label.add_theme_font_size_override("font_size", tooltip_font_size)

	if use_label_font:
		_tooltip_label.add_theme_font_override("font", get_theme_font("font"))

	add_child(_tooltip_label)
	_position_tooltip()


func _hide_custom_tooltip() -> void:
	if not _tooltip_label:
		return

	_tooltip_label.queue_free()
	_tooltip_label = null


func _position_tooltip() -> void:
	if not _tooltip_label:
		return

	var label_size := _tooltip_label.get_combined_minimum_size()
	var source_rect := get_global_rect()
	_tooltip_label.size = label_size

	match tooltip_placement:
		TooltipPlacement.RIGHT:
			_tooltip_label.global_position = Vector2(
				source_rect.end.x + tooltip_offset.x,
				source_rect.position.y + (source_rect.size.y - label_size.y) * 0.5 + tooltip_offset.y
			)
		_:
			_tooltip_label.global_position = Vector2(
				source_rect.position.x + (source_rect.size.x - label_size.x) * 0.5 + tooltip_offset.x,
				source_rect.position.y - label_size.y + tooltip_offset.y
			)


func _on_visibility_changed() -> void:
	if not visible:
		_hide_custom_tooltip()
