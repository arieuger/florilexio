extends HBoxContainer
class_name FinalCompositionItemRow

signal discard_requested(plant_id: StringName)

const DRAG_DATA_TYPE := "final_composition_plant"
const DISCARD_DEFAULT_COLOR := Color(0, 0.015686275, 0.03137255, 1)
const DISCARD_HOVER_COLOR := Color(0.85, 0.08, 0.06, 1)

@onready var name_label: Label = $NameLabel
@onready var amount_label: Label = $AmountLabel
@onready var discard_button: Label = $DiscardButton

var plant_id: StringName
var display_name := ""
var available_amount := 0


func setup(new_plant_id: StringName, new_display_name: String, new_available_amount: int) -> void:
	plant_id = new_plant_id
	display_name = new_display_name
	available_amount = new_available_amount
	name_label.text = display_name
	amount_label.text = "x" + str(available_amount)
	modulate.a = 1.0 if available_amount > 0 else 0.45
	discard_button.modulate.a = 1.0 if available_amount > 0 else 0.45


func _ready() -> void:
	discard_button.add_theme_color_override("font_color", DISCARD_DEFAULT_COLOR)
	discard_button.mouse_entered.connect(_on_discard_button_mouse_entered)
	discard_button.mouse_exited.connect(_on_discard_button_mouse_exited)
	discard_button.gui_input.connect(_on_discard_button_gui_input)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if available_amount <= 0:
		return null

	var preview := Label.new()
	preview.text = display_name
	preview.add_theme_font_override("font", name_label.get_theme_font("font"))
	preview.add_theme_font_size_override("font_size", 6)
	preview.add_theme_color_override("font_color", Color(0.0, 0.015, 0.031, 1.0))
	set_drag_preview(preview)

	return {
		type = DRAG_DATA_TYPE,
		plant_id = plant_id,
		display_name = display_name,
	}


func _on_discard_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if available_amount > 0:
			discard_requested.emit(plant_id)


func _on_discard_button_mouse_entered() -> void:
	discard_button.add_theme_color_override("font_color", DISCARD_HOVER_COLOR)


func _on_discard_button_mouse_exited() -> void:
	discard_button.add_theme_color_override("font_color", DISCARD_DEFAULT_COLOR)
