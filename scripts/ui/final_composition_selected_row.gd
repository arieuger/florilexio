extends HBoxContainer

signal remove_requested(index: int)

const REMOVE_DEFAULT_COLOR := Color(0, 0.015686275, 0.03137255, 1)
const REMOVE_HOVER_COLOR := Color(0.85, 0.08, 0.06, 1)

@onready var name_label: Label = $NameContainer/NameLabel
@onready var invasive_warning_label: Label = $NameContainer/InvasiveWarningLabel
@onready var magic_warning_label: Label = $NameContainer/MagicWarningLabel
@onready var remove_button: Label = $RemoveButton

var index := -1


func setup(new_index: int, display_name: String, marks: Dictionary = {}) -> void:
	index = new_index
	name_label.text = display_name
	_update_warning_labels(marks)


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


func _update_warning_labels(marks: Dictionary) -> void:
	_setup_warning_label(
		invasive_warning_label,
		InventoryManager.INVASIVE_WARNING_TEXT,
		InventoryManager.INVASIVE_WARNING_TOOLTIP,
		InventoryManager.should_show_invasive_warning(marks)
	)
	_setup_warning_label(
		magic_warning_label,
		InventoryManager.MAGIC_WARNING_TEXT,
		InventoryManager.MAGIC_WARNING_TOOLTIP,
		InventoryManager.should_show_magic_warning(marks)
	)


func _setup_warning_label(warning_label: Label, warning_text: String, tooltip: String, should_show: bool) -> void:
	warning_label.text = warning_text
	if warning_label.has_method(&"set_custom_tooltip_text"):
		warning_label.set_custom_tooltip_text(tooltip)
	else:
		warning_label.tooltip_text = tooltip
	warning_label.visible = should_show
