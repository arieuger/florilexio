@tool
extends VBoxContainer

signal remove_requested(editor: Control)
signal objective_id_changed

var heading: Label
var objective_id_field: LineEdit
var description_field: TextEdit
var event_selector: OptionButton
var target_type_selector: OptionButton
var target_id_field: LineEdit
var target_id_selector_label: Label
var target_id_selector: OptionButton
var required_amount_field: SpinBox
var submission_mode_label: Label
var submission_mode_selector: OptionButton
var show_in_notebook_field: CheckBox


func _ready() -> void:
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 13)
	add_child(heading)

	objective_id_field = _add_line_field("Objective ID")
	objective_id_field.text_changed.connect(
		func(_new_text: String) -> void:
			objective_id_changed.emit()
	)

	_add_label("Descrición (opcional)")
	description_field = TextEdit.new()
	description_field.custom_minimum_size.y = 56
	description_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(description_field)

	_add_label("Event type")
	event_selector = OptionButton.new()
	add_child(event_selector)
	_populate_event_types()
	event_selector.item_selected.connect(_on_event_type_selected)

	_add_label("Target type")
	target_type_selector = OptionButton.new()
	add_child(target_type_selector)
	_populate_target_types(QuestObjectiveDefinition.EventType.NONE)

	target_id_selector_label = _add_label("Target existente (opcional)")

	target_id_selector = OptionButton.new()
	target_id_selector.item_selected.connect(_on_target_id_selected)
	add_child(target_id_selector)

	target_id_field = _add_line_field("Target ID")

	target_type_selector.item_selected.connect(_on_target_type_selected)

	_refresh_target_id_options()

	submission_mode_label = _add_label("Item submission mode")
	submission_mode_selector = OptionButton.new()
	add_child(submission_mode_selector)

	for mode in QuestObjectiveDefinition.ItemSubmissionMode.values():
		submission_mode_selector.add_item(QuestObjectiveDefinition.ItemSubmissionMode.keys()[mode])
		submission_mode_selector.set_item_metadata(submission_mode_selector.item_count - 1, mode)

	_refresh_submission_mode_visibility()

	_add_label("Required amount")
	required_amount_field = SpinBox.new()
	required_amount_field.min_value = 1
	required_amount_field.max_value = 999
	required_amount_field.step = 1
	required_amount_field.value = 1
	add_child(required_amount_field)

	show_in_notebook_field = CheckBox.new()
	show_in_notebook_field.text = "Mostrar na libreta"
	show_in_notebook_field.button_pressed = true
	add_child(show_in_notebook_field)

	var remove_button := Button.new()
	remove_button.text = "Eliminar obxetivo"
	remove_button.pressed.connect(
		func() -> void:
			remove_requested.emit(self)
	)
	add_child(remove_button)

	var separator := HSeparator.new()
	add_child(separator)


func set_objective_number(number: int) -> void:
	heading.text = "Obxetivo %d" % number


func build_definition() -> QuestObjectiveDefinition:
	var objective := QuestObjectiveDefinition.new()

	objective.objective_id = NarrativeResourceFactory.normalize_id(objective_id_field.text)
	objective.description = description_field.text.strip_edges()
	objective.event_type = int(event_selector.get_selected_metadata())
	objective.target_type = int(target_type_selector.get_selected_metadata())
	objective.target_id = StringName(target_id_field.text.strip_edges())
	objective.required_amount = int(required_amount_field.value)
	objective.item_submission_mode = int(submission_mode_selector.get_selected_metadata())
	objective.show_in_notebook = show_in_notebook_field.button_pressed

	return objective


func get_objective_id() -> StringName:
	return NarrativeResourceFactory.normalize_id(objective_id_field.text)


func _populate_event_types() -> void:
	event_selector.clear()

	for event_type in QuestObjectiveDefinition.EventType.values():
		event_selector.add_item(QuestObjectiveDefinition.EventType.keys()[event_type])
		event_selector.set_item_metadata(event_selector.item_count - 1, event_type)


func _populate_target_types(event_type: int) -> void:
	target_type_selector.clear()
	target_type_selector.add_item("Selecciona un target type")
	target_type_selector.set_item_metadata(0, QuestObjectiveDefinition.TargetType.NONE)

	var allowed_types := QuestObjectiveDefinition.get_allowed_target_types(event_type)

	for target_type in allowed_types:
		target_type_selector.add_item(QuestObjectiveDefinition.TargetType.keys()[target_type])
		target_type_selector.set_item_metadata(target_type_selector.item_count - 1, target_type)

	if allowed_types.size() == 1:
		target_type_selector.select(1)


func _on_event_type_selected(index: int) -> void:
	var event_type := int(event_selector.get_item_metadata(index))

	target_id_field.clear()
	_populate_target_types(event_type)
	_refresh_target_id_options()
	_refresh_submission_mode_visibility()


func _on_target_type_selected(_index: int) -> void:
	target_id_field.clear()
	_refresh_target_id_options()


func _add_line_field(label_text: String) -> LineEdit:
	_add_label(label_text)

	var field := LineEdit.new()
	add_child(field)
	return field


func _add_label(label_text: String) -> Label:
	var label := Label.new()
	label.text = label_text
	add_child(label)
	return label


func _on_target_id_selected(index: int) -> void:
	if index <= 0:
		target_id_field.clear()
		return

	target_id_field.text = str(target_id_selector.get_item_metadata(index))


func _refresh_target_id_options() -> void:
	target_id_selector.clear()

	var target_type := int(
		target_type_selector.get_selected_metadata()
	)
	var index := NarrativeIndex.build()
	var records: Array = []

	match target_type:
		QuestObjectiveDefinition.TargetType.CONVERSATION:
			records = index.conversations.duplicate()

		QuestObjectiveDefinition.TargetType.PLANT_SPECIES:
			records = index.plants.duplicate()

		QuestObjectiveDefinition.TargetType.ITEM_ID:
			for record in index.items:
				var item := record.get("resource") as ItemData
				if item != null and not item is PlantData:
					records.append(record)

		_:
			target_id_selector_label.visible = false
			target_id_selector.visible = false
			target_id_field.editable = true
			return

	target_id_selector_label.visible = true
	target_id_selector.visible = true

	var allows_manual_target := (
		target_type
		== QuestObjectiveDefinition.TargetType.CONVERSATION
	)
	target_id_selector_label.text = (
		"Target existente (opcional)"
		if allows_manual_target
		else "Target existente"
	)
	target_id_field.editable = allows_manual_target

	target_id_selector.add_item("Selecciona un target")
	target_id_selector.set_item_metadata(0, "")

	records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first["id"]) < str(second["id"])
	)

	for record in records:
		var target_id := StringName(record.get("id", &""))
		if target_id.is_empty():
			continue

		var label := str(target_id)
		var resource := record.get("resource") as Resource

		if resource is ItemData:
			var item := resource as ItemData
			label = "%s (%s)" % [item.display_name, item.id]

		var item_index := target_id_selector.item_count
		target_id_selector.add_item(label)
		target_id_selector.set_item_metadata(item_index, target_id)


func _refresh_submission_mode_visibility() -> void:
	var event_type := int(
		event_selector.get_selected_metadata()
	)
	var is_item_submission := (
		event_type
		== QuestObjectiveDefinition.EventType.ITEM_SUBMITTED
	)

	submission_mode_label.visible = is_item_submission
	submission_mode_selector.visible = is_item_submission
