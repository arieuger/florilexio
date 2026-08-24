@tool
extends VBoxContainer

const QuestObjectiveReferencePicker := preload(
	"res://addons/florilexio_narrative_tools/quest_objective_reference_picker.gd"
)

enum CommandType {
	START_QUEST,
	SUBMIT_ITEM,
	ADD_INVENTORY_ITEM,
	UNLOCK_PLANT_KNOWLEDGE,
}

var index: NarrativeIndex
var command_selector: OptionButton
var reference_picker: Control
var plant_label: Label
var plant_selector: OptionButton
var amount_label: Label
var amount_field: SpinBox
var item_label: Label
var item_selector: OptionButton
var fragment_label: Label
var fragment_selector: OptionButton
var preview: CodeEdit
var copy_button: Button
var feedback_label: Label


func _ready() -> void:
	var title := Label.new()
	title.text = "Xerador de comandos .dialogue"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	var explanation := Label.new()
	explanation.text = (
		"Selecciona as referencias e copia o comando no ficheiro .dialogue."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)

	var command_label := Label.new()
	command_label.text = "Comando"
	add_child(command_label)

	command_selector = OptionButton.new()
	command_selector.add_item("Iniciar quest")
	command_selector.set_item_metadata(0, CommandType.START_QUEST)
	command_selector.add_item("Entregar ítem a un obxectivo")
	command_selector.set_item_metadata(1, CommandType.SUBMIT_ITEM)
	command_selector.add_item("Engadir ítem ao inventario")
	command_selector.set_item_metadata(2, CommandType.ADD_INVENTORY_ITEM)
	command_selector.add_item("Desbloquear coñecemento dunha planta")
	command_selector.set_item_metadata(3, CommandType.UNLOCK_PLANT_KNOWLEDGE)
	command_selector.item_selected.connect(_on_command_selected)
	add_child(command_selector)

	reference_picker = QuestObjectiveReferencePicker.new()
	reference_picker.reference_changed.connect(_on_reference_changed)
	add_child(reference_picker)

	plant_label = Label.new()
	plant_label.text = "Planta"
	add_child(plant_label)

	plant_selector = OptionButton.new()
	plant_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plant_selector.item_selected.connect(_on_plant_selected)
	add_child(plant_selector)

	fragment_label = Label.new()
	fragment_label.text = "Fragmento de coñecemento"
	add_child(fragment_label)

	fragment_selector = OptionButton.new()
	fragment_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fragment_selector.item_selected.connect(_on_fragment_selected)
	add_child(fragment_selector)

	item_label = Label.new()
	item_label.text = "Ítem"
	add_child(item_label)

	item_selector = OptionButton.new()
	item_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_selector.item_selected.connect(_on_item_selected)
	add_child(item_selector)

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
	amount_field.value_changed.connect(_on_amount_changed)
	add_child(amount_field)

	var preview_label := Label.new()
	preview_label.text = "Previsualización"
	add_child(preview_label)

	preview = CodeEdit.new()
	preview.custom_minimum_size.y = 100
	preview.editable = false
	preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(preview)

	copy_button = Button.new()
	copy_button.text = "Copiar comando"
	copy_button.pressed.connect(_copy_command)
	add_child(copy_button)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(feedback_label)

	refresh()


func refresh() -> void:
	index = NarrativeIndex.build()
	reference_picker.refresh(index)
	_populate_plants()
	_populate_items()
	_populate_fragments(&"")
	_refresh_command_fields()


func _populate_plants() -> void:
	plant_selector.clear()
	plant_selector.add_item("Selecciona unha planta")
	plant_selector.set_item_metadata(0, &"")

	var records := index.plants.duplicate()
	records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first.get("id", &"")) < str(second.get("id", &""))
	)

	for record: Dictionary in records:
		var plant_id := StringName(record.get("id", &""))

		if plant_id.is_empty():
			continue

		var plant := record.get("resource") as PlantData
		var item_text := String(plant_id)

		if plant != null and not plant.display_name.is_empty():
			item_text = "%s (%s)" % [plant.display_name, plant_id]

		var item_index := plant_selector.item_count
		plant_selector.add_item(item_text)
		plant_selector.set_item_metadata(item_index, plant_id)


func _populate_items() -> void:
	item_selector.clear()
	item_selector.add_item("Selecciona un ítem")
	item_selector.set_item_metadata(0, &"")

	var records := index.items.duplicate()
	records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first.get("id", &"")) < str(second.get("id", &""))
	)

	for record: Dictionary in records:
		var item_id := StringName(record.get("id", &""))

		if item_id.is_empty():
			continue

		var item := record.get("resource") as ItemData
		var item_text := String(item_id)

		if item != null and not item.display_name.is_empty():
			item_text = "%s (%s)" % [item.display_name, item_id]

		var item_index := item_selector.item_count
		item_selector.add_item(item_text)
		item_selector.set_item_metadata(item_index, item_id)


