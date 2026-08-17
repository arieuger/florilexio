@tool
extends VBoxContainer

signal remove_requested(editor: Control)

var heading: Label
var description_field: TextEdit
var objectives_list: ItemList
var empty_options_label: Label


func _ready() -> void:
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 13)
	add_child(heading)

	var description_label := Label.new()
	description_label.text = "Descrición"
	add_child(description_label)

	description_field = TextEdit.new()
	description_field.custom_minimum_size.y = 56
	description_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(description_field)

	var objectives_label := Label.new()
	objectives_label.text = "Obxectivos representados"
	add_child(objectives_label)

	objectives_list = ItemList.new()
	objectives_list.select_mode = ItemList.SELECT_MULTI
	objectives_list.custom_minimum_size.y = 96
	add_child(objectives_list)

	empty_options_label = Label.new()
	empty_options_label.text = "Engade un ID válido a algún obxectivo para poder seleccionalo."
	empty_options_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(empty_options_label)

	var remove_button := Button.new()
	remove_button.text = "Eliminar grupo"
	remove_button.pressed.connect(
		func() -> void:
			remove_requested.emit(self)
	)
	add_child(remove_button)

	add_child(HSeparator.new())


func set_group_number(number: int) -> void:
	heading.text = "Grupo de obxectivos %d" % number


func set_objective_options(options: Array[Dictionary]) -> void:
	var selected_keys := {}

	for selected_index in objectives_list.get_selected_items():
		var metadata: Dictionary = objectives_list.get_item_metadata(selected_index)
		selected_keys[metadata.get("key")] = true

	objectives_list.clear()

	for option in options:
		var objective_id := StringName(option.get("id", &""))
		if objective_id.is_empty():
			continue

		var label := str(objective_id)
		if bool(option.get("duplicate", false)):
			label += " (duplicado — inválido)"

		var item_index := objectives_list.item_count
		objectives_list.add_item(label)
		objectives_list.set_item_metadata(item_index, option)

		if selected_keys.has(option.get("key")):
			objectives_list.select(item_index, false)

	empty_options_label.visible = objectives_list.item_count == 0
	objectives_list.visible = objectives_list.item_count > 0


func build_definition() -> QuestObjectiveGroupDefinition:
	var definition := QuestObjectiveGroupDefinition.new()
	definition.description = description_field.text.strip_edges()

	for selected_index in objectives_list.get_selected_items():
		var metadata: Dictionary = objectives_list.get_item_metadata(selected_index)
		definition.objective_ids.append(StringName(metadata.get("id", &"")))

	return definition
