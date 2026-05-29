extends HBoxContainer

signal discard_requested(plant_id: StringName)

const DISCARD_DEFAULT_COLOR := Color(0, 0.015686275, 0.03137255, 1)
const DISCARD_HOVER_COLOR := Color(0.85, 0.08, 0.06, 1)

@onready var name_label: Label = $NameContainer/NameLabel
@onready var invasive_warning_label: Label = $NameContainer/InvasiveWarningLabel
@onready var amount_label: Label = $AmountLabel
@onready var discard_button: Label = $DiscardButton

var plant_id: StringName


func setup(new_plant_id: StringName, display_name: String, amount: int) -> void:
	# A TextureRect icon slot can be added before NameLabel later.
	plant_id = new_plant_id
	name_label.text = display_name
	amount_label.text = "x" + str(amount)
	discard_button.modulate.a = 1.0 if InventoryManager.can_discard_item(plant_id) else 0.45
	_update_invasive_warning(InventoryManager.get_plant_marks(plant_id))


func _ready() -> void:
	discard_button.add_theme_color_override("font_color", DISCARD_DEFAULT_COLOR)
	discard_button.mouse_entered.connect(_on_discard_button_mouse_entered)
	discard_button.mouse_exited.connect(_on_discard_button_mouse_exited)
	discard_button.gui_input.connect(_on_discard_button_gui_input)


func _on_discard_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if InventoryManager.can_discard_item(plant_id):
			discard_requested.emit(plant_id)


func _on_discard_button_mouse_entered() -> void:
	discard_button.add_theme_color_override("font_color", DISCARD_HOVER_COLOR)


func _on_discard_button_mouse_exited() -> void:
	discard_button.add_theme_color_override("font_color", DISCARD_DEFAULT_COLOR)


func _update_invasive_warning(marks: Dictionary) -> void:
	invasive_warning_label.text = InventoryManager.INVASIVE_WARNING_TEXT
	invasive_warning_label.visible = InventoryManager.should_show_invasive_warning(marks)
