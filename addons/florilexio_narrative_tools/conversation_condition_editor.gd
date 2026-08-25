@tool
extends VBoxContainer

signal remove_requested(editor: Control)

const QuestObjectiveReferencePicker := preload("res://addons/florilexio_narrative_tools/quest_objective_reference_picker.gd")

enum ConditionType {
	QUEST_STATUS,
	QUEST_OBJECTIVE_COMPLETED,
	CONVERSATION_FINISHED,
	INVENTORY_HAS,
}

var heading: Label
var type_selector: OptionButton
var reference_picker: Control
var status_label: Label
var status_selector: OptionButton
var expected_completed_field: CheckBox
var conversation_label: Label
var conversation_selector: OptionButton
var inventory_target_type_label: Label
var inventory_target_type_selector: OptionButton
var plant_label: Label
var plant_selector: OptionButton
var item_label: Label
var item_selector: OptionButton
var amount_label: Label
var amount_field: SpinBox


func _ready() -> void:
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 13)
	add_child(heading)

	var type_label := Label.new()
	type_label.text = "Tipo de condición"
	add_child(type_label)

	type_selector = OptionButton.new()
	type_selector.add_item("Estado dunha quest")
	type_selector.set_item_metadata(0, ConditionType.QUEST_STATUS)
	type_selector.add_item("Obxectivo completado")
	type_selector.set_item_metadata(1, ConditionType.QUEST_OBJECTIVE_COMPLETED)
	type_selector.item_selected.connect(_on_type_selected)
	type_selector.add_item("Conversa finalizada")
	type_selector.set_item_metadata(2, ConditionType.CONVERSATION_FINISHED)
	type_selector.add_item("Inventario ten elemento")
	type_selector.set_item_metadata(3, ConditionType.INVENTORY_HAS)
	add_child(type_selector)

	conversation_label = Label.new()
	conversation_label.text = "Conversa"
	add_child(conversation_label)

	conversation_selector = OptionButton.new()
	conversation_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(conversation_selector)
	_populate_conversation_selector()

	inventory_target_type_label = Label.new()
	inventory_target_type_label.text = "Tipo de elemento"
	add_child(inventory_target_type_label)

	inventory_target_type_selector = OptionButton.new()
	inventory_target_type_selector.add_item("Obxecto")
	inventory_target_type_selector.set_item_metadata(
		0,
		QuestObjectiveDefinition.TargetType.ITEM_ID
	)
	inventory_target_type_selector.add_item("Especie de planta")
	inventory_target_type_selector.set_item_metadata(
		1,
		QuestObjectiveDefinition.TargetType.PLANT_SPECIES
	)
	inventory_target_type_selector.item_selected.connect(
		_on_inventory_target_type_selected
	)
	add_child(inventory_target_type_selector)

	plant_label = Label.new()
	plant_label.text = "Planta"
	add_child(plant_label)

	plant_selector = OptionButton.new()
	plant_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(plant_selector)

	_populate_plant_selector()

	item_label = Label.new()
	item_label.text = "Obxecto"
	add_child(item_label)

	item_selector = OptionButton.new()
	item_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(item_selector)

	_populate_item_selector()

	amount_label = Label.new()
	amount_label.text = "Cantidade"
	add_child(amount_label)

	amount_field = SpinBox.new()
	amount_field.min_value = 1
	amount_field.max_value = 999
	amount_field.step = 1
	amount_field.value = 1
	amount_field.allow_greater = false
	amount_field.allow_lesser = false
	add_child(amount_field)

	reference_picker = QuestObjectiveReferencePicker.new()
	add_child(reference_picker)

	status_label = Label.new()
	status_label.text = "Estado esperado"
	add_child(status_label)

	status_selector = OptionButton.new()
	add_child(status_selector)
	_populate_quest_statuses()

	expected_completed_field = CheckBox.new()
	expected_completed_field.text = "O obxectivo debe estar completado"
	expected_completed_field.button_pressed = true
	add_child(expected_completed_field)

	var remove_button := Button.new()
	remove_button.text = "Eliminar condición"
	remove_button.pressed.connect(
		func() -> void:
			remove_requested.emit(self)
	)
	add_child(remove_button)

	add_child(HSeparator.new())

	_refresh_visibility()


func set_condition_number(number: int) -> void:
	heading.text = "Condición %d" % number


func build_condition() -> ConversationCondition:
	var condition_type := int(
		type_selector.get_selected_metadata()
	)

	match condition_type:
		ConditionType.QUEST_STATUS:
			var condition := QuestStatusCondition.new()
			condition.quest_id = reference_picker.get_quest_id()
			condition.expected_status = int(status_selector.get_selected_metadata())
			return condition

		ConditionType.QUEST_OBJECTIVE_COMPLETED:
			var condition := QuestObjectiveCompletedCondition.new()
			condition.quest_id = reference_picker.get_quest_id()
			condition.objective_id = reference_picker.get_objective_id()
			condition.expected_completed = expected_completed_field.button_pressed
			return condition
		ConditionType.CONVERSATION_FINISHED:
			var condition := ConversationFinishedCondition.new()

			var selected_index := conversation_selector.selected
			if selected_index >= 0:
				condition.conversation_id = StringName(conversation_selector.get_item_metadata(selected_index))

			condition.expected_finished = expected_completed_field.button_pressed
			return condition

		ConditionType.INVENTORY_HAS:
			var condition := InventoryHasCondition.new()
			condition.target_type = int(
				inventory_target_type_selector.get_selected_metadata()
			)

			var selected_index := (
				plant_selector.selected
				if condition.target_type == QuestObjectiveDefinition.TargetType.PLANT_SPECIES
				else item_selector.selected
			)
			var selected_selector := (
				plant_selector
				if condition.target_type == QuestObjectiveDefinition.TargetType.PLANT_SPECIES
				else item_selector
			)
			if selected_index >= 0:
				condition.target_id = StringName(
					selected_selector.get_item_metadata(selected_index)
				)

			condition.amount = int(amount_field.value)
			condition.expected_has = expected_completed_field.button_pressed
			return condition

	return null


