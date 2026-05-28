extends HBoxContainer
class_name FinalCompositionItemRow

const DRAG_DATA_TYPE := "final_composition_plant"

@onready var name_label: Label = $NameLabel
@onready var amount_label: Label = $AmountLabel

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