func _populate_fragments(plant_id: StringName) -> void:
	fragment_selector.clear()
	fragment_selector.add_item("Selecciona un fragmento")
	fragment_selector.set_item_metadata(0, &"")

	if plant_id.is_empty():
		fragment_selector.disabled = true
		return

	var plant_records := index.get_plant_records(plant_id)

	if plant_records.is_empty():
		fragment_selector.disabled = true
		return

	var plant := plant_records[0].get("resource") as PlantData

	if plant == null:
		fragment_selector.disabled = true
		return

	for fragment in plant.knowledge_fragments:
		if fragment == null or fragment.id.is_empty():
			continue

		var item_index := fragment_selector.item_count
		fragment_selector.add_item(String(fragment.id))
		fragment_selector.set_item_metadata(item_index, fragment.id)

	fragment_selector.disabled = fragment_selector.item_count <= 1


func _refresh_command_fields() -> void:
	var command_type := int(command_selector.get_selected_metadata())
	var submits_item := command_type == CommandType.SUBMIT_ITEM
	var adds_inventory_item := command_type == CommandType.ADD_INVENTORY_ITEM
	var unlocks_knowledge := (
		command_type == CommandType.UNLOCK_PLANT_KNOWLEDGE
	)

	reference_picker.visible = (
		command_type == CommandType.START_QUEST or submits_item
	)
	reference_picker.set_objective_selection_enabled(submits_item)
	plant_label.visible = unlocks_knowledge
	plant_selector.visible = unlocks_knowledge
	item_label.visible = submits_item or adds_inventory_item
	item_selector.visible = submits_item or adds_inventory_item
	fragment_label.visible = unlocks_knowledge
	fragment_selector.visible = unlocks_knowledge
	amount_label.visible = submits_item or adds_inventory_item
	amount_field.visible = submits_item or adds_inventory_item

	_update_preview()


func _update_preview() -> void:
	var command := _build_command()
	preview.text = command
	copy_button.disabled = command.is_empty()

	if command.is_empty():
		feedback_label.text = "Completa as referencias necesarias."
	else:
		feedback_label.text = ""


func _build_command() -> String:
	var quest_id: StringName = reference_picker.get_quest_id()
	var command_type := int(command_selector.get_selected_metadata())

	match command_type:
		CommandType.START_QUEST:
			if quest_id.is_empty():
				return ""

			return 'do QuestManager.start_quest("%s")' % quest_id

		CommandType.SUBMIT_ITEM:
			var objective_id: StringName = reference_picker.get_objective_id()
			var item_id := _get_selected_item_id()

			if (
				quest_id.is_empty()
				or objective_id.is_empty()
				or item_id.is_empty()
			):
				return ""

			return 'do QuestManager.submit_item("%s", "%s", "%s", %d)' % [
				quest_id,
				objective_id,
				item_id,
				int(amount_field.value),
			]

		CommandType.ADD_INVENTORY_ITEM:
			var item_id := _get_selected_item_id()

			if item_id.is_empty():
				return ""

			return 'do InventoryManager.add_item("%s", %d)' % [
				item_id,
				int(amount_field.value),
			]

		CommandType.UNLOCK_PLANT_KNOWLEDGE:
			var plant_id := _get_selected_plant_id()
			var fragment_id := _get_selected_fragment_id()

			if plant_id.is_empty() or fragment_id.is_empty():
				return ""

			return 'do FlorilexioManager.unlock_knowledge("%s", "%s")' % [
				plant_id,
				fragment_id,
			]

	return ""


func _get_selected_plant_id() -> StringName:
	if plant_selector.selected <= 0:
		return &""

	return StringName(plant_selector.get_selected_metadata())


func _get_selected_item_id() -> StringName:
	if item_selector.selected <= 0:
		return &""

	return StringName(item_selector.get_selected_metadata())


func _get_selected_fragment_id() -> StringName:
	if fragment_selector.selected <= 0:
		return &""

	return StringName(fragment_selector.get_selected_metadata())


func _copy_command() -> void:
	var command := _build_command()

	if command.is_empty():
		return

	DisplayServer.clipboard_set(command)
	feedback_label.text = "Comando copiado."


func _on_command_selected(_item_index: int) -> void:
	_refresh_command_fields()


func _on_reference_changed(
	_quest_id: StringName,
	_objective_id: StringName
) -> void:
	_update_preview()


func _on_plant_selected(_item_index: int) -> void:
	_populate_fragments(_get_selected_plant_id())
	_update_preview()


func _on_item_selected(_item_index: int) -> void:
	_update_preview()


func _on_fragment_selected(_item_index: int) -> void:
	_update_preview()


func _on_amount_changed(_value: float) -> void:
	_update_preview()