func _populate_quest_statuses() -> void:
	status_selector.clear()

	for status in QuestState.Status.values():
		var item_index := status_selector.item_count
		status_selector.add_item(QuestState.Status.keys()[status].capitalize())
		status_selector.set_item_metadata(item_index, status)

		if status == QuestState.Status.ACTIVE:
			status_selector.select(item_index)


func _on_type_selected(_index: int) -> void:
	_refresh_visibility()


func _on_inventory_target_type_selected(_index: int) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	var condition_type := int(type_selector.get_selected_metadata())

	var is_quest_status := condition_type == ConditionType.QUEST_STATUS
	var uses_quest := (
		condition_type == ConditionType.QUEST_STATUS
		or condition_type == ConditionType.QUEST_OBJECTIVE_COMPLETED
	)
	var uses_conversation := condition_type == ConditionType.CONVERSATION_FINISHED
	var uses_inventory := condition_type == ConditionType.INVENTORY_HAS
	var inventory_target_type := int(
		inventory_target_type_selector.get_selected_metadata()
	)
	var uses_plant := (
		uses_inventory
		and inventory_target_type == QuestObjectiveDefinition.TargetType.PLANT_SPECIES
	)
	var uses_item := (
		uses_inventory
		and inventory_target_type == QuestObjectiveDefinition.TargetType.ITEM_ID
	)

	reference_picker.visible = uses_quest
	reference_picker.set_objective_selection_enabled(condition_type == ConditionType.QUEST_OBJECTIVE_COMPLETED)

	status_label.visible = is_quest_status
	status_selector.visible = is_quest_status

	conversation_label.visible = uses_conversation
	conversation_selector.visible = uses_conversation
	inventory_target_type_label.visible = uses_inventory
	inventory_target_type_selector.visible = uses_inventory

	plant_label.visible = uses_plant
	plant_selector.visible = uses_plant
	item_label.visible = uses_item
	item_selector.visible = uses_item
	amount_label.visible = uses_plant or uses_item
	amount_field.visible = uses_plant or uses_item

	expected_completed_field.visible = condition_type != ConditionType.QUEST_STATUS

	match condition_type:
		ConditionType.QUEST_OBJECTIVE_COMPLETED:
			expected_completed_field.text = "O obxectivo debe estar completado"

		ConditionType.CONVERSATION_FINISHED:
			expected_completed_field.text = "A conversa debe estar finalizada"

		ConditionType.INVENTORY_HAS:
			expected_completed_field.text = "O elemento debe estar no inventario"


func _populate_conversation_selector() -> void:
	conversation_selector.clear()
	conversation_selector.add_item("Selecciona unha conversa…")
	conversation_selector.set_item_metadata(0, &"")

	var index := NarrativeIndex.build()

	for record: Dictionary in index.conversations:
		var conversation_id := StringName(record.get("id", &""))
		if conversation_id.is_empty():
			continue

		conversation_selector.add_item(String(conversation_id))
		conversation_selector.set_item_metadata(conversation_selector.item_count - 1, conversation_id)



func _populate_plant_selector() -> void:
	plant_selector.clear()
	plant_selector.add_item("Selecciona unha planta…")
	plant_selector.set_item_metadata(0, &"")

	var index := NarrativeIndex.build()

	for record: Dictionary in index.plants:
		var plant_id := StringName(record.get("id", &""))
		if plant_id.is_empty():
			continue

		var plant := record.get("resource") as PlantData
		var display_name := plant.display_name if plant != null else ""
		var item_text := String(plant_id)

		if not display_name.is_empty():
			item_text = "%s (%s)" % [display_name, plant_id]

		plant_selector.add_item(item_text)
		plant_selector.set_item_metadata(
			plant_selector.item_count - 1,
			plant_id
		)


func _populate_item_selector() -> void:
	item_selector.clear()
	item_selector.add_item("Selecciona un obxecto…")
	item_selector.set_item_metadata(0, &"")

	var index := NarrativeIndex.build()

	for record: Dictionary in index.items:
		var item := record.get("resource") as ItemData
		if item == null or item is PlantData or item.id.is_empty():
			continue

		var item_text := String(item.id)
		if not item.display_name.is_empty():
			item_text = "%s (%s)" % [item.display_name, item.id]

		item_selector.add_item(item_text)
		item_selector.set_item_metadata(
			item_selector.item_count - 1,
			item.id
		)
