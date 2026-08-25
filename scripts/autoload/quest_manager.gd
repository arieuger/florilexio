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
	GameplayEvents.item_acquired.connect(_on_item_acquired)
	GameplayEvents.dialogue_completed.connect(_on_dialogue_completed)
	InventoryManager.item_added.connect(_on_inventory_item_changed)
	InventoryManager.item_removed.connect(_on_inventory_item_changed)


func register_catalog(catalog: QuestCatalog) -> bool:
	if catalog == null or catalog.catalog_id.is_empty():
		push_warning("QuestManager: invalid quest catalog.")
		return false

	if _registered_catalog_ids.has(catalog.catalog_id):
		return false

	var errors := catalog.get_validation_errors()

	for index in range(catalog.quests.size()):
		var definition := catalog.quests[index]

		if definition == null:
			continue

		for definition_error in _get_registration_errors(definition):
			errors.append("quest %d ('%s'): %s" % [
					index,
					definition.quest_id,
					definition_error,
				]
			)

	if not errors.is_empty():
		push_warning("QuestManager: catalog '%s' is invalid:\n- %s" % [catalog.catalog_id, "\n- ".join(errors)])
		return false

	for definition in catalog.quests:
		_register_validated_definition(definition)

	_registered_catalog_ids[catalog.catalog_id] = true
	return true


func register_definition(definition: QuestDefinition) -> bool:
	var errors := _get_registration_errors(definition)

	if not errors.is_empty():
		var quest_id := (definition.quest_id if definition != null else &"<null>")

		push_warning("QuestManager: quest '%s' cannot be registered:\n- %s" % [quest_id, "\n- ".join(errors)])
		return false

	_register_validated_definition(definition)
	return true


func start_quest(quest_id: StringName) -> bool:
	var state := _get_state(quest_id)
	if state == null:
		push_warning("QuestManager: cannot start unknown quest '%s'." % quest_id)
		return false

	if state.status != QuestState.Status.INACTIVE:
		return false

	state.status = QuestState.Status.ACTIVE
	quest_started.emit(quest_id)
	var progress_changed := _reevaluate_inventory_owned_objectives_for_quest(quest_id)

	if not progress_changed:
		quest_updated.emit(quest_id)
	return true


