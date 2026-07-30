extends Node

signal quest_started(quest_id: StringName)
signal quest_updated(quest_id: StringName)
signal objective_completed(quest_id: StringName, objective_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_failed(quest_id: StringName)
signal state_reloaded

const SAVE_VERSION := 1
const FIRST_NIGHT_CATALOG: QuestCatalog = preload("res://resources/quests/catalogs/loop_1.tres")

var _registered_catalog_ids: Dictionary[StringName, bool] = {}
var _definitions: Dictionary[StringName, QuestDefinition] = {}
var _states: Dictionary[StringName, QuestState] = {}

func _ready() -> void:
	register_catalog(FIRST_NIGHT_CATALOG) # TODO: Mentres só haxa 1 bucle
	GameplayEvents.plant_collected.connect(_on_plant_collected)
	GameplayEvents.dialogue_completed.connect(_on_dialogue_completed)

func register_catalog(catalog: QuestCatalog) -> bool:
	if catalog == null or catalog.catalog_id.is_empty():
		push_warning("QuestManager: invalid quest catalog.")
		return false

	if _registered_catalog_ids.has(catalog.catalog_id):
		return false

	var errors := PackedStringArray()
	var catalog_quest_ids := {}

	for index in range(catalog.quests.size()):
		var definition := catalog.quests[index]

		if definition == null:
			errors.append("quest at index %d is null" % index)
			continue

		for definition_error in _get_registration_errors(definition):
			errors.append("quest %d ('%s'): %s"% [index, definition.quest_id, definition_error])

		if not definition.quest_id.is_empty():
			if catalog_quest_ids.has(definition.quest_id):
				errors.append("duplicated quest_id '%s' inside catalog"% definition.quest_id)
			else:
				catalog_quest_ids[definition.quest_id] = true

	if not errors.is_empty():
		push_warning("QuestManager: catalog '%s' is invalid:\n- %s"% [catalog.catalog_id, "\n- ".join(errors)])
		return false

	for definition in catalog.quests:
		_register_validated_definition(definition)

	_registered_catalog_ids[catalog.catalog_id] = true
	return true


func register_definition(definition: QuestDefinition) -> bool:
	var errors := _get_registration_errors(definition)

	if not errors.is_empty():
		var quest_id := (definition.quest_id if definition != null else &"<null>")

		push_warning("QuestManager: quest '%s' cannot be registered:\n- %s"% [quest_id, "\n- ".join(errors)])
		return false

	_register_validated_definition(definition)
	return true


func start_quest(quest_id: StringName) -> bool:
	var state := _get_state(quest_id)
	if state == null:
		push_warning("QuestManager: cannot start unknown quest '%s'."% quest_id)
		return false

	if state.status != QuestState.Status.INACTIVE:
		return false

	state.status = QuestState.Status.ACTIVE
	quest_started.emit(quest_id)
	quest_updated.emit(quest_id)
	return true


func submit_item(quest_id: StringName, objective_id: StringName, plant_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var state := _get_state(quest_id)
	var objective := _get_objective_definition(quest_id, objective_id)

	if (state == null or objective == null) or \
	(state.status != QuestState.Status.ACTIVE) or \
	(objective.event_type != QuestObjectiveDefinition.EventType.ITEM_SUBMITTED) or \
	(objective.target_type != QuestObjectiveDefinition.TargetType.PLANT_SPECIES) or \
	(objective.target_id != plant_id):
		return false

	var current_amount := state.get_current_amount(objective_id)
	var remaining_amount := (objective.required_amount - current_amount)

	if remaining_amount <= 0:
		return false

	var submitted_amount := mini(amount, remaining_amount)

	if not InventoryManager.has_item(plant_id,submitted_amount):
		return false

	var display_name := InventoryManager.get_display_name(plant_id)
	var marks := InventoryManager.get_plant_marks(plant_id)

	if not InventoryManager.remove_item(plant_id, submitted_amount):
		return false

	if not advance_objective(quest_id, objective_id, submitted_amount):
		InventoryManager.add_item(plant_id, submitted_amount, display_name, marks)
		push_warning("QuestManager: item submission was rolled back for quest '%s', objective '%s'."% [quest_id, objective_id])
		return false

	return true


func is_inactive(quest_id: StringName) -> bool:
	return has_definition(quest_id) and _has_status(quest_id, QuestState.Status.INACTIVE)


func get_objective_progress(quest_id: StringName, objective_id: StringName) -> int:
	var state := _get_state(quest_id)
	var objective := _get_objective_definition(quest_id, objective_id)

	if state == null or objective == null:
		return 0

	return state.get_current_amount(objective_id)


func _on_plant_collected(plant_id: StringName, collection_id: StringName, amount: int) -> void:
	for raw_quest_id in _definitions.keys():
		var quest_id := StringName(raw_quest_id)

		if not is_active(quest_id):
			continue

		var definition := _get_definition(quest_id)
		for objective in definition.objectives:
			if objective.event_type != QuestObjectiveDefinition.EventType.PLANT_COLLECTED:
				continue

			var matched_by := &""

			match objective.target_type:
				QuestObjectiveDefinition.TargetType.PLANT_SPECIES:
					if objective.target_id == plant_id:
						matched_by = &"plant_id"
				QuestObjectiveDefinition.TargetType.PLANT_INSTANCE:
					if objective.target_id == collection_id:
						matched_by = &"collection_id"


			if matched_by.is_empty():
				continue

			if OS.is_debug_build():
				print("[QuestManager] plant_collected matched quest '%s', objective '%s' by %s."
					% [
						quest_id,
						objective.objective_id,
						matched_by,
					])

			advance_objective(quest_id, objective.objective_id, amount)


func _on_dialogue_completed(conversation_id: StringName, start_title: StringName, result_id: StringName) -> void:
	for raw_quest_id in _definitions.keys():
		var quest_id := StringName(raw_quest_id)

		if not is_active(quest_id):
			continue

		var definition := _get_definition(quest_id)

		for objective in definition.objectives:
			if objective.event_type != QuestObjectiveDefinition.EventType.DIALOGUE_COMPLETED:
				continue

			if objective.target_type != QuestObjectiveDefinition.TargetType.CONVERSATION:
				continue

			if objective.target_id != conversation_id:
				continue

			if OS.is_debug_build():
				print("[QuestManager] dialogue_completed matched quest '%s', objective '%s'; conversation '%s', title '%s', result '%s'."
					% [
						quest_id,
						objective.objective_id,
						conversation_id,
						start_title,
						result_id,
					]
				)

			advance_objective(quest_id, objective.objective_id, 1)


func export_state() -> Dictionary:
	var exported_quests := {}

	for raw_quest_id in _states.keys():
		var quest_id := StringName(raw_quest_id)
		var state := _get_state(quest_id)

		if state == null:
			continue

		var exported_objectives := {}

		for raw_objective_id in state.objective_progress.keys():
			var objective_id := StringName(raw_objective_id)
			exported_objectives[str(objective_id)] = max(0, state.get_current_amount(objective_id))

		exported_quests[str(quest_id)] = {
			"status": int(state.status),
			"objectives": exported_objectives,
		}

	return {
		"version": SAVE_VERSION,
		"quests": exported_quests,
	}

func import_state(data: Dictionary) -> bool:
	var version := int(data.get("version", -1))
	if version != SAVE_VERSION:
		push_warning("QuestManager: unsupported save version '%s'."% version)
		return false

	var raw_quests: Variant = data.get("quests", {})
	if not raw_quests is Dictionary:
		push_warning("QuestManager: 'quests' must be a Dictionary.")
		return false

	_reset_states()

	for raw_quest_id in raw_quests.keys():
		var quest_id := StringName(str(raw_quest_id))

		if not _definitions.has(quest_id):
			push_warning("QuestManager: ignoring retired quest '%s'."% quest_id)
			continue

		var raw_quest: Variant = raw_quests[raw_quest_id]
		if not raw_quest is Dictionary:
			push_warning("QuestManager: invalid state for quest '%s'."% quest_id)
			continue

		var status := int(
			raw_quest.get("status", QuestState.Status.INACTIVE)
		)

		if not _is_valid_status(status):
			push_warning("QuestManager: invalid status '%s' for quest '%s'."% [status, quest_id])
			continue

		var state := _get_state(quest_id)
		var definition := _get_definition(quest_id)

		if status == QuestState.Status.INACTIVE:
			continue

		var raw_objectives: Variant = raw_quest.get("objectives", {})

		if not raw_objectives is Dictionary:
			push_warning("QuestManager: invalid objectives for quest '%s'."% quest_id)
			raw_objectives = {}

		for objective in definition.objectives:
			var saved_amount := int(raw_objectives.get(str(objective.objective_id), 0))

			state.objective_progress[objective.objective_id] = clampi(saved_amount, 0, objective.required_amount)

		state.status = status

		if status == QuestState.Status.COMPLETED:
			_complete_all_objective_progress(definition, state)
		elif status == QuestState.Status.ACTIVE \
				and _are_all_objectives_completed(quest_id):
			state.status = QuestState.Status.COMPLETED

	state_reloaded.emit()
	return true

func clear() -> void:
	_reset_states()
	state_reloaded.emit()


func _get_registration_errors(definition: QuestDefinition) -> PackedStringArray:
	var errors := PackedStringArray()

	if definition == null:
		errors.append("definition is null")
		return errors

	errors.append_array(definition.get_validation_errors())

	if not definition.quest_id.is_empty() and _definitions.has(definition.quest_id):
		errors.append("quest_id '%s' is already registered"% definition.quest_id)

	return errors


func _register_validated_definition(definition: QuestDefinition) -> void:
	_definitions[definition.quest_id] = definition
	_states[definition.quest_id] = QuestState.create(definition)


func _reset_states() -> void:
	_states.clear()

	for raw_quest_id in _definitions.keys():
		var quest_id := StringName(raw_quest_id)
		_states[quest_id] = QuestState.create(_get_definition(quest_id))


func _complete_all_objective_progress(definition: QuestDefinition, state: QuestState) -> void:
	for objective in definition.objectives:
		state.objective_progress[objective.objective_id] = (objective.required_amount)


func _is_valid_status(status: int) -> bool:
	return status == QuestState.Status.INACTIVE \
		or status == QuestState.Status.ACTIVE \
		or status == QuestState.Status.COMPLETED \
		or status == QuestState.Status.FAILED


func get_objective_required_amount(quest_id: StringName, objective_id: StringName) -> int:
	var objective := _get_objective_definition(quest_id, objective_id)
	return objective.required_amount if objective != null else 0


func has_definition(quest_id: StringName) -> bool:
	return _definitions.has(quest_id)


func is_active(quest_id: StringName) -> bool:
	return _has_status(quest_id, QuestState.Status.ACTIVE)


func is_completed(quest_id: StringName) -> bool:
	return _has_status(quest_id, QuestState.Status.COMPLETED)


func is_failed(quest_id: StringName) -> bool:
	return _has_status(quest_id, QuestState.Status.FAILED)


func is_objective_completed(quest_id: StringName, objective_id: StringName) -> bool:
	var definition := _get_definition(quest_id)
	var state := _get_state(quest_id)

	if definition == null or state == null:
		return false

	for objective in definition.objectives:
		if objective.objective_id == objective_id:
			return (state.get_current_amount(objective_id) >= objective.required_amount)

	return false


func _has_status(quest_id: StringName, expected_status: int) -> bool:
	var state := _get_state(quest_id)
	return state != null and state.status == expected_status


func _get_definition(quest_id: StringName) -> QuestDefinition:
	return _definitions.get(quest_id) as QuestDefinition


func _get_state(quest_id: StringName) -> QuestState:
	return _states.get(quest_id) as QuestState


func advance_objective(quest_id: StringName, objective_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var state := _get_state(quest_id)
	var objective := _get_objective_definition(quest_id, objective_id)

	if state == null or objective == null:
		return false

	if state.status != QuestState.Status.ACTIVE:
		return false

	var current_amount := state.get_current_amount(objective_id)
	if current_amount >= objective.required_amount:
		return false

	var new_amount := mini(current_amount + amount, objective.required_amount)
	state.objective_progress[objective_id] = new_amount

	if new_amount >= objective.required_amount:
		objective_completed.emit(quest_id, objective_id)

	if _are_all_objectives_completed(quest_id):
		state.status = QuestState.Status.COMPLETED
		quest_completed.emit(quest_id)

	quest_updated.emit(quest_id)
	return true


func complete_quest(quest_id: StringName) -> bool:
	var definition := _get_definition(quest_id)
	var state := _get_state(quest_id)

	if definition == null or state == null:
		return false

	if state.status != QuestState.Status.ACTIVE:
		return false

	for objective in definition.objectives:
		if not is_objective_completed(quest_id, objective.objective_id):
			state.objective_progress[objective.objective_id] = (objective.required_amount)
			objective_completed.emit(quest_id, objective.objective_id)

	state.status = QuestState.Status.COMPLETED
	quest_completed.emit(quest_id)
	quest_updated.emit(quest_id)
	return true


func fail_quest(quest_id: StringName) -> bool:
	var state := _get_state(quest_id)

	if state == null or state.status != QuestState.Status.ACTIVE:
		return false

	state.status = QuestState.Status.FAILED
	quest_failed.emit(quest_id)
	quest_updated.emit(quest_id)
	return true


func _get_objective_definition(quest_id: StringName, objective_id: StringName) -> QuestObjectiveDefinition:
	var definition := _get_definition(quest_id)
	if definition == null:
		return null

	for objective in definition.objectives:
		if objective.objective_id == objective_id:
			return objective

	return null


func _are_all_objectives_completed(quest_id: StringName) -> bool:
	var definition := _get_definition(quest_id)
	if definition == null or definition.objectives.is_empty():
		return false

	for objective in definition.objectives:
		if not is_objective_completed(quest_id, objective.objective_id):
			return false

	return true
