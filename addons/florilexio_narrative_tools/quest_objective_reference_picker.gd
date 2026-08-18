@tool
extends VBoxContainer

signal reference_changed(quest_id: StringName, objective_id: StringName)

var quest_selector: OptionButton
var objective_selector: OptionButton
var objective_label: Label

var _objective_selection_enabled := true
var _index: NarrativeIndex

func _ready() -> void:
	var quest_label = Label.new()
	quest_label.text = "Quest"
	add_child(quest_label)

	quest_selector = OptionButton.new()
	quest_selector.item_selected.connect(_on_quest_selected)
	add_child(quest_selector)

	objective_label = Label.new()
	objective_label.text = "Obxetivo"
	add_child(objective_label)

	objective_selector = OptionButton.new()
	objective_selector.item_selected.connect(_on_objective_selected)
	add_child(objective_selector)

	refresh()

	set_objective_selection_enabled(_objective_selection_enabled)


func refresh(index: NarrativeIndex = null) -> void:
	_index = index if index != null else NarrativeIndex.build()
	_populate_quests()


func get_quest_id() -> StringName:
	if quest_selector.selected <= 0:
		return &""

	return StringName(quest_selector.get_selected_metadata())


func get_objective_id() -> StringName:
	if not _objective_selection_enabled or objective_selector.selected <= 0:
		return &""

	return StringName(objective_selector.get_selected_metadata())


func set_objective_selection_enabled(enabled: bool) -> void:
	_objective_selection_enabled = enabled

	if not is_node_ready():
		return

	objective_label.visible = enabled
	objective_selector.visible = enabled

	if enabled:
		_populate_objectives(get_quest_id())
	else:
		_populate_objectives(&"")


func _populate_quests() -> void:
	quest_selector.clear()
	quest_selector.add_item("Selecciona unha quest")
	quest_selector.set_item_metadata(0, &"")

	var records = _index.quests.duplicate()
	records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first["id"]) < str(second["id"])
	)

	for record in records:
		var quest_id := StringName(record.get("id", &""))
		if quest_id.is_empty():
			continue

		var quest := record.get("resource") as QuestDefinition
		var label := str(quest_id)

		if quest != null and not quest.description.strip_edges().is_empty():
			label = "%s (%s)" %[quest.description.strip_edges(), quest_id]

		var item_index := quest_selector.get_item_count()
		quest_selector.add_item(label)
		quest_selector.set_item_metadata(item_index, quest_id)

	_populate_objectives(&"")


func _populate_objectives(quest_id: StringName) -> void:
	objective_selector.clear()
	objective_selector.add_item("Selecciona un obxetivo")
	objective_selector.set_item_metadata(0, &"")

	if quest_id.is_empty():
		objective_selector.disabled = true
		return

	objective_selector.disabled = false

	var records := (
		_index.get_quest_objective_records(quest_id)
	)
	records.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first["id"]) < str(second["id"])
	)

	for record in records:
		var objective_id := StringName(
			record.get("id", &"")
		)
		if objective_id.is_empty():
			continue

		var objective := (
			record.get("resource")
			as QuestObjectiveDefinition
		)
		var label := str(objective_id)

		if objective != null \
				and not objective.description.strip_edges().is_empty():
			label = "%s (%s)" % [
				objective.description.strip_edges(),
				objective_id,
			]

		var item_index := objective_selector.item_count
		objective_selector.add_item(label)
		objective_selector.set_item_metadata(
			item_index,
			objective_id
		)


func _on_quest_selected(_index: int) -> void:
	var quest_id := get_quest_id()
	if _objective_selection_enabled:
		_populate_objectives(quest_id)
	else:
		_populate_objectives(&"")

	reference_changed.emit(quest_id, &"")


func _on_objective_selected(_index: int) -> void:
	reference_changed.emit(
		get_quest_id(),
		get_objective_id()
	)