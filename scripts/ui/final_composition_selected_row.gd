extends HBoxContainer

signal remove_requested(index: int)

const REMOVE_DEFAULT_COLOR := Color(0, 0.015686275, 0.03137255, 1)
const REMOVE_HOVER_COLOR := Color(0.85, 0.08, 0.06, 1)

@onready var name_label: Label = $NameLabel
@onready var remove_button: Label = $RemoveButton

var index := -1


func setup(new_index: int, display_name: String) -> void:
	index = new_index
	name_label.text = display_name


func _ready() -> void:
	remove_button.add_theme_color_override("font_color", REMOVE_DEFAULT_COLOR)
	remove_button.mouse_entered.connect(_on_remove_button_mouse_entered)
	remove_button.mouse_exited.connect(_on_remove_button_mouse_exited)
	remove_button.gui_input.connect(_on_remove_button_gui_input)


func _on_remove_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		remove_requested.emit(index)


func _on_remove_button_mouse_entered() -> void:
	remove_button.add_theme_color_override("font_color", REMOVE_HOVER_COLOR)


func _on_remove_button_mouse_exited() -> void:
	remove_button.add_theme_color_override("font_color", REMOVE_DEFAULT_COLOR)
