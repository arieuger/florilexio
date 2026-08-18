@tool
extends VBoxContainer

signal resource_open_requested(resource_path: String)

enum TargetKind {
	QUEST,
	OBJECTIVE,
	CONVERSATION,
	PLANT,
}

var index: NarrativeIndex
var kind_selector: OptionButton
var target_selector: OptionButton
var results_label: Label
var results_list: ItemList


func _ready() -> void:
	var title := Label.new()
	title.text = "Usado por"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	var kind_label := Label.new()
	kind_label.text = "Tipo de elemento"
	add_child(kind_label)

	kind_selector = OptionButton.new()
	kind_selector.add_item("Quest")
	kind_selector.set_item_metadata(0, TargetKind.QUEST)
	kind_selector.add_item("Obxectivo")
	kind_selector.set_item_metadata(1, TargetKind.OBJECTIVE)
	kind_selector.add_item("Conversa")
	kind_selector.set_item_metadata(2, TargetKind.CONVERSATION)
	kind_selector.add_item("Planta")
	kind_selector.set_item_metadata(3, TargetKind.PLANT)
	kind_selector.item_selected.connect(_on_kind_selected)
	add_child(kind_selector)

	var target_label := Label.new()
	target_label.text = "Elemento"
	add_child(target_label)

	target_selector = OptionButton.new()
	target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_selector.item_selected.connect(_on_target_selected)
	add_child(target_selector)

	results_label = Label.new()
	results_label.text = "Selecciona un elemento."
	results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(results_label)

	results_list = ItemList.new()
	results_list.custom_minimum_size.y = 180
	results_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_list.item_activated.connect(_on_result_activated)
	add_child(results_list)

	refresh()


func refresh() -> void:
	index = NarrativeIndex.build()
	_populate_targets()


func _on_kind_selected(_item_index: int) -> void:
	_populate_targets()


func _on_target_selected(_item_index: int) -> void:
	_populate_results()


func _on_result_activated(item_index: int) -> void:
	var resource_path := String(results_list.get_item_metadata(item_index))

	if resource_path.is_empty():
		return

	resource_open_requested.emit(resource_path)


func _populate_targets() -> void:
	target_selector.clear()
	target_selector.add_item("Selecciona un elemento…")
	target_selector.set_item_metadata(0, {})

	if index == null:
		_populate_results()
		return

	var selected_kind := int(kind_selector.get_selected_metadata())

	match selected_kind:
		TargetKind.QUEST:
			for record: Dictionary in index.quests:
				var quest_id := StringName(record.get("id", &""))
				_add_target_option(
					String(quest_id),
					&"quest",
					quest_id
				)

		TargetKind.OBJECTIVE:
			for record: Dictionary in index.objectives:
				var quest_id := StringName(
					record.get("quest_id", &"")
				)
				var objective_id := StringName(
					record.get("id", &"")
				)

				_add_target_option(
					"%s → %s" % [quest_id, objective_id],
					&"objective",
					objective_id,
					quest_id
				)

		TargetKind.CONVERSATION:
			for record: Dictionary in index.conversations:
				var conversation_id := StringName(
					record.get("id", &"")
				)
				_add_target_option(
					String(conversation_id),
					&"conversation",
					conversation_id
				)

		TargetKind.PLANT:
			for record: Dictionary in index.plants:
				var plant_id := StringName(record.get("id", &""))
				var plant := record.get("resource") as PlantData
				var item_text := String(plant_id)

				if plant != null and not plant.display_name.is_empty():
					item_text = "%s (%s)" % [
						plant.display_name,
						plant_id,
					]

				_add_target_option(
					item_text,
					&"plant",
					plant_id
				)

	target_selector.select(0)
	_populate_results()


func _populate_results() -> void:
	results_list.clear()

	var selected_index := target_selector.selected

	if selected_index <= 0:
		results_label.text = "Selecciona un elemento."
		return

	var target: Dictionary = target_selector.get_item_metadata(selected_index)

	var target_kind := StringName(target.get("target_kind", &""))
	var target_id := StringName(target.get("target_id", &""))
	var target_parent_id := StringName(target.get("target_parent_id", &""))

	var found_references := index.get_references_to(target_kind, target_id, target_parent_id)

	if found_references.is_empty():
		results_label.text = "Non se atoparon referencias."
		return

	results_label.text = "%d referencia(s)" % found_references.size()

	for reference: Dictionary in found_references:
		var description := String(reference.get("description", "Referencia narrativa"))
		var source_id := StringName(reference.get("source_id", &""))
		var source_path := String(reference.get("source_path", ""))

		var item_text := description

		if not source_id.is_empty():
			item_text += " · %s" % source_id

		var item_index := results_list.item_count
		results_list.add_item(item_text)
		results_list.set_item_metadata(item_index, source_path)
		results_list.set_item_tooltip(item_index, source_path)


func _add_target_option(item_text: String, target_kind: StringName, 
	target_id: StringName, target_parent_id: StringName = &"") -> void:
	if target_id.is_empty():
		return

	var item_index := target_selector.item_count
	target_selector.add_item(item_text)
	target_selector.set_item_metadata(item_index, {
		"target_kind": target_kind,
		"target_id": target_id,
		"target_parent_id": target_parent_id,
	})