func submit_item(quest_id: StringName, objective_id: StringName, item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var state := _get_state(quest_id)
	var objective := _get_objective_definition(quest_id, objective_id)

	if (state == null or objective == null) or \
	(state.status != QuestState.Status.ACTIVE) or \
	(objective.event_type != QuestObjectiveDefinition.EventType.INVENTORY_SUBMITTED) or \
	((objective.target_type != QuestObjectiveDefinition.TargetType.PLANT_SPECIES) and \
		(objective.target_type != QuestObjectiveDefinition.TargetType.ITEM_ID)) or \
	(objective.target_id != item_id):
		return false

	var current_amount := state.get_current_amount(objective_id)
	var remaining_amount := objective.required_amount - current_amount

	if remaining_amount <= 0:
		return false

	var consumes_item := objective.consumes_submitted_item()
	var submitted_amount := 0

	if consumes_item:
		submitted_amount = mini(amount, remaining_amount)
	else:
		submitted_amount = remaining_amount

	if not InventoryManager.has_item(item_id, submitted_amount):
		return false

	if consumes_item:
		if not InventoryManager.remove_item(item_id, submitted_amount):
			return false

	if not advance_objective(quest_id, objective_id, submitted_amount):
		if consumes_item:
			InventoryManager.add_item(
				item_id,
				submitted_amount,
				InventoryManager.AdditionMode.RESTORE
			)
			push_warning("QuestManager: item submission was rolled back for quest '%s', objective '%s'." % [quest_id, objective_id])
		else:
			push_warning("QuestManager: shown item could not advance quest '%s', objective '%s'." % [quest_id, objective_id])

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


func _advance_matching_objectives(
	event_type: QuestObjectiveDefinition.EventType,
	target_ids: Dictionary[
		QuestObjectiveDefinition.TargetType, StringName
	], amount: int) -> void:
	if amount <= 0:
		return

	for raw_quest_id in _definitions.keys():
		var quest_id := StringName(raw_quest_id)
		if not is_active(quest_id):
			continue

		var definition := _get_definition(quest_id)

		for objective in definition.objectives:
			if objective.event_type != event_type:
				continue

			if not target_ids.has(objective.target_type):
				continue

			var reported_target_id := StringName(target_ids[objective.target_type])
			if objective.target_id != reported_target_id:
				continue


			if OS.is_debug_build():
				print("[QuestManager] %s matched quest '%s', objective '%s' by %s." % [
					QuestObjectiveDefinition.EventType.keys()[event_type],
					quest_id,
					objective.objective_id,
					QuestObjectiveDefinition.TargetType.keys()[objective.target_type]
				])

			advance_objective(quest_id, objective.objective_id, amount)


func _on_item_acquired(item_id: StringName, collection_id: StringName, amount: int) -> void:
	if ItemDatabase.get_plant(item_id) == null:
		var item_targets: Dictionary[QuestObjectiveDefinition.TargetType, StringName] = {}
		item_targets[QuestObjectiveDefinition.TargetType.ITEM_ID] = item_id

		_advance_matching_objectives(
			QuestObjectiveDefinition.EventType.ITEM_COLLECTED,
			item_targets,
			amount
		)
		return

	var plant_targets: Dictionary[QuestObjectiveDefinition.TargetType, StringName] = {}
	plant_targets[QuestObjectiveDefinition.TargetType.PLANT_SPECIES] = item_id

	if not collection_id.is_empty():
		plant_targets[QuestObjectiveDefinition.TargetType.PLANT_INSTANCE] = collection_id

	_advance_matching_objectives(
		QuestObjectiveDefinition.EventType.PLANT_COLLECTED,
		plant_targets,
		amount
	)


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
		push_warning("QuestManager: unsupported save version '%s'." % version)
		return false

	var raw_quests: Variant = data.get("quests", {})
	if not raw_quests is Dictionary:
		push_warning("QuestManager: 'quests' must be a Dictionary.")
		return false

	_reset_states()

	for raw_quest_id in raw_quests.keys():
		var quest_id := StringName(str(raw_quest_id))

		if not _definitions.has(quest_id):
			push_warning("QuestManager: ignoring retired quest '%s'." % quest_id)
			continue

		var raw_quest: Variant = raw_quests[raw_quest_id]
		if not raw_quest is Dictionary:
			push_warning("QuestManager: invalid state for quest '%s'." % quest_id)
			continue

		var status := int(
			raw_quest.get("status", QuestState.Status.INACTIVE)
		)

		if not _is_valid_status(status):
			push_warning("QuestManager: invalid status '%s' for quest '%s'." % [status, quest_id])
			continue

		var state := _get_state(quest_id)
		var definition := _get_definition(quest_id)

		if status == QuestState.Status.INACTIVE:
			continue

		var raw_objectives: Variant = raw_quest.get("objectives", {})

		if not raw_objectives is Dictionary:
			push_warning("QuestManager: invalid objectives for quest '%s'." % quest_id)
			raw_objectives = {}

		for objective in definition.objectives:
			var saved_amount := int(raw_objectives.get(str(objective.objective_id), 0))

			state.objective_progress[objective.objective_id] = clampi(saved_amount, 0, objective.required_amount)

		state.status = status as QuestState.Status

		if status == QuestState.Status.COMPLETED:
			_complete_required_objective_progress(definition, state)
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
		errors.append("quest_id '%s' is already registered" % definition.quest_id)

	return errors


func _register_validated_definition(definition: QuestDefinition) -> void:
	_definitions[definition.quest_id] = definition
	_states[definition.quest_id] = QuestState.create(definition)


func _reset_states() -> void:
	_states.clear()

	for raw_quest_id in _definitions.keys():
		var quest_id := StringName(raw_quest_id)
		_states[quest_id] = QuestState.create(_get_definition(quest_id))


func _complete_required_objective_progress(
	definition: QuestDefinition,
	state: QuestState
) -> Array[StringName]:
	var completed_objective_ids: Array[StringName] = []
	var grouped_objective_ids := {}

	for group in definition.objective_groups:
		if group == null:
			continue

		for objective_id in group.objective_ids:
			grouped_objective_ids[objective_id] = true

		if group.completion_mode == QuestObjectiveGroupDefinition.CompletionMode.ANY:
			var already_satisfied := false
			for objective_id in group.objective_ids:
				var objective := _find_objective_in_definition(definition, objective_id)
				if objective != null and state.get_current_amount(objective_id) >= objective.required_amount:
					already_satisfied = true
					break

			if not already_satisfied and not group.objective_ids.is_empty():
				_complete_objective_progress(
					definition,
					state,
					group.objective_ids[0],
					completed_objective_ids
				)
		else:
			for objective_id in group.objective_ids:
				_complete_objective_progress(
					definition,
					state,
					objective_id,
					completed_objective_ids
				)

	for objective in definition.objectives:
		if not grouped_objective_ids.has(objective.objective_id):
			_complete_objective_progress(
				definition,
				state,
				objective.objective_id,
				completed_objective_ids
			)

	return completed_objective_ids


func _complete_objective_progress(
	definition: QuestDefinition,
	state: QuestState,
	objective_id: StringName,
	completed_objective_ids: Array[StringName]
) -> void:
	var objective := _find_objective_in_definition(definition, objective_id)
	if objective == null:
		return

	if state.get_current_amount(objective_id) >= objective.required_amount:
		return

	state.objective_progress[objective_id] = objective.required_amount
	completed_objective_ids.append(objective_id)


func _find_objective_in_definition(
	definition: QuestDefinition,
	objective_id: StringName
) -> QuestObjectiveDefinition:
	for objective in definition.objectives:
		if objective != null and objective.objective_id == objective_id:
			return objective

	return null


func _is_valid_status(status: int) -> bool:
	return status == QuestState.Status.INACTIVE \
		or status == QuestState.Status.ACTIVE \
		or status == QuestState.Status.COMPLETED \
		or status == QuestState.Status.FAILED


func get_registered_quest_ids() -> Array[StringName]:
	var quest_ids: Array[StringName] = []

	for raw_quest_id in _definitions.keys():
		quest_ids.append(StringName(raw_quest_id))

	return quest_ids


func get_quest_definition(quest_id: StringName) -> QuestDefinition:
	return _get_definition(quest_id)


func get_quest_status(quest_id: StringName) -> QuestState.Status:
	var state := _get_state(quest_id)

	if state == null:
		return QuestState.Status.INACTIVE

	return state.status


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

	for objective_id in _complete_required_objective_progress(definition, state):
		objective_completed.emit(quest_id, objective_id)

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
	var grouped_objective_ids := {}

	for group in definition.objective_groups:
		if group == null or group.objective_ids.is_empty():
			return false

		for objective_id in group.objective_ids:
			grouped_objective_ids[objective_id] = true

		if not _is_objective_group_completed(quest_id, group):
			return false

	for objective in definition.objectives:
		if grouped_objective_ids.has(objective.objective_id):
			continue

		if not is_objective_completed(quest_id, objective.objective_id):
			return false

	return true


func _is_objective_group_completed(
	quest_id: StringName,
	group: QuestObjectiveGroupDefinition
) -> bool:
	match group.completion_mode:
		QuestObjectiveGroupDefinition.CompletionMode.ALL:
			for objective_id in group.objective_ids:
				if not is_objective_completed(quest_id, objective_id):
					return false
			return true

		QuestObjectiveGroupDefinition.CompletionMode.ANY:
			for objective_id in group.objective_ids:
				if is_objective_completed(quest_id, objective_id):
					return true
			return false

	return false


func _set_objective_progress(quest_id: StringName, objective_id: StringName, amount: int) -> bool:
	var state := _get_state(quest_id)
	var objective := _get_objective_definition(quest_id, objective_id)

	if state == null or objective == null:
		return false

	if state.status != QuestState.Status.ACTIVE:
		return false

	var old_amount := state.get_current_amount(objective_id)
	var new_amount := clampi(amount, 0, objective.required_amount)

	if old_amount == new_amount:
		return false

	var was_completed := old_amount >= objective.required_amount
	var is_now_completed := new_amount >= objective.required_amount

	state.objective_progress[objective_id] = new_amount

	if not was_completed and is_now_completed:
		objective_completed.emit(quest_id, objective_id)

	if _are_all_objectives_completed(quest_id):
		state.status = QuestState.Status.COMPLETED
		quest_completed.emit(quest_id)

	quest_updated.emit(quest_id)
	return true


func _reevaluate_inventory_owned_objective(quest_id: StringName, objective: QuestObjectiveDefinition) -> bool:
	if objective.event_type != QuestObjectiveDefinition.EventType.INVENTORY_OWNED:
		return false

	var current_amount := InventoryManager.get_amount(objective.target_id)

	return _set_objective_progress(quest_id, objective.objective_id, current_amount)


func _reevaluate_inventory_owned_objectives_for_quest(quest_id: StringName) -> bool:
	if not is_active(quest_id):
		return false

	var definition := _get_definition(quest_id)
	if definition == null:
		return false

	var changed := false

	for objective in definition.objectives:
		if _reevaluate_inventory_owned_objective(quest_id, objective):
			changed = true

	return changed


func _reevaluate_inventory_owned_objectives_for_item(item_id: StringName) -> void:
	if item_id.is_empty():
		return

	for raw_quest_id in _definitions.keys():
		var quest_id := StringName(raw_quest_id)

		if not is_active(quest_id):
			continue

		var definition := _get_definition(quest_id)
		if definition == null:
			continue

		for objective in definition.objectives:
			if objective.event_type != QuestObjectiveDefinition.EventType.INVENTORY_OWNED:
				continue

			if objective.target_id != item_id:
				continue

			_reevaluate_inventory_owned_objective(quest_id, objective)


func _on_inventory_item_changed(item_id: StringName, _amount: int, _new_total: int) -> void:
	_reevaluate_inventory_owned_objectives_for_item(item_id)
