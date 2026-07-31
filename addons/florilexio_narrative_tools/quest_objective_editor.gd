@tool
extends VBoxContainer

signal remove_requested(editor: Control)

var heading: Label
var objective_id_field: LineEdit
var event_selector: OptionButton
var target_type_selector: OptionButton
var target_id_field: LineEdit
var target_id_selector_label: Label
var target_id_selector: OptionButton
var required_amount_field: SpinBox


func _ready() -> void:
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 13)
	add_child(heading)

	objective_id_field = _add_line_field("Objective ID")

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

	_add_label("Required amount")
	required_amount_field = SpinBox.new()
	required_amount_field.min_value = 1
	required_amount_field.max_value = 999
	required_amount_field.step = 1
	required_amount_field.value = 1
	add_child(required_amount_field)

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
	objective.event_type = int(event_selector.get_selected_metadata())
	objective.target_type = int(target_type_selector.get_selected_metadata())
	objective.target_id = StringName(target_id_field.text.strip_edges())
	objective.required_amount = int(required_amount_field.value)

	return objective


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

	_populate_target_types(event_type)
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


func _on_target_type_selected(_index: int) -> void:
	_refresh_target_id_options()


func _on_target_id_selected(index: int) -> void:
	if index <= 0:
		return

	target_id_field.text = str(
		target_id_selector.get_item_metadata(index)
	)


func _refresh_target_id_options() -> void:
	target_id_selector.clear()
	target_id_selector.add_item("Introducir ID manualmente")
	target_id_selector.set_item_metadata(0, "")

	var target_type := int(
		target_type_selector.get_selected_metadata()
	)

	var has_existing_targets := target_type == QuestObjectiveDefinition.TargetType.CONVERSATION

	target_id_selector_label.visible = has_existing_targets
	target_id_selector.visible = has_existing_targets

	if not has_existing_targets:
		return

	var index := NarrativeIndex.build()
	var records := index.conversations.duplicate()

	records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first["id"]) < str(second["id"])
	)

	for record in records:
		var conversation_id := str(record.get("id", ""))

		if conversation_id.is_empty():
			continue

		target_id_selector.add_item(conversation_id)
		target_id_selector.set_item_metadata(target_id_selector.item_count - 1, conversation_id)