extends HBoxContainer

signal discard_requested(plant_id: StringName)

const DISCARD_DEFAULT_COLOR := Color(0, 0.015686275, 0.03137255, 1)
const DISCARD_HOVER_COLOR := Color(0.85, 0.08, 0.06, 1)

@onready var name_label: Label = $NameContainer/NameLabel
@onready var invasive_warning_label: Label = $NameContainer/InvasiveWarningLabel
@onready var magic_warning_label: Label = $NameContainer/MagicWarningLabel
@onready var mortal_warning_label: Label = $NameContainer/MortalWarningLabel
@onready var amount_label: Label = $AmountLabel
@onready var discard_button: Label = $DiscardButton

var plant_id: StringName


func setup(new_plant_id: StringName, display_name: String, amount: int) -> void:
	# A TextureRect icon slot can be added before NameLabel later.
	plant_id = new_plant_id
	name_label.text = display_name
	amount_label.text = "x" + str(amount)
	discard_button.modulate.a = 1.0 if InventoryManager.can_discard_item(plant_id) else 0.45
	_update_warning_labels(ItemDatabase.get_plant(plant_id))


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
	SoundManager.play_simple_sound("Actions/Hover")


func _on_discard_button_mouse_exited() -> void:
	discard_button.add_theme_color_override("font_color", DISCARD_DEFAULT_COLOR)


func _update_warning_labels(plant_data: PlantData) -> void:
	_setup_warning_label(
		invasive_warning_label,
		InventoryManager.INVASIVE_WARNING_TEXT,
		InventoryManager.INVASIVE_WARNING_TOOLTIP,
		InventoryManager.should_show_invasive_warning(plant_data)
	)
	_setup_warning_label(
		magic_warning_label,
		InventoryManager.MAGIC_WARNING_TEXT,
		InventoryManager.MAGIC_WARNING_TOOLTIP,
		InventoryManager.should_show_magic_warning(plant_data)
	)
	_setup_warning_label(
		mortal_warning_label,
		InventoryManager.MORTAL_WARNING_TEXT,
		InventoryManager.MORTAL_WARNING_TOOLTIP,
		InventoryManager.should_show_mortal_warning(plant_data)
	)


func _setup_warning_label(warning_label: Label, warning_text: String, tooltip: String, should_show: bool) -> void:
	warning_label.text = warning_text
	if warning_label.has_method(&"set_custom_tooltip_text"):
		warning_label.set_custom_tooltip_text(tr(tooltip))
	else:
		warning_label.tooltip_text = tr(tooltip)
	warning_label.visible = should_show
